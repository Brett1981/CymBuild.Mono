using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Web;

namespace CymBuild_AIErrorServiceAPI.Services
{
    public class AiAnalyzerService
    {
        private readonly HttpClient _http;
        private readonly IConfiguration _config;
        private string? _cachedToken;
        private DateTime _tokenExpiresUtc = DateTime.MinValue;

        public AiAnalyzerService(IConfiguration config, HttpClient http)
        {
            _config = config;
            _http = http;
        }

        public async Task<string> AnalyzeAsync(string error, string stack, string context)
        {
            var prompt = $"Analyze this CymBuild error:\n\nError: {error}\n\nStack Trace: {stack}\n\nContext: {context}";

            // Try once, allow retry if token expired
            return await CallChatEndpointAsync(prompt, retryOnUnauthorized: true);
        }

        private async Task<string> CallChatEndpointAsync(string message, bool retryOnUnauthorized)
        {
            string token = await GetJwtTokenAsync();
            var endpoint = _config["BlueGen:Endpoint"];
            var payload = JsonSerializer.Serialize(new { message });

            // === Log the outgoing request ===
            Console.WriteLine($"[BlueGen] Calling endpoint: {endpoint}");
            //Console.WriteLine($"\n\nToken: {token}\n\n");
            Console.WriteLine($"[BlueGen] Sending to: {endpoint}");
            Console.WriteLine($"[BlueGen] JWT Expires: {_tokenExpiresUtc:u}");
            Console.WriteLine($"[BlueGen] JWT (start): {token.Substring(0, Math.Min(80, token.Length))}...");
            Console.WriteLine($"[BlueGen] Payload: {payload}");

            using var request = new HttpRequestMessage(HttpMethod.Post, endpoint);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            request.Content = new StringContent(payload, Encoding.UTF8, "application/json");

            // Dump headers
            Console.WriteLine("[BlueGen] Headers:");
            foreach (var header in request.Headers)
                Console.WriteLine($"    {header.Key}: {string.Join(", ", header.Value)}");

            // === Send initial request ===
            var response = await _http.SendAsync(request);
            Console.WriteLine($"[BlueGen] Initial response status: {response.StatusCode}");

            // === Retry once on Unauthorized ===
            if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized && retryOnUnauthorized)
            {
                Console.WriteLine("[BlueGen] Token expired or rejected. Retrying with new token...");
                _cachedToken = null;
                _tokenExpiresUtc = DateTime.MinValue;

                token = await GetJwtTokenAsync();
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

                response = await _http.SendAsync(request);
                Console.WriteLine($"[BlueGen] Retry response status: {response.StatusCode}");
            }

            // === Read and log raw response body ===
            string responseBody = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                Console.Error.WriteLine($"❌ [BlueGen] Chat API failed: {response.StatusCode}");
                Console.Error.WriteLine($"❌ [BlueGen] Response body: {responseBody}");

                return $"[AI analysis failed: BlueGen {response.StatusCode} - {responseBody?.Substring(0, Math.Min(300, responseBody.Length))}]";
            }

            // === Attempt to parse and extract 'summary' or 'ai_response' ===
            try
            {
                var json = JsonSerializer.Deserialize<JsonElement>(responseBody);
                Console.WriteLine($"[BlueGen] Parsed JSON response: {json}");

                if (json.TryGetProperty("summary", out var summaryProp) && summaryProp.ValueKind == JsonValueKind.String)
                    return summaryProp.GetString() ?? "[AI analysis returned null summary]";

                if (json.TryGetProperty("ai_response", out var aiProp) && aiProp.ValueKind == JsonValueKind.String)
                    return aiProp.GetString() ?? "[AI analysis returned null ai_response]";
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"❌ [BlueGen] Failed to parse JSON response: {ex.Message}");
                Console.Error.WriteLine($"❌ [BlueGen] Raw response body: {responseBody}");

