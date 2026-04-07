using System.Text.Json.Serialization;

namespace PostCodeLookup.Integrations.IdealPostcode
{
    public class IdealAddressResult
    {
        [JsonPropertyName("id")] public string Id { get; set; } = default!;

        [JsonPropertyName("suggestion")] public string Suggestion { get; set; } = default!;

        [JsonPropertyName("udprn")] public int Udprn { get; set; }  // Changed to int

        [JsonPropertyName("urls")] public IdealAddressResultUrls Urls { get; set; } = default!;
    }

    public class IdealAddressResultUrls
    {
        [JsonPropertyName("udprn")] public string Udprn { get; set; } = default!;
    }
}