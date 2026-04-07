using CymBuild_Outlook_API.Services;
using CymBuild_Outlook_Common.Helpers;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Graph;
using Newtonsoft.Json;

namespace CymBuild_Outlook_API.Controllers
{
    [Authorize(Policy = "AccessAsUserPolicy")]
    [Route("api/[controller]")]
    [ApiController]
    [EnableCors("AddinCors")]
    public class UserSettingsController : ControllerBase
    {
        private readonly IMSGraphBase _graphBaseService;
        private readonly IConfiguration _configuration;
        private readonly LoggingHelper _loggingHelper;

        public UserSettingsController(
            IMSGraphBase graphBaseService,
            IConfiguration configuration,
            LoggingHelper loggingHelper)
        {
            _graphBaseService = graphBaseService;
            _configuration = configuration;
            _loggingHelper = loggingHelper;
        }

        // GET: /api/UserSettings
        [HttpGet]
        public async Task<ActionResult<Dictionary<string, object>>> Get()
        {
            var corr = Request.Headers.TryGetValue("X-Correlation-Id", out var v) ? v.ToString() : $"settings-{Guid.NewGuid():N}".Substring(0, 18);
            if (User?.Identity?.IsAuthenticated != true)
            {
                _loggingHelper.LogWarning($"[{corr}] Get UserSettings UNAUTHENTICATED => 401", "UserSettingsController.Get()");
                return Unauthorized();
            }
            try
            {
                _loggingHelper.LogInfo($"[{corr}] Get UserSettings START", "UserSettingsController.Get()");

                var settings = await GetUserSettingsFromGraphAsync();

                _loggingHelper.LogInfo($"[{corr}] Get UserSettings END keys={settings.Count}", "UserSettingsController.Get()");
                return Ok(settings);
            }
            catch (ServiceException ex)
            {
                _loggingHelper.LogError($"[{corr}] Get UserSettings GRAPH ERROR", ex, "UserSettingsController.Get()");
                return StatusCode(500, ex.Message);
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError($"[{corr}] Get UserSettings ERROR", ex, "UserSettingsController.Get()");
                return StatusCode(500, "Internal server error");
            }
        }

        // POST: /api/UserSettings
        [HttpPost]
        public async Task<IActionResult> Post([FromBody] Dictionary<string, object> settings)
        {
            var corr = Request.Headers.TryGetValue("X-Correlation-Id", out var v) ? v.ToString() : $"settings-{Guid.NewGuid():N}".Substring(0, 18);
            if (User?.Identity?.IsAuthenticated != true)
            {
                _loggingHelper.LogWarning($"[{corr}] Save UserSettings UNAUTHENTICATED => 401", "UserSettingsController.Post()");
                return Unauthorized();
            }
            try
            {
                _loggingHelper.LogInfo($"[{corr}] Save UserSettings START keys={settings?.Count ?? 0}", "UserSettingsController.Post()");

                await SaveUserSettingsToGraphAsync(settings ?? new Dictionary<string, object>());

                _loggingHelper.LogInfo($"[{corr}] Save UserSettings END OK", "UserSettingsController.Post()");
                return Ok();
            }
            catch (ServiceException ex)
            {
                _loggingHelper.LogError($"[{corr}] Save UserSettings GRAPH ERROR", ex, "UserSettingsController.Post()");
                return StatusCode(500, ex.Message);
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError($"[{corr}] Save UserSettings ERROR", ex, "UserSettingsController.Post()");
                return StatusCode(500, "Internal server error");
            }
        }

        // -----------------------
        // Shared internal logic
        // -----------------------

        private string GetFiledRecordPropertyValue()
        {
            var tokenRequestConfig = _configuration.GetSection("FiledRecords");
            var values = tokenRequestConfig.GetValue<string[]>("PropertyValue");
            var v = values?.FirstOrDefault();
            return string.IsNullOrWhiteSpace(v) ? string.Empty : v;
        }

        private async Task<Dictionary<string, object>> GetUserSettingsFromGraphAsync()
        {
            var graphClient = _graphBaseService.GetGraphClient();
            var user = await graphClient.Me.GetAsync();

            var key = GetFiledRecordPropertyValue();

            // default settings if key missing or graph returns nothing
            var defaults = new Dictionary<string, object>
            {
                { "moveToCymBuildFiled", false },
                { "extractAttachments", false }
            };

            if (string.IsNullOrWhiteSpace(key) || user?.AdditionalData == null)
                return defaults;

            if (user.AdditionalData.TryGetValue(key, out var settingsObj) && settingsObj != null)
            {
                var json = settingsObj.ToString();
                if (!string.IsNullOrWhiteSpace(json))
                {
                    var settings = JsonConvert.DeserializeObject<Dictionary<string, object>>(json);
                    if (settings != null)
                        return settings;
                }
            }

            return defaults;
        }

        private async Task SaveUserSettingsToGraphAsync(Dictionary<string, object> settings)
        {
            var graphClient = _graphBaseService.GetGraphClient();
            var key = GetFiledRecordPropertyValue();

            if (string.IsNullOrWhiteSpace(key))
                throw new InvalidOperationException("FiledRecords:PropertyValue is not configured.");

            var json = JsonConvert.SerializeObject(settings);

            await graphClient.Me.PatchAsync(new Microsoft.Graph.Models.User
            {
                AdditionalData = new Dictionary<string, object>
                {
                    { key, json }
                }
            });
        }
    }
}
