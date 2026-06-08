using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_API.Models;
using CymBuild_Outlook_API.Services;
using CymBuild_Outlook_Common.Helpers;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Graph;
using Microsoft.Graph.Models;
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
        private readonly AppDbContext _context;
      

        public UserSettingsController(
            IMSGraphBase graphBaseService,
            IConfiguration configuration,
            LoggingHelper loggingHelper,
            AppDbContext context
            )
        {
            _graphBaseService = graphBaseService;
            _configuration = configuration;
            _loggingHelper = loggingHelper;
            _context = context;
            
        }

        // GET: /api/UserSettings
        [HttpGet]
        public async Task<ActionResult<Models.UserSettings>> Get()
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

                var email = Request.Headers["X-User-Email"].ToString();

                _loggingHelper.LogInfo($"[{corr}] Get UserSettings", $"Extracting email address => {email}");

                var settings = await GetUserSettingsFromGraphAsync(email);

                _loggingHelper.LogInfo($"[{corr}] Settings -> [MoveToCymBuildFiled] : {settings.MoveToCymBuildFiled}, [ExtractAttachments] : {settings.ExtractAttachments} ", "UserSettingsController.Get()");

                _loggingHelper.LogInfo($"[{corr}] Get UserSettings END ", "UserSettingsController.Get()");
                return Ok(settings);
            }
            catch (ServiceException ex)
            {
                _loggingHelper.LogError($"[{corr}] Get UserSettings  ERROR", ex, "UserSettingsController.Get()");
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
        public async Task<IActionResult> Post([FromBody] UserSettingsRequest settings)
        {
            var corr = Request.Headers.TryGetValue("X-Correlation-Id", out var v) ? v.ToString() : $"settings-{Guid.NewGuid():N}".Substring(0, 18);
            if (User?.Identity?.IsAuthenticated != true)
            {
                _loggingHelper.LogWarning($"[{corr}] Save UserSettings UNAUTHENTICATED => 401", "UserSettingsController.Post()");
                return Unauthorized();
            }
            try
            {
                _loggingHelper.LogInfo($"[{corr}] Save UserSettings START", "UserSettingsController.Post()");

                await SaveUserSettingsToGraphAsync(settings ?? new UserSettingsRequest());

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

     
        private async Task<Models.UserSettings> GetUserSettingsFromGraphAsync(string email)
        {

            // default settings if key missing or graph returns nothing
            var defaults = new Models.UserSettings();

            var settings = await _context.GetUserSettings(email);

            if (settings != null) 
            {
                _loggingHelper.LogInfo($"GetUserSettingsFromGraphAsync() => settings: {JsonConvert.SerializeObject(settings)}");
                return settings;
            }
            else
            {
                return defaults;
            }
        }


        private async Task SaveUserSettingsToGraphAsync(UserSettingsRequest settings)
        {
            string userEmail = settings.UserId;

            _loggingHelper.LogInfo($"User Email : {userEmail}");

            if (string.IsNullOrWhiteSpace(userEmail))
                throw new MissingFieldException("Payload was missing the User ID.");

            var settingsToSave = new
            {
                settings.MoveToCymBuildFiled,
                settings.ExtractAttachments
            };

            var json = JsonConvert.SerializeObject(settingsToSave);

            _loggingHelper.LogInfo($"JSON = {json}");

            int res = await _context.UpsertOutlookSettings(json, userEmail);

            _loggingHelper.LogInfo($"res = {res}");
        }
    }
}
