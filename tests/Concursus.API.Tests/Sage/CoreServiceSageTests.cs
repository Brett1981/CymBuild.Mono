using Concursus.API.Core;
using Concursus.API.Sage.SOAP.Models;
using Concursus.Common.Shared.Models.Finance;
using Concursus.EF.Finance;
using Grpc.Core;
using Moq;
using Xunit;

namespace Concursus.API.Tests.Sage;

/// <summary>
/// Covers CoreService.Sage.cs - the only CoreService partial confirmed to use exclusively
/// constructor-injected interfaces (ISageApiClient, ITransactionSageSubmissionAdminService,
/// ISageInboundPaymentSyncService, ISageInboundDiagnosticsRepository), with no reference to
/// _serviceBase/_entityFramework or raw SQL. That makes it the only CoreService surface unit
/// testable today; the rest needs a real SQL Server-backed integration harness instead.
/// </summary>
public sealed class CoreServiceSageTests
{
    [Fact]
    public async Task SageInboundReceiptMaterialisationAutoCorrect_MapsRequestAndResultItems()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageInboundDiagnosticsRepository
            .Setup(repository => repository.AutoCorrectReceiptMaterialisationAsync(123L, 50, true, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageInboundReceiptMaterialisationAutoCorrectResult
            {
                ProcessedCount = 2,
                CorrectedCount = 1,
                SkippedCount = 1,
                FailedCount = 0,
                Items =
                {
                    new Concursus.Common.Shared.Models.Finance.SageInboundReceiptMaterialisationAutoCorrectResultItem
                    {
                        ExternalTransactionId = 123L,
                        Outcome = "Corrected",
                        MatchedTransactionId = 456L
                    }
                }
            });

        var request = new SageInboundReceiptMaterialisationAutoCorrectRequest
        {
            ExternalTransactionId = 123L,
            HasExternalTransactionId = true,
            BatchSize = 50,
            DryRun = true
        };

        var reply = await service.SageInboundReceiptMaterialisationAutoCorrect(
            request, TestServerCallContext.Create());

        Assert.Equal(2, reply.ProcessedCount);
        Assert.Equal(1, reply.CorrectedCount);
        var item = Assert.Single(reply.Items);
        Assert.Equal("Corrected", item.Outcome);
        Assert.Equal(456L, item.MatchedTransactionId);
    }

