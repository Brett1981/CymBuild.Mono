using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Web;

namespace CymBuild_Outlook_API.Services
{
    public class BlueGenService
    {
        private readonly HttpClient _http;
        private readonly IConfiguration _config;
        private readonly ILogger<BlueGenService> _logger;

        public BlueGenService(IConfiguration config, HttpClient http, ILogger<BlueGenService> logger)
        {
            _config = config;
            _http = http;
            _logger = logger;
        }

        public async Task<string> GenerateEmailDescriptionAsync(string subject, string body)
        {
            var truncatedBody = TruncateBody(body, 1000);
            
            var prompt = $@"Generate a concise, professional description (2-3 sentences, max 250 characters) for this email to be used when filing it. Focus on key action items, decisions, or important information.

Subject: {subject}

Body: {truncatedBody}

Return only the description text, nothing else.";

            return await CallChatEndpointAsync(prompt, retryOnUnauthorized: true);
        }

        private string TruncateBody(string body, int maxLength)
        {
            if (string.IsNullOrEmpty(body) || body.Length <= maxLength)
                return body ?? string.Empty;

            return body.Substring(0, maxLength) + "...";
        }

        private async Task<string> CallChatEndpointAsync(string message, bool retryOnUnauthorized)
        {
            string token = await GetJwtTokenAsync();
            var endpoint = $"{_config["BlueGen:BaseUrl"]}/api/chat";
            var payload = JsonSerializer.Serialize(new { message });

            _logger.LogInformation("[BlueGen] Calling endpoint: {Endpoint}", endpoint);

            using var request = new HttpRequestMessage(HttpMethod.Post, endpoint);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            request.Content = new StringContent(payload, Encoding.UTF8, "application/json");

            var response = await _http.SendAsync(request);
            _logger.LogInformation("[BlueGen] Initial response status: {StatusCode}", response.StatusCode);

            if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized && retryOnUnauthorized)
            {
                _logger.LogWarning("[BlueGen] Token expired or rejected. Retrying with new token...");

                token = await GetJwtTokenAsync();
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

                response = await _http.SendAsync(request);
                _logger.LogInformation("[BlueGen] Retry response status: {StatusCode}", response.StatusCode);
            }

            string responseBody = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("[BlueGen] Chat API failed: {StatusCode}, Response: {Response}", 
                    response.StatusCode, responseBody);
                return $"[AI analysis failed: BlueGen {response.StatusCode}]";
            }

            try
            {
                var json = JsonSerializer.Deserialize<JsonElement>(responseBody);
                _logger.LogInformation("[BlueGen] Parsed JSON response");

                if (json.TryGetProperty("summary", out var summaryProp) && summaryProp.ValueKind == JsonValueKind.String)
                    return summaryProp.GetString() ?? "[AI analysis returned null summary]";

                if (json.TryGetProperty("ai_response", out var aiProp) && aiProp.ValueKind == JsonValueKind.String)
                    return aiProp.GetString() ?? "[AI analysis returned null ai_response]";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[BlueGen] Failed to parse JSON response. Raw body: {Body}", responseBody);
                return $"[AI analysis failed: Invalid JSON - {ex.Message}]";
            }

            return $"[AI analysis failed: No expected properties in BlueGen reply]";
        }

        private async Task<string> GetJwtTokenAsync()
        {
            var authUrl = $"{_config["BlueGen:BaseUrl"]}/api/token";
            var email = _config["BlueGen:Email"];
            var password = _config["BlueGen:Password"];

            if (string.IsNullOrWhiteSpace(authUrl) || string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
                throw new InvalidOperationException("[BlueGen] Missing auth credentials.");

            var uriBuilder = new UriBuilder(authUrl);
            var query = HttpUtility.ParseQueryString(uriBuilder.Query);
            query["email"] = email;
            query["password"] = password;
            uriBuilder.Query = query.ToString();

            _logger.LogInformation("[BlueGen] Requesting new JWT token");

            var response = await _http.PostAsync(uriBuilder.Uri, null);

            if (!response.IsSuccessStatusCode)
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                _logger.LogError("[BlueGen] Token request failed ({StatusCode}): {Error}", 
                    response.StatusCode, errorContent);
                throw new InvalidOperationException($"[BlueGen] Token request failed ({response.StatusCode})");
            }

            var result = await response.Content.ReadFromJsonAsync<JsonElement>();

            if (result.TryGetProperty("access_token", out var tokenElement))
            {
                var token = tokenElement.GetString() ?? throw new InvalidOperationException("[BlueGen] Empty token received.");
                _logger.LogInformation("[BlueGen] New token acquired");
                return token;
            }
            else if (result.TryGetProperty("token", out tokenElement))
            {
                var token = tokenElement.GetString() ?? throw new InvalidOperationException("[BlueGen] Empty token received.");
                _logger.LogInformation("[BlueGen] New token acquired");
                return token;
            }
            else
            {
                _logger.LogError("[BlueGen] Token not found in response");
                throw new InvalidOperationException($"[BlueGen] Token not found in response");
            }
        }
    }
}
