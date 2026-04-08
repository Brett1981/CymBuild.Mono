using Concursus.API.Core;
using Concursus.API.Sage.SOAP.Client;
using Concursus.API.Sage.SOAP.Interface;
using Concursus.API.Sage.SOAP.Models;
using Concursus.Common.Shared.Models.Finance;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;
using System.Globalization;
using System.Text.Json;

namespace Concursus.API.Services;

[Authorize]
public partial class CoreService
{
    private static readonly JsonSerializerOptions SageJsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true
    };

    public override async Task<SageInboundPaymentSyncReply> SageInboundPaymentSync(
    SageInboundPaymentSyncRequestMessage request,
    ServerCallContext context)
    {
        if (request is null || string.IsNullOrWhiteSpace(request.CymBuildDocumentGuid))
        {
            throw new RpcException(
                new Status(StatusCode.InvalidArgument, "A CymBuild document guid must be supplied."));
        }

        if (!Guid.TryParse(request.CymBuildDocumentGuid, out var cymBuildDocumentGuid))
        {
            throw new RpcException(
                new Status(StatusCode.InvalidArgument, $"Invalid CymBuild document guid: {request.CymBuildDocumentGuid}"));
        }

        var result = await _sageInboundPaymentSyncService.SyncAsync(
            cymBuildDocumentGuid,
            request.Force,
            context.CancellationToken);

        var reply = new SageInboundPaymentSyncReply
        {
            CymBuildDocumentGuid = result.CymBuildDocumentGuid.ToString(),
            IsSuccess = result.IsSuccess,
            IsRetryableFailure = result.IsRetryableFailure,
            Message = result.Message ?? string.Empty,
            ExternalTransactionCount = result.ExternalTransactionCount,
            ExternalAllocationCount = result.ExternalAllocationCount,
            ReconciledInvoiceCount = result.ReconciledInvoiceCount,
            ReconciledAllocationCount = result.ReconciledAllocationCount,
            UpdatedInvoiceRequestCount = result.UpdatedInvoiceRequestCount
        };

        foreach (var item in result.Items)
        {
            reply.Items.Add(new SageInboundPaymentSyncResultItemMessage
            {
                ExternalTransactionId = item.ExternalTransactionId,
                MatchedTransactionId = item.MatchedTransactionId,
                MatchedInvoiceRequestId = item.MatchedInvoiceRequestId,
                MatchedJobId = item.MatchedJobId,
                MatchRule = item.MatchRule ?? string.Empty
            });
        }

        return reply;
    }

    public override async Task<SageInboundPaymentSyncEnqueueReply> SageInboundPaymentSyncEnqueue(
    SageInboundPaymentSyncEnqueueRequestMessage request,
    ServerCallContext context)
    {
        if (request is null || string.IsNullOrWhiteSpace(request.CymBuildDocumentGuid))
        {
            throw new RpcException(
                new Status(StatusCode.InvalidArgument, "A CymBuild document guid must be supplied."));
        }

        if (!Guid.TryParse(request.CymBuildDocumentGuid, out var cymBuildDocumentGuid))
        {
            throw new RpcException(
                new Status(StatusCode.InvalidArgument, $"Invalid CymBuild document guid: {request.CymBuildDocumentGuid}"));
        }

        var result = await _sageInboundPaymentSyncService.EnqueueAsync(
            cymBuildDocumentGuid,
            request.ForceRequeue,
            context.CancellationToken);

        return new SageInboundPaymentSyncEnqueueReply
        {
            CymBuildDocumentGuid = result.CymBuildDocumentGuid.ToString(),
            IsSuccess = result.IsSuccess,
            Message = result.Message ?? string.Empty
        };
    }

    public override async Task<SageInboundDiagnosticsGetReply> SageInboundDiagnosticsGet(
            SageInboundDiagnosticsGetRequest request,
            ServerCallContext context)
    {
        if (request == null)
        {
            throw new RpcException(new Status(StatusCode.InvalidArgument, "Request cannot be null."));
        }

        var model = new SageInboundDiagnosticsGetRequestModel
        {
            StatusCode = request.StatusCode ?? string.Empty,
            SageAccountReference = request.SageAccountReference ?? string.Empty,
            SageDocumentNo = request.SageDocumentNo ?? string.Empty,
            OnlyRetryableFailures = request.IncludeOnlyRetryableFailuresSpecified ? request.IncludeOnlyRetryableFailures : null,
            InvoiceRequestId = request.InvoiceRequestIdSpecified ? request.InvoiceRequestId : null,
            TransactionId = request.TransactionIdSpecified ? request.TransactionId : null,
            JobId = request.JobIdSpecified ? request.JobId : null
        };

        try
        {
            var rows = await _sageInboundDiagnosticsRepository
                .GetAsync(_serviceBase._entityFramework, model, context.CancellationToken)
                .ConfigureAwait(false);

            var reply = new SageInboundDiagnosticsGetReply();
            foreach (var row in rows)
            {
                reply.Rows.Add(new SageInboundDiagnosticsRow
                {
                    Id = row.Id,
                    Guid = row.Guid.ToString(),
                    CymBuildEntityTypeId = row.CymBuildEntityTypeId,
                    CymBuildDocumentGuid = row.CymBuildDocumentGuid.ToString(),
                    CymBuildDocumentId = row.CymBuildDocumentId,
                    InvoiceRequestId = row.InvoiceRequestId,
                    TransactionId = row.TransactionId,
                    JobId = row.JobId,
                    SageDataset = row.SageDataset ?? string.Empty,
                    SageAccountReference = row.SageAccountReference ?? string.Empty,
                    SageDocumentNo = row.SageDocumentNo ?? string.Empty,
                    LastOperationName = row.LastOperationName ?? string.Empty,
                    StatusCode = row.StatusCode ?? string.Empty,
                    IsInProgress = row.IsInProgress,
                    InProgressClaimedOnUtc = ToTimestamp(row.InProgressClaimedOnUtc),
                    LastSucceededOnUtc = ToTimestamp(row.LastSucceededOnUtc),
                    LastFailedOnUtc = ToTimestamp(row.LastFailedOnUtc),
                    LastError = row.LastError ?? string.Empty,
                    LastErrorIsRetryable = row.LastErrorIsRetryable ?? false,
                    LastErrorIsRetryableSpecified = row.LastErrorIsRetryable.HasValue,
                    LastSourceWatermarkUtc = ToTimestamp(row.LastSourceWatermarkUtc),
                    UpdatedDateTimeUtc = ToTimestamp(row.UpdatedDateTimeUtc),
                    LastAttemptedOnUtc = ToTimestamp(row.LastAttemptedOnUtc),
                    LastCompletedOnUtc = ToTimestamp(row.LastCompletedOnUtc),
                    LastAttemptIsSuccess = row.LastAttemptIsSuccess ?? false,
                    LastAttemptIsSuccessSpecified = row.LastAttemptIsSuccess.HasValue,
                    LastAttemptErrorMessage = row.LastAttemptErrorMessage ?? string.Empty,
                    LastAttemptIsRetryableFailure = row.LastAttemptIsRetryableFailure ?? false,
                    LastAttemptIsRetryableFailureSpecified = row.LastAttemptIsRetryableFailure.HasValue,
                    LastAttemptResponseStatus = row.LastAttemptResponseStatus ?? string.Empty,
                    LastAttemptResponseDetail = row.LastAttemptResponseDetail ?? string.Empty,
                    CanRequeue = row.CanRequeue,
                    CanForceRequeue = row.CanForceRequeue
                });
            }

            return reply;
        }
        catch (RpcException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw new RpcException(new Status(StatusCode.Internal, $"SageInboundDiagnosticsGet failed. {ex.Message}"));
        }
    }
    public override async Task<SageHealthGetResponse> SageHealthGet(
    SageHealthGetRequest request,
    ServerCallContext context)
    {
        var response = new SageHealthGetResponse();

        try
        {
            var raw = await _sageApiClient.GetHealthAsync(context.CancellationToken);

            response.RawResponse = raw ?? string.Empty;

            if (!string.IsNullOrWhiteSpace(raw) &&
                raw.Contains("disabled", StringComparison.OrdinalIgnoreCase))
            {
                response.Status = "disabled";
                response.IsHealthy = false;
                response.Detail = raw;
                return response;
            }

            response.Status = "ok";
            response.IsHealthy = !string.IsNullOrWhiteSpace(raw) &&
                                 raw.Contains("healthy", StringComparison.OrdinalIgnoreCase);

            if (!string.IsNullOrWhiteSpace(raw))
            {
                response.Detail = raw;
            }
        }
        catch (Exception ex)
        {
            response.ErrorReturned = ex.Message;
            response.Status = "error";
            response.IsHealthy = false;
        }

        return response;
    }

    public override async Task<TransactionSageSubmissionRequeueReply> TransactionSageSubmissionRequeue(
            TransactionSageSubmissionRequeueRequest request,
            ServerCallContext context)
    {
        if (request is null || request.TransactionGuids.Count == 0)
        {
            throw new RpcException(
                new Status(StatusCode.InvalidArgument, "At least one transaction guid must be supplied."));
        }

        var parsedGuids = new List<Guid>();

        foreach (var value in request.TransactionGuids)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                continue;
            }

            if (!Guid.TryParse(value, out var parsedGuid))
            {
                throw new RpcException(
                    new Status(StatusCode.InvalidArgument, $"Invalid transaction guid: {value}"));
            }

            if (!parsedGuids.Contains(parsedGuid))
            {
                parsedGuids.Add(parsedGuid);
            }
        }

        if (parsedGuids.Count == 0)
        {
            throw new RpcException(
                new Status(StatusCode.InvalidArgument, "No valid transaction guids were supplied."));
        }

        var result = await _transactionSageSubmissionAdminService.RequeueAsync(
            parsedGuids,
            context.CancellationToken);

        var reply = new TransactionSageSubmissionRequeueReply
        {
            RequeuedTransactionCount = result.RequeuedTransactionCount,
            ResetOutboxRowCount = result.ResetOutboxRowCount,
            ResetStatusRowCount = result.ResetStatusRowCount,
            Message = result.Message ?? string.Empty
        };

        foreach (var item in result.Items)
        {
            reply.Items.Add(new Core.TransactionSageSubmissionRequeueResultItem
            {
                TransactionId = item.TransactionId,
                TransactionGuid = item.TransactionGuid.ToString(),
                ResetStatusRow = item.ResetStatusRow,
                ResetOutboxRows = item.ResetOutboxRows
            });
        }

        return reply;
    }

    public override async Task<Core.SageFetchSalesOrdersResponse> SageFetchSalesOrders(
        SageFetchSalesOrdersRequest request,
        ServerCallContext context)
    {
        var response = new Core.SageFetchSalesOrdersResponse();

        try
        {
            var result = await _sageApiClient.FetchSalesOrdersAsync(
                System.Enum.Parse<SageDataset>(request.Dataset, true),
                request.OrderId ?? string.Empty,
                string.IsNullOrWhiteSpace(request.FilterOperator) ? null : request.FilterOperator,
                request.Force,
                context.CancellationToken);

            response.Status = result?.Status ?? string.Empty;
            response.Detail = result?.Detail ?? string.Empty;
            response.RawJson = JsonSerializer.Serialize(result, SageJsonOptions); // legacy/debug

            if (result?.SalesOrders != null)
            {
                response.SalesOrders.AddRange(
                    result.SalesOrders.Select(MapSalesOrder));
            }
        }
        catch (Exception ex)
        {
            response.ErrorReturned = ex.Message;
        }

        return response;
    }

    public override async Task<Core.SageFetchCustomerTransactionsResponse> SageFetchCustomerTransactions(
        SageFetchCustomerTransactionsRequest request,
        ServerCallContext context)
    {
        var response = new Core.SageFetchCustomerTransactionsResponse();

        try
        {
            var result = await _sageApiClient.FetchCustomerTransactionsAsync(
                System.Enum.Parse<SageDataset>(request.Dataset, true),
                string.IsNullOrWhiteSpace(request.AccountReference) ? null : request.AccountReference,
                string.IsNullOrWhiteSpace(request.DocumentNo) ? null : request.DocumentNo,
                request.HasSysTraderTranType ? request.SysTraderTranType : null,
                request.Force,
                context.CancellationToken);

            response.Status = result?.Status ?? string.Empty;
            response.Detail = result?.Detail ?? string.Empty;
            response.RawJson = JsonSerializer.Serialize(result, SageJsonOptions); // legacy/debug

            if (result?.Transactions != null)
            {
                response.Transactions.AddRange(
                    result.Transactions.Select(MapCustomerTransaction));
            }
        }
        catch (Exception ex)
        {
            response.ErrorReturned = ex.Message;
        }

        return response;
    }

    public override async Task<Core.SageCreateSalesOrderResponse> SageCreateSalesOrder(
        Core.SageCreateSalesOrderRequest request,
        ServerCallContext context)
    {
        var response = new Core.SageCreateSalesOrderResponse();

        try
        {
            var apiRequest = new Concursus.API.Sage.SOAP.Models.SageCreateSalesOrderRequest
            {
                Dataset = System.Enum.Parse<SageDataset>(request.Dataset, true),
                AccountReference = request.AccountReference ?? string.Empty,
                CustomerOrderNo = NullIfEmpty(request.CustomerOrderNo),
                DocumentDate = NullIfEmpty(request.DocumentDate),
                UseInvoiceAddress = request.HasUseInvoiceAddress ? request.UseInvoiceAddress : null,
                OverrideOnHold = request.HasOverrideOnHold ? request.OverrideOnHold : null,
                AllowCreditLimitException = request.HasAllowCreditLimitException ? request.AllowCreditLimitException : null,
                AnalysisCode01Value = NullIfEmpty(request.AnalysisCode01Value),
                AnalysisCode02Value = NullIfEmpty(request.AnalysisCode02Value),
                AnalysisCode03Value = NullIfEmpty(request.AnalysisCode03Value),
                Lines = request.Lines.Select(x => new SageSalesOrderLine
                {
                    ItemDescription = x.ItemDescription ?? string.Empty,
                    NominalRef = x.NominalRef ?? string.Empty,
                    Quantity = x.Quantity,
                    UnitPrice = Convert.ToDecimal(x.UnitPrice),
                    LineType = NullIfEmpty(x.LineType),
                    NominalCC = NullIfEmpty(x.NominalCc),
                    NominalDept = NullIfEmpty(x.NominalDept),
                    TaxCode = x.HasTaxCode ? x.TaxCode : null
                }).ToList()
            };

            var result = await _sageApiClient.CreateSalesOrderAsync(apiRequest, context.CancellationToken);

            response.Status = result?.Status ?? string.Empty;
            response.OrderId = result?.OrderId ?? string.Empty;
            response.Detail = result?.Detail ?? string.Empty;
            response.RawJson = JsonSerializer.Serialize(result, SageJsonOptions); // legacy/debug
            response.Success = string.Equals(result?.Status, "Ok", StringComparison.OrdinalIgnoreCase);
        }
        catch (Exception ex)
        {
            response.ErrorReturned = ex.Message;
            response.Success = false;
        }

        return response;
    }

    private static Core.SageSalesOrder MapSalesOrder(IDictionary<string, object?> source)
    {
        var mapped = new Core.SageSalesOrder
        {
            AccountReference = GetString(source, "accountReference"),
            DocumentNo = GetString(source, "documentNo"),
            AdditionalFields = BuildStruct(
                source,
                "accountReference",
                "documentNo",
                "customerOrderNo",
                "documentDate")
        };

        var customerOrderNo = GetStringOrNull(source, "customerOrderNo");
        if (!string.IsNullOrWhiteSpace(customerOrderNo))
        {
            mapped.CustomerOrderNo = customerOrderNo;
        }

        var documentDate = GetStringOrNull(source, "documentDate");
        if (!string.IsNullOrWhiteSpace(documentDate))
        {
            mapped.DocumentDate = documentDate;
        }

        return mapped;
    }

    private static Core.SageCustomerTransaction MapCustomerTransaction(IDictionary<string, object?> source)
    {
        var mapped = new Core.SageCustomerTransaction
        {
            AdditionalFields = BuildStruct(
                source,
                "transactionReference",
                "accountReference",
                "secondReference",
                "sysTraderTranType",
                "transactionDate",
                "netAmount",
                "taxAmount",
                "grossAmount",
                "outstandingAmount")
        };

        SetString(source, "transactionReference", v => mapped.TransactionReference = v);
        SetString(source, "accountReference", v => mapped.AccountReference = v);
        SetString(source, "secondReference", v => mapped.SecondReference = v);
        SetString(source, "transactionDate", v => mapped.TransactionDate = v);

        SetInt(source, "sysTraderTranType", v => mapped.SysTraderTranType = v);

        SetDouble(source, "netAmount", v => mapped.NetAmount = v);
        SetDouble(source, "taxAmount", v => mapped.TaxAmount = v);
        SetDouble(source, "grossAmount", v => mapped.GrossAmount = v);
        SetDouble(source, "outstandingAmount", v => mapped.OutstandingAmount = v);

        return mapped;
    }

    private static Struct BuildStruct(IDictionary<string, object?> source, params string[] excludedKeys)
    {
        var excluded = new HashSet<string>(excludedKeys, StringComparer.OrdinalIgnoreCase);
        var result = new Struct();

        foreach (var kvp in source)
        {
            if (excluded.Contains(kvp.Key))
                continue;

            result.Fields[kvp.Key] = ToProtoValue(kvp.Value);
        }

        return result;
    }

    private static Value ToProtoValue(object? value)
    {
        if (value is null)
        {
            return Value.ForNull();
        }

        return value switch
        {
            string s => Value.ForString(s),
            bool b => Value.ForBool(b),
            int i => Value.ForNumber(i),
            long l => Value.ForNumber(l),
            float f => Value.ForNumber(f),
            double d => Value.ForNumber(d),
            decimal m => Value.ForNumber((double)m),
            IDictionary<string, object?> dict => Value.ForStruct(BuildStruct(dict)),
            IEnumerable<object?> list => Value.ForList(list.Select(ToProtoValue).ToArray()),
            _ => Value.ForString(value.ToString() ?? string.Empty)
        };
    }

    private static Struct BuildStruct(IDictionary<string, object?> source)
    {
        var result = new Struct();

        foreach (var kvp in source)
        {
            result.Fields[kvp.Key] = ToProtoValue(kvp.Value);
        }

        return result;
    }

    private static string GetString(IDictionary<string, object?> source, string key)
        => GetStringOrNull(source, key) ?? string.Empty;

    private static string? GetStringOrNull(IDictionary<string, object?> source, string key)
    {
        if (!source.TryGetValue(key, out var value) || value is null)
            return null;

        return value.ToString();
    }

    private static void SetString(IDictionary<string, object?> source, string key, Action<string> setter)
    {
        var value = GetStringOrNull(source, key);
        if (!string.IsNullOrWhiteSpace(value))
            setter(value);
    }

    private static void SetInt(IDictionary<string, object?> source, string key, Action<int> setter)
    {
        if (!source.TryGetValue(key, out var value) || value is null)
            return;

        if (value is int i)
        {
            setter(i);
            return;
        }

        if (int.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed))
        {
            setter(parsed);
        }
    }

    private static void SetDouble(IDictionary<string, object?> source, string key, Action<double> setter)
    {
        if (!source.TryGetValue(key, out var value) || value is null)
            return;

        if (value is double d)
        {
            setter(d);
            return;
        }

        if (value is float f)
        {
            setter(f);
            return;
        }

        if (value is decimal m)
        {
            setter((double)m);
            return;
        }

        if (double.TryParse(value.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed))
        {
            setter(parsed);
        }
    }
    private static Timestamp? ToTimestamp(DateTime? value)
    {
        return value.HasValue
            ? Timestamp.FromDateTime(DateTime.SpecifyKind(value.Value, DateTimeKind.Utc))
            : null;
    }
    private static string? NullIfEmpty(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value;
}