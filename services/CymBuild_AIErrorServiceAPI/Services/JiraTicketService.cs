using CymBuild_AIErrorServiceAPI.Dto;
using CymBuild_AIErrorServiceAPI.Helpers;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace CymBuild_AIErrorServiceAPI.Services
{
    public class JiraTicketService
    {
        private readonly HttpClient _http;
        private readonly IConfiguration _config;

        public JiraTicketService(IConfiguration config, HttpClient http)
        {
            _config = config;
            _http = http;

            var baseUrl = _config["Jira:BaseUrl"];
            _http.BaseAddress = new Uri(baseUrl);

            var email = _config["Jira:Username"];
            var token = _config["Jira:ApiToken"];
            var auth = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{email}:{token}"));

            _http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic", auth);
        }

        public async Task<(string Status, string Description, string Priority, string AiAnalysis)> GetTicketDetailsAsync(string ticketKey)
        {
            var cloudId = _config["Jira:CloudId"];
            var url = $"/ex/jira/{cloudId}/rest/api/3/issue/{ticketKey}";

            var response = await _http.GetAsync(url);
            response.EnsureSuccessStatusCode();

            var json = await response.Content.ReadFromJsonAsync<JsonElement>();
            var fields = json.GetProperty("fields");

            // Status
            var status = fields.GetProperty("status").GetProperty("name").GetString();

            // Description (ADF JSON)
            var description = fields.TryGetProperty("description", out var descNode)
                ? JsonSerializer.Serialize(descNode)
                : null;

            // Priority
            var priority = fields.TryGetProperty("priority", out var priNode)
                ? priNode.GetProperty("name").GetString()
                : null;

            // AI Response (ADF JSON)
            var aiAnalysis = fields.TryGetProperty("customfield_10256", out var aiField)
                ? JsonSerializer.Serialize(aiField)
                : null;

            return (status, description, priority, aiAnalysis);
        }

        public async Task<(string Key, string Url, string Status)> CreateTicketAsync(string summary, string description, string aiAnalysis)
        {
            var cloudId = _config["Jira:CloudId"];
            var apiUrl = $"/ex/jira/{cloudId}/rest/api/3/issue";

            // Deserialize the ADF JSON we already generated
            var descriptionAdf = JsonSerializer.Deserialize<JsonElement>(description);

            // Convert AI summary from Markdown to ADF
            var aiAnalysisAdf = MarkdownToAdfConverter.Convert(aiAnalysis);

            var payload = new
            {
                fields = new
                {
                    project = new { key = _config["Jira:ProjectKey"] },
                    summary,
                    description = descriptionAdf,
                    customfield_10256 = aiAnalysisAdf,  // Use converted ADF
                    issuetype = new { name = "Bug" }
                }
            };

            var response = await _http.PostAsJsonAsync(apiUrl, payload);
            if (!response.IsSuccessStatusCode)
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                Console.WriteLine("❌ Jira create failed: {statusCode} - {body}", response.StatusCode, errorContent);
                throw new Exception($"Jira create failed: {response.StatusCode}");
            }

            var json = await response.Content.ReadFromJsonAsync<JsonElement>();
            var key = json.GetProperty("key").GetString();
            var url = $"https://{_config["Jira:Url"]}/browse/{key}";

            return (key, url, "New");
        }

        public async Task<List<JiraTicketDto>> GetAllTicketsForProjectAsync(string projectKey)
        {
            var cloudId = _config["Jira:CloudId"];
            var urlBase = $"/ex/jira/{cloudId}/rest/api/3/search";
            var tickets = new List<JiraTicketDto>();

            int startAt = 0;
            const int maxResults = 50;

            while (true)
            {
                var url = $"{urlBase}?jql=project={projectKey}&startAt={startAt}&maxResults={maxResults}";
                var response = await _http.GetAsync(url);
                response.EnsureSuccessStatusCode();

                var json = await response.Content.ReadFromJsonAsync<JsonElement>();
                var issues = json.GetProperty("issues");

                foreach (var issue in issues.EnumerateArray())
                {
                    var key = issue.GetProperty("key").GetString();
                    var status = issue.GetProperty("fields").GetProperty("status").GetProperty("name").GetString();
                    var summary = issue.GetProperty("fields").GetProperty("summary").GetString();

                    tickets.Add(new JiraTicketDto
                    {
                        Key = key,
                        Status = status,
                        Summary = summary,
                        JiraDescription = issue.GetProperty("fields").TryGetProperty("description", out var descNode) ? JsonSerializer.Serialize(descNode) : string.Empty,
                        JiraPriority = issue.GetProperty("fields").TryGetProperty("priority", out var priNode) ? priNode.GetProperty("name").GetString() : "Medium",
                        Url = $"https://{_config["Jira:Url"]}/browse/{key}"
                    });
                }

                if (issues.GetArrayLength() < maxResults)
                    break;

                startAt += maxResults;
            }

            return tickets;
        }

        private string SanitizeForAdf(string input)
        {
            if (string.IsNullOrWhiteSpace(input))
                return "[No AI analysis available]";

            return input
                .Replace("\r", "")
                .Replace("\n", " ")
                .Replace("\t", " ")
                .Replace("\"", "'")
                .Trim();
        }
    }
}