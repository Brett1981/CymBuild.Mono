using Concursus.API.Core;
using Grpc.Core;
using Microsoft.Data.SqlClient;
using System.Data;

namespace Concursus.API.Services;

public partial class CoreService
{
    private async Task<OnboardingMigrationStageResponse> OnboardingMigrationStageCrossServerAsync(
        OnboardingMigrationStageRequest request,
        OnboardingDatabaseContext databaseContext,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(databaseContext.SourceDatabaseName))
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                "Source database is required for cross-server OnBoarding staging."));
        }

        if (!Guid.TryParse(request.BusinessUnitGroupGuid, out var businessUnitGroupGuid))
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                "BusinessUnitGroupGuid is required and must be a valid Guid."));
        }

        try
        {
            await using var templateConnection = await OpenSqlAsync(cancellationToken);

            // Match the Metadata Migration cross-server pattern:
            // 1. Open the selected target connection first.
            // 2. Use that connection string template to open the selected source connection.
            // 3. Read source data outside the target transaction.
            // 4. Open one short target transaction only for reset/reserve/bulk-copy/finalise.
            await using var targetConnection = await OpenSqlForServerDatabaseAsync(
                templateConnection.ConnectionString,
                databaseContext.TargetServerName,
                databaseContext.TargetDatabaseName,
                cancellationToken);

            await using var sourceConnection = await OpenSqlForServerDatabaseAsync(
                targetConnection.ConnectionString,
                databaseContext.SourceServerName,
                databaseContext.SourceDatabaseName,
                cancellationToken);

            var sourceBusinessUnitOrganisationalUnitGuid = await ResolveSourceBusinessUnitOrganisationalUnitGuidAsync(
                sourceConnection,
                businessUnitGroupGuid,
                cancellationToken);

            if (sourceBusinessUnitOrganisationalUnitGuid is null)
            {
                throw new RpcException(new Status(
                    StatusCode.InvalidArgument,
                    $"Could not resolve source business unit group {businessUnitGroupGuid} to an organisational unit in {databaseContext.SourceServerName}/{databaseContext.SourceDatabaseName}. The group must be used as SCore.OrganisationalUnits.DefaultSecurityGroupId or match an organisational unit name."));
            }

            var stagedTables = new List<(OnboardingStageQuery StageQuery, DataTable Table)>();
            foreach (var stageQuery in CrossServerStageQueries)
            {
                var table = await ReadOnboardingSourceStageTableAsync(
                    sourceConnection,
                    stageQuery,
                    runGuid,
                    businessUnitGroupGuid,
                    sourceBusinessUnitOrganisationalUnitGuid.Value,
                    cancellationToken);

                stagedTables.Add((stageQuery, table));
            }

            await using var transaction = (SqlTransaction)await targetConnection.BeginTransactionAsync(cancellationToken);

            try
            {
                await ExecuteOnboardingNonQueryAsync(
                    targetConnection,
                    transaction,
                    "SMigration.OnboardingStage_Reset",
                    command => command.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid }),
                    cancellationToken);

                await ExecuteOnboardingNonQueryAsync(
                    targetConnection,
                    transaction,
                    "SMigration.OnboardingRun_Reserve",
                    command =>
                    {
                        command.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
                        command.Parameters.Add(new SqlParameter("@SourceDatabase", SqlDbType.NVarChar, 128) { Value = databaseContext.SourceDatabaseName });
                        command.Parameters.Add(new SqlParameter("@SourceServerName", SqlDbType.NVarChar, 128) { Value = databaseContext.SourceServerName });
                        command.Parameters.Add(new SqlParameter("@TargetServerName", SqlDbType.NVarChar, 128) { Value = databaseContext.TargetServerName });
                        command.Parameters.Add(new SqlParameter("@TargetDatabaseName", SqlDbType.NVarChar, 128) { Value = databaseContext.TargetDatabaseName });
                        command.Parameters.Add(new SqlParameter("@BusinessUnitGroupGuid", SqlDbType.UniqueIdentifier) { Value = businessUnitGroupGuid });
                        command.Parameters.Add(new SqlParameter("@SourceBusinessUnitOrganisationalUnitGuid", SqlDbType.UniqueIdentifier) { Value = sourceBusinessUnitOrganisationalUnitGuid.Value });
                        command.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, 1000) { Value = request.Notes ?? string.Empty });
                    },
                    cancellationToken);

                foreach (var stagedTable in stagedTables)
                {
                    RemoveDuplicateRowsForStageKey(
                        stagedTable.Table,
                        stagedTable.StageQuery.TargetTableName);

                    await BulkCopyOnboardingStageAsync(
                        targetConnection,
                        transaction,
                        stagedTable.StageQuery.TargetTableName,
                        stagedTable.Table,
                        cancellationToken);
                }

                var response = await FinaliseCrossServerOnboardingStageAsync(
                    targetConnection,
                    transaction,
                    runGuid,
                    cancellationToken);

                await transaction.CommitAsync(cancellationToken);
                response.RunGuid = runGuid.ToString();
                return response;
            }
            catch
            {
                await transaction.RollbackAsync(cancellationToken);
                throw;
            }
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                $"Cross-server OnBoarding stage SQL failed: {ex.Message}"));
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            var message = ex.InnerException is null ? ex.Message : $"{ex.Message} Inner: {ex.InnerException.Message}";
            throw new RpcException(new Status(
                StatusCode.Internal,
                $"Cross-server OnBoarding stage failed: {message}"));
        }
    }

    private async Task<OnboardingMigrationLookupResponse> ReadBusinessUnitGroupsCrossServerAsync(
        OnboardingDatabaseContext databaseContext,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(databaseContext.SourceDatabaseName))
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, "Source database is required."));
        }

        var response = new OnboardingMigrationLookupResponse();
        await using var templateConnection = await OpenSqlAsync(cancellationToken);
        await using var sourceConnection = await OpenSqlForServerDatabaseAsync(
            templateConnection.ConnectionString,
            databaseContext.SourceServerName,
            databaseContext.SourceDatabaseName,
            cancellationToken);

        await using var cmd = new SqlCommand(CrossServerBusinessUnitLookupSql, sourceConnection)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            response.Items.Add(new OnboardingMigrationLookupItem
            {
                Guid = Convert.ToString(reader["Guid"]) ?? string.Empty,
                Name = Convert.ToString(reader["Name"]) ?? string.Empty,
                Code = Convert.ToString(reader["Code"]) ?? string.Empty,
                Description = Convert.ToString(reader["Description"]) ?? string.Empty
            });
        }

        return response;
    }

    private static async Task<Guid?> ResolveSourceBusinessUnitOrganisationalUnitGuidAsync(
        SqlConnection sourceConnection,
        Guid businessUnitGroupGuid,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(
            """
            SELECT TOP (1)
                SourceBusinessUnitOrganisationalUnitGuid = ou.Guid
            FROM SCore.OrganisationalUnits AS ou
            INNER JOIN SCore.Groups AS g
                ON g.ID = ou.DefaultSecurityGroupId
            WHERE g.Guid = @BusinessUnitGroupGuid
              AND ou.ID > 0
              AND g.ID > 0
            ORDER BY ou.ID;
            """,
            sourceConnection)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@BusinessUnitGroupGuid", SqlDbType.UniqueIdentifier) { Value = businessUnitGroupGuid });

        var result = await cmd.ExecuteScalarAsync(cancellationToken);
        if (result is Guid directMatch)
        {
            return directMatch;
        }

        await using var fallback = new SqlCommand(
            """
            SELECT TOP (1)
                SourceBusinessUnitOrganisationalUnitGuid = ou.Guid
            FROM SCore.OrganisationalUnits AS ou
            INNER JOIN SCore.Groups AS g
                ON g.Guid = @BusinessUnitGroupGuid
            WHERE ou.Name = g.Name
              AND ou.ID > 0
              AND g.ID > 0
            ORDER BY ou.ID;
            """,
            sourceConnection)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 300
        };
        fallback.Parameters.Add(new SqlParameter("@BusinessUnitGroupGuid", SqlDbType.UniqueIdentifier) { Value = businessUnitGroupGuid });

        result = await fallback.ExecuteScalarAsync(cancellationToken);
        return result is Guid fallbackMatch ? fallbackMatch : null;
    }

    private static async Task<DataTable> ReadOnboardingSourceStageTableAsync(
        SqlConnection sourceConnection,
        OnboardingStageQuery stageQuery,
        Guid runGuid,
        Guid businessUnitGroupGuid,
        Guid sourceBusinessUnitOrganisationalUnitGuid,
        CancellationToken cancellationToken)
    {
        try
        {
            await using var cmd = new SqlCommand(stageQuery.Sql, sourceConnection)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 300
            };

            cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });
            cmd.Parameters.Add(new SqlParameter("@BusinessUnitGroupGuid", SqlDbType.UniqueIdentifier) { Value = businessUnitGroupGuid });
            cmd.Parameters.Add(new SqlParameter("@BusinessUnitOuGuid", SqlDbType.UniqueIdentifier) { Value = sourceBusinessUnitOrganisationalUnitGuid });

            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
            var table = new DataTable();
            table.Load(reader);
            return table;
        }
        catch (SqlException ex)
        {
            throw new RpcException(new Status(
                StatusCode.InvalidArgument,
                $"Cross-server OnBoarding source read failed for {stageQuery.TargetTableName}: {ex.Message}"));
        }
    }


    private static void RemoveDuplicateRowsForStageKey(DataTable table, string targetTableName)
    {
        if (table.Rows.Count < 2)
        {
            return;
        }

        var keyColumns = GetOnboardingStageKeyColumns(targetTableName);
        if (keyColumns.Length == 0)
        {
            return;
        }

        foreach (var keyColumn in keyColumns)
        {
            if (!table.Columns.Contains(keyColumn))
            {
                return;
            }
        }

        var seenKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var duplicateRows = new List<DataRow>();

        foreach (DataRow row in table.Rows)
        {
            var key = string.Join("", keyColumns.Select(columnName => Convert.ToString(row[columnName], System.Globalization.CultureInfo.InvariantCulture) ?? string.Empty));
            if (!seenKeys.Add(key))
            {
                duplicateRows.Add(row);
            }
        }

        foreach (var duplicateRow in duplicateRows)
        {
            table.Rows.Remove(duplicateRow);
        }

        if (duplicateRows.Count > 0)
        {
            table.AcceptChanges();
        }
    }

    private static string[] GetOnboardingStageKeyColumns(string targetTableName)
    {
        return targetTableName switch
        {
            "SMigration.Onboarding_Groups" => new[] { "RunGuid", "GroupGuid" },
            "SMigration.Onboarding_OrganisationalUnits" => new[] { "RunGuid", "OrganisationalUnitGuid" },
            "SMigration.Onboarding_Addresses" => new[] { "RunGuid", "AddressGuid" },
            "SMigration.Onboarding_Contacts" => new[] { "RunGuid", "ContactGuid" },
            "SMigration.Onboarding_Identities" => new[] { "RunGuid", "IdentityGuid" },
            "SMigration.Onboarding_UserGroups" => new[] { "RunGuid", "UserGroupGuid" },
            "SMigration.Onboarding_Workflows" => new[] { "RunGuid", "WorkflowGuid" },
            "SMigration.Onboarding_WorkflowStatuses" => new[] { "RunGuid", "WorkflowStatusGuid" },
            "SMigration.Onboarding_WorkflowTransitions" => new[] { "RunGuid", "WorkflowTransitionGuid" },
            "SMigration.Onboarding_WorkflowStatusNotificationGroups" => new[] { "RunGuid", "WorkflowNotificationGroupGuid" },
            "SMigration.Onboarding_JobTypes" => new[] { "RunGuid", "JobTypeGuid" },
            "SMigration.Onboarding_ActivityTypes" => new[] { "RunGuid", "ActivityTypeGuid" },
            "SMigration.Onboarding_MilestoneTypes" => new[] { "RunGuid", "MilestoneTypeGuid" },
            "SMigration.Onboarding_Products" => new[] { "RunGuid", "ProductGuid" },
            "SMigration.Onboarding_JobTypeActivityTypes" => new[] { "RunGuid", "JobTypeActivityTypeGuid" },
            "SMigration.Onboarding_JobTypeMilestoneTemplates" => new[] { "RunGuid", "JobTypeMilestoneTemplateGuid" },
            "SMigration.Onboarding_ProductJobActivities" => new[] { "RunGuid", "ProductJobActivityGuid" },
            _ => Array.Empty<string>()
        };
    }

    private static async Task BulkCopyOnboardingStageAsync(
        SqlConnection targetConnection,
        SqlTransaction transaction,
        string targetTableName,
        DataTable table,
        CancellationToken cancellationToken)
    {
        if (table.Rows.Count == 0)
        {
            return;
        }

        using var bulkCopy = new SqlBulkCopy(targetConnection, SqlBulkCopyOptions.CheckConstraints, transaction)
        {
            DestinationTableName = targetTableName,
            BulkCopyTimeout = 300,
            BatchSize = 1000
        };

        foreach (DataColumn column in table.Columns)
        {
            bulkCopy.ColumnMappings.Add(column.ColumnName, column.ColumnName);
        }

        await bulkCopy.WriteToServerAsync(table, cancellationToken);
    }

    private static async Task ExecuteOnboardingNonQueryAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string procedureName,
        Action<SqlCommand> configure,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(procedureName, connection, transaction)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        configure(cmd);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task<OnboardingMigrationStageResponse> FinaliseCrossServerOnboardingStageAsync(
        SqlConnection targetConnection,
        SqlTransaction transaction,
        Guid runGuid,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand("SMigration.OnboardingStage_FinaliseApiLoad", targetConnection, transaction)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };
        cmd.Parameters.Add(new SqlParameter("@RunGuid", SqlDbType.UniqueIdentifier) { Value = runGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new RpcException(new Status(
                StatusCode.Internal,
                "Cross-server OnBoarding stage did not return a stage summary."));
        }

        return new OnboardingMigrationStageResponse
        {
            RunGuid = runGuid.ToString(),
            GroupCount = Convert.ToInt32(reader["GroupCount"]),
            IdentityCount = Convert.ToInt32(reader["IdentityCount"]),
            UserGroupCount = Convert.ToInt32(reader["UserGroupCount"]),
            WorkflowNotificationGroupCount = Convert.ToInt32(reader["WorkflowNotificationGroupCount"]),
            JobTypeCount = Convert.ToInt32(reader["JobTypeCount"]),
            ActivityTypeCount = Convert.ToInt32(reader["ActivityTypeCount"]),
            MilestoneTypeCount = Convert.ToInt32(reader["MilestoneTypeCount"]),
            ProductCount = Convert.ToInt32(reader["ProductCount"]),
            JobTypeActivityTypeCount = Convert.ToInt32(reader["JobTypeActivityTypeCount"]),
            JobTypeMilestoneTemplateCount = Convert.ToInt32(reader["JobTypeMilestoneTemplateCount"]),
            ProductJobActivityCount = Convert.ToInt32(reader["ProductJobActivityCount"])
        };
    }

    private sealed record OnboardingStageQuery(string TargetTableName, string Sql);

    private const string CrossServerBusinessUnitLookupSql = """
        SELECT
            Guid = CAST(g.Guid AS NVARCHAR(36)),
            Name = ISNULL(g.Name, N''),
            Code = ISNULL(g.Code, N''),
            Description = CONCAT(ISNULL(g.Code, N''), N' - ', ISNULL(g.Name, N''))
        FROM SCore.Groups AS g
        WHERE g.RowStatus NOT IN (0,254)
          AND g.ID > 0
          AND g.Guid <> '00000000-0000-0000-0000-000000000000'
          AND ISNULL(g.DirectoryId, N'') <> N''
          AND EXISTS
          (
              SELECT 1
              FROM SCore.OrganisationalUnits AS ou
              WHERE ou.ID > 0
                AND ou.RowStatus NOT IN (0,254)
                AND
                (
                    ou.DefaultSecurityGroupId = g.ID
                    OR ou.Name = g.Name
                )
          )
        ORDER BY g.Name;
        """;

    private static readonly OnboardingStageQuery[] CrossServerStageQueries = new OnboardingStageQuery[]
    {
        new("SMigration.Onboarding_Groups", """
            ;WITH StageIdentityIds AS
            (
                SELECT DISTINCT i.ID
                FROM SCore.Identities AS i
                INNER JOIN SCore.UserGroups AS ug ON ug.IdentityID = i.ID AND ug.RowStatus NOT IN (0,254)
                INNER JOIN SCore.Groups AS g ON g.ID = ug.GroupID AND g.RowStatus NOT IN (0,254)
                WHERE i.RowStatus NOT IN (0,254) AND i.ID > 0 AND g.Guid = @BusinessUnitGroupGuid
            ),
            StageOU AS
            (
                SELECT ou.ID, g.ID AS DefaultGroupID
                FROM SCore.OrganisationalUnits AS ou
                INNER JOIN SCore.Groups AS g ON g.ID = ou.DefaultSecurityGroupId
                CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b
                WHERE ou.RowStatus NOT IN (0,254)
                  AND ou.ID > 0
                  AND (ou.OrgNode.IsDescendantOf(b.OrgNode) = 1 OR b.OrgNode.IsDescendantOf(ou.OrgNode) = 1)
            ),
            RelevantGroups AS
            (
                SELECT g.ID, g.Guid, g.RowStatus, g.DirectoryId, g.Code, g.Name, g.Source
                FROM SCore.Groups AS g
                WHERE g.Guid = @BusinessUnitGroupGuid AND g.ID > 0
                UNION
                SELECT DISTINCT g.ID, g.Guid, g.RowStatus, g.DirectoryId, g.Code, g.Name, g.Source
                FROM SCore.Groups AS g
                INNER JOIN SCore.UserGroups AS ug ON ug.GroupID = g.ID
                INNER JOIN StageIdentityIds AS s ON s.ID = ug.IdentityID
                WHERE g.RowStatus NOT IN (0,254) AND ug.RowStatus NOT IN (0,254) AND g.ID > 0
                UNION
                SELECT DISTINCT g.ID, g.Guid, g.RowStatus, g.DirectoryId, g.Code, g.Name, g.Source
                FROM SCore.Groups AS g
                INNER JOIN StageOU AS sou ON sou.DefaultGroupID = g.ID
                WHERE g.RowStatus NOT IN (0,254) AND g.ID > 0
            )
            SELECT DISTINCT
                RunGuid = @RunGuid,
                GroupGuid = rg.Guid,
                RowStatus = rg.RowStatus,
                DirectoryId = ISNULL(rg.DirectoryId, N''),
                Code = ISNULL(rg.Code, N''),
                Name = ISNULL(rg.Name, N''),
                Source = ISNULL(rg.Source, N''),
                IsBusinessUnitGroup = CAST(CASE WHEN rg.Guid = @BusinessUnitGroupGuid THEN 1 ELSE 0 END AS BIT)
            FROM RelevantGroups AS rg
            WHERE rg.ID > 0 AND rg.Guid <> '00000000-0000-0000-0000-000000000000';
            """),
        new("SMigration.Onboarding_OrganisationalUnits", """
            SELECT
                RunGuid = @RunGuid,
                OrganisationalUnitGuid = ou.Guid,
                RowStatus = ou.RowStatus,
                Name = ISNULL(ou.Name, N''),
                ParentOrganisationalUnitGuid = parent.Guid,
                ParentOrganisationalUnitName = ISNULL(parent.Name, N''),
                AddressGuid = a.Guid,
                ContactGuid = c.Guid,
                OfficialAddressGuid = oa.Guid,
                OfficialContactGuid = oc.Guid,
                DepartmentPrefix = ISNULL(ou.DepartmentPrefix, N''),
                CostCentreCode = ISNULL(ou.CostCentreCode, N''),
                DefaultSecurityGroupGuid = g.Guid,
                QuoteThreshold = ou.QuoteThreshold,
                OrgLevel = ou.OrgNode.GetLevel()
            FROM SCore.OrganisationalUnits AS ou
            LEFT JOIN SCore.OrganisationalUnits AS parent ON parent.ID = ou.ParentID
            INNER JOIN SCrm.Addresses AS a ON a.ID = ou.AddressId
            INNER JOIN SCrm.Contacts AS c ON c.ID = ou.ContactId
            INNER JOIN SCrm.Addresses AS oa ON oa.ID = ou.OfficialAddressId
            INNER JOIN SCrm.Contacts AS oc ON oc.ID = ou.OfficialContactId
            INNER JOIN SCore.Groups AS g ON g.ID = ou.DefaultSecurityGroupId
            CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b
            WHERE ou.RowStatus NOT IN (0,254)
              AND ou.ID > 0
              AND ou.Guid <> '00000000-0000-0000-0000-000000000000'
              AND (ou.OrgNode.IsDescendantOf(b.OrgNode) = 1 OR b.OrgNode.IsDescendantOf(ou.OrgNode) = 1);
            """),
        new("SMigration.Onboarding_Addresses", """
            ;WITH StageOU AS
            (
                SELECT ou.AddressId, ou.OfficialAddressId, ou.ContactId, ou.OfficialContactId
                FROM SCore.OrganisationalUnits AS ou
                CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b
                WHERE ou.RowStatus NOT IN (0,254)
                  AND ou.ID > 0
                  AND (ou.OrgNode.IsDescendantOf(b.OrgNode) = 1 OR b.OrgNode.IsDescendantOf(ou.OrgNode) = 1)
            ),
            IdentityContactIds AS
            (
                SELECT DISTINCT i.ContactId
                FROM SCore.Identities AS i
                INNER JOIN SCore.UserGroups AS ug ON ug.IdentityID = i.ID AND ug.RowStatus NOT IN (0,254)
                INNER JOIN SCore.Groups AS g ON g.ID = ug.GroupID AND g.RowStatus NOT IN (0,254)
                WHERE i.RowStatus NOT IN (0,254) AND i.ID > 0 AND g.Guid = @BusinessUnitGroupGuid
            ),
            ContactAddressIds AS
            (
                SELECT c.PrimaryAddressID AS AddressID FROM SCrm.Contacts AS c INNER JOIN IdentityContactIds AS i ON i.ContactId = c.ID
                UNION SELECT c.PrimaryAddressID FROM SCrm.Contacts AS c INNER JOIN StageOU AS ou ON ou.ContactId = c.ID
                UNION SELECT c.PrimaryAddressID FROM SCrm.Contacts AS c INNER JOIN StageOU AS ou ON ou.OfficialContactId = c.ID
            ),
            RelevantAddressIds AS
            (
                SELECT AddressId AS AddressID FROM StageOU
                UNION SELECT OfficialAddressId FROM StageOU
                UNION SELECT AddressID FROM ContactAddressIds
            )
            SELECT DISTINCT
                RunGuid = @RunGuid,
                AddressGuid = a.Guid,
                RowStatus = a.RowStatus,
                AddressNumber = a.AddressNumber,
                Name = ISNULL(a.Name, N''),
                Number = ISNULL(a.Number, N''),
                AddressLine1 = ISNULL(a.AddressLine1, N''),
                AddressLine2 = ISNULL(a.AddressLine2, N''),
                AddressLine3 = ISNULL(a.AddressLine3, N''),
                Town = ISNULL(a.Town, N''),
                CountyGuid = county.Guid,
                Postcode = ISNULL(a.Postcode, N''),
                CountryGuid = country.Guid,
                LegacySystemID = a.LegacySystemID
            FROM SCrm.Addresses AS a
            LEFT JOIN SCrm.Counties AS county ON county.ID = a.CountyID
            LEFT JOIN SCrm.Countries AS country ON country.ID = a.CountryID
            INNER JOIN RelevantAddressIds AS r ON r.AddressID = a.ID
            WHERE a.ID > 0 AND a.Guid <> '00000000-0000-0000-0000-000000000000';
            """),
        new("SMigration.Onboarding_Contacts", """
            ;WITH StageOU AS
            (
                SELECT ou.ContactId, ou.OfficialContactId
                FROM SCore.OrganisationalUnits AS ou
                CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b
                WHERE ou.RowStatus NOT IN (0,254)
                  AND ou.ID > 0
                  AND (ou.OrgNode.IsDescendantOf(b.OrgNode) = 1 OR b.OrgNode.IsDescendantOf(ou.OrgNode) = 1)
            ),
            RelevantContactIds AS
            (
                SELECT ContactId AS ContactID FROM StageOU
                UNION SELECT OfficialContactId FROM StageOU
                UNION
                SELECT DISTINCT i.ContactId
                FROM SCore.Identities AS i
                INNER JOIN SCore.UserGroups AS ug ON ug.IdentityID = i.ID AND ug.RowStatus NOT IN (0,254)
                INNER JOIN SCore.Groups AS g ON g.ID = ug.GroupID AND g.RowStatus NOT IN (0,254)
                WHERE i.RowStatus NOT IN (0,254) AND i.ID > 0 AND g.Guid = @BusinessUnitGroupGuid
            )
            SELECT DISTINCT
                RunGuid = @RunGuid,
                ContactGuid = c.Guid,
                RowStatus = c.RowStatus,
                PrimaryAccountGuid = acct.Guid,
                PrimaryAddressGuid = addr.Guid,
                FirstName = ISNULL(c.FirstName, N''),
                Initials = ISNULL(c.Initials, N''),
                Surname = ISNULL(c.Surname, N''),
                PostNominals = ISNULL(c.PostNominals, N''),
                TitleGuid = title.Guid,
                DisplayName = ISNULL(c.DisplayName, N''),
                IsPerson = c.IsPerson,
                PositionGuid = pos.Guid,
                LegacySystemID = c.LegacySystemID
            FROM SCrm.Contacts AS c
            LEFT JOIN SCrm.Accounts AS acct ON acct.ID = c.PrimaryAccountID
            INNER JOIN SCrm.Addresses AS addr ON addr.ID = c.PrimaryAddressID
            LEFT JOIN SCrm.ContactTitles AS title ON title.ID = c.TitleId
            LEFT JOIN SCrm.ContactPositions AS pos ON pos.ID = c.PositionID
            INNER JOIN RelevantContactIds AS r ON r.ContactID = c.ID
            WHERE c.ID > 0 AND c.Guid <> '00000000-0000-0000-0000-000000000000';
            """),
        new("SMigration.Onboarding_Identities", """
            SELECT DISTINCT
                RunGuid = @RunGuid,
                IdentityGuid = i.Guid,
                RowStatus = i.RowStatus,
                FullName = ISNULL(i.FullName, N''),
                EmailAddress = ISNULL(i.EmailAddress, N''),
                UserGuid = i.UserGuid,
                JobTitle = ISNULL(i.JobTitle, N''),
                OrganisationalUnitGuid = ou.Guid,
                IsActive = i.IsActive,
                ContactGuid = c.Guid,
                BillableRate = i.BillableRate,
                Signature = ISNULL(i.Signature, 0x)
            FROM SCore.Identities AS i
            INNER JOIN SCore.UserGroups AS ug ON ug.IdentityID = i.ID AND ug.RowStatus NOT IN (0,254)
            INNER JOIN SCore.Groups AS g ON g.ID = ug.GroupID AND g.RowStatus NOT IN (0,254)
            INNER JOIN SCore.OrganisationalUnits AS ou ON ou.ID = i.OriganisationalUnitId
            INNER JOIN SCrm.Contacts AS c ON c.ID = i.ContactId
            WHERE i.RowStatus NOT IN (0,254)
              AND i.ID > 0
              AND i.Guid <> '00000000-0000-0000-0000-000000000000'
              AND g.Guid = @BusinessUnitGroupGuid;
            """),
        new("SMigration.Onboarding_UserGroups", """
            ;WITH RelevantGroups AS
            (
                SELECT g.ID, g.Guid
                FROM SCore.Groups AS g
                WHERE g.Guid = @BusinessUnitGroupGuid AND g.ID > 0
                UNION
                SELECT DISTINCT g.ID, g.Guid
                FROM SCore.Groups AS g
                INNER JOIN SCore.UserGroups AS ug ON ug.GroupID = g.ID AND ug.RowStatus NOT IN (0,254)
                INNER JOIN SCore.Identities AS i ON i.ID = ug.IdentityID AND i.RowStatus NOT IN (0,254)
                INNER JOIN SCore.UserGroups AS bug ON bug.IdentityID = i.ID AND bug.RowStatus NOT IN (0,254)
                INNER JOIN SCore.Groups AS bg ON bg.ID = bug.GroupID AND bg.Guid = @BusinessUnitGroupGuid
                WHERE g.RowStatus NOT IN (0,254) AND g.ID > 0
            ),
            SourceUserGroups AS
            (
                SELECT
                    RunGuid = @RunGuid,
                    UserGroupGuid = ug.Guid,
                    RowStatus = ug.RowStatus,
                    IdentityGuid = i.Guid,
                    GroupGuid = g.Guid,
                    DuplicateRank = ROW_NUMBER() OVER (PARTITION BY ug.Guid ORDER BY ug.ID)
                FROM SCore.UserGroups AS ug
                INNER JOIN SCore.Identities AS i ON i.ID = ug.IdentityID AND i.ID > 0 AND i.RowStatus NOT IN (0,254)
                INNER JOIN SCore.Groups AS g ON g.ID = ug.GroupID AND g.ID > 0 AND g.RowStatus NOT IN (0,254)
                INNER JOIN RelevantGroups AS rg ON rg.ID = g.ID
                WHERE ug.RowStatus NOT IN (0,254)
                  AND ug.ID > 0
                  AND ug.Guid <> '00000000-0000-0000-0000-000000000000'
                  AND EXISTS
                  (
                      SELECT 1
                      FROM SCore.UserGroups AS bug
                      INNER JOIN SCore.Groups AS bg ON bg.ID = bug.GroupID AND bg.Guid = @BusinessUnitGroupGuid
                      WHERE bug.IdentityID = i.ID AND bug.RowStatus NOT IN (0,254)
                  )
            )
            SELECT RunGuid, UserGroupGuid, RowStatus, IdentityGuid, GroupGuid
            FROM SourceUserGroups
            WHERE DuplicateRank = 1;
            """),
        new("SMigration.Onboarding_Workflows", """
            ;WITH StageOU AS
            (
                SELECT ou.ID, ou.Guid
                FROM SCore.OrganisationalUnits AS ou
                CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b
                WHERE ou.RowStatus NOT IN (0,254) AND ou.ID > 0 AND ou.OrgNode.IsDescendantOf(b.OrgNode) = 1
            ),
            RelevantGroups AS
            (
                SELECT g.ID, g.Guid FROM SCore.Groups AS g WHERE g.Guid = @BusinessUnitGroupGuid AND g.ID > 0
                UNION SELECT DISTINCT g.ID, g.Guid
                FROM SCore.Groups AS g
                INNER JOIN SCore.UserGroups AS ug ON ug.GroupID = g.ID AND ug.RowStatus NOT IN (0,254)
                INNER JOIN SCore.Identities AS i ON i.ID = ug.IdentityID AND i.RowStatus NOT IN (0,254)
                INNER JOIN SCore.UserGroups AS bug ON bug.IdentityID = i.ID AND bug.RowStatus NOT IN (0,254)
                INNER JOIN SCore.Groups AS bg ON bg.ID = bug.GroupID AND bg.Guid = @BusinessUnitGroupGuid
                WHERE g.RowStatus NOT IN (0,254) AND g.ID > 0
            ),
            SourceWorkflows AS
            (
                SELECT DISTINCT wf.Guid AS WorkflowGuid, wf.RowStatus, ou.Guid AS OrganisationalUnitGuid, et.Guid AS EntityTypeGuid, eh.Guid AS EntityHoBTGuid, wf.Name, wf.Description, wf.Enabled
                FROM SCore.Workflow AS wf
                LEFT JOIN SCore.OrganisationalUnits AS ou ON ou.ID = wf.OrganisationalUnitId
                LEFT JOIN SCore.EntityTypes AS et ON et.ID = wf.EntityTypeID
                LEFT JOIN SCore.EntityHoBTs AS eh ON eh.ID = wf.EntityHoBTID
                WHERE wf.ID > 0 AND wf.Guid <> '00000000-0000-0000-0000-000000000000'
                  AND (wf.RowStatus NOT IN (0,254) OR EXISTS (SELECT 1 FROM SCore.WorkflowStatusNotificationGroups AS wsng WHERE wsng.WorkflowID = wf.ID AND wsng.RowStatus NOT IN (0,254) AND wsng.ID > 0))
                  AND (wf.OrganisationalUnitId = -1 OR EXISTS (SELECT 1 FROM StageOU AS sou WHERE sou.ID = wf.OrganisationalUnitId))
                UNION
                SELECT DISTINCT wf.Guid, wf.RowStatus, ou.Guid, et.Guid, eh.Guid, wf.Name, wf.Description, wf.Enabled
                FROM SCore.WorkflowStatusNotificationGroups AS wsng
                INNER JOIN SCore.Workflow AS wf ON wf.ID = wsng.WorkflowID AND wf.ID > 0 AND wf.Guid <> '00000000-0000-0000-0000-000000000000'
                INNER JOIN RelevantGroups AS rg ON rg.ID = wsng.GroupID
                LEFT JOIN SCore.OrganisationalUnits AS ou ON ou.ID = wf.OrganisationalUnitId
                LEFT JOIN SCore.EntityTypes AS et ON et.ID = wf.EntityTypeID
                LEFT JOIN SCore.EntityHoBTs AS eh ON eh.ID = wf.EntityHoBTID
                WHERE wsng.RowStatus NOT IN (0,254) AND wsng.ID > 0
            )
            SELECT DISTINCT
                RunGuid = @RunGuid,
                WorkflowGuid = sw.WorkflowGuid,
                RowStatus = sw.RowStatus,
                OrganisationalUnitGuid = sw.OrganisationalUnitGuid,
                EntityTypeGuid = sw.EntityTypeGuid,
                EntityHoBTGuid = sw.EntityHoBTGuid,
                Name = ISNULL(sw.Name, N''),
                Description = sw.Description,
                Enabled = sw.Enabled
            FROM SourceWorkflows AS sw;
            """),
        new("SMigration.Onboarding_WorkflowStatuses", """
            ;WITH StageOU AS
            (
                SELECT ou.ID, ou.Guid
                FROM SCore.OrganisationalUnits AS ou
                CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b
                WHERE ou.RowStatus NOT IN (0,254) AND ou.ID > 0 AND ou.OrgNode.IsDescendantOf(b.OrgNode) = 1
            ),
            RelevantGroups AS
            (
                SELECT g.ID, g.Guid FROM SCore.Groups AS g WHERE g.Guid = @BusinessUnitGroupGuid AND g.ID > 0
                UNION SELECT DISTINCT g.ID, g.Guid
                FROM SCore.Groups AS g
                INNER JOIN SCore.UserGroups AS ug ON ug.GroupID = g.ID AND ug.RowStatus NOT IN (0,254)
                INNER JOIN SCore.Identities AS i ON i.ID = ug.IdentityID AND i.RowStatus NOT IN (0,254)
                INNER JOIN SCore.UserGroups AS bug ON bug.IdentityID = i.ID AND bug.RowStatus NOT IN (0,254)
                INNER JOIN SCore.Groups AS bg ON bg.ID = bug.GroupID AND bg.Guid = @BusinessUnitGroupGuid
                WHERE g.RowStatus NOT IN (0,254) AND g.ID > 0
            ),
            SourceWorkflows AS
            (
                SELECT DISTINCT wf.ID
                FROM SCore.Workflow AS wf
                LEFT JOIN SCore.OrganisationalUnits AS ou ON ou.ID = wf.OrganisationalUnitId
                WHERE wf.ID > 0 AND wf.Guid <> '00000000-0000-0000-0000-000000000000'
                  AND (wf.RowStatus NOT IN (0,254) OR EXISTS (SELECT 1 FROM SCore.WorkflowStatusNotificationGroups AS wsng WHERE wsng.WorkflowID = wf.ID AND wsng.RowStatus NOT IN (0,254) AND wsng.ID > 0))
                  AND (wf.OrganisationalUnitId = -1 OR EXISTS (SELECT 1 FROM StageOU AS sou WHERE sou.ID = wf.OrganisationalUnitId))
                UNION
                SELECT DISTINCT wf.ID
                FROM SCore.WorkflowStatusNotificationGroups AS wsng
                INNER JOIN SCore.Workflow AS wf ON wf.ID = wsng.WorkflowID AND wf.ID > 0 AND wf.Guid <> '00000000-0000-0000-0000-000000000000'
                INNER JOIN RelevantGroups AS rg ON rg.ID = wsng.GroupID
                WHERE wsng.RowStatus NOT IN (0,254) AND wsng.ID > 0
            ),
            WorkflowStatusGuids AS
            (
                SELECT DISTINCT fromWs.Guid AS WorkflowStatusGuid
                FROM SCore.WorkflowTransition AS wt
                INNER JOIN SourceWorkflows AS sw ON sw.ID = wt.WorkflowID
                INNER JOIN SCore.WorkflowStatus AS fromWs ON fromWs.ID = wt.FromStatusID AND wt.FromStatusID > 0
                WHERE wt.ID > 0 AND wt.RowStatus NOT IN (0,254) AND fromWs.RowStatus NOT IN (0,254) AND fromWs.Guid <> '00000000-0000-0000-0000-000000000000'
                UNION
                SELECT DISTINCT toWs.Guid AS WorkflowStatusGuid
                FROM SCore.WorkflowTransition AS wt
                INNER JOIN SourceWorkflows AS sw ON sw.ID = wt.WorkflowID
                INNER JOIN SCore.WorkflowStatus AS toWs ON toWs.ID = wt.ToStatusID AND wt.ToStatusID > 0
                WHERE wt.ID > 0 AND wt.RowStatus NOT IN (0,254) AND toWs.RowStatus NOT IN (0,254) AND toWs.Guid <> '00000000-0000-0000-0000-000000000000'
                UNION
                SELECT DISTINCT ws.Guid AS WorkflowStatusGuid
                FROM SCore.WorkflowStatusNotificationGroups AS wsng
                INNER JOIN SourceWorkflows AS sw ON sw.ID = wsng.WorkflowID
                INNER JOIN SCore.WorkflowStatus AS ws ON ws.Guid = wsng.WorkflowStatusGuid
                WHERE wsng.ID > 0 AND wsng.RowStatus NOT IN (0,254) AND ws.RowStatus NOT IN (0,254) AND ws.Guid <> '00000000-0000-0000-0000-000000000000'
                UNION
                SELECT DISTINCT ws.Guid AS WorkflowStatusGuid
                FROM SCore.WorkflowStatus AS ws
                LEFT JOIN StageOU AS sou ON sou.ID = ws.OrganisationalUnitId
                WHERE ws.ID > 0 AND ws.RowStatus NOT IN (0,254) AND ws.Guid <> '00000000-0000-0000-0000-000000000000'
                  AND (ws.OrganisationalUnitId = -1 OR sou.ID IS NOT NULL)
            )
            SELECT DISTINCT
                RunGuid = @RunGuid,
                WorkflowStatusGuid = ws.Guid,
                RowStatus = ws.RowStatus,
                OrganisationalUnitGuid = ou.Guid,
                Name = ISNULL(ws.Name, N''),
                Description = ISNULL(ws.Description, N''),
                ShowInEnquiries = ws.ShowInEnquiries,
                ShowInQuotes = ws.ShowInQuotes,
                ShowInJobs = ws.ShowInJobs,
                Enabled = ws.Enabled,
                IsPredefined = ws.IsPredefined,
                SortOrder = ws.SortOrder,
                Colour = ws.Colour,
                Icon = ws.Icon,
                SendNotification = ws.SendNotification,
                IsCompleteStatus = ws.IsCompleteStatus,
                IsCustomerWaitingStatus = ws.IsCustomerWaitingStatus,
                RequiresUsersAction = ws.RequiresUsersAction,
                IsActiveStatus = ws.IsActiveStatus,
                AuthorisationNeeded = ws.AuthorisationNeeded,
                IsAuthStatus = ws.IsAuthStatus
            FROM SCore.WorkflowStatus AS ws
            INNER JOIN WorkflowStatusGuids AS relevant ON relevant.WorkflowStatusGuid = ws.Guid
            LEFT JOIN SCore.OrganisationalUnits AS ou ON ou.ID = ws.OrganisationalUnitId;
            """),
        new("SMigration.Onboarding_WorkflowTransitions", """
            ;WITH StageWorkflowIds AS
            (
                SELECT DISTINCT wf.ID
                FROM SCore.Workflow AS wf
                LEFT JOIN SCore.OrganisationalUnits AS ou ON ou.ID = wf.OrganisationalUnitId
                CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b
                WHERE wf.ID > 0 AND (wf.OrganisationalUnitId = -1 OR ou.OrgNode.IsDescendantOf(b.OrgNode) = 1)
            )
            SELECT
                RunGuid = @RunGuid,
                WorkflowTransitionGuid = wt.Guid,
                RowStatus = wt.RowStatus,
                WorkflowGuid = wf.Guid,
                FromStatusGuid = ISNULL(fromWs.Guid, '00000000-0000-0000-0000-000000000000'),
                ToStatusGuid = ISNULL(toWs.Guid, '00000000-0000-0000-0000-000000000000'),
                IsFinal = wt.IsFinal,
                Enabled = wt.Enabled,
                SortOrder = wt.SortOrder,
                Description = ISNULL(wt.Description, N'')
            FROM SCore.WorkflowTransition AS wt
            INNER JOIN SCore.Workflow AS wf ON wf.ID = wt.WorkflowID
            LEFT JOIN SCore.WorkflowStatus AS fromWs ON fromWs.ID = wt.FromStatusID AND wt.FromStatusID > 0
            LEFT JOIN SCore.WorkflowStatus AS toWs ON toWs.ID = wt.ToStatusID AND wt.ToStatusID > 0
            INNER JOIN StageWorkflowIds AS sw ON sw.ID = wf.ID
            WHERE wt.ID > 0 AND wt.RowStatus NOT IN (0,254) AND wt.Guid <> '00000000-0000-0000-0000-000000000000';
            """),
        new("SMigration.Onboarding_WorkflowStatusNotificationGroups", """
            ;WITH RelevantGroups AS
            (
                SELECT g.ID, g.Guid FROM SCore.Groups AS g WHERE g.Guid = @BusinessUnitGroupGuid AND g.ID > 0
                UNION SELECT DISTINCT g.ID, g.Guid
                FROM SCore.Groups AS g
                INNER JOIN SCore.UserGroups AS ug ON ug.GroupID = g.ID AND ug.RowStatus NOT IN (0,254)
                INNER JOIN SCore.Identities AS i ON i.ID = ug.IdentityID AND i.RowStatus NOT IN (0,254)
                INNER JOIN SCore.UserGroups AS bug ON bug.IdentityID = i.ID AND bug.RowStatus NOT IN (0,254)
                INNER JOIN SCore.Groups AS bg ON bg.ID = bug.GroupID AND bg.Guid = @BusinessUnitGroupGuid
                WHERE g.RowStatus NOT IN (0,254) AND g.ID > 0
            )
            SELECT DISTINCT
                RunGuid = @RunGuid,
                WorkflowNotificationGroupGuid = x.Guid,
                RowStatus = x.RowStatus,
                WorkflowGuid = wf.Guid,
                WorkflowStatusGuid = x.WorkflowStatusGuid,
                GroupGuid = g.Guid,
                CanAction = x.CanAction
            FROM SCore.WorkflowStatusNotificationGroups AS x
            INNER JOIN SCore.Workflow AS wf ON wf.ID = x.WorkflowID
            INNER JOIN RelevantGroups AS g ON g.ID = x.GroupID
            WHERE x.RowStatus NOT IN (0,254)
              AND x.ID > 0
              AND x.Guid <> '00000000-0000-0000-0000-000000000000';
            """),
        new("SMigration.Onboarding_JobTypes", """
            ;WITH StageOU AS
            (
                SELECT ou.ID, ou.Guid
                FROM SCore.OrganisationalUnits AS ou
                CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b
                WHERE ou.RowStatus NOT IN (0,254) AND ou.ID > 0 AND ou.OrgNode.IsDescendantOf(b.OrgNode) = 1
            )
            SELECT DISTINCT
                RunGuid = @RunGuid,
                JobTypeGuid = jt.Guid,
                RowStatus = jt.RowStatus,
                Name = ISNULL(jt.Name, N''),
                IsActive = jt.IsActive,
                SequenceID = jt.SequenceID,
                UseTimeSheets = jt.UseTimeSheets,
                UsePlanChecks = jt.UsePlanChecks,
                OrganisationalUnitGuid = ou.Guid
            FROM SJob.JobTypes AS jt
            INNER JOIN StageOU AS ou ON ou.ID = jt.OrganisationalUnitID
            WHERE jt.RowStatus NOT IN (0,254) AND jt.ID > 0 AND jt.Guid <> '00000000-0000-0000-0000-000000000000';
            """),
        new("SMigration.Onboarding_ActivityTypes", """
            ;WITH StageOU AS
            (
                SELECT ou.ID
                FROM SCore.OrganisationalUnits AS ou
                CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b
                WHERE ou.RowStatus NOT IN (0,254) AND ou.ID > 0 AND ou.OrgNode.IsDescendantOf(b.OrgNode) = 1
            ), StageJobTypes AS
            (
                SELECT jt.ID FROM SJob.JobTypes AS jt INNER JOIN StageOU AS ou ON ou.ID = jt.OrganisationalUnitID WHERE jt.RowStatus NOT IN (0,254) AND jt.ID > 0
            )
            SELECT DISTINCT
                RunGuid = @RunGuid,
                ActivityTypeGuid = at.Guid,
                RowStatus = at.RowStatus,
                Name = ISNULL(at.Name, N''),
                IsActive = at.IsActive,
                SortOrder = at.SortOrder,
                IsFeeTrigger = at.IsFeeTrigger,
                IsLiveTrigger = at.IsLiveTrigger,
                IsAdmin = at.IsAdmin,
                IsScheduleItem = at.IsScheduleItem,
                Colour = ISNULL(at.Colour, N''),
                IsMeeting = at.IsMeeting,
                IsSiteVisit = at.IsSiteVisit,
                IsBillable = at.IsBillable,
                IsCommencementTrigger = at.IsCommencementTrigger
            FROM SJob.ActivityTypes AS at
            INNER JOIN SJob.JobTypeActivityTypes AS jtat ON jtat.ActivityTypeID = at.ID AND jtat.RowStatus NOT IN (0,254)
            INNER JOIN StageJobTypes AS jt ON jt.ID = jtat.JobTypeID
            WHERE at.RowStatus NOT IN (0,254) AND at.ID > 0 AND at.Guid <> '00000000-0000-0000-0000-000000000000';
            """),
        new("SMigration.Onboarding_MilestoneTypes", """
            ;WITH StageOU AS
            (
                SELECT ou.ID FROM SCore.OrganisationalUnits AS ou CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b WHERE ou.RowStatus NOT IN (0,254) AND ou.ID > 0 AND ou.OrgNode.IsDescendantOf(b.OrgNode) = 1
            ), StageJobTypes AS
            (
                SELECT jt.ID FROM SJob.JobTypes AS jt INNER JOIN StageOU AS ou ON ou.ID = jt.OrganisationalUnitID WHERE jt.RowStatus NOT IN (0,254) AND jt.ID > 0
            )
            SELECT DISTINCT
                RunGuid = @RunGuid,
                MilestoneTypeGuid = mt.Guid,
                RowStatus = mt.RowStatus,
                Code = ISNULL(mt.Code, N''),
                Name = ISNULL(mt.Name, N''),
                IsActive = mt.IsActive,
                IsInvoiceTrigger = mt.IsInvoiceTrigger,
                IsReviewRequired = mt.IsReviewRequired,
                HelpText = ISNULL(mt.HelpText, N''),
                HasQuotedHours = mt.HasQuotedHours,
                HasDescription = mt.HasDescription,
                HasReference = mt.HasReference,
                IsCompulsory = mt.IsCompulsory,
                IncludeStart = mt.IncludeStart,
                IncludeSchedule = mt.IncludeSchedule,
                IncludeDueDate = mt.IncludeDueDate,
                HasExternalSubmission = mt.HasExternalSubmission
            FROM SJob.MilestoneTypes AS mt
            INNER JOIN SJob.JobTypeMilestoneTemplates AS jtmt ON jtmt.MilestoneTypeID = mt.ID AND jtmt.RowStatus NOT IN (0,254)
            INNER JOIN StageJobTypes AS jt ON jt.ID = jtmt.JobTypeID
            WHERE mt.RowStatus NOT IN (0,254) AND mt.ID > 0 AND mt.Guid <> '00000000-0000-0000-0000-000000000000';
            """),
        new("SMigration.Onboarding_JobTypeActivityTypes", """
            ;WITH StageOU AS (SELECT ou.ID FROM SCore.OrganisationalUnits AS ou CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b WHERE ou.RowStatus NOT IN (0,254) AND ou.ID > 0 AND ou.OrgNode.IsDescendantOf(b.OrgNode) = 1),
            StageJobTypes AS (SELECT jt.ID FROM SJob.JobTypes AS jt INNER JOIN StageOU AS ou ON ou.ID = jt.OrganisationalUnitID WHERE jt.RowStatus NOT IN (0,254) AND jt.ID > 0),
            StageActivityTypes AS (SELECT DISTINCT at.ID FROM SJob.ActivityTypes AS at INNER JOIN SJob.JobTypeActivityTypes AS jtat ON jtat.ActivityTypeID = at.ID AND jtat.RowStatus NOT IN (0,254) INNER JOIN StageJobTypes AS jt ON jt.ID = jtat.JobTypeID WHERE at.RowStatus NOT IN (0,254) AND at.ID > 0)
            SELECT DISTINCT
                RunGuid = @RunGuid,
                JobTypeActivityTypeGuid = jtat.Guid,
                RowStatus = jtat.RowStatus,
                JobTypeGuid = jt.Guid,
                ActivityTypeGuid = at.Guid
            FROM SJob.JobTypeActivityTypes AS jtat
            INNER JOIN SJob.JobTypes AS jt ON jt.ID = jtat.JobTypeID
            INNER JOIN SJob.ActivityTypes AS at ON at.ID = jtat.ActivityTypeID
            INNER JOIN StageJobTypes AS sjt ON sjt.ID = jt.ID
            INNER JOIN StageActivityTypes AS sat ON sat.ID = at.ID
            WHERE jtat.RowStatus NOT IN (0,254) AND jtat.ID > 0 AND jtat.Guid <> '00000000-0000-0000-0000-000000000000';
            """),
        new("SMigration.Onboarding_JobTypeMilestoneTemplates", """
            ;WITH StageOU AS (SELECT ou.ID FROM SCore.OrganisationalUnits AS ou CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b WHERE ou.RowStatus NOT IN (0,254) AND ou.ID > 0 AND ou.OrgNode.IsDescendantOf(b.OrgNode) = 1),
            StageJobTypes AS (SELECT jt.ID FROM SJob.JobTypes AS jt INNER JOIN StageOU AS ou ON ou.ID = jt.OrganisationalUnitID WHERE jt.RowStatus NOT IN (0,254) AND jt.ID > 0),
            StageMilestoneTypes AS (SELECT DISTINCT mt.ID FROM SJob.MilestoneTypes AS mt INNER JOIN SJob.JobTypeMilestoneTemplates AS jtmt ON jtmt.MilestoneTypeID = mt.ID AND jtmt.RowStatus NOT IN (0,254) INNER JOIN StageJobTypes AS jt ON jt.ID = jtmt.JobTypeID WHERE mt.RowStatus NOT IN (0,254) AND mt.ID > 0)
            SELECT DISTINCT
                RunGuid = @RunGuid,
                JobTypeMilestoneTemplateGuid = jtmt.Guid,
                RowStatus = jtmt.RowStatus,
                JobTypeGuid = jt.Guid,
                MilestoneTypeGuid = mt.Guid,
                Description = ISNULL(jtmt.Description, N''),
                SortOrder = jtmt.SortOrder
            FROM SJob.JobTypeMilestoneTemplates AS jtmt
            INNER JOIN SJob.JobTypes AS jt ON jt.ID = jtmt.JobTypeID
            INNER JOIN SJob.MilestoneTypes AS mt ON mt.ID = jtmt.MilestoneTypeID
            INNER JOIN StageJobTypes AS sjt ON sjt.ID = jt.ID
            INNER JOIN StageMilestoneTypes AS smt ON smt.ID = mt.ID
            WHERE jtmt.RowStatus NOT IN (0,254) AND jtmt.ID > 0 AND jtmt.Guid <> '00000000-0000-0000-0000-000000000000';
            """),
        new("SMigration.Onboarding_Products", """
            ;WITH StageOU AS (SELECT ou.ID FROM SCore.OrganisationalUnits AS ou CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b WHERE ou.RowStatus NOT IN (0,254) AND ou.ID > 0 AND ou.OrgNode.IsDescendantOf(b.OrgNode) = 1),
            StageJobTypes AS (SELECT jt.ID, jt.Guid FROM SJob.JobTypes AS jt INNER JOIN StageOU AS ou ON ou.ID = jt.OrganisationalUnitID WHERE jt.RowStatus NOT IN (0,254) AND jt.ID > 0)
            SELECT DISTINCT
                RunGuid = @RunGuid,
                ProductGuid = p.Guid,
                RowStatus = p.RowStatus,
                Code = ISNULL(p.Code, N''),
                Description = ISNULL(p.Description, N''),
                CreatedJobTypeGuid = jt.Guid,
                NeverConsolidate = p.NeverConsolidate,
                RibaStageGuid = rs.Guid
            FROM SProd.Products AS p
            INNER JOIN StageJobTypes AS jt ON jt.ID = p.CreatedJobType
            LEFT JOIN SJob.RibaStages AS rs ON rs.ID = p.RibaStageId
            WHERE p.ID > 0 AND p.RowStatus NOT IN (0,254) AND p.Guid <> '00000000-0000-0000-0000-000000000000';
            """),
        new("SMigration.Onboarding_ProductJobActivities", """
            ;WITH StageOU AS (SELECT ou.ID FROM SCore.OrganisationalUnits AS ou CROSS JOIN (SELECT OrgNode FROM SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) AS b WHERE ou.RowStatus NOT IN (0,254) AND ou.ID > 0 AND ou.OrgNode.IsDescendantOf(b.OrgNode) = 1),
            StageJobTypes AS (SELECT jt.ID FROM SJob.JobTypes AS jt INNER JOIN StageOU AS ou ON ou.ID = jt.OrganisationalUnitID WHERE jt.RowStatus NOT IN (0,254) AND jt.ID > 0),
            StageProducts AS (SELECT p.ID FROM SProd.Products AS p INNER JOIN StageJobTypes AS jt ON jt.ID = p.CreatedJobType WHERE p.ID > 0 AND p.RowStatus NOT IN (0,254)),
            StageJTAT AS (SELECT jtat.ID, jtat.Guid FROM SJob.JobTypeActivityTypes AS jtat INNER JOIN StageJobTypes AS jt ON jt.ID = jtat.JobTypeID WHERE jtat.RowStatus NOT IN (0,254) AND jtat.ID > 0),
            StageJTMT AS (SELECT jtmt.ID, jtmt.Guid FROM SJob.JobTypeMilestoneTemplates AS jtmt INNER JOIN StageJobTypes AS jt ON jt.ID = jtmt.JobTypeID WHERE jtmt.RowStatus NOT IN (0,254) AND jtmt.ID > 0)
            SELECT DISTINCT
                RunGuid = @RunGuid,
                ProductJobActivityGuid = pja.Guid,
                RowStatus = pja.RowStatus,
                ProductGuid = p.Guid,
                JobTypeActivityTypeGuid = jtat.Guid,
                ActivityTitle = ISNULL(pja.ActivityTitle, N''),
                OffsetDays = pja.OffsetDays,
                OffsetWeeks = pja.OffsetWeeks,
                OffsetMonths = pja.OffsetMonths,
                JobTypeMilestoneTemplateGuid = jtmt.Guid,
                PercentageOfProductValue = pja.PercentageOfProductValue
            FROM SJob.ProductJobActivities AS pja
            INNER JOIN SProd.Products AS p ON p.ID = pja.ProductId
            INNER JOIN StageProducts AS sp ON sp.ID = p.ID
            INNER JOIN StageJTAT AS jtat ON jtat.ID = pja.JobTypeActivityTypeId
            LEFT JOIN StageJTMT AS jtmt ON jtmt.ID = pja.JobTypeMilestoneTemplateId
            WHERE pja.RowStatus NOT IN (0,254) AND pja.ID > 0 AND pja.Guid <> '00000000-0000-0000-0000-000000000000';
            """)
    };
}
