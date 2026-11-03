// ==============================
// FILE: CymBuild_Outlook_API/Controllers/FrequentFilingRecordsController.cs
// ==============================
using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_API.Helpers;
using CymBuild_Outlook_Common.Helpers;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;

namespace CymBuild_Outlook_API.Controllers
{
    /// <summary>
    /// Records the signed-in user files emails to most often, for the add-in's
    /// "Frequently filed" suggestions.
    /// </summary>
    [Authorize(Policy = "AccessAsUserPolicy")]
    [Route("api/[controller]")]
    [ApiController]
    [EnableCors("AddinCors")]
    public class FrequentFilingRecordsController : ControllerBase
    {
        private const int WindowMonths = 6;

        private readonly AppDbContext _context;
        private readonly LoggingHelper _loggingHelper;

        public FrequentFilingRecordsController(AppDbContext context, LoggingHelper loggingHelper)
        {
            _context = context;
            _loggingHelper = loggingHelper;
        }

        // GET: api/FrequentFilingRecords
        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var corr = GetCorrelationId();
            var sw = Stopwatch.StartNew();

            try
            {
                // Same identity SaveToSharePoint stores as the filing mailbox, so the counts line up.
                var mailbox = User?.GetPreferredUsername();

                if (string.IsNullOrWhiteSpace(mailbox))
                {
                    _loggingHelper.LogWarning($"[{corr}] FrequentFilingRecords no mailbox claim => 401", "Get()");
                    return Unauthorized();
                }

                _loggingHelper.LogInfo($"[{corr}] FrequentFilingRecords START", "Get()");

                var windowStart = DateTime.UtcNow.AddMonths(-WindowMonths);

                var swDb = Stopwatch.StartNew();
                var rows = await _context.GetFrequentFilingRecordsAsync(mailbox, windowStart);
                swDb.Stop();

                var ranked = FrequentFilingRecordRanker.Rank(rows);

                _loggingHelper.LogInfo($"[{corr}] FrequentFilingRecords DB OK rowCount={rows?.Count ?? 0} rankedCount={ranked.Count} DbElapsedMs={swDb.ElapsedMilliseconds}", "Get()");
                _loggingHelper.LogInfo($"[{corr}] FrequentFilingRecords END ElapsedMs={sw.ElapsedMilliseconds}", "Get()");

                return Ok(ranked);
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError($"[{corr}] FrequentFilingRecords ERROR ElapsedMs={sw.ElapsedMilliseconds}", ex, "Get()");
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
