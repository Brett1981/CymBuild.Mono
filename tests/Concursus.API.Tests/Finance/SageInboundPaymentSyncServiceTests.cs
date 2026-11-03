using Concursus.API.Sage.SOAP.Interface;
using Concursus.API.Sage.SOAP.Models;
using Concursus.API.Services.Finance;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using System.Net;
using System.Text.Json;
using Xunit;

namespace Concursus.API.Tests.Finance;

[Trait("Level", "Unit")]
[Trait("Area", "Sage")]
public sealed class SageInboundPaymentSyncServiceTests
{
    private readonly Guid _documentGuid = Guid.Parse("44444444-4444-4444-4444-444444444444");
    private readonly SageInboundSyncTarget _target;
    private readonly Mock<ISageInboundPaymentReadRepository> _readRepository = new();
    private readonly Mock<ISageInboundPaymentIdempotencyRepository> _idempotencyRepository = new();
    private readonly Mock<ISageInboundPaymentPersistenceRepository> _persistenceRepository = new();
    private readonly Mock<ISageInboundPaymentWorklistRepository> _worklistRepository = new();
    private readonly Mock<ISageApiClient> _sageApiClient = new();
    private readonly SageInboundPaymentSyncWorkerOptions _options = new();
    private readonly List<SageAllocationRecordRequest> _recordedAllocations = new();

