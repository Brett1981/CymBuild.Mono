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
            command.Parameters.AddWithValue("@OutstandingAmount", request.OutstandingAmount);
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

        private static async Task<long> ResolveExternalTransactionIdAsync(
            SqlConnection connection,
            string dataset,
            string accountReference,
            int transactionTypeCode,
            string documentNo,
            string transactionReference,
            CancellationToken cancellationToken)
        {
            const string sql = @"
SELECT TOP (1) ID
FROM SFin.SageExternalTransactions
WHERE SageDataset = @SageDataset
  AND SageAccountReference = @SageAccountReference
  AND SageTransactionTypeCode = @SageTransactionTypeCode
  AND SageDocumentNo = @SageDocumentNo
  AND SageTransactionReference = @SageTransactionReference
  AND RowStatus NOT IN (0,254)
ORDER BY ID;";

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.AddWithValue("@SageDataset", dataset ?? string.Empty);
            command.Parameters.AddWithValue("@SageAccountReference", accountReference ?? string.Empty);
            command.Parameters.AddWithValue("@SageTransactionTypeCode", transactionTypeCode);
            command.Parameters.AddWithValue("@SageDocumentNo", documentNo ?? string.Empty);
            command.Parameters.AddWithValue("@SageTransactionReference", transactionReference ?? string.Empty);

            var result = await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false);
            return result is long id ? id : Convert.ToInt64(result);
        }

        private static async Task<long> ResolveExternalAllocationIdAsync(
            SqlConnection connection,
            long sourceExternalTransactionId,
            long targetExternalTransactionId,
            decimal allocatedAmount,
            DateTime? allocationDate,
            string sourceHash,
            CancellationToken cancellationToken)
        {
            const string sql = @"
SELECT TOP (1) ID
FROM SFin.SageExternalAllocations
WHERE SourceExternalTransactionID = @SourceExternalTransactionID
  AND TargetExternalTransactionID = @TargetExternalTransactionID
  AND AllocatedAmount = @AllocatedAmount
  AND ISNULL(AllocationDate, '19000101') = ISNULL(@AllocationDate, '19000101')
  AND SourceHash = @SourceHash
  AND RowStatus NOT IN (0,254)
ORDER BY ID;";

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