using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Data.SqlClient;
using Concursus.API.Core;

namespace Concursus.API.EntityFramework
{
    internal static class Security
    {
        public static async Task<UserGroupListResponse> UserGroupList(Core entityFramework, UserGroupListRequest request)
        {
            try
            {
                UserGroupListResponse rsl = new();

                using (var connection = entityFramework.CreateConnection())
                {
                    await entityFramework.OpenConnectionAsync(connection);

                    string statement = "SELECT ug.ID, ug.Guid, ug.RowVersion, ug.IdentityId, ug.GroupId, g.Name, g.Guid as GroupGuid, i.Guid as IdentityGuid " +
                        "FROM SCore.UserGroups ug " +
                        "JOIN SCore.Groups g ON (ug.GroupID = g.ID) " +
                        "JOIN SCore.Identities i on (ug.IdentityID = i.ID) " +
                        "WHERE (ug.IdentityId = @UserId)";

                    using (var command = entityFramework.CreateCommand(statement, connection))
                    {
                        command.Parameters.Add(new SqlParameter("UserId", request.UserId));

                        using (var reader = await command.ExecuteReaderAsync())
                        { while (reader.Read())
                            {
                                rsl.UserGroups.Add(new UserGroup()
                                {
                                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                    Guid = reader.GetString(reader.GetOrdinal("Guid")),
                                    RowVersion = reader.GetString(reader.GetOrdinal("RowVersion")),
                                    UserId = reader.GetInt32(reader.GetOrdinal("IdentityId")),
                                    UserGuid = reader.GetString(reader.GetOrdinal("IdentityGuid")),
                                    GroupId = reader.GetInt32(reader.GetOrdinal("GroupId")),
                                    GroupGuid = reader.GetString(reader.GetOrdinal("GroupGuid")),
                                    GroupName = reader.GetString(reader.GetOrdinal("GroupName")),
                                });
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

        public static async Task<UserGroupDeleteResponse> UserGroupDelete(Core entityFramework, UserGroupDeleteRequest request)
        {
            try
            {
                DataObjectDeleteRequest deleteRequest = new()
                {
                    ObjectGuid = "",
                    EntityTypeGuid = "",
                    EntityQueryGuid = ""
                };
                
                DataObjectDeleteResponse deleteResponse = await entityFramework.DataObjectDelete(deleteRequest);

                UserGroupDeleteResponse rsl = new();
                rsl.Success = true;

                return rsl;
            }
            catch (Exception ex)
            {
                entityFramework.logger.LogException(ex);
                throw;
            }
        }

        #region ObjectSecurity

        public static async Task<ObjectSecurityListResponse> ObjectSecurityList(Core entityFramework, ObjectSecurityListRequest request)
        {
            try
            {
                ObjectSecurityListResponse rsl = new();

                using (var connection = entityFramework.CreateConnection()) 
                {
                    await entityFramework.OpenConnectionAsync(connection);

                    string statement = "SELECT os.RowVersion, os.Guid, os.ObjectGuid, os.UserGuid, os.GroupGuid, os.CanRead, os.CanWrite " +
                        "FROM SCore.ObjectSecurity os " +
                        "WHERE  (os.GroupGuid = @GroupGuid)" +
                        "   AND (os.RecordGuid = @RecordGuid)";

                    using (var command = entityFramework.CreateCommand(statement, connection))
                    {
                        command.Parameters.Add(new SqlParameter("GroupGuid", request.GroupGuid));
                        command.Parameters.Add(new SqlParameter("RecordGuid", request.RecordGuid));

                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                rsl.ObjectSecurity.Add(new ObjectSecurity()
                                {
                                    RowStatus = reader.GetInt32(reader.GetOrdinal("RowStatus")),
                                    Guid = reader.GetString(reader.GetOrdinal("Guid")),
                                    ObjectGuid = reader.GetString(reader.GetOrdinal("ObjectGuid")),
                                    UserGuid = reader.GetString(reader.GetOrdinal("UserGuid")),
                                    GroupGuid = reader.GetString(reader.GetOrdinal("GroupGuid")),
                                    CanRead = reader.GetBoolean(reader.GetOrdinal("CanRead")),
                                    CanWrite = reader.GetBoolean(reader.GetOrdinal("CanWrite")),
                                });
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

        #endregion

    }
}
