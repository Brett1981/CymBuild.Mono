using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PostCodeLookup.Data;
using PostCodeLookup.Data.Entities;
using PostCodeLookup.DTOs;
using PostCodeLookup.POCO;
using System.Text.Json;
using IdealApiAddressResolveResponse = PostCodeLookup.Integrations.IdealPostcode.IdealApiAddressResolveResponse;

//Class defintions - to do with request and response structures.
using IdealApiAddressResponse = PostCodeLookup.Integrations.IdealPostcode.IdealApiAddressResponse;
using IdealApiResponse = PostCodeLookup.Integrations.IdealPostcode.IdealApiResponse;

namespace PostCodeLookup.Services
{
    public class IdealPostcodeLookupService
    {
        private readonly PostcodeLookupDbContext _db;
        private readonly HttpClient _http;
        private readonly string _apiKey;
        private readonly ILogger<IdealPostcodeLookupService> _logger;

        public IdealPostcodeLookupService(
          PostcodeLookupDbContext db,
          IHttpClientFactory httpFactory,
          IOptions<PostcodeLookupOptions> opts,
          ILogger<IdealPostcodeLookupService> logger)
        {
            _db = db;
            _http = httpFactory.CreateClient("IdealPostcodesClient");
            _apiKey = opts.Value.IdealPostcodes.ApiKey;
            _logger = logger;
        }

        /// <summary>
        /// Function definition for when searching by a postcode.
        /// </summary>
        /// <param name="postcodeInput"> Postcode entered </param>
        /// <param name="forceApi">      Whether to fetch from the db or the API. </param>
        /// <returns> </returns>
        public async Task<IReadOnlyList<PostcodeAddressResponse>> LookupAddressesByPostcodeAsync(string postcodeInput, bool forceApi)
        {
            var postcode = NormalizePostcode(postcodeInput);
            if (string.IsNullOrEmpty(postcode))
                return Array.Empty<PostcodeAddressResponse>();

            // 1) Load or create the cache row
            var cache = await _db.PostcodeCaches
                                .Include(pc => pc.Addresses)
                                .FirstOrDefaultAsync(pc => pc.Postcode == postcode);

            if (cache != null && !forceApi && cache.Addresses.Any())
            {
                // Return cached DTOs immediately if not forcing an API call
                return cache.Addresses.Select(a => MapToDto(a, cache.Postcode)).ToList();
            }

            // 2) Fetch fresh from Ideal
            List<PostcodeAddressResponse> results;
            try
            {
                results = await FetchPostcodeFromIdealAsync(postcode);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ideal API failed for {Postcode}", postcode);
                // fallback: return existing cache or placeholder
                if (cache?.Addresses?.Any() ?? false)
                    return cache.Addresses.Select(a => MapToDto(a, cache.Postcode)).ToList();
                return new[] { PlaceholderForPostcode(postcode) };
            }

            // 3) Ensure we have a cache row
            if (cache == null)
            {
                cache = new PostcodeCache
                {
                    Postcode = postcode,
                    CreatedUtc = DateTime.UtcNow,
                    UpdatedUtc = DateTime.UtcNow,
                    LastFetchedUtc = DateTime.UtcNow,
                    CacheCount = results.Count
                };
                _db.PostcodeCaches.Add(cache);
            }
            else
            {
                cache.UpdatedUtc = cache.LastFetchedUtc = DateTime.UtcNow;
                cache.CacheCount = results.Count;
            }

            // 4) Build a lookup of existing AddressCache by UPRN
            var existingByUprn = cache.Addresses
                .Where(a => !string.IsNullOrWhiteSpace(a.Uprn))
                .ToDictionary(a => a.Uprn!, StringComparer.OrdinalIgnoreCase);

            // 5) Upsert each incoming DTO
            foreach (var dto in results)
            {
                if (!string.IsNullOrWhiteSpace(dto.Uprn)
                    && existingByUprn.TryGetValue(dto.Uprn!, out var entity))
                {
                    // --- UPDATE existing ---
                    entity.FormattedAddress = dto.FormattedAddress;
                    entity.Line1 = dto.Line1;
                    entity.Line2 = dto.Line2;
                    entity.Town = dto.Town;
                    entity.County = dto.County;
                    entity.LocalAuthority = dto.LocalAuthority;
                    entity.AuthorityCode = dto.AuthorityCode;
                    entity.Latitude = dto.Latitude;
                    entity.Longitude = dto.Longitude;
                    // Remove from dictionary so we know it’s been processed
                    existingByUprn.Remove(dto.Uprn!);
                }
                else
                {
                    // --- INSERT new ---
                    cache.Addresses.Add(new AddressCache
                    {
                        PostcodeCache = cache,
                        FormattedAddress = dto.FormattedAddress,
                        Line1 = dto.Line1,
                        Line2 = dto.Line2,
                        Town = dto.Town,
                        County = dto.County,
                        Country = dto.Country,
                        Uprn = dto.Uprn,
                        LocalAuthority = dto.LocalAuthority,
                        AuthorityCode = dto.AuthorityCode,
                        Latitude = dto.Latitude,
                        Longitude = dto.Longitude,
                        CreatedUtc = DateTime.UtcNow
                    });
                }
            }

            // 6) DELETE any addresses no longer returned by the API
            if (existingByUprn.Count > 0)
            {
                _db.AddressCaches.RemoveRange(existingByUprn.Values);
            }

            // 7) Persist everything
            await _db.SaveChangesAsync();

            // 8) Return the fresh DTO list
            return results;
        }

