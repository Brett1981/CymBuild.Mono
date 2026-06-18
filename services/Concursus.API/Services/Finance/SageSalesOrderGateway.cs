#nullable enable

using Concursus.API.Sage.SOAP;
using Concursus.API.Sage.SOAP.Models;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using SageCreateSalesOrderRequest = Concursus.Common.Shared.Models.Finance.SageCreateSalesOrderRequest;
using SageCreateSalesOrderResponse = Concursus.Common.Shared.Models.Finance.SageCreateSalesOrderResponse;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// HTTP gateway for the Sage REST-wrapper sales-order endpoint.
    ///
    /// Responsibilities:
    /// - isolate wrapper HTTP details from orchestration logic
    /// - keep request/response serialization deterministic
    /// - preserve response metadata required for retry classification
    /// - avoid throwing for expected wrapper/API failures
    /// </summary>
    public sealed class SageSalesOrderGateway : ISageSalesOrderGateway
    {
        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNamingPolicy = null,
            PropertyNameCaseInsensitive = true,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        private readonly HttpClient _httpClient;
        private readonly IOptionsMonitor<SageApiOptions> _options;
        private readonly ILogger<SageSalesOrderGateway> _logger;

        public SageSalesOrderGateway(
            HttpClient httpClient,
            IOptionsMonitor<SageApiOptions> options,
            ILogger<SageSalesOrderGateway> logger)
        {
            _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
            _options = options ?? throw new ArgumentNullException(nameof(options));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        /// <summary>
        /// Submits a sales order to the wrapper endpoint.
        /// Returns a populated response DTO for both success and expected HTTP failures.
        /// Throws only for invalid local state or malformed success payloads.
        /// </summary>
        public async Task<SageCreateSalesOrderResponse> CreateSalesOrderAsync(
            SageCreateSalesOrderRequest request,
            CancellationToken cancellationToken = default)
        {
            if (request is null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            var options = _options.CurrentValue;

            if (!options.Enabled)
            {
                _logger.LogInformation(
                    "Sage sales-order submission skipped because Sage integration is disabled.");

                return new SageCreateSalesOrderResponse
                {
                    Status = "Error",
                    OrderId = string.Empty,
                    Detail = "Sage integration is disabled.",
                    HttpStatusCode = 503,
                    RawResponseBody = string.Empty
                };
            }

            var requestJson = JsonSerializer.Serialize(request, JsonOptions);

            using var message = new HttpRequestMessage(HttpMethod.Post, "api/sales-orders")
            {
                Content = new StringContent(requestJson, Encoding.UTF8, "application/json")
            };

            if (!string.IsNullOrWhiteSpace(options.ApiKey))
            {
                message.Headers.Authorization =
                    new AuthenticationHeaderValue("Bearer", options.ApiKey.Trim());
            }

            _logger.LogInformation(
                "Posting sales order to Sage wrapper. Dataset={Dataset}, AccountReference={AccountReference}, CustomerOrderNo={CustomerOrderNo}, LineCount={LineCount}",
                request.Dataset,
                request.AccountReference,
                request.CustomerOrderNo,
                request.Lines?.Count ?? 0);

            try
            {
                using var response = await _httpClient.SendAsync(
                    message,
                    HttpCompletionOption.ResponseHeadersRead,
                    cancellationToken);

                var responseBody = response.Content is null
                    ? string.Empty
                    : await response.Content.ReadAsStringAsync(cancellationToken);

                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning(
                        "Sage sales-order POST failed. StatusCode={StatusCode}, Body={Body}",
                        (int)response.StatusCode,
                        responseBody);

                    return new SageCreateSalesOrderResponse
                    {
                        Status = "Error",
                        OrderId = string.Empty,
                        Detail = string.IsNullOrWhiteSpace(responseBody)
                            ? $"HTTP {(int)response.StatusCode}"
                            : responseBody,
                        HttpStatusCode = (int)response.StatusCode,
                        RawResponseBody = responseBody ?? string.Empty
                    };
                }

                if (string.IsNullOrWhiteSpace(responseBody))
                {
                    throw new InvalidOperationException(
                        "Sage sales-order response body was empty on a successful HTTP response.");
                }

                var dto = JsonSerializer.Deserialize<SageCreateSalesOrderResponse>(responseBody, JsonOptions);

                if (dto is null)
                {
                    throw new InvalidOperationException(
                        "Sage sales-order response body could not be deserialized.");
                }

                dto.HttpStatusCode = (int)response.StatusCode;
                dto.RawResponseBody = responseBody;

                _logger.LogInformation(
                    "Sage sales-order POST succeeded. StatusCode={StatusCode}, WrapperStatus={WrapperStatus}, OrderId={OrderId}",
                    (int)response.StatusCode,
                    dto.Status,
                    dto.OrderId);

                return dto;
            }
            catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                _logger.LogWarning(
                    "Sage sales-order POST timed out before completion.");

                return new SageCreateSalesOrderResponse
                {
                    Status = "Error",
                    OrderId = string.Empty,
                    Detail = "The Sage sales-order request timed out.",
                    HttpStatusCode = 408,
                    RawResponseBody = string.Empty
                };
            }
            catch (HttpRequestException ex)
            {
                var statusCode = ex.StatusCode is null
                    ? (int?)null
                    : (int)ex.StatusCode.Value;

                _logger.LogWarning(
                    ex,
                    "HTTP error while posting sales order to Sage wrapper. StatusCode={StatusCode}",
                    statusCode);

                return new SageCreateSalesOrderResponse
                {
                    Status = "Error",
                    OrderId = string.Empty,
                    Detail = string.IsNullOrWhiteSpace(ex.Message)
                        ? "A network error occurred while calling the Sage wrapper."
                        : ex.Message,
                    HttpStatusCode = statusCode,
                    RawResponseBody = string.Empty
                };
            }
        }

        public async Task<IReadOnlyList<Dictionary<string, object?>>> FetchCustomerTransactionsAsync(
    SageDataset dataset,
    string accountReference,
    string documentNo,
    int? sysTraderTranType = null,
    bool force = false,
    CancellationToken cancellationToken = default)
        {
            var options = _options.CurrentValue;

            if (!options.Enabled)
            {
                _logger.LogInformation("Sage customer transaction fetch skipped because Sage integration is disabled.");
                return Array.Empty<Dictionary<string, object?>>();
            }

            var query = new List<string>
    {
        $"dataset={WebUtility.UrlEncode(dataset.ToString().ToLowerInvariant())}"
    };

            if (!string.IsNullOrWhiteSpace(accountReference))
                query.Add($"accountReference={WebUtility.UrlEncode(accountReference.Trim())}");

            if (!string.IsNullOrWhiteSpace(documentNo))
                query.Add($"documentNo={WebUtility.UrlEncode(documentNo.Trim())}");

            if (sysTraderTranType.HasValue)
                query.Add($"sysTraderTranType={sysTraderTranType.Value}");

            if (force)
                query.Add("force=true");

            var uri = "api/customer-transactions?" + string.Join("&", query);

            using var message = new HttpRequestMessage(HttpMethod.Get, uri);

            if (!string.IsNullOrWhiteSpace(options.ApiKey))
            {
                message.Headers.Authorization =
                    new AuthenticationHeaderValue("Bearer", options.ApiKey.Trim());
            }

            _logger.LogInformation(
                "Fetching Sage customer transactions. Dataset={Dataset}, AccountReference={AccountReference}, DocumentNo={DocumentNo}, SysTraderTranType={SysTraderTranType}, Force={Force}",
                dataset,
                accountReference,
                documentNo,
                sysTraderTranType,
                force);

            using var response = await _httpClient.SendAsync(
                message,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken).ConfigureAwait(false);

            var responseBody = response.Content is null
                ? string.Empty
                : await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning(
                    "Sage customer transaction fetch failed. StatusCode={StatusCode}, Body={Body}",
                    (int)response.StatusCode,
                    responseBody);

                return Array.Empty<Dictionary<string, object?>>();
            }

            using var document = JsonDocument.Parse(responseBody);

            if (!document.RootElement.TryGetProperty("transactions", out var transactionsElement) ||
                transactionsElement.ValueKind != JsonValueKind.Array)
            {
                _logger.LogWarning(
                    "Sage customer transaction fetch response did not contain a transactions array. Body={Body}",
                    responseBody);

                return Array.Empty<Dictionary<string, object?>>();
            }

            var rows = JsonSerializer.Deserialize<List<Dictionary<string, object?>>>(
                transactionsElement.GetRawText(),
                JsonOptions);

            _logger.LogInformation(
                "Sage customer transaction fetch completed. Returned={Returned}, DocumentNo={DocumentNo}",
                rows?.Count ?? 0,
                documentNo);

            return rows ?? new List<Dictionary<string, object?>>();
        }
    }
}