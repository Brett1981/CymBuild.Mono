using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class EmailDescriptionService
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<EmailDescriptionService> _logger;

        public EmailDescriptionService(HttpClient httpClient, ILogger<EmailDescriptionService> logger)
        {
            _httpClient = httpClient;
            _logger = logger;
        }

        public async Task<string> GenerateDescriptionAsync(string subject, string body, string apiToken)
        {
            try
            {
                _logger.LogInformation("GenerateDescriptionAsync called. SubjectLength={SubjectLength}, BodyLength={BodyLength}", 
                    subject?.Length ?? 0, body?.Length ?? 0);

                if (string.IsNullOrWhiteSpace(subject) && string.IsNullOrWhiteSpace(body))
                {
                    _logger.LogWarning("Both subject and body are empty");
                    return "Unable to generate description: email has no subject or body";
                }

                var request = new GenerateDescriptionRequest
                {
                    Subject = subject,
                    Body = body
                };

                using var httpRequest = new HttpRequestMessage(HttpMethod.Post, "api/EmailDescription/generate");
                httpRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiToken);
                httpRequest.Content = JsonContent.Create(request);

                var response = await _httpClient.SendAsync(httpRequest);

                if (!response.IsSuccessStatusCode)
                {
                    var errorBody = await response.Content.ReadAsStringAsync();
                    _logger.LogError("API call failed. Status={Status}, Response={Response}", 
                        response.StatusCode, errorBody);
                    return "Failed to generate description. Please try again.";
                }

                var result = await response.Content.ReadFromJsonAsync<GenerateDescriptionResponse>();

                if (result == null || !result.Success)
                {
                    _logger.LogWarning("API returned unsuccessful response. Error={Error}", result?.Error);
                    return result?.Error ?? "Failed to generate description";
                }

                _logger.LogInformation("Description generated successfully. Length={Length}", result.Description?.Length ?? 0);
                return result.Description ?? string.Empty;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Exception in GenerateDescriptionAsync");
                return "An error occurred while generating description";
            }
        }
    }

    public class GenerateDescriptionRequest
    {
        public string? Subject { get; set; }
        public string? Body { get; set; }
    }

    public class GenerateDescriptionResponse
    {
        public bool Success { get; set; }
        public string? Description { get; set; }
        public string? Error { get; set; }
    }
}
