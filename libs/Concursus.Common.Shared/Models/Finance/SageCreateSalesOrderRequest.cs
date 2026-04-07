#nullable enable

using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Outbound request DTO for POST /api/sales-orders.
    /// Matches the real Sage REST-wrapper contract.
    /// </summary>
    public sealed class SageCreateSalesOrderRequest
    {
        [JsonPropertyName("dataset")]
        [Required]
        public string Dataset { get; set; } = string.Empty;

        [JsonPropertyName("accountReference")]
        [Required]
        public string AccountReference { get; set; } = string.Empty;

        [JsonPropertyName("customerOrderNo")]
        public string? CustomerOrderNo { get; set; }

        [JsonPropertyName("documentDate")]
        public DateTime? DocumentDate { get; set; }

        [JsonPropertyName("useInvoiceAddress")]
        public bool UseInvoiceAddress { get; set; }

        [JsonPropertyName("allowCreditLimitException")]
        public bool AllowCreditLimitException { get; set; }

        [JsonPropertyName("overrideOnHold")]
        public bool OverrideOnHold { get; set; }

        [JsonPropertyName("analysisCode01Value")]
        public string? AnalysisCode01Value { get; set; }

        [JsonPropertyName("analysisCode02Value")]
        public string? AnalysisCode02Value { get; set; }

        [JsonPropertyName("analysisCode03Value")]
        public string? AnalysisCode03Value { get; set; }

        [JsonPropertyName("lines")]
        [Required]
        public List<SageCreateSalesOrderLineRequest> Lines { get; set; } = new();
    }

    /// <summary>
    /// Outbound line DTO for POST /api/sales-orders.
    /// Matches the real Sage REST-wrapper contract.
    /// </summary>
    public sealed class SageCreateSalesOrderLineRequest
    {
        [JsonPropertyName("itemDescription")]
        [Required]
        public string ItemDescription { get; set; } = string.Empty;

        [JsonPropertyName("lineType")]
        public string? LineType { get; set; }

        [JsonPropertyName("nominalRef")]
        [Required]
        public string NominalRef { get; set; } = string.Empty;

        [JsonPropertyName("nominalCC")]
        public string? NominalCC { get; set; }

        [JsonPropertyName("nominalDept")]
        public string? NominalDept { get; set; }

        [JsonPropertyName("quantity")]
        [Range(1, int.MaxValue)]
        public int Quantity { get; set; }

        [JsonPropertyName("unitPrice")]
        public decimal UnitPrice { get; set; }

        [JsonPropertyName("taxCode")]
        public int? TaxCode { get; set; }
    }

    /// <summary>
    /// Inbound response DTO for POST /api/sales-orders.
    /// Matches the real Sage REST-wrapper contract.
    /// </summary>
    public sealed class SageCreateSalesOrderResponse
    {
        [JsonIgnore]
        public int? HttpStatusCode { get; set; }

        [JsonIgnore]
        public string RawResponseBody { get; set; } = string.Empty;

        [JsonPropertyName("status")]
        public string Status { get; set; } = string.Empty;

        [JsonPropertyName("orderId")]
        public string OrderId { get; set; } = string.Empty;

        [JsonPropertyName("detail")]
        public string Detail { get; set; } = string.Empty;

        [JsonIgnore]
        public bool IsOk =>
            string.Equals(Status, "Ok", StringComparison.OrdinalIgnoreCase);

        [JsonIgnore]
        public bool IsError =>
            string.Equals(Status, "Error", StringComparison.OrdinalIgnoreCase);
    }
}