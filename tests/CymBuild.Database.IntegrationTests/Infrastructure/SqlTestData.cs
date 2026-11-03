using System.Data;

namespace CymBuild.Database.IntegrationTests.Infrastructure;

internal sealed record NonActivityFixture(
    Guid AbsenceTypeGuid,
    short TeamId,
    short MemberId,
    Guid CreatedByUserGuid,
    Guid FirstStatusGuid,
    Guid SecondStatusGuid);

internal static class SqlTestData
{
    internal static async Task<NonActivityFixture> ReadNonActivityFixtureAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
SELECT
    (SELECT TOP (1) nat.Guid
     FROM SCore.NonActivityTypes AS nat
     WHERE nat.RowStatus NOT IN (0, 254)
       AND nat.Guid IS NOT NULL
     ORDER BY nat.ID) AS AbsenceTypeGuid,
    (SELECT TOP (1) CONVERT(SMALLINT, g.ID)
     FROM SCore.Groups AS g
     WHERE g.RowStatus NOT IN (0, 254)
       AND TRY_CONVERT(SMALLINT, g.ID) IS NOT NULL
     ORDER BY CASE WHEN g.ID = -1 THEN 0 ELSE 1 END, g.ID) AS TeamId,
    (SELECT TOP (1) CONVERT(SMALLINT, i.ID)
     FROM SCore.Identities AS i
     WHERE i.RowStatus NOT IN (0, 254)
       AND TRY_CONVERT(SMALLINT, i.ID) IS NOT NULL
       AND i.Guid IS NOT NULL
     ORDER BY CASE WHEN i.ID = -1 THEN 0 ELSE 1 END, i.ID) AS MemberId,
    (SELECT TOP (1) i.Guid
     FROM SCore.Identities AS i
     WHERE i.RowStatus NOT IN (0, 254)
       AND i.Guid IS NOT NULL
     ORDER BY CASE WHEN i.ID = -1 THEN 0 ELSE 1 END, i.ID) AS CreatedByUserGuid;
""";

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        Assert.True(await reader.ReadAsync(cancellationToken), "The SQL fixture query did not return a row.");

        Assert.False(reader.IsDBNull(0), "No active SCore.NonActivityTypes row is available in the dedicated test database.");
        Assert.False(reader.IsDBNull(1), "No SCore.Groups ID compatible with the production SMALLINT procedure parameter is available.");
        Assert.False(reader.IsDBNull(2), "No SCore.Identities ID compatible with the production SMALLINT procedure parameter is available.");
        Assert.False(reader.IsDBNull(3), "No active identity GUID is available for workflow transition tests.");

        var absenceTypeGuid = reader.GetGuid(0);
        var teamId = reader.GetInt16(1);
        var memberId = reader.GetInt16(2);
        var createdByUserGuid = reader.GetGuid(3);
        await reader.DisposeAsync();

        const string statusSql = """
SELECT TOP (2) ws.Guid
FROM SCore.WorkflowStatus AS ws
WHERE ws.RowStatus NOT IN (0, 254)
  AND ws.Guid IS NOT NULL
  AND ws.Guid <> '00000000-0000-0000-0000-000000000000'
ORDER BY ws.ID;
""";

        var statuses = new List<Guid>(capacity: 2);
        await using var statusCommand = SqlTestDatabase.CreateCommand(connection, transaction, statusSql);
        await using var statusReader = await statusCommand.ExecuteReaderAsync(cancellationToken);
        while (await statusReader.ReadAsync(cancellationToken))
        {
            statuses.Add(statusReader.GetGuid(0));
        }

        Assert.True(statuses.Count >= 2, "At least two active workflow statuses are required in the dedicated test database.");

        return new NonActivityFixture(
            absenceTypeGuid,
            teamId,
            memberId,
            createdByUserGuid,
            statuses[0],
            statuses[1]);
    }

    internal static async Task ExecuteNonActivityEventUpsertAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        NonActivityFixture fixture,
        Guid recordGuid,
        DateTime startTime,
        DateTime endTime,
        CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@AbsenceTypeGuid", SqlDbType.UniqueIdentifier) { Value = fixture.AbsenceTypeGuid },
            new SqlParameter("@StartTime", SqlDbType.DateTime) { Value = startTime },
            new SqlParameter("@EndTime", SqlDbType.DateTime) { Value = endTime },
            new SqlParameter("@TeamId", SqlDbType.SmallInt) { Value = fixture.TeamId },
            new SqlParameter("@MemberId", SqlDbType.SmallInt) { Value = fixture.MemberId },
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = recordGuid }
        };

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SCore.NonActivityEventsUpsert",
            parameters,
            CommandType.StoredProcedure);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    internal static async Task ExecuteTransitionUpsertAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid transitionGuid,
        Guid oldStatusGuid,
        Guid statusGuid,
        string comment,
        Guid createdByUserGuid,
        Guid dataObjectGuid,
        CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = transitionGuid },
            new SqlParameter("@OldStatusGuid", SqlDbType.UniqueIdentifier) { Value = oldStatusGuid },
            new SqlParameter("@StatusGuid", SqlDbType.UniqueIdentifier) { Value = statusGuid },
            new SqlParameter("@Comment", SqlDbType.NVarChar, -1) { Value = comment },
            new SqlParameter("@CreatedByUserGuid", SqlDbType.UniqueIdentifier) { Value = createdByUserGuid },
            new SqlParameter("@SurveyorUserGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Empty },
            new SqlParameter("@DataObjectGuid", SqlDbType.UniqueIdentifier) { Value = dataObjectGuid },
            new SqlParameter("@IsImported", SqlDbType.Bit) { Value = false }
        };

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SCore.DataObjectTransitionUpsert",
            parameters,
            CommandType.StoredProcedure);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    internal static async Task ExecuteUpsertDataObjectAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid guid,
        string schemeName,
        string objectName,
        CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = guid },
            new SqlParameter("@SchemeName", SqlDbType.NVarChar, 255) { Value = schemeName },
            new SqlParameter("@ObjectName", SqlDbType.NVarChar, 255) { Value = objectName },
            new SqlParameter("@IncludeDefaultSecurity", SqlDbType.Bit) { Value = true },
            new SqlParameter("@IsInsert", SqlDbType.Bit) { Direction = ParameterDirection.Output }
        };

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SCore.UpsertDataObject",
            parameters,
            CommandType.StoredProcedure);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    internal sealed record JobClosureFixture(
        short AuthoriserIdentityId,
        int OrganisationalUnitId,
        Guid ClosureRequestStatusGuid,
        Guid ApproveClosureStatusGuid,
        Guid CompletedStatusGuid,
        Guid ClosureRejectedStatusGuid);

    internal static async Task<JobClosureFixture> ReadJobClosureFixtureAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        CancellationToken cancellationToken = default)
    {
        const string identitySql = """
SELECT TOP (1) CONVERT(SMALLINT, i.ID)
FROM SCore.Identities AS i
WHERE i.RowStatus NOT IN (0, 254)
  AND i.Guid = 'D4D00004-0000-4000-8000-000000000001';
""";
        object? identityId;
        await using (var identityCommand = SqlTestDatabase.CreateCommand(connection, transaction, identitySql))
        {
            identityId = await identityCommand.ExecuteScalarAsync(cancellationToken);
        }
        Assert.False(identityId is null or DBNull, "The R4 identity fixture is required for Job closure tests.");

        const string orgUnitSql = """
SELECT TOP (1) ou.ID
FROM SCore.OrganisationalUnits AS ou
WHERE ou.RowStatus NOT IN (0, 254)
  AND ou.Name = N'CymBuild R4 Test OrgUnit';
""";
        object? orgUnitId;
        await using (var orgUnitCommand = SqlTestDatabase.CreateCommand(connection, transaction, orgUnitSql))
        {
            orgUnitId = await orgUnitCommand.ExecuteScalarAsync(cancellationToken);
        }
        Assert.False(orgUnitId is null or DBNull, "The R4 OrganisationalUnit fixture is required for Job closure tests.");

        return new JobClosureFixture(
            Convert.ToInt16(identityId, System.Globalization.CultureInfo.InvariantCulture),
            Convert.ToInt32(orgUnitId, System.Globalization.CultureInfo.InvariantCulture),
            Guid.Parse("5ED9C55A-4E14-44F6-A106-AE0F5C5EC38D"),
            Guid.Parse("E6776DB3-812F-4328-B81E-FEFD494EA049"),
            Guid.Parse("20D22623-283B-4088-9CEB-D944AC3E6516"),
            Guid.Parse("48507119-2F28-490C-83A6-CE8F85E5AF7F"));
    }

    internal static async Task InsertJobFixtureAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid jobGuid,
        JobClosureFixture fixture,
        string jobNumber,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
INSERT INTO SJob.Jobs (RowStatus, Guid, Number, SurveyorID, JobDescription, BillingInstruction, OrganisationalUnitId)
VALUES (1, @Guid, @Number, @SurveyorID, @JobDescription, @BillingInstruction, @OrganisationalUnitId);
""";
        var parameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = jobGuid },
            new SqlParameter("@Number", SqlDbType.NVarChar, 50) { Value = jobNumber },
            new SqlParameter("@SurveyorID", SqlDbType.Int) { Value = (int)fixture.AuthoriserIdentityId },
            new SqlParameter("@JobDescription", SqlDbType.NVarChar, 1000) { Value = "R4 Job closure decision test" },
            new SqlParameter("@BillingInstruction", SqlDbType.NVarChar, -1) { Value = "R4 test billing instruction" },
            new SqlParameter("@OrganisationalUnitId", SqlDbType.Int) { Value = fixture.OrganisationalUnitId }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await command.ExecuteNonQueryAsync(cancellationToken);

        await ExecuteUpsertDataObjectAsync(connection, transaction, jobGuid, "SJob", "Jobs", cancellationToken);
    }

    internal sealed record JobClosureDecisionResult(string StoredComment, DateTime DecisionDateTimeUtc);

    internal static async Task<JobClosureDecisionResult> ExecuteJobClosureDecisionAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid jobGuid,
        short authoriserUserId,
        byte decision,
        string? comment,
        CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid },
            new SqlParameter("@AuthoriserUserId", SqlDbType.Int) { Value = (int)authoriserUserId },
            new SqlParameter("@Decision", SqlDbType.TinyInt) { Value = decision },
            new SqlParameter("@Comment", SqlDbType.NVarChar, 2000) { Value = (object?)comment ?? DBNull.Value },
            new SqlParameter("@StoredComment", SqlDbType.NVarChar, 2000) { Direction = ParameterDirection.Output },
            new SqlParameter("@DecisionDateTimeUtc", SqlDbType.DateTime2) { Direction = ParameterDirection.Output }
        };

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SJob.usp_JobClosureDecision",
            parameters,
            CommandType.StoredProcedure);
        await command.ExecuteNonQueryAsync(cancellationToken);

        return new JobClosureDecisionResult(
            (string)parameters[4].Value,
            (DateTime)parameters[5].Value);
    }

    internal static async Task<int> ReadActiveAccountIdAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
