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
    public class PostcodeLookupController : ControllerBase
    {
        private readonly IdealPostcodeLookupService _lookupService;
        private readonly ILogger<PostcodeLookupController> _logger;

        public PostcodeLookupController(
            IdealPostcodeLookupService lookupService,
            ILogger<PostcodeLookupController> logger)
        {
            _lookupService = lookupService;
            _logger = logger;
        }

        /// <summary>
        /// POST api/postcodelookup
        /// Body: { "postcode": "SW1A 2AA", "forceApi": false }
        /// Returns: 200 OK with JSON array of AddressResponse objects.
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> LookupAddresses([FromBody] PostcodeRequest request)
        {
            // 10.1 Basic validation: ensure the postcode field is not empty
            if (request == null || string.IsNullOrWhiteSpace(request.Postcode))
            {
                return BadRequest(new { error = "Address is required." });
            }

            // 10.2 Extract the user’s identity (once AAD is set up). For now, it may be null.
            var userEmail = User.Identity?.Name ?? "Unknown";
            _logger.LogInformation("User {UserEmail} requested address {Address} (forceApi={ForceApi})",
                userEmail, request.Postcode, request.ForceApi);

            try
            {
                var addressNotFound = "Address Not Found, Update Addresses?";
                // 10.3 Delegate to the service
                var results = await _lookupService.LookupAddressesByPostcodeAsync(request.Postcode, request.ForceApi);

                //Check if we are returning type "PlaceholderForPostcode"
                if (results[0].FormattedAddress == addressNotFound)
                {
                    //Return 404
                    return NotFound(results);
                }
                else
                {
                    //Return 200
                    return Ok(results); // returns 200 with List<AddressResponse> as JSON
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unhandled exception in LookupAddresses for {Postcode}", request.Postcode);
                // 10.4 Return generic 500 (in production you might provide more detail or a
                // ProblemDetails object)
                return StatusCode(500, new { error = "Internal server error." });
            }
        }
    }
}