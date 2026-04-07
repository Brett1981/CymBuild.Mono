using System.Text.Json.Serialization;

namespace PostCodeLookup.Integrations.IdealPostcode
{
    /*
        JSON body structure declaration for when we would like to resolve an address by ID.
    */

    public class IdealApiAddressResolveResponse
    {
        [JsonPropertyName("code")] public int Code { get; set; }

        [JsonPropertyName("message")] public string Message { get; set; } = default!;

        [JsonPropertyName("result")] public ResolveAddressResponse Result { get; set; } = default!;
    }
}