SELECT TOP (1) a.ID
FROM SCrm.Accounts AS a
WHERE a.RowStatus NOT IN (0, 254)
ORDER BY a.ID;
""";

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql);
        var accountId = await command.ExecuteScalarAsync(cancellationToken);
        Assert.False(accountId is null or DBNull, "At least one active SCrm.Accounts row is required in the dedicated test database.");

        return Convert.ToInt32(accountId, System.Globalization.CultureInfo.InvariantCulture);
    }

    internal sealed record TransactionFixture(long TransactionId, Guid TransactionGuid);

    /// <summary>
    /// Inserts a minimal active SFin.Transactions row (plus one SFin.TransactionDetails
    /// line, required by SFin.Transaction_InvoiceMergeInfo's inner join) and registers
    /// the matching SCore.DataObjects row, mirroring InsertJobFixtureAsync's pattern.
    /// </summary>
    internal static async Task<TransactionFixture> InsertTransactionFixtureAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        int accountId,
        string reservedInvoiceNumber,
        string? sageInvoiceNumber = null,
        string? sageSalesOrderNumber = null,
        string? sageTransactionReference = null,
        CancellationToken cancellationToken = default)
    {
        var transactionGuid = Guid.NewGuid();

        const string insertTransactionSql = """
INSERT INTO SFin.Transactions
    (RowStatus, Guid, AccountID, ReservedInvoiceNumber, SageInvoiceNumber, SageSalesOrderNumber, SageTransactionReference)
