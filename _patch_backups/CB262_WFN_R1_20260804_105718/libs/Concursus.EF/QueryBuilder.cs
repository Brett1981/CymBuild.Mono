using Concursus.EF.Types;
using Google.Protobuf.WellKnownTypes;
using Microsoft.Data.SqlClient;
using System.Data;

namespace Concursus.EF
{
    public static class QueryBuilder
    {
        #region Public Methods

        public static SqlTransaction BeginTransaction(SqlConnection connection, System.Data.IsolationLevel isolationLevel = System.Data.IsolationLevel.ReadCommitted)
        {
            SqlTransaction transaction = connection.BeginTransaction(isolationLevel);

            return transaction;
        }

        public static async Task CloseConnectionAsync(SqlConnection connection)
        {
            if (connection is not null)
            {
                if (connection.State == System.Data.ConnectionState.Open)
                {
                    await connection.CloseAsync();
                }
            }
        }

        public static SqlParameter[] CloneParams(IEnumerable<SqlParameter> src)
        => src.Select(p =>
        {
            // Name + Value is usually enough; ADO.NET infers DbType
            var clone = new SqlParameter(p.ParameterName, p.Value ?? DBNull.Value)
            {
                Direction = p.Direction,
                IsNullable = p.IsNullable,
                Size = p.Size,
                Precision = p.Precision,
                Scale = p.Scale
            };
            // If we set SqlDbType/TypeName elsewhere, copy them too:
            if (p.SqlDbType != SqlDbType.Variant && p.SqlDbType != 0) clone.SqlDbType = p.SqlDbType;
            if (!string.IsNullOrEmpty(p.TypeName)) clone.TypeName = p.TypeName;
            return clone;
        }).ToArray();

        /// <summary>
        /// Sets the isolation level of the given SQL connection to ReadUncommitted, so all
        /// following commands use NOLOCK. Call immediately after opening your SqlConnection.
        /// </summary>
        public static async Task SetReadUncommittedAsync(SqlConnection connection)
        {
            if (connection == null)
                throw new ArgumentNullException(nameof(connection));
            using (var cmd = new SqlCommand("SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;", connection))
            {
                await cmd.ExecuteNonQueryAsync();
            }
        }

        /// <summary>
        /// Sets the isolation level of the given SQL connection to ReadCommitted, so all following
        /// commands use NOLOCK. Call immediately after opening your SqlConnection.
        /// </summary>
        public static async Task SetReadCommittedAsync(SqlConnection connection)
        {
            if (connection == null)
                throw new ArgumentNullException(nameof(connection));
            using (var cmd = new SqlCommand("SET TRANSACTION ISOLATION LEVEL READ COMMITTED;", connection))
            {
                await cmd.ExecuteNonQueryAsync();
            }
        }

        public static async Task CommitTransactionAsync(SqlTransaction transaction)
        {
            await transaction.CommitAsync();
        }

        public static SqlCommand CreateCommand(string statement, SqlConnection connection, SqlTransaction? transaction = null, int? timeoutSeconds = 120)
        {
            SqlCommand cmd = connection.CreateCommand();
            if (timeoutSeconds.HasValue) cmd.CommandTimeout = timeoutSeconds.Value;
            if (statement != null)
            {
                cmd.CommandText = statement;
            }

            if (transaction != null)
            {
                cmd.Transaction = transaction;
            }

            return cmd;
        }

        public static async Task RollbackTransactionAsync(SqlTransaction transaction)
        {
            await transaction.RollbackAsync();
        }

        #endregion Public Methods

        #region Internal Methods

