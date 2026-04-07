using System.Text.Json.Serialization;

namespace PostCodeLookup.Integrations.IdealPostcode
{
    public class ResolveAddressResponse
    {
        [JsonPropertyName("id")] public string Id { get; set; }

        [JsonPropertyName("dataset")] public string Dataset { get; set; }

        [JsonPropertyName("country_iso")] public string Country_ISO { get; set; }

        [JsonPropertyName("country_iso_2")] public string Country_ISO_2 { get; set; }

        [JsonPropertyName("country")] public string Country { get; set; }

        [JsonPropertyName("language")] public string Language { get; set; }

        [JsonPropertyName("line_1")] public string Line_1 { get; set; }

        [JsonPropertyName("line_2")] public string Line_2 { get; set; }

        [JsonPropertyName("line_3")] public string Line_3 { get; set; }

        [JsonPropertyName("post_town")] public string Post_town { get; set; }

        [JsonPropertyName("postcode")] public string Postcode { get; set; }

        [JsonPropertyName("county")] public string County { get; set; }

        [JsonPropertyName("county_code")] public string County_code { get; set; }

        [JsonPropertyName("uprn")] public string UPRN { get; set; }

        [JsonPropertyName("udprn")] public long UDPRN { get; set; }

        [JsonPropertyName("postcode_outward")] public string Postcode_outward { get; set; }

        [JsonPropertyName("postcode_inward")] public string Postcode_inward { get; set; }

        [JsonPropertyName("dependant_locality")] public string Dependant_locality { get; set; }

        [JsonPropertyName("double_dependant_locality")] public string Double_Dependant_locality { get; set; }

        [JsonPropertyName("thoroughfare")] public string Thoroughfare { get; set; }

        [JsonPropertyName("dependant_thoroughfare")] public string Dependant_thoroughfare { get; set; }

        [JsonPropertyName("building_number")] public string Building_number { get; set; }

        [JsonPropertyName("building_name")] public string Building_name { get; set; }

        [JsonPropertyName("sub_building_name")] public string Sub_building_name { get; set; }

        [JsonPropertyName("po_box")] public string Po_box { get; set; }

        [JsonPropertyName("department_name")] public string Department_name { get; set; }

        [JsonPropertyName("organisation_name")] public string Organisation_name { get; set; }

        [JsonPropertyName("postcode_type")] public string Postcode_type { get; set; }

        [JsonPropertyName("su_organisation_indicator")] public string Su_organisation_indicator { get; set; }

        [JsonPropertyName("delivery_point_suffix")] public string Delivery_point_suffix { get; set; }

        [JsonPropertyName("premise")] public string Premise { get; set; }

        [JsonPropertyName("administrative_county")] public string Administrative_county { get; set; }

        [JsonPropertyName("postal_county")] public string Postal_county { get; set; }

        [JsonPropertyName("traditional_county")] public string Traditional_county { get; set; }

        [JsonPropertyName("district")] public string District { get; set; }

        [JsonPropertyName("ward")] public string Ward { get; set; }

        [JsonPropertyName("longitude")] public double? Longitude { get; set; }

        [JsonPropertyName("latitude")] public double? Latitude { get; set; }

        [JsonPropertyName("eastings")] public double? Eastings { get; set; }

        [JsonPropertyName("northings")] public double? Northings { get; set; }
    }
}