        /// <summary>
        /// Looks up a list of addresses based on a given address string and context. Attempts to
        /// fetch fresh results from the Ideal API.
        /// </summary>
        /// <param name="address">  The input address or search term. </param>
        /// <param name="context"> 
        /// The context or location filter for narrowing down the address search.
        /// </param>
        /// <param name="forceApi">
        /// Flag to indicate whether to force an API call (not currently used in this logic).
        /// </param>
        /// <returns>
        /// A read-only list of matched <see cref="AddressResponse"/> records. Returns an empty list
        /// if inputs are invalid or if an error occurs.
        /// </returns>
        public async Task<IReadOnlyList<AddressResponse>> LookupAddressesAsync(string address, string context, bool forceApi)
        {
            //TODO: Implement normalisation for addresses.
            if (string.IsNullOrEmpty(address))
                return Array.Empty<AddressResponse>();
            else if (string.IsNullOrEmpty(context))
                return Array.Empty<AddressResponse>();

            // 2) Fetch fresh from Ideal
            List<AddressResponse> results = new(new List<AddressResponse>());
            try
            {
                results = await FetchAddressFromIdealAsync(address, context);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ideal API failed for {Address}", address);
            }

            return results;
        }

        /// <summary>
        /// Resolves a given address suggestion with the provided ID.
        /// </summary>
        /// <param name="ID">      The ID field of the suggestion. </param>
        /// <param name="Context">
        /// The context (country) or location filter for narrowing down the address search.
        /// </param>
        /// <returns> A read-only list of matched <see cref="ResolveAddressResponse"/> records. </returns>
        public async Task<ResolveAddressResponse> ResolveAddressByID(string ID, string Context)
        {
            ResolveAddressResponse resolvedAddress = new ResolveAddressResponse { Id = ID, Country = Context };

            //TODO: Implement normalisation for addresses.
            if (string.IsNullOrEmpty(ID))
                return resolvedAddress;

            ResolveAddressResponse results = new();
            try
            {
                results = await ResolveAddressById(ID, Context);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ideal API failed to resolve address with ID ", ID);
            }

            return results;
        }

        /// <summary>
        /// Normalizes a UK postcode: trims, uppercases, and adds a space before last 3 chars.
        /// </summary>
        /// <param name="postcode"> The postcode </param>
        private static string NormalizePostcode(string postcode)
        {
            if (string.IsNullOrWhiteSpace(postcode))
                return string.Empty;

            var trimmed = postcode.Trim().ToUpperInvariant().Replace("\u00A0", " ");
            if (trimmed.Length > 3 && !trimmed.Contains(" "))
            {
                trimmed = trimmed[..^3] + " " + trimmed[^3..];
            }
            return trimmed;
        }

