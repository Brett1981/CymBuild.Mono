using Microsoft.AspNetCore.Mvc;
using Sage200Microservice.API.DTOs;
using Sage200Microservice.Data.Models;
using Sage200Microservice.Services.Interfaces;

namespace Sage200Microservice.API.Controllers
{
    /// <summary>
    /// Controller for audit logs
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    public class AuditLogsController : ControllerBase
    {
        private readonly ILogger<AuditLogsController> _logger;
        private readonly IAuditLogService _auditLogService;

        /// <summary>
        /// Initializes a new instance of the AuditLogsController class
        /// </summary>
        /// <param name="logger">          The logger </param>
        /// <param name="auditLogService"> The audit log service </param>
        public AuditLogsController(
            ILogger<AuditLogsController> logger,
            IAuditLogService auditLogService)
        {
            _logger = logger;
            _auditLogService = auditLogService;
        }

        /// <summary>
        /// Gets a filtered and paginated list of audit logs
        /// </summary>
        /// <param name="request"> The search request </param>
        /// <returns> A paginated list of audit logs </returns>
        [HttpGet]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<ActionResult<PaginatedResponse<AuditLogResponseDto>>> Search([FromQuery] AuditLogSearchRequestDto request)
        {
            try
            {
                var eventTypes = request.EventTypes?.Select(et => Enum.Parse<AuditEventType>(et)).ToList();
                var categories = request.Categories?.Select(c => Enum.Parse<AuditEventCategory>(c)).ToList();
                var severities = request.Severities?.Select(s => Enum.Parse<AuditEventSeverity>(s)).ToList();
                var statuses = request.Statuses?.Select(s => Enum.Parse<AuditEventStatus>(s)).ToList();

                var (logs, totalCount) = await _auditLogService.GetFilteredPagedAsync(
                    request.StartDate,
                    request.EndDate,
                    eventTypes,
                    categories,
                    severities,
                    statuses,
                    request.UserId,
                    request.ClientId,
                    request.IpAddress,
                    request.Resource,
                    request.Action,
                    request.CorrelationId,
                    request.SearchTerm,
                    request.Page,
                    request.PageSize,
                    request.SortBy ?? "Timestamp",
                    request.SortDirection ?? "desc");

                var items = logs.Select(log => MapToResponseDto(log)).ToList();

                var response = new PaginatedResponse<AuditLogResponseDto>
                {
                    Items = items,
                    TotalCount = totalCount,
                    Page = request.Page,
                    PageSize = request.PageSize,
                    TotalPages = (int)Math.Ceiling(totalCount / (double)request.PageSize)
                };

                return Ok(response);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error searching audit logs");
                return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An error occurred while searching audit logs" });
            }
        }

        /// <summary>
        /// Gets an audit log by ID
        /// </summary>
        /// <param name="id"> The audit log ID </param>
        /// <returns> The audit log </returns>
        [HttpGet("{id}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<AuditLogResponseDto>> GetById(long id)
        {
            try
            {
                var auditLog = await _auditLogService.GetByIdAsync(id);

                if (auditLog == null)
                {
                    return NotFound();
                }

                return Ok(MapToResponseDto(auditLog));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting audit log {Id}", id);
                return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An error occurred while getting the audit log" });
            }
        }

        /// <summary>
        /// Gets audit logs by correlation ID
        /// </summary>
        /// <param name="correlationId"> The correlation ID </param>
        /// <returns> A list of audit logs </returns>
        [HttpGet("correlation/{correlationId}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<ActionResult<List<AuditLogResponseDto>>> GetByCorrelationId(string correlationId)
        {
            try
            {
                var auditLogs = await _auditLogService.GetByCorrelationIdAsync(correlationId);
                var items = auditLogs.Select(log => MapToResponseDto(log)).ToList();
                return Ok(items);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting audit logs by correlation ID {CorrelationId}", correlationId);
                return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An error occurred while getting audit logs" });
            }
        }

        /// <summary>
        /// Gets audit logs for a specific resource
        /// </summary>
        /// <param name="resource">    The resource name </param>
        /// <param name="referenceId"> The reference ID </param>
        /// <returns> A list of audit logs </returns>
        [HttpGet("resource/{resource}/{referenceId}")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<ActionResult<List<AuditLogResponseDto>>> GetByResource(string resource, string referenceId)
        {
            try
            {
                var auditLogs = await _auditLogService.GetByResourceAsync(resource, referenceId);
                var items = auditLogs.Select(log => MapToResponseDto(log)).ToList();
                return Ok(items);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting audit logs for resource {Resource} with ID {ReferenceId}", resource, referenceId);
                return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An error occurred while getting audit logs" });
            }
        }

        /// <summary>
        /// Gets audit log statistics
        /// </summary>
        /// <param name="startDate"> The start date </param>
        /// <param name="endDate">   The end date </param>
        /// <returns> Audit log statistics </returns>
        [HttpGet("statistics")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<ActionResult<AuditLogStatisticsResponseDto>> GetStatistics([FromQuery] DateTime? startDate = null, [FromQuery] DateTime? endDate = null)
        {
            try
            {
                var statistics = await _auditLogService.GetStatisticsAsync(startDate, endDate);

                var response = new AuditLogStatisticsResponseDto
                {
                    TotalCount = statistics.TotalCount,
                    CountByEventType = statistics.CountByEventType.ToDictionary(
                        kvp => kvp.Key.ToString(),
                        kvp => kvp.Value),
                    CountByCategory = statistics.CountByCategory.ToDictionary(
                        kvp => kvp.Key.ToString(),
                        kvp => kvp.Value),
                    CountBySeverity = statistics.CountBySeverity.ToDictionary(
                        kvp => kvp.Key.ToString(),
                        kvp => kvp.Value),
                    CountByStatus = statistics.CountByStatus.ToDictionary(
                        kvp => kvp.Key.ToString(),
                        kvp => kvp.Value),
                    CountByResource = statistics.CountByResource,
                    CountByAction = statistics.CountByAction,
                    CountByClientId = statistics.CountByClientId,
                    CountByUserId = statistics.CountByUserId,
                    CountByIpAddress = statistics.CountByIpAddress,
                    CountByDay = statistics.CountByDay.ToDictionary(
                        kvp => kvp.Key.ToString("yyyy-MM-dd"),
                        kvp => kvp.Value)
                };

                return Ok(response);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting audit log statistics");
                return StatusCode(StatusCodes.Status500InternalServerError, new { message = "An error occurred while getting audit log statistics" });
            }
        }

        /// <summary>
        /// Maps an audit log to a response DTO
        /// </summary>
        /// <param name="auditLog"> The audit log </param>
        /// <returns> The audit log response DTO </returns>
        private AuditLogResponseDto MapToResponseDto(AuditLog auditLog)
        {
            return new AuditLogResponseDto
            {
                Id = auditLog.Id,
                Timestamp = auditLog.Timestamp,
                EventType = auditLog.EventType.ToString(),
                Category = auditLog.Category.ToString(),
                Severity = auditLog.Severity.ToString(),
                UserId = auditLog.UserId,
                ClientId = auditLog.ClientId,
                IpAddress = auditLog.IpAddress,
                Resource = auditLog.Resource,
                Action = auditLog.Action,
                Status = auditLog.Status.ToString(),
                Description = auditLog.Description,
                Details = auditLog.Details,
                CorrelationId = auditLog.CorrelationId,
                HttpMethod = auditLog.HttpMethod,
                UrlPath = auditLog.UrlPath,
                HttpStatusCode = auditLog.HttpStatusCode,
                DurationMs = auditLog.DurationMs,
                UserAgent = auditLog.UserAgent,
                ReferenceId = auditLog.ReferenceId,
                ReferenceName = auditLog.ReferenceName,
                PreviousState = auditLog.PreviousState,
                NewState = auditLog.NewState
            };
        }
    }
}