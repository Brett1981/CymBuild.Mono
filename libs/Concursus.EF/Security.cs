using Concursus.EF.Types;
using Microsoft.Data.SqlClient;

namespace Concursus.EF
{
    public static class Security
    {
        #region Public Methods

        public static async Task<List<ObjectSecurity>> ObjectSecurityList(Core entityFramework, Guid groupGuid, Guid recordGuid)
        {
            List<ObjectSecurity> rsl = new();

            using (var connection = entityFramework.CreateConnection())
            {
                await entityFramework.OpenConnectionAsync(connection);

                string statement = "SELECT os.RowVersion, os.Guid, os.ObjectGuid, os.UserGuid, os.GroupGuid, os.CanRead, os.CanWrite " +
                    "FROM SCore.ObjectSecurity os " +
                    "WHERE  (os.GroupGuid = @GroupGuid)" +
                    "   AND (os.RecordGuid = @RecordGuid)";

                using (var command = QueryBuilder.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("GroupGuid", groupGuid));
                    command.Parameters.Add(new SqlParameter("RecordGuid", recordGuid));
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                rsl.Add(new ObjectSecurity()
                                {
                                    RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                    ObjectGuid = reader.GetGuid(reader.GetOrdinal("ObjectGuid")),
                                    UserGuid = reader.GetGuid(reader.GetOrdinal("UserGuid")),
                                    GroupGuid = reader.GetGuid(reader.GetOrdinal("GroupGuid")),
                                    CanRead = reader.GetBoolean(reader.GetOrdinal("CanRead")),
                                    CanWrite = reader.GetBoolean(reader.GetOrdinal("CanWrite")),
                                });
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting ObjectSecurityList: {ex.Message}", ex);
                    }
                }
            }

            return rsl;
        }

        public static Task UserGroupDelete(Core entityFramework)
        {
            throw new NotImplementedException();
        }

        public static Task UserGroupList(Core entityFramework, int userId)
        {
            throw new NotImplementedException();
        }

        #endregion Public Methods

        private static string BuildSqlWithParams(string query, SqlParameter[] parameters)
        {
            var formattedParams = parameters
                .Select(p => $"@{p.ParameterName} = '{p.Value}'")
                .ToArray();

            return $"{query}\nParams:\n{string.Join("\n", formattedParams)}";
        }
    }
}