OUTPUT INSERTED.ID
VALUES
    (1, @Guid, @AccountID, @ReservedInvoiceNumber, @SageInvoiceNumber, @SageSalesOrderNumber, @SageTransactionReference);
""";
        var transactionParameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = transactionGuid },
            new SqlParameter("@AccountID", SqlDbType.Int) { Value = accountId },
            new SqlParameter("@ReservedInvoiceNumber", SqlDbType.NVarChar, 30) { Value = reservedInvoiceNumber },
            new SqlParameter("@SageInvoiceNumber", SqlDbType.NVarChar, 50) { Value = (object?)sageInvoiceNumber ?? DBNull.Value },
            new SqlParameter("@SageSalesOrderNumber", SqlDbType.NVarChar, 50) { Value = (object?)sageSalesOrderNumber ?? DBNull.Value },
            new SqlParameter("@SageTransactionReference", SqlDbType.NVarChar, 50) { Value = (object?)sageTransactionReference ?? string.Empty }
        };

        await using var insertCommand = SqlTestDatabase.CreateCommand(connection, transaction, insertTransactionSql, transactionParameters);
        var transactionId = Convert.ToInt64(
            await insertCommand.ExecuteScalarAsync(cancellationToken),
            System.Globalization.CultureInfo.InvariantCulture);

        const string insertDetailSql = """
