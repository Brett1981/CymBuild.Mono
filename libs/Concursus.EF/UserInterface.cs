using Concursus.EF.Types;
using Microsoft.Data.SqlClient;

namespace Concursus.EF
{
    public class UserInterface
    {
        #region Private Fields

        private const string gridDefinitionUpsertStatement = "EXECUTE SUserInterface.GridDefinitionUpsert @Code = @Code, @Name = @Name, @PageUri = @PageUri, @TabName = @TabName, @ShowAsTiles = @ShowAsTiles, @Guid = @Guid, @ClearViews = @ClearViews, @Id = @Id OUT";

        private const string gridViewColumnDefinitionUpsertStatement = "EXECUTE SUserInterface.GridViewColumnDefinitionUpsert @Name = @Name, @ColumnOrder = @ColumnOrder, @Title = @Title, @GridViewDefinitionId = @GridViewDefinitionId, " +
            "@IsPrimaryKey = @IsPrimaryKey, @IsHidden = @IsHidden, @IsFiltered = @IsFiltered, @IsCombo = @IsCombo, @Guid = @Guid, @Id = @Id OUT";

        private const string gridViewDefinitionUpsertStatement = "EXECUTE SUserInterface.GridViewDefinitionUpsert @Code = @Code, @Name = @Name, @GridDefinitionId = @GridDefinitionId, @DetailPageUri = @DetailPageUri, @SqlQuery = @SqlQuery, " +
                            "@DefaultSortColumnName = @DefaultSortColumnName, @SecurableCode = @SecurableCode, @DisplayOrder = @DisplayOrder, @DisplayGroupName = @DisplayGroupName, @TileSqlQuery = @TileSqlQuery, " +
                    "@OnDataBoundFunction = @onDataBoundFunction, @Guid = @Guid, @Id = @Id OUT";

        #endregion Private Fields

        #region Public Methods

        public static async Task<List<DashboardMetric>> DashboardMetricsGet(Core entityFramework)
        {
            List<DashboardMetric> rsl = new();
            string sqlQuery;
            SqlConnection connection = null;

            try
            {
                connection = entityFramework.CreateConnection();
                await entityFramework.OpenConnectionAsync(connection);

                sqlQuery = "SELECT * FROM [SCore].[tvf_DashboardMetrics] (@UserId)";

                using (var command = QueryBuilder.CreateCommand(sqlQuery, connection))
                {
                    command.Parameters.Add(new SqlParameter("@UserId", await entityFramework.GetCurrentUserId(connection)));
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                DashboardMetric dm = new()
                                {
                                    Label = reader.GetString(reader.GetOrdinal("Label")),
                                    DisplayOrder = reader.GetInt32(reader.GetOrdinal("DisplayOrder")),
                                    DisplayGroupName = reader.GetString(reader.GetOrdinal("DisplayGroupName")),
                                    Min = reader.GetInt32(reader.GetOrdinal("Min")),
                                    Max = reader.GetInt32(reader.GetOrdinal("Max")),
                                    MinorUnit = reader.GetInt32(reader.GetOrdinal("MinorUnit")),
                                    MajorUnit = reader.GetInt32(reader.GetOrdinal("MajorUnit")),
                                    StartAngle = reader.GetInt32(reader.GetOrdinal("StartAngle")),
                                    EndAngle = reader.GetInt32(reader.GetOrdinal("EndAngle")),
                                    Reverse = reader.GetBoolean(reader.GetOrdinal("Reverse")),
                                    MetricTypeName = reader.GetString(reader.GetOrdinal("MetricTypeName")),
                                    MetricSqlQuery = reader.GetString(reader.GetOrdinal("MetricSqlQuery")),
                                    PageUri = reader.GetString(reader.GetOrdinal("PageUri")),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid"))
                                };

                                if (reader.GetDecimal(reader.GetOrdinal("Range1MinValue")) != 0)
                                {
                                    DashboardMetricRange dr = new()
                                    {
                                        MinValue = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("Range1MinValue"))),
                                        MaxValue = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("Range1MaxValue"))),
                                        ColourHex = reader.GetString(reader.GetOrdinal("Range1ColourHex"))
                                    };

                                    dm.Ranges.Add(dr);
                                }

