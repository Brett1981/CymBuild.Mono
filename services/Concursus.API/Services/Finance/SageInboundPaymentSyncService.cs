#nullable enable

using Concursus.API.Sage.SOAP.Interface;
using Concursus.API.Sage.SOAP.Models;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Extensions.Logging;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Concursus.API.Services.Finance
{
    public sealed class SageInboundPaymentSyncService : ISageInboundPaymentSyncService
    {
        private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
        {
            WriteIndented = false
        };

        private readonly ILogger<SageInboundPaymentSyncService> _logger;
        private readonly ISageInboundPaymentReadRepository _readRepository;
        private readonly ISageInboundPaymentIdempotencyRepository _idempotencyRepository;
        private readonly ISageInboundPaymentPersistenceRepository _persistenceRepository;
        private readonly ISageApiClient _sageApiClient;
        private readonly ISageInboundPaymentWorklistRepository _worklistRepository;

        public SageInboundPaymentSyncService(
                ILogger<SageInboundPaymentSyncService> logger,
                ISageInboundPaymentReadRepository readRepository,
                ISageInboundPaymentIdempotencyRepository idempotencyRepository,
                ISageInboundPaymentPersistenceRepository persistenceRepository,
                ISageInboundPaymentWorklistRepository worklistRepository,
                ISageApiClient sageApiClient)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _readRepository = readRepository ?? throw new ArgumentNullException(nameof(readRepository));
            _idempotencyRepository = idempotencyRepository ?? throw new ArgumentNullException(nameof(idempotencyRepository));
            _persistenceRepository = persistenceRepository ?? throw new ArgumentNullException(nameof(persistenceRepository));
            _worklistRepository = worklistRepository ?? throw new ArgumentNullException(nameof(worklistRepository));
            _sageApiClient = sageApiClient ?? throw new ArgumentNullException(nameof(sageApiClient));
        }

        public Task<SageInboundPaymentSyncResult> SyncAsync(
            SageInboundPaymentSyncRequest request,
            CancellationToken cancellationToken = default)
        {
            if (request is null)
                throw new ArgumentNullException(nameof(request));

            return SyncAsync(request.CymBuildDocumentGuid, request.Force, cancellationToken);
        }

        public async Task<SageInboundPaymentSyncResult> SyncAsync(
            Guid cymBuildDocumentGuid,
            bool force,
            CancellationToken cancellationToken = default)
        {
            var attemptedOnUtc = DateTime.UtcNow;
            var result = new SageInboundPaymentSyncResult
            {
                CymBuildDocumentGuid = cymBuildDocumentGuid
            };

            SageInboundClaimResult? claim = null;
            string requestPayloadJson = string.Empty;
            string? responsePayloadJson = null;

            try
            {
                var target = await _readRepository.GetSyncTargetAsync(cymBuildDocumentGuid, cancellationToken).ConfigureAwait(false);

                if (target is null)
                {
                    result.IsSuccess = false;
                    result.IsRetryableFailure = false;
                    result.Message = $"No Sage inbound sync target could be resolved for document guid {cymBuildDocumentGuid}.";
                    return result;
                }

                requestPayloadJson = JsonSerializer.Serialize(new
                {
                    cymBuildDocumentGuid = target.CymBuildDocumentGuid,
                    force
                }, JsonOptions);

                await _idempotencyRepository.EnsureAsync(target, cancellationToken).ConfigureAwait(false);

                claim = await _idempotencyRepository.TryClaimAsync(target.CymBuildDocumentGuid, cancellationToken).ConfigureAwait(false);

                if (!claim.ClaimSucceeded)
                {
                    result.IsSuccess = false;
                    result.IsRetryableFailure = true;
                    result.Message = "The document could not be claimed for inbound Sage payment sync.";
                    return result;
                }

                var dataset = Enum.Parse<SageDataset>(target.SageDataset, ignoreCase: true);

                var wrapperResponse = await _sageApiClient.FetchCustomerTransactionsAsync(
                    dataset,
                    target.SageAccountReference,
                    string.IsNullOrWhiteSpace(target.SageDocumentNo) ? null : target.SageDocumentNo,
                    null,
                    force,
                    cancellationToken).ConfigureAwait(false);

                var rows = wrapperResponse?.Transactions ?? new List<Dictionary<string, object?>>();

                foreach (var row in rows)
                {
                    var rawJson = JsonSerializer.Serialize(row, JsonOptions);
                    var sourceHash = ComputeSha256(rawJson);

                    var externalTransactionId = await _persistenceRepository.UpsertExternalTransactionAsync(
                        new SageExternalTransactionUpsertRequest
                        {
                            SageDataset = target.SageDataset,
                            SageAccountReference = GetString(row, "accountReference"),
                            SageDocumentNo = GetString(row, "documentNo"),
                            SageTransactionReference = GetString(row, "transactionReference"),
                            SecondReference = GetString(row, "secondReference"),
                            SageTransactionTypeCode = GetInt(row, "sysTraderTranType", -1),
                            TransactionDateUtc = GetDate(row, "transactionDate"),
                            NetAmount = GetDecimal(row, "netAmount"),
                            TaxAmount = GetDecimal(row, "taxAmount"),
                            GrossAmount = GetDecimal(row, "grossAmount"),
                            OutstandingAmount = GetDecimal(row, "outstandingAmount"),
                            SourceHash = sourceHash,
                            RawPayloadJson = rawJson
                        },
                        cancellationToken).ConfigureAwait(false);

                    result.ExternalTransactionCount++;

                    var reconcileResult = await _persistenceRepository.ReconcileInvoiceAsync(
                        externalTransactionId,
                        cancellationToken).ConfigureAwait(false);

                    result.Items.Add(new SageInboundPaymentSyncResultItem
                    {
                        ExternalTransactionId = reconcileResult.ExternalTransactionId,
                        MatchedTransactionId = reconcileResult.MatchedTransactionId,
                        MatchedInvoiceRequestId = reconcileResult.MatchedInvoiceRequestId,
                        MatchedJobId = reconcileResult.MatchedJobId,
                        MatchRule = reconcileResult.MatchRule
                    });

                    if (reconcileResult.IsMatched)
                    {
                        result.ReconciledInvoiceCount++;

                        if (reconcileResult.MatchedInvoiceRequestId > 0)
                        {
                            await _persistenceRepository.ApplyInvoicePaymentStatusAsync(
                                reconcileResult.MatchedInvoiceRequestId,
                                cancellationToken).ConfigureAwait(false);

                            result.UpdatedInvoiceRequestCount++;
                        }
                    }
                }

                responsePayloadJson = JsonSerializer.Serialize(new
                {
                    result.ExternalTransactionCount,
                    result.ExternalAllocationCount,
                    result.ReconciledInvoiceCount,
                    result.ReconciledAllocationCount,
                    result.UpdatedInvoiceRequestCount
                }, JsonOptions);

                result.IsSuccess = true;
                result.IsRetryableFailure = false;
                result.Message = $"Sage inbound payment sync succeeded for document {cymBuildDocumentGuid}.";

                await _idempotencyRepository.MarkSuccessAsync(
                    cymBuildDocumentGuid,
                    DateTime.UtcNow,
                    cancellationToken).ConfigureAwait(false);

                await _idempotencyRepository.InsertAttemptAsync(
                    claim.Id,
                    claim.CymBuildDocumentGuid,
                    claim.CymBuildDocumentId,
                    "SyncCustomerTransactions",
                    attemptedOnUtc,
                    DateTime.UtcNow,
                    true,
                    false,
                    "Succeeded",
                    result.Message,
                    null,
                    requestPayloadJson,
                    responsePayloadJson,
                    cancellationToken).ConfigureAwait(false);

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Unhandled error during Sage inbound payment sync for {CymBuildDocumentGuid}.",
                    cymBuildDocumentGuid);

                result.IsSuccess = false;
                result.IsRetryableFailure = true;
                result.Message = ex.Message;

                if (claim is not null && claim.ClaimSucceeded)
                {
                    await _idempotencyRepository.MarkFailureAsync(
                        cymBuildDocumentGuid,
                        ex.ToString(),
                        true,
                        cancellationToken).ConfigureAwait(false);

                    await _idempotencyRepository.InsertAttemptAsync(
                        claim.Id,
                        claim.CymBuildDocumentGuid,
                        claim.CymBuildDocumentId,
                        "SyncCustomerTransactions",
                        attemptedOnUtc,
                        DateTime.UtcNow,
                        false,
                        true,
                        "Failed",
                        ex.Message,
                        ex.ToString(),
                        requestPayloadJson,
                        responsePayloadJson,
                        cancellationToken).ConfigureAwait(false);
                }

                return result;
            }
        }

        private static string GetString(Dictionary<string, object?> row, string key)
        {
            if (!TryGetValueIgnoreCase(row, key, out var value) || value is null)
                return string.Empty;

            if (value is JsonElement je)
            {
                if (je.ValueKind == JsonValueKind.String)
                    return je.GetString() ?? string.Empty;

                return je.ToString();
            }

            return Convert.ToString(value, CultureInfo.InvariantCulture) ?? string.Empty;
        }

        private static int GetInt(Dictionary<string, object?> row, string key, int defaultValue = 0)
        {
            if (!TryGetValueIgnoreCase(row, key, out var value) || value is null)
                return defaultValue;

            if (value is JsonElement je)
            {
                if (je.ValueKind == JsonValueKind.Number && je.TryGetInt32(out var i))
                    return i;

                if (je.ValueKind == JsonValueKind.String &&
                    int.TryParse(je.GetString(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed))
                    return parsed;

                return defaultValue;
            }

            try
            {
                return Convert.ToInt32(value, CultureInfo.InvariantCulture);
            }
            catch
            {
                return defaultValue;
            }
        }

        private static decimal GetDecimal(Dictionary<string, object?> row, string key, decimal defaultValue = 0m)
        {
            if (!TryGetValueIgnoreCase(row, key, out var value) || value is null)
                return defaultValue;

            if (value is JsonElement je)
            {
                if (je.ValueKind == JsonValueKind.Number && je.TryGetDecimal(out var d))
                    return d;

                if (je.ValueKind == JsonValueKind.String &&
                    decimal.TryParse(je.GetString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed))
                    return parsed;

                return defaultValue;
            }

            try
            {
                return Convert.ToDecimal(value, CultureInfo.InvariantCulture);
            }
            catch
            {
                return defaultValue;
            }
        }

        private static DateTime? GetDate(Dictionary<string, object?> row, string key)
        {
            if (!TryGetValueIgnoreCase(row, key, out var value) || value is null)
                return null;

            if (value is JsonElement je)
            {
                if (je.ValueKind == JsonValueKind.String &&
                    DateTime.TryParse(je.GetString(), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var parsed))
                    return parsed;

                return null;
            }

            if (value is DateTime dt)
                return dt;

            return DateTime.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), out var parsedDate)
                ? parsedDate
                : null;
        }

        private static bool TryGetValueIgnoreCase(Dictionary<string, object?> row, string key, out object? value)
        {
            foreach (var kvp in row)
            {
                if (string.Equals(kvp.Key, key, StringComparison.OrdinalIgnoreCase))
                {
                    value = kvp.Value;
                    return true;
                }
            }

            value = null;
            return false;
        }

        private static string ComputeSha256(string value)
        {
            using var sha = SHA256.Create();
            var bytes = Encoding.UTF8.GetBytes(value ?? string.Empty);
            var hash = sha.ComputeHash(bytes);
            return Convert.ToHexString(hash);
        }

        public Task<SageInboundPaymentSyncEnqueueResult> EnqueueAsync(
    SageInboundPaymentSyncEnqueueRequest request,
    CancellationToken cancellationToken = default)
        {
            if (request is null)
                throw new ArgumentNullException(nameof(request));

            return EnqueueAsync(request.CymBuildDocumentGuid, request.ForceRequeue, cancellationToken);
        }

        public async Task<SageInboundPaymentSyncEnqueueResult> EnqueueAsync(
            Guid cymBuildDocumentGuid,
            bool forceRequeue,
            CancellationToken cancellationToken = default)
        {
            if (cymBuildDocumentGuid == Guid.Empty)
                throw new ArgumentException("A valid CymBuild document guid is required.", nameof(cymBuildDocumentGuid));

            await _worklistRepository.EnqueueAsync(
                cymBuildDocumentGuid,
                forceRequeue,
                cancellationToken).ConfigureAwait(false);

            return new SageInboundPaymentSyncEnqueueResult
            {
                CymBuildDocumentGuid = cymBuildDocumentGuid,
                IsSuccess = true,
                Message = forceRequeue
                    ? "The document was successfully requeued for inbound Sage payment sync."
                    : "The document was successfully enqueued for inbound Sage payment sync."
            };
        }
    }
}