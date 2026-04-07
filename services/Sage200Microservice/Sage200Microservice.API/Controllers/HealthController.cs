using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Sage200Microservice.Data;

namespace Sage200Microservice.API.Controllers
{
    /// <summary>
    /// Controller for checking the health of the microservice
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Produces("application/json")]
    public class HealthController : ControllerBase
    {
        private readonly ApplicationContext _context;

        /// <summary>
        /// Initializes a new instance of the HealthController
        /// </summary>
        /// <param name="context"> The database context </param>
        public HealthController(ApplicationContext context)
        {
            _context = context;
        }

        /// <summary>
        /// Gets the health status of the microservice
        /// </summary>
        /// <returns> The health status </returns>
        /// <response code="200"> Returns the health status </response>
        /// <response code="500"> If there was an error checking the health status </response>
        [HttpGet]
        [ProducesResponseType(typeof(HealthStatus), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(HealthStatus), StatusCodes.Status500InternalServerError)]
        public async Task<ActionResult<HealthStatus>> Get()
        {
            try
            {
                // Check database connectivity
                var canConnect = await _context.Database.CanConnectAsync();

                // Check if migrations are applied
                var pendingMigrations = await _context.Database.GetPendingMigrationsAsync();
                var hasPendingMigrations = pendingMigrations.Any();

                return Ok(new HealthStatus
                {
                    Status = "Healthy",
                    DatabaseConnected = canConnect,
                    HasPendingMigrations = hasPendingMigrations,
                    Timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new HealthStatus
                {
                    Status = "Unhealthy",
                    DatabaseConnected = false,
                    ErrorMessage = ex.Message,
                    Timestamp = DateTime.UtcNow
                });
            }
        }
    }

    /// <summary>
    /// Response model for health status
    /// </summary>
    public class HealthStatus
    {
        /// <summary>
        /// The overall status of the microservice
        /// </summary>
        /// <example> Healthy </example>
        public string Status { get; set; }

        /// <summary>
        /// Indicates whether the database connection is working
        /// </summary>
        public bool DatabaseConnected { get; set; }

        /// <summary>
        /// Indicates whether there are pending database migrations
        /// </summary>
        public bool HasPendingMigrations { get; set; }

        /// <summary>
        /// The error message if the status is unhealthy
        /// </summary>
        public string ErrorMessage { get; set; }

        /// <summary>
        /// The timestamp of the health check
        /// </summary>
        public DateTime Timestamp { get; set; }
    }
}