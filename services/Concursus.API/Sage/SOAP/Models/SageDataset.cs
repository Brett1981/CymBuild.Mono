using System.Text.Json.Serialization;

namespace Concursus.API.Sage.SOAP.Models
{
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public enum SageDataset
    {
        group,
        asbestos
    }
}
