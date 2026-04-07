namespace PostCodeLookup.DTOs
{
    /// <summary>
    /// Models the POST body: { "postcode": "...", "Context":"...", "forceApi": false }.
    /// </summary>
    public class AddressRequest
    {
        /// <summary>
        /// The address to look up. Required.
        /// </summary>
        public string Address { get; set; } = default!;

        /// <summary>
        /// ISO country code Required.
        /// </summary>
        public string Context { get; set; } = "GBR";

        /// <summary>
        /// If true, ignore any cached data and force a fresh GetAddress.io call. Default=false.
        /// </summary>
        public bool ForceApi { get; set; } = false;
    }
}