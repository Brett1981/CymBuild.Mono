#nullable enable

using Concursus.API.Sage.SOAP.Interface;
using Concursus.API.Sage.SOAP.Models;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.API.Services.Finance
{
    public sealed class SageInboundPaymentSyncService : ISageInboundPaymentSyncService
    {
        private const int SageInvoiceTransactionTypeCode = 4;
        private const int SageCreditNoteTransactionTypeCode = 5;
        // SFA (ticket #58103): 1 is a Receipt; 6 is an Opening Balance Invoice and is ignored.
        private const int SageReceiptTransactionTypeCode = 1;

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
        private readonly SageInboundPaymentSyncWorkerOptions _options;

        public SageInboundPaymentSyncService(
            ILogger<SageInboundPaymentSyncService> logger,
            ISageInboundPaymentReadRepository readRepository,
            ISageInboundPaymentIdempotencyRepository idempotencyRepository,
            ISageInboundPaymentPersistenceRepository persistenceRepository,
            ISageInboundPaymentWorklistRepository worklistRepository,
            ISageApiClient sageApiClient,
            IOptions<SageInboundPaymentSyncWorkerOptions> options)
        {
            _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
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
            ArgumentNullException.ThrowIfNull(request);
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
                    target.SageDataset,
                    target.SageAccountReference,
                    target.SageDocumentNo,
                    force
                }, JsonOptions);

                await _idempotencyRepository.EnsureAsync(target, cancellationToken).ConfigureAwait(false);

                claim = new SageInboundClaimResult
                {
                    ClaimSucceeded = true,
                    CymBuildDocumentGuid = target.CymBuildDocumentGuid,
                    CymBuildDocumentId = target.CymBuildDocumentId
                };

                var dataset = Enum.Parse<SageDataset>(target.SageDataset, ignoreCase: true);

                var wrapperResponse = await _sageApiClient.FetchCustomerTransactionsAsync(
                    dataset,
                    target.SageAccountReference,
                    target.SageDocumentNo,
                    null,
                    force,
                    cancellationToken).ConfigureAwait(false);

                var rows = wrapperResponse?.Transactions ?? new List<Dictionary<string, object?>>();
                var latestContinuePolling = false;

                // CYB-555: ask Sage what settled each settled invoice before anything
                // is written. If a lookup fails, nothing is written and the whole
                // sync is retried later; the wrapper never returns a partial answer.
                var settlementAllocations = _options.UseSalesAllocations
                    ? await FetchSettlementAllocationsAsync(target, dataset, rows, cancellationToken).ConfigureAwait(false)
                    : new Dictionary<int, SageFetchSalesAllocationsResponse>();

                for (var rowIndex = 0; rowIndex < rows.Count; rowIndex++)
                {
                    var row = rows[rowIndex];
                    cancellationToken.ThrowIfCancellationRequested();

                    var sageTransactionTypeCode = GetInt(row, "sysTraderTranType", -1);
                    if (sageTransactionTypeCode != SageInvoiceTransactionTypeCode &&
                        sageTransactionTypeCode != SageCreditNoteTransactionTypeCode &&
                        sageTransactionTypeCode != SageReceiptTransactionTypeCode)
                    {
                        _logger.LogInformation(
                            "Ignoring unsupported Sage customer transaction during invoice payment sync. CymBuildDocumentGuid={CymBuildDocumentGuid}, SageTransactionTypeCode={SageTransactionTypeCode}, TransactionReference={TransactionReference}",
                            target.CymBuildDocumentGuid,
                            sageTransactionTypeCode,
                            GetString(row, "transactionReference"));
                        continue;
                    }

                    // CYB-555: SFA ignores the account filter, so the document-number
                    // lookup can return another customer's row with the same reference.
                    var rowAccountReference = GetRowAccountReference(row);
                    if (!SageAccountReferenceMatcher.IsRequestedAccount(rowAccountReference, target.SageAccountReference))
                    {
                        _logger.LogWarning(
                            "Ignoring Sage customer transaction for another account during invoice payment sync. CymBuildDocumentGuid={CymBuildDocumentGuid}, RequestedAccountReference={RequestedAccountReference}, RowAccountReference={RowAccountReference}, SageTransactionTypeCode={SageTransactionTypeCode}, TransactionReference={TransactionReference}",
                            target.CymBuildDocumentGuid,
                            target.SageAccountReference,
                            rowAccountReference,
                            sageTransactionTypeCode,
                            GetString(row, "transactionReference"));
                        continue;
                    }

                    var rawJson = JsonSerializer.Serialize(row, JsonOptions);
                    var sourceHash = ComputeSha256(rawJson);

                    var upsertRequest = new SageExternalTransactionUpsertRequest
                    {
                        SageDataset = target.SageDataset,
                        // As Sage holds it: v2 keeps the leading zeros (00030607).
                        SageAccountReference = !string.IsNullOrWhiteSpace(rowAccountReference)
                                            ? rowAccountReference
                                            : target.SageAccountReference,
                        SageDocumentNo = ResolveDocumentNo(row, target.SageDocumentNo),
                        SageTransactionReference = GetString(row, "transactionReference"),
                        SecondReference = GetString(row, "secondReference"),
                        SageTransactionTypeCode = sageTransactionTypeCode,
                        TransactionDateUtc = GetDate(row, "transactionDate"),
                        NetAmount = GetDecimal(row, "netAmount"),
                        TaxAmount = GetDecimal(row, "taxAmount"),
                        GrossAmount = GetDecimal(row, "grossAmount"),
                        OutstandingAmount = GetDecimal(row, "outstandingAmount"),
                        AllocatedValue = GetDecimal(row, "allocatedValue"),
                        DocumentDiscountedValue = GetDecimal(row, "documentDiscountedValue"),
                        IsPaid = GetBool(row, "isPaid"),
                        IsFullyPaid = GetBool(row, "isFullyPaid"),
                        PaymentStateCode = SageAggregatePaymentStateCodes.Unknown,
                        SourceHash = sourceHash,
                        RawPayloadJson = rawJson
                    };

                    var externalTransactionId = await _persistenceRepository.UpsertExternalTransactionAsync(
                        upsertRequest,
                        cancellationToken).ConfigureAwait(false);

                    result.ExternalTransactionCount++;

                    var reconcileResult = await _persistenceRepository.ReconcileInvoiceAsync(
                        externalTransactionId,
                        cancellationToken).ConfigureAwait(false);

                    if (reconcileResult.IsMatched)
                    {
                        result.ReconciledInvoiceCount++;

                        if (sageTransactionTypeCode == SageInvoiceTransactionTypeCode &&
                            reconcileResult.MatchedTransactionGuid != Guid.Empty &&
                            !string.IsNullOrWhiteSpace(upsertRequest.SageDocumentNo))
                        {
                            await TryApplySageInvoiceDocumentNumberAsync(
                                reconcileResult.MatchedTransactionGuid,
                                upsertRequest.SageDocumentNo,
                                cancellationToken).ConfigureAwait(false);
                        }
                    }

                    var aggregateResult = await _persistenceRepository.ApplyAggregatePaymentStateAsync(
                        externalTransactionId,
                        cancellationToken).ConfigureAwait(false);

                    if (_options.UseSalesAllocations)
                    {
                        // CYB-555: Sage's allocation sessions decide what settled the
                        // invoice: a Receipt, a Credit Note, or settled with the method
                        // unknown. No row here is materialised directly, so a Receipt is
                        // never inferred from a settled invoice, and a credit note that
                        // the document-number lookup also returns is not counted twice.
                        if (sageTransactionTypeCode == SageInvoiceTransactionTypeCode &&
                            reconcileResult.IsMatched &&
                            settlementAllocations.TryGetValue(rowIndex, out var allocations))
                        {
                            await RecordSettlementAllocationsAsync(
                                target,
                                externalTransactionId,
                                allocations,
                                result,
                                cancellationToken).ConfigureAwait(false);
                        }
                    }
                    else
                    {
                        // UseSalesAllocations off (the emergency fallback):
                        // A Credit Note/Receipt (1/5) is always a candidate allocation source.
                        // CYB-568: an Invoice (4) row is passed through again (restoring the
                        // CYB-543 behaviour that CYB-555 removed). The production Sage source
                        // never sends a distinct 1/5 row for a paid invoice - it only flips
                        // IsPaid/AllocatedValue on the invoice's own row - so without this no
                        // receipt or allocation is ever created. The materialise procedure
                        // ignores a type 4 row once a real 1/5 row exists for the same invoice,
                        // so this never double-materialises when Sage does send both.
                        var isAllocationSource =
                            sageTransactionTypeCode == SageCreditNoteTransactionTypeCode ||
                            sageTransactionTypeCode == SageReceiptTransactionTypeCode ||
                            sageTransactionTypeCode == SageInvoiceTransactionTypeCode;

                        if (isAllocationSource &&
                            Math.Abs(aggregateResult.AllocatedValue) > 0m &&
                            reconcileResult.IsMatched)
                        {
                            await _persistenceRepository.MaterialiseReceiptAndAllocationAsync(
                                externalTransactionId,
                                cancellationToken).ConfigureAwait(false);
                        }
                    }

                    if (sageTransactionTypeCode == SageInvoiceTransactionTypeCode &&
                        (aggregateResult.PaymentStateCode == SageAggregatePaymentStateCodes.Paid ||
                         aggregateResult.PaymentStateCode == SageAggregatePaymentStateCodes.OverAllocated))
                    {
                        result.FullyPaidCount++;
                    }
                    else if (sageTransactionTypeCode == SageInvoiceTransactionTypeCode &&
                             aggregateResult.PaymentStateCode == SageAggregatePaymentStateCodes.PartiallyPaid)
                    {
                        result.PartiallyPaidCount++;
                        latestContinuePolling = true;
                    }
                    else if (sageTransactionTypeCode == SageInvoiceTransactionTypeCode)
                    {
                        result.UnpaidCount++;
                        latestContinuePolling = true;
                    }

                    if (sageTransactionTypeCode == SageInvoiceTransactionTypeCode)
                    {
                        var nextPollDueOnUtc = CalculateNextPollDueOnUtc(aggregateResult, DateTime.UtcNow);

                        await _persistenceRepository.UpdateInboundStatusFromExternalTransactionAsync(
                            target.CymBuildDocumentGuid,
                            externalTransactionId,
                            nextPollDueOnUtc,
                            cancellationToken).ConfigureAwait(false);
                    }

                    result.Items.Add(new SageInboundPaymentSyncResultItem
                    {
                        ExternalTransactionId = reconcileResult.ExternalTransactionId,
                        MatchedTransactionId = reconcileResult.MatchedTransactionId,
                        MatchedInvoiceRequestId = reconcileResult.MatchedInvoiceRequestId,
                        MatchedJobId = reconcileResult.MatchedJobId,
                        MatchRule = reconcileResult.MatchRule,
                        SageTransactionReference = upsertRequest.SageTransactionReference,
                        SageDocumentNo = upsertRequest.SageDocumentNo,
                        SageTransactionTypeCode = upsertRequest.SageTransactionTypeCode,
                        GrossAmount = aggregateResult.GrossAmount,
                        AllocatedValue = aggregateResult.AllocatedValue,
                        OutstandingAmount = aggregateResult.OutstandingAmount,
                        DocumentDiscountedValue = aggregateResult.DocumentDiscountedValue,
                        IsPaid = aggregateResult.IsPaid,
                        IsFullyPaid = aggregateResult.IsFullyPaid,
                        PaymentStateCode = aggregateResult.PaymentStateCode,
                        TransactionDateUtc = upsertRequest.TransactionDateUtc,
                        LastSeenOnUtc = DateTime.UtcNow
                    });
                }

                result.ShouldContinuePolling = latestContinuePolling || result.UnpaidCount > 0 || result.PartiallyPaidCount > 0;

                responsePayloadJson = JsonSerializer.Serialize(new
                {
                    result.ExternalTransactionCount,
                    result.ReconciledInvoiceCount,
                    result.UpdatedInvoiceRequestCount,
                    result.FullyPaidCount,
                    result.PartiallyPaidCount,
                    result.UnpaidCount,
                    result.ShouldContinuePolling
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

                // CYB-555: a 400 from the allocations endpoint is a CymBuild bug
                // (a missing or non-numeric URN); retrying would only repeat it.
                var isRetryable = ex is not SageAllocationsRequestRejectedException;

                result.IsSuccess = false;
                result.IsRetryableFailure = isRetryable;
                result.Message = ex.Message;

                if (claim is not null && claim.ClaimSucceeded)
                {
                    await _idempotencyRepository.MarkFailureAsync(
                        cymBuildDocumentGuid,
                        ex.ToString(),
                        isRetryable,
                        cancellationToken).ConfigureAwait(false);

                    await _idempotencyRepository.InsertAttemptAsync(
                        claim.Id,
                        claim.CymBuildDocumentGuid,
                        claim.CymBuildDocumentId,
                        "SyncCustomerTransactions",
                        attemptedOnUtc,
                        DateTime.UtcNow,
                        false,
                        isRetryable,
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

        public Task<SageInboundPaymentSyncEnqueueResult> EnqueueAsync(
            SageInboundPaymentSyncEnqueueRequest request,
            CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(request);
            return EnqueueAsync(request.CymBuildDocumentGuid, request.ForceRequeue, cancellationToken);
        }

        public async Task<SageInboundPaymentSyncEnqueueResult> EnqueueAsync(
            Guid cymBuildDocumentGuid,
            bool forceRequeue,
            CancellationToken cancellationToken = default)
        {
            if (cymBuildDocumentGuid == Guid.Empty)
            {
                throw new ArgumentException("A valid CymBuild document guid is required.", nameof(cymBuildDocumentGuid));
            }

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

        private async Task TryApplySageInvoiceDocumentNumberAsync(
            Guid transactionGuid,
            string sageDocumentNo,
            CancellationToken cancellationToken)
        {
            try
            {
                await _persistenceRepository.ApplySageInvoiceDocumentNumberAsync(
                    transactionGuid,
                    sageDocumentNo,
                    -1,
                    cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(
                    ex,
                    "Failed to apply Sage document number to transaction. This is best-effort and does not affect payment sync. TransactionGuid={TransactionGuid}, SageDocumentNo={SageDocumentNo}",
                    transactionGuid,
                    sageDocumentNo);
            }
        }

        /// <summary>
        /// CYB-555: for each settled invoice row on the requested account, asks
        /// the wrapper's /api/v2/sales-allocations what settled it. Called before
        /// anything is written. A 400 (a CymBuild bug) throws
        /// <see cref="SageAllocationsRequestRejectedException"/>, which is not
        /// retried; any other failure (500 sage_error, timeout) propagates and the
        /// whole sync is retried later.
        /// </summary>
        private async Task<Dictionary<int, SageFetchSalesAllocationsResponse>> FetchSettlementAllocationsAsync(
            SageInboundSyncTarget target,
            SageDataset dataset,
            List<Dictionary<string, object?>> rows,
            CancellationToken cancellationToken)
        {
            var responses = new Dictionary<int, SageFetchSalesAllocationsResponse>();

            for (var rowIndex = 0; rowIndex < rows.Count; rowIndex++)
            {
                var row = rows[rowIndex];

                if (GetInt(row, "sysTraderTranType", -1) != SageInvoiceTransactionTypeCode ||
                    GetDecimal(row, "allocatedValue") == 0m)
                {
                    continue;
                }

                var accountReference = GetRowAccountReference(row);
                if (!SageAccountReferenceMatcher.IsRequestedAccount(accountReference, target.SageAccountReference))
                {
                    continue;
                }

                // Sent exactly as Sage holds them: the padded account from v2 (30607
                // matches nothing) and the URN as a string of digits.
                var urn = GetString(row, "uniqueReferenceNumber").Trim();
                if (string.IsNullOrWhiteSpace(accountReference) || string.IsNullOrWhiteSpace(urn))
                {
                    _logger.LogWarning(
                        "Settled Sage invoice has no account or URN, so what settled it cannot be looked up; nothing is recorded for it. CymBuildDocumentGuid={CymBuildDocumentGuid}, AccountReference={AccountReference}, Urn={Urn}",
                        target.CymBuildDocumentGuid,
                        accountReference,
                        urn);
                    continue;
                }

                try
                {
                    var response = await _sageApiClient.FetchSalesAllocationsAsync(
                        dataset,
                        accountReference,
                        urn,
                        cancellationToken).ConfigureAwait(false);

                    if (response is not null)
                    {
                        responses[rowIndex] = response;
                    }
                }
                catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.BadRequest)
                {
                    throw new SageAllocationsRequestRejectedException(
                        $"The Sage allocations lookup rejected account '{accountReference}', URN '{urn}' (400). This is a CymBuild bug and is not retried.",
                        ex);
                }
            }

            return responses;
        }

        /// <summary>
        /// CYB-555: records what settled one invoice, from its allocation sessions.
        /// For each row of a session that is not the invoice itself:
        /// - a negative row resolved as a Receipt (1) or Credit Note (5) is recorded
        ///   and materialised as that type;
        /// - a negative row Sage could not resolve is recorded as settled, method
        ///   unknown, and nothing is materialised for it;
        /// - a positive row (another invoice the same receipt or credit note paid,
        ///   type 4/6 or unresolved) is ignored.
        /// The amount settled on this invoice is the invoice's own row in each session.
        /// </summary>
        private async Task RecordSettlementAllocationsAsync(
            SageInboundSyncTarget target,
            long invoiceExternalTransactionId,
            SageFetchSalesAllocationsResponse response,
            SageInboundPaymentSyncResult result,
            CancellationToken cancellationToken)
        {
            foreach (var session in response.Sessions)
            {
                cancellationToken.ThrowIfCancellationRequested();

                var appliedToInvoice = Math.Abs(session.Rows.Where(x => x.IsRequested).Sum(x => x.AllocationValue));
                if (appliedToInvoice == 0m || string.IsNullOrWhiteSpace(session.AllocationHeaderId))
                {
                    continue;
                }

                var settlingRows = new List<SageSalesAllocationRow>();

                foreach (var row in session.Rows.Where(x => !x.IsRequested && x.AllocationValue < 0m))
                {
                    if (string.IsNullOrWhiteSpace(row.Urn))
                    {
                        continue;
                    }

                    if (!row.TypeResolved ||
                        row.SysTraderTranType == SageReceiptTransactionTypeCode ||
                        row.SysTraderTranType == SageCreditNoteTransactionTypeCode)
                    {
                        settlingRows.Add(row);
                    }
                    else
                    {
                        _logger.LogWarning(
                            "Ignoring a Sage allocation counterpart that is neither a Receipt nor a Credit Note. CymBuildDocumentGuid={CymBuildDocumentGuid}, AllocationHeaderId={AllocationHeaderId}, CounterpartUrn={CounterpartUrn}, SageTransactionTypeCode={SageTransactionTypeCode}",
                            target.CymBuildDocumentGuid,
                            session.AllocationHeaderId,
                            row.Urn,
                            row.SysTraderTranType);
                    }
                }

                var shares = ApportionAppliedAmount(appliedToInvoice, settlingRows);

                for (var i = 0; i < settlingRows.Count; i++)
                {
                    var row = settlingRows[i];
                    var counterpartTypeCode = row.TypeResolved ? row.SysTraderTranType : null;

                    var recordResult = await _persistenceRepository.RecordAllocationAsync(
                        new SageAllocationRecordRequest
                        {
                            InvoiceExternalTransactionId = invoiceExternalTransactionId,
                            CounterpartUrn = row.Urn!.Trim(),
                            CounterpartTypeCode = counterpartTypeCode,
                            CounterpartReference = FirstNonEmpty(row.TransactionReference, row.InstrumentNo, row.Urn),
                            CounterpartSecondReference = row.SecondReference ?? string.Empty,
                            CounterpartTransactionDateUtc = TryParseSageDate(row.TransactionDate, out var transactionDate) ? transactionDate : null,
                            CounterpartNetAmount = row.NetAmount ?? 0m,
                            CounterpartTaxAmount = row.TaxAmount ?? 0m,
                            CounterpartGrossAmount = row.GrossAmount ?? row.AllocationValue,
                            CounterpartRawPayloadJson = JsonSerializer.Serialize(row, JsonOptions),
                            AllocationHeaderId = session.AllocationHeaderId!.Trim(),
                            SessionDateUtc = TryParseSageDate(session.SessionDate, out var sessionDate) ? sessionDate : null,
                            AppliedAmount = shares[i],
                            AllocationRawPayloadJson = JsonSerializer.Serialize(session, JsonOptions)
                        },
                        cancellationToken).ConfigureAwait(false);

                    var reconcileResult = await _persistenceRepository.ReconcileAllocationAsync(
                        recordResult.ExternalAllocationId,
                        cancellationToken).ConfigureAwait(false);

                    result.ExternalTransactionCount++;

                    if (counterpartTypeCode is null)
                    {
                        _logger.LogInformation(
                            "Sage invoice settled, method unknown: the counterpart's type could not be resolved, so no Receipt or Credit Note is created. CymBuildDocumentGuid={CymBuildDocumentGuid}, AllocationHeaderId={AllocationHeaderId}, CounterpartUrn={CounterpartUrn}, AppliedAmount={AppliedAmount}",
                            target.CymBuildDocumentGuid,
                            session.AllocationHeaderId,
                            row.Urn,
                            shares[i]);
                    }
                    else if (!reconcileResult.IsFullyMatched)
                    {
                        _logger.LogWarning(
                            "Sage allocation was recorded but not materialised. CymBuildDocumentGuid={CymBuildDocumentGuid}, ExternalAllocationId={ExternalAllocationId}, CounterpartUrn={CounterpartUrn}, SageTransactionTypeCode={SageTransactionTypeCode}",
                            target.CymBuildDocumentGuid,
                            recordResult.ExternalAllocationId,
                            row.Urn,
                            counterpartTypeCode);
                    }
                }
            }
        }

        /// <summary>
        /// Splits the amount settled on the invoice in one session across the rows
        /// that settled it. With one row, it all comes from that row; a receipt's
        /// own value can also cover other invoices, so it is never used directly.
        /// With several, each row's share is in proportion to its value; when the
        /// invoice is the only one in the session, that is exactly each row's value.
        /// </summary>
        internal static decimal[] ApportionAppliedAmount(decimal appliedToInvoice, IReadOnlyList<SageSalesAllocationRow> settlingRows)
        {
            var shares = new decimal[settlingRows.Count];
            if (settlingRows.Count == 0)
            {
                return shares;
            }

            var total = settlingRows.Sum(x => Math.Abs(x.AllocationValue));
            var remaining = appliedToInvoice;

            for (var i = 0; i < settlingRows.Count; i++)
            {
                shares[i] = i == settlingRows.Count - 1 || total == 0m
                    ? remaining
                    : Math.Round(appliedToInvoice * Math.Abs(settlingRows[i].AllocationValue) / total, 2, MidpointRounding.AwayFromZero);

                if (total == 0m)
                {
                    break;
                }

                remaining -= shares[i];
            }

            return shares;
        }

        private static string GetRowAccountReference(Dictionary<string, object?> row)
        {
            var accountReference = GetString(row, "accountReference");
            return !string.IsNullOrWhiteSpace(accountReference)
                ? accountReference.Trim()
                : GetString(row, "customerAccountNumber").Trim();
        }


        private static string FirstNonEmpty(params string?[] values)
        {
            foreach (var value in values)
            {
                if (!string.IsNullOrWhiteSpace(value))
                {
                    return value.Trim();
                }
            }

            return string.Empty;
        }

        private static string ResolveDocumentNo(Dictionary<string, object?> row, string fallbackDocumentNo)
        {
            var explicitDocumentNo = GetString(row, "documentNo");
            if (!string.IsNullOrWhiteSpace(explicitDocumentNo))
            {
                return explicitDocumentNo;
            }

            var secondReference = GetString(row, "secondReference");
            return !string.IsNullOrWhiteSpace(secondReference) ? secondReference : fallbackDocumentNo;
        }

        private static DateTime? CalculateNextPollDueOnUtc(
    SageAggregatePaymentStateResult aggregateState,
    DateTime nowUtc)
        {
            ArgumentNullException.ThrowIfNull(aggregateState);

            var isTerminal =
                aggregateState.IsFullyPaid ||
                aggregateState.OutstandingAmount <= 0m ||
                string.Equals(aggregateState.PaymentStateCode, "Paid", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(aggregateState.PaymentStateCode, "OverAllocated", StringComparison.OrdinalIgnoreCase);

            if (isTerminal)
            {
                return null;
            }

            return nowUtc.AddHours(4);
        }

        private static string GetString(Dictionary<string, object?> row, string key)
        {
            if (!TryGetValueIgnoreCase(row, key, out var value) || value is null)
            {
                return string.Empty;
            }

            if (value is JsonElement je)
            {
                if (je.ValueKind == JsonValueKind.String)
                {
                    return je.GetString() ?? string.Empty;
                }

                return je.ToString();
            }

            return Convert.ToString(value, CultureInfo.InvariantCulture) ?? string.Empty;
        }

        private static int GetInt(Dictionary<string, object?> row, string key, int defaultValue = 0)
        {
            if (!TryGetValueIgnoreCase(row, key, out var value) || value is null)
            {
                return defaultValue;
            }

            if (value is JsonElement je)
            {
                if (je.ValueKind == JsonValueKind.Number && je.TryGetInt32(out var i))
                {
                    return i;
                }

                if (je.ValueKind == JsonValueKind.String &&
                    int.TryParse(je.GetString(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed))
                {
                    return parsed;
                }

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
            {
                return defaultValue;
            }

            if (value is JsonElement je)
            {
                if (je.ValueKind == JsonValueKind.Number && je.TryGetDecimal(out var d))
                {
                    return d;
                }

                if (je.ValueKind == JsonValueKind.String &&
                    decimal.TryParse(je.GetString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed))
                {
                    return parsed;
                }

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

        private static bool GetBool(Dictionary<string, object?> row, string key, bool defaultValue = false)
        {
            if (!TryGetValueIgnoreCase(row, key, out var value) || value is null)
            {
                return defaultValue;
            }

            if (value is JsonElement je)
            {
                if (je.ValueKind == JsonValueKind.True)
                {
                    return true;
                }

                if (je.ValueKind == JsonValueKind.False)
                {
                    return false;
                }

                if (je.ValueKind == JsonValueKind.String &&
                    bool.TryParse(je.GetString(), out var parsed))
                {
                    return parsed;
                }

                return defaultValue;
            }

            try
            {
                return Convert.ToBoolean(value, CultureInfo.InvariantCulture);
            }
            catch
            {
                return defaultValue;
            }
        }

        private static DateTime? GetDate(Dictionary<string, object?> row, string key)
        {
            if (!TryGetValueIgnoreCase(row, key, out var value) || value is null)
            {
                return null;
            }

            if (value is DateTime dt)
            {
                return dt;
            }

            var text = value is JsonElement je
                ? (je.ValueKind == JsonValueKind.String ? je.GetString() : null)
                : Convert.ToString(value, CultureInfo.InvariantCulture);

            return TryParseSageDate(text, out var parsed) ? parsed : null;
        }

        // CYB-568: Sage is a UK system. Depending on the wrapper, transactionDate
        // arrives as ISO 8601 or as a UK dd/MM/yyyy string. Parsing the UK form
        // with InvariantCulture reads it as US MM/dd, so 04/09/2026 (4 September)
        // was stored as 9 April. ISO is tried first; slash dates are only ever
        // read day-first.
        private static readonly string[] SageUkDateFormats =
        [
            "dd/MM/yyyy",
            "d/M/yyyy",
            "dd/MM/yyyy HH:mm:ss",
            "d/M/yyyy H:mm:ss",
            "dd/MM/yyyy HH:mm",
            "d/M/yyyy H:mm"
        ];

        internal static bool TryParseSageDate(string? text, out DateTime parsed)
        {
            parsed = default;

            if (string.IsNullOrWhiteSpace(text))
            {
                return false;
            }

            text = text.Trim();

            // ISO 8601 always starts with a four-digit year.
            if (text.Length >= 10 && char.IsDigit(text[0]) && text[4] == '-' &&
                DateTime.TryParse(
                    text,
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                    out parsed))
            {
                return true;
            }

            return DateTime.TryParseExact(
                text,
                SageUkDateFormats,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                out parsed);
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
    }

    /// <summary>
    /// CYB-555: the wrapper's allocations endpoint returned 400 (a missing or
    /// non-numeric URN). That is a CymBuild bug, so the sync is not retried.
    /// </summary>
    public sealed class SageAllocationsRequestRejectedException : Exception
    {
        public SageAllocationsRequestRejectedException(string message, Exception innerException)
            : base(message, innerException)
        {
        }
    }
}
