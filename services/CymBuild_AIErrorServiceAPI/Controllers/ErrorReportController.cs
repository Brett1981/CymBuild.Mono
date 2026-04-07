using CymBuild_AIErrorServiceAPI.Dto;
using CymBuild_AIErrorServiceAPI.Models;
using CymBuild_AIErrorServiceAPI.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Cryptography;
using System.Text;
using Telerik.DataSource;
using Telerik.DataSource.Extensions;

namespace CymBuild_AIErrorServiceAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ErrorReportController : ControllerBase
    {
        private readonly AiAnalyzerService _analyzer;
        private readonly JiraTicketService _jira;
        private readonly AiErrorDbContext _db;
        private readonly IConfiguration _config;

        public ErrorReportController(AiAnalyzerService analyzer, JiraTicketService jira, AiErrorDbContext db, IConfiguration config)
        {
            _analyzer = analyzer;
            _jira = jira;
            _db = db;
            _config = config;
        }

        [HttpPost]
        public async Task<ActionResult<ErrorReportResponse>> ReportError([FromBody] ErrorReportRequest req)
        {
            var hash = Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(req.ErrorMessage + req.StackTrace)));

            var existing = await _db.AiErrorReports.FirstOrDefaultAsync(r => r.Hash == hash);
            if (existing != null)
            {
                return Ok(new ErrorReportResponse
                {
                    Hash = hash,
                    AiSummary = existing.AiAnalysis,
                    JiraDescription = existing.JiraDescription,
                    JiraTicketKey = existing.JiraTicketKey,
                    JiraUrl = existing.JiraUrl,
                    ErrorMessage = existing.ErrorMessage,
                    JiraStatus = existing.JiraStatus,
                    AlreadyExists = true
                });
            }

            string aiSummary;
            try
            {
                aiSummary = await _analyzer.AnalyzeAsync(req.ErrorMessage, req.StackTrace, req.ContextJson);
            }
            catch (Exception ex)
            {
                aiSummary = "[AI Analysis Failed] " + ex.Message;
                Console.WriteLine($"⚠️ BlueGen failed: {ex.Message}");
            }

            string ticketKey = "", ticketUrl = "", ticketStatus = "New";
            bool jiraFailed = false;
            if (_config.GetValue<bool>("Jira:Enabled"))
            {
                try
                {
                    (ticketKey, ticketUrl, ticketStatus) = await _jira.CreateTicketAsync(
                        $"[CB-AI-{hash.Substring(0, 6)}] {Truncate(req.ErrorMessage, 100)}",
                        $"{req.Description}",
                        $"{aiSummary}"
                    );
                }
                catch (Exception ex)
                {
                    jiraFailed = true;
                    Console.WriteLine($"⚠️ Jira ticket creation failed: {ex.Message}");
                }
            }

            var report = new AiErrorReport
            {
                Hash = hash,
                UserId = req.UserId,
                ErrorMessage = $"[CB-AI-{hash.Substring(0, 6)}] {Truncate(req.ErrorMessage, 100)}",
                StackTrace = req.StackTrace ?? "",
                ContextJson = req.ContextJson ?? "{}",
                AiAnalysis = aiSummary ?? "",
                JiraDescription = req.Description ?? "",
                CreatedUtc = DateTime.UtcNow,
                JiraTicketKey = ticketKey ?? "",
                JiraUrl = ticketUrl ?? "",
                JiraStatus = ticketStatus ?? "New",
                JiraPriority = "P3 - Medium",
                JiraTicketCreated = ticketKey != null,
                IsResolved = ticketStatus == "Resolved"
            };

            _db.AiErrorReports.Add(report);
            await _db.SaveChangesAsync();

            return Ok(new ErrorReportResponse
            {
                Hash = hash,
                AiSummary = aiSummary ?? "",
                JiraDescription = report.JiraDescription ?? "",
                JiraTicketKey = ticketKey,
                JiraUrl = ticketUrl,
                JiraStatus = ticketStatus,
                ErrorMessage = report.ErrorMessage,
                AlreadyExists = false,
                JiraError = jiraFailed ? "Jira ticket creation failed. Please retry later." : null
            });
        }

        [HttpPatch("{hash}/status")]
        public async Task<IActionResult> UpdateStatus(string hash, [FromBody] string status)
        {
            var report = await _db.AiErrorReports.FirstOrDefaultAsync(r => r.Hash == hash);
            if (report == null) return NotFound();

            report.JiraStatus = status;
            report.IsResolved = status == "Resolved";
            await _db.SaveChangesAsync();
            return NoContent();
        }

        [HttpGet("all")]
        public async Task<ActionResult<List<AiErrorReport>>> GetAll()
        {
            return await _db.AiErrorReports
                .OrderByDescending(e => e.CreatedUtc)
                .ToListAsync();
        }

        [HttpPost("refresh-statuses")]
        public async Task<IActionResult> RefreshStatuses()
        {
            var reportsWithTickets = await _db.AiErrorReports
                .Where(r => r.JiraTicketCreated && !string.IsNullOrEmpty(r.JiraTicketKey))
                .ToListAsync();

            foreach (var report in reportsWithTickets)
            {
                try
                {
                    var (newStatus, _, _, _) = await _jira.GetTicketDetailsAsync(report.JiraTicketKey);
                    if (!string.Equals(report.JiraStatus, newStatus, StringComparison.OrdinalIgnoreCase))
                    {
                        report.JiraStatus = newStatus;
                        report.IsResolved = newStatus.Equals("Resolved", StringComparison.OrdinalIgnoreCase);
                        report.JiraLastSyncedUtc = DateTime.UtcNow;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"❌ Failed to get Jira status for {report.JiraTicketKey}: {ex.Message}");
                }
            }

            await _db.SaveChangesAsync();
            return Ok();
        }

        [HttpPost("upload-file")]
        public async Task<ActionResult<ErrorReportResponse>> UploadFile([FromForm] FileUploadForm form, [FromForm] string description)
        {
            var file = form.File;
            var message = form.Message;
            if (file == null || file.Length == 0)
                return BadRequest("No file uploaded.");

            if (string.IsNullOrWhiteSpace(description))
                description = "Uploaded file";

            string hash;
            byte[] fileBytes;

            using (var ms = new MemoryStream())
            {
                await file.CopyToAsync(ms);
                fileBytes = ms.ToArray();
                var combinedBytes = Encoding.UTF8.GetBytes(description)
                    .Concat(fileBytes).ToArray();

                hash = Convert.ToBase64String(SHA256.HashData(combinedBytes));
            }

            var existing = await _db.AiErrorReports.FirstOrDefaultAsync(r => r.Hash == hash);
            if (existing != null)
            {
                return Ok(new ErrorReportResponse
                {
                    Hash = existing.Hash,
                    AiSummary = existing.AiAnalysis,
                    JiraDescription = existing.JiraDescription,
                    JiraTicketKey = existing.JiraTicketKey,
                    JiraUrl = existing.JiraUrl,
                    JiraStatus = existing.JiraStatus,
                    AlreadyExists = true
                });
            }

            // Analyze with BlueGen
            string aiSummary;
            try
            {
                using var fileStream = new MemoryStream(fileBytes);
                aiSummary = await _analyzer.AnalyzeFileAsync(file.FileName, fileStream, description);
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"BlueGen analysis failed: {ex.Message}");
            }

            // Create Jira Ticket (if enabled)
            string ticketKey = null, ticketUrl = null, ticketStatus = null;
            if (_config.GetValue<bool>("Jira:Enabled"))
            {
                var summary = $"[CB-AI-{hash.Substring(0, 6)}] 📎 {Truncate(file.FileName, 80)}";
                var descriptionText = $"{description}";

                (ticketKey, ticketUrl, ticketStatus) = await _jira.CreateTicketAsync(summary, descriptionText, aiSummary);
            }

            // Save to DB
            var report = new AiErrorReport
            {
                Hash = hash,
                UserId = "UploadedFile",
                ErrorMessage = $"📎 File Upload: {file.FileName}",
                StackTrace = "N/A",
                ContextJson = description,
                AiAnalysis = aiSummary,
                JiraDescription = description,
                CreatedUtc = DateTime.UtcNow,
                JiraTicketKey = ticketKey,
                JiraUrl = ticketUrl,
                JiraStatus = ticketStatus,
                JiraTicketCreated = ticketKey != null,
                IsResolved = ticketStatus == "Resolved"
            };

            _db.AiErrorReports.Add(report);
            await _db.SaveChangesAsync();

            return Ok(new ErrorReportResponse
            {
                Hash = hash,
                AiSummary = aiSummary,
                JiraDescription = description,
                JiraTicketKey = ticketKey,
                JiraUrl = ticketUrl,
                JiraStatus = ticketStatus,
                AlreadyExists = false
            });
        }

        public record UpdateStatusRequest(string Hash, string NewStatus);

        [HttpPost("retry/{hash}")]
        public async Task<IActionResult> RetryJira(string hash)
        {
            var report = await _db.AiErrorReports.FirstOrDefaultAsync(r => r.Hash == hash);
            if (report == null) return NotFound();

            if (!_config.GetValue<bool>("Jira:Enabled"))
                return BadRequest("Jira sync is disabled.");

            string summary = $"[CB-AI-{hash.Substring(0, 6)}] {Truncate(report.ErrorMessage, 100)}";
            string description = report.JiraDescription ?? "No description available";
            string analysis = report.AiAnalysis ?? "No AI analysis available";

            try
            {
                var (key, url, status) = await _jira.CreateTicketAsync(summary, description, analysis);

                report.JiraTicketKey = key;
                report.JiraUrl = url;
                report.JiraStatus = status;
                report.JiraTicketCreated = true;
                report.JiraLastSyncedUtc = DateTime.UtcNow;

                await _db.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ Jira ticket creation failed on retry: {ex.Message}");
                return StatusCode(500, $"Jira error: {ex.Message}");
            }
            return Ok();
        }

        [HttpPost("sync-jira")]
        public async Task<IActionResult> SyncJiraTickets()
        {
            var projectKey = _config["Jira:ProjectKey"];
            var now = DateTime.UtcNow;
            var log = new JiraSyncLog
            {
                StartedUtc = now
            };

            int inserted = 0, updated = 0, unchanged = 0;

            try
            {
                var tickets = await _jira.GetAllTicketsForProjectAsync(projectKey);

                var existingKeys = await _db.AiErrorReports
                    .Where(r => r.JiraTicketCreated && r.JiraTicketKey != null)
                    .Select(r => r.JiraTicketKey)
                    .ToListAsync();

                foreach (var ticket in tickets)
                {
                    var existing = await _db.AiErrorReports.FirstOrDefaultAsync(r => r.JiraTicketKey == ticket.Key);
                    var (status, description, priority, aiAnalsis) = await _jira.GetTicketDetailsAsync(ticket.Key);

                    if (existing != null)
                    {
                        if (existing.JiraStatus != status || string.IsNullOrWhiteSpace(existing.JiraDescription) || existing.AiAnalysis != aiAnalsis)
                        {
                            existing.JiraStatus = status;
                            existing.JiraPriority = priority;
                            existing.JiraLastSyncedUtc = now;
                            existing.JiraDescription = description ?? "";
                            existing.AiAnalysis = aiAnalsis ?? "[Imported from Jira]";
                            existing.IsResolved = status == "Resolved";
                            updated++;
                        }
                        else
                        {
                            unchanged++;
                        }
                    }
                    else
                    {
                        _db.AiErrorReports.Add(new AiErrorReport
                        {
                            Hash = Guid.NewGuid().ToString(),
                            UserId = "JiraSync",
                            ErrorMessage = ticket.Summary,
                            StackTrace = "Imported from Jira",
                            ContextJson = "{}",
                            AiAnalysis = "[Imported from Jira]",
                            JiraDescription = description ?? "",
                            JiraPriority = priority,
                            CreatedUtc = now,
                            JiraTicketKey = ticket.Key,
                            JiraUrl = ticket.Url,
                            JiraStatus = status,
                            JiraTicketCreated = true,
                            IsResolved = status == "Resolved",
                            JiraLastSyncedUtc = now
                        });
                        inserted++;
                    }
                }

                var currentKeys = tickets.Select(t => t.Key).ToHashSet();
                var toDelete = await _db.AiErrorReports
                    .Where(r => r.JiraTicketCreated && !currentKeys.Contains(r.JiraTicketKey))
                    .ToListAsync();

                _db.AiErrorReports.RemoveRange(toDelete);

                await _db.SaveChangesAsync();

                // 🧠 Log success
                log.EndedUtc = DateTime.UtcNow;
                log.Success = true;
                log.Message = $"Inserted: {inserted}, Updated: {updated}, Unchanged: {unchanged}, Deleted: {toDelete.Count}";
            }
            catch (Exception ex)
            {
                log.EndedUtc = DateTime.UtcNow;
                log.Success = false;
                log.Message = $"Manual Jira sync failed: {ex.Message}";
            }

            _db.JiraSyncLogs.Add(log);
            await _db.SaveChangesAsync();

            return Ok(new
            {
                inserted,
                updated,
                unchanged,
                deleted = log.Message?.Split("Deleted: ").LastOrDefault() ?? "0"
            });
        }

        [HttpGet("jira-logs")]
        public async Task<ActionResult<List<JiraSyncLogDto>>> GetJiraLogs()
        {
            var logs = await _db.JiraSyncLogs
                .OrderByDescending(l => l.StartedUtc)
                .Select(l => new JiraSyncLogDto
                {
                    TimeStartedUtc = l.StartedUtc,
                    TimeEndedUtc = l.EndedUtc,
                    Success = l.Success,
                    Message = l.Message
                })
                .ToListAsync();

            return Ok(logs);
        }

        [HttpGet("status/{ticketKey}")]
        public async Task<ActionResult<AiStatusDto>> GetStatus(string ticketKey)
        {
            var report = await _db.AiErrorReports.FirstOrDefaultAsync(x => x.JiraTicketKey == ticketKey);
            if (report == null) return NotFound();

            if (report.JiraLastSyncedUtc.HasValue && (DateTime.UtcNow - report.JiraLastSyncedUtc.Value).TotalHours < 12)
            {
                return Ok(new AiStatusDto
                {
                    JiraStatus = report.JiraStatus,
                    JiraPriority = report.JiraPriority,
                    JiraDescription = report.JiraDescription,
                    AIAnalysis = report.AiAnalysis,
                    JiraLastSyncedUtc = report.JiraLastSyncedUtc
                });
            }

            try
            {
                var (status, description, priority, aiAnalsis) = await _jira.GetTicketDetailsAsync(ticketKey);
                report.JiraStatus = status;
                report.JiraPriority = priority;
                report.JiraDescription = description;
                report.AiAnalysis = aiAnalsis ?? "[Imported from Jira]";
                report.JiraLastSyncedUtc = DateTime.UtcNow;
                await _db.SaveChangesAsync();

                return Ok(new AiStatusDto
                {
                    JiraStatus = status,
                    JiraPriority = priority,
                    JiraDescription = description,
                    AIAnalysis = aiAnalsis ?? "[Imported from Jira]",
                    JiraLastSyncedUtc = report.JiraLastSyncedUtc
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Error syncing Jira ticket: {ex.Message}");
            }
        }

        [HttpGet("paged")]
        public async Task<ActionResult<PagedResult<AiErrorReport>>> GetPaged([FromQuery] int Skip = 0, [FromQuery] int Take = 20)
        {
            var total = await _db.AiErrorReports.CountAsync();

            var items = await _db.AiErrorReports
                .OrderByDescending(r => r.CreatedUtc)
                .Skip(Skip)
                .Take(Take)
                .ToListAsync();

            return Ok(new PagedResult<AiErrorReport> { Items = items, TotalCount = total });
        }

        [HttpPost("paged-source")]
        public async Task<ActionResult<DataSourceResult<AiErrorReport>>> GetPagedFromSource([FromBody] DataSourceRequest request)
        {
            var query = _db.AiErrorReports
                .OrderByDescending(r => r.CreatedUtc)
                .Select(e => new AiErrorReport
                {
                    Hash = e.Hash,
                    UserId = e.UserId,
                    AiAnalysis = e.AiAnalysis,
                    JiraTicketKey = e.JiraTicketKey,
                    JiraUrl = e.JiraUrl,
                    JiraStatus = e.JiraStatus,
                    JiraPriority = e.JiraPriority,
                    JiraLastSyncedUtc = e.JiraLastSyncedUtc,
                    ErrorMessage = e.ErrorMessage,
                    StackTrace = e.StackTrace,
                    ContextJson = e.ContextJson,
                    CreatedUtc = e.CreatedUtc
                });

            var result = await query.ToDataSourceResultAsync(request);

            return Ok(new DataSourceResult<AiErrorReport>
            {
                Data = result.Data.Cast<AiErrorReport>(),
                Total = result.Total
            });
        }

        private static string Truncate(string text, int maxLength) =>
            string.IsNullOrWhiteSpace(text) ? "" :
            text.Length <= maxLength ? text : text.Substring(0, maxLength - 3) + "...";
    }
}