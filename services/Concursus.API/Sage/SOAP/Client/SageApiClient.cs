using Concursus.API.Sage.SOAP.Interface;
using Concursus.API.Sage.SOAP.Models;
using Microsoft.Extensions.Options;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace Concursus.API.Sage.SOAP.Client
{
    /// <summary>
    /// HTTP client wrapper for the external Sage API.
    /// Existing functionality is preserved.
    /// Additional safeguards:
    /// - honours Enabled flag
    /// - supports configurable timeout from Program.cs
    /// - supports configurable health path
    /// - throws clear errors when misconfigured
    /// </summary>
    public sealed class SageApiClient : ISageApiClient
    {
        private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

        private readonly HttpClient _httpClient;
        private readonly SageApiOptions _options;

        public SageApiClient(HttpClient httpClient, IOptions<SageApiOptions> options)
        {
            _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
            _options = options?.Value ?? throw new ArgumentNullException(nameof(options));

            if (!_httpClient.DefaultRequestHeaders.Accept.Any(h => h.MediaType == "application/json"))
            {
                _httpClient.DefaultRequestHeaders.Accept.Add(
                    new MediaTypeWithQualityHeaderValue("application/json"));
            }

            if (!string.IsNullOrWhiteSpace(_options.ApiKey))
            {
                if (string.Equals(_options.ApiKeyHeaderName, "Authorization", StringComparison.OrdinalIgnoreCase))
                {
                    _httpClient.DefaultRequestHeaders.Authorization =
                        new AuthenticationHeaderValue(
                            string.IsNullOrWhiteSpace(_options.ApiKeyPrefix) ? "Bearer" : _options.ApiKeyPrefix,
                            _options.ApiKey);
                }
                else
                {
                    _httpClient.DefaultRequestHeaders.Remove(_options.ApiKeyHeaderName);
                    _httpClient.DefaultRequestHeaders.Add(_options.ApiKeyHeaderName, _options.ApiKey);
                }
            }
        }

        public async Task<string> GetHealthAsync(CancellationToken cancellationToken = default)
        {
            EnsureEnabled();

            var path = string.IsNullOrWhiteSpace(_options.HealthPath) ? "/health" : _options.HealthPath;
            return await _httpClient.GetStringAsync(path, cancellationToken);
        }

        public async Task<SageCreateSalesOrderResponse?> CreateSalesOrderAsync(
            SageCreateSalesOrderRequest request,
            CancellationToken cancellationToken = default)
        {
            EnsureEnabled();
            ArgumentNullException.ThrowIfNull(request);

            using var response = await _httpClient.PostAsJsonAsync(
                "/api/sales-orders",
                request,
                JsonOptions,
                cancellationToken);

            await EnsureSuccessAsync(response, cancellationToken);

            return await response.Content.ReadFromJsonAsync<SageCreateSalesOrderResponse>(JsonOptions, cancellationToken);
        }

        public async Task<SageFetchSalesOrdersResponse?> FetchSalesOrdersAsync(
            SageDataset dataset,
            string orderId,
            string? filterOperator = null,
            bool force = false,
            CancellationToken cancellationToken = default)
        {
            EnsureEnabled();

            var query = new List<string>
            {
                $"dataset={Uri.EscapeDataString(dataset.ToString())}",
                $"orderId={Uri.EscapeDataString(orderId ?? string.Empty)}"
            };

            if (!string.IsNullOrWhiteSpace(filterOperator))
            {
                query.Add($"filterOperator={Uri.EscapeDataString(filterOperator)}");
            }

            if (force)
            {
                query.Add("force=true");
            }

            var url = "/api/sales-orders?" + string.Join("&", query);

            return await _httpClient.GetFromJsonAsync<SageFetchSalesOrdersResponse>(url, JsonOptions, cancellationToken);
        }

        public async Task<SageFetchCustomerTransactionsResponse?> FetchCustomerTransactionsAsync(
            SageDataset dataset,
            string? accountReference = null,
            string? documentNo = null,
            int? sysTraderTranType = null,
            bool force = false,
            CancellationToken cancellationToken = default)
        {
            EnsureEnabled();

            if (string.IsNullOrWhiteSpace(accountReference) && string.IsNullOrWhiteSpace(documentNo))
            {
                throw new ArgumentException("Either accountReference or documentNo must be provided.");
            }

            var query = new List<string>
            {
                $"dataset={Uri.EscapeDataString(dataset.ToString())}"
            };

            if (!string.IsNullOrWhiteSpace(accountReference))
            {
                query.Add($"accountReference={Uri.EscapeDataString(accountReference)}");
            }

            if (!string.IsNullOrWhiteSpace(documentNo))
            {
                query.Add($"documentNo={Uri.EscapeDataString(documentNo)}");
            }

            if (sysTraderTranType.HasValue)
            {
                query.Add($"sysTraderTranType={sysTraderTranType.Value}");
            }

            if (force)
            {
                query.Add("force=true");
            }

            var url = "/api/customer-transactions?" + string.Join("&", query);

            return await _httpClient.GetFromJsonAsync<SageFetchCustomerTransactionsResponse>(url, JsonOptions, cancellationToken);
        }

        private void EnsureEnabled()
        {
            if (!_options.Enabled)
            {
                throw new InvalidOperationException("Sage integration is disabled by configuration.");
            }
        }

        private static async Task EnsureSuccessAsync(HttpResponseMessage response, CancellationToken cancellationToken)
        {
            if (response.IsSuccessStatusCode)
            {
                return;
            }

            var responseBody = response.Content is null
                ? string.Empty
                : await response.Content.ReadAsStringAsync(cancellationToken);

            throw new HttpRequestException(
                $"Sage API request failed with status {(int)response.StatusCode} ({response.ReasonPhrase}). Response: {responseBody}");
        }
    }
}