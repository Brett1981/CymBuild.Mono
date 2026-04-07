using Microsoft.AspNetCore.Mvc;

namespace Concursus.API.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class ConfigController : ControllerBase
    {
        private readonly IConfiguration _configuration;

        public ConfigController(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        [HttpGet("api-url")]
        public IActionResult GetApiUrl()
        {
            var apiUrl = _configuration.GetValue<string>("Kestrel:Endpoints:Https:Url");
            return Ok(new { ApiUrl = apiUrl });
        }
    }
}