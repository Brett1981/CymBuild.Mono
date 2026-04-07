using CymBuild_AIErrorServiceAPI.Services;
using Microsoft.AspNetCore.Mvc;
using System.Net.Http.Headers;
using System.Text.Json;

namespace CymBuild_AIErrorServiceAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AiTaskController : ControllerBase
    {
        private readonly AiAnalyzerService _analyzer;
        private readonly IConfiguration _config;
        private readonly HttpClient _http;

        public AiTaskController(AiAnalyzerService analyzer, IConfiguration config, HttpClient http)
        {
            _analyzer = analyzer;
            _config = config;
            _http = http;
        }

        [HttpPost("ask")]
        public async Task<string> AskAsync(string prompt)
        {
            var token = await _analyzer.GetJwtTokenAsync();
            _http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

            var body = new
            {
                message = prompt
            };

            var response = await _http.PostAsJsonAsync(_config["BlueGen:Endpoint"], body);
            response.EnsureSuccessStatusCode();

            var json = await response.Content.ReadAsStringAsync();
            var data = JsonSerializer.Deserialize<JsonElement>(json);
            return data.GetProperty("ai_response").GetString() ?? "[No response]";
        }
    }
}