using System.Text.Json.Serialization;

namespace PostCodeLookup.Data
{
    public class OsPlacesResponse
    {
        [JsonPropertyName("header")]
        public OsHeader Header { get; set; } = default!;

        [JsonPropertyName("results")]
        public List<OsPlaceResult> Results { get; set; } = new();
    }

    public class OsHeader
    {
        [JsonPropertyName("totalresults")]
        public int TotalResults { get; set; }

        [JsonPropertyName("dataset")]
        public string Dataset { get; set; } = default!;
    }

    public class OsPlaceResult
    {
        [JsonPropertyName("DPA")]
        public OsDpa DPA { get; set; } = default!;

        [JsonPropertyName("LPI")]
        public OsLpi LPI { get; set; } = default!;

        [JsonPropertyName("LOCALITY")]
        public OsLocality Locality { get; set; } = default!;
    }

    public class OsDpa
    {
        [JsonPropertyName("UPRN")]
        public string? UPRN { get; set; }

        // In the JSON, “ADDRESS” is a single string (e.g., "10 Downing Street, Westminster, London,
        // SW1A 2AA")
        [JsonPropertyName("ADDRESS")]
        public string? Address { get; set; }

        [JsonPropertyName("BUILDING_NAME")]
        public string? BuildingName { get; set; }

        [JsonPropertyName("BUILDING_NUMBER")]
        public string? BuildingNumber { get; set; }

        [JsonPropertyName("THOROUGHFARE_NAME")]
        public string? ThoroughfareName { get; set; }

        [JsonPropertyName("DEPENDENT_THOROUGHFARE_NAME")]
        public string? DependentThoroughfare { get; set; }

        [JsonPropertyName("DEPENDENT_LOCALITY")]
        public string? DependentLocality { get; set; }

        [JsonPropertyName("DOUBLE_DEPENDENT_LOCALITY")]
        public string? DoubleDependentLocality { get; set; }

        [JsonPropertyName("POST_TOWN")]
        public string PostTown { get; set; } = default!;

        [JsonPropertyName("POSTCODE")]
        public string Postcode { get; set; } = default!;

        [JsonPropertyName("X_COORDINATE")]
        public double X { get; set; }

        [JsonPropertyName("Y_COORDINATE")]
        public double Y { get; set; }

        // longitude in WGS84 (EPSG:4326) after output_srs=EPSG:4326
        [JsonPropertyName("LNG")]
        public double? Longitude { get; set; }

        // ← NEW: latitude in WGS84
        [JsonPropertyName("LAT")]
        public double? Latitude { get; set; }

        [JsonPropertyName("STATUS")]
        public string? Status { get; set; }

        [JsonPropertyName("LOGICAL_STATUS_CODE")]
        public int? LogicalStatusCode { get; set; }

        [JsonPropertyName("CLASSIFICATION_CODE")]
        public string? ClassificationCode { get; set; }

        [JsonPropertyName("CLASSIFICATION_CODE_DESCRIPTION")]
        public string? ClassificationCodeDescription { get; set; }

        [JsonPropertyName("LOCAL_CUSTODIAN_CODE")]
        public int? LocalCustodianCode { get; set; }

        [JsonPropertyName("LOCAL_CUSTODIAN_CODE_DESCRIPTION")]
        public string? LocalCustodianCodeDescription { get; set; }

        [JsonPropertyName("COUNTRY_CODE")]
        public string? CountryCode { get; set; }

        [JsonPropertyName("COUNTRY_CODE_DESCRIPTION")]
        public string? CountryCodeDescription { get; set; }

        [JsonPropertyName("BLPU_STATE_CODE")]
        public int? BlpuStateCode { get; set; }

        [JsonPropertyName("BLPU_STATE_CODE_DESCRIPTION")]
        public string? BlpuStateCodeDescription { get; set; }
    }

    public class OsLpi
    {
        [JsonPropertyName("UPRN")]
        public string? UPRN { get; set; }

        [JsonPropertyName("ADDRESS")]
        public string Address { get; set; } = default!;

        [JsonPropertyName("USRN")]
        public int? USRN { get; set; }

        [JsonPropertyName("LPI_KEY")]
        public string? LpiKey { get; set; }

        [JsonPropertyName("ORGANISATION")]
        public string? Organisation { get; set; }

