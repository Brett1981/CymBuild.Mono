using Microsoft.AspNetCore.Mvc;
using PostCodeLookup.DTOs;
using PostCodeLookup.Services;

/*
 * CombinedAddressLookupController.cs
 *
 * This controller acts as the main endpoint for address lookups, utilizing both postcode and address search functionalities.
 * When a user submits a lookup request via the LookForAddress endpoint, the system first attempts to find addresses using the postcode.
 * If no results are found (e.g., a 404 or empty response), it falls back to using the address lookup instead.
 *
 * This approach ensures a more flexible and fault-tolerant way of resolving user-submitted address data.
 */

namespace PostCodeLookup.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CombinedAddressLookupController : ControllerBase
    {
        private readonly IdealPostcodeLookupService _lookupService;
        private readonly ILogger<CombinedAddressLookupController> _logger;

        public CombinedAddressLookupController(
            IdealPostcodeLookupService lookupService,
            ILogger<CombinedAddressLookupController> logger)
        {
            _lookupService = lookupService;
            _logger = logger;
        }

        /// <summary> Main endpoint for address lookups using Ideal Postcode services. Attempts to
        /// look up address suggestions based on a given input string. First tries to match a
        /// postcode directly. If no match is found, it falls back to a general address suggestion.
        /// If suggestions are returned, a placeholder ("Address Not Found") is also appended to
        /// give the user the option to update manually. Suggestions returned from here must be
        /// resolved via the /api/AddressLookup/ResolveAddress endpoint. </summary> <param
        /// name="req">The user's address input request (address string, context, and API override
        /// flag).</param> <returns> 200 OK with one or more address/postcode suggestions, 404
        /// NotFound with only a placeholder if no matches were found, 400 BadRequest if input is
        /// invalid, 500 Internal Serv
        [HttpPost("LookForAddress")]
        public async Task<IActionResult> LookForAddress([FromBody] AddressRequest req)
        {
            _logger.LogInformation($"api/AddressLookup/LookupAddresses has been hit with params [ID : {req.Address}, Context: {req.Context}, ForceAPI: {req.ForceApi} ]");

            if (req == null || string.IsNullOrWhiteSpace(req.Address))
            {
                return BadRequest(new { error = "An address is required!." });
            }

            // 10.2 Extract the user’s identity (once AAD is set up). For now, it may be null.
            var userEmail = User.Identity?.Name ?? "Unknown";
            _logger.LogInformation($"User X requested address {req.Address} (forceApi={req.ForceApi})",
                userEmail, req.Address, req.ForceApi);

            try
            {
                var addressNotFound = "Address Not Found, Update Addresses?";

                //Try to hit the endpoint for postcode first.
                IReadOnlyList<PostcodeAddressResponse> postcodeResults = await _lookupService.LookupAddressesByPostcodeAsync(req.Address, req.ForceApi);

                //If there are no results, we should receive a response where the "FormattedAddress" field is set to "Address Not Found, Update Addresses?".
                if (postcodeResults[0].FormattedAddress == addressNotFound)
                {
                    //Now, try the endpoint for address lookup.
                    IReadOnlyList<AddressResponse> res = await _lookupService.LookupAddressesAsync(req.Address, req.Context, req.ForceApi);

                    //Add "Address not found" as an option.
                    var resAsList = res.ToList();
                    resAsList.Add(_lookupService.GetPlaceHolderForAddress());

                    //One item -> "AddressNotFound" (404)
                    if (resAsList.Count == 1)
                        return NotFound((IReadOnlyList<AddressResponse>)resAsList);

                    _logger.LogInformation($"[LookForAddress endpoint] -> [Returning Address Suggestions]");

                    //More than one item (200)
                    return Ok((IReadOnlyList<AddressResponse>)resAsList);
                }

                //We are returning a postcode suggestion - ensure the "address not found" option is added
                //so that the user can amend the address manually if needed.
                _logger.LogInformation($"[LookForAddress endpoint] -> [Returning Postcode Suggestions]");
                //Add "Address not found as a valid option"
                var postCodeResultsAsList = postcodeResults.ToList();
                postCodeResultsAsList.Add(_lookupService.GetAddressNotFoundPlaceholder(req.Address));

                //Return postcode suggestion if everything went ok.
                return Ok((IReadOnlyList<PostcodeAddressResponse>)postCodeResultsAsList);
            }
            catch (Exception ex)
            {
                _logger.LogError($"There was a problem returning address for search:  {req.Address} ");
                //Return status code of 500 to indicate that something went wrong with the request.
                return StatusCode(500, new { error = $"Internal server error: {ex.Message}" });
            }
        }
    }
}