using CymBuild_Outlook_Common.Models;
using CymBuild_Outlook_Common.Models.SharePoint;
using System.Net.Http.Headers;
using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class GraphService
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly LoggingHelper _loggingHelper;

        // API client (preferred path for ALL operations)
        private HttpClient ApiClient => _httpClientFactory.CreateClient("CymBuild_Outlook_API");

        // Graph client remains available, but should NOT be used in the add-in now.
        // Kept only to avoid breaking DI / older call sites accidentally.
        private HttpClient GraphClient => _httpClientFactory.CreateClient("Graph");

        public GraphService(IHttpClientFactory httpClientFactory, LoggingHelper loggingHelper)
        {
            _httpClientFactory = httpClientFactory;
            _loggingHelper = loggingHelper;
        }

        // --------------------------------------------------------------------
        // IMPORTANT RULE (LOCKED ARCHITECTURE)
        // --------------------------------------------------------------------
        // The Outlook Add-in MUST NOT call Microsoft Graph directly.
        // It should call your API with an API-audience token, and the API
        // performs Graph calls using OBO (On-Behalf-Of).
        // --------------------------------------------------------------------

        // ----------------------------
        // API CALLS (OBO happens server-side)
        // ----------------------------

        /// <summary>
        /// Retrieves message data (including custom properties) via your API.
        /// </summary>
        public async Task<MailRead?> GetEmailDataAsync(string messageId, string? apiToken = null)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(messageId))
                    return null;

                var encodedMessageId = Uri.EscapeDataString(messageId);

                using var req = new HttpRequestMessage(HttpMethod.Get, $"api/Graph/GetMessage/{encodedMessageId}");
                AttachBearerIfProvided(req, apiToken);

                var response = await ApiClient.SendAsync(req);
                response.EnsureSuccessStatusCode();

                return await response.Content.ReadFromJsonAsync<MailRead>();
            }
            catch (HttpRequestException ex)
            {
                _loggingHelper.LogError("HTTP request error", ex, "GetEmailDataAsync()");
                return null;
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError("Unexpected error", ex, "GetEmailDataAsync()");
                return null;
            }
        }

        /// <summary>
        /// Translate Exchange IDs via your API (which must perform the Graph call using OBO).
        /// </summary>
        public async Task<List<ConvertIdResult>?> TranslateExchangeIdsAsync(
            List<string> inputIds,
            string sourceIdType,
            string targetIdType,
            string? apiToken = null,
            string? mailboxOwnerEmail = null)
        {
            try
            {
                if (inputIds == null || inputIds.Count == 0)
                    return new List<ConvertIdResult>();

                var requestBody = new TranslateExchangeIdsApiRequest
                {
                    InputIds = inputIds,
                    SourceIdType = sourceIdType,
                    TargetIdType = targetIdType,
                    MailboxOwnerEmail = mailboxOwnerEmail
                };

                using var req = new HttpRequestMessage(HttpMethod.Post, "api/Graph/TranslateExchangeIds")
                {
                    Content = JsonContent.Create(requestBody)
                };
                AttachBearerIfProvided(req, apiToken);

                var response = await ApiClient.SendAsync(req);
                response.EnsureSuccessStatusCode();

                var result = await response.Content.ReadFromJsonAsync<TranslateExchangeIdsResponse>();
                return result?.Value ?? new List<ConvertIdResult>();
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError("TranslateExchangeIdsAsync (API) failed", ex, "TranslateExchangeIdsAsync()");
                return null;
            }
        }

        /// <summary>
        /// If you still need to read shared mailbox messages, do it via API + OBO.
        /// Your API should implement this route.
        /// </summary>
        public async Task<MailRead?> GetSharedEmailDataAsync(string ownerEmail, string itemId, string? apiToken = null)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(ownerEmail) || string.IsNullOrWhiteSpace(itemId))
                    return null;

                var encodedOwner = Uri.EscapeDataString(ownerEmail);
                var encodedItemId = Uri.EscapeDataString(itemId);

                using var req = new HttpRequestMessage(
                    HttpMethod.Get,
                    $"api/Graph/GetSharedMessage?ownerEmail={encodedOwner}&messageId={encodedItemId}"
                );

                AttachBearerIfProvided(req, apiToken);

                var response = await ApiClient.SendAsync(req);
                response.EnsureSuccessStatusCode();

                return await response.Content.ReadFromJsonAsync<MailRead>();
            }
            catch (HttpRequestException ex)
            {
                _loggingHelper.LogError("HTTP request error", ex, "GetSharedEmailDataAsync()");
                return null;
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError("Unexpected error", ex, "GetSharedEmailDataAsync()");
                return null;
            }
        }

        //public async Task<List<SaveToSharePointResponse>?> SaveMultipleToSharePointAsync(List<SaveToSharePointRequest> requests, string? apiToken = null)
        public async Task<List<SaveToSharePointResponse>?> SaveMultipleToSharePointAsync(
            List<SaveToSharePointRequest> requests,
            string? apiToken = null,
            string? correlationId = null)
        {
            try
            {
                using var req = new HttpRequestMessage(HttpMethod.Post, "api/Graph/SaveMultipleToSharePoint")
                {
                    Content = JsonContent.Create(requests)
                };
                AttachBearerIfProvided(req, apiToken);
                if (!string.IsNullOrWhiteSpace(correlationId))
                    req.Headers.TryAddWithoutValidation("X-Correlation-Id", correlationId);

                var response = await ApiClient.SendAsync(req);
                response.EnsureSuccessStatusCode();

                return await response.Content.ReadFromJsonAsync<List<SaveToSharePointResponse>>();
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError("SaveMultipleToSharePointAsync failed", ex, "SaveMultipleToSharePointAsync()");
                return null;
            }
        }

        public async Task<SaveToSharePointResponse?> SaveToSharePointAsync(SaveToSharePointRequest request, string? apiToken = null)
        {
            try
            {
                using var req = new HttpRequestMessage(HttpMethod.Post, "api/Graph/SaveToSharePoint")
                {
                    Content = JsonContent.Create(request)
                };
                AttachBearerIfProvided(req, apiToken);

                var response = await ApiClient.SendAsync(req);
                response.EnsureSuccessStatusCode();

                var result = await response.Content.ReadFromJsonAsync<SaveToSharePointResponse>();
                if (result != null)
                    _loggingHelper.LogInfo($"Full URL: {result.FullUrl}", "SaveToSharePointAsync()");

                return result;
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError("SaveToSharePointAsync failed", ex, "SaveToSharePointAsync()");
                return null;
            }
        }

        // ----------------------------
        // Helpers
        // ----------------------------

        private static void AttachBearerIfProvided(HttpRequestMessage req, string? token)
        {
            if (!string.IsNullOrWhiteSpace(token))
            {
                req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            }
        }

        // ----------------------------
        // DTOs for API translate
        // ----------------------------

        public class TranslateExchangeIdsApiRequest
        {
            public List<string> InputIds { get; set; } = new();
            public string SourceIdType { get; set; } = "restId";
            public string TargetIdType { get; set; } = "restImmutableEntryId";

            // optional: when shared mailbox
            public string? MailboxOwnerEmail { get; set; }
        }

        public class TranslateExchangeIdsResponse
        {
            public List<ConvertIdResult>? Value { get; set; }
        }

        public class ConvertIdResult
        {
            public string? SourceId { get; set; }
            public string? TargetId { get; set; }
        }
    }
}
