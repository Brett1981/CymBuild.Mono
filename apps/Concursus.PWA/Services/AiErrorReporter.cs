using Concursus.API.Client.Models;
using Concursus.PWA.Shared;
using Microsoft.AspNetCore.Components.WebAssembly.Authentication;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace Concursus.PWA.Services
{
    public class AiErrorReporter
    {
        private readonly IAccessTokenProvider _tokenProvider;
        private readonly HttpClient _http;
        private readonly IConfiguration _config;
        private readonly UserService _userService;

        public AiErrorReporter(HttpClient http,
                               IAccessTokenProvider tokenProvider,
                               IConfiguration config,
                               UserService userService)
        {
            _http = http;
            _tokenProvider = tokenProvider;
            _config = config;
            _userService = userService;
        }

        public async Task<AiErrorReportResult?> ReportAsync(Exception ex, object context)
        {
            // Check if AI error service is enabled
            if (!_config.GetValue<bool>("AiErrorService:Enabled"))
                return null;

            try
            {
                var tokenResult = await _tokenProvider.RequestAccessToken();
                if (!tokenResult.TryGetToken(out var token))
                {
                    Console.WriteLine("⚠ Unable to authenticate for AI error reporting.", MessageDisplay.ShowMessageType.Warning);
                    return new AiErrorReportResult
                    {
                        Success = false,
                        UiMessage = "⚠ Unable to authenticate for AI error reporting.",
                        MessageType = MessageDisplay.ShowMessageType.Error
                    };
                }

                _http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Value);

                var baseUrl = _config["AiErrorService:BaseUrl"]?.TrimEnd('/');
                if (string.IsNullOrEmpty(baseUrl))
                {
                    Console.WriteLine("❌ AI Error Service URL is not configured.", MessageDisplay.ShowMessageType.Error);
                    return new AiErrorReportResult
                    {
                        Success = true,
                        UiMessage = $"⚠ Failed to contact AI error service. Please raise a helpdesk ticket.",
                        MessageType = MessageDisplay.ShowMessageType.Information
                    };
                }

                var userId = _userService.FullName;
                var endpoint = $"{baseUrl}/api/ErrorReport";

                var request = new
                {
                    UserId = userId,
                    ErrorMessage = ex.Message,
                    Description = ex.Data.Contains("UserInteractionLog") ? ex.Data["UserInteractionLog"]?.ToString() : "No description provided.",
                    StackTrace = ex.StackTrace ?? "No stack trace available.",
                    ContextJson = JsonSerializer.Serialize(context)
                };

                var response = await _http.PostAsJsonAsync(endpoint, request);
                if (!response.IsSuccessStatusCode)
                {
                    Console.WriteLine("⚠ Failed to contact AI error service. Please raise a helpdesk ticket.", MessageDisplay.ShowMessageType.Warning);
                    return new AiErrorReportResult
                    {
                        Success = false,
                        UiMessage = $"⚠ Failed to contact AI error service. Please raise a helpdesk ticket.",
                        MessageType = MessageDisplay.ShowMessageType.Information
                    };
                }

                var resultJson = await response.Content.ReadAsStringAsync();
                var result = JsonSerializer.Deserialize<AiErrorResponse>(resultJson, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                if (result == null)
                {
                    Console.WriteLine("⚠ Unexpected response from AI error service.", MessageDisplay.ShowMessageType.Warning);
                    return new AiErrorReportResult
                    {
                        Success = false,
                        UiMessage = $"⚠ Unexpected response from AI error service.",
                        MessageType = MessageDisplay.ShowMessageType.Information
                    };
                }

                if (result.AlreadyExists)
                {
                    return new AiErrorReportResult
                    {
                        Success = true,
                        AlreadyExists = true,
                        JiraTicketKey = result.JiraTicketKey,
                        JiraStatus = result.JiraStatus,
                        JiraDescription = result.JiraDescription,
                        ErrorMessage = result.ErrorMessage,
                        UiMessage = $"📌 This issue has already been raised and logged.\n" +
                                    $"🔖 Ticket: {result.JiraTicketKey}\n" +
                                    $"📄 Title: {(result.ErrorMessage.Length > 60 ? result.ErrorMessage.Substring(0, 60) + "..." : result.ErrorMessage)}\n" +
                                    $"📌 Status: {result.JiraStatus}",
                        MessageType = MessageDisplay.ShowMessageType.Information
                    };
                }
                else
                {
                    return new AiErrorReportResult
                    {
                        Success = true,
                        AlreadyExists = false,
                        JiraTicketKey = result.JiraTicketKey,
                        JiraStatus = result.JiraStatus,
                        ErrorMessage = result.ErrorMessage,
                        UiMessage = $"🧠 We have automatically logged this new issue on your behalf.\n" +
                                    $"🔖 Ticket: {result.JiraTicketKey}\n" +
                                    $"📄 Title: {(result.ErrorMessage.Length > 60 ? result.ErrorMessage.Substring(0, 60) + "..." : result.ErrorMessage)}\n" +
                                    $"📌 Status: {result.JiraStatus}",
                        MessageType = MessageDisplay.ShowMessageType.Success
                    };
                }
            }
            catch (Exception e)
            {
                return new AiErrorReportResult
                {
                    Success = false,
                    UiMessage = "❌ Failed to report AI error. Please raise a helpdesk ticket.",
                    MessageType = MessageDisplay.ShowMessageType.Error
                };
            }
        }

        private class AiErrorResponse
        {
            public bool AlreadyExists { get; set; }
            public string JiraTicketKey { get; set; } = string.Empty;
            public string JiraStatus { get; set; } = string.Empty;
            public string ErrorMessage { get; set; } = string.Empty;
            public string JiraDescription { get; set; } = string.Empty;
        }

        public class AiErrorReportResult
        {
            public bool Success { get; set; }
            public bool AlreadyExists { get; set; }
            public string JiraTicketKey { get; set; } = string.Empty;
            public string JiraStatus { get; set; } = string.Empty;
            public string ErrorMessage { get; set; } = string.Empty;
            public string JiraDescription { get; set; } = string.Empty;
            public string UiMessage { get; set; } = string.Empty;
            public MessageDisplay.ShowMessageType MessageType { get; set; }
        }
    }
}