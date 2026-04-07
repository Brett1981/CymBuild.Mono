using Azure.Core;
using Grpc.Core;
using Microsoft.Data.SqlClient;
using Microsoft.Graph.Identity.B2xUserFlows.Item.Languages.Item.OverridesPages;
using Microsoft.Graph.Models;
using Concursus.API.Core;
using Concursus.API.Enums;
using Concursus.API.Services;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using System.Threading.Tasks;

namespace Concursus.API.EntityFramework
{
    internal class UserInterface
    {
        private const string gridDefinitionUpsertStatement = "EXECUTE SUserInterface.GridDefinitionUpsert @Code = @Code, @Name = @Name, @PageUri = @PageUri, @TabName = @TabName, @ShowAsTiles = @ShowAsTiles, @Guid = @Guid, @ClearViews = @ClearViews, @Id = @Id OUT";
        private const string gridViewDefinitionUpsertStatement = "EXECUTE SUserInterface.GridViewDefinitionUpsert @Code = @Code, @Name = @Name, @GridDefinitionId = @GridDefinitionId, @DetailPageUri = @DetailPageUri, @SqlQuery = @SqlQuery, " +
                    "@DefaultSortColumnName = @DefaultSortColumnName, @SecurableCode = @SecurableCode, @DisplayOrder = @DisplayOrder, @DisplayGroupName = @DisplayGroupName, @TileSqlQuery = @TileSqlQuery, " +
                    "@OnDataBoundFunction = @onDataBoundFunction, @Guid = @Guid, @Id = @Id OUT";
        private const string gridViewColumnDefinitionUpsertStatement = "EXECUTE SUserInterface.GridViewColumnDefinitionUpsert @Name = @Name, @ColumnOrder = @ColumnOrder, @Title = @Title, @GridViewDefinitionId = @GridViewDefinitionId, " +
            "@IsPrimaryKey = @IsPrimaryKey, @IsHidden = @IsHidden, @IsFiltered = @IsFiltered, @IsCombo = @IsCombo, @Guid = @Guid, @Id = @Id OUT";

