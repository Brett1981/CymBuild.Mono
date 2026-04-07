using Microsoft.AspNetCore.Mvc;
using PostCodeLookup.DTOs;
using PostCodeLookup.Services;

namespace PostCodeLookup.Controllers
{
    /// <summary>
    /// Single controller for postcode lookup. Exposes POST /api/postcodelookup
    /// </summary>
   // [Authorize] // Requires a valid Azure AD token (placeholders for now).
    [ApiController]
    [Route("api/[controller]")]
    public class AddressLookupController : ControllerBase
    {
        private readonly IdealPostcodeLookupService _lookupService;
        private readonly ILogger<AddressLookupController> _logger;

        public AddressLookupController(
         IdealPostcodeLookupService lookupService,
         ILogger<AddressLookupController> logger)
        {
            _lookupService = lookupService;
            _logger = logger;
        }

        /// <summary>
        /// POST api/postcodelookup
        /// Body: { "postcode": "SW1A 2AA", "forceApi": false }
        /// Returns: 200 OK with JSON array of AddressResponse objects.
        /// </summary>
        [HttpPost("GetAddress")]
        public async Task<IActionResult> LookupAddresses([FromBody] AddressRequest request)
        {
            _logger.LogInformation($"api/AddressLookup/LookupAddresses has been hit with params [ID : {request.Address}, Context: {request.Context} ");
            // 10.1 Basic validation: ensure the postcode field is not empty
            if (request == null || string.IsNullOrWhiteSpace(request.Address))
            {
                return BadRequest(new { error = "Address is required." });
            }

            // 10.2 Extract the user’s identity (once AAD is set up). For now, it may be null.
            var userEmail = User.Identity?.Name ?? "Unknown";
            _logger.LogInformation($"User X requested address {request.Address} (forceApi={request.ForceApi})",
                userEmail, request.Address, request.ForceApi);

            try
            {
                // 10.3 Delegate to the service
                var results = await _lookupService.LookupAddressesAsync(request.Address, request.Context, request.ForceApi);
                return Ok(results); // returns 200 with List<AddressResponse> as JSON
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unhandled exception in LookupAddresses for {Postcode}", request.Address);
                // 10.4 Return generic 500 (in production you might provide more detail or a
                // ProblemDetails object)
                return StatusCode(500, new { error = "Internal server error." });
            }
        }

        [HttpPost("ResolveAddress")]
        public async Task<IActionResult> ResolveAddressById([FromBody] ResolveAddressRequest request)
        {
            _logger.LogInformation($"api/AddressLookup/ResolveAddress has been hit with params [ID : {request.ID}, Context: {request.Context} ");

            if (request == null || string.IsNullOrEmpty(request.ID))
            {
                return BadRequest(new { error = "ID of address is required." });
            }

            // 10.2 Extract the user’s identity (once AAD is set up). For now, it may be null.
            var userEmail = User.Identity?.Name ?? "Unknown";
            _logger.LogInformation($"User X requested to resolve address with ID of {request.ID})",
                userEmail, request.ID);

            try
            {
                // 10.3 Delegate to the service
                var results = await _lookupService.ResolveAddressByID(request.ID, request.Context);
                return Ok(results); // returns 200 with List<AddressResponse> as JSON
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unhandled exception in ResolveAddressById for {ID}", request.ID);
                // 10.4 Return generic 500 (in production you might provide more detail or a
                // ProblemDetails object)
                return StatusCode(500, new { error = $"Internal server error.{ex.Message}" });
            }
        }

        [HttpGet("ping")]
        public IActionResult Ping() => Ok("pong");
    }
}