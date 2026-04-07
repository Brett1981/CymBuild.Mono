using CymBuild_Outlook_API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;

namespace CymBuild_Outlook_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [EnableCors("AddinCors")]
    [Authorize(Policy = "AccessAsUserPolicy")]
    public class EmailDescriptionController : ControllerBase
    {
        private readonly BlueGenService _blueGenService;
        private readonly ILogger<EmailDescriptionController> _logger;

        public EmailDescriptionController(BlueGenService blueGenService, ILogger<EmailDescriptionController> logger)
        {
            _blueGenService = blueGenService;
            _logger = logger;
        }

        [HttpPost("generate")]
        public async Task<IActionResult> GenerateDescription([FromBody] GenerateDescriptionRequest request)
        {
            try
            {
                _logger.LogInformation("GenerateDescription called with subject length: {SubjectLength}, body length: {BodyLength}", 
                    request.Subject?.Length ?? 0, request.Body?.Length ?? 0);

                if (string.IsNullOrWhiteSpace(request.Subject) && string.IsNullOrWhiteSpace(request.Body))
                {
                    return BadRequest(new GenerateDescriptionResponse
                    {
                        Success = false,
                        Error = "Both subject and body cannot be empty"
                    });
                }

                var description = await _blueGenService.GenerateEmailDescriptionAsync(
                    request.Subject ?? string.Empty,
                    request.Body ?? string.Empty);

                _logger.LogInformation("Description generated successfully, length: {Length}", description.Length);

                return Ok(new GenerateDescriptionResponse
                {
                    Success = true,
                    Description = description
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error generating email description");
                return StatusCode(500, new GenerateDescriptionResponse
                {
                    Success = false,
                    Error = "Failed to generate description. Please try again."
                });
            }
        }
    }

    public class GenerateDescriptionRequest
    {
        public string? Subject { get; set; }
        public string? Body { get; set; }
    }

    public class GenerateDescriptionResponse
    {
        public bool Success { get; set; }
        public string? Description { get; set; }
        public string? Error { get; set; }
    }
}
