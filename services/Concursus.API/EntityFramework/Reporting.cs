using Grpc.Core;
using Microsoft.Data.SqlClient;
using Concursus.API.Core;

namespace Concursus.API.EntityFramework
{
    internal static class Reporting
    {
        public static async Task<ReportingParametersGetResponse> ReportingParametersGet(Core entityFramework, ReportingParametersGetRequest request)
        {
            ReportingParametersGetResponse rsl = new();

            try
            {
                int rootFolderId = -1;

                if (request.ReportId == 0)
                {
                    rootFolderId = (int)System.Enum.Parse(typeof(Shore.Common.Enums.RootFolder), request.RootFolder);
                }

                using (var connection = entityFramework.CreateConnection()) 
                { 
                    await entityFramework.OpenConnectionAsync(connection);

                    string statement = "SELECT  rt.Code, r.Name, rt.ReportFileName, r.Id, r.RootFolderId, r.FolderId, r.RecordId, " +
                        "rt.SqlSchema, rt.SqlTable, rt.SqlIdColumn " +
                        "FROM SCore.Reports r " +
                        "JOIN SCore.ReportTemplated rt ON (rt.Id = r.ReportingTemplateId) " +
                        "WHERE  ((r.Id = @ReportId) AND (@ReportId > 0)) " +
                        "OR ((r.VirtualPath + N'\\' + r.Name + N'.shore' = @ReportPath)" +
                        "AND (r.RootFolderId = @RootFolderId) AND (r.FolderId = @RecordId))";

                    using (var command = entityFramework.CreateCommand(statement, connection))
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            rsl.ReportingParameters = new ReportingParameters()
                            {
                                ReportingTemplateCode = reader.GetString(reader.GetOrdinal("Code")),
                                ReportName = reader.GetString(reader.GetOrdinal("Name")),
                                ReportId = reader.GetInt32(reader.GetOrdinal("Id")),
                                RootFolderId = reader.GetInt32(reader.GetOrdinal("RootFolderId")),
                                EditPage = "",
                                FolderId = reader.GetInt32(reader.GetOrdinal("FolderId")),
                                RecordId = reader.GetInt32(reader.GetOrdinal("RecordId")),
                                FileTitle = "",
                                FileSubject = "",
                                FileBody = "",
                                ReportFileName = reader.GetString(reader.GetOrdinal("ReportFileName")),
                                SqlConnectionString = connection.ConnectionString
                            };
                        }
                    }
                }

