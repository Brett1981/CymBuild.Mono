#nullable enable

using Concursus.Common.Shared.Models.Finance;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Data;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.EF.Finance
{
    public sealed class SageInboundDiagnosticsRepository : ISageInboundDiagnosticsRepository
    {
        private readonly Core _core;

        public SageInboundDiagnosticsRepository(Core core)
        {
            _core = core ?? throw new ArgumentNullException(nameof(core));
        }

        public async Task<SageInboundReceiptMaterialisationAutoCorrectResult> AutoCorrectReceiptMaterialisationAsync(
    long? externalTransactionId,
    int batchSize,
    bool dryRun,
    CancellationToken cancellationToken = default)
        {
            var result = new SageInboundReceiptMaterialisationAutoCorrectResult();

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInboundReceiptMaterialisation_AutoCorrect]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add(new SqlParameter("@ExternalTransactionID", SqlDbType.BigInt)
            {
                Value = externalTransactionId.HasValue ? externalTransactionId.Value : DBNull.Value
            });

            command.Parameters.Add(new SqlParameter("@BatchSize", SqlDbType.Int)
            {
                Value = batchSize <= 0 ? 100 : batchSize
            });

            command.Parameters.Add(new SqlParameter("@DryRun", SqlDbType.Bit)
            {
                Value = dryRun
            });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            if (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                result.ProcessedCount = reader.GetInt32(reader.GetOrdinal("ProcessedCount"));
                result.CorrectedCount = reader.GetInt32(reader.GetOrdinal("CorrectedCount"));
                result.SkippedCount = reader.GetInt32(reader.GetOrdinal("SkippedCount"));
                result.FailedCount = reader.GetInt32(reader.GetOrdinal("FailedCount"));
            }

            if (await reader.NextResultAsync(cancellationToken).ConfigureAwait(false))
            {
                while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
                {
                    result.Items.Add(new SageInboundReceiptMaterialisationAutoCorrectResultItem
                    {
                        ExternalTransactionId = reader.GetInt64(reader.GetOrdinal("ExternalTransactionID")),
                        Outcome = reader.GetString(reader.GetOrdinal("Outcome")),
                        Message = reader.GetString(reader.GetOrdinal("Message")),
                        MatchedTransactionId = reader.IsDBNull(reader.GetOrdinal("MatchedTransactionID")) ? -1 : reader.GetInt64(reader.GetOrdinal("MatchedTransactionID")),
                        MaterialisedReceiptTransactionId = reader.IsDBNull(reader.GetOrdinal("MaterialisedReceiptTransactionID")) ? -1 : reader.GetInt64(reader.GetOrdinal("MaterialisedReceiptTransactionID")),
                        MaterialisedAllocationId = reader.IsDBNull(reader.GetOrdinal("MaterialisedAllocationID")) ? -1 : reader.GetInt64(reader.GetOrdinal("MaterialisedAllocationID"))
                    });
                }
            }

            return result;
        }

        public async Task<List<SageInboundDiagnosticsRowModel>> GetAsync(
            SageInboundDiagnosticsGetRequestModel request,
            CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(request);

            var results = new List<SageInboundDiagnosticsRowModel>();

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInboundDiagnostics_Get]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add(new SqlParameter("@StatusCode", SqlDbType.NVarChar, 30)
            {
                Value = string.IsNullOrWhiteSpace(request.StatusCode) ? DBNull.Value : request.StatusCode.Trim()
            });

            command.Parameters.Add(new SqlParameter("@SageAccountReference", SqlDbType.NVarChar, 100)
            {
                Value = string.IsNullOrWhiteSpace(request.SageAccountReference) ? DBNull.Value : request.SageAccountReference.Trim()
            });

            command.Parameters.Add(new SqlParameter("@SageDocumentNo", SqlDbType.NVarChar, 100)
            {
                Value = string.IsNullOrWhiteSpace(request.SageDocumentNo) ? DBNull.Value : request.SageDocumentNo.Trim()
            });

            command.Parameters.Add(new SqlParameter("@TransactionNumber", SqlDbType.NVarChar, 50)
            {
                Value = string.IsNullOrWhiteSpace(request.TransactionNumber) ? DBNull.Value : request.TransactionNumber.Trim()
            });

            command.Parameters.Add(new SqlParameter("@OnlyRetryableFailures", SqlDbType.Bit)
            {
                Value = request.OnlyRetryableFailures.HasValue ? request.OnlyRetryableFailures.Value : DBNull.Value
            });

            command.Parameters.Add(new SqlParameter("@InvoiceRequestID", SqlDbType.Int)
            {
                Value = request.InvoiceRequestId.HasValue ? request.InvoiceRequestId.Value : DBNull.Value
            });

            command.Parameters.Add(new SqlParameter("@TransactionID", SqlDbType.BigInt)
            {
                Value = request.TransactionId.HasValue ? request.TransactionId.Value : DBNull.Value
            });

            command.Parameters.Add(new SqlParameter("@JobID", SqlDbType.Int)
            {
                Value = request.JobId.HasValue ? request.JobId.Value : DBNull.Value
            });

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                results.Add(Map(reader));
            }

            return results;
        }

        public async Task<int> ApplyTransactionReferencesAsync(
    Guid? statusGuid = null,
    long? transactionId = null,
    bool dryRun = true,
    CancellationToken cancellationToken = default)
        {
            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[SageInboundDiagnostics_ApplyTransactionReferences]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add(new SqlParameter("@StatusGuid", SqlDbType.UniqueIdentifier)
            {
                Value = statusGuid.HasValue ? statusGuid.Value : DBNull.Value
            });

            command.Parameters.Add(new SqlParameter("@TransactionID", SqlDbType.BigInt)
            {
                Value = transactionId.HasValue ? transactionId.Value : DBNull.Value
            });

            command.Parameters.Add(new SqlParameter("@DryRun", SqlDbType.Bit)
            {
                Value = dryRun
            });

            var affected = 0;

            await using var reader = await command.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);

            while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
            {
                var wouldUpdateOrdinal = reader.GetOrdinal("WouldUpdate");
                var appliedOrdinal = reader.GetOrdinal("Applied");

                var wouldUpdate =
                    !reader.IsDBNull(wouldUpdateOrdinal) &&
                    reader.GetBoolean(wouldUpdateOrdinal);

                var applied =
                    !reader.IsDBNull(appliedOrdinal) &&
                    reader.GetBoolean(appliedOrdinal);

                if ((dryRun && wouldUpdate) || (!dryRun && applied))
                {
                    affected++;
                }
            }

            return affected;
        }

        private static SageInboundDiagnosticsRowModel Map(SqlDataReader reader)
        {
            return new SageInboundDiagnosticsRowModel
            {
                Id = GetInt64(reader, "ID"),
                Guid = GetGuid(reader, "Guid"),
                CymBuildEntityTypeId = GetInt32(reader, "CymBuildEntityTypeID"),
                CymBuildDocumentGuid = GetGuid(reader, "CymBuildDocumentGuid"),
                CymBuildDocumentId = GetInt64(reader, "CymBuildDocumentID"),
                InvoiceRequestId = GetInt32(reader, "InvoiceRequestID"),
                TransactionId = GetInt64(reader, "TransactionID"),
                JobId = GetInt32(reader, "JobID"),

                SageDataset = GetString(reader, "SageDataset"),
                SageAccountReference = GetString(reader, "SageAccountReference"),
                SageDocumentNo = GetString(reader, "SageDocumentNo"),
                LastOperationName = GetString(reader, "LastOperationName"),
                StatusCode = GetString(reader, "StatusCode"),
                IsInProgress = GetBool(reader, "IsInProgress"),
                InProgressClaimedOnUtc = GetDateTimeNullable(reader, "InProgressClaimedOnUtc"),
                LastSucceededOnUtc = GetDateTimeNullable(reader, "LastSucceededOnUtc"),
                LastFailedOnUtc = GetDateTimeNullable(reader, "LastFailedOnUtc"),
                LastError = GetString(reader, "LastError"),
                LastErrorIsRetryable = GetBoolNullable(reader, "LastErrorIsRetryable"),
                LastSourceWatermarkUtc = GetDateTimeNullable(reader, "LastSourceWatermarkUtc"),
                UpdatedDateTimeUtc = GetDateTime(reader, "UpdatedDateTimeUTC"),

                LastGrossAmount = GetDecimal(reader, "LastGrossAmount"),
                LastAllocatedValue = GetDecimal(reader, "LastAllocatedValue"),
                LastOutstandingAmount = GetDecimal(reader, "LastOutstandingAmount"),
                LastDocumentDiscountedValue = GetDecimal(reader, "LastDocumentDiscountedValue"),
                LastIsPaid = GetBool(reader, "LastIsPaid"),
                LastIsFullyPaid = GetBool(reader, "LastIsFullyPaid"),
                LastPaymentStateCode = GetString(reader, "LastPaymentStateCode"),
                LastTransactionDate = GetDateTimeNullable(reader, "LastTransactionDate"),
                LastSageTransactionReference = GetString(reader, "LastSageTransactionReference"),
                LastSecondReference = GetString(reader, "LastSecondReference"),
                LastSageTransactionTypeCode = GetInt32(reader, "LastSageTransactionTypeCode"),
                NextPollDueOnUtc = GetDateTimeNullable(reader, "NextPollDueOnUtc"),
                PollAttemptCount = GetInt32(reader, "PollAttemptCount"),
                IsTerminalState = GetBool(reader, "IsTerminalState"),

                LastAttemptedOnUtc = GetDateTimeNullable(reader, "LastAttemptedOnUtc"),
                LastCompletedOnUtc = GetDateTimeNullable(reader, "LastCompletedOnUtc"),
                LastAttemptIsSuccess = GetBoolNullable(reader, "LastAttemptIsSuccess"),
                LastAttemptErrorMessage = GetString(reader, "LastAttemptErrorMessage"),
                LastAttemptIsRetryableFailure = GetBoolNullable(reader, "LastAttemptIsRetryableFailure"),
                LastAttemptResponseStatus = GetString(reader, "LastAttemptResponseStatus"),
                LastAttemptResponseDetail = GetString(reader, "LastAttemptResponseDetail"),
                CanRequeue = GetBool(reader, "CanRequeue"),
                CanForceRequeue = GetBool(reader, "CanForceRequeue"),

                TransactionGuid = GetGuidNullable(reader, "TransactionGuid"),
                TransactionNumber = GetString(reader, "TransactionNumber"),
                TransactionIsBatched = GetBoolNullable(reader, "TransactionIsBatched"),

                MatchedTransactionGuid = GetGuidNullable(reader, "MatchedTransactionGuid"),
                MatchedTransactionNumber = GetString(reader, "MatchedTransactionNumber"),
                TransactionSageTransactionReference = GetString(reader, "TransactionSageTransactionReference"),
                MatchedTransactionSageTransactionReference = GetString(reader, "MatchedTransactionSageTransactionReference"),

                MaterialisedReceiptTransactionGuid = GetGuidNullable(reader, "MaterialisedReceiptTransactionGuid"),
                MaterialisedReceiptTransactionNumber = GetString(reader, "MaterialisedReceiptTransactionNumber"),

                MaterialisedAllocationGuid = GetGuidNullable(reader, "MaterialisedAllocationGuid"),
                MaterialisedAllocationId = GetInt64Nullable(reader, "MaterialisedAllocationID")
            };
        }

        public async Task<bool> SetTransactionSageReferenceIfMissingAsync(
    long transactionId,
    string sageTransactionReference,
    CancellationToken cancellationToken = default)
        {
            if (transactionId <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(transactionId), "Transaction id must be greater than zero.");
            }

            if (string.IsNullOrWhiteSpace(sageTransactionReference))
            {
                throw new ArgumentException("Sage transaction reference is required.", nameof(sageTransactionReference));
            }

            await using var connection = new SqlConnection(_core.CreateConnection().ConnectionString);
            await connection.OpenAsync(cancellationToken).ConfigureAwait(false);

            await using var command = new SqlCommand("[SFin].[TransactionSageReference_SetIfMissing]", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            command.Parameters.Add(new SqlParameter("@TransactionID", SqlDbType.BigInt)
            {
                Value = transactionId
            });

            command.Parameters.Add(new SqlParameter("@SageTransactionReference", SqlDbType.NVarChar, 100)
            {
                Value = sageTransactionReference.Trim()
            });

            var result = await command.ExecuteScalarAsync(cancellationToken).ConfigureAwait(false);

            return result != null && result != DBNull.Value && Convert.ToBoolean(result);
        }

        private static int Ord(SqlDataReader reader, string name) => reader.GetOrdinal(name);

        private static string GetString(SqlDataReader reader, string name)
        {
            var ordinal = Ord(reader, name);
            return reader.IsDBNull(ordinal) ? string.Empty : Convert.ToString(reader.GetValue(ordinal)) ?? string.Empty;
        }

        private static int GetInt32(SqlDataReader reader, string name)
        {
            var ordinal = Ord(reader, name);
            return reader.IsDBNull(ordinal) ? -1 : Convert.ToInt32(reader.GetValue(ordinal));
        }

        private static long GetInt64(SqlDataReader reader, string name)
        {
            var ordinal = Ord(reader, name);
            return reader.IsDBNull(ordinal) ? -1 : Convert.ToInt64(reader.GetValue(ordinal));
        }

        private static long? GetInt64Nullable(SqlDataReader reader, string name)
        {
            var ordinal = Ord(reader, name);
            return reader.IsDBNull(ordinal) ? null : Convert.ToInt64(reader.GetValue(ordinal));
        }

        private static decimal GetDecimal(SqlDataReader reader, string name)
        {
            var ordinal = Ord(reader, name);
            return reader.IsDBNull(ordinal) ? 0m : Convert.ToDecimal(reader.GetValue(ordinal));
        }

        private static bool GetBool(SqlDataReader reader, string name)
        {
            var ordinal = Ord(reader, name);
            return !reader.IsDBNull(ordinal) && Convert.ToBoolean(reader.GetValue(ordinal));
        }

        private static bool? GetBoolNullable(SqlDataReader reader, string name)
        {
            var ordinal = Ord(reader, name);
            return reader.IsDBNull(ordinal) ? null : Convert.ToBoolean(reader.GetValue(ordinal));
        }

        private static Guid GetGuid(SqlDataReader reader, string name)
        {
            var ordinal = Ord(reader, name);
            return reader.IsDBNull(ordinal) ? Guid.Empty : reader.GetGuid(ordinal);
        }

        private static Guid? GetGuidNullable(SqlDataReader reader, string name)
        {
            var ordinal = Ord(reader, name);
            return reader.IsDBNull(ordinal) ? null : reader.GetGuid(ordinal);
        }

        private static DateTime GetDateTime(SqlDataReader reader, string name)
        {
            var ordinal = Ord(reader, name);
            return reader.IsDBNull(ordinal) ? DateTime.MinValue : reader.GetDateTime(ordinal);
        }

        private static DateTime? GetDateTimeNullable(SqlDataReader reader, string name)
        {
            var ordinal = Ord(reader, name);
            return reader.IsDBNull(ordinal) ? null : reader.GetDateTime(ordinal);
        }
    }
}