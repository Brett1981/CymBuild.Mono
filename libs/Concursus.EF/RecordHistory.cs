using Concursus.Common.Shared.Extensions;
using Microsoft.Data.SqlClient;

namespace Concursus.EF
{
    public static class RecordHistory
    {
        public static async Task RecordHistoryAdd(
            Core entityFramework,
            string columnName,
            string tableName,
            long rowId,
            string previousValue,
            string newValue)
        {
            string statement = @"
                INSERT INTO SCore.RecordHistory
                (ColumnName, TableName, Datetime, RowId, UserId, PreviousValue, NewValue)
                VALUES (@ColumnName, @TableName, @Datetime, @RowId, @UserId, @PreviousValue, @NewValue)";

            using (var connection = entityFramework.CreateConnection())
            {
                try
                {
                    await entityFramework.OpenConnectionAsync(connection);

                    await connection.ExecuteInTransaction(async transaction =>
                    {
                        using (var command = QueryBuilder.CreateCommand(statement, connection, transaction))
                        {
                            command.AddParameters(
                                new SqlParameter("ColumnName", columnName),
                                new SqlParameter("TableName", tableName),
                                new SqlParameter("Datetime", DateTimeOffset.Now),
                                new SqlParameter("RowId", rowId),
                                new SqlParameter("UserId", await entityFramework.GetCurrentUserId(connection)),
                                new SqlParameter("PreviousValue", previousValue),
                                new SqlParameter("NewValue", newValue)
                            );

                            await command.ExecuteNonQueryAsync();
                        }
                    });
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"Error in RecordHistoryAdd: {ex.Message}");
                    throw;
                }
            }
        }

        public static async Task<List<Types.RecordHistory>> RecordHistoryGet(Core entityFramework, long recordId)
        {
            List<Types.RecordHistory> rsl = new();

            if (recordId != 0)
            {
                using (var connection = entityFramework.CreateConnection())
                {
                    await entityFramework.OpenConnectionAsync(connection);

                    string statement = @"
                        SELECT rh.Id, rh.UserId, rh.RowID, rh.DateTime, rh.TableName,
                               rh.ColumnName, rh.SchemaName, rh.SqlUser, rh.PreviousValue, rh.NewValue,
                               ISNULL(u.FullName, rh.SqlUser) AS UserName
                        FROM SCore.RecordHistory rh
                        LEFT JOIN SCore.Indentities u ON u.Id = rh.UserID
                        WHERE rh.RowId = @RecordId
                        ORDER BY rh.Datetime DESC";

                    using (var command = QueryBuilder.CreateCommand(statement, connection))
                    {
                        command.Parameters.Add(new SqlParameter("RecordId", recordId));

                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                DateTime dbTime = reader.GetDateTime(reader.GetOrdinal("DateTime"));

                                // Force UTC kind explicitly (otherwise Timestamp will assume Local)
                                if (dbTime.Kind == DateTimeKind.Unspecified)
                                    dbTime = DateTime.SpecifyKind(dbTime, DateTimeKind.Utc);

                                rsl.Add(new Types.RecordHistory()
                                {
                                    Id = reader.GetInt64(reader.GetOrdinal("Id")),
                                    UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
                                    RowId = reader.GetInt64(reader.GetOrdinal("RowId")),
                                    DateTimeUtc = dbTime.ToUniversalTime(), // Safe: already Kind.Utc
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
    }
}