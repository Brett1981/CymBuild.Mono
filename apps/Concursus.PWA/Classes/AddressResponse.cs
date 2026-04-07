namespace Concursus.PWA.Classes
{
    /// <summary>
    /// Models a single address entry returned by our API.
    /// </summary>
    public class AddressResponse
    {
        /// <summary>
        /// Building number
        /// </summary>
        public string Number { get; set; } = "";

        /// <summary>
        /// Single-line, formatted address (e.g. "10 Downing Street, Westminster, London, SW1A 2AA,
        /// United Kingdom").
        /// </summary>
        public string FormattedAddress { get; set; } = default!;

        /// <summary>
        /// Address line 1 (e.g. "10 Downing Street").
        /// </summary>
        public string Line1 { get; set; }

        /// <summary>
        /// Address line 2 (e.g. “Westminster”).
        /// </summary>
        public string? Line2 { get; set; }

        /// <summary>
        /// Town or city (e.g. "London").
        /// </summary>
        public string Town { get; set; }

        /// <summary>
        /// County (e.g. "Greater London"), if present.
        /// </summary>
        public string? County { get; set; }

        /// <summary>
        /// The postcode (e.g. "SW1A 2AA").
        /// </summary>
        public string Postcode { get; set; } = default!;

        /// <summary>
        /// Country—defaults to "United Kingdom".
        /// </summary>
        public string Country { get; set; }

        /// <summary>
        /// Unique Property Reference Number from GetAddress.io.
        /// </summary>
        public string? Uprn { get; set; }

        /// <summary>
        /// Local authority (e.g. "City of Westminster").
        /// </summary>
        public string? LocalAuthority { get; set; }

        /// <summary>
        /// Authority code (e.g. "E09000033").
        /// </summary>
        public string? AuthorityCode { get; set; }

        /// <summary>
        /// latitude/longitude in WGS84(EPSG:4326)
        /// </summary>

        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
    }
}