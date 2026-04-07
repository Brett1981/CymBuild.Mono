using System.Text.Json.Serialization;

namespace Concursus.API.Client.Models
{
    public class FileModel
    {
        [JsonPropertyName("name")]
        public string Name { get; set; }

        [JsonPropertyName("size")]
        public long Size { get; set; } = 0;

        [JsonPropertyName("content")]
        public byte[]? Content { get; set; } // Base64 encoded content of the file

        [JsonPropertyName("mimeType")]
        public string? MimeType { get; set; } // MIME type of the file (e.g., image/png)

        [JsonPropertyName("storageUrl")]
        public string? StorageUrl { get; set; } // URL where the file should be stored
    }
}