INSERT INTO SFin.TransactionDetails (RowStatus, TransactionID, Description, Net, Vat, Gross)
VALUES (1, @TransactionID, @Description, @Net, @Vat, @Gross);
""";
        var detailParameters = new[]
        {
            new SqlParameter("@TransactionID", SqlDbType.BigInt) { Value = transactionId },
            new SqlParameter("@Description", SqlDbType.NVarChar, 2000) { Value = "CYB-501 fixture line" },
            new SqlParameter("@Net", SqlDbType.Decimal) { Value = 100m },
            new SqlParameter("@Vat", SqlDbType.Decimal) { Value = 20m },
            new SqlParameter("@Gross", SqlDbType.Decimal) { Value = 120m }
        };

        await using var detailCommand = SqlTestDatabase.CreateCommand(connection, transaction, insertDetailSql, detailParameters);
        await detailCommand.ExecuteNonQueryAsync(cancellationToken);

        await ExecuteUpsertDataObjectAsync(connection, transaction, transactionGuid, "SFin", "Transactions", cancellationToken);

        return new TransactionFixture(transactionId, transactionGuid);
    }

    internal static async Task ExecuteTransactionSageInvoiceDetailsUpsertAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid transactionGuid,
        string? sageInvoiceNumber,
        string? sageSalesOrderNumber,
        CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier) { Value = transactionGuid },
            new SqlParameter("@SageInvoiceNumber", SqlDbType.NVarChar, 50) { Value = (object?)sageInvoiceNumber ?? DBNull.Value },
            new SqlParameter("@SageSalesOrderNumber", SqlDbType.NVarChar, 50) { Value = (object?)sageSalesOrderNumber ?? DBNull.Value },
            new SqlParameter("@UpdatedByUserID", SqlDbType.Int) { Value = -1 }
        };

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SFin.TransactionSageInvoiceDetails_Upsert",
            parameters,
            CommandType.StoredProcedure);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    internal static async Task<long> InsertTransactionSageSubmissionStatusAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        long transactionId,
        Guid transactionGuid,
        string statusCode,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
INSERT INTO SFin.TransactionSageSubmissionStatus (RowStatus, TransactionID, TransactionGuid, StatusCode)
OUTPUT INSERTED.ID
VALUES (1, @TransactionID, @TransactionGuid, @StatusCode);
""";
        var parameters = new[]
        {
            new SqlParameter("@TransactionID", SqlDbType.BigInt) { Value = transactionId },
            new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier) { Value = transactionGuid },
            new SqlParameter("@StatusCode", SqlDbType.NVarChar, 30) { Value = statusCode }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        return Convert.ToInt64(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);
    }

    internal static async Task<string> ReadTransactionSageSubmissionStatusCodeAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        long statusId,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