        public static async Task<long> GetMetricData(Core entityFramework, string gridCode, string gridViewCode)
        {
            long rsl = new();

            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                string statement = "SELECT gvd.TileSqlQuery " +
                    "FROM SUserInterface.GridViewDefinitions gvd " +
                    "JOIN   SUserInterface.GridDefinitions gd on (gvd.GridDefinitionId = gd.Id)" +
                    "WHERE  (gvd.Code = @GridViewCode) " +
                "   AND (gd.Code = @GridCode)";

                using (var command = entityFramework.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("GridViewCode", gridViewCode));
                    command.Parameters.Add(new SqlParameter("GridCode", gridCode));

                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            string sqlQuery = reader.GetString(reader.GetOrdinal("TileSqlQuery"));

                            using (var command2 = entityFramework.CreateCommand(sqlQuery, connection))
                            {
                                using (var reader2 = await command2.ExecuteReaderAsync())
                                {
                                    rsl = long.Parse(command2.ExecuteScalar().ToString() ?? "0");
                                }
                            }
                        }
                    }
                }
            }            

            return rsl;
        }

        public static async Task<GridDefinition> GetGridDefinition(Core entityFramework, string code, int id, bool forUi, bool forExport)
        {
            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                return await GetGridDefinition(entityFramework, connection, code, id, forUi, forExport);
            }
        }

        public static async Task<GridDefinition> GetGridDefinition(Core entityFramework, SqlConnection connection, string code, int id, bool forUi, bool forExport)
        {
            GridDefinition gd2 = new();

            await entityFramework.OpenConnectionAsync(connection);

            // To do: Update code everywhere this is consumed to replace this fall back code
            if (code == "")
            {
                forUi = false;
            }
            else
            {
                forUi = true;
            }

            bool canRead = true;
            int _userId = await entityFramework.GetCurrentUserId(connection);

            string statement = "SELECT gd.Code, gd.Id, gd.Name, gd.PageUri, gd.TabName, gd.RowVersion, gd.ShowAsTiles " +
                    "FROM SUserInterface.GridDefinitions gd " +
                    "WHERE (gd.Id = @Id)" +
                    "   OR (gd.Code = @Code)";

            using (var command = entityFramework.CreateCommand(statement, connection))
            {          
                command.Parameters.Add(new SqlParameter("Id", id));
                command.Parameters.Add(new SqlParameter("Code", code));

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

            if (forUi || forExport)
            {

                statement = "SELECT gvd.Id, gvd.Code, gvd.Name, gvd.DetailPageUri, gvd.DefaultSortColumnName, gvd.DisplayOrder, gvd.SecurableCode, gvd.DisplayGroupName," +
                    "gvd.GridDefinitionId, gvd.SqlQuery, gvd.MetricSqlQuery, gvd.ShowMetric, gvd.IsDetailWindowed, et.Guid as EntityTypeGuid " +
                    "FROM SUserInterface.GridViewDefinitions gvd " +
                    "JOIN   SCore.EntityTypes et on (gvd.EntityTypeID = et.ID)" +
                    "WHERE  (GridDefinitionId = @GridDefinitionId)";

                using (var command = entityFramework.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("GridDefinitionID", gd2.Id));

                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            string securableCode = reader.GetString(reader.GetOrdinal("SecurableCode"));
                            /*if (securableCode != "")
                            {
                                canRead = _serviceBase.ctx.tvf_GetSecurablePermissions(_userId, securableCode).FirstOrDefault().CanRead ?? false;
                            }
                            else
                            {
                                canRead = true;
                            }*/

                            if (forExport == true || canRead == true)
                            {
                                GridViewDefinition gvd2 = new();
                                gvd2.Id = reader.GetInt32(reader.GetOrdinal("Id"));
                                gvd2.Code = reader.GetString(reader.GetOrdinal("Code"));
                                gvd2.Name = reader.GetString(reader.GetOrdinal("Name"));
                                gvd2.DetailPageUri = reader.GetString(reader.GetOrdinal("DetailPageUri"));
                                gvd2.DefaultSortColumnName = reader.GetString(reader.GetOrdinal("DefaultSortColumnName"));
                                gvd2.SecurableCode = securableCode;
                                gvd2.DisplayOrder = reader.GetInt32(reader.GetOrdinal("DisplayOrder"));
                                gvd2.DisplayGroupName = reader.GetString(reader.GetOrdinal("DisplayGroupName"));
                                gvd2.IsDetailWindowed = reader.GetBoolean(reader.GetOrdinal("IsDetailWindowed"));
                                gvd2.EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")).ToString();
                                gvd2.ShowMetric = reader.GetBoolean(reader.GetOrdinal("ShowMetric"));

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
                }

                statement = "SELECT Id, ColumnOrder, Name, Title, IsPrimaryKey, IsHidden, IsFiltered, IsCombo, GridViewDefinitionId " +
                            "FROM SUserInterface.GridViewColumnDefinitions " +
                            "WHERE  (GridViewDefinitionId = @GridViewDefinitionId)";

                foreach (GridViewDefinition gvd in  gd2.Views)
                {
                    using (var command = entityFramework.CreateCommand(statement, connection))
                    {
                        command.Parameters.Add(new SqlParameter("@GridViewDefinitionId", gvd.Id));

                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                GridViewColumnDefinition gvcd2 = new();
                                gvcd2.Id = reader.GetInt32(reader.GetOrdinal("Id"));
                                gvcd2.ColumnOrder = reader.GetInt32(reader.GetOrdinal("ColumnOrder"));
                                gvcd2.Name = reader.GetString(reader.GetOrdinal("Name"));
                                gvcd2.Title = reader.GetString(reader.GetOrdinal("Title"));
                                gvcd2.IsPrimaryKey = reader.GetBoolean(reader.GetOrdinal("IsPrimaryKey"));
                                gvcd2.IsHidden = reader.GetBoolean(reader.GetOrdinal("IsHidden"));
                                gvcd2.IsFiltered = reader.GetBoolean(reader.GetOrdinal("IsFiltered"));
                                gvcd2.IsCombo = reader.GetBoolean(reader.GetOrdinal("IsCombo"));

                                if (forExport)
                                {
                                    gvcd2.GridViewDefinitionId = reader.GetInt32(reader.GetOrdinal("GridViewDefinitionId"));
                                }

                                gvd.Columns.Add(gvcd2 );
                            }
                        }
                    }
                }
            }            

            if (gd2.Views.Count < 1)
            {
                GridViewDefinition gvd = new();
                gd2.Views.Add(gvd);
            }

            return gd2;
        }

        public static async Task<GridViewDefinition> GetGridViewDefinition(Core entityFramework, int id)
        {
            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                return await GetGridViewDefinition(entityFramework, connection, id);
            }
        }

        public static async Task<GridViewDefinition> GetGridViewDefinition(Core entityFramework, SqlConnection connection, int id = 0, string gridCode = "", string gridViewCode = "")
        {
            GridViewDefinition rsl = new();

            string statement = "SELECT gvd.Id, gvd.Name, gvd.RowVersion, gvd.GridDefinitionId, gvd.SqlQuery, " +
                "gvd.DetailPageUri, gvd.DefaultSortColumnName, gvd.Code, gvd.SecurableCode, gvd.DisplayGroupName, " +
                "gvd.DisplayOrder, gvd.MetricSqlQuery, gvd.ShowMetric, gvd.IsDetailWindowed, et.Guid as EntityTypeGuid " +
                "FROM SUserInterface.GridViewDefinitions gvd " +
                "JOIN SUserInterface.GridDefinitions gd on (gvd.GridDefinitionId = gd.ID) " +
                "JOIN SCore.EntityTypes et on (gvd.EntityTypeID = et.ID) " +
                "WHERE  (gvd.Id = @Id) " +
                "   OR  (" +
                "           (gvd.Code = @GridViewCode)" +
                "           AND (gd.Code = @GridCode)" +
                "        )";

            using (var command = entityFramework.CreateCommand(statement, connection))
            {
                command.Parameters.Add(new SqlParameter("Id", id));
                command.Parameters.Add(new SqlParameter("GridCode", gridCode));
                command.Parameters.Add(new SqlParameter("GridViewCode", gridViewCode));

                using (var reader = await command.ExecuteReaderAsync())
                {
                    while (reader.Read())
                    {
                        rsl = new()
                        {
                            Id = reader.GetInt32(reader.GetOrdinal("Id")),
                            Name = reader.GetString(reader.GetOrdinal("Name")),
                            RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                            GridDefinitionId = reader.GetInt32(reader.GetOrdinal("GridDefinitionId")),
                            SqlQuery = reader.GetString(reader.GetOrdinal("SqlQuery")),
                            DetailPageUri = reader.GetString(reader.GetOrdinal("DetailPageUri")),
                            DefaultSortColumnName = reader.GetString(reader.GetOrdinal("DefaultSortColumnName")),
                            Code = reader.GetString(reader.GetOrdinal("Code")),
                            SecurableCode = reader.GetString(reader.GetOrdinal("SecurableCode")),
                            DisplayGroupName = reader.GetString(reader.GetOrdinal("DisplayGroupName")),
                            DisplayOrder = reader.GetInt32(reader.GetOrdinal("DisplayOrder")),
                            MetricSqlQuery = reader.GetString(reader.GetOrdinal("MetricSqlQuery")),
                            ShowMetric = reader.GetBoolean(reader.GetOrdinal("ShowMetric")),
                            IsDetailWindowed = reader.GetBoolean(reader.GetOrdinal("IsDetailWindowed")),
                            EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")).ToString(),
                        };
                    }
                }
            }

            return rsl;
        }

        public static async Task<GridViewColumnDefinition> GridViewColumnDefinitionUpsert(Core entityFramework, GridViewColumnDefinitionUpsertRequest request)
        {
            GridViewColumnDefinition rsl = new();
            int gridViewColumnDefinitionId;

            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                using (var transaction = entityFramework.BeginTransaction(connection))
                {
                    using (var command = entityFramework.CreateCommand(gridViewColumnDefinitionUpsertStatement, connection, transaction))
                    {
                        command.Parameters.Add(new SqlParameter("Name", request.GridViewColumnDefinition.Name));
                        command.Parameters.Add(new SqlParameter("ColumnOrder", request.GridViewColumnDefinition.ColumnOrder));
                        command.Parameters.Add(new SqlParameter("Title", request.GridViewColumnDefinition.Title));
                        command.Parameters.Add(new SqlParameter("GridViewDefinitionId", request.GridViewColumnDefinition.GridViewDefinitionId));
                        command.Parameters.Add(new SqlParameter("IsPrimaryKey", request.GridViewColumnDefinition.IsPrimaryKey));
                        command.Parameters.Add(new SqlParameter("IsHidden", request.GridViewColumnDefinition.IsHidden));
                        command.Parameters.Add(new SqlParameter("IsFiltered", request.GridViewColumnDefinition.IsFiltered));
                        command.Parameters.Add(new SqlParameter("IsCombo", request.GridViewColumnDefinition.IsCombo));
                        command.Parameters.Add(new SqlParameter("Guid", request.GridViewColumnDefinition.Guid));

                        SqlParameter gridViewColumnDefinitionIdParameter = command.Parameters.Add(new SqlParameter("Id", request.GridViewColumnDefinition.Id) { Direction = ParameterDirection.InputOutput });

                        command.ExecuteNonQuery();

                        gridViewColumnDefinitionId = int.Parse(gridViewColumnDefinitionIdParameter.Value.ToString() ?? "0");
                    }
                }

                rsl = await GetGridViewColumnDefinition(entityFramework, connection, gridViewColumnDefinitionId);
            }

            return rsl;
        }

        public static async Task<GridDefinition> GridDefinitionUpsert(Core entityFramework, GridDefinitionUpsertRequest request)
        {
            GridDefinition rsl = new();

            int gridDefinitionId = request.GridDefinition.Id;
            int gridViewDefinitionId;
            int gridViewColumnDefinitionId;
            SqlParameter gridDefinitionIdParameter;
            SqlParameter gridViewDefinitionIdParameter;
            SqlParameter gridViewColumnDefinitionIdParameter;

            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                using (var transaction = entityFramework.BeginTransaction(connection))
                {
                    // Grid Definition 
                    using (var command = entityFramework.CreateCommand(gridDefinitionUpsertStatement, connection, transaction))
                    {
                        command.Parameters.Add(new SqlParameter("Code", request.GridDefinition.Code));
                        command.Parameters.Add(new SqlParameter("Name", request.GridDefinition.Name));
                        command.Parameters.Add(new SqlParameter("PageUri", request.GridDefinition.PageUri));
                        command.Parameters.Add(new SqlParameter("TabName", request.GridDefinition.TabName));
                        command.Parameters.Add(new SqlParameter("ShowAsTiles", request.GridDefinition.ShowAsTiles));
                        command.Parameters.Add(new SqlParameter("Guid", request.GridDefinition.Guid));

                        if (request.GridDefinition.Views.Count > 0)
                        {
                            command.Parameters.Add(new SqlParameter("ClearViews", true));
                        }
                        else
                        {
                            command.Parameters.Add(new SqlParameter("ClearViews", false));
                        }

                        gridDefinitionIdParameter = command.Parameters.Add(new SqlParameter("Id", gridDefinitionId) { Direction = ParameterDirection.InputOutput });

                        command.ExecuteNonQuery();

                        gridDefinitionId = int.Parse(gridDefinitionIdParameter.Value.ToString() ?? "0");
                    }

                    // Grid View Definition                     
                    foreach (GridViewDefinition gvd in request.GridDefinition.Views)
                    {
                        gridViewDefinitionId = gvd.Id;

                        using (var command2 = entityFramework.CreateCommand(gridViewDefinitionUpsertStatement, connection, transaction))
                        {
                            command2.Parameters.Add(new SqlParameter("Code", gvd.Code));
                            command2.Parameters.Add(new SqlParameter("Name", gvd.Name));
                            command2.Parameters.Add(new SqlParameter("GridDefinitionId", gridDefinitionId));
                            command2.Parameters.Add(new SqlParameter("DetailPageUri", gvd.DetailPageUri));
                            command2.Parameters.Add(new SqlParameter("SqlQuery", gvd.SqlQuery));
                            command2.Parameters.Add(new SqlParameter("DefaultSortColumnName", gvd.DefaultSortColumnName));
                            command2.Parameters.Add(new SqlParameter("SecurableCode", gvd.SecurableCode));
                            command2.Parameters.Add(new SqlParameter("DisplayOrder", gvd.DisplayOrder));
                            command2.Parameters.Add(new SqlParameter("DisplayGroupName", gvd.DisplayGroupName));
                            command2.Parameters.Add(new SqlParameter("MetricSqlQuery", gvd.MetricSqlQuery));
                            command2.Parameters.Add(new SqlParameter("ShowMetric", gvd.ShowMetric));
                            command2.Parameters.Add(new SqlParameter("Guid", gvd.Guid));
                            command2.Parameters.Add(new SqlParameter("EntityTypeGuid", gvd.EntityTypeGuid));

                            gridViewDefinitionIdParameter = command2.Parameters.Add(new SqlParameter("Id", gridViewDefinitionId) { Direction = ParameterDirection.InputOutput });

                            command2.ExecuteNonQuery();

                            gridViewDefinitionId = int.Parse(gridViewDefinitionIdParameter.Value.ToString() ?? "0");
                        }

                        foreach (GridViewColumnDefinition gvcd in gvd.Columns)
                        {
                            gridViewColumnDefinitionId = gvcd.Id;

                            using (var command3 = entityFramework.CreateCommand(gridViewColumnDefinitionUpsertStatement, connection, transaction))
                            {
                                command3.Parameters.Add(new SqlParameter("Name", gvcd.Name));
                                command3.Parameters.Add(new SqlParameter("ColumnOrder", gvcd.ColumnOrder));
                                command3.Parameters.Add(new SqlParameter("Title", gvcd.Title));
                                command3.Parameters.Add(new SqlParameter("GridViewDefinitionId", gridViewColumnDefinitionId));
                                command3.Parameters.Add(new SqlParameter("IsPrimaryKey", gvcd.IsPrimaryKey));
                                command3.Parameters.Add(new SqlParameter("IsHidden", gvcd.IsHidden));
                                command3.Parameters.Add(new SqlParameter("IsFiltered", gvcd.IsFiltered));
                                command3.Parameters.Add(new SqlParameter("IsCombo", gvcd.IsCombo));
                                command3.Parameters.Add(new SqlParameter("Guid", gvcd.Guid));

                                gridViewColumnDefinitionIdParameter = command3.Parameters.Add(new SqlParameter("Id", gridViewColumnDefinitionId) { Direction = ParameterDirection.InputOutput });

                                command3.ExecuteNonQuery();

                                gridViewColumnDefinitionId = int.Parse(gridViewColumnDefinitionIdParameter.Value.ToString() ?? "0");
                            }
                        }
                    }

                    await transaction.CommitAsync();
                }

                rsl = await GetGridDefinition(entityFramework, connection, request.GridDefinition.Code, gridDefinitionId, true, true);
            }

            return rsl;
        }

        public static async Task<GridViewDefinition> GridViewDefinitionUpsert(Core entityFramework, GridViewDefinitionUpsertRequest request)
        {
            GridViewDefinition rsl = new();

            int gridViewDefinitionId;

            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                using (var transaction = entityFramework.BeginTransaction(connection))
                {
                    using (var command = entityFramework.CreateCommand(gridViewDefinitionUpsertStatement, connection, transaction))
                    {
                        command.Parameters.Add(new SqlParameter("Code", request.GridViewDefinition.Code));
                        command.Parameters.Add(new SqlParameter("Name", request.GridViewDefinition.Name));
                        command.Parameters.Add(new SqlParameter("GridDefinitionId", request.GridViewDefinition.GridDefinitionId));
                        command.Parameters.Add(new SqlParameter("DetailPageUri", request.GridViewDefinition.DetailPageUri));
                        command.Parameters.Add(new SqlParameter("SqlQuery", request.GridViewDefinition.SqlQuery));
                        command.Parameters.Add(new SqlParameter("DefaultSortColumnName", request.GridViewDefinition.DefaultSortColumnName));
                        command.Parameters.Add(new SqlParameter("SecurableCode", request.GridViewDefinition.SecurableCode));
                        command.Parameters.Add(new SqlParameter("DisplayOrder", request.GridViewDefinition.DisplayOrder));
                        command.Parameters.Add(new SqlParameter("DisplayGroupName", request.GridViewDefinition.DisplayGroupName));
                        command.Parameters.Add(new SqlParameter("MetricSqlQuery", request.GridViewDefinition.MetricSqlQuery));
                        command.Parameters.Add(new SqlParameter("ShowMetric", request.GridViewDefinition.ShowMetric));
                        command.Parameters.Add(new SqlParameter("Guid", request.GridViewDefinition.Guid));
                        command.Parameters.Add(new SqlParameter("EntityTypeGuid", request.GridViewDefinition.EntityTypeGuid));

                        SqlParameter gridViewDefinitionIdParameter = command.Parameters.Add(new SqlParameter("Id", request.GridViewDefinition.Id) { Direction = ParameterDirection.InputOutput });

                        command.ExecuteNonQuery();

                        gridViewDefinitionId = int.Parse(gridViewDefinitionIdParameter.Value.ToString() ?? "0");
                    }

                    await transaction.CommitAsync();
                }

                rsl = await GetGridViewDefinition(entityFramework, connection, gridViewDefinitionId);
            }

            return rsl;            
        }

        public static async Task<bool> GridViewColumnDefinitionDelete(Core entityFramework, GridViewColumnDefinitionDeleteRequest request)
        {
            GridViewColumnDefinitionDeleteReply rsl = new();

            using (var connection = entityFramework.CreateConnection())
            {
                using (var transaction = entityFramework.BeginTransaction(connection))
                {
                    string statement = "UPDATE SUserInterface.GridViewColumnDefinitions SET RowStatus = @RowStatus WHERE (Id = @ID)";

                    using (var command = entityFramework.CreateCommand(statement, connection, transaction))
                    {
                        command.Parameters.Add(new SqlParameter("RowStatus", (int)RowStatus.Deleted));
                        command.Parameters.Add(new SqlParameter("Id", request.GridViewColumnDefinition.Id));

                        await command.ExecuteNonQueryAsync();
                    }

                    await transaction.CommitAsync();
                }
            }

            return true;
        }

        public static async Task<GridViewColumnDefinition> GetGridViewColumnDefinition(Core entityFramework, SqlConnection connection, int gridViewColumnDefinitionId)
        {
            string statement = "SELECT Id, Name, RowVersion, GridViewDefinitionId, Title, IsCombo, IsFiltered, IsHidden, IsPrimaryKey, ColumnOrder " +
                "FROM   SUserInterface.GridViewColumnDefinitions " +
                "WHERE  (ID = @Id)";

            using (var command = entityFramework.CreateCommand(statement, connection))
            {
                command.Parameters.Add(new SqlParameter("Id", gridViewColumnDefinitionId));

                using (var reader = await command.ExecuteReaderAsync())
                {
                    while (reader.Read())
                    {
                        GridViewColumnDefinition rslGridViewColumn = new()
                        {
                            Id = reader.GetInt32(reader.GetOrdinal("Id")),
                            Name = reader.GetString(reader.GetString("Name")),
                            RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                            GridViewDefinitionId = reader.GetInt32(reader.GetOrdinal("GridViewDefinitionId")),
                            Title = reader.GetString(reader.GetOrdinal("Title")),
                            IsCombo = reader.GetBoolean(reader.GetOrdinal("IsCombo")),
                            IsFiltered = reader.GetBoolean(reader.GetOrdinal("IsFiltered")),
                            IsHidden = reader.GetBoolean(reader.GetOrdinal("IsHidden")),
                            IsPrimaryKey = reader.GetBoolean(reader.GetOrdinal("IsPrimaryKey")),
                            ColumnOrder = reader.GetInt32(reader.GetOrdinal("ColumnOrder")),
                        };


                        return rslGridViewColumn;
                    }
                }
            }
            return new();
        }

        public static async Task<GridViewColumnDefinitionsReply> GridViewColumnDefinitions(Core entityFramework, GridViewColumnDefinitionsRequest request)
        {
            GridViewColumnDefinitionsReply rsl = new();

            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                string statement = "SELECT Id, Name, RowVersion, GridViewDefinitionId, Title, IsCombo, IsFiltered, IsHidden, IsPrimaryKey, ColumnOrder " +
                    "FROM   SUserInterface.GridViewColumnDefinitions gvcd " +
                    "WHERE  (gvcd.GridViewDefinitionID = @GridViewDefinitionId)" +
                    "   AND (gvcd.RowStatus != " + (int)RowStatus.Deleted + ")";

                using (var command = entityFramework.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("GridViewDefinitionId", request.GridViewDefinitionId));

                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            GridViewColumnDefinition rslGridViewColumn = new()
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
                            };

                            rsl.Columns.Add(rslGridViewColumn);
                        }
                    }
                }
            }

            return rsl;
        }

        public static async Task<DropDownDataListReply> DropDownDataList(Core entityFramework, DropDownDataListRequest request)
        {
            DropDownDataListReply rsl = new();

            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                string statement = "SELECT ddld.Code, ddld.SqlQuery, ddld.DefaultSortColumnName, ddld.NameColumn, ddld.ValueColumn " +
                    "FROM SUserInterface.DropDownListDefinitions ddld " +
                    "WHERE  (ddld.Guid = @Guid)";

                string dataSqlQuery = "";
                string dataSortOrderColumn = "";
                string dataNameColumn = "";
                string dataValueColumn = "";

                using (var command = entityFramework.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("Guid", request.Guid));

                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            dataSqlQuery = reader.GetString(reader.GetOrdinal("SqlQuery"));
                            dataSortOrderColumn = reader.GetString(reader.GetOrdinal("DefaultSortColumnName"));
                            dataNameColumn = reader.GetString(reader.GetOrdinal("NameColumn"));
                            dataValueColumn = reader.GetString(reader.GetOrdinal("ValueColumn"));
                        }
                    }
                }

                string sqlWhere = entityFramework.DataObjectCompositeFilterListToPredicate(dataSqlQuery, request.Filters.ToList());

                string sqlSort = " ORDER BY " + dataSortOrderColumn + " ASC ";

                dataSqlQuery = ServiceBase.StripPredicateFromQuery(dataSqlQuery);

                sqlWhere = sqlWhere.Replace("[[ParentGuid]]", request.ParentGuid);
                sqlWhere = sqlWhere.Replace("[[RecordGuid]]", request.RecordGuid);
                sqlWhere = sqlWhere.Replace("[[UserId]]", (await entityFramework.GetCurrentUserId(connection)).ToString());

                dataSqlQuery = dataSqlQuery.Replace("[[ParentGuid]]", request.ParentGuid);
                dataSqlQuery = dataSqlQuery.Replace("[[RecordGuid]]", request.RecordGuid);
                dataSqlQuery = dataSqlQuery.Replace("[[UserId]]", (await entityFramework.GetCurrentUserId(connection)).ToString());

                using (var command = entityFramework.CreateCommand(dataSqlQuery + sqlWhere + sqlSort, connection))
                {
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            DropDownDataListItem dddli = new();
                            dddli.Name = reader.GetValue(reader.GetOrdinal(dataNameColumn)).ToString();
                            dddli.Value = reader.GetValue(reader.GetOrdinal(dataValueColumn)).ToString();

                            rsl.Items.Add(dddli);

                            // if this was the -1 row. Add the add new row. 
                            if (dddli.Value == "-1" & request.IsAddingAllowed)
                            {
                                DropDownDataListItem ndddli = new()
                                { 
                                    Name = "-- Add new --",
                                    Value = "-2"
                                };

                                rsl.Items.Add(ndddli);
                            }
                        }
                    }
                }
            }

            return rsl;
        }

        public static async Task<DropDownListDefinitionGetResponse> DropDownDataListDefinitionGet (Core entityFramework, DropDownListDefinitionGetRequest request)
        {
            DropDownListDefinitionGetResponse rsl = new();

            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                string statement = "SELECT * " +
                    "FROM SUserInterface.DropDownListDefinitions ddld " +
                    "WHERE  (ddld.Guid = @Guid)";

                using (var command = entityFramework.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("Guid", request.Guid));

                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            DropDownListDefinition dropDownListDefinition = new() {
                                Guid = reader.GetGuid(reader.GetOrdinal("Guid")).ToString(),
                                Code = reader.GetString(reader.GetOrdinal("Code")),
                                SqlQuery = reader.GetString(reader.GetOrdinal("SqlQuery")),
                                DefaultSortColumnName = reader.GetString(reader.GetOrdinal("DefaultSortColumnName")),
                                NameColumn = reader.GetString(reader.GetOrdinal("NameColumn")),
                                ValueColumn = reader.GetString(reader.GetOrdinal("ValueColumn")),
                                DetailPageUrl = reader.GetString(reader.GetOrdinal("DetailPageUrl")),
                                IsDetailWindowed = reader.GetBoolean(reader.GetOrdinal("IsDetailWindowed")),
                            };

                            rsl.DropDownListDefinition = dropDownListDefinition;
                        }
                    }
                }
            }

            return rsl;
        }

        public static async Task<GridDataListReply> GridDataList(Core entityFramework, GridDataListRequest request)
        {
            // TO DO this whole thing needs changing to Data Objects 
            
            GridDataListReply rsl = new();
            string sqlQuery = "";

            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                GridViewDefinition gridViewDefinition = await GetGridViewDefinition(entityFramework, connection, 0, request.GridCode, request.GridViewCode);

                sqlQuery = gridViewDefinition.SqlQuery;

                List<GridViewColumnDefinition> columns = (await GridViewColumnDefinitions(entityFramework, new() { GridViewDefinitionId = gridViewDefinition.Id })).Columns.ToList();

                string sqlWhere = "";//" WHERE";
                string sqlSort = " ORDER BY";

                if (sqlQuery.IndexOf("WHERE") > -1)
                {
                    sqlWhere = sqlQuery.Substring(sqlQuery.IndexOf("WHERE") + 6);
                }
                sqlWhere = sqlWhere.Replace("[[ParentGuid]]", request.ParentGuid);
                sqlWhere = sqlWhere.Replace("[[UserId]]", (await entityFramework.GetCurrentUserId(connection)).ToString());

                sqlQuery = sqlQuery.Replace("[[ParentGuid]]", request.ParentGuid);
                sqlQuery = sqlQuery.Replace("[[UserId]]", (await entityFramework.GetCurrentUserId(connection)).ToString());

                sqlWhere = (sqlWhere != "") ? " WHERE " + sqlWhere : sqlWhere;

                foreach (DataSort s in request.Sort)
                {
                    if (sqlSort != " ORDER BY")
                    {
                        sqlSort += ", ";
                    }
                    sqlSort += " [" + s.ColumnName + "] " + (s.Direction == "Ascending" ? "ASC" : "DESC");
                }

                if (sqlSort == " ORDER BY")
                {
                    sqlSort += " ID ASC";
                }

                if (request.PageSize > 0)
                {
                    sqlSort += " OFFSET " + (request.PageSize * (request.Page - 1)) + " ROWS FETCH NEXT " + request.PageSize + " ROWS ONLY ";
                }

                sqlQuery = ServiceBase.StripPredicateFromQuery(sqlQuery);

                using (var command = entityFramework.CreateCommand("SELECT Count(1) FROM " + sqlQuery[(sqlQuery.ToLower().IndexOf("from") + 5)..] + sqlWhere, connection))
                {
                    int totalRowCount = int.Parse(command.ExecuteScalar().ToString() ?? "0");
                    rsl.TotalRows = totalRowCount;
                }
                
                using (var command = entityFramework.CreateCommand(sqlQuery + sqlWhere + sqlSort, connection))
                {
                    using (SqlDataReader reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            GridDataRow dRow = new();

                            foreach (GridViewColumnDefinition col in columns)
                            {
                                GridDataColumn dCol = new()
                                {
                                    Name = col.Name,
                                    Value = reader.GetValue(reader.GetOrdinal(col.Name)).ToString()
                                };

                                dRow.Columns.Add(dCol);
                            }

                            rsl.DataTable.Add(dRow);
                        }
                    }
                }                
            }
                           
            return rsl;
        }

        public static async Task<DashboardMetricsGetResponse> DashboardMetricsGet(Core entityFramework, DashboardMetricsGetRequest request)
        {
            DashboardMetricsGetResponse rsl = new();
            string sqlQuery = "";

            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                sqlQuery = "SELECT * FROM  [SCore].[tvf_DashboardMetrics] (@UserId)";

                using (var command = entityFramework.CreateCommand(sqlQuery, connection))
                {
                    command.Parameters.Add(new SqlParameter("@UserId", await entityFramework.GetCurrentUserId(connection)));

                    using (SqlDataReader reader = await command.ExecuteReaderAsync())
                    {
                        while (reader.Read())
                        {
                            DashboardMetric dm = new()
                            {
                                Label = reader.GetString(reader.GetOrdinal("Label")),
                                SortOrder = reader.GetInt32(reader.GetOrdinal("SortOrder")),
                                Min = reader.GetInt32(reader.GetOrdinal("Min")),
                                Max = reader.GetInt32(reader.GetOrdinal("Max")),
                                MinorUnit = reader.GetInt32(reader.GetOrdinal("MinorUnit")),
                                MajorUnit = reader.GetInt32(reader.GetOrdinal("MajorUnit")),
                                StartAngle = reader.GetInt32(reader.GetOrdinal("StartAngle")),
                                EndAngle = reader.GetInt32(reader.GetOrdinal("EndAngle")),
                                Reverse = reader.GetBoolean(reader.GetOrdinal("Reverse")),
                                MetricTypeName = reader.GetString(reader.GetOrdinal("MetricTypeName")),
                                MetricSqlQuery = reader.GetString(reader.GetOrdinal("MetricSqlQuery"))
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

                            rsl.Metrics.Add(dm);

                        }
                    }
                }

                foreach (DashboardMetric dm in rsl.Metrics)
                {
                    string metricQuery = dm.MetricSqlQuery;
                    metricQuery = metricQuery.Replace("[[UserId]]", (await entityFramework.GetCurrentUserId(connection)).ToString());
                    
                    using (var command = entityFramework.CreateCommand(metricQuery, connection))
                    {                    
                        using (SqlDataReader reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                DashboardMetricValue dv = new()
                                {
                                    Value = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("MetricValue1"))),
                                    ColourHex = reader.GetString(reader.GetOrdinal("Value1ColourHex"))
                                };

                                dm.Values.Add(dv);
                            
                                dv = new()
                                {
                                    Value = Decimal.ToDouble(reader.GetDecimal(reader.GetOrdinal("MetricValue2"))),
                                    ColourHex = reader.GetString(reader.GetOrdinal("Value2ColourHex"))
                                };

                                dm.Values.Add(dv);
                                
                                dm.MetricSqlQuery = "";
                            }
                        }
                    }
                }
            }

            return rsl;
        }

        
    }
}
