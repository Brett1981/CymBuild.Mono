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
       ISNULL(t.SageTransactionReference, N'') AS SageTransactionReference,
       s.LastSucceededOnUtc,
       s.LastFailedOnUtc,
       ISNULL(s.LastError, N'') AS LastError
FROM   SFin.TransactionSageSubmissionStatus AS s
LEFT JOIN SFin.Transactions AS t
 ON t.Guid = s.TransactionGuid
AND t.RowStatus NOT IN (0,254)
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
    string sageTransactionReference,
    string sageDataSet,
    string responseStatus,
    string responseDetail,
    string requestPayloadJson,
    string responsePayloadJson,
    int updatedByUserId,
    CancellationToken cancellationToken = default)
        {
            if (transactionGuid == Guid.Empty)
            {
                throw new ArgumentException("Transaction guid cannot be empty.", nameof(transactionGuid));
            }

            if (transitionGuid == Guid.Empty)
            {
                throw new ArgumentException("Transition guid cannot be empty.", nameof(transitionGuid));
            }

            await using var connection = _entityFramework.CreateConnection();
            await _entityFramework.OpenConnectionAsync(connection);

            await using var markSuccessCommand = QueryBuilder.CreateCommand(
                "[SFin].[TransactionSageSubmissionStatus_MarkSuccess]",
                connection,
                transaction: null);

            markSuccessCommand.CommandType = CommandType.StoredProcedure;

            markSuccessCommand.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier)
            {
                Value = transactionGuid
            });

            markSuccessCommand.Parameters.Add(new SqlParameter("@TransitionGuid", SqlDbType.UniqueIdentifier)
            {
                Value = transitionGuid
            });

            markSuccessCommand.Parameters.Add(new SqlParameter("@SageOrderId", SqlDbType.NVarChar, 100)
            {
                Value = string.IsNullOrWhiteSpace(sageOrderId)
                    ? DBNull.Value
                    : sageOrderId.Trim()
            });

            markSuccessCommand.Parameters.Add(new SqlParameter("@SageOrderNumber", SqlDbType.NVarChar, 100)
            {
                Value = string.IsNullOrWhiteSpace(sageOrderNumber)
                    ? DBNull.Value
                    : sageOrderNumber.Trim()
            });

            markSuccessCommand.Parameters.Add(new SqlParameter("@SageTransactionReference", SqlDbType.NVarChar, 100)
            {
                Value = string.IsNullOrWhiteSpace(sageTransactionReference)
                    ? DBNull.Value
                    : sageTransactionReference.Trim()
            });

            markSuccessCommand.Parameters.Add(new SqlParameter("@ResponseStatus", SqlDbType.NVarChar, 50)
            {
                Value = string.IsNullOrWhiteSpace(responseStatus)
                    ? DBNull.Value
                    : responseStatus.Trim()
            });

            markSuccessCommand.Parameters.Add(new SqlParameter("@ResponseDetail", SqlDbType.NVarChar)
            {
                Value = string.IsNullOrWhiteSpace(responseDetail)
                    ? DBNull.Value
                    : responseDetail.Trim()
            });

            markSuccessCommand.Parameters.Add(new SqlParameter("@RequestPayloadJson", SqlDbType.NVarChar)
            {
                Value = string.IsNullOrWhiteSpace(requestPayloadJson)
                    ? DBNull.Value
                    : requestPayloadJson
            });

            markSuccessCommand.Parameters.Add(new SqlParameter("@ResponsePayloadJson", SqlDbType.NVarChar)
            {
                Value = string.IsNullOrWhiteSpace(responsePayloadJson)
                    ? DBNull.Value
                    : responsePayloadJson
            });

            markSuccessCommand.Parameters.Add(new SqlParameter("@UpdatedByUserID", SqlDbType.Int)
            {
                Value = updatedByUserId
            });

            _ = await markSuccessCommand
                .ExecuteNonQueryAsync(cancellationToken)
                .ConfigureAwait(false);

            try
            {
                var sageDocumentNo = !string.IsNullOrWhiteSpace(sageOrderNumber)
                    ? sageOrderNumber.Trim()
                    : !string.IsNullOrWhiteSpace(sageTransactionReference)
                        ? sageTransactionReference.Trim()
                        : string.Empty;

                var normalisedSageDataSet = string.IsNullOrWhiteSpace(sageDataSet)
                    ? string.Empty
                    : sageDataSet.Trim();

                var enqueueTarget = await ResolveInboundEnqueueTargetAsync(
                        connection,
                        transactionGuid,
                        sageDocumentNo,
                        normalisedSageDataSet,
                        cancellationToken)
                    .ConfigureAwait(false);

                if (enqueueTarget is null)
                {
                    return;
                }

                await using var enqueueCommand = QueryBuilder.CreateCommand(
                    "[SFin].[SageInboundPaymentSync_Enqueue]",
                    connection,
                    transaction: null);

                enqueueCommand.CommandType = CommandType.StoredProcedure;

                enqueueCommand.Parameters.Add(new SqlParameter("@CymBuildEntityTypeID", SqlDbType.Int)
                {
                    Value = enqueueTarget.CymBuildEntityTypeId
                });

                enqueueCommand.Parameters.Add(new SqlParameter("@CymBuildDocumentGuid", SqlDbType.UniqueIdentifier)
                {
                    Value = enqueueTarget.CymBuildDocumentGuid
                });

                enqueueCommand.Parameters.Add(new SqlParameter("@CymBuildDocumentID", SqlDbType.BigInt)
                {
                    Value = enqueueTarget.CymBuildDocumentId
                });

                enqueueCommand.Parameters.Add(new SqlParameter("@InvoiceRequestID", SqlDbType.Int)
                {
                    Value = enqueueTarget.InvoiceRequestId
                });

                enqueueCommand.Parameters.Add(new SqlParameter("@TransactionID", SqlDbType.BigInt)
                {
                    Value = enqueueTarget.TransactionId
                });

                enqueueCommand.Parameters.Add(new SqlParameter("@JobID", SqlDbType.Int)
                {
                    Value = enqueueTarget.JobId
                });

                enqueueCommand.Parameters.Add(new SqlParameter("@SageDataset", SqlDbType.NVarChar, 30)
                {
                    Value = string.IsNullOrWhiteSpace(enqueueTarget.SageDataset)
                        ? string.Empty
                        : enqueueTarget.SageDataset.Trim()
                });

                enqueueCommand.Parameters.Add(new SqlParameter("@SageAccountReference", SqlDbType.NVarChar, 100)
                {
                    Value = string.IsNullOrWhiteSpace(enqueueTarget.SageAccountReference)
                        ? string.Empty
                        : enqueueTarget.SageAccountReference.Trim()
                });

                enqueueCommand.Parameters.Add(new SqlParameter("@SageDocumentNo", SqlDbType.NVarChar, 100)
                {
                    Value = string.IsNullOrWhiteSpace(enqueueTarget.SageDocumentNo)
                        ? sageDocumentNo
                        : enqueueTarget.SageDocumentNo.Trim()
                });

                enqueueCommand.Parameters.Add(new SqlParameter("@ForceRequeue", SqlDbType.Bit)
                {
                    Value = false
                });

                _ = await enqueueCommand
                    .ExecuteNonQueryAsync(cancellationToken)
                    .ConfigureAwait(false);
            }
            catch
            {
                // The outbound Sage submission has already been committed by
                // SFin.TransactionSageSubmissionStatus_MarkSuccess. A follow-up
                // inbound diagnostics enqueue issue must not throw back to the
                // worker, because it can make a successfully-created Sage order
                // look like a failed outbound submission.
            }
        }

        private sealed class SageInboundEnqueueTarget
        {
            public int CymBuildEntityTypeId { get; init; }
            public Guid CymBuildDocumentGuid { get; init; }
            public long CymBuildDocumentId { get; init; }
            public int InvoiceRequestId { get; init; }
            public long TransactionId { get; init; }
            public int JobId { get; init; }
            public string SageDataset { get; init; } = string.Empty;
            public string SageAccountReference { get; init; } = string.Empty;
            public string SageDocumentNo { get; init; } = string.Empty;
        }

        private static async Task<SageInboundEnqueueTarget?> ResolveInboundEnqueueTargetAsync(
    SqlConnection connection,
    Guid transactionGuid,
    string sageOrderNumber,
    string sageDataset,
    CancellationToken cancellationToken)
        {
            const string sql = @"
DECLARE @TransactionEntityTypeID INT = NULL;
DECLARE @InvoiceRequestEntityTypeID INT = NULL;

SELECT TOP (1)
    @TransactionEntityTypeID = et.ID
FROM SCore.EntityTypes AS et
WHERE et.RowStatus NOT IN (0, 254)
  AND et.Name IN (N'Transactions', N'Finance Transactions', N'Transaction')
ORDER BY
    CASE et.Name
        WHEN N'Transactions' THEN 1
        WHEN N'Finance Transactions' THEN 2
        WHEN N'Transaction' THEN 3
        ELSE 4
    END,
    et.ID;

SELECT TOP (1)
    @InvoiceRequestEntityTypeID = et.ID
FROM SCore.EntityTypes AS et
WHERE et.RowStatus NOT IN (0, 254)
  AND et.Name IN (N'Invoice Requests', N'InvoiceRequests', N'Invoice Request')
ORDER BY
    CASE et.Name
        WHEN N'Invoice Requests' THEN 1
        WHEN N'InvoiceRequests' THEN 2
        WHEN N'Invoice Request' THEN 3
        ELSE 4
    END,
    et.ID;

;WITH TransactionBase AS
(
    SELECT TOP (1)
        t.ID,
        t.Guid,
        t.JobID,
        t.AccountID,
        t.Number,
        t.ReservedInvoiceNumber,
        t.SageInvoiceNumber,
        t.SageSalesOrderNumber,
        t.SageTransactionReference
    FROM SFin.Transactions AS t
    WHERE t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0, 254)
    ORDER BY t.ID DESC
),
InvoiceRequestTarget AS
(
    SELECT TOP (1)
        SortOrder             = 1,
        CymBuildEntityTypeID  = @InvoiceRequestEntityTypeID,
        CymBuildDocumentGuid  = ir.Guid,
        CymBuildDocumentID    = CAST(ir.ID AS BIGINT),
        InvoiceRequestID      = ir.ID,
        TransactionID         = tb.ID,
        JobID                 = COALESCE(NULLIF(ir.JobId, -1), NULLIF(tb.JobID, -1), -1),
        SageDataset           = ISNULL(NULLIF(@SageDataset, N''), N''),
        SageAccountReference  = ISNULL(a.Code, N''),
        SageDocumentNo        =
            COALESCE
            (
                NULLIF(@SageOrderNumber, N''),
                NULLIF(tb.SageSalesOrderNumber, N''),
                NULLIF(tb.SageInvoiceNumber, N''),
                NULLIF(tb.ReservedInvoiceNumber, N''),
                NULLIF(tb.Number, N''),
                N''
            )
    FROM TransactionBase AS tb
    JOIN SFin.TransactionDetails AS td
        ON td.TransactionID = tb.ID
       AND td.RowStatus NOT IN (0, 254)
    JOIN SFin.InvoiceRequestItems AS iri
        ON iri.ID = td.InvoiceRequestItemId
       AND iri.RowStatus NOT IN (0, 254)
    JOIN SFin.InvoiceRequests AS ir
        ON ir.ID = iri.InvoiceRequestId
       AND ir.RowStatus NOT IN (0, 254)
    LEFT JOIN SCrm.Accounts AS a
        ON a.ID = tb.AccountID
       AND a.RowStatus NOT IN (0, 254)
    WHERE @InvoiceRequestEntityTypeID IS NOT NULL
),
TransactionTarget AS
(
    SELECT TOP (1)
        SortOrder             = 2,
        CymBuildEntityTypeID  = @TransactionEntityTypeID,
        CymBuildDocumentGuid  = tb.Guid,
        CymBuildDocumentID    = CAST(tb.ID AS BIGINT),
        InvoiceRequestID      = -1,
        TransactionID         = tb.ID,
        JobID                 = COALESCE(NULLIF(tb.JobID, -1), -1),
        SageDataset           = ISNULL(NULLIF(@SageDataset, N''), N''),
        SageAccountReference  = ISNULL(a.Code, N''),
        SageDocumentNo        =
            COALESCE
            (
                NULLIF(@SageOrderNumber, N''),
                NULLIF(tb.SageSalesOrderNumber, N''),
                NULLIF(tb.SageInvoiceNumber, N''),
                NULLIF(tb.ReservedInvoiceNumber, N''),
                NULLIF(tb.Number, N''),
                N''
            )
    FROM TransactionBase AS tb
    LEFT JOIN SCrm.Accounts AS a
        ON a.ID = tb.AccountID
       AND a.RowStatus NOT IN (0, 254)
    WHERE @TransactionEntityTypeID IS NOT NULL
)
SELECT TOP (1)
    r.CymBuildEntityTypeID,
    r.CymBuildDocumentGuid,
    r.CymBuildDocumentID,
    r.InvoiceRequestID,
    r.TransactionID,
    r.JobID,
    r.SageDataset,
    r.SageAccountReference,
    r.SageDocumentNo
