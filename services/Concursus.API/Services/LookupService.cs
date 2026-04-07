using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Concursus.API.Classes;
using Concursus.API.Interfaces;
using Microsoft.Extensions.Options;

namespace Concursus.API.Services;

public sealed class LookupService : ILookupService
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        PropertyNameCaseInsensitive = true
    };

    private readonly HttpClient _httpClient;
    private readonly LookupServicesOptions _options;
    private readonly ILogger<LookupService> _logger;

    public LookupService(
        HttpClient httpClient,
        IOptions<LookupServicesOptions> options,
        ILogger<LookupService> logger)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
        _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));

        if (!string.IsNullOrWhiteSpace(_options.BaseUrl))
        {
            _httpClient.BaseAddress = new Uri(_options.BaseUrl, UriKind.Absolute);
        }

        if (!_httpClient.DefaultRequestHeaders.Accept.Any(x => x.MediaType == "application/json"))
        {
            _httpClient.DefaultRequestHeaders.Accept.Add(
                new MediaTypeWithQualityHeaderValue("application/json"));
        }

        if (!string.IsNullOrWhiteSpace(_options.ApplicationName) &&
            !_httpClient.DefaultRequestHeaders.Contains("X-Application-Name"))
        {
            _httpClient.DefaultRequestHeaders.TryAddWithoutValidation(
                "X-Application-Name",
                _options.ApplicationName);
        }

        if (!string.IsNullOrWhiteSpace(_options.ApiKey) &&
            !_httpClient.DefaultRequestHeaders.Contains("X-Api-Key"))
        {
            _httpClient.DefaultRequestHeaders.TryAddWithoutValidation(
                "X-Api-Key",
                _options.ApiKey);
        }
    }

    public async Task<LookupSearchResult> SearchAsync(
        string searchText,
        string context,
        bool forceApi,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabledAndConfigured();

        if (string.IsNullOrWhiteSpace(searchText))
        {
            return new LookupSearchResult();
        }

        var request = new LookupSearchHttpRequest
        {
            Address = searchText.Trim(),
            Context = string.IsNullOrWhiteSpace(context) ? "GBR" : context.Trim(),
            ForceApi = forceApi
        };

        using var response = await _httpClient.PostAsJsonAsync(
            "CombinedAddressLookup/LookForAddress",
            request,
            JsonOptions,
            cancellationToken);

        await EnsureSuccessAsync(
            response,
            "searching for postcode/address suggestions",
            cancellationToken);

        var json = await response.Content.ReadAsStringAsync(cancellationToken);
        return ParseSearchResponse(json);
    }

    public async Task<LookupAddressRecord> ResolveAsync(
        string id,
        string context,
        CancellationToken cancellationToken = default)
    {
        EnsureEnabledAndConfigured();

        if (string.IsNullOrWhiteSpace(id))
        {
            throw new ArgumentException("Address id is required.", nameof(id));
        }

        var request = new LookupResolveHttpRequest
        {
            Id = id.Trim(),
            Context = string.IsNullOrWhiteSpace(context) ? "GBR" : context.Trim()
        };

        using var response = await _httpClient.PostAsJsonAsync(
            "AddressLookup/ResolveAddress",
            request,
            JsonOptions,
            cancellationToken);

        await EnsureSuccessAsync(
            response,
            "resolving address details",
            cancellationToken);

        var resolved = await response.Content.ReadFromJsonAsync<ResolveAddressHttpResponse>(
            JsonOptions,
            cancellationToken);

        if (resolved is null)
        {
            throw new InvalidOperationException("The postcode API returned an empty resolve response.");
        }

        return MapResolvedAddress(resolved);
    }

    private void EnsureEnabledAndConfigured()
    {
        if (!_options.Enabled)
        {
            throw new InvalidOperationException("Lookup services are disabled.");
        }

        if (string.IsNullOrWhiteSpace(_options.BaseUrl))
        {
            throw new InvalidOperationException("LookupServices:BaseUrl is not configured.");
        }
    }

    private async Task EnsureSuccessAsync(
        HttpResponseMessage response,
        string operation,
        CancellationToken cancellationToken)
    {
        if (response.IsSuccessStatusCode)
        {
            return;
        }

        var body = await response.Content.ReadAsStringAsync(cancellationToken);

        _logger.LogWarning(
            "Lookup service call failed while {Operation}. StatusCode={StatusCode}, Body={Body}",
            operation,
            (int)response.StatusCode,
            body);

        throw new InvalidOperationException(
            $"Lookup service call failed while {operation}. " +
            $"HTTP {(int)response.StatusCode} {response.ReasonPhrase}. {body}");
    }

    private static LookupSearchResult ParseSearchResponse(string json)
    {
        var result = new LookupSearchResult();

        if (string.IsNullOrWhiteSpace(json))
        {
            return result;
        }

        using var document = JsonDocument.Parse(json);

        if (document.RootElement.ValueKind != JsonValueKind.Array)
        {
            return result;
        }

        foreach (var item in document.RootElement.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object)
            {
                continue;
            }

            if (item.TryGetProperty("suggestion", out _))
            {
                result.AddressSuggestions.Add(new LookupAddressSuggestion
                {
                    Id = GetString(item, "id"),
                    Suggestion = GetString(item, "suggestion"),
                    Udprn = GetString(item, "udprn"),
                    Urls = GetString(item, "urls")
                });

                continue;
            }

            if (item.TryGetProperty("formattedAddress", out _))
            {
                result.PostcodeAddresses.Add(new LookupAddressRecord
                {
                    Number = GetString(item, "number"),
                    FormattedAddress = GetString(item, "formattedAddress"),
                    Line1 = GetString(item, "line1"),
                    Line2 = GetString(item, "line2"),
                    Town = GetString(item, "town"),
                    County = GetString(item, "county"),
                    Postcode = GetString(item, "postcode"),
                    Country = GetString(item, "country"),
                    Uprn = GetString(item, "uprn"),
                    LocalAuthority = GetString(item, "localAuthority"),
                    AuthorityCode = GetString(item, "authorityCode"),
                    Latitude = GetNullableDouble(item, "latitude"),
                    Longitude = GetNullableDouble(item, "longitude")
                });
            }
        }

        return result;
    }

    private static LookupAddressRecord MapResolvedAddress(ResolveAddressHttpResponse source)
    {
        return new LookupAddressRecord
        {
            Number = source.BuildingNumber ?? string.Empty,
            FormattedAddress = string.Empty,
            Line1 = source.Line1 ?? string.Empty,
            Line2 = source.Line2 ?? string.Empty,
            Town = source.PostTown ?? string.Empty,
            County = source.County ?? string.Empty,
            Postcode = source.Postcode ?? string.Empty,
            Country = source.Country ?? string.Empty,
            Uprn = source.Uprn ?? string.Empty,
            LocalAuthority = source.District ?? string.Empty,
            AuthorityCode = string.Empty,
            Latitude = source.Latitude,
            Longitude = source.Longitude
        };
    }

    private static string GetString(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var property))
        {
            return string.Empty;
        }

        return property.ValueKind switch
        {
            JsonValueKind.String => property.GetString() ?? string.Empty,
            JsonValueKind.Number => property.ToString(),
            JsonValueKind.True => "true",
            JsonValueKind.False => "false",
            _ => string.Empty
        };
    }

    private static double? GetNullableDouble(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var property))
        {
            return null;
        }

        if (property.ValueKind == JsonValueKind.Number && property.TryGetDouble(out var value))
        {
            return value;
        }

        if (property.ValueKind == JsonValueKind.String &&
            double.TryParse(property.GetString(), out var parsed))
        {
            return parsed;
        }

        return null;
    }

    private sealed class LookupSearchHttpRequest
    {
        [JsonPropertyName("address")]
        public string Address { get; set; } = string.Empty;

        [JsonPropertyName("context")]
        public string Context { get; set; } = "GBR";

        [JsonPropertyName("forceApi")]
        public bool ForceApi { get; set; }
    }

    private sealed class LookupResolveHttpRequest
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("context")]
        public string Context { get; set; } = "GBR";
    }

    private sealed class ResolveAddressHttpResponse
    {
        [JsonPropertyName("id")]
        public string? Id { get; set; }

        [JsonPropertyName("country")]
        public string? Country { get; set; }

        [JsonPropertyName("line_1")]
        public string? Line1 { get; set; }

        [JsonPropertyName("line_2")]
        public string? Line2 { get; set; }

        [JsonPropertyName("post_town")]
        public string? PostTown { get; set; }

        [JsonPropertyName("postcode")]
        public string? Postcode { get; set; }

        [JsonPropertyName("county")]
        public string? County { get; set; }

        [JsonPropertyName("uprn")]
        public string? Uprn { get; set; }

        [JsonPropertyName("district")]
        public string? District { get; set; }

        [JsonPropertyName("building_number")]
        public string? BuildingNumber { get; set; }

        [JsonPropertyName("latitude")]
        public double? Latitude { get; set; }

        [JsonPropertyName("longitude")]
        public double? Longitude { get; set; }
    }
}