using System;
using System.Collections.Generic;
using System.Data;
using System.Threading;
using System.Threading.Tasks;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Data.SqlClient;

namespace Concursus.EF.Finance
{
    public interface ISageInboundDiagnosticsRepository
    {
        Task<IReadOnlyList<SageInboundDiagnosticsRowModel>> GetAsync(Core entityFramework, SageInboundDiagnosticsGetRequestModel request, CancellationToken cancellationToken = default);
    }

    public sealed class SageInboundDiagnosticsRepository : ISageInboundDiagnosticsRepository
    {
        public async Task<IReadOnlyList<SageInboundDiagnosticsRowModel>> GetAsync(
            Core entityFramework,
            SageInboundDiagnosticsGetRequestModel request,
            CancellationToken cancellationToken = default)
        {
            if (entityFramework == null)
            {
                throw new ArgumentNullException(nameof(entityFramework));
            }

            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            const string sql = @"
SELECT
    d.ID,
    d.Guid,
    d.CymBuildEntityTypeID,
    d.CymBuildDocumentGuid,
    d.CymBuildDocumentID,
    d.InvoiceRequestID,
    d.TransactionID,
    d.JobID,
    d.SageDataset,
    d.SageAccountReference,
    d.SageDocumentNo,
    d.LastOperationName,
    d.StatusCode,
    d.IsInProgress,
    d.InProgressClaimedOnUtc,
    d.LastSucceededOnUtc,
    d.LastFailedOnUtc,
    d.LastError,
    d.LastErrorIsRetryable,
    d.LastSourceWatermarkUtc,
    d.UpdatedDateTimeUTC,
    d.LastAttemptedOnUtc,
    d.LastCompletedOnUtc,
    d.LastAttemptIsSuccess,
    d.LastAttemptErrorMessage,
    d.LastAttemptIsRetryableFailure,
    d.LastAttemptResponseStatus,
    d.LastAttemptResponseDetail,
    d.CanRequeue,
    d.CanForceRequeue
FROM SFin.tvf_SageInboundDiagnostics(
    @StatusCode,
    @SageAccountReference,
    @SageDocumentNo,
    @OnlyRetryableFailures,
    @InvoiceRequestID,
    @TransactionID,
    @JobID
) AS d
ORDER BY
    CASE d.StatusCode
        WHEN N'Failed' THEN 0
        WHEN N'RetryPending' THEN 1
        WHEN N'Pending' THEN 2
        WHEN N'Succeeded' THEN 3
        ELSE 4
    END,
    ISNULL(d.LastFailedOnUtc, CONVERT(DATETIME2(7), '1900-01-01T00:00:00')) DESC,
    d.SageAccountReference ASC,
    d.SageDocumentNo ASC,
    d.ID DESC;";

            var result = new List<SageInboundDiagnosticsRowModel>();
            SqlConnection? connection = null;

            try
            {
                connection = entityFramework.CreateConnection();
                await entityFramework.OpenConnectionAsync(connection).ConfigureAwait(false);

                using var command = QueryBuilder.CreateCommand(sql, connection);
                command.CommandType = CommandType.Text;
                command.Parameters.Add(new SqlParameter("@StatusCode", SqlDbType.NVarChar, 30) { Value = string.IsNullOrWhiteSpace(request.StatusCode) ? DBNull.Value : request.StatusCode.Trim() });
                command.Parameters.Add(new SqlParameter("@SageAccountReference", SqlDbType.NVarChar, 100) { Value = string.IsNullOrWhiteSpace(request.SageAccountReference) ? DBNull.Value : request.SageAccountReference.Trim() });
                command.Parameters.Add(new SqlParameter("@SageDocumentNo", SqlDbType.NVarChar, 100) { Value = string.IsNullOrWhiteSpace(request.SageDocumentNo) ? DBNull.Value : request.SageDocumentNo.Trim() });
                command.Parameters.Add(new SqlParameter("@OnlyRetryableFailures", SqlDbType.Bit) { Value = request.OnlyRetryableFailures.HasValue ? request.OnlyRetryableFailures.Value : DBNull.Value });
                command.Parameters.Add(new SqlParameter("@InvoiceRequestID", SqlDbType.Int) { Value = request.InvoiceRequestId.HasValue ? request.InvoiceRequestId.Value : DBNull.Value });
                command.Parameters.Add(new SqlParameter("@TransactionID", SqlDbType.BigInt) { Value = request.TransactionId.HasValue ? request.TransactionId.Value : DBNull.Value });
                command.Parameters.Add(new SqlParameter("@JobID", SqlDbType.Int) { Value = request.JobId.HasValue ? request.JobId.Value : DBNull.Value });

                using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
                while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
                {
                    result.Add(Map(reader));
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to load Sage inbound diagnostics. {ex.Message}", ex);
            }
            finally
            {
                if (connection != null && connection.State != ConnectionState.Closed)
                {
                    await connection.CloseAsync().ConfigureAwait(false);
                }

                connection?.Dispose();
            }

            return result;
        }

        private static SageInboundDiagnosticsRowModel Map(SqlDataReader reader)
        {
            return new SageInboundDiagnosticsRowModel
            {
                Id = reader.GetInt64(reader.GetOrdinal("ID")),
                Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                CymBuildEntityTypeId = reader.GetInt32(reader.GetOrdinal("CymBuildEntityTypeID")),
                CymBuildDocumentGuid = reader.GetGuid(reader.GetOrdinal("CymBuildDocumentGuid")),
                CymBuildDocumentId = reader.GetInt64(reader.GetOrdinal("CymBuildDocumentID")),
                InvoiceRequestId = reader.GetInt32(reader.GetOrdinal("InvoiceRequestID")),
                TransactionId = reader.GetInt64(reader.GetOrdinal("TransactionID")),
                JobId = reader.GetInt32(reader.GetOrdinal("JobID")),
                SageDataset = reader.GetString(reader.GetOrdinal("SageDataset")),
                SageAccountReference = reader.GetString(reader.GetOrdinal("SageAccountReference")),
                SageDocumentNo = reader.GetString(reader.GetOrdinal("SageDocumentNo")),
                LastOperationName = reader.GetString(reader.GetOrdinal("LastOperationName")),
                StatusCode = reader.GetString(reader.GetOrdinal("StatusCode")),
                IsInProgress = reader.GetBoolean(reader.GetOrdinal("IsInProgress")),
                InProgressClaimedOnUtc = GetNullableDateTime(reader, "InProgressClaimedOnUtc"),
                LastSucceededOnUtc = GetNullableDateTime(reader, "LastSucceededOnUtc"),
                LastFailedOnUtc = GetNullableDateTime(reader, "LastFailedOnUtc"),
                LastError = GetNullableString(reader, "LastError"),
                LastErrorIsRetryable = GetNullableBoolean(reader, "LastErrorIsRetryable"),
                LastSourceWatermarkUtc = GetNullableDateTime(reader, "LastSourceWatermarkUtc"),
                UpdatedDateTimeUtc = reader.GetDateTime(reader.GetOrdinal("UpdatedDateTimeUTC")),
                LastAttemptedOnUtc = GetNullableDateTime(reader, "LastAttemptedOnUtc"),
                LastCompletedOnUtc = GetNullableDateTime(reader, "LastCompletedOnUtc"),
                LastAttemptIsSuccess = GetNullableBoolean(reader, "LastAttemptIsSuccess"),
                LastAttemptErrorMessage = GetNullableString(reader, "LastAttemptErrorMessage"),
                LastAttemptIsRetryableFailure = GetNullableBoolean(reader, "LastAttemptIsRetryableFailure"),
                LastAttemptResponseStatus = GetNullableString(reader, "LastAttemptResponseStatus"),
                LastAttemptResponseDetail = GetNullableString(reader, "LastAttemptResponseDetail"),
                CanRequeue = reader.GetBoolean(reader.GetOrdinal("CanRequeue")),
                CanForceRequeue = reader.GetBoolean(reader.GetOrdinal("CanForceRequeue"))
            };
        }

        private static string GetNullableString(SqlDataReader reader, string columnName)
        {
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? string.Empty : reader.GetString(ordinal);
        }

        private static DateTime? GetNullableDateTime(SqlDataReader reader, string columnName)
        {
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? null : reader.GetDateTime(ordinal);
        }

        private static bool? GetNullableBoolean(SqlDataReader reader, string columnName)
        {
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? null : reader.GetBoolean(ordinal);
        }
    }
}