SELECT StatusCode
FROM SFin.TransactionSageSubmissionStatus
WHERE ID = @ID;
""";
        var parameters = new[] { new SqlParameter("@ID", SqlDbType.BigInt) { Value = statusId } };
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        return (string)(await command.ExecuteScalarAsync(cancellationToken) ?? string.Empty);
    }

    /// <summary>
    /// Inserts a minimal SJob.Jobs stub row (ClientAccountID/ProjectId default to -1, so the
    /// JOINs inside SCore.IntegrationOutbox_EnqueueJobCreatedFromProposal resolve to no match)
    /// and registers the matching SCore.DataObjects row.
    /// </summary>
    internal static async Task<int> InsertMinimalJobAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid jobGuid,
        string jobNumber,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
INSERT INTO SJob.Jobs (RowStatus, Guid, Number, SurveyorID, JobDescription)
OUTPUT INSERTED.ID
VALUES (1, @Guid, @Number, -1, N'R4 outbox test job');
""";
        var parameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = jobGuid },
            new SqlParameter("@Number", SqlDbType.NVarChar, 50) { Value = jobNumber }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        var jobId = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);

        await ExecuteUpsertDataObjectAsync(connection, transaction, jobGuid, "SJob", "Jobs", cancellationToken);

        return jobId;
    }

    internal sealed record MinimalQuote(int QuoteId, Guid QuoteGuid);

    /// <summary>
    /// Inserts a minimal SSop.Quotes stub row (EnquiryServiceID defaults to -1; this slice does
    /// not test the Enquiry/Quote upsert chain, only the QuoteItems -> Job outbox trigger).
    /// </summary>
    internal static async Task<MinimalQuote> InsertMinimalQuoteAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        string quoteNumber,
        CancellationToken cancellationToken = default)
    {
        var quoteGuid = Guid.NewGuid();
        const string sql = """
INSERT INTO SSop.Quotes (RowStatus, Guid, EnquiryServiceID, Number)
OUTPUT INSERTED.ID
VALUES (1, @Guid, -1, @Number);
""";
        var parameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = quoteGuid },
            new SqlParameter("@Number", SqlDbType.NVarChar, 50) { Value = quoteNumber }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        var quoteId = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);

        return new MinimalQuote(quoteId, quoteGuid);
    }

    internal static async Task<int> InsertQuoteItemAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        int quoteId,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
