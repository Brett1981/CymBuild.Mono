using System.Text.Json.Serialization;

namespace PostCodeLookup.Integrations.IdealPostcode
{
    public class IdealResult
    {
        [JsonPropertyName("id")] public string Id { get; set; } = default!;
        [JsonPropertyName("dataset")] public string Dataset { get; set; } = default!;
        [JsonPropertyName("country_iso")] public string CountryIso3 { get; set; } = default!;
        [JsonPropertyName("country_iso_2")] public string CountryIso2 { get; set; } = default!;
        [JsonPropertyName("country")] public string Country { get; set; } = default!;
        [JsonPropertyName("language")] public string Language { get; set; } = default!;
        [JsonPropertyName("line_1")] public string Line1 { get; set; } = default!;
        [JsonPropertyName("line_2")] public string? Line2 { get; set; }
        [JsonPropertyName("line_3")] public string? Line3 { get; set; }
        [JsonPropertyName("post_town")] public string PostTown { get; set; } = default!;
        [JsonPropertyName("postcode")] public string Postcode { get; set; } = default!;
        [JsonPropertyName("county")] public string? County { get; set; }
        [JsonPropertyName("county_code")] public string? CountyCode { get; set; }
        [JsonPropertyName("uprn")] public string? UPRN { get; set; }
        [JsonPropertyName("udprn")] public int? UDPRN { get; set; }
        [JsonPropertyName("longitude")] public double? Longitude { get; set; }
        [JsonPropertyName("latitude")] public double? Latitude { get; set; }
        [JsonPropertyName("local_custodian_code")] public int? LocalCustodianCode { get; set; }
        [JsonPropertyName("local_custodian_code_description")] public string? LocalCustodianCodeDescription { get; set; }
        [JsonPropertyName("administrative_county")] public string? AdministrativeCounty { get; set; }

        [JsonPropertyName("postal_county")] public string? PostalCounty { get; set; }

        [JsonPropertyName("traditional_county")] public string? TraditionalCounty { get; set; }

        /// <summary>
        /// The current district/unitary authority for this postcode.
        /// </summary>
        [JsonPropertyName("district")] public string? District { get; set; }

        /// <summary>
        /// The current electoral ward for this address.
        /// </summary>
        [JsonPropertyName("ward")] public string? Ward { get; set; }
    }
}