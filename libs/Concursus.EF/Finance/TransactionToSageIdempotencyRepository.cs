using System;
using System.Data;
using System.Threading;
using System.Threading.Tasks;
using Concursus.Common.Shared.Models.Finance;
using Concursus.Common.Shared.Services.Finance;
using Microsoft.Data.SqlClient;

namespace Concursus.EF.Finance
{
    public sealed class TransactionToSageIdempotencyRepository : ITransactionToSageIdempotencyRepository
    {
        private readonly Core _entityFramework;

        public TransactionToSageIdempotencyRepository(Core entityFramework)
        {
            _entityFramework = entityFramework ?? throw new ArgumentNullException(nameof(entityFramework));
        }

        public async Task<TransactionToSageIdempotencyStatus> GetStatusAsync(
            Guid transactionGuid,
            CancellationToken cancellationToken = default)
        {
            if (transactionGuid == Guid.Empty)
            {
                throw new ArgumentException("Transaction guid cannot be empty.", nameof(transactionGuid));
            }

            await using var connection = _entityFramework.CreateConnection();
            await _entityFramework.OpenConnectionAsync(connection);

            const string sql = """
SELECT TOP (1)
       s.TransactionGuid,
       CASE WHEN s.StatusCode = N'Succeeded' THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS IsAlreadyProcessed,
       s.IsInProgress,
       ISNULL(s.SageOrderId, N'') AS SageOrderId,
       ISNULL(s.SageOrderNumber, N'') AS SageOrderNumber,
       s.LastSucceededOnUtc,
       s.LastFailedOnUtc,
       ISNULL(s.LastError, N'') AS LastError
FROM   SFin.TransactionSageSubmissionStatus AS s
WHERE  s.TransactionGuid = @TransactionGuid
  AND  s.RowStatus NOT IN (0, 254);
""";

            await using var command = QueryBuilder.CreateCommand(sql, connection, transaction: null);
            command.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier)
            {
                Value = transactionGuid
            });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken);

            if (await reader.ReadAsync(cancellationToken))
            {
                return new TransactionToSageIdempotencyStatus
                {
                    TransactionGuid = reader.GetGuid(reader.GetOrdinal("TransactionGuid")),
                    IsAlreadyProcessed = reader.GetBoolean(reader.GetOrdinal("IsAlreadyProcessed")),
                    IsInProgress = reader.GetBoolean(reader.GetOrdinal("IsInProgress")),
                    SageOrderId = reader.GetString(reader.GetOrdinal("SageOrderId")),
                    SageOrderNumber = reader.GetString(reader.GetOrdinal("SageOrderNumber")),
                    LastSucceededOnUtc = reader.IsDBNull(reader.GetOrdinal("LastSucceededOnUtc"))
                        ? null
                        : reader.GetDateTime(reader.GetOrdinal("LastSucceededOnUtc")),
                    LastFailedOnUtc = reader.IsDBNull(reader.GetOrdinal("LastFailedOnUtc"))
                        ? null
                        : reader.GetDateTime(reader.GetOrdinal("LastFailedOnUtc")),
                    LastError = reader.GetString(reader.GetOrdinal("LastError"))
                };
            }

            return new TransactionToSageIdempotencyStatus
            {
                TransactionGuid = transactionGuid,
                IsAlreadyProcessed = false,
                IsInProgress = false
            };
        }

        public async Task<TransactionToSageIdempotencyClaimResult> TryClaimAsync(
            long transactionId,
            Guid transactionGuid,
            Guid transitionGuid,
            int updatedByUserId,
            int claimTimeoutMinutes,
            CancellationToken cancellationToken = default)
        {
            await using var connection = _entityFramework.CreateConnection();
            await _entityFramework.OpenConnectionAsync(connection);

            await using var command = QueryBuilder.CreateCommand(
                "[SFin].[TransactionSageSubmissionStatus_TryClaim]",
                connection,
                transaction: null);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.Add(new SqlParameter("@TransactionID", SqlDbType.BigInt) { Value = transactionId });
            command.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier) { Value = transactionGuid });
            command.Parameters.Add(new SqlParameter("@TransitionGuid", SqlDbType.UniqueIdentifier) { Value = transitionGuid });
            command.Parameters.Add(new SqlParameter("@CreatedByUserID", SqlDbType.Int) { Value = updatedByUserId });
            command.Parameters.Add(new SqlParameter("@ClaimTimeoutMinutes", SqlDbType.Int) { Value = claimTimeoutMinutes });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken);

            if (!await reader.ReadAsync(cancellationToken))
            {
                throw new InvalidOperationException("TryClaim did not return a result row.");
            }

            return new TransactionToSageIdempotencyClaimResult
            {
                TransactionGuid = transactionGuid,
                TransitionGuid = transitionGuid,
                ClaimAcquired = reader.GetBoolean(reader.GetOrdinal("ClaimAcquired")),
                AlreadyProcessed = reader.GetBoolean(reader.GetOrdinal("AlreadyProcessed")),
                InProgressElsewhere = reader.GetBoolean(reader.GetOrdinal("InProgressElsewhere")),
                StaleClaimReclaimed = reader.GetBoolean(reader.GetOrdinal("StaleClaimReclaimed")),
                StatusCode = reader.GetString(reader.GetOrdinal("StatusCode")),
                PreviousClaimedOnUtc = reader.IsDBNull(reader.GetOrdinal("PreviousClaimedOnUtc"))
                    ? null
                    : reader.GetDateTime(reader.GetOrdinal("PreviousClaimedOnUtc")),
                SageOrderId = reader.GetString(reader.GetOrdinal("SageOrderId")),
                SageOrderNumber = reader.GetString(reader.GetOrdinal("SageOrderNumber")),
                Message = reader.GetString(reader.GetOrdinal("Message")),
                EvaluatedOnUtc = DateTime.UtcNow
            };
        }

        public async Task MarkSuccessAsync(
            Guid transactionGuid,
            Guid transitionGuid,
            string sageOrderId,
            string sageOrderNumber,
            string responseStatus,
            string responseDetail,
            string requestPayloadJson,
            string responsePayloadJson,
            int updatedByUserId,
            CancellationToken cancellationToken = default)
        {
            await using var connection = _entityFramework.CreateConnection();
            await _entityFramework.OpenConnectionAsync(connection);

            await using var command = QueryBuilder.CreateCommand(
                "[SFin].[TransactionSageSubmissionStatus_MarkSuccess]",
                connection,
                transaction: null);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier) { Value = transactionGuid });
            command.Parameters.Add(new SqlParameter("@TransitionGuid", SqlDbType.UniqueIdentifier) { Value = transitionGuid });
            command.Parameters.Add(new SqlParameter("@SageOrderId", SqlDbType.NVarChar, 100) { Value = (object?)sageOrderId ?? DBNull.Value });
            command.Parameters.Add(new SqlParameter("@SageOrderNumber", SqlDbType.NVarChar, 100) { Value = (object?)sageOrderNumber ?? DBNull.Value });
            command.Parameters.Add(new SqlParameter("@ResponseStatus", SqlDbType.NVarChar, 50) { Value = (object?)responseStatus ?? DBNull.Value });
            command.Parameters.Add(new SqlParameter("@ResponseDetail", SqlDbType.NVarChar) { Value = (object?)responseDetail ?? DBNull.Value });
            command.Parameters.Add(new SqlParameter("@RequestPayloadJson", SqlDbType.NVarChar) { Value = (object?)requestPayloadJson ?? DBNull.Value });
            command.Parameters.Add(new SqlParameter("@ResponsePayloadJson", SqlDbType.NVarChar) { Value = (object?)responsePayloadJson ?? DBNull.Value });
            command.Parameters.Add(new SqlParameter("@UpdatedByUserID", SqlDbType.Int) { Value = updatedByUserId });

            _ = await command.ExecuteNonQueryAsync(cancellationToken);
        }

        public async Task MarkFailureAsync(
            Guid transactionGuid,
            Guid transitionGuid,
            string errorMessage,
            bool isRetryable,
            string responseStatus,
            string responseDetail,
            string requestPayloadJson,
            string responsePayloadJson,
            int updatedByUserId,
            CancellationToken cancellationToken = default)
        {
            await using var connection = _entityFramework.CreateConnection();
            await _entityFramework.OpenConnectionAsync(connection);

            await using var command = QueryBuilder.CreateCommand(
                "[SFin].[TransactionSageSubmissionStatus_MarkFailure]",
                connection,
                transaction: null);

            command.CommandType = CommandType.StoredProcedure;

            command.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier) { Value = transactionGuid });
            command.Parameters.Add(new SqlParameter("@TransitionGuid", SqlDbType.UniqueIdentifier) { Value = transitionGuid });
            command.Parameters.Add(new SqlParameter("@ErrorMessage", SqlDbType.NVarChar) { Value = (object?)errorMessage ?? DBNull.Value });
            command.Parameters.Add(new SqlParameter("@IsRetryable", SqlDbType.Bit) { Value = isRetryable });
            command.Parameters.Add(new SqlParameter("@ResponseStatus", SqlDbType.NVarChar, 50) { Value = (object?)responseStatus ?? DBNull.Value });
            command.Parameters.Add(new SqlParameter("@ResponseDetail", SqlDbType.NVarChar) { Value = (object?)responseDetail ?? DBNull.Value });
            command.Parameters.Add(new SqlParameter("@RequestPayloadJson", SqlDbType.NVarChar) { Value = (object?)requestPayloadJson ?? DBNull.Value });
            command.Parameters.Add(new SqlParameter("@ResponsePayloadJson", SqlDbType.NVarChar) { Value = (object?)responsePayloadJson ?? DBNull.Value });
            command.Parameters.Add(new SqlParameter("@UpdatedByUserID", SqlDbType.Int) { Value = updatedByUserId });

            _ = await command.ExecuteNonQueryAsync(cancellationToken);
        }
    }
}