FROM
(
    SELECT
        irt.SortOrder,
        irt.CymBuildEntityTypeID,
        irt.CymBuildDocumentGuid,
        irt.CymBuildDocumentID,
        irt.InvoiceRequestID,
        irt.TransactionID,
        irt.JobID,
        irt.SageDataset,
        irt.SageAccountReference,
        irt.SageDocumentNo
    FROM InvoiceRequestTarget AS irt

    UNION ALL

    SELECT
        tt.SortOrder,
        tt.CymBuildEntityTypeID,
        tt.CymBuildDocumentGuid,
        tt.CymBuildDocumentID,
        tt.InvoiceRequestID,
        tt.TransactionID,
        tt.JobID,
        tt.SageDataset,
        tt.SageAccountReference,
        tt.SageDocumentNo
    FROM TransactionTarget AS tt
) AS r
WHERE r.CymBuildEntityTypeID IS NOT NULL
  AND r.CymBuildDocumentGuid IS NOT NULL
  AND r.TransactionID > 0
ORDER BY r.SortOrder;";

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.Add(new SqlParameter("@TransactionGuid", SqlDbType.UniqueIdentifier)
            {
                Value = transactionGuid
            });

            command.Parameters.Add(new SqlParameter("@SageOrderNumber", SqlDbType.NVarChar, 100)
            {
                Value = string.IsNullOrWhiteSpace(sageOrderNumber)
                    ? string.Empty
                    : sageOrderNumber.Trim()
            });

            command.Parameters.Add(new SqlParameter("@SageDataset", SqlDbType.NVarChar, 30)
            {
                Value = string.IsNullOrWhiteSpace(sageDataset)
                    ? string.Empty
                    : sageDataset.Trim()
            });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                return null;
            }

            return new SageInboundEnqueueTarget
            {
                CymBuildEntityTypeId = reader.GetInt32(reader.GetOrdinal("CymBuildEntityTypeID")),
                CymBuildDocumentGuid = reader.GetGuid(reader.GetOrdinal("CymBuildDocumentGuid")),
                CymBuildDocumentId = reader.GetInt64(reader.GetOrdinal("CymBuildDocumentID")),
                InvoiceRequestId = reader.GetInt32(reader.GetOrdinal("InvoiceRequestID")),
                TransactionId = reader.GetInt64(reader.GetOrdinal("TransactionID")),
                JobId = reader.GetInt32(reader.GetOrdinal("JobID")),
                SageDataset = reader.GetString(reader.GetOrdinal("SageDataset")),
                SageAccountReference = reader.GetString(reader.GetOrdinal("SageAccountReference")),
                SageDocumentNo = reader.GetString(reader.GetOrdinal("SageDocumentNo"))
            };
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