using Concursus.API.Sage.SOAP;
using Concursus.API.Sage.SOAP.Interface;
using Concursus.API.Sage.SOAP.Models;
using Concursus.API.Services.Finance;
using Concursus.Common.Shared.Models.Finance;
using Concursus.EF.Finance;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using Xunit;
using CommonSageCreateSalesOrderResponse = Concursus.Common.Shared.Models.Finance.SageCreateSalesOrderResponse;

namespace Concursus.API.Tests.Finance;

public sealed class TransactionToSageSubmissionServiceTests
{
    private readonly Guid _transitionGuid = Guid.Parse("11111111-1111-1111-1111-111111111111");
    private readonly Guid _transactionGuid = Guid.Parse("22222222-2222-2222-2222-222222222222");
    private readonly TransactionApprovedForSageSubmissionEvent _approvedEvent;
    private readonly ApprovedTransactionForSageReadModel _transaction;
    private readonly Concursus.Common.Shared.Models.Finance.SageCreateSalesOrderRequest _request;

    private readonly Mock<ITransactionToSageReadRepository> _readRepository = new();
    private readonly Mock<ITransactionToSageEligibilityValidator> _eligibilityValidator = new();
    private readonly Mock<ITransactionToSageIdempotencyService> _idempotencyService = new();
    private readonly Mock<IApprovedTransactionForSagePayloadFactory> _payloadFactory = new();
    private readonly Mock<ISageSalesOrderGateway> _gateway = new();
    private readonly Mock<ISageApiClient> _sageApiClient = new();
    private readonly Mock<ISageInboundDiagnosticsRepository> _diagnosticsRepository = new();
    private readonly Mock<IOptionsMonitor<SageApiOptions>> _sageOptions = new();
    private readonly Mock<IOptionsMonitor<SageTransactionSubmissionWorkerOptions>> _workerOptions = new();

