using System.Text.Json.Serialization;

namespace PostCodeLookup.Integrations.IdealPostcode
{
    public class IdealApiResponse
    {
        [JsonPropertyName("result")]
        public List<IdealResult> Result { get; set; } = new();

        [JsonPropertyName("code")]
        public int Code { get; set; }

        [JsonPropertyName("message")]
        public string Message { get; set; } = default!;

        [JsonPropertyName("page")]
        public int Page { get; set; }

        [JsonPropertyName("limit")]
        public int Limit { get; set; }

        [JsonPropertyName("total")]
        public int Total { get; set; }
    }
}