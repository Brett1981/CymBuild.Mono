using Concursus.Common.Shared.Models.Finance;
using Concursus.Common.Shared.Services.Finance;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.EF.Finance
{
    public sealed class TransactionSageSubmissionAdminRepository : ITransactionSageSubmissionAdminRepository
    {
        private readonly Core _entityFramework;

        public TransactionSageSubmissionAdminRepository(Core entityFramework)
        {
            _entityFramework = entityFramework ?? throw new ArgumentNullException(nameof(entityFramework));
        }

        public async Task<TransactionSageSubmissionRequeueResult> RequeueAsync(
            IReadOnlyCollection<Guid> transactionGuids,
            CancellationToken cancellationToken = default)
        {
            if (transactionGuids is null || transactionGuids.Count == 0)
            {
                throw new ArgumentException("At least one transaction guid must be supplied.", nameof(transactionGuids));
            }

            var distinctGuids = transactionGuids
                .Where(x => x != Guid.Empty)
                .Distinct()
                .ToList();

            if (distinctGuids.Count == 0)
            {
                throw new ArgumentException("At least one valid transaction guid must be supplied.", nameof(transactionGuids));
            }

            var json = JsonSerializer.Serialize(distinctGuids.Select(x => x.ToString()));

            await using var connection = _entityFramework.CreateConnection();
            await _entityFramework.OpenConnectionAsync(connection);

            await using var command = QueryBuilder.CreateCommand(
                "[SFin].[TransactionSageSubmission_Requeue]",
                connection,
                transaction: null);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier)
            {
                Value = DBNull.Value
            });

            command.Parameters.Add(new SqlParameter("@TransactionGuidsJson", SqlDbType.NVarChar)
            {
                Value = json
            });

            var result = new TransactionSageSubmissionRequeueResult();

            await using var reader = await command.ExecuteReaderAsync(cancellationToken);

            if (await reader.ReadAsync(cancellationToken))
            {
                result.RequeuedTransactionCount = reader.GetInt32(reader.GetOrdinal("RequeuedTransactionCount"));
                result.ResetOutboxRowCount = reader.GetInt32(reader.GetOrdinal("ResetOutboxRowCount"));
                result.ResetStatusRowCount = reader.GetInt32(reader.GetOrdinal("ResetStatusRowCount"));
                result.Message = reader.GetString(reader.GetOrdinal("Message"));
            }

            if (await reader.NextResultAsync(cancellationToken))
            {
                while (await reader.ReadAsync(cancellationToken))
                {
                    result.Items.Add(new TransactionSageSubmissionRequeueResultItem
                    {
                        TransactionId = reader.GetInt64(reader.GetOrdinal("TransactionID")),
                        TransactionGuid = reader.GetGuid(reader.GetOrdinal("TransactionGuid")),
                        ResetStatusRow = reader.GetBoolean(reader.GetOrdinal("ResetStatusRow")),
                        ResetOutboxRows = reader.GetInt32(reader.GetOrdinal("ResetOutboxRows"))
                    });
                }
            }

            return result;
        }
    }
}