    [Fact]
    public async Task SageInboundReceiptMaterialisationAutoCorrect_DefaultsBatchSizeWhenNotPositive()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageInboundDiagnosticsRepository
            .Setup(repository => repository.AutoCorrectReceiptMaterialisationAsync(null, 100, false, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageInboundReceiptMaterialisationAutoCorrectResult());

        await service.SageInboundReceiptMaterialisationAutoCorrect(
            new SageInboundReceiptMaterialisationAutoCorrectRequest { BatchSize = 0 },
            TestServerCallContext.Create());

        mocks.SageInboundDiagnosticsRepository.Verify(
            repository => repository.AutoCorrectReceiptMaterialisationAsync(null, 100, false, It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task SageInboundPaymentSync_RejectsMissingDocumentGuid()
    {
        var (service, _) = CoreServiceTestFactory.Create();

        var exception = await Assert.ThrowsAsync<RpcException>(() =>
            service.SageInboundPaymentSync(
                new SageInboundPaymentSyncRequestMessage { CymBuildDocumentGuid = "" },
                TestServerCallContext.Create()));

        Assert.Equal(StatusCode.InvalidArgument, exception.StatusCode);
    }

    [Fact]
    public async Task SageInboundPaymentSync_RejectsUnparsableDocumentGuid()
    {
        var (service, _) = CoreServiceTestFactory.Create();

        var exception = await Assert.ThrowsAsync<RpcException>(() =>
            service.SageInboundPaymentSync(
                new SageInboundPaymentSyncRequestMessage { CymBuildDocumentGuid = "not-a-guid" },
                TestServerCallContext.Create()));

        Assert.Equal(StatusCode.InvalidArgument, exception.StatusCode);
    }

    [Fact]
    public async Task SageInboundPaymentSync_MapsSuccessfulResultAndItems()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        var documentGuid = Guid.NewGuid();
        mocks.SageInboundPaymentSyncService
            .Setup(sync => sync.SyncAsync(documentGuid, true, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageInboundPaymentSyncResult
            {
                CymBuildDocumentGuid = documentGuid,
                IsSuccess = true,
                ExternalTransactionCount = 3,
                Items = { new SageInboundPaymentSyncResultItem { ExternalTransactionId = 999L, SageDocumentNo = "SI-1" } }
            });

        var reply = await service.SageInboundPaymentSync(
            new SageInboundPaymentSyncRequestMessage { CymBuildDocumentGuid = documentGuid.ToString(), Force = true },
            TestServerCallContext.Create());

        Assert.True(reply.IsSuccess);
        Assert.Equal(3, reply.ExternalTransactionCount);
        var item = Assert.Single(reply.Items);
        Assert.Equal(999L, item.ExternalTransactionId);
        Assert.Equal("SI-1", item.SageDocumentNo);
    }

    [Fact]
    public async Task SageInboundPaymentSyncEnqueue_RejectsMissingDocumentGuid()
    {
        var (service, _) = CoreServiceTestFactory.Create();

        var exception = await Assert.ThrowsAsync<RpcException>(() =>
            service.SageInboundPaymentSyncEnqueue(
                new SageInboundPaymentSyncEnqueueRequestMessage { CymBuildDocumentGuid = "" },
                TestServerCallContext.Create()));

        Assert.Equal(StatusCode.InvalidArgument, exception.StatusCode);
    }

    [Fact]
    public async Task SageInboundPaymentSyncEnqueue_MapsResult()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        var documentGuid = Guid.NewGuid();
        mocks.SageInboundPaymentSyncService
            .Setup(sync => sync.EnqueueAsync(documentGuid, true, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageInboundPaymentSyncEnqueueResult
            {
                CymBuildDocumentGuid = documentGuid,
                IsSuccess = true,
                Message = "Enqueued."
            });

        var reply = await service.SageInboundPaymentSyncEnqueue(
            new SageInboundPaymentSyncEnqueueRequestMessage { CymBuildDocumentGuid = documentGuid.ToString(), ForceRequeue = true },
            TestServerCallContext.Create());

        Assert.True(reply.IsSuccess);
        Assert.Equal("Enqueued.", reply.Message);
    }

    [Fact]
    public async Task SageInboundDiagnosticsGet_MapsRequestModelAndRows()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        var rowGuid = Guid.NewGuid();
        var documentGuid = Guid.NewGuid();

        mocks.SageInboundDiagnosticsRepository
            .Setup(repository => repository.GetAsync(
                It.Is<SageInboundDiagnosticsGetRequestModel>(model =>
                    model.StatusCode == "Failed" &&
                    model.TransactionId == 42L &&
                    model.PageNumber == 2 &&
                    model.PageSize == 25 &&
                    model.PaymentFilter == "Paid"),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageInboundDiagnosticsPageResult
            {
                TotalCount = 51,
                Rows =
                {
                    new()
                    {
                        Id = 1,
                        Guid = rowGuid,
                        CymBuildDocumentGuid = documentGuid,
                        StatusCode = "Failed",
                        CanRequeue = true
                    }
                }
            });

        var request = new SageInboundDiagnosticsGetRequest
        {
            StatusCode = "Failed",
            TransactionId = 42L,
            TransactionIdSpecified = true,
            PageNumber = 2,
            PageSize = 25,
            PaymentFilter = "Paid"
        };

        var reply = await service.SageInboundDiagnosticsGet(request, TestServerCallContext.Create());

        var row = Assert.Single(reply.Rows);
        Assert.Equal(rowGuid.ToString(), row.Guid);
        Assert.Equal(documentGuid.ToString(), row.CymBuildDocumentGuid);
        Assert.Equal("Failed", row.StatusCode);
        Assert.True(row.CanRequeue);
        Assert.Equal(51, reply.TotalCount);
    }

    [Fact]
    public async Task SageInboundDiagnosticsSummaryGet_MapsRequestModelAndCounts()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();

        mocks.SageInboundDiagnosticsRepository
            .Setup(repository => repository.GetSummaryAsync(
                It.Is<SageInboundDiagnosticsSummaryRequestModel>(model =>
                    model.SageAccountReference == "ACC-1" &&
                    model.JobId == 7),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SageInboundDiagnosticsSummaryModel
            {
                TotalCount = 10,
                SucceededCount = 4,
                RetryPendingCount = 2,
                PaidCount = 3,
                ReceiptsCreatedCount = 1,
                CreditNotesCreatedCount = 2
            });

        var request = new SageInboundDiagnosticsSummaryGetRequest
        {
            SageAccountReference = "ACC-1",
            JobId = 7,
            JobIdSpecified = true
        };

        var reply = await service.SageInboundDiagnosticsSummaryGet(request, TestServerCallContext.Create());

        Assert.Equal(10, reply.TotalCount);
        Assert.Equal(4, reply.SucceededCount);
        Assert.Equal(2, reply.RetryPendingCount);
        Assert.Equal(3, reply.PaidCount);
        Assert.Equal(1, reply.ReceiptsCreatedCount);
        Assert.Equal(2, reply.CreditNotesCreatedCount);
    }

    [Fact]
    public async Task SageHealthGet_ReportsHealthyWhenRawResponseContainsHealthy()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageApiClient
            .Setup(client => client.GetHealthAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync("Status: healthy");

        var response = await service.SageHealthGet(new SageHealthGetRequest(), TestServerCallContext.Create());

        Assert.Equal("ok", response.Status);
        Assert.True(response.IsHealthy);
    }

    [Fact]
    public async Task SageHealthGet_ReportsErrorStatusWhenClientThrows()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageApiClient
            .Setup(client => client.GetHealthAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("Sage wrapper unreachable."));

        var response = await service.SageHealthGet(new SageHealthGetRequest(), TestServerCallContext.Create());

        Assert.Equal("error", response.Status);
        Assert.False(response.IsHealthy);
        Assert.Equal("Sage wrapper unreachable.", response.ErrorReturned);
    }

    [Fact]
    public async Task TransactionSageSubmissionRequeue_RejectsEmptyGuidList()
    {
        var (service, _) = CoreServiceTestFactory.Create();

        var exception = await Assert.ThrowsAsync<RpcException>(() =>
            service.TransactionSageSubmissionRequeue(
                new TransactionSageSubmissionRequeueRequest(), TestServerCallContext.Create()));

        Assert.Equal(StatusCode.InvalidArgument, exception.StatusCode);
    }

    [Fact]
    public async Task TransactionSageSubmissionRequeue_RejectsInvalidGuid()
    {
        var (service, _) = CoreServiceTestFactory.Create();
        var request = new TransactionSageSubmissionRequeueRequest { TransactionGuids = { "not-a-guid" } };

        var exception = await Assert.ThrowsAsync<RpcException>(() =>
            service.TransactionSageSubmissionRequeue(request, TestServerCallContext.Create()));

        Assert.Equal(StatusCode.InvalidArgument, exception.StatusCode);
    }

    [Fact]
    public async Task TransactionSageSubmissionRequeue_DeduplicatesGuidsAndMapsResult()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        var transactionGuid = Guid.NewGuid();
        mocks.TransactionSageSubmissionAdminService
            .Setup(admin => admin.RequeueAsync(
                It.Is<IReadOnlyCollection<Guid>>(guids => guids.Count == 1 && guids.Contains(transactionGuid)),
                true,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new TransactionSageSubmissionRequeueResult
            {
                RequeuedTransactionCount = 1,
                Items = { new Concursus.Common.Shared.Models.Finance.TransactionSageSubmissionRequeueResultItem { TransactionId = 7L, TransactionGuid = transactionGuid } }
            });

        var request = new TransactionSageSubmissionRequeueRequest
        {
            TransactionGuids = { transactionGuid.ToString(), transactionGuid.ToString() },
            IncludeNonRetryableFailures = true
        };

        var reply = await service.TransactionSageSubmissionRequeue(request, TestServerCallContext.Create());

        Assert.Equal(1, reply.RequeuedTransactionCount);
        var item = Assert.Single(reply.Items);
        Assert.Equal(transactionGuid.ToString(), item.TransactionGuid);
    }

    [Fact]
    public async Task SageFetchSalesOrders_MapsSalesOrdersFromRawDictionaries()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageApiClient
            .Setup(client => client.FetchSalesOrdersAsync(SageDataset.group, "SO-1", null, false, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Concursus.API.Sage.SOAP.Models.SageFetchSalesOrdersResponse
            {
                Status = "Ok",
                SalesOrders =
                {
                    new Dictionary<string, object?>
                    {
                        ["accountReference"] = "ACC1",
                        ["documentNo"] = "SO-1",
                        ["customerOrderNo"] = "PO-1"
                    }
                }
            });

        var request = new SageFetchSalesOrdersRequest { Dataset = "group", OrderId = "SO-1" };

        var response = await service.SageFetchSalesOrders(request, TestServerCallContext.Create());

        Assert.Equal("Ok", response.Status);
        var order = Assert.Single(response.SalesOrders);
        Assert.Equal("ACC1", order.AccountReference);
        Assert.Equal("SO-1", order.DocumentNo);
        Assert.Equal("PO-1", order.CustomerOrderNo);
    }

    [Fact]
    public async Task SageFetchSalesOrders_ReturnsErrorReturnedWhenClientThrows()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageApiClient
            .Setup(client => client.FetchSalesOrdersAsync(SageDataset.group, It.IsAny<string>(), null, false, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("Sage timeout."));

        var response = await service.SageFetchSalesOrders(
            new SageFetchSalesOrdersRequest { Dataset = "group" }, TestServerCallContext.Create());

        Assert.Equal("Sage timeout.", response.ErrorReturned);
    }

    [Fact]
    public async Task SageFetchCustomerTransactions_MapsTransactionsFromRawDictionaries()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageApiClient
            .Setup(client => client.FetchCustomerTransactionsAsync(SageDataset.asbestos, "ACC1", null, null, false, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Concursus.API.Sage.SOAP.Models.SageFetchCustomerTransactionsResponse
            {
                Status = "Ok",
                Transactions =
                {
                    new Dictionary<string, object?>
                    {
                        ["transactionReference"] = "TR-1",
                        ["accountReference"] = "ACC1",
                        ["grossAmount"] = 120.5,
                        ["sysTraderTranType"] = 1
                    }
                }
            });

        var request = new SageFetchCustomerTransactionsRequest { Dataset = "asbestos", AccountReference = "ACC1" };

        var response = await service.SageFetchCustomerTransactions(request, TestServerCallContext.Create());

        Assert.Equal("Ok", response.Status);
        var transaction = Assert.Single(response.Transactions);
        Assert.Equal("TR-1", transaction.TransactionReference);
        Assert.Equal(120.5, transaction.GrossAmount);
        Assert.Equal(1, transaction.SysTraderTranType);
    }

    [Fact]
    public async Task SageFetchSalesAllocations_MapsSessionsAndCounterparts()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageApiClient
            .Setup(client => client.FetchSalesAllocationsAsync(SageDataset.group, "00030607", "9000027", It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Concursus.API.Sage.SOAP.Models.SageFetchSalesAllocationsResponse
            {
                Status = "Ok",
                AccountReference = "00030607",
                Urn = "9000027",
                Sessions =
                {
                    new Concursus.API.Sage.SOAP.Models.SageSalesAllocationSession
                    {
                        AllocationHeaderId = "200000001",
                        SessionDate = "2026-10-19",
                        Rows =
                        {
                            new Concursus.API.Sage.SOAP.Models.SageSalesAllocationRow { Urn = "9000027", AllocationValue = 900m, IsRequested = true },
                            new Concursus.API.Sage.SOAP.Models.SageSalesAllocationRow
                            {
                                Urn = "9000028",
                                AllocationValue = -900m,
                                TypeResolved = true,
                                SysTraderTranType = 5,
                                TransactionReference = "SC-00028",
                                GrossAmount = -900m,
                                TaxAmount = -150m,
                                NetAmount = -750m
                            },
                            new Concursus.API.Sage.SOAP.Models.SageSalesAllocationRow { Urn = "9000029", AllocationValue = -10m }
                        }
                    }
                }
            });

        var request = new SageFetchSalesAllocationsRequest { Dataset = "group", AccountReference = "00030607", Urn = "9000027" };

        var response = await service.SageFetchSalesAllocations(request, TestServerCallContext.Create());

        Assert.Equal("Ok", response.Status);
        Assert.True(string.IsNullOrEmpty(response.ErrorReturned));
        var session = Assert.Single(response.Sessions);
        Assert.Equal("200000001", session.AllocationHeaderId);
        Assert.Equal(3, session.Rows.Count);
        Assert.True(session.Rows[0].IsRequested);
        Assert.Equal(5, session.Rows[1].SysTraderTranType);
        Assert.Equal("SC-00028", session.Rows[1].TransactionReference);
        Assert.Equal(-150, session.Rows[1].TaxAmount);
        Assert.False(session.Rows[2].TypeResolved);
        Assert.Null(session.Rows[2].SysTraderTranType);
        Assert.Null(session.Rows[2].GrossAmount);
    }

    [Fact]
    public async Task SageFetchSalesAllocations_ReturnsErrorInsteadOfThrowing()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageApiClient
            .Setup(client => client.FetchSalesAllocationsAsync(It.IsAny<SageDataset>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("404 Not Found"));

        var response = await service.SageFetchSalesAllocations(
            new SageFetchSalesAllocationsRequest { Dataset = "group", AccountReference = "ACC1", Urn = "1" },
            TestServerCallContext.Create());

        Assert.Equal("404 Not Found", response.ErrorReturned);
        Assert.Empty(response.Sessions);
    }

    [Fact]
    public async Task SageCreateSalesOrder_MapsSuccessAndTransactionReferenceFromResponse()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageApiClient
            .Setup(client => client.CreateSalesOrderAsync(
                It.Is<Concursus.API.Sage.SOAP.Models.SageCreateSalesOrderRequest>(r => r.AccountReference == "ACC1"),
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Concursus.API.Sage.SOAP.Models.SageCreateSalesOrderResponse
            {
                Status = "Ok",
                OrderId = "SO-99",
                SageTransactionReference = "TR-99"
            });

        var request = new Core.SageCreateSalesOrderRequest
        {
            Dataset = "group",
            AccountReference = "ACC1"
        };

        var response = await service.SageCreateSalesOrder(request, TestServerCallContext.Create());

        Assert.True(response.Success);
        Assert.Equal("SO-99", response.OrderId);
        Assert.Equal("TR-99", response.SageTransactionReference);
        mocks.SageInboundDiagnosticsRepository.Verify(
            repository => repository.SetTransactionSageReferenceIfMissingAsync(
                It.IsAny<long>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task SageCreateSalesOrder_LooksUpMissingTransactionReferenceAndPersistsIt()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageApiClient
            .Setup(client => client.CreateSalesOrderAsync(It.IsAny<Concursus.API.Sage.SOAP.Models.SageCreateSalesOrderRequest>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Concursus.API.Sage.SOAP.Models.SageCreateSalesOrderResponse { Status = "Ok", OrderId = "SO-1" });
        mocks.SageApiClient
            .Setup(client => client.FetchCustomerTransactionsAsync(
                SageDataset.group, "ACC1", "PO-1", 4, true, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Concursus.API.Sage.SOAP.Models.SageFetchCustomerTransactionsResponse
            {
                Transactions = { new Dictionary<string, object?> { ["transactionReference"] = "TR-LOOKED-UP" } }
            });
        mocks.SageInboundDiagnosticsRepository
            .Setup(repository => repository.SetTransactionSageReferenceIfMissingAsync(
                55L, "TR-LOOKED-UP", It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var request = new Core.SageCreateSalesOrderRequest
        {
            Dataset = "group",
            AccountReference = "ACC1",
            CustomerOrderNo = "PO-1",
            TransactionId = 55L,
            HasTransactionId = true
        };

        var response = await service.SageCreateSalesOrder(request, TestServerCallContext.Create());

        Assert.Equal("TR-LOOKED-UP", response.SageTransactionReference);
        mocks.SageInboundDiagnosticsRepository.Verify(
            repository => repository.SetTransactionSageReferenceIfMissingAsync(
                55L, "TR-LOOKED-UP", It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task SageCreateSalesOrder_ReturnsFailureWhenClientThrows()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageApiClient
            .Setup(client => client.CreateSalesOrderAsync(It.IsAny<Concursus.API.Sage.SOAP.Models.SageCreateSalesOrderRequest>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("Sage create failed."));

        var response = await service.SageCreateSalesOrder(
            new Core.SageCreateSalesOrderRequest { Dataset = "group" }, TestServerCallContext.Create());

        Assert.False(response.Success);
        Assert.Equal("Sage create failed.", response.ErrorReturned);
    }

    [Fact]
    public async Task SageInboundDiagnosticsApplyTransactionReferences_RejectsInvalidStatusGuid()
    {
        var (service, _) = CoreServiceTestFactory.Create();

        var exception = await Assert.ThrowsAsync<RpcException>(() =>
            service.SageInboundDiagnosticsApplyTransactionReferences(
                new SageInboundDiagnosticsApplyTransactionReferencesRequest { StatusGuid = "not-a-guid" },
                TestServerCallContext.Create()));

        Assert.Equal(StatusCode.InvalidArgument, exception.StatusCode);
    }

    [Fact]
    public async Task SageInboundDiagnosticsApplyTransactionReferences_RejectsNonPositiveTransactionId()
    {
        var (service, _) = CoreServiceTestFactory.Create();
        var request = new SageInboundDiagnosticsApplyTransactionReferencesRequest
        {
            TransactionId = 0,
            HasTransactionId = true
        };

        var exception = await Assert.ThrowsAsync<RpcException>(() =>
            service.SageInboundDiagnosticsApplyTransactionReferences(request, TestServerCallContext.Create()));

        Assert.Equal(StatusCode.InvalidArgument, exception.StatusCode);
    }

    [Fact]
    public async Task SageInboundDiagnosticsApplyTransactionReferences_ReturnsAppliedCountOnSuccess()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageInboundDiagnosticsRepository
            .Setup(repository => repository.ApplyTransactionReferencesAsync(null, null, true, It.IsAny<CancellationToken>()))
            .ReturnsAsync(3);

        var reply = await service.SageInboundDiagnosticsApplyTransactionReferences(
            new SageInboundDiagnosticsApplyTransactionReferencesRequest { DryRun = true },
            TestServerCallContext.Create());

        Assert.True(reply.Success);
        Assert.Equal(3, reply.AppliedCount);
        Assert.Contains("would be applied", reply.Message);
    }

    [Fact]
    public async Task SageInboundDiagnosticsApplyTransactionReferences_ReturnsFailureWhenRepositoryThrows()
    {
        var (service, mocks) = CoreServiceTestFactory.Create();
        mocks.SageInboundDiagnosticsRepository
            .Setup(repository => repository.ApplyTransactionReferencesAsync(null, null, false, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("DB unavailable."));

        var reply = await service.SageInboundDiagnosticsApplyTransactionReferences(
            new SageInboundDiagnosticsApplyTransactionReferencesRequest(), TestServerCallContext.Create());

        Assert.False(reply.Success);
        Assert.Equal("DB unavailable.", reply.ErrorReturned);
    }
}
