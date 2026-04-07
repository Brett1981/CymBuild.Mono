namespace PostCodeLookup.DTOs
{
    /// <summary>
    /// Models the POST body: { "postcode": "...", "forceApi": false }.
    /// </summary>
    public class PostcodeRequest
    {
        /// <summary>
        /// The UK postcode to look up (e.g. "SW1A 2AA"). Required.
        /// </summary>
        public string Postcode { get; set; } = default!;

        /// <summary>
        /// If true, ignore any cached data and force a fresh GetAddress.io call. Default=false.
        /// </summary>
        public bool ForceApi { get; set; } = false;
    }
}