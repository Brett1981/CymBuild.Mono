using System.Net.Http.Headers;
using System.Text.Json;

namespace CymBuild_AIErrorServiceAPI.Services
{
    public class JiraOAuthService
    {
        private readonly IConfiguration _config;
        private readonly HttpClient _http;
        private string _cachedToken;
        private DateTime _tokenExpires = DateTime.MinValue;

        public JiraOAuthService(IConfiguration config, IHttpClientFactory factory)
        {
            _config = config;
            _http = factory.CreateClient();
        }

        private string _userAccessToken;
        private DateTime _userAccessTokenExpires = DateTime.MinValue;

        public void SetUserAccessToken(string token, int expiresInSeconds)
        {
            _userAccessToken = token;
            _userAccessTokenExpires = DateTime.UtcNow.AddSeconds(expiresInSeconds - 60);
        }

        public async Task<string> GetAccessTokenAsync()
        {
            if (!string.IsNullOrWhiteSpace(_userAccessToken) && DateTime.UtcNow < _userAccessTokenExpires)
                return _userAccessToken;

            throw new InvalidOperationException("No user-granted access token found. Please complete the authorization flow.");
        }

        public async Task<string> FetchCloudIdAsync(string accessToken)
        {
            using var client = new HttpClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

            var response = await client.GetAsync("https://api.atlassian.com/oauth/token/accessible-resources");
            if (!response.IsSuccessStatusCode)
                throw new InvalidOperationException("Failed to fetch Jira Cloud ID.");

            var json = await response.Content.ReadFromJsonAsync<JsonElement>();

            if (json.GetArrayLength() == 0)
                throw new InvalidOperationException("No accessible Jira cloud instances found for this token.");

            return json[0].GetProperty("id").GetString()!;
        }
    }
}