INSERT INTO SSop.QuoteItems (RowStatus, QuoteId, CreatedJobId)
OUTPUT INSERTED.ID
VALUES (1, @QuoteId, NULL);
""";
        var parameters = new[] { new SqlParameter("@QuoteId", SqlDbType.Int) { Value = quoteId } };
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// Fires SSop.tr_QuoteItems_EnqueueJobCreatedFromProposal (CreatedJobId moving from
    /// unset to a real Job ID), which enqueues a JobCreatedFromProposal outbox row.
    /// </summary>
    internal static async Task SetQuoteItemCreatedJobIdAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        int quoteItemId,
        int jobId,
        CancellationToken cancellationToken = default)
    {
        const string sql = "UPDATE SSop.QuoteItems SET CreatedJobId = @JobId WHERE ID = @QuoteItemId;";
        var parameters = new[]
        {
            new SqlParameter("@JobId", SqlDbType.Int) { Value = jobId },
            new SqlParameter("@QuoteItemId", SqlDbType.Int) { Value = quoteItemId }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    internal sealed record JobCreatedFromProposalOutboxRow(Guid? JobGuid, Guid? QuoteGuid, string? EventType);

    internal static async Task<JobCreatedFromProposalOutboxRow?> ReadJobCreatedFromProposalOutboxRowAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid jobGuid,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
SELECT TOP (1)
    TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(PayloadJson, '$.jobGuid')),
    TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(PayloadJson, '$.quoteGuid')),
    JSON_VALUE(PayloadJson, '$.eventType')
FROM SCore.IntegrationOutbox
WHERE EventType = N'JobCreatedFromProposal'
  AND RowStatus NOT IN (0, 254)
  AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(PayloadJson, '$.jobGuid')) = @JobGuid;
""";
        var parameters = new[] { new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid } };
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return new JobCreatedFromProposalOutboxRow(
            reader.IsDBNull(0) ? null : reader.GetGuid(0),
            reader.IsDBNull(1) ? null : reader.GetGuid(1),
            reader.IsDBNull(2) ? null : reader.GetString(2));
    }

    internal sealed record QuoteJobsSummaryFixture(Guid QuoteGuid, int QuoteId, int ProductId);

    /// <summary>
    /// Builds the minimal chain of rows SSop.Quote_JobsSummary inner-joins through
    /// (RibaStages, Products, Contracts, JobTypes, OrganisationalUnits, Enquiries,
    /// EnquiryServices, Quotes), for CYB-553. RibaStages ID 2 is created explicitly via
    /// IDENTITY_INSERT because SSop.Quote_JobsSummary, SJob.Job_FeeDrawdown, and
    /// SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems all hardcode the literal RibaStages
    /// ID 2 as the "ProvideAtStageID = -1" (no stage set) fallback target - this fixture
    /// must match that literal exactly, not just create "a" stage row.
    /// </summary>
    internal static async Task<QuoteJobsSummaryFixture> InsertQuoteJobsSummaryFixtureAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        CancellationToken cancellationToken = default)
    {
        const string ribaStageSql = """
SET IDENTITY_INSERT SJob.RibaStages ON;
IF NOT EXISTS (SELECT 1 FROM SJob.RibaStages WHERE ID = 1)
BEGIN
    INSERT INTO SJob.RibaStages (ID, RowStatus, Number, Description, IsRealStage)
    VALUES (1, 1, 1, N'CYB-553 R4 test stage 1', 1);
END;
IF NOT EXISTS (SELECT 1 FROM SJob.RibaStages WHERE ID = 2)
BEGIN
    INSERT INTO SJob.RibaStages (ID, RowStatus, Number, Description, IsRealStage)
    VALUES (2, 1, 2, N'CYB-553 R4 test stage 2', 1);
END;
SET IDENTITY_INSERT SJob.RibaStages OFF;
""";
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, ribaStageSql))
        {
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        const string productSql = """
INSERT INTO SProd.Products (RowStatus, Code, Description)
OUTPUT INSERTED.ID
VALUES (1, N'', N'CYB-553 R4 test product');
""";
        int productId;
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, productSql))
        {
            productId = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);
        }

        const string contractSql = "INSERT INTO SSop.Contracts (RowStatus) OUTPUT INSERTED.ID VALUES (1);";
        int contractId;
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, contractSql))
        {
            contractId = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);
        }

        const string jobTypeSql = """
INSERT INTO SJob.JobTypes (RowStatus, Name)
OUTPUT INSERTED.ID
VALUES (1, @Name);
""";
        int jobTypeId;
        var jobTypeParameters = new[]
        {
            new SqlParameter("@Name", SqlDbType.NVarChar, 50) { Value = $"CYB-553 R4 JobType {Guid.NewGuid():N}" }
        };
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, jobTypeSql, jobTypeParameters))
        {
            jobTypeId = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);
        }

        const string orgUnitSql = """
INSERT INTO SCore.OrganisationalUnits (RowStatus, Name)
OUTPUT INSERTED.ID
VALUES (1, N'CYB-553 R4 test OrgUnit');
""";
        int orgUnitId;
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, orgUnitSql))
        {
            orgUnitId = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);
        }

        var enquiryGuid = Guid.NewGuid();
        const string enquirySql = """
INSERT INTO SSop.Enquiries (RowStatus, Guid, CurrentProjectRibaStageID)
OUTPUT INSERTED.ID
VALUES (1, @Guid, 2);
""";
        int enquiryId;
        var enquiryParameters = new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = enquiryGuid } };
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, enquirySql, enquiryParameters))
        {
            enquiryId = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);
        }

        var enquiryServiceGuid = Guid.NewGuid();
        const string enquiryServiceSql = """
INSERT INTO SSop.EnquiryServices (RowStatus, Guid, EnquiryId, JobTypeId)
OUTPUT INSERTED.ID
VALUES (1, @Guid, @EnquiryId, @JobTypeId);
""";
        int enquiryServiceId;
        var enquiryServiceParameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = enquiryServiceGuid },
            new SqlParameter("@EnquiryId", SqlDbType.Int) { Value = enquiryId },
            new SqlParameter("@JobTypeId", SqlDbType.Int) { Value = jobTypeId }
        };
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, enquiryServiceSql, enquiryServiceParameters))
        {
            enquiryServiceId = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);
        }

        var quoteGuid = Guid.NewGuid();
        const string quoteSql = """
INSERT INTO SSop.Quotes
    (RowStatus, Guid, EnquiryServiceID, OrganisationalUnitID, ContractID, AgentContractID, AppointmentFromRibaStageId)
OUTPUT INSERTED.ID
VALUES (1, @Guid, @EnquiryServiceId, @OrgUnitId, @ContractId, @ContractId, 2);
""";
        int quoteId;
        var quoteParameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = quoteGuid },
            new SqlParameter("@EnquiryServiceId", SqlDbType.Int) { Value = enquiryServiceId },
            new SqlParameter("@OrgUnitId", SqlDbType.Int) { Value = orgUnitId },
            new SqlParameter("@ContractId", SqlDbType.Int) { Value = contractId }
        };
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, quoteSql, quoteParameters))
        {
            quoteId = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);
        }

        return new QuoteJobsSummaryFixture(quoteGuid, quoteId, productId);
    }

    /// <summary>
    /// Inserts a single SSop.QuoteItems + SSop.QuoteItemTotals row against a
    /// InsertQuoteJobsSummaryFixtureAsync fixture. CreatedJobId = -1 mirrors
    /// SSop.Quote_JobsSummary's "job not yet created" filter.
    /// </summary>
    internal static async Task<int> InsertQuoteJobsSummaryQuoteItemAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        int quoteId,
        int productId,
        int provideAtStageId,
        decimal lineNet,
        CancellationToken cancellationToken = default)
    {
        const string quoteItemSql = """
INSERT INTO SSop.QuoteItems (RowStatus, QuoteId, CreatedJobId, ProvideAtStageID, ProductId, Quantity)
OUTPUT INSERTED.ID
VALUES (1, @QuoteId, -1, @ProvideAtStageID, @ProductId, 1);
""";
        var quoteItemParameters = new[]
        {
            new SqlParameter("@QuoteId", SqlDbType.Int) { Value = quoteId },
            new SqlParameter("@ProvideAtStageID", SqlDbType.Int) { Value = provideAtStageId },
            new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId }
        };

        int quoteItemId;
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, quoteItemSql, quoteItemParameters))
        {
            quoteItemId = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);
        }

        const string quoteItemTotalSql = "INSERT INTO SSop.QuoteItemTotals (ID, LineNet) VALUES (@ID, @LineNet);";
        var quoteItemTotalParameters = new[]
        {
            new SqlParameter("@ID", SqlDbType.Int) { Value = quoteItemId },
            new SqlParameter("@LineNet", SqlDbType.Decimal) { Value = lineNet }
        };
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, quoteItemTotalSql, quoteItemTotalParameters))
        {
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        return quoteItemId;
    }

    internal sealed record QuoteJobsSummaryRow(decimal Net, decimal AgreedFee, decimal RibaStage1Fee, decimal RibaStage2Fee);

    internal static async Task<QuoteJobsSummaryRow?> ReadQuoteJobsSummaryRowAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid quoteGuid,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