    public SageInboundPaymentSyncServiceTests()
    {
        _target = new SageInboundSyncTarget
        {
            CymBuildDocumentGuid = _documentGuid,
            CymBuildDocumentId = 12,
            SageDataset = "group",
            SageAccountReference = "CUST001",
            SageDocumentNo = "INV-100"
        };

        _readRepository
            .Setup(x => x.GetSyncTargetAsync(_documentGuid, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_target);
        _idempotencyRepository
            .Setup(x => x.EnsureAsync(_target, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageInboundStatusEnsureResult { Guid = Guid.NewGuid() });
        _idempotencyRepository
            .Setup(x => x.MarkSuccessAsync(It.IsAny<Guid>(), It.IsAny<DateTime?>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _idempotencyRepository
            .Setup(x => x.MarkFailureAsync(It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<bool>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _idempotencyRepository
            .Setup(x => x.InsertAttemptAsync(
                It.IsAny<long>(), It.IsAny<Guid>(), It.IsAny<long>(), It.IsAny<string>(),
                It.IsAny<DateTime>(), It.IsAny<DateTime?>(), It.IsAny<bool>(), It.IsAny<bool>(),
                It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<string?>(), It.IsAny<string?>(),
                It.IsAny<string?>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _sageApiClient
            .Setup(x => x.FetchCustomerTransactionsAsync(
                SageDataset.group,
                "CUST001",
                "INV-100",
                null,
                It.IsAny<bool>(),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageFetchCustomerTransactionsResponse { Status = "Ok" });

        _persistenceRepository
            .Setup(x => x.UpsertExternalTransactionAsync(It.IsAny<SageExternalTransactionUpsertRequest>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(101);
        _persistenceRepository
            .Setup(x => x.ReconcileInvoiceAsync(It.IsAny<long>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageReconcileInvoiceResult { ExternalTransactionId = 101 });
        _persistenceRepository
            .Setup(x => x.ApplyAggregatePaymentStateAsync(It.IsAny<long>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageAggregatePaymentStateResult
            {
                ExternalTransactionId = 101,
                PaymentStateCode = SageAggregatePaymentStateCodes.Unpaid,
                GrossAmount = 120m,
                OutstandingAmount = 120m
            });
        _persistenceRepository
            .Setup(x => x.UpdateInboundStatusFromExternalTransactionAsync(
                It.IsAny<Guid>(), It.IsAny<long>(), It.IsAny<DateTime?>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _persistenceRepository
            .Setup(x => x.MaterialiseReceiptAndAllocationAsync(It.IsAny<long>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _persistenceRepository
            .Setup(x => x.ApplySageInvoiceDocumentNumberAsync(
                It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<int>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _worklistRepository
            .Setup(x => x.EnqueueAsync(It.IsAny<Guid>(), It.IsAny<bool>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _persistenceRepository
            .Setup(x => x.RecordAllocationAsync(It.IsAny<SageAllocationRecordRequest>(), It.IsAny<CancellationToken>()))
            .Callback<SageAllocationRecordRequest, CancellationToken>((request, _) => _recordedAllocations.Add(request))
            .ReturnsAsync(() => new SageAllocationRecordResult
            {
                CounterpartExternalTransactionId = 300 + _recordedAllocations.Count,
                ExternalAllocationId = 400 + _recordedAllocations.Count
            });
        _persistenceRepository
            .Setup(x => x.ReconcileAllocationAsync(It.IsAny<long>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((long id, CancellationToken _) => new SageReconcileAllocationResult
            {
                ExternalAllocationId = id,
                IsFullyMatched = true,
                MatchedSourceTransactionId = 900,
                MatchedTargetTransactionId = 55
            });
    }

    [Fact]
    public async Task SyncAsync_MissingTargetReturnsNonRetryableFailureWithoutCallingSage()
    {
        _readRepository
            .Setup(x => x.GetSyncTargetAsync(_documentGuid, It.IsAny<CancellationToken>()))
            .ReturnsAsync((SageInboundSyncTarget?)null);

        var result = await CreateService().SyncAsync(_documentGuid, force: false);

        Assert.False(result.IsSuccess);
        Assert.False(result.IsRetryableFailure);
        Assert.True(result.Message.Contains("No Sage inbound sync target", StringComparison.Ordinal));
        _sageApiClient.Verify(x => x.FetchCustomerTransactionsAsync(
            It.IsAny<SageDataset>(), It.IsAny<string?>(), It.IsAny<string?>(), It.IsAny<int?>(), It.IsAny<bool>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SyncAsync_NoRowsMarksSuccessfulAttempt()
    {
        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        Assert.False(result.IsRetryableFailure);
        Assert.Equal(0, result.ExternalTransactionCount);
        Assert.False(result.ShouldContinuePolling);
        _sageApiClient.Verify(x => x.FetchCustomerTransactionsAsync(
            SageDataset.group, "CUST001", "INV-100", null, true, It.IsAny<CancellationToken>()), Times.Once);
        _idempotencyRepository.Verify(x => x.MarkSuccessAsync(
            _documentGuid, It.IsAny<DateTime?>(), It.IsAny<CancellationToken>()), Times.Once);
        _idempotencyRepository.Verify(x => x.InsertAttemptAsync(
            It.IsAny<long>(), _documentGuid, 12, "SyncCustomerTransactions",
            It.IsAny<DateTime>(), It.IsAny<DateTime?>(), true, false, "Succeeded",
            It.IsAny<string?>(), null, It.IsAny<string?>(), It.IsAny<string?>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SyncAsync_PaidInvoiceWithNoDistinctAllocationSource_MaterialisesReceipt()
    {
        // The CYB-568 fallback, now only with UseSalesAllocations off (the kill switch).
        _options.UseSalesAllocations = false;
        SageExternalTransactionUpsertRequest? capturedRequest = null;
        DateTime? capturedNextPoll = DateTime.MaxValue;

        _sageApiClient
            .Setup(x => x.FetchCustomerTransactionsAsync(
                SageDataset.group, "CUST001", "INV-100", null, true, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageFetchCustomerTransactionsResponse
            {
                Status = "Ok",
                Transactions =
                [
                    new Dictionary<string, object?>
                    {
                        ["customerAccountNumber"] = "000CUST001",
                        ["secondReference"] = "DOC-ALT",
                        ["transactionReference"] = "TR-200",
                        ["sysTraderTranType"] = "4",
                        ["transactionDate"] = "2026-08-01T12:30:00Z",
                        ["netAmount"] = "100.00",
                        ["taxAmount"] = 20m,
                        ["grossAmount"] = 120m,
                        ["outstandingAmount"] = 0m,
                        ["allocatedValue"] = 120m,
                        ["documentDiscountedValue"] = 0m,
                        ["isPaid"] = "true",
                        ["isFullyPaid"] = true
                    }
                ]
            });
        _persistenceRepository
            .Setup(x => x.UpsertExternalTransactionAsync(It.IsAny<SageExternalTransactionUpsertRequest>(), It.IsAny<CancellationToken>()))
            .Callback<SageExternalTransactionUpsertRequest, CancellationToken>((request, _) => capturedRequest = request)
            .ReturnsAsync(101);
        _persistenceRepository
            .Setup(x => x.ReconcileInvoiceAsync(101, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageReconcileInvoiceResult
            {
                ExternalTransactionId = 101,
                IsMatched = true,
                MatchedTransactionId = 55,
                MatchedInvoiceRequestId = 66,
                MatchedJobId = 77,
                MatchRule = "DocumentNo"
            });
        _persistenceRepository
            .Setup(x => x.ApplyAggregatePaymentStateAsync(101, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageAggregatePaymentStateResult
            {
                ExternalTransactionId = 101,
                PaymentStateCode = SageAggregatePaymentStateCodes.Paid,
                GrossAmount = 120m,
                AllocatedValue = 120m,
                OutstandingAmount = 0m,
                IsPaid = true,
                IsFullyPaid = true
            });
        _persistenceRepository
            .Setup(x => x.UpdateInboundStatusFromExternalTransactionAsync(
                _documentGuid, 101, It.IsAny<DateTime?>(), It.IsAny<CancellationToken>()))
            .Callback<Guid, long, DateTime?, CancellationToken>((_, _, nextPoll, _) => capturedNextPoll = nextPoll)
            .Returns(Task.CompletedTask);

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        Assert.Equal(1, result.ExternalTransactionCount);
        Assert.Equal(1, result.ReconciledInvoiceCount);
        Assert.Equal(1, result.FullyPaidCount);
        Assert.False(result.ShouldContinuePolling);
        Assert.Null(capturedNextPoll);

        Assert.NotNull(capturedRequest);
        Assert.Equal("000CUST001", capturedRequest.SageAccountReference);
        Assert.Equal("DOC-ALT", capturedRequest.SageDocumentNo);
        Assert.Equal("TR-200", capturedRequest.SageTransactionReference);
        Assert.Equal(4, capturedRequest.SageTransactionTypeCode);
        Assert.Equal(120m, capturedRequest.GrossAmount);
        Assert.False(string.IsNullOrWhiteSpace(capturedRequest.SourceHash));
        Assert.True(capturedRequest.RawPayloadJson.Contains("TR-200", StringComparison.Ordinal));

        // CYB-568 (restoring CYB-543): the production Sage source only flips the
        // invoice row to allocated, so the invoice row is passed on to be
        // materialised as a Receipt. The procedure ignores it if a real 5/6 row exists.
        _persistenceRepository.Verify(x => x.ApplyAggregatePaymentStateAsync(
            101, It.IsAny<CancellationToken>()), Times.Once);
        _persistenceRepository.Verify(x => x.MaterialiseReceiptAndAllocationAsync(
            101, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SyncAsync_PartiallyPaidRowSchedulesNextPoll()
    {
        DateTime? capturedNextPoll = null;
        var before = DateTime.UtcNow;

        SetSingleTransactionRow();
        _persistenceRepository
            .Setup(x => x.ReconcileInvoiceAsync(101, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageReconcileInvoiceResult { ExternalTransactionId = 101, IsMatched = true });
        _persistenceRepository
            .Setup(x => x.ApplyAggregatePaymentStateAsync(101, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageAggregatePaymentStateResult
            {
                ExternalTransactionId = 101,
                PaymentStateCode = SageAggregatePaymentStateCodes.PartiallyPaid,
                GrossAmount = 120m,
                AllocatedValue = 20m,
                OutstandingAmount = 100m
            });
        _persistenceRepository
            .Setup(x => x.UpdateInboundStatusFromExternalTransactionAsync(
                _documentGuid, 101, It.IsAny<DateTime?>(), It.IsAny<CancellationToken>()))
            .Callback<Guid, long, DateTime?, CancellationToken>((_, _, nextPoll, _) => capturedNextPoll = nextPoll)
            .Returns(Task.CompletedTask);

        var result = await CreateService().SyncAsync(_documentGuid, force: false);
        var after = DateTime.UtcNow;

        Assert.True(result.IsSuccess);
        Assert.Equal(1, result.PartiallyPaidCount);
        Assert.True(result.ShouldContinuePolling);
        Assert.NotNull(capturedNextPoll);
        Assert.InRange(capturedNextPoll.Value, before.AddHours(4), after.AddHours(4).AddSeconds(1));
    }

    [Fact]
    public async Task SyncAsync_UnmatchedAllocationSourceDoesNotMaterialiseTransaction()
    {
        SetSingleTransactionRow(5);
        _persistenceRepository
            .Setup(x => x.ReconcileInvoiceAsync(101, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageReconcileInvoiceResult { ExternalTransactionId = 101, IsMatched = false });
        _persistenceRepository
            .Setup(x => x.ApplyAggregatePaymentStateAsync(101, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageAggregatePaymentStateResult
            {
                ExternalTransactionId = 101,
                PaymentStateCode = SageAggregatePaymentStateCodes.PartiallyPaid,
                GrossAmount = 120m,
                AllocatedValue = 20m,
                OutstandingAmount = 100m
            });

        var result = await CreateService().SyncAsync(_documentGuid, force: false);

        Assert.True(result.IsSuccess);
        _persistenceRepository.Verify(x => x.MaterialiseReceiptAndAllocationAsync(
            It.IsAny<long>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Theory]
    [InlineData(5, false, 1)]
    [InlineData(1, false, 1)]
    // CYB-555: with allocations on, a credit note or receipt that the
    // document-number lookup also returns is not materialised a second time.
    [InlineData(5, true, 0)]
    [InlineData(1, true, 0)]
    public async Task SyncAsync_MatchedExplicitAllocationSourceIsMaterialisedWithoutReplacingInvoiceStatus(
        int sageTransactionTypeCode, bool useSalesAllocations, int expectedMaterialisations)
    {
        _options.UseSalesAllocations = useSalesAllocations;
        _sageApiClient
            .Setup(x => x.FetchCustomerTransactionsAsync(
                SageDataset.group, "CUST001", "INV-100", null, true, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageFetchCustomerTransactionsResponse
            {
                Status = "Ok",
                Transactions =
                [
                    new Dictionary<string, object?>
                    {
                        ["transactionReference"] = "SAS-100",
                        ["sysTraderTranType"] = sageTransactionTypeCode,
                        ["grossAmount"] = 30m,
                        ["allocatedValue"] = 30m
                    }
                ]
            });
        _persistenceRepository
            .Setup(x => x.ReconcileInvoiceAsync(101, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageReconcileInvoiceResult
            {
                ExternalTransactionId = 101,
                IsMatched = true,
                MatchedTransactionId = 55
            });
        _persistenceRepository
            .Setup(x => x.ApplyAggregatePaymentStateAsync(101, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageAggregatePaymentStateResult
            {
                ExternalTransactionId = 101,
                PaymentStateCode = SageAggregatePaymentStateCodes.Paid,
                GrossAmount = 30m,
                AllocatedValue = 30m,
                OutstandingAmount = 0m
            });

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        Assert.Equal(1, result.ExternalTransactionCount);
        Assert.Equal(1, result.ReconciledInvoiceCount);
        Assert.Equal(0, result.FullyPaidCount);
        _sageApiClient.Verify(x => x.FetchCustomerTransactionsAsync(
            SageDataset.group, "CUST001", "INV-100", null, true, It.IsAny<CancellationToken>()), Times.Once);
        _persistenceRepository.Verify(x => x.MaterialiseReceiptAndAllocationAsync(
            101, It.IsAny<CancellationToken>()), Times.Exactly(expectedMaterialisations));
        _persistenceRepository.Verify(x => x.UpdateInboundStatusFromExternalTransactionAsync(
            It.IsAny<Guid>(), It.IsAny<long>(), It.IsAny<DateTime?>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    // CYB-568: UK dd/MM/yyyy dates were parsed as US MM/dd, so a receipt dated
    // 4 September 2026 was stored as 9 April 2026.
    [Theory]
    [InlineData("04/09/2026", 2026, 9, 4)]
    [InlineData("04/09/2026 00:00:00", 2026, 9, 4)]
    [InlineData("03/09/2026 14:25", 2026, 9, 3)]
    [InlineData("4/9/2026", 2026, 9, 4)]
    [InlineData("25/08/2026", 2026, 8, 25)]
    [InlineData("2026-09-04T00:00:00", 2026, 9, 4)]
    [InlineData("2026-08-01T12:30:00Z", 2026, 8, 1)]
    [InlineData("2026-09-04", 2026, 9, 4)]
    public async Task SyncAsync_ReadsSageTransactionDateAsIsoOrUkDayFirst(
        string sageTransactionDate,
        int expectedYear,
        int expectedMonth,
        int expectedDay)
    {
        var capturedRequest = await SyncSingleRowAndCaptureUpsertAsync(sageTransactionDate);

        Assert.NotNull(capturedRequest.TransactionDateUtc);
        Assert.Equal(new DateTime(expectedYear, expectedMonth, expectedDay), capturedRequest.TransactionDateUtc.Value.Date);
    }

    [Theory]
    [InlineData("")]
    [InlineData("not a date")]
    [InlineData("09/25/2026")]
    public async Task SyncAsync_UnparseableOrUsOrderedSageTransactionDate_IsNull(string sageTransactionDate)
    {
        var capturedRequest = await SyncSingleRowAndCaptureUpsertAsync(sageTransactionDate);

        // Null lets the materialise procedure fall back to the matched invoice date.
        Assert.Null(capturedRequest.TransactionDateUtc);
    }

    private async Task<SageExternalTransactionUpsertRequest> SyncSingleRowAndCaptureUpsertAsync(string sageTransactionDate)
    {
        SageExternalTransactionUpsertRequest? capturedRequest = null;

        _sageApiClient
            .Setup(x => x.FetchCustomerTransactionsAsync(
                SageDataset.group, "CUST001", "INV-100", null, It.IsAny<bool>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageFetchCustomerTransactionsResponse
            {
                Status = "Ok",
                Transactions =
                [
                    new Dictionary<string, object?>
                    {
                        ["transactionReference"] = "SR-568",
                        ["sysTraderTranType"] = 1,
                        ["transactionDate"] = System.Text.Json.JsonSerializer.SerializeToElement(sageTransactionDate)
                    }
                ]
            });
        _persistenceRepository
            .Setup(x => x.UpsertExternalTransactionAsync(It.IsAny<SageExternalTransactionUpsertRequest>(), It.IsAny<CancellationToken>()))
            .Callback<SageExternalTransactionUpsertRequest, CancellationToken>((request, _) => capturedRequest = request)
            .ReturnsAsync(101);

        var result = await CreateService().SyncAsync(_documentGuid, force: false);

        Assert.True(result.IsSuccess);
        Assert.NotNull(capturedRequest);
        return capturedRequest;
    }

    [Fact]
    public async Task SyncAsync_ExceptionAfterClaimMarksRetryableFailureAndAttempt()
    {
        _sageApiClient
            .Setup(x => x.FetchCustomerTransactionsAsync(
                It.IsAny<SageDataset>(), It.IsAny<string?>(), It.IsAny<string?>(), It.IsAny<int?>(), It.IsAny<bool>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("Inbound wrapper unavailable."));

        var result = await CreateService().SyncAsync(_documentGuid, force: false);

        Assert.False(result.IsSuccess);
        Assert.True(result.IsRetryableFailure);
        Assert.Equal("Inbound wrapper unavailable.", result.Message);
        _idempotencyRepository.Verify(x => x.MarkFailureAsync(
            _documentGuid,
            It.Is<string>(error => error.Contains("Inbound wrapper unavailable.", StringComparison.Ordinal)),
            true,
            It.IsAny<CancellationToken>()), Times.Once);
        _idempotencyRepository.Verify(x => x.InsertAttemptAsync(
            It.IsAny<long>(), _documentGuid, 12, "SyncCustomerTransactions",
            It.IsAny<DateTime>(), It.IsAny<DateTime?>(), false, true, "Failed",
            "Inbound wrapper unavailable.", It.IsAny<string?>(), It.IsAny<string?>(), It.IsAny<string?>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task EnqueueAsync_EmptyGuidThrowsArgumentException()
    {
        await Assert.ThrowsAsync<ArgumentException>(() => CreateService().EnqueueAsync(Guid.Empty, forceRequeue: false));
        _worklistRepository.Verify(x => x.EnqueueAsync(It.IsAny<Guid>(), It.IsAny<bool>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Theory]
    [InlineData(false, "enqueued")]
    [InlineData(true, "requeued")]
    public async Task EnqueueAsync_PassesForceFlagAndReturnsExpectedMessage(bool forceRequeue, string expectedWord)
    {
        var result = await CreateService().EnqueueAsync(_documentGuid, forceRequeue);

        Assert.True(result.IsSuccess);
        Assert.Equal(_documentGuid, result.CymBuildDocumentGuid);
        Assert.True(result.Message.Contains(expectedWord, StringComparison.OrdinalIgnoreCase));
        _worklistRepository.Verify(x => x.EnqueueAsync(
            _documentGuid, forceRequeue, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SyncAsync_MatchedInvoiceAppliesSageDocumentNumberToMatchedTransaction()
    {
        var matchedTransactionGuid = Guid.Parse("55555555-5555-5555-5555-555555555555");

        SetSingleTransactionRow();
        _persistenceRepository
            .Setup(x => x.ReconcileInvoiceAsync(101, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageReconcileInvoiceResult
            {
                ExternalTransactionId = 101,
                IsMatched = true,
                MatchedTransactionId = 55,
                MatchedTransactionGuid = matchedTransactionGuid,
                MatchRule = "DocumentNo"
            });

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        _persistenceRepository.Verify(x => x.ApplySageInvoiceDocumentNumberAsync(
            matchedTransactionGuid, "INV-100", It.IsAny<int>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SyncAsync_UnmatchedInvoiceDoesNotApplySageDocumentNumber()
    {
        SetSingleTransactionRow();
        _persistenceRepository
            .Setup(x => x.ReconcileInvoiceAsync(101, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageReconcileInvoiceResult { ExternalTransactionId = 101, IsMatched = false });

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        _persistenceRepository.Verify(x => x.ApplySageInvoiceDocumentNumberAsync(
            It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<int>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SyncAsync_MatchedCreditNoteDoesNotApplySageDocumentNumber()
    {
        var matchedTransactionGuid = Guid.Parse("66666666-6666-6666-6666-666666666666");

        SetSingleTransactionRow(SageCreditNoteTransactionTypeCode);
        _persistenceRepository
            .Setup(x => x.ReconcileInvoiceAsync(101, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageReconcileInvoiceResult
            {
                ExternalTransactionId = 101,
                IsMatched = true,
                MatchedTransactionId = 55,
                MatchedTransactionGuid = matchedTransactionGuid,
                MatchRule = "DocumentNo"
            });

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        _persistenceRepository.Verify(x => x.ApplySageInvoiceDocumentNumberAsync(
            It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<int>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SyncAsync_RowForAnotherAccount_IsNotStoredOrMaterialised()
    {
        // CYB-555: SFA ignores the account filter, so the document-number lookup can
        // return another customer's row with the same reference (LIVE: a 2010 invoice
        // for 12955 alongside a credit note for 30607).
        _sageApiClient
            .Setup(x => x.FetchCustomerTransactionsAsync(
                SageDataset.group, "CUST001", "INV-100", null, true, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageFetchCustomerTransactionsResponse
            {
                Status = "Ok",
                Transactions =
                [
                    new Dictionary<string, object?>
                    {
                        ["customerAccountNumber"] = "12955",
                        ["secondReference"] = "INV-100",
                        ["transactionReference"] = "TR-OTHER",
                        ["sysTraderTranType"] = 4,
                        ["allocatedValue"] = 1090.40m,
                        ["isPaid"] = true,
                        ["isFullyPaid"] = true
                    }
                ]
            });

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        Assert.Equal(0, result.ExternalTransactionCount);
        _persistenceRepository.Verify(x => x.UpsertExternalTransactionAsync(
            It.IsAny<SageExternalTransactionUpsertRequest>(), It.IsAny<CancellationToken>()), Times.Never);
        _persistenceRepository.Verify(x => x.MaterialiseReceiptAndAllocationAsync(
            It.IsAny<long>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    // CYB-555: SFA (ticket #58103) confirmed 1 = Receipt, 2 = Payment (refund),
    // 6 = Opening Balance Invoice and 7 = Opening Balance Credit Note. CymBuild
    // used to treat 6 as a Receipt; none of these may be stored or materialised.
    [Theory]
    [InlineData(2)]
    [InlineData(6)]
    [InlineData(7)]
    public async Task SyncAsync_UnsupportedSageTransactionType_IsNotStoredOrMaterialised(int sageTransactionTypeCode)
    {
        SetSingleTransactionRow(sageTransactionTypeCode);

        var result = await CreateService().SyncAsync(_documentGuid, force: false);

        Assert.True(result.IsSuccess);
        Assert.Equal(0, result.ExternalTransactionCount);
        _persistenceRepository.Verify(x => x.UpsertExternalTransactionAsync(
            It.IsAny<SageExternalTransactionUpsertRequest>(), It.IsAny<CancellationToken>()), Times.Never);
        _persistenceRepository.Verify(x => x.MaterialiseReceiptAndAllocationAsync(
            It.IsAny<long>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    private const int SageCreditNoteTransactionTypeCode = 5;

    private void SetSingleTransactionRow(int sageTransactionTypeCode = 4)
    {
        _sageApiClient
            .Setup(x => x.FetchCustomerTransactionsAsync(
                SageDataset.group, "CUST001", "INV-100", null, It.IsAny<bool>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageFetchCustomerTransactionsResponse
            {
                Status = "Ok",
                Transactions =
                [
                    new Dictionary<string, object?>
                    {
                        ["accountReference"] = "CUST001",
                        ["documentNo"] = "INV-100",
                        ["transactionReference"] = "TR-100",
                        ["sysTraderTranType"] = sageTransactionTypeCode,
                        ["grossAmount"] = 120m
                    }
                ]
            });
    }

    // ---------------------------------------------------------------------
    // CYB-555: what settled an invoice, from GET /api/v2/sales-allocations.
    // ---------------------------------------------------------------------

    // LIVE session 212563132: CDM8506 invoice 3489107 (+3072) against credit
    // note 3494317 (type 5; -3072 gross, -512 VAT, -2560 net).
    [Fact]
    public async Task SyncAsync_InvoiceSettledByCreditNote_RecordsACreditNoteNotAReceipt()
    {
        SetUpSettledInvoice(urn: 3489107, gross: 3072m, allocated: 3072m);
        SetUpAllocations("3489107", Session("212563132", "2026-09-09",
            Requested("3489107", 3072m),
            Counterpart("3494317", -3072m, 5, "0000046930", gross: -3072m, tax: -512m, net: -2560m)));

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        var recorded = Assert.Single(_recordedAllocations);
        Assert.Equal(101, recorded.InvoiceExternalTransactionId);
        Assert.Equal("3494317", recorded.CounterpartUrn);
        Assert.Equal(5, recorded.CounterpartTypeCode);
        Assert.Equal("0000046930", recorded.CounterpartReference);
        Assert.Equal(-3072m, recorded.CounterpartGrossAmount);
        Assert.Equal(-512m, recorded.CounterpartTaxAmount);
        Assert.Equal(-2560m, recorded.CounterpartNetAmount);
        Assert.Equal("212563132", recorded.AllocationHeaderId);
        Assert.Equal(3072m, recorded.AppliedAmount);
        _sageApiClient.Verify(x => x.FetchSalesAllocationsAsync(
            SageDataset.group, "000CUST001", "3489107", It.IsAny<CancellationToken>()), Times.Once);
        _persistenceRepository.Verify(x => x.ReconcileAllocationAsync(401, It.IsAny<CancellationToken>()), Times.Once);
        // Never the CYB-568 "settled means Receipt" fallback.
        _persistenceRepository.Verify(x => x.MaterialiseReceiptAndAllocationAsync(
            It.IsAny<long>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SyncAsync_InvoiceSettledByReceipt_RecordsAReceipt()
    {
        SetUpSettledInvoice(urn: 9000027, gross: 900m, allocated: 900m);
        SetUpAllocations("9000027", Session("200000001", "2026-10-19",
            Requested("9000027", 900m),
            Counterpart("9000028", -900m, 1, "SR-00028", gross: -900m, tax: 0m, net: -900m)));

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        var recorded = Assert.Single(_recordedAllocations);
        Assert.Equal(1, recorded.CounterpartTypeCode);
        Assert.Equal(900m, recorded.AppliedAmount);
        _persistenceRepository.Verify(x => x.MaterialiseReceiptAndAllocationAsync(
            It.IsAny<long>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    // LIVE session 212381948: MAC073 receipt 3491986 (-20,162.00) paid invoice
    // 3485347 (16,562.00) and invoice 3390694 (3,600.00).
    [Fact]
    public async Task SyncAsync_OneReceiptForTwoInvoices_AppliesOnlyThisInvoicesShareAndIgnoresTheOtherInvoice()
    {
        SetUpSettledInvoice(urn: 3485347, gross: 19874.40m, allocated: 16562m, outstanding: 3312.40m);
        SetUpAllocations("3485347", Session("212381948", "2026-08-28",
            Requested("3485347", 16562m),
            Counterpart("3491986", -20162m, 1, "3491986", gross: -20162m, tax: 0m, net: -20162m),
            Counterpart("3390694", 3600m, 4, "INV-3390694", gross: 3600m, tax: 600m, net: 3000m)));

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        var recorded = Assert.Single(_recordedAllocations);
        Assert.Equal("3491986", recorded.CounterpartUrn);
        Assert.Equal(1, recorded.CounterpartTypeCode);
        Assert.Equal(-20162m, recorded.CounterpartGrossAmount);
        Assert.Equal(16562m, recorded.AppliedAmount);
        Assert.Equal(1, result.PartiallyPaidCount);
    }

    [Fact]
    public async Task SyncAsync_PartPayment_AppliesTheInvoicesOwnAllocationAndKeepsPolling()
    {
        SetUpSettledInvoice(urn: 9000031, gross: 900m, allocated: 450m, outstanding: 450m);
        SetUpAllocations("9000031", Session("200000009", "2026-10-19",
            Requested("9000031", 450m),
            Counterpart("9000032", -450m, 1, "SR-00032", gross: -450m, tax: 0m, net: -450m)));

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        Assert.Equal(450m, Assert.Single(_recordedAllocations).AppliedAmount);
        Assert.Equal(1, result.PartiallyPaidCount);
        Assert.True(result.ShouldContinuePolling);
    }

    [Fact]
    public async Task SyncAsync_TwoSessions_RecordsEachSessionsShare()
    {
        SetUpSettledInvoice(urn: 9000031, gross: 900m, allocated: 900m);
        SetUpAllocations("9000031",
            Session("200000009", "2026-10-19",
                Requested("9000031", 450m),
                Counterpart("9000032", -450m, 1, "SR-00032", gross: -450m, tax: 0m, net: -450m)),
            Session("200000010", "2026-10-20",
                Requested("9000031", 450m),
                Counterpart("9000040", -450m, 5, "SC-00040", gross: -450m, tax: -75m, net: -375m)));

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        Assert.Collection(
            _recordedAllocations,
            first =>
            {
                Assert.Equal("200000009", first.AllocationHeaderId);
                Assert.Equal(1, first.CounterpartTypeCode);
                Assert.Equal(450m, first.AppliedAmount);
            },
            second =>
            {
                Assert.Equal("200000010", second.AllocationHeaderId);
                Assert.Equal(5, second.CounterpartTypeCode);
                Assert.Equal(450m, second.AppliedAmount);
            });
    }

    [Fact]
    public async Task SyncAsync_UnresolvedCounterpart_IsRecordedAsSettledMethodUnknown_NeverAReceipt()
    {
        SetUpSettledInvoice(urn: 9000027, gross: 900m, allocated: 900m);
        SetUpAllocations("9000027", Session("200000001", "2026-10-19",
            Requested("9000027", 900m),
            new SageSalesAllocationRow { Urn = "9000028", TransactionDate = "2026-10-19", AllocationValue = -900m, TypeResolved = false }));

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        var recorded = Assert.Single(_recordedAllocations);
        Assert.Null(recorded.CounterpartTypeCode);
        Assert.Equal(900m, recorded.AppliedAmount);
        _persistenceRepository.Verify(x => x.MaterialiseReceiptAndAllocationAsync(
            It.IsAny<long>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SyncAsync_NoSessions_RecordsNothing()
    {
        SetUpSettledInvoice(urn: 3489107, gross: 3072m, allocated: 3072m);
        SetUpAllocations("3489107");

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        Assert.Empty(_recordedAllocations);
        _persistenceRepository.Verify(x => x.MaterialiseReceiptAndAllocationAsync(
            It.IsAny<long>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SyncAsync_SageError500_WritesNothingAndIsRetriedLater()
    {
        SetUpSettledInvoice(urn: 3489107, gross: 3072m, allocated: 3072m);
        _sageApiClient
            .Setup(x => x.FetchSalesAllocationsAsync(
                It.IsAny<SageDataset>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("sage_error", null, HttpStatusCode.InternalServerError));

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.False(result.IsSuccess);
        Assert.True(result.IsRetryableFailure);
        _persistenceRepository.Verify(x => x.UpsertExternalTransactionAsync(
            It.IsAny<SageExternalTransactionUpsertRequest>(), It.IsAny<CancellationToken>()), Times.Never);
        Assert.Empty(_recordedAllocations);
        _idempotencyRepository.Verify(x => x.MarkFailureAsync(
            _documentGuid, It.IsAny<string>(), true, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SyncAsync_BadRequest400_WritesNothingAndIsNotRetried()
    {
        SetUpSettledInvoice(urn: 3489107, gross: 3072m, allocated: 3072m);
        _sageApiClient
            .Setup(x => x.FetchSalesAllocationsAsync(
                It.IsAny<SageDataset>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("urn must be numeric", null, HttpStatusCode.BadRequest));

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.False(result.IsSuccess);
        Assert.False(result.IsRetryableFailure);
        _persistenceRepository.Verify(x => x.UpsertExternalTransactionAsync(
            It.IsAny<SageExternalTransactionUpsertRequest>(), It.IsAny<CancellationToken>()), Times.Never);
        _idempotencyRepository.Verify(x => x.MarkFailureAsync(
            _documentGuid, It.IsAny<string>(), false, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SyncAsync_SalesAllocationsOff_FallsBackToTheCyb568Receipt()
    {
        _options.UseSalesAllocations = false;
        SetUpSettledInvoice(urn: 3489107, gross: 3072m, allocated: 3072m);

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        _sageApiClient.Verify(x => x.FetchSalesAllocationsAsync(
            It.IsAny<SageDataset>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
        _persistenceRepository.Verify(x => x.MaterialiseReceiptAndAllocationAsync(
            101, It.IsAny<CancellationToken>()), Times.Once);
    }

    // v2: account codes and instrument numbers are strings with their zeros
    // kept; uniqueReferenceNumber is still a number.
    [Fact]
    public async Task SyncAsync_V2Payload_KeepsTheZerosAndSendsTheUrnAsDigits()
    {
        const string v2Json = """
            {
              "status": "Ok",
              "transactions": [
                {
                  "customerAccountNumber": "00030607",
                  "accountReference": "00030607",
                  "instrumentNo": "0000046930",
                  "transactionReference": "0000046930",
                  "secondReference": "0001117996",
                  "sysTraderTranType": 4,
                  "uniqueReferenceNumber": 3489107,
                  "transactionDate": "2026-08-28T00:00:00",
                  "netAmount": 2560.00,
                  "taxAmount": 512.00,
                  "grossAmount": 3072.00,
                  "allocatedValue": 3072.00,
                  "outstandingAmount": 0,
                  "isPaid": true,
                  "isFullyPaid": true,
                  "nominalAnalysisItems": [ { "nominalAccountNumber": "31010", "goodsValueInBaseCurrency": 2560.00 } ],
                  "taxAnalysisItems": [ { "taxCode": 1, "taxRate": 20.0, "taxOnGoodsValue": 512.00 } ]
                }
              ]
            }
            """;
        var response = JsonSerializer.Deserialize<SageFetchCustomerTransactionsResponse>(
            v2Json, new JsonSerializerOptions(JsonSerializerDefaults.Web))!;
        _target.SageAccountReference = "30607";
        SageExternalTransactionUpsertRequest? stored = null;
        _sageApiClient
            .Setup(x => x.FetchCustomerTransactionsAsync(
                SageDataset.group, "30607", "INV-100", null, true, It.IsAny<CancellationToken>()))
            .ReturnsAsync(response);
        _persistenceRepository
            .Setup(x => x.UpsertExternalTransactionAsync(It.IsAny<SageExternalTransactionUpsertRequest>(), It.IsAny<CancellationToken>()))
            .Callback<SageExternalTransactionUpsertRequest, CancellationToken>((request, _) => stored = request)
            .ReturnsAsync(101);
        SetUpReconcile(101, matchedTransactionId: 55);
        SetUpAggregate(gross: 3072m, allocated: 3072m, outstanding: 0m);
        _sageApiClient
            .Setup(x => x.FetchSalesAllocationsAsync(
                SageDataset.group, "00030607", "3489107", It.IsAny<CancellationToken>()))
            .ReturnsAsync(AllocationsResponse("3489107"));

        var result = await CreateService().SyncAsync(_documentGuid, force: true);

        Assert.True(result.IsSuccess);
        Assert.NotNull(stored);
        Assert.Equal("00030607", stored.SageAccountReference);
        Assert.Equal(3072m, stored.GrossAmount);
        Assert.Equal(512m, stored.TaxAmount);
        Assert.Contains("\"instrumentNo\":\"0000046930\"", stored.RawPayloadJson, StringComparison.Ordinal);
        _sageApiClient.Verify(x => x.FetchSalesAllocationsAsync(
            SageDataset.group, "00030607", "3489107", It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    // The invoice is the only one in the session: each row's own value.
    [InlineData(900, new[] { -500.0, -400.0 }, new[] { 500.0, 400.0 })]
    // One row: all of it, whatever the row's own (wider) value.
    [InlineData(16562, new[] { -20162.0 }, new[] { 16562.0 })]
    // Several rows and other invoices: in proportion, remainder on the last.
    [InlineData(100, new[] { -100.0, -200.0 }, new[] { 33.33, 66.67 })]
    public void ApportionAppliedAmount_SplitsTheInvoicesShareAcrossTheRowsThatSettledIt(
        double appliedToInvoice, double[] rowValues, double[] expectedShares)
    {
        var rows = rowValues
            .Select((value, i) => new SageSalesAllocationRow { Urn = $"{i}", AllocationValue = (decimal)value })
            .ToList();

        var shares = SageInboundPaymentSyncService.ApportionAppliedAmount((decimal)appliedToInvoice, rows);

        Assert.Equal(expectedShares.Select(x => (decimal)x), shares);
    }

    // A type 4 invoice row on account 000CUST001 with the given URN and
    // amounts, reconciled to CymBuild transaction 55 as external row 101.
    private void SetUpSettledInvoice(long urn, decimal gross, decimal allocated, decimal outstanding = 0m)
    {
        _sageApiClient
            .Setup(x => x.FetchCustomerTransactionsAsync(
                SageDataset.group, "CUST001", "INV-100", null, true, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageFetchCustomerTransactionsResponse
            {
                Status = "Ok",
                Transactions =
                [
                    new Dictionary<string, object?>
                    {
                        ["customerAccountNumber"] = "000CUST001",
                        ["secondReference"] = "DOC-ALT",
                        ["transactionReference"] = "TR-200",
                        ["sysTraderTranType"] = 4,
                        ["uniqueReferenceNumber"] = urn,
                        ["grossAmount"] = gross,
                        ["outstandingAmount"] = outstanding,
                        ["allocatedValue"] = allocated,
                        ["isPaid"] = true,
                        ["isFullyPaid"] = outstanding == 0m
                    }
                ]
            });
        SetUpReconcile(101, matchedTransactionId: 55);
        SetUpAggregate(gross, allocated, outstanding);
    }

    private void SetUpAggregate(decimal gross, decimal allocated, decimal outstanding)
    {
        _persistenceRepository
            .Setup(x => x.ApplyAggregatePaymentStateAsync(101, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageAggregatePaymentStateResult
            {
                ExternalTransactionId = 101,
                PaymentStateCode = outstanding == 0m
                    ? SageAggregatePaymentStateCodes.Paid
                    : SageAggregatePaymentStateCodes.PartiallyPaid,
                GrossAmount = gross,
                AllocatedValue = allocated,
                OutstandingAmount = outstanding,
                IsPaid = true,
                IsFullyPaid = outstanding == 0m
            });
    }

    private void SetUpReconcile(long externalTransactionId, long matchedTransactionId)
    {
        _persistenceRepository
            .Setup(x => x.ReconcileInvoiceAsync(externalTransactionId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageReconcileInvoiceResult
            {
                ExternalTransactionId = externalTransactionId,
                IsMatched = true,
                MatchedTransactionId = matchedTransactionId,
                MatchRule = "ReservedInvoiceNumber=SageDocumentNo"
            });
    }

    private void SetUpAllocations(string invoiceUrn, params SageSalesAllocationSession[] sessions)
    {
        _sageApiClient
            .Setup(x => x.FetchSalesAllocationsAsync(
                SageDataset.group, "000CUST001", invoiceUrn, It.IsAny<CancellationToken>()))
            .ReturnsAsync(AllocationsResponse(invoiceUrn, sessions));
    }

    private static SageFetchSalesAllocationsResponse AllocationsResponse(string invoiceUrn, params SageSalesAllocationSession[] sessions)
    {
        return new SageFetchSalesAllocationsResponse
        {
            Status = "Ok",
            AccountReference = "000CUST001",
            Urn = invoiceUrn,
            Sessions = [.. sessions]
        };
    }

    private static SageSalesAllocationSession Session(string allocationHeaderId, string sessionDate, params SageSalesAllocationRow[] rows)
    {
        return new SageSalesAllocationSession
        {
            AllocationHeaderId = allocationHeaderId,
            SessionDate = sessionDate,
            Rows = [.. rows]
        };
    }

    private static SageSalesAllocationRow Requested(string urn, decimal allocationValue)
    {
        return new SageSalesAllocationRow
        {
            Urn = urn,
            TransactionDate = "2026-08-28",
            AllocationValue = allocationValue,
            IsRequested = true
        };
    }

    private static SageSalesAllocationRow Counterpart(
        string urn,
        decimal allocationValue,
        int sysTraderTranType,
        string transactionReference,
        decimal gross,
        decimal tax,
        decimal net)
    {
        return new SageSalesAllocationRow
        {
            Urn = urn,
            TransactionDate = "2026-09-07",
            AllocationValue = allocationValue,
            TypeResolved = true,
            SysTraderTranType = sysTraderTranType,
            TransactionReference = transactionReference,
            InstrumentNo = transactionReference,
            SecondReference = transactionReference,
            GrossAmount = gross,
            TaxAmount = tax,
            NetAmount = net
        };
    }

    private SageInboundPaymentSyncService CreateService()
    {
        return new SageInboundPaymentSyncService(
            Mock.Of<ILogger<SageInboundPaymentSyncService>>(),
            _readRepository.Object,
            _idempotencyRepository.Object,
            _persistenceRepository.Object,
            _worklistRepository.Object,
            _sageApiClient.Object,
            Options.Create(_options));
    }
}
