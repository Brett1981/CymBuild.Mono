using CymBuild_Outlook_API.Data;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CymBuild_Outlook_API.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [EnableCors("AddinCors")]
    public class RecordSearchController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly LoggingHelper _loggingHelper; // Declare the logger

        public RecordSearchController(AppDbContext context, LoggingHelper loggingHelper) // Inject the logger
        {
            _context = context;
            _loggingHelper = loggingHelper; // Assign the logger
        }

        // GET: api/RecordSearch
        [HttpGet]
        public async Task<IActionResult> Search(
            [FromQuery] int userId,
            [FromQuery] string searchString = "", // Default to empty string if not provided
            [FromQuery] Guid entityTypeGuid = default(Guid), // Default to empty Guid if not provided
            [FromQuery] string toAddressesCSV = "", // Default to empty string if not provided
            [FromQuery] string fromAddress = "", // Default to empty string if not provided
            [FromQuery] string subject = "") // Default to empty string if not provided
        {
            _loggingHelper.LogInfo($"Search called with parameters: userId={userId}, searchString={searchString}, entityTypeGuid={entityTypeGuid}, toAddressesCSV={toAddressesCSV}, fromAddress={fromAddress}, subject={subject}", "Search()");

            try
            {
                var results = _context.SearchRecords(userId, searchString, entityTypeGuid, toAddressesCSV, fromAddress, subject);

                // Asynchronous execution of the query
                var listResults = await results.ToListAsync();

                _loggingHelper.LogInfo($"Search completed successfully. Result count: {listResults.Count}", "Search()");

                return Ok(listResults);
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError($"Error occurred during search: ", ex, "Search()");
                return StatusCode(500, "Internal server error");
            }
        }
    }
}