                return rsl;
            }
            catch (RpcException ex)
            {
                entityFramework.logger.LogException(ex);
                throw;
            }
            catch (Exception ex)
            {
                entityFramework.logger.LogException(ex);
                throw new RpcException(new Grpc.Core.Status(StatusCode.Unknown, "SQL Exception: " + ex.Message), ex.Message);
            }
        }

        public static async Task<ReportingTemplatesGetResponse> ReportingTemplatesGet(Core entityFramework, ReportingTemplatesGetRequest request)
        {
            ReportingTemplatesGetResponse rsl = new();

            try
            {
                using (var connection = entityFramework.CreateConnection())
                {
                    await entityFramework.OpenConnectionAsync(connection);

                    string statement = "SELECT rt.Id, rt.Code, rt.Name, rt.Code + N' : ' + rt.Name as Label " +
                        "FROM SCore.ReportTemplates rt " +
                        "WHERE  (EXISTS" +
                        "           (" +
                        "               SELECT  1" +
                        "               FROM    SCore.ReportingTemplateAreas rta " +
                        "               JOIN    SCore.ReportingAreas ra ON (rta.ReportingAreaId = ra.Id) " +
                        "               WHERE   (ra.Core = @TemplateAreaName) " +
                        "                   AND (rta.ReportingTemplateId = rt.Id)" +
                        "           )" +
                        "   )";

                    using (var command = entityFramework.CreateCommand(statement, connection))
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read()) 
                            {
                                rsl.ReportingTemplates.Add(new ReportingTemplate()
                                {
                                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                    Code = reader.GetString(reader.GetOrdinal("Code")),
                                    Name = reader.GetString(reader.GetOrdinal("Name")),
                                    Label = reader.GetString(reader.GetOrdinal("Label")),
                                });
                            }
                        }
                    }
                }

                return rsl;
            }
            catch (RpcException ex)
            {
                entityFramework.logger.LogException(ex);
                throw;
            }
            catch (Exception ex)
            {
                entityFramework.logger.LogException(ex);
                throw new RpcException(new Grpc.Core.Status(StatusCode.Unknown, "SQL Exception: " + ex.Message), ex.Message);
            }
        }

        public static async Task<ReportUpsertResponse> ReportUpsert(Core entityFramework, ReportUpsertRequest request)
        {
            try
            {
                ReportUpsertResponse rsl = new();

                using (var connection = entityFramework.CreateConnection())
                {
                    await entityFramework.OpenConnectionAsync(connection);
                                   
                    using (var transaction = entityFramework.BeginTransaction(connection))
                    {
                        string reportGuid = Guid.Empty.ToString(); 
                        
                        string statement = "EXECUTE SCore.ReportUpsert " +
                            "@ReportTempleteId = @ReportTemplateId, " +
                            "@FolderId = @FolderId, " +
                            "@ReportName = @ReportName, " +
                            "@RecordId = @RecordId, " +
                            "@Guid = @Guid OUT";
                        
                        using (var command = entityFramework.CreateCommand(statement, connection, transaction))
                        {
                            command.Parameters.Add(new SqlParameter("ReportTemplateId", request.Report.ReportingTemplateId));
                            command.Parameters.Add(new SqlParameter("FolderId", request.Report.FolderId));
                            command.Parameters.Add(new SqlParameter("ReportName", request.Report.ReportName));
                            command.Parameters.Add(new SqlParameter("RecordID", request.Report.RecordId));

                            SqlParameter guidParameter = new SqlParameter("Guid", request.Report.Guid);
                            guidParameter.Direction = System.Data.ParameterDirection.InputOutput;

                            await command.ExecuteNonQueryAsync();

                            if (guidParameter.Value != null) {
                                reportGuid = guidParameter.Value.ToString() ?? Guid.Empty.ToString();
                            }
                        }

                        statement = "SELECT r.Guid, rt.Code as ReportingTemplateCode, r.Id, r.Name, r.RecordId, r.FolderId, " +
                            "rt.RootFolderId, rt.AreaFolderId, r.RowVersion, r.ReplotingTemplateId" +
                            "FROM SCore.Reports r " +
                            "JOIN SCore.ReportTemplate rt ON (r.ReportingTemplateId = rt.Id)" +
                            "WHERE (r.Guid = @guid)";

                        using (var command = entityFramework.CreateCommand(statement, connection, transaction))
                        {
                            command.Parameters.Add(new SqlParameter("guid", reportGuid));

                            using (var reader = await command.ExecuteReaderAsync())
                            {
                                while (reader.Read()) 
                                {
                                    rsl.Report = new()
                                    {
                                        Guid = reader.GetString(reader.GetOrdinal("Guid")),
                                        ReportingTemplateCode = reader.GetString(reader.GetOrdinal("ReportingTemplateCode")),
                                        ReportId = reader.GetInt32(reader.GetOrdinal("Id")),
                                        ReportName = reader.GetString(reader.GetOrdinal("Name")),
                                        RecordId = reader.GetInt32(reader.GetOrdinal("RecordId")),
                                        FolderId = reader.GetInt32(reader.GetOrdinal("FolderId")),
                                        FileTitle = "",
                                        FileSubject = "",
                                        FileBody = "",
                                        RootFolderId = reader.GetInt32(reader.GetOrdinal("RootFolderId")),
                                        AreaFolderId = reader.GetInt32(reader.GetOrdinal("AreaFolderId")),
                                        SqlConnectionString = connection.ConnectionString,
                                        ReportFileName = "",
                                        ReportRowVersion = reader.GetString(reader.GetOrdinal("RowVersion")),
                                        ReportingTemplateId = reader.GetInt32(reader.GetOrdinal("ReportingTemplateId")),
                                    };
                                }
                            }
                        }
                    }
                }                              

                return rsl;
            }
            catch (Exception ex)
            {
                entityFramework.logger.LogException(ex);
                throw;
            }
        }
    }
}
