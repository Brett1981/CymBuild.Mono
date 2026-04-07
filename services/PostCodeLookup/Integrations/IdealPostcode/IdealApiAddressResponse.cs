using System.Text.Json.Serialization;

namespace PostCodeLookup.Integrations.IdealPostcode
{
    public class IdealApiAddressResponse
    {
        [JsonPropertyName("code")] public int Code { get; set; }

        [JsonPropertyName("message")] public string Message { get; set; } = default!;

        [JsonPropertyName("result")] public IdealAddressResultWrapper Result { get; set; } = default!;
    }

    public class IdealAddressResultWrapper
    {
        [JsonPropertyName("hits")] public List<IdealAddressResult> Hits { get; set; } = new();
    }
}