        /// <summary>
        /// Returns addresses based on the postcode - no need to resolve any of these.
        /// </summary>
        /// <param name="postcode"> The postcode we are searching for </param>
        private async Task<List<PostcodeAddressResponse>> FetchPostcodeFromIdealAsync(string postcode)
        {
            var encoded = Uri.EscapeDataString(postcode);
            var url = $"postcodes/{encoded}?api_key={_apiKey}";
            var apiResp = await _http.GetFromJsonAsync<IdealApiResponse>(url);

            // If nothing came back, return placeholder
            if (apiResp?.Result == null || apiResp.Result.Count == 0)
                return new List<PostcodeAddressResponse> { PlaceholderForPostcode(postcode) };

            // Map each IdealResult into your AddressResponse
            return apiResp.Result.Select(r => new PostcodeAddressResponse
            {
                FormattedAddress = $"{r.Line1}{(string.IsNullOrEmpty(r.Line2) ? "" : ", " + r.Line2)}, {r.PostTown}, {r.County}, {r.Postcode}, {r.Country}",
                Line1 = r.Line1,
                Line2 = r.Line2,
                Town = r.PostTown,
                County = r.County,
                Postcode = r.Postcode,
                Country = r.Country,
                Uprn = r.UPRN,
                LocalAuthority = r.District,
                AuthorityCode = r.Ward,
                Latitude = r.Latitude,
                Longitude = r.Longitude
            }).ToList();
        }

        /// <summary>
        /// Fetches all suggestions for a given address entered - these will need to be resolved
        /// using the /api/AddressLookup/ResolveAddress endpoint.
        /// </summary>
        /// <param name="address"> The address entered by the user </param>
        /// <param name="context"> The country using ISO code (e.g. GBR) </param>
        private async Task<List<AddressResponse>> FetchAddressFromIdealAsync(string address, string context)
        {
            _logger.Log(LogLevel.Information, $"Entering FetchAddressFromIdealAsync with address {address} and context {context} ");

            var encoded = Uri.EscapeDataString(address);
            var url = $"autocomplete/addresses?api_key={_apiKey}&query={encoded}&context={context}";
            var apiResp = await _http.GetFromJsonAsync<IdealApiAddressResponse>(url);

            // If nothing came back, return placeholder
            if (apiResp?.Result == null)
                return new List<AddressResponse> { PlaceHolderForAddress(address) };

            // Map each IdealResult into your AddressResponse
            return apiResp.Result.Hits.Select(hit => new AddressResponse
            {
                Id = hit.Id,
                Suggestion = hit.Suggestion,
                Udprn = hit.Udprn.ToString(),
                Urls = hit.Urls.Udprn
            }).ToList();
        }

