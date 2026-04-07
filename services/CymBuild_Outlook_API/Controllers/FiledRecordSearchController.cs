// ==============================
// FILE: CymBuild_Outlook_API/Controllers/FiledRecordSearchController.cs
// ==============================
using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_Common.Helpers;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;

namespace CymBuild_Outlook_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [EnableCors("AddinCors")]
    public class FiledRecordSearchController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly LoggingHelper _loggingHelper;

        public FiledRecordSearchController(AppDbContext context, LoggingHelper loggingHelper)
        {
            _context = context;
            _loggingHelper = loggingHelper;
        }

        // GET: api/FiledRecordSearch?messageId=...
        [HttpGet]
        public async Task<IActionResult> Search([FromQuery] string messageId)
        {
            var corr = GetCorrelationId();
            var sw = Stopwatch.StartNew();

            var msgHash = Hash10(messageId);
            var msgLen = messageId?.Length ?? 0;

            _loggingHelper.LogInfo($"[{corr}] FiledRecordSearch START messageIdLen={msgLen} messageIdHash={msgHash}", "Search(messageId)");

            try
            {
                if (string.IsNullOrWhiteSpace(messageId))
                {
                    _loggingHelper.LogError($"[{corr}] FiledRecordSearch invalid request: messageId empty", new ArgumentException("messageId"), "Search(messageId)");
                    return BadRequest("messageId is required");
                }

                var swDb = Stopwatch.StartNew();
                var results = await _context.SearchFiledRecordsAsync(messageId);
                swDb.Stop();

                _loggingHelper.LogInfo($"[{corr}] FiledRecordSearch DB OK resultCount={results?.Count ?? 0} DbElapsedMs={swDb.ElapsedMilliseconds}", "Search(messageId)");

                _loggingHelper.LogInfo($"[{corr}] FiledRecordSearch END ElapsedMs={sw.ElapsedMilliseconds}", "Search(messageId)");
                return Ok(results);
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError($"[{corr}] FiledRecordSearch ERROR ElapsedMs={sw.ElapsedMilliseconds} messageIdLen={msgLen} messageIdHash={msgHash}", ex, "Search(messageId)");
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

        private static string Hash10(string? s)
        {
            if (string.IsNullOrEmpty(s)) return "(empty)";
            using var sha = SHA256.Create();
            var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(s));
            return Convert.ToHexString(bytes).Substring(0, 10).ToLowerInvariant();
        }
    }
}