    public TransactionToSageSubmissionServiceTests()
    {
        _approvedEvent = new TransactionApprovedForSageSubmissionEvent
        {
            EventGuid = Guid.Parse("33333333-3333-3333-3333-333333333333"),
            EventType = "TransactionApprovedForSageSubmission",
            OccurredOnUtc = new DateTime(2026, 8, 6, 8, 0, 0, DateTimeKind.Utc),
            TransitionGuid = _transitionGuid,
            TransitionId = 10,
            TransactionGuid = _transactionGuid,
            TransactionId = 20,
            TransactionNumber = "TX-100",
            ActorIdentityId = 42
        };

        _transaction = new ApprovedTransactionForSageReadModel
        {
            TransitionGuid = _transitionGuid,
            TransitionId = 10,
            TransactionGuid = _transactionGuid,
            TransactionId = 20,
            TransactionNumber = "TX-100",
            InvoiceNumber = "INV-100",
            ActorIdentityId = 42,
            RowStatus = 1,
            CustomerName = "Customer",
            SageCustomerReference = "CUST001",
            NetAmount = 100m,
            VatAmount = 20m,
            GrossAmount = 120m
        };

        _request = new Concursus.Common.Shared.Models.Finance.SageCreateSalesOrderRequest
        {
            Dataset = "group",
            AccountReference = "CUST001",
            CustomerOrderNo = "PO-100",
            Lines =
            [
                new SageCreateSalesOrderLineRequest
                {
                    ItemDescription = "Professional services",
                    NominalRef = "31010",
                    Quantity = 1,
                    UnitPrice = 100m
                }
            ]
        };

        _readRepository
            .Setup(x => x.DeserializeApprovedTransactionEvent(It.IsAny<string>()))
            .Returns(_approvedEvent);
        _readRepository
            .Setup(x => x.GetApprovedTransactionForSageAsync(_transitionGuid, It.IsAny<CancellationToken>()))
            .ReturnsAsync(_transaction);

        _idempotencyService
            .Setup(x => x.GetStatusAsync(_transactionGuid, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new TransactionToSageIdempotencyStatus { TransactionGuid = _transactionGuid });
        _idempotencyService
            .Setup(x => x.TryClaimAsync(
                It.IsAny<long>(),
                It.IsAny<Guid>(),
                It.IsAny<Guid>(),
                It.IsAny<int>(),
                It.IsAny<int>(),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new TransactionToSageIdempotencyClaimResult
            {
                TransactionGuid = _transactionGuid,
                TransitionGuid = _transitionGuid,
                ClaimAcquired = true,
                StatusCode = "Claimed"
            });
        _idempotencyService
            .Setup(x => x.MarkSuccessAsync(
                It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<int>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _idempotencyService
            .Setup(x => x.MarkFailureAsync(
                It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<bool>(),
                It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(),
                It.IsAny<int>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        _eligibilityValidator
            .Setup(x => x.ValidateAsync(
                It.IsAny<ApprovedTransactionForSageReadModel?>(),
                It.IsAny<bool>(),
                It.IsAny<bool>(),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(TransactionToSageEligibilityResult.Eligible());

        _payloadFactory.Setup(x => x.BuildJson(_transaction)).Returns("{\"request\":true}");
        _payloadFactory.Setup(x => x.Build(_transaction)).Returns(_request);

        _gateway
            .Setup(x => x.CreateSalesOrderAsync(_request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(CreateGatewayResponse());

        _diagnosticsRepository
            .Setup(x => x.SetTransactionSageReferenceIfMissingAsync(
                It.IsAny<long>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _diagnosticsRepository
            .Setup(x => x.ApplyTransactionReferencesAsync(
                It.IsAny<Guid?>(), It.IsAny<long?>(), It.IsAny<bool>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);

        _sageOptions.SetupGet(x => x.CurrentValue).Returns(new SageApiOptions
        {
            Enabled = true,
            BaseUrl = "https://sage.test"
        });
        _workerOptions.SetupGet(x => x.CurrentValue).Returns(new SageTransactionSubmissionWorkerOptions
        {
            Enabled = true,
            ClaimTimeoutMinutes = 23
        });
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_EmptyPayloadIsNonRetryable()
    {
        var result = await CreateService().ProcessApprovedTransactionAsync("   ");

        Assert.Equal(TransactionToSageProcessStatus.FailedNonRetryable, result.Status);
        Assert.Equal("invalid_outbox_payload", result.FailureCode);
        Assert.Equal(Guid.Empty, result.TransactionGuid);
        _readRepository.Verify(x => x.DeserializeApprovedTransactionEvent(It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_DeserializationFailureIsNonRetryable()
    {
        _readRepository.Setup(x => x.DeserializeApprovedTransactionEvent(It.IsAny<string>())).Returns((TransactionApprovedForSageSubmissionEvent?)null);

        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.Equal(TransactionToSageProcessStatus.FailedNonRetryable, result.Status);
        Assert.Equal("invalid_outbox_payload", result.FailureCode);
        _readRepository.Verify(x => x.GetApprovedTransactionForSageAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_InvalidEventIsNonRetryable()
    {
        _approvedEvent.EventType = string.Empty;

        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.Equal(TransactionToSageProcessStatus.FailedNonRetryable, result.Status);
        Assert.Equal("invalid_outbox_payload", result.FailureCode);
        Assert.Equal(_transitionGuid, result.TransitionGuid);
        Assert.Equal(_transactionGuid, result.TransactionGuid);
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_MissingReadModelIsRetryable()
    {
        _readRepository
            .Setup(x => x.GetApprovedTransactionForSageAsync(_transitionGuid, It.IsAny<CancellationToken>()))
            .ReturnsAsync((ApprovedTransactionForSageReadModel?)null);

        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.Equal(TransactionToSageProcessStatus.FailedRetryable, result.Status);
        Assert.True(result.IsRetryableFailure);
        Assert.Equal("read_model_not_found", result.FailureCode);
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_NotEligibleStopsBeforeClaim()
    {
        _eligibilityValidator
            .Setup(x => x.ValidateAsync(_transaction, true, false, It.IsAny<CancellationToken>()))
            .ReturnsAsync(TransactionToSageEligibilityResult.NotEligible(
                TransactionToSageEligibilityFailureReason.MissingCustomerMapping,
                "Customer mapping is missing."));

        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.Equal(TransactionToSageProcessStatus.NotEligible, result.Status);
        Assert.Equal("not_eligible", result.FailureCode);
        Assert.Equal("Customer mapping is missing.", result.Message);
        _idempotencyService.Verify(x => x.TryClaimAsync(
            It.IsAny<long>(), It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<int>(), It.IsAny<int>(), It.IsAny<CancellationToken>()), Times.Never);
        _gateway.Verify(x => x.CreateSalesOrderAsync(It.IsAny<Concursus.Common.Shared.Models.Finance.SageCreateSalesOrderRequest>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_ExistingSuccessfulStatusReturnsAlreadyProcessed()
    {
        _idempotencyService
            .Setup(x => x.GetStatusAsync(_transactionGuid, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new TransactionToSageIdempotencyStatus
            {
                TransactionGuid = _transactionGuid,
                IsAlreadyProcessed = true,
                SageOrderId = "SO-OLD",
                SageOrderNumber = "SO-OLD"
            });

        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.Equal(TransactionToSageProcessStatus.AlreadyProcessed, result.Status);
        Assert.True(result.IsSuccess);
        Assert.True(result.IsAlreadyProcessed);
        Assert.Equal("SO-OLD", result.SageOrderId);
        _idempotencyService.Verify(x => x.TryClaimAsync(
            It.IsAny<long>(), It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<int>(), It.IsAny<int>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_CompletedClaimReturnsAlreadyProcessed()
    {
        _idempotencyService
            .Setup(x => x.TryClaimAsync(20, _transactionGuid, _transitionGuid, 42, 23, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new TransactionToSageIdempotencyClaimResult
            {
                TransactionGuid = _transactionGuid,
                TransitionGuid = _transitionGuid,
                AlreadyProcessed = true,
                SageOrderId = "SO-CLAIM",
                SageOrderNumber = "SO-CLAIM"
            });

        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.Equal(TransactionToSageProcessStatus.AlreadyProcessed, result.Status);
        Assert.Equal("SO-CLAIM", result.SageOrderId);
        _gateway.Verify(x => x.CreateSalesOrderAsync(It.IsAny<Concursus.Common.Shared.Models.Finance.SageCreateSalesOrderRequest>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_ContendedClaimIsRetryable()
    {
        _idempotencyService
            .Setup(x => x.TryClaimAsync(20, _transactionGuid, _transitionGuid, 42, 23, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new TransactionToSageIdempotencyClaimResult
            {
                TransactionGuid = _transactionGuid,
                TransitionGuid = _transitionGuid,
                InProgressElsewhere = true,
                StatusCode = "InProgress"
            });

        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.Equal(TransactionToSageProcessStatus.FailedRetryable, result.Status);
        Assert.Equal("submission_already_in_progress", result.FailureCode);
        _gateway.Verify(x => x.CreateSalesOrderAsync(It.IsAny<Concursus.Common.Shared.Models.Finance.SageCreateSalesOrderRequest>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_SuccessMarksIdempotencyAndAppliesReference()
    {
        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.Equal(TransactionToSageProcessStatus.Succeeded, result.Status);
        Assert.True(result.IsSuccess);
        Assert.Equal("SO-100", result.SageOrderId);

        _idempotencyService.Verify(x => x.MarkSuccessAsync(
            _transactionGuid,
            _transitionGuid,
            "SO-100",
            "SO-100",
            "TR-100",
            "group",
            "Ok",
            It.IsAny<string?>(),
            "{\"request\":true}",
            It.Is<string>(json => json.Contains("SO-100", StringComparison.Ordinal)),
            42,
            It.IsAny<CancellationToken>()), Times.Once);

        _diagnosticsRepository.Verify(x => x.SetTransactionSageReferenceIfMissingAsync(
            20, "TR-100", It.IsAny<CancellationToken>()), Times.Once);
        _diagnosticsRepository.Verify(x => x.ApplyTransactionReferencesAsync(
            null, 20, false, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_MissingResponseReferenceUsesReadBack()
    {
        _gateway
            .Setup(x => x.CreateSalesOrderAsync(_request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(CreateGatewayResponse(transactionReference: string.Empty));
        _sageApiClient
            .Setup(x => x.FetchCustomerTransactionsAsync(
                SageDataset.group,
                "CUST001",
                "PO-100",
                4,
                true,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageFetchCustomerTransactionsResponse
            {
                Status = "Ok",
                Transactions =
                [
                    new Dictionary<string, object?>
                    {
                        ["secondReference"] = "PO-100",
                        ["transactionReference"] = "TR-READBACK"
                    }
                ]
            });

        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.True(result.IsSuccess);
        _idempotencyService.Verify(x => x.MarkSuccessAsync(
            _transactionGuid,
            _transitionGuid,
            "SO-100",
            "SO-100",
            "TR-READBACK",
            It.IsAny<string>(),
            It.IsAny<string>(),
            It.IsAny<string?>(),
            It.IsAny<string>(),
            It.IsAny<string>(),
            42,
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_MalformedSuccessIsNonRetryableAndRecorded()
    {
        _gateway
            .Setup(x => x.CreateSalesOrderAsync(_request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(CreateGatewayResponse(orderId: string.Empty));

        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.Equal(TransactionToSageProcessStatus.FailedNonRetryable, result.Status);
        Assert.Equal("sage_malformed_success_payload", result.FailureCode);
        _idempotencyService.Verify(x => x.MarkFailureAsync(
            _transactionGuid,
            _transitionGuid,
            It.Is<string>(message => message.Contains("did not provide an order identifier", StringComparison.Ordinal)),
            false,
            "Ok",
            It.IsAny<string?>(),
            It.IsAny<string>(),
            It.IsAny<string>(),
            42,
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Theory]
    [InlineData(400, false, "sage_validation_failed")]
    [InlineData(408, true, "sage_timeout")]
    [InlineData(409, false, "sage_conflict")]
    [InlineData(429, true, "sage_rate_limited")]
    [InlineData(500, true, "sage_server_error")]
    public async Task ProcessApprovedTransactionAsync_GatewayFailureIsClassifiedAndRecorded(
        int statusCode,
        bool expectedRetryable,
        string expectedCode)
    {
        _gateway
            .Setup(x => x.CreateSalesOrderAsync(_request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new CommonSageCreateSalesOrderResponse
            {
                Status = "Error",
                HttpStatusCode = statusCode,
                Detail = "Gateway rejected request."
            });

        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.Equal(expectedRetryable, result.IsRetryableFailure);
        Assert.Equal(expectedCode, result.FailureCode);
        Assert.Equal(
            expectedRetryable ? TransactionToSageProcessStatus.FailedRetryable : TransactionToSageProcessStatus.FailedNonRetryable,
            result.Status);

        _idempotencyService.Verify(x => x.MarkFailureAsync(
            _transactionGuid,
            _transitionGuid,
            "Gateway rejected request.",
            expectedRetryable,
            "Error",
            "Gateway rejected request.",
            It.IsAny<string>(),
            It.IsAny<string>(),
            42,
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_MappingValidationExceptionIsNonRetryableAndRecorded()
    {
        _payloadFactory.Setup(x => x.BuildJson(_transaction)).Throws(new InvalidOperationException("Missing nominal mapping."));

        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.Equal(TransactionToSageProcessStatus.FailedNonRetryable, result.Status);
        Assert.Equal("mapping_validation_failed", result.FailureCode);
        Assert.Equal("Missing nominal mapping.", result.Message);
        _idempotencyService.Verify(x => x.MarkFailureAsync(
            _transactionGuid,
            _transitionGuid,
            "Missing nominal mapping.",
            false,
            "Error",
            "Missing nominal mapping.",
            It.IsAny<string>(),
            It.IsAny<string>(),
            42,
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ProcessApprovedTransactionAsync_GatewayExceptionIsRetryableAndRecorded()
    {
        _gateway
            .Setup(x => x.CreateSalesOrderAsync(_request, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("Sage wrapper unavailable."));

        var result = await CreateService().ProcessApprovedTransactionAsync("{}");

        Assert.Equal(TransactionToSageProcessStatus.FailedRetryable, result.Status);
        Assert.Equal("submission_exception", result.FailureCode);
        Assert.Equal("Sage wrapper unavailable.", result.Message);
        _idempotencyService.Verify(x => x.MarkFailureAsync(
            _transactionGuid,
            _transitionGuid,
            "Sage wrapper unavailable.",
            true,
            "Error",
            "Sage wrapper unavailable.",
            It.IsAny<string>(),
            It.IsAny<string>(),
            42,
            It.IsAny<CancellationToken>()), Times.Once);
    }

    private TransactionToSageSubmissionService CreateService()
    {
        return new TransactionToSageSubmissionService(
            _readRepository.Object,
            _eligibilityValidator.Object,
            _idempotencyService.Object,
            _payloadFactory.Object,
            _gateway.Object,
            _sageApiClient.Object,
            _diagnosticsRepository.Object,
            _sageOptions.Object,
            _workerOptions.Object,
            Mock.Of<ILogger<TransactionToSageSubmissionService>>());
    }

    private static CommonSageCreateSalesOrderResponse CreateGatewayResponse(
        string orderId = "SO-100",
        string transactionReference = "TR-100")
    {
        return new CommonSageCreateSalesOrderResponse
        {
            Status = "Ok",
            HttpStatusCode = 200,
            OrderId = orderId,
            SageTransactionReference = transactionReference,
            Detail = "Created"
        };
    }
}