SELECT
    Net,
    AgreedFee,
    RibaStage1Fee,
    RibaStage2Fee
FROM SSop.Quote_JobsSummary
WHERE QuoteGuid = @QuoteGuid;
""";
        var parameters = new[] { new SqlParameter("@QuoteGuid", SqlDbType.UniqueIdentifier) { Value = quoteGuid } };
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        var row = new QuoteJobsSummaryRow(
            reader.GetDecimal(0),
            reader.GetDecimal(1),
            reader.GetDecimal(2),
            reader.GetDecimal(3));

        Assert.False(await reader.ReadAsync(cancellationToken), "Expected exactly one SSop.Quote_JobsSummary row for the test QuoteGuid.");

        return row;
    }

    internal static async Task<long> CountJobCreatedFromProposalOutboxRowsAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        Guid jobGuid,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
SELECT COUNT_BIG(1)
FROM SCore.IntegrationOutbox
WHERE EventType = N'JobCreatedFromProposal'
  AND RowStatus NOT IN (0, 254)
  AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(PayloadJson, '$.jobGuid')) = @JobGuid;
""";
        var parameters = new[] { new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid } };
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        return (long)(await command.ExecuteScalarAsync(cancellationToken) ?? 0L);
    }

    /// <summary>
    /// Ensures the given SJob.RibaStages IDs exist (IDENTITY_INSERT, idempotent), for tests that
    /// need stages beyond the 1 and 2 that InsertQuoteJobsSummaryFixtureAsync creates.
    /// </summary>
    internal static async Task EnsureRibaStagesAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        IEnumerable<int> ribaStageIds,
        CancellationToken cancellationToken = default)
    {
        foreach (var ribaStageId in ribaStageIds)
        {
            const string sql = """
SET IDENTITY_INSERT SJob.RibaStages ON;
IF NOT EXISTS (SELECT 1 FROM SJob.RibaStages WHERE ID = @ID)
BEGIN
    INSERT INTO SJob.RibaStages (ID, RowStatus, Number, Description, IsRealStage)
    VALUES (@ID, 1, @ID, N'R4 test stage', 1);
END;
SET IDENTITY_INSERT SJob.RibaStages OFF;
""";
            var parameters = new[] { new SqlParameter("@ID", SqlDbType.Int) { Value = ribaStageId } };
            await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
            await command.ExecuteNonQueryAsync(cancellationToken);
        }
    }

    internal static async Task<int> InsertInvoiceScheduleAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        int quoteId,
        string name,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
