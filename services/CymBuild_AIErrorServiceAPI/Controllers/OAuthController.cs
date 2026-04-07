using CymBuild_AIErrorServiceAPI.Services;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace CymBuild_AIErrorServiceAPI.Controllers
{
    [ApiController]
    [Route("oauth")]
    public class OAuthController : ControllerBase
    {
        private readonly IConfiguration _config;
        private readonly IHttpClientFactory _httpFactory;
        private readonly JiraOAuthService _oauthService;

        public OAuthController(IConfiguration config, IHttpClientFactory httpFactory, JiraOAuthService oauthService)
        {
            _config = config;
            _httpFactory = httpFactory;
            _oauthService = oauthService;
        }

        [HttpGet("start")]
        public IActionResult Start()
        {
            var clientId = _config["Jira:ClientId"];
            var redirectUri = Uri.EscapeDataString("https://localhost:44353/oauth/callback");
            var scopes = Uri.EscapeDataString("read:jira-work write:jira-work manage:jira-project read:jira-user");

            var url = $"https://auth.atlassian.com/authorize?audience=api.atlassian.com&client_id={clientId}&scope={scopes}&redirect_uri={redirectUri}&response_type=code&prompt=consent";

            return Redirect(url);
        }

        [HttpGet("callback")]
        public async Task<IActionResult> Callback([FromQuery] string code)
        {
            var http = _httpFactory.CreateClient();
            var tokenResponse = await http.PostAsJsonAsync("https://auth.atlassian.com/oauth/token", new
            {
                grant_type = "authorization_code",
                client_id = _config["Jira:ClientId"],
                client_secret = _config["Jira:ClientSecret"],
                code,
                redirect_uri = "https://localhost:44353/oauth/callback"
            });

            var json = await tokenResponse.Content.ReadFromJsonAsync<JsonElement>();
            var token = json.GetProperty("access_token").GetString();
            var expiresIn = json.GetProperty("expires_in").GetInt32();

            // Cache in service
            var service = HttpContext.RequestServices.GetRequiredService<JiraOAuthService>();
            service.SetUserAccessToken(token, expiresIn);

            return Ok($"Access token response: {token}");
        }
    }
}