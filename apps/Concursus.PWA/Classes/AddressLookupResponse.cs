namespace Concursus.PWA.Classes
{
    public class AddressLookupResponse
    {
        public int Code { get; set; }

        public string Message { get; set; }

        public IdealAddressResultWrapper Result { get; set; }
    }

    public class IdealAddressResultWrapper
    {
        public List<IdealAddressResult> Hits { get; set; } = new();
    }

    public class IdealAddressResult
    {
        public string Id { get; set; } = default!;

        public string Suggestion { get; set; } = default!;

        public int Udprn { get; set; }  // Changed to int

        public IdealAddressResultUrls Urls { get; set; } = default!;
    }

    /// <summary>
    /// Part of IdealAddressResult
    /// </summary>
    public class IdealAddressResultUrls
    {
        public string Udprn { get; set; } = default!;
    }

    /// <summary>
    /// Structure returned when searching by an address rather than postcode.
    /// </summary>
    public class AddressSearchResult
    {
        public string Id { get; set; }
        public string Suggestion { get; set; }
        public string Udprn { get; set; }
        public string Urls { get; set; }
    }

    /// <summary>
    /// Structure returned when we resolve a given address.
    /// </summary>
    public class ResolveAddressResponse
    {
        public string Id { get; set; }
        public string Dataset { get; set; }
        public string Country_ISO { get; set; }
        public string Country_ISO_2 { get; set; }
        public string Country { get; set; }
        public string Language { get; set; }
        public string Line_1 { get; set; }
        public string Line_2 { get; set; }
        public string Line_3 { get; set; }
        public string Post_town { get; set; }
        public string Postcode { get; set; }
        public string County { get; set; }
        public string County_code { get; set; }
        public string UPRN { get; set; }
        public string UDPRN { get; set; }
        public string Postcode_outward { get; set; }
        public string Postcode_inward { get; set; }
        public string Dependant_locality { get; set; }
        public string Double_Dependant_locality { get; set; }
        public string Thoroughfare { get; set; }
        public string Dependant_thoroughfare { get; set; }
        public string Building_number { get; set; }
        public string Building_name { get; set; }
        public string Sub_building_name { get; set; }
        public string Po_box { get; set; }
        public string Department_name { get; set; }
        public string Organisation_name { get; set; }
        public string Postcode_type { get; set; }
        public string Su_organisation_indicator { get; set; }
        public string Delivery_point_suffix { get; set; }
        public string Premise { get; set; }
        public string Administrative_county { get; set; }
        public string Postal_county { get; set; }
        public string Traditional_county { get; set; }
        public string District { get; set; }
        public string Ward { get; set; }
        public double? Longitude { get; set; }
        public double? Latitude { get; set; }
        public double? Eastings { get; set; }
        public double? Northings { get; set; }
    }
}