INSERT INTO SFin.InvoiceSchedules (RowStatus, Name, QuoteId)
OUTPUT INSERTED.ID
VALUES (1, @Name, @QuoteId);
""";
        var parameters = new[]
        {
            new SqlParameter("@Name", SqlDbType.NVarChar, 50) { Value = name },
            new SqlParameter("@QuoteId", SqlDbType.Int) { Value = quoteId }
        };
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);
    }

    internal static async Task InsertInvoiceScheduleMonthConfigurationAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        int invoiceScheduleId,
        int periodNumber,
        decimal amount,
        int ribaStageId,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
INSERT INTO SFin.InvoiceScheduleMonthConfiguration (RowStatus, InvoiceScheduleId, PeriodNumber, Amount, RIBAStageId)
VALUES (1, @InvoiceScheduleId, @PeriodNumber, @Amount, @RibaStageId);
""";
        var parameters = new[]
        {
            new SqlParameter("@InvoiceScheduleId", SqlDbType.Int) { Value = invoiceScheduleId },
            new SqlParameter("@PeriodNumber", SqlDbType.Int) { Value = periodNumber },
            new SqlParameter("@Amount", SqlDbType.Decimal) { Value = amount, Precision = 19, Scale = 2 },
            new SqlParameter("@RibaStageId", SqlDbType.Int) { Value = ribaStageId }
        };
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    /// <summary>
    /// Inserts a SSop.QuoteItems + SSop.QuoteItemTotals row that has already created the given
    /// Job - the input SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems reads.
    /// </summary>
    internal static async Task<int> InsertCreatedQuoteItemAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        int quoteId,
        int productId,
        int createdJobId,
        int provideAtStageId,
        int invoicingScheduleId,
        decimal lineNet,
        int sortOrder,
        CancellationToken cancellationToken = default)
    {
        const string quoteItemSql = """
INSERT INTO SSop.QuoteItems (RowStatus, QuoteId, CreatedJobId, ProvideAtStageID, ProductId, Quantity, InvoicingSchedule, SortOrder)
OUTPUT INSERTED.ID
VALUES (1, @QuoteId, @CreatedJobId, @ProvideAtStageID, @ProductId, 1, @InvoicingSchedule, @SortOrder);
""";
        var quoteItemParameters = new[]
        {
            new SqlParameter("@QuoteId", SqlDbType.Int) { Value = quoteId },
            new SqlParameter("@CreatedJobId", SqlDbType.Int) { Value = createdJobId },
            new SqlParameter("@ProvideAtStageID", SqlDbType.Int) { Value = provideAtStageId },
            new SqlParameter("@ProductId", SqlDbType.Int) { Value = productId },
            new SqlParameter("@InvoicingSchedule", SqlDbType.Int) { Value = invoicingScheduleId },
            new SqlParameter("@SortOrder", SqlDbType.Int) { Value = sortOrder }
        };

        int quoteItemId;
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, quoteItemSql, quoteItemParameters))
        {
            quoteItemId = Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken), System.Globalization.CultureInfo.InvariantCulture);
        }

        const string quoteItemTotalSql = "INSERT INTO SSop.QuoteItemTotals (ID, LineNet) VALUES (@ID, @LineNet);";
        var quoteItemTotalParameters = new[]
        {
            new SqlParameter("@ID", SqlDbType.Int) { Value = quoteItemId },
            new SqlParameter("@LineNet", SqlDbType.Decimal) { Value = lineNet, Precision = 19, Scale = 2 }
        };
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, quoteItemTotalSql, quoteItemTotalParameters))
        {
            await command.ExecuteNonQueryAsync(cancellationToken);
        }

        return quoteItemId;
    }

    internal static async Task ExecuteJobRibaStageFeesUpsertFromCreatedQuoteItemsAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        int jobId,
        CancellationToken cancellationToken = default)
    {
        const string sql = "EXEC SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems @JobID = @JobID;";
        var parameters = new[] { new SqlParameter("@JobID", SqlDbType.Int) { Value = jobId } };
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    internal sealed record JobRibaStageFeeRow(int RibaStageId, long CreatedFromQuoteItemId, decimal AgreedFee);

    internal static async Task<IReadOnlyList<JobRibaStageFeeRow>> ReadActiveJobRibaStageFeesAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        int jobId,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
SELECT
    RibaStageID,
    CreatedFromQuoteItemID,
    AgreedFee
FROM SJob.JobRibaStageFees
WHERE JobID = @JobID
  AND RowStatus NOT IN (0, 254)
ORDER BY RibaStageID;
""";
        var parameters = new[] { new SqlParameter("@JobID", SqlDbType.Int) { Value = jobId } };
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var rows = new List<JobRibaStageFeeRow>();
        while (await reader.ReadAsync(cancellationToken))
        {
            rows.Add(new JobRibaStageFeeRow(reader.GetInt32(0), reader.GetInt64(1), reader.GetDecimal(2)));
        }

        return rows;
    }
}