        /// <summary>
        /// Resolves a given suggestion using the provided ID that is returned. This is purely used
        /// for address suggestions - postcode based search results need no resolving.
        /// </summary>
        /// <param name="ID">      The provided ID of a given suggestion </param>
        /// <param name="context"> The country ISO code </param>
        /// <returns> Returns <see cref="ResolveAddressResponse"/> </returns>
        private async Task<ResolveAddressResponse> ResolveAddressById(string ID, string context)
        {
            _logger.Log(LogLevel.Information, $"Resolving address with ID {ID} and context {context}");

            var url = $"autocomplete/addresses/{ID}/{context}?api_key={_apiKey}";
            var apiResp = await _http.GetFromJsonAsync<IdealApiAddressResolveResponse>(url);

            if (apiResp?.Result == null)
            {
                return new ResolveAddressResponse { Id = ID, Country = context };
            }

            // Log the full response
            _logger.Log(LogLevel.Information, $"Response for resolving address: {JsonSerializer.Serialize(apiResp, new JsonSerializerOptions { WriteIndented = true })}");

            var vals = apiResp.Result;

            return new ResolveAddressResponse()
            {
                Id = vals.Id,
                Dataset = vals.Dataset,
                Country_ISO = vals.Country_ISO,
                Country_ISO_2 = vals.Country_ISO_2,
                Country = vals.Country,
                Language = vals.Language,
                Line_1 = vals.Line_1,
                Line_2 = vals.Line_2,
                Line_3 = vals.Line_3,
                Post_town = vals.Post_town,
                Postcode = vals.Postcode,
                County = vals.County,
                County_code = vals.County_code,
                UPRN = vals.UPRN,
                UDPRN = vals.UDPRN.ToString(),
                Postcode_outward = vals.Postcode_outward,
                Postcode_inward = vals.Postcode_inward,
                Dependant_locality = vals.Dependant_locality,
                Double_Dependant_locality = vals.Double_Dependant_locality,
                Thoroughfare = vals.Thoroughfare,
                Dependant_thoroughfare = vals.Dependant_thoroughfare,
                Building_number = vals.Building_number,
                Building_name = vals.Building_name,
                Sub_building_name = vals.Sub_building_name,
                Po_box = vals.Po_box,
                Department_name = vals.Department_name,
                Organisation_name = vals.Organisation_name,
                Postcode_type = vals.Postcode_type,
                Su_organisation_indicator = vals.Su_organisation_indicator,
                Delivery_point_suffix = vals.Delivery_point_suffix,
                Premise = vals.Premise,
                Administrative_county = vals.Administrative_county,
                Postal_county = vals.Postal_county,
                Traditional_county = vals.Traditional_county,
                District = vals.District,
                Ward = vals.Ward,
                Longitude = vals.Longitude,
                Latitude = vals.Latitude,
                Eastings = vals.Eastings,
                Northings = vals.Northings
            };
        }

        /// <summary>
        /// "Not found” placeholder. This is used for postcode based search only.
        /// </summary>
        /// <param name="postcode"> The originally entered postcode </param>
        private PostcodeAddressResponse PlaceholderForPostcode(string postcode) =>
            new PostcodeAddressResponse
            {
                FormattedAddress = "Address Not Found, Update Addresses?",
                Line1 = null,
                Line2 = null,
                Town = null,
                County = null,
                Postcode = postcode,
                Country = string.Empty,
                Uprn = null,
                LocalAuthority = null,
                AuthorityCode = null,
                Latitude = null,
                Longitude = null
            };

        /// <summary>
        /// Returns placeholder when trying to search by the address rather than the postcode.
        /// </summary>
        /// <param name="postcode"> The postcode which was originally entered. </param>
        /// <returns> Returns type of <see cref="PostcodeAddressResponse"/> </returns>
        public PostcodeAddressResponse GetAddressNotFoundPlaceholder(string postcode)
        {
            return PlaceholderForPostcode(postcode);
        }

        /// <summary>
        /// Not found definition.
        /// </summary>
        /// <param name="address"> </param>
        /// <returns> </returns>
        private AddressResponse PlaceHolderForAddress(string address) =>
            new AddressResponse
            {
                Id = null,
                Suggestion = address,
                Udprn = null,
            };

        /// <summary>
        /// Returns not found definition when searching by address
        /// </summary>
        /// <returns> Returns type of <see cref="AddressResponse"/> </returns>
        public AddressResponse GetPlaceHolderForAddress()
        {
            return PlaceHolderForAddress("Address Not Found, Update Addresses?");
        }

        /// <summary>
        /// Map an EF AddressCache back into your DTO (preserving the parent postcode).
        /// </summary>
        private PostcodeAddressResponse MapToDto(AddressCache e, string parentPostcode) =>
            new PostcodeAddressResponse
            {
                FormattedAddress = e.FormattedAddress,
                Line1 = e.Line1,
                Line2 = e.Line2,
                Town = e.Town,
                County = e.County,
                Postcode = parentPostcode,
                Country = e.Country,
                Uprn = e.Uprn,
                LocalAuthority = e.LocalAuthority,
                AuthorityCode = e.AuthorityCode,
                Latitude = e.Latitude,
                Longitude = e.Longitude
            };
    }
}