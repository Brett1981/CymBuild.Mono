// ==============================
// FILE: CymBuild_Outlook_API/Controllers/SuggestedFilingLocationsController.cs
// ==============================
using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_API.Helpers;
using CymBuild_Outlook_Common.Helpers;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;

namespace CymBuild_Outlook_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [EnableCors("AddinCors")]
    public class SuggestedFilingLocationsController : ControllerBase
    {
        private const int WindowMonths = 6;

        private readonly AppDbContext _context;
        private readonly LoggingHelper _loggingHelper;

        public SuggestedFilingLocationsController(AppDbContext context, LoggingHelper loggingHelper)
        {
            _context = context;
            _loggingHelper = loggingHelper;
        }

        // GET: api/SuggestedFilingLocations?targetObjectId=...&entityTypeId=...
        [HttpGet]
        public async Task<IActionResult> Get([FromQuery] long targetObjectId, [FromQuery] int entityTypeId)
        {
            var corr = GetCorrelationId();
            var sw = Stopwatch.StartNew();

            _loggingHelper.LogInfo($"[{corr}] SuggestedFilingLocations START targetObjectId={targetObjectId} entityTypeId={entityTypeId}", "Get(targetObjectId,entityTypeId)");

            try
            {
                if (targetObjectId <= 0 || entityTypeId <= 0)
                {
                    _loggingHelper.LogError($"[{corr}] SuggestedFilingLocations invalid request", new ArgumentException("targetObjectId/entityTypeId"), "Get(targetObjectId,entityTypeId)");
                    return BadRequest("targetObjectId and entityTypeId are required");
                }

                var windowStart = DateTime.UtcNow.AddMonths(-WindowMonths);

                var swDb = Stopwatch.StartNew();
                var rows = await _context.GetSuggestedFilingLocationsAsync(targetObjectId, entityTypeId, windowStart);
                swDb.Stop();

                var ranked = FolderSuggestionRanker.Rank(rows);

                _loggingHelper.LogInfo($"[{corr}] SuggestedFilingLocations DB OK rowCount={rows?.Count ?? 0} rankedCount={ranked.Count} DbElapsedMs={swDb.ElapsedMilliseconds}", "Get(targetObjectId,entityTypeId)");
                _loggingHelper.LogInfo($"[{corr}] SuggestedFilingLocations END ElapsedMs={sw.ElapsedMilliseconds}", "Get(targetObjectId,entityTypeId)");

                return Ok(ranked);
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError($"[{corr}] SuggestedFilingLocations ERROR ElapsedMs={sw.ElapsedMilliseconds}", ex, "Get(targetObjectId,entityTypeId)");
                return StatusCode(500, "Internal server error");
            }
        }

        private string GetCorrelationId()
        {
            // prefer add-in correlation if present
            if (Request.Headers.TryGetValue("X-Correlation-Id", out var v) && !string.IsNullOrWhiteSpace(v))
                return v.ToString();

            // fallback
            return $"api-{DateTime.UtcNow:HHmmss}-{Guid.NewGuid():N}".Substring(0, 24);
        }
    }
}
