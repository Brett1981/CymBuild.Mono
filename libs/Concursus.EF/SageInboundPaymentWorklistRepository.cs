#nullable enable

using Concursus;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Data.SqlClient;
using System.Data;

namespace Concursus.EF
{
    public sealed class SageInboundPaymentWorklistRepository : ISageInboundPaymentWorklistRepository
    {
        private readonly Core _core;

        public SageInboundPaymentWorklistRepository(Core core)
        {
            _core = core ?? throw new ArgumentNullException(nameof(core));
        }

        public async Task<IReadOnlyList<SageInboundPaymentWorklistItem>> GetWorklistAsync(
            int batchSize,
            int claimStaleAfterMinutes,
            CancellationToken cancellationToken = default)
        {
            var results = new List<SageInboundPaymentWorklistItem>();

            await using var connection = _core.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInboundPaymentSync_Worklist]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.AddWithValue("@BatchSize", batchSize);
            command.Parameters.AddWithValue("@ClaimStaleAfterMinutes", claimStaleAfterMinutes);

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                results.Add(new SageInboundPaymentWorklistItem
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
                    StatusCode = reader.GetString(reader.GetOrdinal("StatusCode")),
                    IsInProgress = reader.GetBoolean(reader.GetOrdinal("IsInProgress")),
                    InProgressClaimedOnUtc = reader.IsDBNull(reader.GetOrdinal("InProgressClaimedOnUtc"))
                        ? null
                        : reader.GetDateTime(reader.GetOrdinal("InProgressClaimedOnUtc")),
                    LastSucceededOnUtc = reader.IsDBNull(reader.GetOrdinal("LastSucceededOnUtc"))
                        ? null
                        : reader.GetDateTime(reader.GetOrdinal("LastSucceededOnUtc")),
                    LastFailedOnUtc = reader.IsDBNull(reader.GetOrdinal("LastFailedOnUtc"))
                        ? null
                        : reader.GetDateTime(reader.GetOrdinal("LastFailedOnUtc")),
                    LastError = reader.IsDBNull(reader.GetOrdinal("LastError"))
                        ? string.Empty
                        : reader.GetString(reader.GetOrdinal("LastError")),
                    LastErrorIsRetryable = reader.IsDBNull(reader.GetOrdinal("LastErrorIsRetryable"))
                        ? null
                        : reader.GetBoolean(reader.GetOrdinal("LastErrorIsRetryable"))
                });
            }

            return results;
        }

        public async Task EnqueueAsync(
            Guid cymBuildDocumentGuid,
            bool forceRequeue,
            CancellationToken cancellationToken = default)
        {
            await using var connection = _core.CreateConnection();
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInboundPaymentSync_Enqueue]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add(new SqlParameter("@CymBuildDocumentGuid", SqlDbType.UniqueIdentifier)
            {
                Value = cymBuildDocumentGuid
            });

            command.Parameters.Add(new SqlParameter("@ForceRequeue", SqlDbType.Bit)
            {
                Value = forceRequeue
            });

            await command.ExecuteNonQueryAsync(cancellationToken).ConfigureAwait(false);
        }
    }
}