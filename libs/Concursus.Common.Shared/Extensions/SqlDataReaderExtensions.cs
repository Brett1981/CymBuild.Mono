using Microsoft.Data.SqlClient;
using System.Data;
using System.Data.SqlTypes;
using System.Text.Json;

namespace Concursus.Common.Shared.Extensions
{
    public static class SqlDataReaderExtensions
    {
        //USUAGE:
        //  SharePointSiteId = reader.HasColumn("SharePointSiteId") && !reader.IsDBNull(reader.GetOrdinal("SharePointSiteId"))
        //                                    ? reader.GetInt32(reader.GetOrdinal("SharePointSiteId"))
        //                                    : -1,
        public static bool HasColumn(this SqlDataReader reader, string columnName)
        {
            for (int i = 0; i < reader.FieldCount; i++)
            {
                if (reader.GetName(i).Equals(columnName, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }
            return false;
        }

        //USUAGE:
        //  int someValue = reader.GetSafeValue<int>("SomeColumn", -1);
        //  string someText = reader.GetSafeValue<string>("TextColumn", "Default Text");
        public static T GetSafeValue<T>(this SqlDataReader reader, string columnName, T defaultValue = default)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return (T)reader[columnName];
            }
            return defaultValue;
        }

        //USUAGE:
        //  int? someValue = reader.GetNullableValue<int>("SomeColumn");
        public static T? GetNullableValue<T>(this SqlDataReader reader, string columnName) where T : struct
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return (T)reader[columnName];
            }
            return null;
        }

        //USUAGE:
        //  var jsonObject = reader.GetJsonObject<MyClass>("JsonColumn");
        public static T GetJsonObject<T>(this SqlDataReader reader, string columnName) where T : class
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                string jsonString = reader.GetString(reader.GetOrdinal(columnName));
                return JsonSerializer.Deserialize<T>(jsonString);
            }
            return null;
        }

        //USUAGE:
        //  DateTime? nullableDateTime = reader.GetDateTimeOrNull("DateColumn");
        public static DateTime? GetDateTimeOrNull(this SqlDataReader reader, string columnName)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetDateTime(reader.GetOrdinal(columnName));
            }
            return null;
        }

        //USUAGE:
        //  MyEnum enumValue = reader.GetEnumValue<MyEnum>("EnumColumn");
        public static T GetEnumValue<T>(this SqlDataReader reader, string columnName) where T : Enum
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return (T)Enum.Parse(typeof(T), reader[columnName].ToString());
            }
            return default;
        }

        //USUAGE:
        //  Guid? nullableGuid = reader.GetGuidOrNull("GuidColumn");
        public static Guid? GetGuidOrNull(this SqlDataReader reader, string columnName)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetGuid(reader.GetOrdinal(columnName));
            }
            return null;
        }

        // USUAGE: Guid guid = reader.GetGuidOrEmpty("GuidColumn");
        public static Guid GetGuidOrEmpty(this SqlDataReader reader, string columnName)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetGuid(reader.GetOrdinal(columnName));
            }
            return Guid.Empty;
        }

        //USUAGE:
        //  DataTable table = reader.ToDataTable();
        public static DataTable ToDataTable(this SqlDataReader reader)
        {
            DataTable dataTable = new();
            dataTable.Load(reader);
            return dataTable;
        }

        //USUAGE:
        //  bool isActive = reader.GetBooleanSafe("IsActive", false);
        public static bool GetBooleanSafe(this SqlDataReader reader, string columnName, bool defaultValue = false)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetBoolean(reader.GetOrdinal(columnName));
            }
            return defaultValue;
        }

        //USUAGE:
        //  string someText = reader.GetStringOrNull("TextColumn");
        public static string GetStringOrNull(this SqlDataReader reader, string columnName)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetString(reader.GetOrdinal(columnName));
            }
            return null;
        }

        // USUAGE: string someText = reader.GetStringOrEmpty("TextColumn");
        public static string GetStringOrEmpty(this SqlDataReader reader, string columnName)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetString(reader.GetOrdinal(columnName));
            }
            return string.Empty;
        }

        // USUAGE: string someText = reader.GetStringOrDefault("TextColumn");
        public static string GetStringOrDefault(this SqlDataReader reader, string columnName, string defaultValue = "")
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetString(reader.GetOrdinal(columnName));
            }
            return defaultValue;
        }

        //USUAGE:
        //  decimal someValue = reader.GetDecimalSafe("AmountColumn", 0.0m);
        public static decimal GetDecimalSafe(this SqlDataReader reader, string columnName, decimal defaultValue = 0)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetDecimal(reader.GetOrdinal(columnName));
            }
            return defaultValue;
        }

        //USUAGE:
        //  byte[] byteArray = reader.GetByteArray("BinaryColumn");
        public static byte[] GetByteArray(this SqlDataReader reader, string columnName)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetFieldValue<byte[]>(reader.GetOrdinal(columnName));
            }
            return null;
        }

        // Automatically map the current row to an object using reflection.
        //USUAGE:
        //  var myObject = reader.MapTo<MyClass>();
        public static T MapTo<T>(this SqlDataReader reader) where T : new()
        {
            T obj = new();
            for (int i = 0; i < reader.FieldCount; i++)
            {
                string columnName = reader.GetName(i);
                var property = typeof(T).GetProperty(columnName, System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.IgnoreCase);
                if (property != null && !reader.IsDBNull(i))
                {
                    property.SetValue(obj, reader.GetValue(i));
                }
            }
            return obj;
        }

        //USUAGE:
        //  TimeSpan? timeSpan = reader.GetTimeSpan("DurationColumn");
        public static TimeSpan? GetTimeSpan(this SqlDataReader reader, string columnName)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetTimeSpan(reader.GetOrdinal(columnName));
            }
            return null;
        }

        //USUAGE:
        //  int someValue = reader.GetIntSafe("SomeColumn", -1);
        public static int GetIntSafe(this SqlDataReader reader, string columnName, int defaultValue = 0)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetInt32(reader.GetOrdinal(columnName));
            }
            return defaultValue;
        }

        //USUAGE:
        //  bool isAdmin = reader.ColumnValueEquals("UserRole", "Admin");
        public static bool ColumnValueEquals<T>(this SqlDataReader reader, string columnName, T value)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader[columnName].Equals(value);
            }
            return false;
        }

        // Handle SQL DateTime that might contain its minimum value.
        //USUAGE:
        //  DateTime? nullableDateTime = reader.GetSqlDateTime("DateColumn");
        public static DateTime? GetSqlDateTime(this SqlDataReader reader, string columnName)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                var dateTime = reader.GetDateTime(reader.GetOrdinal(columnName));
                return dateTime == SqlDateTime.MinValue.Value ? null : dateTime;
            }
            return null;
        }

        //USUAGE:
        //  long someValue = reader.GetLongSafe("SomeColumn", -1);
        public static long GetLongSafe(this SqlDataReader reader, string columnName, long defaultValue = 0)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetInt64(reader.GetOrdinal(columnName));
            }
            return defaultValue;
        }

        // Retrieve an enum by matching the database value.
        //USUAGE:
        //  MyEnum myEnum = reader.GetEnumByValue<MyEnum>("EnumColumn");
        public static T GetEnumByValue<T>(this SqlDataReader reader, string columnName) where T : Enum
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                var dbValue = reader.GetValue(reader.GetOrdinal(columnName));
                return (T)Enum.ToObject(typeof(T), dbValue);
            }
            return default;
        }

        //USUAGE:
        //  bool isNull = reader.IsColumnNull("NullableColumn");
        public static bool IsColumnNull(this SqlDataReader reader, string columnName)
        {
            return !reader.HasColumn(columnName) || reader.IsDBNull(reader.GetOrdinal(columnName));
        }

        // Retrieve a single row of data as a dictionary with column names as keys and their values as values.
        //USUAGE:
        //  var rowData  = reader.ToDictionary();
        public static Dictionary<string, object> ToDictionary(this SqlDataReader reader)
        {
            var result = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            for (int i = 0; i < reader.FieldCount; i++)
            {
                result[reader.GetName(i)] = reader.IsDBNull(i) ? null : reader.GetValue(i);
            }
            return result;
        }

        // Map all rows in a result set to a list of objects using reflection
        //USUAGE:
        //  var list = reader.MapAllTo<MyClass>();
        public static List<T> MapAllTo<T>(this SqlDataReader reader) where T : new()
        {
            var list = new List<T>();
            while (reader.Read())
            {
                list.Add(reader.MapTo<T>());
            }
            return list;
        }

        // A helper for fetching single values (e.g., COUNT, SUM, etc.) from SQL commands.
        //USUAGE:
        //  int count = command.ExecuteScalarAs<int>();
        public static T ExecuteScalarAs<T>(this SqlCommand command)
        {
            object result = command.ExecuteScalar();
            return result != DBNull.Value && result != null ? (T)Convert.ChangeType(result, typeof(T)) : default;
        }

        // Execute a NonQuery (e.g., INSERT, UPDATE, DELETE) with optional logging of affected rows.
        //USUAGE:
        //  command.ExecuteWithLog(log => Console.WriteLine(log));
        public static int ExecuteWithLog(this SqlCommand command, Action<string> logAction = null)
        {
            int rowsAffected = command.ExecuteNonQuery();
            logAction?.Invoke($"Rows affected: {rowsAffected}");
            return rowsAffected;
        }

        // Bulk-insert a DataTable into a database table.
        //USUAGE:
        //  connection.BulkInsert("TableName", dataTable);
        public static void BulkInsert(this SqlConnection connection, string tableName, DataTable dataTable, SqlTransaction transaction = null)
        {
            using SqlBulkCopy bulkCopy = new(connection, SqlBulkCopyOptions.Default, transaction);
            bulkCopy.DestinationTableName = tableName;
            bulkCopy.WriteToServer(dataTable);
        }

        // Convert a SqlDataReader directly into a DataTable.
        //USUAGE:
        //  DataTable table = command.ExecuteToDataTable();
        public static DataTable ExecuteToDataTable(this SqlCommand command)
        {
            using SqlDataReader reader = command.ExecuteReader();
            DataTable table = new();
            table.Load(reader);
            return table;
        }

        // Wrap a transaction in a using block for convenience and automatic rollback on error.
        //USUAGE:
        //  await connection.ExecuteInTransaction(async transaction =>
        //  {
        //    result = await GridViewActionsGet(connection, guid, userId);
        //  }, System.Data.IsolationLevel.ReadCommitted);
        public static async Task ExecuteInTransaction(
                this SqlConnection connection,
                Func<SqlTransaction, Task> transactionAction,
                IsolationLevel isolationLevel = IsolationLevel.ReadCommitted)
        {
            using var transaction = connection.BeginTransaction(isolationLevel);
            try
            {
                Console.WriteLine("Transaction started.");
                await transactionAction(transaction); // Await the asynchronous delegate
                transaction.Commit();
                Console.WriteLine("Transaction committed.");
            }
            catch (Exception ex)
            {
                transaction.Rollback();
                Console.WriteLine($"Transaction rolled back due to error: {ex.Message}");
                throw; // Re-throw the exception for the caller to handle
            }
        }

        public static void AddParameter(this SqlCommand command, string parameterName, object value)
        {
            if (command != null)
            {
                command.Parameters.Add(new SqlParameter(parameterName, value ?? DBNull.Value));
            }
        }

        // Add multiple parameters to a SqlCommand in one go.
        //USUAGE:
        //  command.AddParameters(
        //      new SqlParameter("@Id", 123),
        //      new SqlParameter("@Name", "Test")
        //  );
        public static void AddParameters(this SqlCommand command, params SqlParameter[] parameters)
        {
            if (parameters != null)
            {
                foreach (var param in parameters)
                {
                    command.Parameters.Add(param);
                }
            }
        }

        // Add multiple parameters to a SqlCommand in one go using a dictionary.
        //USUAGE:
        //  command.AddParameters(new Dictionary<string, object>
        //  {
        //      { "@Id", 123 },
        //      { "@Name", "Test" }
        //  });
        public static void AddParameters(this SqlCommand command, Dictionary<string, object> parameters)
        {
            if (parameters != null)
            {
                foreach (var param in parameters)
                {
                    command.Parameters.Add(new SqlParameter(param.Key, param.Value ?? DBNull.Value));
                }
            }
        }

        // Create a SqlCommand and attach parameters in one method call.
        //USUAGE:
        //  using var command = connection.CreateCommandWithParameters("SELECT * FROM MyTable WHERE Id = @Id", CommandType.Text,
        //      new SqlParameter("@Id", 123));
        //  using SqlDataReader reader = command.ExecuteReader();
        public static SqlCommand CreateCommandWithParameters(this SqlConnection connection, string query, CommandType commandType = CommandType.Text, params SqlParameter[] parameters)
        {
            var command = connection.CreateCommand();
            command.CommandText = query;
            command.CommandType = commandType;
            command.AddParameters(parameters);
            return command;
        }

        public static SqlCommand CreateCommandWithParametersTransaction(
    this SqlConnection connection,
    string query,
    CommandType commandType = CommandType.Text,
    SqlTransaction? transaction = null,
    params SqlParameter[] parameters)
        {
            if (connection == null) throw new ArgumentNullException(nameof(connection));
            if (string.IsNullOrWhiteSpace(query)) throw new ArgumentException("Query cannot be null or empty.", nameof(query));

            var command = connection.CreateCommand();
            command.CommandText = query;
            command.CommandType = commandType;

            if (transaction != null)
            {
                command.Transaction = transaction;
            }

            if (parameters != null && parameters.Length > 0)
            {
                command.AddParameters(parameters);
            }

            return command;
        }

        // Execute a paginated query using OFFSET and FETCH NEXT.
        //USUAGE:
        //  command.CommandText = "SELECT * FROM MyTable ORDER BY Id";
        //  var pagedResults = command.ExecutePaginatedQuery(pageNumber: 1, pageSize: 10);
        public static DataTable ExecutePaginatedQuery(this SqlCommand command, int pageNumber, int pageSize)
        {
            command.CommandText += " OFFSET @Offset ROWS FETCH NEXT @Fetch ROWS ONLY";
            command.AddParameters(
                new SqlParameter("@Offset", (pageNumber - 1) * pageSize),
                new SqlParameter("@Fetch", pageSize)
            );
            return command.ExecuteToDataTable();
        }

        // Log details of a SqlCommand for debugging.
        //USUAGE:
        //  Console.WriteLine(command.GetCommandDebugInfo());
        public static string GetCommandDebugInfo(this SqlCommand command)
        {
            var parameters = string.Join(", ", command.Parameters.Cast<SqlParameter>().Select(p => $"{p.ParameterName}={p.Value}"));
            return $"Command: {command.CommandText}\nParameters: {parameters}";
        }

        // Check if a table exists in the database.
        //USUAGE:
        //  bool exists = connection.TableExists("MyTable");
        public static bool TableExists(this SqlConnection connection, string tableName)
        {
            using var command = connection.CreateCommand();
            command.CommandText = "SELECT COUNT(1) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = @TableName";
            command.AddParameters(new SqlParameter("@TableName", tableName));
            return (int)command.ExecuteScalar() > 0;
        }

        // Insert a record and return the generated identity value.
        //USUAGE:
        /*  command.CommandText = "INSERT INTO MyTable (Column1, Column2) VALUES (@Value1, @Value2)";
            command.AddParameters(
                    new SqlParameter("@Value1", "Test"),
                    new SqlParameter("@Value2", 123)
            );
            int newId = command.InsertAndReturnIdentity(); */

        public static int InsertAndReturnIdentity(this SqlCommand command)
        {
            command.CommandText += "; SELECT SCOPE_IDENTITY();";
            return Convert.ToInt32(command.ExecuteScalar());
        }

        /// <summary>
        /// Safely gets a field value of type T, handling nulls gracefully and allowing a default value.
        /// </summary>
        /// <typeparam name="T"> The type of the field. </typeparam>
        /// <param name="reader">       The SqlDataReader instance. </param>
        /// <param name="columnName">   The name of the column. </param>
        /// <param name="defaultValue"> The default value to return if the field is null. </param>
        /// <returns> The field value or the specified default value if the value is null. </returns>
        public static T GetFieldValueSafe<T>(this SqlDataReader reader, string columnName, T defaultValue = default!)
        {
            if (reader.HasColumn(columnName) && !reader.IsDBNull(reader.GetOrdinal(columnName)))
            {
                return reader.GetFieldValue<T>(reader.GetOrdinal(columnName));
            }

            return defaultValue;
        }
    }
}