                                if (reader.GetDecimal(reader.GetOrdinal("Range2MinValue")) != 0)
                                {
                                    DashboardMetricRange dr = new()
                                    {
                                        MinValue = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("Range2MinValue"))),
                                        MaxValue = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("Range2MaxValue"))),
                                        ColourHex = reader.GetString(reader.GetOrdinal("Range2ColourHex"))
                                    };

                                    dm.Ranges.Add(dr);
                                }

                                rsl.Add(dm);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting DashboardMetricsGet: {ex.Message}", ex);
                    }
                }

                foreach (DashboardMetric dm in rsl)
                {
                    var metricQuery = dm.MetricSqlQuery; // <— same as before, but no .Replace()
                    var userId = await entityFramework.GetCurrentUserId(connection);
                    var bound = Core.BindStandardTokens(metricQuery, userId, userId);
                    using (var command = QueryBuilder.CreateCommand(bound.Sql, connection))
                    {
                        command.Parameters.AddRange(QueryBuilder.CloneParams(bound.Params.ToArray()));
                        try
                        {
                            using (var reader = await command.ExecuteReaderAsync())
                            {
                                while (reader.Read())
                                {
                                    var dv = new DashboardMetricValue
                                    {
                                        Value = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("MetricValue1"))),
                                        ColourHex = reader.GetString(reader.GetOrdinal("Value1ColourHex"))
                                    };
                                    dm.Values.Add(dv);

                                    dv = new DashboardMetricValue
                                    {
                                        Value = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("MetricValue2"))),
                                        ColourHex = reader.GetString(reader.GetOrdinal("Value2ColourHex"))
                                    };
                                    dm.Values.Add(dv);

                                    dm.MetricSqlQuery = "";
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                            throw new Exception($"Exception occurred getting DashboardMetricsGet: {ex.Message}", ex);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                // Log or handle the exception as needed
                throw new Exception("Error occurred while fetching dashboard metrics: " + ex.Message, ex);
            }
            finally
            {
                if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                {
                    connection.Close();
                }
                connection?.Dispose();
            }

            return rsl;
        }

        public static async Task<DropDownDataListReply> DropDownDataList(Core entityFramework, DropDownDataListRequest request)
        {
            DropDownDataListReply result = new();
            SqlConnection? connection = null;

            try
            {
                connection = entityFramework.CreateConnection();
                await entityFramework.OpenConnectionAsync(connection);
                await QueryBuilder.SetReadCommittedAsync(connection);

                // [CBLD-570] -> Added ColourHexColumn
                const string statement = @"
            SELECT
                ddld.Code,
                ddld.SqlQuery,
                ddld.DefaultSortColumnName,
                ddld.NameColumn,
                ddld.ValueColumn,
                ddld.GroupColumn,
                ddld.ColourHexColumn
            FROM SUserInterface.DropDownListDefinitions ddld
            WHERE ddld.Guid = @Guid";

                using (var command = QueryBuilder.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@Guid", request.Guid));

                    // Read the drop-down definition
                    string dataSqlQuery = "";
                    string dataSortOrderColumn = "";
                    string dataNameColumn = "";
                    string dataValueColumn = "";
                    string dataGroupColumn = "";
                    string colourHexColumn = "";

                    try
                    {
                        using var reader = await command.ExecuteReaderAsync();
                        if (await reader.ReadAsync())
                        {
                            dataSqlQuery = reader.IsDBNull(reader.GetOrdinal("SqlQuery")) ? "" : reader.GetString(reader.GetOrdinal("SqlQuery"));
                            dataSortOrderColumn = reader.IsDBNull(reader.GetOrdinal("DefaultSortColumnName")) ? "" : reader.GetString(reader.GetOrdinal("DefaultSortColumnName"));
                            dataNameColumn = reader.IsDBNull(reader.GetOrdinal("NameColumn")) ? "" : reader.GetString(reader.GetOrdinal("NameColumn"));
                            dataValueColumn = reader.IsDBNull(reader.GetOrdinal("ValueColumn")) ? "" : reader.GetString(reader.GetOrdinal("ValueColumn"));
                            dataGroupColumn = reader.IsDBNull(reader.GetOrdinal("GroupColumn")) ? "" : reader.GetString(reader.GetOrdinal("GroupColumn"));
                            colourHexColumn = reader.IsDBNull(reader.GetOrdinal("ColourHexColumn")) ? "" : reader.GetString(reader.GetOrdinal("ColourHexColumn"));
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting DropDownDataList: {ex.Message}", ex);
                    }

                    if (!string.IsNullOrWhiteSpace(dataSqlQuery))
                    {
                        // Build WHERE / SORT
                        string sqlWhere = Core.DataObjectCompositeFilterListToPredicate(dataSqlQuery, request.Filters.ToList());
                        string sqlSort = !string.IsNullOrEmpty(dataSortOrderColumn) ? $" ORDER BY {dataSortOrderColumn} ASC " : "";

                        // Base (no trailing ORDER BY)
                        dataSqlQuery = Functions.StripPredicateFromQuery(dataSqlQuery);

                        // Compose final SQL
                        var userId = await entityFramework.GetCurrentUserId(connection);
                        var finalSql = dataSqlQuery + " " + sqlWhere;

                        // Add the union row ONLY if we actually have a selected value
                        if (request.CurrentSelectedValueGuid != Guid.Empty)
                        {
                            finalSql += $" UNION {dataSqlQuery} WHERE (root_hobt.Guid = @CurrentSelectedValueGuid)";
                        }

                        finalSql += sqlSort;

                        // Bind [[...]] tokens to @params
                        var bound = Core.BindStandardTokens(
                            finalSql,
                            currentUserId: userId,
                            userId: userId,
                            parentGuid: request.ParentGuid,
                            recordGuid: request.RecordGuid,
                            currentSelectedValueGuid: request.CurrentSelectedValueGuid);

                        using (var dataCommand = QueryBuilder.CreateCommand(bound.Sql, connection))
                        {
                            // Add token params
                            dataCommand.Parameters.AddRange(QueryBuilder.CloneParams(bound.Params.ToArray()));

                            // If SQL references direct params (like @CurrentSelectedValueGuid) that
                            // weren't added via tokens, add them now
                            void AddIfMissing(string name, object? value)
                            {
                                if (value is null) return;
                                if (dataCommand.CommandText.IndexOf(name, StringComparison.OrdinalIgnoreCase) >= 0 &&
                                    !dataCommand.Parameters.Contains(name))
                                {
                                    dataCommand.Parameters.Add(new SqlParameter(name, value));
                                }
                            }

                            AddIfMissing("@CurrentSelectedValueGuid", request.CurrentSelectedValueGuid == Guid.Empty ? null : request.CurrentSelectedValueGuid);
                            AddIfMissing("@ParentGuid", request.ParentGuid);
                            AddIfMissing("@RecordGuid", request.RecordGuid);
                            AddIfMissing("@UserId", userId);
                            AddIfMissing("@CURRENT_USER_ID", userId);

                            // Add filter params
                            dataCommand.Parameters.AddRange(Core.DataObjectCompositeFilterListToSqlParameterList(request.Filters).ToArray());

                            try
                            {
                                using var dataReader = await dataCommand.ExecuteReaderAsync();
                                while (await dataReader.ReadAsync())
                                {
                                    if (request.Guid.ToString().Equals("0031902a-b82c-4b50-9b3d-194a5d30b931", StringComparison.OrdinalIgnoreCase))
                                    {
                                        var item = new DropDownDataListItem
                                        {
                                            Name = dataReader.GetString(dataReader.GetOrdinal(dataNameColumn)),
                                            Value = dataReader.GetValue(dataReader.GetOrdinal(dataValueColumn)).ToString() ?? "",
                                            Group = !string.IsNullOrEmpty(dataGroupColumn)
                                                        ? (dataReader.IsDBNull(dataReader.GetOrdinal(dataGroupColumn)) ? "" : dataReader.GetString(dataReader.GetOrdinal(dataGroupColumn)))
                                                        : "",
                                            ColourHex = dataReader.GetString(dataReader.GetOrdinal("ColourHex")) ?? "" // your query must alias it as ColourHex when used
                                        };
                                        result.Items.Add(item);
                                    }
                                    else
                                    {
                                        var item = new DropDownDataListItem
                                        {
                                            Name = dataReader.GetString(dataReader.GetOrdinal(dataNameColumn)),
                                            Value = dataReader.GetValue(dataReader.GetOrdinal(dataValueColumn)).ToString() ?? "",
                                            Group = !string.IsNullOrEmpty(dataGroupColumn)
                                                        ? (dataReader.IsDBNull(dataReader.GetOrdinal(dataGroupColumn)) ? "" : dataReader.GetString(dataReader.GetOrdinal(dataGroupColumn)))
                                                        : ""
                                        };
                                        result.Items.Add(item);
                                    }
                                }
                            }
                            catch (Exception ex)
                            {
                                ex.Data["SQL"] = BuildSqlWithParams(dataCommand.CommandText, dataCommand.Parameters.Cast<SqlParameter>().ToArray());
                                throw new Exception($"Exception occurred getting DropDownDataList: {ex.Message}", ex);
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Error occurred while retrieving drop-down data list: {ex.Message}", ex);
            }
            finally
            {
                if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                    connection.Close();
                connection?.Dispose();
            }

            return result;
        }

        public static async Task<DropDownListDefinitionGetResponse> DropDownDataListDefinitionGet(Core entityFramework, Guid guid)
        {
            SqlConnection connection = null;
            try
            {
                connection = entityFramework.CreateConnection();
                await entityFramework.OpenConnectionAsync(connection);

                return await DropDownDataListDefinitionGet(connection, guid);
            }
            catch (Exception ex)
            {
                throw new Exception("Error occurred while retrieving drop-down list definition: " + ex.Message, ex);
            }
            finally
            {
                if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                {
                    connection.Close();
                }
                connection?.Dispose();
            }
        }

        public static async Task<DropDownListDefinitionGetResponse> DropDownDataListDefinitionGet(SqlConnection connection, Guid guid)
        {
            DropDownListDefinitionGetResponse rsl = new();

            try
            {
                string statement = "SELECT * " +
                    "FROM SUserInterface.DropDownListDefinitions ddld " +
                    "WHERE (ddld.Guid = @Guid)";

                using (var command = QueryBuilder.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("Guid", guid));
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                DropDownListDefinition dropDownListDefinition = new()
                                {
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                    Code = reader.GetString(reader.GetOrdinal("Code")),
                                    SqlQuery = reader.GetString(reader.GetOrdinal("SqlQuery")),
                                    DefaultSortColumnName = reader.GetString(reader.GetOrdinal("DefaultSortColumnName")),
                                    NameColumn = reader.GetString(reader.GetOrdinal("NameColumn")),
                                    ValueColumn = reader.GetString(reader.GetOrdinal("ValueColumn")),
                                    DetailPageUrl = reader.GetString(reader.GetOrdinal("DetailPageUrl")),
                                    IsDetailWindowed = reader.GetBoolean(reader.GetOrdinal("IsDetailWindowed")),
                                    InformationPageUrl = reader.GetString(reader.GetOrdinal("InformationPageUrl")),
                                    GroupColumn = reader.GetString(reader.GetOrdinal("GroupColumn")),
                                    ColourHexColumn = reader.GetString(reader.GetOrdinal("ColourHexColumn")) //CBLD-570
                                };

                                rsl.DropDownListDefinition = dropDownListDefinition;
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting DropDownDataListDefinitionGet: {ex.Message}", ex);
                    }
                }
            }
            catch (Exception ex)
            {
                throw new Exception("Error occurred while fetching data from the database: " + ex.Message, ex);
            }

            return rsl;
        }

        public static async Task<GridDefinition> GetGridDefinition(Core entityFramework, string code, bool forUi, bool forExport)
        {
            SqlConnection connection = null;
            try
            {
                connection = entityFramework.CreateConnection();
                await entityFramework.OpenConnectionAsync(connection);

                // Set to ReadCommitted for non-blocking reads
                await QueryBuilder.SetReadCommittedAsync(connection);

                return await GetGridDefinition(entityFramework, connection, code, forUi, forExport);
            }
            catch (Exception ex)
            {
                throw new Exception($"Error in GetGridDefinition for code {code}: {ex.Message}", ex);
            }
            finally
            {
                if (connection?.State != System.Data.ConnectionState.Closed)
                {
                    connection?.Close();
                }
                connection?.Dispose();
            }
        }

        public static async Task<GridDefinition> GetGridDefinition(Core entityFramework, SqlConnection connection, string code, bool forUi, bool forExport)
        {
            GridDefinition gd2 = new();

            try
            {
                // Optionally, set to ReadCommitted here for defensive safety
                await QueryBuilder.SetReadCommittedAsync(connection);

                string statement = "SELECT gd.Code, gd.Id, gd.Name, gd.PageUri, gd.TabName, gd.RowVersion, gd.ShowAsTiles " +
                                   "FROM SUserInterface.tvf_GridDefinitions(@GridCode, @UserId) gd";

                using (var command = QueryBuilder.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@GridCode", code));
                    command.Parameters.Add(new SqlParameter("@UserId", entityFramework.UserId));
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                gd2.Code = reader.GetString(reader.GetOrdinal("Code"));
                                gd2.Id = reader.GetInt32(reader.GetOrdinal("Id"));
                                gd2.Name = reader.GetString(reader.GetOrdinal("Name"));
                                gd2.PageUri = reader.GetString(reader.GetOrdinal("PageUri"));
                                gd2.TabName = reader.GetString(reader.GetOrdinal("TabName"));
                                gd2.RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion")));
                                gd2.ShowAsTiles = reader.GetBoolean(reader.GetOrdinal("ShowAsTiles"));
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting GetGridDefintions: {ex.Message}", ex);
                    }
                }

                if (forUi || forExport)
                {
                    await PopulateGridViewDefinitions(entityFramework, connection, gd2, forExport);
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Error in GetGridDefinition for code {code}: {ex.Message}", ex);
            }

            return gd2;
        }

        //OE: CBLD-265.
        public static async Task<List<GridViewAction>> GetGridViewActions(SqlConnection connection, string guid, int userId)
        {
            string statement = @"SELECT * FROM SUserInterface.tvf_ActionsForGridView(@Guid, @UserId)";
            List<GridViewAction> gridViewActions = new();

            try
            {
                // Set to ReadCommitted for non-blocking reads
                await QueryBuilder.SetReadCommittedAsync(connection);

                using (var command = QueryBuilder.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@Guid", guid));
                    command.Parameters.Add(new SqlParameter("@UserId", userId));
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                GridViewAction gridViewAction = new()
                                {
                                    Title = reader.GetString(reader.GetOrdinal("Title")),
                                    Statement = reader.GetString(reader.GetOrdinal("Statement")),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid"))
                                };

                                gridViewActions.Add(gridViewAction);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting GetGridViewActions: {ex.Message}", ex);
                    }
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Error in GetGridViewActions for Guid {guid}: {ex.Message}", ex);
            }

            return gridViewActions;
        }

        public static async Task<GridViewDefinition> GetGridViewDefinition(SqlConnection connection, int userId, int id = 0, string gridCode = "", string gridViewCode = "")
        {
            GridViewDefinition rsl = new();
            try
            {
                // Set isolation level to ReadCommitted for this connection/session
                await QueryBuilder.SetReadCommittedAsync(connection);

                string statement = "SELECT * FROM SUserInterface.tvf_GridViewDefinitions(@Id, @GridViewCode, @GridCode, @UserId)";

                using (var command = QueryBuilder.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@Id", id));
                    command.Parameters.Add(new SqlParameter("@GridCode", gridCode));
                    command.Parameters.Add(new SqlParameter("@GridViewCode", gridViewCode));
                    command.Parameters.Add(new SqlParameter("@UserId", userId));
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                rsl = new()
                                {
                                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                    Name = reader.GetString(reader.GetOrdinal("Name")),
                                    SqlQuery = reader.GetString(reader.GetOrdinal("SqlQuery"))
                                };
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting GetGridViewDefinition: {ex.Message}", ex);
                    }
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Error in GetGridViewDefinition for Id {id}: {ex.Message}", ex);
            }

            return rsl;
        }

        public static async Task<long> GetMetricData(Core entityFramework, string gridCode, string gridViewCode)
        {
            long result = 0;

            using (var connection = entityFramework.CreateConnection())
            {
                try
                {
                    await entityFramework.OpenConnectionAsync(connection);

                    // Set isolation level to ReadCommitted for this connection/session
                    await QueryBuilder.SetReadCommittedAsync(connection);

                    string statement = @"
        SELECT gvd.TileSqlQuery
        FROM SUserInterface.GridViewDefinitions gvd
        JOIN SUserInterface.GridDefinitions gd
          ON gvd.GridDefinitionId = gd.Id
        WHERE gvd.Code = @GridViewCode
          AND gd.Code = @GridCode";

                    using (var command = QueryBuilder.CreateCommand(statement, connection))
                    {
                        command.Parameters.Add(new SqlParameter("@GridViewCode", gridViewCode));
                        command.Parameters.Add(new SqlParameter("@GridCode", gridCode));
                        try
                        {
                            using (var reader = await command.ExecuteReaderAsync())
                            {
                                if (reader.Read())
                                {
                                    string sqlQuery = reader.GetString(reader.GetOrdinal("TileSqlQuery"));

                                    if (!string.IsNullOrEmpty(sqlQuery))
                                    {
                                        using (var command2 = QueryBuilder.CreateCommand(sqlQuery, connection))
                                        {
                                            object? scalarResult = await command2.ExecuteScalarAsync();
                                            result = scalarResult != null ? Convert.ToInt64(scalarResult) : 0;
                                        }
                                    }
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                            throw new Exception($"Exception occurred getting GetMetricData: {ex.Message}", ex);
                        }
                    }
                }
                catch (Exception ex)
                {
                    throw new Exception($"Error while getting metric data for GridCode: {gridCode} and GridViewCode: {gridViewCode}. Details: {ex.Message}", ex);
                }
                finally
                {
                    if (connection.State != System.Data.ConnectionState.Closed)
                    {
                        connection.Close();
                    }
                }
            }

            return result;
        }

        public static async Task<GridDataListReply> GridDataList(Core entityFramework, GridDataListRequest request, string UserOverride = "")
        {
            await Core.ValidateCompositeFilterList(request.Filters);

            var result = new GridDataListReply();
            SqlConnection? connection = null;

            try
            {
                connection = entityFramework.CreateConnection();
                await entityFramework.OpenConnectionAsync(connection);

                // Keep session at READ COMMITTED (pairs well with RCSI in Step 5)
                await QueryBuilder.SetReadCommittedAsync(connection);

                // 1) Get grid/view + columns
                GridViewDefinition gridViewDefinition = await GetGridViewDefinition(
                    connection, entityFramework.UserId, 0, request.GridCode, request.GridViewCode);

                if (string.IsNullOrEmpty(gridViewDefinition.SqlQuery))
                    throw new Exception("No query statement returned for the grid view.");

                string sqlQuery = gridViewDefinition.SqlQuery;
                List<GridViewColumnDefinition> columns =
                    (await GridViewColumnDefinitions(entityFramework, gridViewDefinition.Id)).ToList();
                (string Sql, List<SqlParameter> Params) boundBase;
                // 2) Replace tokens
                try
                {
                    int userId = await entityFramework.GetCurrentUserId(connection);
                    boundBase = Core.BindStandardTokens(
                                            sqlQuery,
                                            currentUserId: string.IsNullOrEmpty(UserOverride) ? userId : int.Parse(UserOverride),
                                            userId: string.IsNullOrEmpty(UserOverride) ? userId : int.Parse(UserOverride),
                                            parentGuid: request.ParentGuid,
                                            recordGuid: null
                                        );
                    sqlQuery = boundBase.Sql; // use SQL with @params; keep boundBase.Params for later
                }
                catch (Exception ex)
                {
                    throw new Exception($"Exception occurred replacing tokens in predicate: {ex.Message}", ex);
                }

                // 3) Build WHERE and SORT
                string sqlWhere = Core.DataObjectCompositeFilterListToPredicate(sqlQuery, request.Filters);
                // Use new overload so default sort comes from metadata instead of hardcoded ID
                // (Step 4)
                string sqlSort = BuildSortClause(request.Sort, columns, defaultSortColumnName: null);

                // Paginate
                if (request.PageSize > 0)
                {
                    sqlSort += $" OFFSET {request.PageSize * (request.Page - 1)} ROWS FETCH NEXT {request.PageSize} ROWS ONLY";
                }

                // Base (no WHERE)
                string baseSql = Functions.StripPredicateFromQuery(sqlQuery);
                baseSql = StripTrailingOrderBy(baseSql); // ensure no ORDER BY inside the derived table

                // 4) COUNT over derived table (robust & plan-safe)
                string countQuery = $@"
            SELECT COUNT_BIG(1)
            FROM (
                {baseSql} {sqlWhere}
            ) AS q
            OPTION (RECOMPILE)"; // avoids bad sniffed plans for ever-changing filters

                // build params once
                var tokenParams = QueryBuilder.CloneParams(boundBase.Params);
                var filterParams = Core.DataObjectCompositeFilterListToSqlParameterList(request.Filters).ToArray();

                using var countCommand = QueryBuilder.CreateCommand(countQuery, connection);
                countCommand.CommandTimeout = 120;
                countCommand.Parameters.AddRange(tokenParams);
                countCommand.Parameters.AddRange(filterParams);

                try
                {
                    var scalar = await QueryBuilderTiming.ExecuteScalarTimedAsync(countCommand, "GridDataList: COUNT");
                    result.TotalRows = Convert.ToInt32(scalar);
                }
                catch (Exception ex)
                {
                    // you can access the command here because it's in scope
                    ex.Data["SQL"] = BuildSqlWithParams(
                        countCommand.CommandText,
                        countCommand.Parameters.Cast<SqlParameter>().ToArray()
                    );
                    throw new Exception($"Exception occurred getting row count: {ex.Message}", ex);
                }

                // we already built baseSql above and removed any trailing ORDER BY

                string finalQuery = $"{baseSql} {sqlWhere} {sqlSort}";

                using (var command = QueryBuilder.CreateCommand(finalQuery, connection))
                {
                    // If you set CommandTimeout centrally, remove next line.
                    command.CommandTimeout = 120;
                    command.Parameters.AddRange(QueryBuilder.CloneParams(boundBase.Params));
                    command.Parameters.AddRange(Core.DataObjectCompositeFilterListToSqlParameterList(request.Filters).ToArray());

                    try
                    {
                        using (var reader = await QueryBuilderTiming.ExecuteReaderTimedAsync(command, "GridDataList: DataTable Final read"))

                        {
                            while (reader.Read())
                            {
                                var row = new GridDataRow();
                                foreach (var column in columns)
                                {
                                    var col = new GridDataColumn
                                    {
                                        Name = column.Name,
                                        Value = reader.GetValue(reader.GetOrdinal(column.Name)).ToString() ?? string.Empty
                                    };
                                    row.Columns.Add(col);
                                }
                                result.DataTable.Add(row);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting GridDataList: {ex.Message}", ex);
                    }
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"GridDataList failed: {ex.Message}", ex);
            }
            finally
            {
                if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                    connection.Close();
                connection?.Dispose();
            }

            return result;
        }

        public static async Task<List<GridViewColumnDefinition>> GridViewColumnDefinitions(Core entityFramework, int gridViewDefinitionId)
        {
            List<GridViewColumnDefinition> result = new();
            SqlConnection? connection = null;

            try
            {
                connection = entityFramework.CreateConnection();
                await entityFramework.OpenConnectionAsync(connection);

                // Set connection to ReadCommitted for all subsequent commands
                await QueryBuilder.SetReadCommittedAsync(connection);

                string statement = @"SELECT Id, Name, RowVersion, Guid, GridViewDefinitionId, Title,
                     IsCombo, IsFiltered, IsHidden, IsPrimaryKey, ColumnOrder,
                     DisplayFormat, Width, TopHeaderCategory, TopHeaderCategoryOrder
                     FROM SUserInterface.tvf_GridViewColumnDefinitions (@GridViewDefinitionId, @UserId) gvcd";

                using (var command = QueryBuilder.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@GridViewDefinitionId", gridViewDefinitionId));
                    command.Parameters.Add(new SqlParameter("@UserId", entityFramework.UserId));
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                GridViewColumnDefinition columnDefinition = new()
                                {
                                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                    Name = reader.GetString(reader.GetOrdinal("Name")),
                                    RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                                    GridViewDefinitionId = reader.GetInt32(reader.GetOrdinal("GridViewDefinitionId")),
                                    Title = reader.GetString(reader.GetOrdinal("Title")),
                                    IsCombo = reader.GetBoolean(reader.GetOrdinal("IsCombo")),
                                    IsFiltered = reader.GetBoolean(reader.GetOrdinal("IsFiltered")),
                                    IsHidden = reader.GetBoolean(reader.GetOrdinal("IsHidden")),
                                    IsPrimaryKey = reader.GetBoolean(reader.GetOrdinal("IsPrimaryKey")),
                                    ColumnOrder = reader.GetInt32(reader.GetOrdinal("ColumnOrder")),
                                    DisplayFormat = reader.GetString(reader.GetOrdinal("DisplayFormat")),
                                    Width = reader.GetString(reader.GetOrdinal("Width")),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                    TopHeaderCategory = reader.GetString(reader.GetOrdinal("TopHeaderCategory")),
                                    TopHeaderCategoryOrder = reader.GetInt32(reader.GetOrdinal("TopHeaderCategoryOrder"))
                                };

                                result.Add(columnDefinition);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting GridViewColumnDefinitions: {ex.Message}", ex);
                    }
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Error occurred in GridViewColumnDefinitions: {ex.Message}", ex);
            }
            finally
            {
                if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                {
                    connection.Close();
                }
                connection?.Dispose();
            }

            return result;
        }

        public static async Task<List<RecentItem>> RecentItemsGet(Core entityFramework, int UserId)
        {
            List<RecentItem> recentItems = new();
            SqlConnection? connection = null;

            try
            {
                connection = entityFramework.CreateConnection();
                await entityFramework.OpenConnectionAsync(connection);

                string sqlQuery = "SELECT TOP(10) * FROM [SCore].[tvf_RecentItems] (@UserId) ORDER BY DateTime DESC";

                using (var command = QueryBuilder.CreateCommand(sqlQuery, connection))
                {
                    command.Parameters.Add(new SqlParameter("@UserId", await entityFramework.GetCurrentUserId(connection)));
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                RecentItem item = new()
                                {
                                    Label = reader.GetString(reader.GetOrdinal("Label")),
                                    DateTime = reader.GetDateTime(reader.GetOrdinal("Datetime")),
                                    EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")),
                                    RecordGuid = reader.GetGuid(reader.GetOrdinal("RecordGuid")),
                                    DetailPageUri = reader.GetString(reader.GetOrdinal("DetailPageUrl")),
                                    EntityTypeLabel = reader.GetString(reader.GetOrdinal("EntityTypeLabel")),
                                };

                                recentItems.Add(item);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting RecentItemsGet: {ex.Message}", ex);
                    }
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Error occurred in RecentItemsGet: {ex.Message}", ex);
            }
            finally
            {
                if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                {
                    connection.Close();
                }
                connection?.Dispose();
            }

            return recentItems;
        }

        /// <summary>
        /// Returns the total and average for the automated invoicing KPI.
        /// </summary>
        /// <param name="entityFramework"></param>
        /// <param name="UserId"></param>
        /// <returns></returns>
        /// <exception cref="Exception"></exception>
        public static async Task<AutomatedInvoicingKPI> GetAutomatedInvoicingKPI(Core entityFramework)
        {
            AutomatedInvoicingKPI rsl = new();

           
            SqlConnection? connection = null;

            try
            {
                connection = entityFramework.CreateConnection();
                await entityFramework.OpenConnectionAsync(connection);

                string query = "SELECT * FROM [SFin].[tvf_AutomatedInvoicingKPI] (@UserId)";

                using (var command = QueryBuilder.CreateCommand(query, connection))
                {
                    command.Parameters.Add(new SqlParameter("@UserId", await entityFramework.GetCurrentUserId(connection)));
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                rsl = new()
                                {
                                    Average = (double) reader.GetDecimal(reader.GetOrdinal("Average")),
                                    Sum = (double) reader.GetDecimal(reader.GetOrdinal("Total")),
                                    NumberOfPaid = reader.GetInt32(reader.GetOrdinal("TotalPaid")),
                                    NumberOfPending = reader.GetInt32(reader.GetOrdinal("TotalPending")),
                                    NumberOfOverdue = reader.GetInt32(reader.GetOrdinal("TotalOverdue"))
                                };
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting Invoicing KPI: {ex.Message}", ex);
                    }
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Error occurred in Invoicing KPI: {ex.Message}", ex);
            }
            finally
            {
                if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                {
                    connection.Close();
                }
                connection?.Dispose();
            }

            return rsl;
        }


        //OE: CBLD-408
        public static async Task<WidgetLayoutGetResponse> WidgetLayoutGet(Core entityFramework, string userOverride = "")
        {
            WidgetLayoutGetResponse rsl = new();
            string query = "SELECT * FROM [SUserInterface].[tvf_WidgetDashBoardDefinitions] (@UserId)";
            SqlConnection? connection = null;

            try
            {
                connection = entityFramework.CreateConnection();
                await entityFramework.OpenConnectionAsync(connection);

                using (var command = QueryBuilder.CreateCommand(query, connection))
                {
                    //Check if the Appsettings has the userOverride set to a value -use that, otherwise get the current id.
                    if (string.IsNullOrWhiteSpace(userOverride))
                    {
                        command.Parameters.Add(new SqlParameter("@UserId", await entityFramework.GetCurrentUserId(connection)));
                    }
                    else if (Guid.TryParse(userOverride, out var userGuid))
                    {
                        command.Parameters.Add(new SqlParameter("@UserId", userGuid));
                    }
                    else
                    {
                        throw new Exception($"Invalid userOverride passed to WidgetLayoutGet: '{userOverride}' is not a valid GUID.");
                    }

                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                var type = reader.GetString(reader.GetOrdinal("Type"));

                                if (type == "WIDGETGRIDS")
                                {
                                    var gvd2 = new GridViewDefinitionForWidgets
                                    {
                                        Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                        Code = reader.GetString(reader.GetOrdinal("Code")),
                                        Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                        Name = reader.GetString(reader.GetOrdinal("Name")),
                                        RowVersion = reader.GetInt32(reader.GetOrdinal("RowVersion")).ToString(),
                                        GridDefinitionId = reader.GetInt32(reader.GetOrdinal("GridDefinitionId")),
                                        SqlQuery = reader.GetString(reader.GetOrdinal("SqlQuery")),
                                        DetailPageUri = reader.GetString(reader.GetOrdinal("DetailPageUri")),
                                        DefaultSortColumnName = reader.GetString(reader.GetOrdinal("DefaultSortColumnName")),
                                        DisplayGroupName = reader.GetString(reader.GetOrdinal("DisplayGroupName")),
                                        DisplayOrder = reader.GetInt32(reader.GetOrdinal("DisplayOrder")),
                                        MetricSqlQuery = reader.GetString(reader.GetOrdinal("MetricSqlQuery")),
                                        ShowMetric = reader.GetInt32(reader.GetOrdinal("ShowMetric")) == 1,
                                        IsDetailWindowed = reader.GetInt32(reader.GetOrdinal("IsDetailWindowed")) == 1,
                                        EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")),
                                        DrawerIconCss = reader.GetString(reader.GetOrdinal("DrawerIconCss")),
                                        AllowNew = false, // To block the "New" button from appearing.
                                        AllowExcelExport = reader.GetInt32(reader.GetOrdinal("AllowExcelExport")) == 1,
                                        AllowCsvExport = reader.GetInt32(reader.GetOrdinal("AllowCsvExport")) == 1,
                                        AllowPdfExport = reader.GetInt32(reader.GetOrdinal("AllowPdfExport")) == 1,
                                        IsDefaultSortDescending = reader.GetInt32(reader.GetOrdinal("IsDefaultSortDescending")) == 1,
                                        GridViewTypeId = reader.GetInt32(reader.GetOrdinal("GridViewTypeId")),
                                        GridViewCode = reader.GetString(reader.GetOrdinal("GridCode"))
                                    };

                                    rsl.GridViewDefinitions.Add(gvd2);
                                }
                                else if (type == "WIDGETGAUGES")
                                {
                                    var dm = new DashboardMetricForWidgets
                                    {
                                        Label = reader.GetString(reader.GetOrdinal("Name")),
                                        DisplayOrder = reader.GetInt32(reader.GetOrdinal("DisplayOrder")),
                                        DisplayGroupName = reader.GetString(reader.GetOrdinal("DisplayGroupName")),
                                        Min = reader.GetInt32(reader.GetOrdinal("Min")),
                                        Max = reader.GetInt32(reader.GetOrdinal("Max")),
                                        MinorUnit = reader.GetInt32(reader.GetOrdinal("MinorUnit")),
                                        MajorUnit = reader.GetInt32(reader.GetOrdinal("MajorUnit")),
                                        StartAngle = reader.GetInt32(reader.GetOrdinal("StartAngle")),
                                        EndAngle = reader.GetInt32(reader.GetOrdinal("EndAngle")),
                                        Reverse = reader.GetInt32(reader.GetOrdinal("Reverse")) == 1,
                                        MetricTypeName = reader.GetString(reader.GetOrdinal("MetricTypeName")),
                                        MetricSqlQuery = reader.GetString(reader.GetOrdinal("GaugeMetricSqlQuery")),
                                        PageUri = reader.GetString(reader.GetOrdinal("PageUri")),
                                        Guid = reader.GetGuid(reader.GetOrdinal("MetricGuid")),
                                        Code = reader.GetString(reader.GetOrdinal("GridCode")),
                                        GridViewCode = reader.GetString(reader.GetOrdinal("Code"))
                                    };

                                    AddDashboardMetricRanges(dm, reader);
                                    rsl.DashboardMetrics.Add(dm);
                                }
                                else if (type == "WIDGETLAYOUT")
                                {
                                    rsl.WidgetLayout = reader.GetString(reader.GetOrdinal("Name"));
                                }
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting WidgetLayoutGet: {ex.Message}", ex);
                    }
                }

                await PopulateDashboardMetricValues(entityFramework, connection, rsl.DashboardMetrics);
            }
            catch (Exception ex)
            {
                // Log or handle exception as needed
                throw new Exception($"WidgetLayoutGet failed: {ex.Message}", ex);
            }
            finally
            {
                if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                {
                    connection.Close();
                }
                connection?.Dispose();
            }

            return rsl;
        }

        #endregion Public Methods

        #region Private Methods

        // Helper to add ranges
        private static void AddDashboardMetricRanges(DashboardMetricForWidgets dm, SqlDataReader reader)
        {
            if (reader.GetDecimal(reader.GetOrdinal("Range1MinValue")) != 0)
            {
                dm.Ranges.Add(new DashboardMetricRange
                {
                    MinValue = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("Range1MinValue"))),
                    MaxValue = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("Range1MaxValue"))),
                    ColourHex = reader.GetString(reader.GetOrdinal("Range1ColourHex"))
                });
            }

            if (reader.GetDecimal(reader.GetOrdinal("Range2MinValue")) != 0)
            {
                dm.Ranges.Add(new DashboardMetricRange
                {
                    MinValue = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("Range2MinValue"))),
                    MaxValue = Decimal.ToDouble(reader.GetOrdinal("Range2MaxValue")),
                    ColourHex = reader.GetString(reader.GetOrdinal("Range2ColourHex"))
                });
            }
        }

        // Back-compat: keep old signature; route to the smarter one
        private static string BuildSortClause(IEnumerable<DataSort> sorts)
            => BuildSortClause(sorts, columns: null, defaultSortColumnName: null);

        // New, smarter overload
        private static string BuildSortClause(
            IEnumerable<DataSort> sorts,
            List<GridViewColumnDefinition>? columns,
            string? defaultSortColumnName)
        {
            string sqlSort = "ORDER BY";

            // 1) Use explicit sorts if provided
            foreach (var sort in sorts ?? Enumerable.Empty<DataSort>())
            {
                if (!string.IsNullOrEmpty(sort.ColumnName))
                {
                    if (sqlSort != "ORDER BY") sqlSort += ", ";
                    sqlSort += $" [{sort.ColumnName}] {(sort.Direction == "Ascending" ? "ASC" : "DESC")}";
                }
            }

            if (sqlSort != "ORDER BY") return sqlSort;

            // 2) No explicit sorts → choose a safe, indexed default
            string? fallback = null;

            if (!string.IsNullOrWhiteSpace(defaultSortColumnName))
            {
                fallback = defaultSortColumnName;
            }
            else if (columns != null && columns.Any())
            {
                // Prefer PK column if available
                var pk = columns.FirstOrDefault(c => c.IsPrimaryKey);
                if (pk != null) fallback = pk.Name;
                else
                {
                    // If a column literally named ID exists, use it; else leave null
                    if (columns.Any(c => string.Equals(c.Name, "ID", StringComparison.OrdinalIgnoreCase)))
                        fallback = "ID";
                }
            }

            return !string.IsNullOrWhiteSpace(fallback)
                ? $"ORDER BY [{fallback}] ASC"
                : "ORDER BY 1"; // last-resort deterministic order
        }

        private static string BuildSqlWithParams(string query, SqlParameter[] parameters)
        {
            var formattedParams = parameters
                .Select(p => $"@{p.ParameterName} = '{p.Value}'")
                .ToArray();

            return $"{query}\nParams:\n{string.Join("\n", formattedParams)}";
        }

        // Helper to populate metric values
        private static async Task PopulateDashboardMetricValues(Core entityFramework, SqlConnection connection, List<DashboardMetricForWidgets> metrics)
        {
            // Always set isolation to ReadCommitted for this connection/session
            await QueryBuilder.SetReadCommittedAsync(connection);

            foreach (var dm in metrics)
            {
                string metricQuery = dm.MetricSqlQuery.Replace("[[UserId]]", (await entityFramework.GetCurrentUserId(connection)).ToString());

                using (var command = QueryBuilder.CreateCommand(metricQuery, connection))
                {
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                dm.Values.Add(new DashboardMetricValue
                                {
                                    Value = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("MetricValue1"))),
                                    ColourHex = reader.GetString(reader.GetOrdinal("Value1ColourHex"))
                                });

                                dm.Values.Add(new DashboardMetricValue
                                {
                                    Value = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("MetricValue2"))),
                                    ColourHex = reader.GetString(reader.GetOrdinal("Value2ColourHex"))
                                });
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting PopulateDashboardMetricValues: {ex.Message}", ex);
                    }
                }

                dm.MetricSqlQuery = "";
            }
        }

        private static async Task PopulateGridViewColumnDefinitions(Core entityFramework, SqlConnection connection, GridDefinition gd2, bool forExport)
        {
            // Set isolation for the session
            await QueryBuilder.SetReadCommittedAsync(connection);

            string statement = "SELECT Id, Name, RowVersion, GridViewDefinitionId, Title, IsCombo, IsFiltered, IsHidden, IsPrimaryKey, ColumnOrder, DisplayFormat, Width, TopHeaderCategory, TopHeaderCategoryOrder " +
                               "FROM SUserInterface.tvf_GridViewColumnDefinitions(@GridViewDefinitionId, @UserId)";

            foreach (GridViewDefinition gvd in gd2.Views)
            {
                using (var command = QueryBuilder.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@GridViewDefinitionId", gvd.Id));
                    command.Parameters.Add(new SqlParameter("@UserId", entityFramework.UserId));
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                GridViewColumnDefinition gvcd2 = new()
                                {
                                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                    ColumnOrder = reader.GetInt32(reader.GetOrdinal("ColumnOrder")),
                                    Name = reader.GetString(reader.GetOrdinal("Name")),
                                    Title = reader.GetString(reader.GetOrdinal("Title")),
                                    IsPrimaryKey = reader.GetBoolean(reader.GetOrdinal("IsPrimaryKey")),
                                    IsHidden = reader.GetBoolean(reader.GetOrdinal("IsHidden")),
                                    IsFiltered = reader.GetBoolean(reader.GetOrdinal("IsFiltered")),
                                    IsCombo = reader.GetBoolean(reader.GetOrdinal("IsCombo")),
                                    Width = reader.GetString(reader.GetOrdinal("Width")),
                                    DisplayFormat = reader.GetString(reader.GetOrdinal("DisplayFormat")),
                                    TopHeaderCategory = reader.GetString(reader.GetOrdinal("TopHeaderCategory")),
                                    TopHeaderCategoryOrder = reader.GetInt32(reader.GetOrdinal("TopHeaderCategoryOrder"))
                                };

                                if (forExport)
                                {
                                    gvcd2.GridViewDefinitionId = reader.GetInt32(reader.GetOrdinal("GridViewDefinitionId"));
                                }

                                gvd.Columns.Add(gvcd2);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting PopulateGridViewColumnDefinitions: {ex.Message}", ex);
                    }
                }
            }
        }

        private static async Task PopulateGridViewDefinitions(Core entityFramework, SqlConnection connection, GridDefinition gd2, bool forExport)
        {
            // Set isolation for the session
            await QueryBuilder.SetReadCommittedAsync(connection);

            string statement = "SELECT * FROM SUserInterface.tvf_GridViewDefinitions(@Id, @GridViewCode, @GridCode, @UserId)";

            using (var command = QueryBuilder.CreateCommand(statement, connection))
            {
                int id = 0;
                command.Parameters.Add(new SqlParameter("@Id", id));
                command.Parameters.Add(new SqlParameter("@GridViewCode", ""));
                command.Parameters.Add(new SqlParameter("@GridCode", gd2.Code));
                command.Parameters.Add(new SqlParameter("@UserId", entityFramework.UserId));
                try
                {
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            GridViewDefinition gvd2 = new()
                            {
                                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                Code = reader.GetString(reader.GetOrdinal("Code")),
                                Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                Name = reader.GetString(reader.GetOrdinal("Name")),
                                RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                                GridDefinitionId = reader.GetInt32(reader.GetOrdinal("GridDefinitionId")),
                                SqlQuery = reader.GetString(reader.GetOrdinal("SqlQuery")),
                                DetailPageUri = reader.GetString(reader.GetOrdinal("DetailPageUri")),
                                DefaultSortColumnName = reader.GetString(reader.GetOrdinal("DefaultSortColumnName")),
                                DisplayGroupName = reader.GetString(reader.GetOrdinal("DisplayGroupName")),
                                DisplayOrder = reader.GetInt32(reader.GetOrdinal("DisplayOrder")),
                                MetricSqlQuery = reader.GetString(reader.GetOrdinal("MetricSqlQuery")),
                                ShowMetric = reader.GetBoolean(reader.GetOrdinal("ShowMetric")),
                                IsDetailWindowed = reader.GetBoolean(reader.GetOrdinal("IsDetailWindowed")),
                                EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")),
                                DrawerIconCss = reader.GetString(reader.GetOrdinal("DrawerIconCss")),
                                AllowNew = reader.GetBoolean(reader.GetOrdinal("AllowNew")),
                                AllowExcelExport = reader.GetBoolean(reader.GetOrdinal("AllowExcelExport")),
                                AllowCsvExport = reader.GetBoolean(reader.GetOrdinal("AllowCsvExport")),
                                AllowPdfExport = reader.GetBoolean(reader.GetOrdinal("AllowPdfExport")),
                                IsDefaultSortDescending = reader.GetBoolean(reader.GetOrdinal("IsDefaultSortDescending")),
                                GridViewTypeId = reader.GetInt32(reader.GetOrdinal("GridViewTypeId")),
                                AllowBulkChange = reader.GetBoolean(reader.GetOrdinal("AllowBulkChange")),
                                ShowOnMobile = reader.GetBoolean(reader.GetOrdinal("ShowOnMobile")),
                                TreeListFirstOrderBy = reader.GetString(reader.GetOrdinal("TreeListFirstOrderBy")),
                                TreeListSecondOrderBy = reader.GetString(reader.GetOrdinal("TreeListSecondOrderBy")),
                                TreeListThirdOrderBy = reader.GetString(reader.GetOrdinal("TreeListThirdOrderBy")),
                                TreeListGroupBy = reader.GetString(reader.GetOrdinal("TreeListGroupBy")),
                                TreeListOrderBy = reader.GetString(reader.GetOrdinal("TreeListOrderBy")),
                                FilteredListCreatedOnColumn = reader.GetString(reader.GetOrdinal("FilteredListCreatedOnColumn")),
                                FilteredListGroupBy = reader.GetString(reader.GetOrdinal("FilteredListGroupBy")),
                                FilteredListRedStatusIndicatorTxt = reader.GetString(reader.GetOrdinal("FilteredListRedStatusIndicatorTxt")),
                                FilteredListOrangeStatusIndicatorTxt = reader.GetString(reader.GetOrdinal("FilteredListOrangeStatusIndicatorTxt")),
                                FilteredListGreenStatusIndicatorTxt = reader.GetString(reader.GetOrdinal("FilteredListGreenStatusIndicatorTxt"))
                            };
                            if (forExport)
                            {
                                gvd2.GridDefinitionId = reader.GetInt32(reader.GetOrdinal("GridDefinitionId"));
                                gvd2.SqlQuery = reader.GetString(reader.GetOrdinal("SqlQuery"));
                                gvd2.MetricSqlQuery = reader.GetString(reader.GetOrdinal("MetricSqlQuery"));
                            }

                            gd2.Views.Add(gvd2);
                        }
                    }
                }
                catch (Exception ex)
                {
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting PopulateGridViewDefinitions: {ex.Message}", ex);
                }
            }

            foreach (var gvd in gd2.Views)
            {
                if (gvd.GridViewTypeId == 2)
                {
                    gvd.GridViewActions = await GetGridViewActions(connection, gvd.Guid.ToString(), entityFramework.UserId);
                }
            }

            await PopulateGridViewColumnDefinitions(entityFramework, connection, gd2, forExport);
        }

        /// <summary>
        /// Removes a trailing ORDER BY (if present) from a SQL text. Keep it simple: we only care
        /// about a final ORDER BY for generated queries.
        /// </summary>
        private static string StripTrailingOrderBy(string sql)
        {
            if (string.IsNullOrWhiteSpace(sql)) return sql;
            int idx = sql.LastIndexOf("ORDER BY", StringComparison.OrdinalIgnoreCase);
            return (idx > -1) ? sql.Substring(0, idx) : sql;
        }

        #endregion Private Methods
    }
}