        internal static SqlCommand BuildCommandForEntityQuery(EntityQuery entityQuery, DataObject dataObject, List<EntityQueryParameterValue> entityQueryParameterValues, SqlConnection connection, SqlTransaction? transaction)
        {
            var command = CreateCommand(entityQuery.Statement, connection, transaction);
            if (transaction != null)
            {
                command.Transaction = transaction; // Ensure transaction is set
            }
            // Build the parameters for the Query
            foreach (EntityQueryParameter eqp in entityQuery.EntityQueryParameters)
            {
                try
                {
                    if (eqp.Name == "@RowStatus")
                    {
                        command.Parameters.Add(new SqlParameter(eqp.Name, dataObject.RowStatus));
                        continue;
                    }
                    else if (eqp.Name == "@Guid")
                    {
                        command.Parameters.Add(new SqlParameter(eqp.Name, dataObject.Guid));
                        continue;
                    }
                    else
                    {
                        DataProperty? dataProperty = dataObject.DataProperties
                            .Where<DataProperty>(p => p.EntityPropertyGuid == eqp.MappedEntityPropertyGuid)
                            .FirstOrDefault();

                        Any? parameterValue = null;

                        if (dataProperty != null)
                        {
                            parameterValue = dataProperty.Value;
                        }

                        if (parameterValue is null && entityQueryParameterValues.Count > 0)
                        {
                            EntityQueryParameterValue? entityQueryParameterValue = entityQueryParameterValues
                                .Where<EntityQueryParameterValue>(eqpv => eqpv.Name == eqp.Name)
                                .FirstOrDefault();

                            if (entityQueryParameterValue != null)
                            {
                                parameterValue = entityQueryParameterValue.Value;
                            }
                        }

                        if (parameterValue is null)
                        {
                            if (dataProperty is null)
                            {
                                string suppliedDataProperties = "";

                                if (dataObject.DataProperties.Count > 0)
                                {
                                    foreach (DataProperty dp in dataObject.DataProperties)
                                    {
                                        suppliedDataProperties = suppliedDataProperties + dp.EntityPropertyGuid.ToString() + "\r\n ";
                                    }

                                    if (dataObject.DataProperties.Count < 1)
                                    {
                                        throw new Exception("DataObject DateProperties was empty (" + dataObject.DataProperties.Count.ToString() + ")");
                                    }

                                    if (suppliedDataProperties.Length < 1)
                                    {
                                        throw new Exception("suppliedDataProperties empty");
                                    }

                                    throw new Exception("No value for parameter " + eqp.Name + " and no matching data property (" + eqp.MappedEntityPropertyGuid + ") was supplied (" + suppliedDataProperties + ").");
                                }
                                else
                                {
                                    throw new Exception("Record is unavailable, This may have been deleted");
                                }
                            }
                            else
                            {
                                throw new Exception("No value for parameter " + eqp.Name);
                            }
                        }

                        if (parameterValue.TypeUrl == "type.googleapis.com/google.protobuf.Empty")
                        {
                            command.Parameters.Add(new SqlParameter(eqp.Name, DBNull.Value));
                        }
                        else
                        {
                            switch (eqp.EntityDataType.Name)
                            {
                                case "NVARCHAR":
                                case "NVARCHAR(MAX)":
                                    command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<StringValue>().Value));
                                    break;

                                case "INT":
                                case "SMALLINT":
                                case "TINYINT":
                                    command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<Int32Value>().Value));
                                    break;

                                case "BIGINT":
                                    command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<Int64Value>().Value));
                                    break;

                                case "DOUBLE":
                                    //OE: CBLD-375
                                    if (eqp.Name == "@Longitude" || eqp.Name == "@Latitude")
                                    {
                                        // Unpack the DoubleValue and round to 6 decimal places
                                        double originalValue = parameterValue.Unpack<DoubleValue>().Value;

                                        SqlParameter SqlParam = new SqlParameter
                                        {
                                            ParameterName = eqp.Name,
                                            SqlDbType = SqlDbType.Decimal,
                                            Value = originalValue,
                                            Scale = 6, //6 decimal places
                                            Precision = 9, //Number of digits in total (3 (max of 180) + 6 (decimal places))
                                        };

                                        command.Parameters.Add(SqlParam);
                                    }
                                    else
                                    {
                                        command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<DoubleValue>().Value));
                                    }
                                    break;

                                case "BIT":
                                    command.Parameters.Add(new SqlParameter(eqp.Name, parameterValue.Unpack<BoolValue>().Value));
                                    break;

                                case "DATETIME2":
                                    {
                                        var raw = parameterValue.Unpack<Timestamp>().ToDateTime(); // returns Kind = Unspecified
                                        //var utc = DateTime.SpecifyKind(raw, DateTimeKind.Local).ToUniversalTime();

                                        Console.WriteLine($"[BuildCommandForEntityQuery] DATETIME2 RAW: {raw} (Kind: {raw.Kind})");
                                        //Console.WriteLine($"[BuildCommandForEntityQuery] DATETIME2 TO UTC: {utc} (Kind: {utc.Kind})");

                                        command.Parameters.Add(new SqlParameter(eqp.Name, raw));
                                        break;
                                    }

                                case "DATE":
                                    {
                                        var raw = parameterValue.Unpack<Timestamp>().ToDateTime();
                                        //var utc = DateTime.SpecifyKind(raw, DateTimeKind.Local).ToUniversalTime();

                                        Console.WriteLine($"[BuildCommandForEntityQuery] DATE RAW: {raw} (Kind: {raw.Kind})");
                                        //Console.WriteLine($"[BuildCommandForEntityQuery] DATE TO UTC: {utc} (Kind: {utc.Kind})");

                                        command.Parameters.Add(new SqlParameter(eqp.Name, raw));
                                        break;
                                    }

                                case "UNIQUEIDENTIFIER":
                                    command.Parameters.Add(new SqlParameter(eqp.Name, Guid.Parse(parameterValue.Unpack<StringValue>().Value)));
                                    break;

                                default:
                                    throw new NotImplementedException(eqp.EntityDataType.Name + " is not implimented.");
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    throw new Exception("Build Command Exception for parameter " + eqp.Name + " : " + ex.Message);
                }
            }

            return command;
        }

        #endregion Internal Methods
    }
}