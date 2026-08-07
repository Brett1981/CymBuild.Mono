using Concursus.API.Sage.SOAP.Interface;
using Concursus.API.Sage.SOAP.Models;
using Concursus.API.Services.Finance;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Concursus.API.Tests.Finance;

public sealed class SageInboundPaymentSyncServiceTests
{
    private readonly Guid _documentGuid = Guid.Parse("44444444-4444-4444-4444-444444444444");
    private readonly SageInboundSyncTarget _target;
    private readonly Mock<ISageInboundPaymentReadRepository> _readRepository = new();
    private readonly Mock<ISageInboundPaymentIdempotencyRepository> _idempotencyRepository = new();
    private readonly Mock<ISageInboundPaymentPersistenceRepository> _persistenceRepository = new();
    private readonly Mock<ISageInboundPaymentWorklistRepository> _worklistRepository = new();
    private readonly Mock<ISageApiClient> _sageApiClient = new();

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
        _worklistRepository
            .Setup(x => x.EnqueueAsync(It.IsAny<Guid>(), It.IsAny<bool>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
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
        _idempotencyRepository.Verify(x => x.MarkSuccessAsync(
            _documentGuid, It.IsAny<DateTime?>(), It.IsAny<CancellationToken>()), Times.Once);
        _idempotencyRepository.Verify(x => x.InsertAttemptAsync(
            It.IsAny<long>(), _documentGuid, 12, "SyncCustomerTransactions",
            It.IsAny<DateTime>(), It.IsAny<DateTime?>(), true, false, "Succeeded",
            It.IsAny<string?>(), null, It.IsAny<string?>(), It.IsAny<string?>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SyncAsync_PaidMatchedRowMapsFallbacksAndMaterialisesReceipt()
    {
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
                        ["customerAccountNumber"] = "CUST-ALT",
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
        Assert.Equal("CUST-ALT", capturedRequest.SageAccountReference);
        Assert.Equal("DOC-ALT", capturedRequest.SageDocumentNo);
        Assert.Equal("TR-200", capturedRequest.SageTransactionReference);
        Assert.Equal(4, capturedRequest.SageTransactionTypeCode);
        Assert.Equal(120m, capturedRequest.GrossAmount);
        Assert.False(string.IsNullOrWhiteSpace(capturedRequest.SourceHash));
        Assert.True(capturedRequest.RawPayloadJson.Contains("TR-200", StringComparison.Ordinal));

        _persistenceRepository.Verify(x => x.MaterialiseReceiptAndAllocationAsync(101, It.IsAny<CancellationToken>()), Times.Once);
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
    public async Task SyncAsync_UnmatchedAllocatedRowDoesNotMaterialiseReceipt()
    {
        SetSingleTransactionRow();
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

    private void SetSingleTransactionRow()
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
                        ["grossAmount"] = 120m
                    }
                ]
            });
    }

    private SageInboundPaymentSyncService CreateService()
    {
        return new SageInboundPaymentSyncService(
            Mock.Of<ILogger<SageInboundPaymentSyncService>>(),
            _readRepository.Object,
            _idempotencyRepository.Object,
            _persistenceRepository.Object,
            _worklistRepository.Object,
            _sageApiClient.Object);
    }
}
