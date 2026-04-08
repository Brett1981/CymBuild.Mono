#nullable enable

using Concursus.Common.Shared.Models.Finance;
using Microsoft.Data.SqlClient;
using System;
using System.Data;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.EF.Finance
{
    public sealed class SageInboundPaymentIdempotencyRepository : ISageInboundPaymentIdempotencyRepository
    {
        private readonly Core _core;

        public SageInboundPaymentIdempotencyRepository(Core core)
        {
            _core = core ?? throw new ArgumentNullException(nameof(core));
        }

        public async Task<SageInboundStatusEnsureResult> EnsureAsync(
            SageInboundSyncTarget target,
            CancellationToken cancellationToken = default)
        {
            if (target is null)
            {
                throw new ArgumentNullException(nameof(target));
            }

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInboundDocumentStatus_Ensure]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@CymBuildEntityTypeID", target.CymBuildEntityTypeId);
            command.Parameters.AddWithValue("@CymBuildDocumentGuid", target.CymBuildDocumentGuid);
            command.Parameters.AddWithValue("@CymBuildDocumentID", target.CymBuildDocumentId);
            command.Parameters.AddWithValue("@InvoiceRequestID", target.InvoiceRequestId);
            command.Parameters.AddWithValue("@TransactionID", target.TransactionId);
            command.Parameters.AddWithValue("@JobID", target.JobId);
            command.Parameters.AddWithValue("@SageDataset", target.SageDataset ?? string.Empty);
            command.Parameters.AddWithValue("@SageAccountReference", target.SageAccountReference ?? string.Empty);
            command.Parameters.AddWithValue("@SageDocumentNo", target.SageDocumentNo ?? string.Empty);

            var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
            {
                Direction = ParameterDirection.InputOutput,
                Value = DBNull.Value
            };

            command.Parameters.Add(guidParameter);

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);

            return new SageInboundStatusEnsureResult
            {
                Guid = guidParameter.Value is Guid guid ? guid : Guid.Empty,
                ExistsAlready = false
            };
        }

        public async Task<SageInboundClaimResult> TryClaimAsync(
            Guid cymBuildDocumentGuid,
            CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInboundDocumentStatus_TryClaim]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@CymBuildDocumentGuid", cymBuildDocumentGuid);

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (!await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                return new SageInboundClaimResult { ClaimSucceeded = false };
            }

            return new SageInboundClaimResult
            {
                ClaimSucceeded = reader.GetBoolean(reader.GetOrdinal("ClaimSucceeded")),
                Id = reader.IsDBNull(reader.GetOrdinal("ID")) ? -1 : reader.GetInt64(reader.GetOrdinal("ID")),
                Guid = reader.IsDBNull(reader.GetOrdinal("Guid")) ? Guid.Empty : reader.GetGuid(reader.GetOrdinal("Guid")),
                CymBuildEntityTypeId = reader.IsDBNull(reader.GetOrdinal("CymBuildEntityTypeID")) ? -1 : reader.GetInt32(reader.GetOrdinal("CymBuildEntityTypeID")),
                CymBuildDocumentGuid = reader.IsDBNull(reader.GetOrdinal("CymBuildDocumentGuid")) ? Guid.Empty : reader.GetGuid(reader.GetOrdinal("CymBuildDocumentGuid")),
                CymBuildDocumentId = reader.IsDBNull(reader.GetOrdinal("CymBuildDocumentID")) ? -1 : reader.GetInt64(reader.GetOrdinal("CymBuildDocumentID")),
                InvoiceRequestId = reader.IsDBNull(reader.GetOrdinal("InvoiceRequestID")) ? -1 : reader.GetInt32(reader.GetOrdinal("InvoiceRequestID")),
                TransactionId = reader.IsDBNull(reader.GetOrdinal("TransactionID")) ? -1 : reader.GetInt64(reader.GetOrdinal("TransactionID")),
                JobId = reader.IsDBNull(reader.GetOrdinal("JobID")) ? -1 : reader.GetInt32(reader.GetOrdinal("JobID")),
                SageDataset = reader.IsDBNull(reader.GetOrdinal("SageDataset")) ? string.Empty : reader.GetString(reader.GetOrdinal("SageDataset")),
                SageAccountReference = reader.IsDBNull(reader.GetOrdinal("SageAccountReference")) ? string.Empty : reader.GetString(reader.GetOrdinal("SageAccountReference")),
                SageDocumentNo = reader.IsDBNull(reader.GetOrdinal("SageDocumentNo")) ? string.Empty : reader.GetString(reader.GetOrdinal("SageDocumentNo")),
                StatusCode = reader.IsDBNull(reader.GetOrdinal("StatusCode")) ? string.Empty : reader.GetString(reader.GetOrdinal("StatusCode")),
                IsInProgress = !reader.IsDBNull(reader.GetOrdinal("IsInProgress")) && reader.GetBoolean(reader.GetOrdinal("IsInProgress")),
                InProgressClaimedOnUtc = reader.IsDBNull(reader.GetOrdinal("InProgressClaimedOnUtc"))
                    ? null
                    : reader.GetDateTime(reader.GetOrdinal("InProgressClaimedOnUtc"))
            };
        }

        public async Task MarkSuccessAsync(
            Guid cymBuildDocumentGuid,
            DateTime? lastSourceWatermarkUtc,
            CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInboundDocumentStatus_MarkSuccess]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@CymBuildDocumentGuid", cymBuildDocumentGuid);
            command.Parameters.AddWithValue("@LastSourceWatermarkUtc", (object?)lastSourceWatermarkUtc ?? DBNull.Value);

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        public async Task MarkFailureAsync(
            Guid cymBuildDocumentGuid,
            string errorMessage,
            bool isRetryable,
            CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInboundDocumentStatus_MarkFailure]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@CymBuildDocumentGuid", cymBuildDocumentGuid);
            command.Parameters.AddWithValue("@ErrorMessage", errorMessage ?? string.Empty);
            command.Parameters.AddWithValue("@IsRetryable", isRetryable);

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }

        public async Task InsertAttemptAsync(
            long inboundStatusId,
            Guid cymBuildDocumentGuid,
            long cymBuildDocumentId,
            string operationName,
            DateTime attemptedOnUtc,
            DateTime? completedOnUtc,
            bool isSuccess,
            bool isRetryableFailure,
            string responseStatus,
            string? responseDetail,
            string? errorMessage,
            string? requestPayloadJson,
            string? responsePayloadJson,
            CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInboundDocumentAttempt_Insert]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@InboundStatusID", inboundStatusId);
            command.Parameters.AddWithValue("@CymBuildDocumentGuid", cymBuildDocumentGuid);
            command.Parameters.AddWithValue("@CymBuildDocumentID", cymBuildDocumentId);
            command.Parameters.AddWithValue("@OperationName", operationName ?? string.Empty);
            command.Parameters.AddWithValue("@AttemptedOnUtc", attemptedOnUtc);
            command.Parameters.AddWithValue("@CompletedOnUtc", (object?)completedOnUtc ?? DBNull.Value);
            command.Parameters.AddWithValue("@IsSuccess", isSuccess);
            command.Parameters.AddWithValue("@IsRetryableFailure", isRetryableFailure);
            command.Parameters.AddWithValue("@ResponseStatus", responseStatus ?? string.Empty);
            command.Parameters.AddWithValue("@ResponseDetail", (object?)responseDetail ?? DBNull.Value);
            command.Parameters.AddWithValue("@ErrorMessage", (object?)errorMessage ?? DBNull.Value);
            command.Parameters.AddWithValue("@RequestPayloadJson", (object?)requestPayloadJson ?? DBNull.Value);
            command.Parameters.AddWithValue("@ResponsePayloadJson", (object?)responsePayloadJson ?? DBNull.Value);

            var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
            {
                Direction = ParameterDirection.InputOutput,
                Value = DBNull.Value
            };

            command.Parameters.Add(guidParameter);

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }
    }
}