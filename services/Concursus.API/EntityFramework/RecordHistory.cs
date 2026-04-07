using Google.Protobuf.WellKnownTypes;
using Microsoft.Data.SqlClient;
using System;
using System.Threading.Tasks;
using Concursus.API.Core;

namespace Concursus.API.EntityFramework
{
    internal static class RecordHistory
    {

        public static async Task<RecordHistoryGetResponse> RecordHistoryGet(Core entityFramework, RecordHistoryGetRequest request)
        {
            try
            {
                RecordHistoryGetResponse rsl = new();


                if (request.RecordId != 0)
                {
                    using (var connection = entityFramework.CreateConnection())
                    {
                        await entityFramework.OpenConnectionAsync(connection);

                        string statement;

                        if (entityFramework.useLegacyUserTables)
                        {
                            statement = "SELECT rh.Id, rh.UserId, rh.RowID, rh.DateTime, rh.TableName, " +
                                "rh.ColumnName, rh.SchemaName, rh.SqlUser, rh.PreviousValue, rh.NewValue " +
                                "ISNULL(u.FullName, rh.SqlUser) as UserName" +
                                "FROM SCore.RecordHistory rh" +
                                "LEFT JOIN dbo.User u (u.UserId = rh.UserID)" +
                                "WHERE (rh.SchemaName = @SchemaName) " +
                                "AND (rh.TableName = @TableName) " +
                                "AND (rh.RowId == request.RecordId) " +
                                "ORDER BY rh.Datetime DESC";
                        }
                        else
                        {
                            statement = "SELECT rh.Id, rh.UserId, rh.RowID, rh.DateTime, rh.TableName, " +
                                "rh.ColumnName, rh.SchemaName, rh.SqlUser, rh.PreviousValue, rh.NewValue " +
                                "ISNULL(u.FullName, rh.SqlUser) as UserName" +
                                "FROM SCore.RecordHistory rh" +
                                "LEFT JOIN SCore.Indentities u (u.Id = rh.UserID)" +
                                "WHERE (rh.SchemaName = @SchemaName) " +
                                "AND (rh.TableName = @TableName) " +
                                "AND (rh.RowId == request.RecordId) " +
                                "ORDER BY rh.Datetime DESC";
                        }

                        using (var command = entityFramework.CreateCommand(statement, connection))
                        {
                            using (var reader = await command.ExecuteReaderAsync())
                            {
                                while (reader.Read())
                                {
                                    rsl.RecordHistory.Add(new Concursus.API.Core.RecordHistory()
                                    {
                                        Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                        UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
                                        RowId = reader.GetInt32(reader.GetOrdinal("RowId")),
                                        DateTimeUtc = Timestamp.FromDateTime(
                                        DateTime.SpecifyKind(reader.GetDateTime(reader.GetOrdinal("DateTime")), DateTimeKind.Utc)),
                                        TableName = reader.GetString(reader.GetOrdinal("TableName")),
                                        ColumnName = reader.GetString(reader.GetOrdinal("ColumnName")),
                                        SchemaName = reader.GetString(reader.GetOrdinal("SchemaName")),
                                        SqlUser = reader.GetString(reader.GetOrdinal("SqlUser")),
                                        PreviousValue = reader.GetString(reader.GetOrdinal("PreviousValue")),
                                        NewValue = reader.GetString(reader.GetOrdinal("NewValue")),
                                        UserName = reader.GetString(reader.GetOrdinal("UserName"))
                                    });
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

        public static async void RecordHistoryAdd(
            Core entityFramework,
            string columnName,
            string tableName,
            long rowId,
            string previousValue,
            string newValue
            )
        {
            /*
             * no try catch block, if this fails we want the process calling it to fail.
            */
            using (var connection = entityFramework.CreateConnection())
            {
                string statement = "INSERT INTO SCore.RecordHistory " +
                    "(ColumnName, TableName, Datetime, RowId, UserId, PreviousValue, NewValue)" +
                    "VALUES (@ColumnName, @TableName, @Datetime, @RowId, @UsaerId, @PreviousValue, @NewValue)";

                await entityFramework.OpenConnectionAsync(connection);

                using (var transaction = entityFramework.BeginTransaction(connection))
                {
                    using (var command = entityFramework.CreateCommand(statement, connection, transaction))
                    {
                        command.Parameters.Add(new SqlParameter("ColumnName", columnName));
                        command.Parameters.Add(new SqlParameter("TableName", tableName));
                        command.Parameters.Add(new SqlParameter("Datetime", DateTimeOffset.UtcNow));
                        command.Parameters.Add(new SqlParameter("RowId", rowId));
                        command.Parameters.Add(new SqlParameter("UserId", entityFramework.GetCurrentUserId(connection)));
                        command.Parameters.Add(new SqlParameter("PreviousValue", previousValue));
                        command.Parameters.Add(new SqlParameter("NewValue", newValue));

                        command.ExecuteNonQuery();
                    }

                    await transaction.CommitAsync();
                }
            }
        }
    }
}
