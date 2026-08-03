using System.Text.Json.Serialization;

namespace Concursus.API.Sage.SOAP.Models
{
    public sealed class SageCreateSalesOrderResponse
    {
        [JsonPropertyName("status")]
        public string? Status { get; set; }

        [JsonPropertyName("orderId")]
        public string? OrderId { get; set; }

        [JsonPropertyName("detail")]
        public string? Detail { get; set; }

        // The Sage wrapper returns this as transactionReference, not sageTransactionReference.
        // Without this explicit mapping, direct ISageApiClient calls can succeed while the
        // Sage transaction reference remains blank.
        [JsonPropertyName("transactionReference")]
        public string? SageTransactionReference { get; set; } = null;
    }
}