                return $"[AI analysis failed: Invalid JSON - {ex.Message}]";
            }

            // === No usable response fields present ===
            return $"[AI analysis failed: No expected properties in BlueGen reply. Body: {responseBody?.Substring(0, Math.Min(300, responseBody.Length))}]";
        }

        public async Task<string> GetJwtTokenAsync()
        {
            var authUrl = _config["BlueGen:AuthEndpoint"];
            var email = _config["BlueGen:Email"];
            var password = _config["BlueGen:Password"];

            if (string.IsNullOrWhiteSpace(authUrl) || string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
                throw new InvalidOperationException("[BlueGen] Missing auth credentials.");

            // Build URL with query parameters
            var uriBuilder = new UriBuilder(authUrl);
            var query = HttpUtility.ParseQueryString(uriBuilder.Query);
            query["email"] = email;
            query["password"] = password;
            uriBuilder.Query = query.ToString();

            var response = await _http.PostAsync(uriBuilder.Uri, null); // No content body needed

            if (!response.IsSuccessStatusCode)
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                throw new InvalidOperationException($"[BlueGen] Token request failed ({response.StatusCode}):\n{errorContent}");
            }

            var result = await response.Content.ReadFromJsonAsync<JsonElement>();

            // Check for token in the response
            if (result.TryGetProperty("access_token", out var tokenElement))
            {
                return tokenElement.GetString() ?? throw new InvalidOperationException("[BlueGen] Empty token received.");
            }
            else if (result.TryGetProperty("token", out tokenElement))
            {
                return tokenElement.GetString() ?? throw new InvalidOperationException("[BlueGen] Empty token received.");
            }
            else
            {
                throw new InvalidOperationException($"[BlueGen] Token not found in response. Response:\n{result}");
            }
        }

        public async Task<string> AnalyzeFileAsync(string filename, Stream stream, string description)
        {
            string token = await GetJwtTokenAsync();

            // Step 1: Request presigned URL
            var presignRequest = new
            {
                files = new[] { filename }
            };

            using var presignContent = new StringContent(JsonSerializer.Serialize(presignRequest), Encoding.UTF8, "application/json");
            using var presignReq = new HttpRequestMessage(HttpMethod.Post, _config["BlueGen:PresignUrl"]);
            presignReq.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            presignReq.Content = presignContent;

            var presignResp = await _http.SendAsync(presignReq);
            presignResp.EnsureSuccessStatusCode();

            var presignJson = await presignResp.Content.ReadFromJsonAsync<JsonElement>();
            var uploadUrl = presignJson.GetProperty("presigned_url")[0].GetString();
            var folder = presignJson.GetProperty("folder").GetString();

            // Step 2: Upload file using PUT
            using var uploadReq = new HttpRequestMessage(HttpMethod.Put, uploadUrl);
            uploadReq.Content = new StreamContent(stream);
            uploadReq.Content.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
            var uploadResp = await _http.SendAsync(uploadReq);
            uploadResp.EnsureSuccessStatusCode();

            // Step 3: Send chat message with folder
            var chatBody = new
            {
                message = description,
                folder = folder
            };

            using var chatContent = new StringContent(JsonSerializer.Serialize(chatBody), Encoding.UTF8, "application/json");
            using var chatReq = new HttpRequestMessage(HttpMethod.Post, _config["BlueGen:Endpoint"]);
            chatReq.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            chatReq.Content = chatContent;

            var chatResp = await _http.SendAsync(chatReq);
            chatResp.EnsureSuccessStatusCode();

            var chatJson = await chatResp.Content.ReadFromJsonAsync<JsonElement>();
            Console.WriteLine("[BlueGen] AnalyzeFileAsync response: " + chatJson);

            if (chatJson.TryGetProperty("ai_response", out var aiRespProp) && aiRespProp.ValueKind == JsonValueKind.String)
                return aiRespProp.GetString() ?? "No analysis returned.";

            return "[AI analysis failed: 'ai_response' not found in response]";
        }
    }
}