        [JsonPropertyName("SAO_START_NUMBER")]
        public int? SaoStartNumber { get; set; }

        [JsonPropertyName("SAO_START_SUFFIX")]
        public string? SaoStartSuffix { get; set; }

        [JsonPropertyName("SAO_END_NUMBER")]
        public int? SaoEndNumber { get; set; }

        [JsonPropertyName("SAO_END_SUFFIX")]
        public string? SaoEndSuffix { get; set; }

        [JsonPropertyName("SAO_TEXT")]
        public string? SaoText { get; set; }

        [JsonPropertyName("PAO_START_NUMBER")]
        public int? PaoStartNumber { get; set; }

        [JsonPropertyName("PAO_START_SUFFIX")]
        public string? PaoStartSuffix { get; set; }

        [JsonPropertyName("PAO_END_NUMBER")]
        public int? PaoEndNumber { get; set; }

        [JsonPropertyName("PAO_END_SUFFIX")]
        public string? PaoEndSuffix { get; set; }

        [JsonPropertyName("PAO_TEXT")]
        public string? PaoText { get; set; }

        [JsonPropertyName("STREET_DESCRIPTION")]
        public string? StreetDescription { get; set; }

        [JsonPropertyName("LOCALITY_NAME")]
        public string? LocalityName { get; set; }

        [JsonPropertyName("TOWN_NAME")]
        public string? TownName { get; set; }

        [JsonPropertyName("ADMINISTRATIVE_AREA")]
        public string? AdministrativeArea { get; set; }

        [JsonPropertyName("AREA_NAME")]
        public string? AreaName { get; set; }

        [JsonPropertyName("POSTCODE_LOCATOR")]
        public string? PostcodeLocator { get; set; }

        [JsonPropertyName("X_COORDINATE")]
        public double? X { get; set; }

        [JsonPropertyName("Y_COORDINATE")]
        public double? Y { get; set; }

        [JsonPropertyName("LNG")]
        public double? Longitude { get; set; }

        [JsonPropertyName("LAT")]
        public double? Latitude { get; set; }

        [JsonPropertyName("STATUS")]
        public string? Status { get; set; }

        [JsonPropertyName("LOGICAL_STATUS_CODE")]
        public int? LogicalStatusCode { get; set; }

        [JsonPropertyName("CLASSIFICATION_CODE")]
        public string? ClassificationCode { get; set; }

        [JsonPropertyName("CLASSIFICATION_CODE_DESCRIPTION")]
        public string? ClassificationCodeDescription { get; set; }

        [JsonPropertyName("LOCAL_CUSTODIAN_CODE")]
        public int? LocalCustodianCode { get; set; }

        [JsonPropertyName("LOCAL_CUSTODIAN_CODE_DESCRIPTION")]
        public string? LocalCustodianCodeDescription { get; set; }

        [JsonPropertyName("COUNTRY_CODE")]
        public string? CountryCode { get; set; }

        [JsonPropertyName("COUNTRY_CODE_DESCRIPTION")]
        public string? CountryCodeDescription { get; set; }

        [JsonPropertyName("PARENT_UPRN")]
        public string? ParentUprn { get; set; }

        [JsonPropertyName("LAST_UPDATE_DATE")]
        public string? LastUpdateDate { get; set; }

        [JsonPropertyName("ENTRY_DATE")]
        public string? EntryDate { get; set; }

        [JsonPropertyName("LPI_LOGICAL_STATUS_CODE")]
        public int? LpiLogicalStatusCode { get; set; }

        [JsonPropertyName("LPI_LOGICAL_STATUS_CODE_DESCRIPTION")]
        public string? LpiLogicalStatusCodeDescription { get; set; }

        [JsonPropertyName("LANGUAGE")]
        public string? Language { get; set; }

        [JsonPropertyName("MATCH")]
        public double? Match { get; set; }

        [JsonPropertyName("MATCH_DESCRIPTION")]
        public string? MatchDescription { get; set; }
    }

    public class OsLocality
    {
        [JsonPropertyName("LOCALITY_NAME")]
        public string LocalityName { get; set; } = default!;

        [JsonPropertyName("LOCAL_AUTHORITY")]
        public string LocalAuthority { get; set; } = default!;
    }
}