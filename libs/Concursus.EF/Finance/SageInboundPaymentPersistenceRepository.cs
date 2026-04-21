#nullable enable

using Concursus.Common.Shared.Models.Finance;
using Microsoft.Data.SqlClient;
using System;
using System.Data;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.EF.Finance
{
    public sealed class SageInboundPaymentPersistenceRepository : ISageInboundPaymentPersistenceRepository
    {
        private readonly Core _core;

        public SageInboundPaymentPersistenceRepository(Core core)
        {
            _core = core ?? throw new ArgumentNullException(nameof(core));
        }

        public async Task<long> UpsertExternalTransactionAsync(
    SageExternalTransactionUpsertRequest request,
    CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(request);

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageExternalTransaction_Upsert]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@SageDataset", request.SageDataset ?? string.Empty);
            command.Parameters.AddWithValue("@SageAccountReference", request.SageAccountReference ?? string.Empty);
            command.Parameters.AddWithValue("@SageDocumentNo", request.SageDocumentNo ?? string.Empty);
            command.Parameters.AddWithValue("@SageTransactionReference", request.SageTransactionReference ?? string.Empty);
            command.Parameters.AddWithValue("@SecondReference", request.SecondReference ?? string.Empty);
            command.Parameters.AddWithValue("@SageTransactionTypeCode", request.SageTransactionTypeCode);
            command.Parameters.AddWithValue("@TransactionDate", (object?)request.TransactionDateUtc?.Date ?? DBNull.Value);
            command.Parameters.AddWithValue("@NetAmount", request.NetAmount);
            command.Parameters.AddWithValue("@TaxAmount", request.TaxAmount);
            command.Parameters.AddWithValue("@GrossAmount", request.GrossAmount);
            command.Parameters.AddWithValue("@AllocatedValue", request.AllocatedValue);
            command.Parameters.AddWithValue("@OutstandingAmount", request.OutstandingAmount);
            command.Parameters.AddWithValue("@DocumentDiscountedValue", request.DocumentDiscountedValue);
            command.Parameters.AddWithValue("@IsPaid", request.IsPaid);
            command.Parameters.AddWithValue("@IsFullyPaid", request.IsFullyPaid);
            command.Parameters.AddWithValue("@PaymentStateCode", request.PaymentStateCode ?? string.Empty);
            command.Parameters.AddWithValue("@MatchedTransactionID", request.MatchedTransactionId);
            command.Parameters.AddWithValue("@MatchedInvoiceRequestID", request.MatchedInvoiceRequestId);
            command.Parameters.AddWithValue("@MatchedJobID", request.MatchedJobId);
            command.Parameters.AddWithValue("@SourceHash", request.SourceHash ?? string.Empty);
            command.Parameters.AddWithValue("@RawPayloadJson", (object?)request.RawPayloadJson ?? DBNull.Value);

            var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
            {
                Direction = ParameterDirection.InputOutput,
                Value = DBNull.Value
            };
            command.Parameters.Add(guidParameter);

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);

            return await ResolveExternalTransactionIdAsync(
                connection,
                request.SageDataset,
                request.SageAccountReference,
                request.SageTransactionTypeCode,
                request.SageDocumentNo,
                request.SageTransactionReference,
                cancellationToken).ConfigureAwait(false);
        }

        public async Task<long> UpsertExternalAllocationAsync(
            SageExternalAllocationUpsertRequest request,
            CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(request);

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageExternalAllocation_Upsert]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@SourceExternalTransactionID", request.SourceExternalTransactionId);
            command.Parameters.AddWithValue("@TargetExternalTransactionID", request.TargetExternalTransactionId);
            command.Parameters.AddWithValue("@AllocatedAmount", request.AllocatedAmount);
            command.Parameters.AddWithValue("@AllocationDate", (object?)request.AllocationDateUtc?.Date ?? DBNull.Value);
            command.Parameters.AddWithValue("@MatchedSourceTransactionID", request.MatchedSourceTransactionId);
            command.Parameters.AddWithValue("@MatchedTargetTransactionID", request.MatchedTargetTransactionId);
            command.Parameters.AddWithValue("@SourceHash", request.SourceHash ?? string.Empty);
            command.Parameters.AddWithValue("@RawPayloadJson", (object?)request.RawPayloadJson ?? DBNull.Value);

            var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
            {
                Direction = ParameterDirection.InputOutput,
                Value = DBNull.Value
            };
            command.Parameters.Add(guidParameter);

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);

            return await ResolveExternalAllocationIdAsync(
                connection,
                request.SourceExternalTransactionId,
                request.TargetExternalTransactionId,
                request.AllocatedAmount,
                request.AllocationDateUtc?.Date,
                request.SourceHash,
                cancellationToken).ConfigureAwait(false);
        }

        public async Task<SageReconcileInvoiceResult> ReconcileInvoiceAsync(
            long externalTransactionId,
            CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInbound_ReconcileInvoiceTransaction]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@ExternalTransactionID", externalTransactionId);

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                return new SageReconcileInvoiceResult
                {
                    ExternalTransactionId = externalTransactionId,
                    IsMatched = false,
                    MatchRule = "NoResult"
                };
            }

            return new SageReconcileInvoiceResult
            {
                ExternalTransactionId = reader.GetInt64(reader.GetOrdinal("ExternalTransactionID")),
                IsMatched = reader.GetBoolean(reader.GetOrdinal("IsMatched")),
                MatchedTransactionId = reader.GetInt64(reader.GetOrdinal("MatchedTransactionID")),
                MatchedInvoiceRequestId = reader.GetInt32(reader.GetOrdinal("MatchedInvoiceRequestID")),
                MatchedJobId = reader.GetInt32(reader.GetOrdinal("MatchedJobID")),
                MatchRule = reader.GetString(reader.GetOrdinal("MatchRule"))
            };
        }

        public async Task<SageReconcileAllocationResult> ReconcileAllocationAsync(
            long externalAllocationId,
            CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInbound_ReconcileAllocations]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@ExternalAllocationID", externalAllocationId);

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                return new SageReconcileAllocationResult
                {
                    ExternalAllocationId = externalAllocationId,
                    IsFullyMatched = false
                };
            }

            return new SageReconcileAllocationResult
            {
                ExternalAllocationId = reader.GetInt64(reader.GetOrdinal("ExternalAllocationID")),
                IsFullyMatched = reader.GetBoolean(reader.GetOrdinal("IsFullyMatched")),
                MatchedSourceTransactionId = reader.GetInt64(reader.GetOrdinal("MatchedSourceTransactionID")),
                MatchedTargetTransactionId = reader.GetInt64(reader.GetOrdinal("MatchedTargetTransactionID"))
            };
        }

        public async Task ApplyInvoicePaymentStatusAsync(
            int invoiceRequestId,
            CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[InvoiceRequestPaymentStatus_ApplyFromSage]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@InvoiceRequestID", invoiceRequestId);
            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        public async Task<SageAggregatePaymentStateResult> ApplyAggregatePaymentStateAsync(
            long externalTransactionId,
            CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInbound_ApplyAggregatePaymentState]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@ExternalTransactionID", externalTransactionId);

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                return new SageAggregatePaymentStateResult
                {
                    ExternalTransactionId = externalTransactionId
                };
            }

            return new SageAggregatePaymentStateResult
            {
                ExternalTransactionId = reader.GetInt64(reader.GetOrdinal("ExternalTransactionID")),
                PaymentStateCode = reader.GetString(reader.GetOrdinal("PaymentStateCode")),
                GrossAmount = reader.GetDecimal(reader.GetOrdinal("GrossAmount")),
                AllocatedValue = reader.GetDecimal(reader.GetOrdinal("AllocatedValue")),
                OutstandingAmount = reader.GetDecimal(reader.GetOrdinal("OutstandingAmount")),
                DocumentDiscountedValue = reader.GetDecimal(reader.GetOrdinal("DocumentDiscountedValue")),
                IsPaid = reader.GetBoolean(reader.GetOrdinal("IsPaid")),
                IsFullyPaid = reader.GetBoolean(reader.GetOrdinal("IsFullyPaid"))
            };
        }

        public async Task UpdateInboundStatusFromExternalTransactionAsync(
            Guid cymBuildDocumentGuid,
            long externalTransactionId,
            DateTime? nextPollDueOnUtc,
            CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInboundDocumentStatus_UpdateFromExternalTransaction]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@CymBuildDocumentGuid", cymBuildDocumentGuid);
            command.Parameters.AddWithValue("@ExternalTransactionID", externalTransactionId);
            command.Parameters.AddWithValue("@NextPollDueOnUtc", (object?)nextPollDueOnUtc ?? DBNull.Value);

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        private static async Task<long> ResolveExternalTransactionIdAsync(
            SqlConnection connection,
            string sageDataset,
            string sageAccountReference,
            int sageTransactionTypeCode,
            string sageDocumentNo,
            string sageTransactionReference,
            CancellationToken cancellationToken)
        {
            const string sql = @"
SELECT TOP (1)
    ext.ID
FROM SFin.SageExternalTransactions AS ext
WHERE ext.RowStatus NOT IN (0,254)
  AND ext.SageDataset = @SageDataset
  AND ext.SageAccountReference = @SageAccountReference
  AND ext.SageTransactionTypeCode = @SageTransactionTypeCode
  AND ext.SageDocumentNo = @SageDocumentNo
  AND ext.SageTransactionReference = @SageTransactionReference
ORDER BY ext.ID DESC;";

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.AddWithValue("@SageDataset", sageDataset ?? string.Empty);
            command.Parameters.AddWithValue("@SageAccountReference", sageAccountReference ?? string.Empty);
            command.Parameters.AddWithValue("@SageTransactionTypeCode", sageTransactionTypeCode);
            command.Parameters.AddWithValue("@SageDocumentNo", sageDocumentNo ?? string.Empty);
            command.Parameters.AddWithValue("@SageTransactionReference", sageTransactionReference ?? string.Empty);

            var result = await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false);
            return result is long id ? id : Convert.ToInt64(result);
        }

        private static async Task<long> ResolveExternalAllocationIdAsync(
            SqlConnection connection,
            long sourceExternalTransactionId,
            long targetExternalTransactionId,
            decimal allocatedAmount,
            DateTime? allocationDate,
            string? sourceHash,
            CancellationToken cancellationToken)
        {
            const string sql = @"
SELECT TOP (1)
    ext.ID
FROM SFin.SageExternalAllocations AS ext
WHERE ext.RowStatus NOT IN (0,254)
  AND ext.SourceExternalTransactionID = @SourceExternalTransactionID
  AND ext.TargetExternalTransactionID = @TargetExternalTransactionID
  AND ext.AllocatedAmount = @AllocatedAmount
  AND ISNULL(ext.AllocationDate, CONVERT(date, '19000101')) = ISNULL(@AllocationDate, CONVERT(date, '19000101'))
  AND ext.SourceHash = @SourceHash
ORDER BY ext.ID DESC;";

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.AddWithValue("@SourceExternalTransactionID", sourceExternalTransactionId);
            command.Parameters.AddWithValue("@TargetExternalTransactionID", targetExternalTransactionId);
            command.Parameters.AddWithValue("@AllocatedAmount", allocatedAmount);
            command.Parameters.AddWithValue("@AllocationDate", (object?)allocationDate ?? DBNull.Value);
            command.Parameters.AddWithValue("@SourceHash", sourceHash ?? string.Empty);

            var result = await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false);
            return result is long id ? id : Convert.ToInt64(result);
        }
    }
}