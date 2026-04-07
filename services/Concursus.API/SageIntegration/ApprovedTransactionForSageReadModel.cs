#nullable enable

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json.Serialization;

namespace Concursus.API.SageIntegration
{
    /// <summary>
    /// Read model consumed by the Phase 5 mapping boundary.
    /// This should be populated by the repository/query layer before mapping.
    /// </summary>
    public sealed class ApprovedTransactionForSageReadModel
    {
        public long TransactionId { get; init; }
        public Guid TransactionGuid { get; init; }

        /// <summary>
        /// CymBuild invoice / transaction number to be used as customerOrderNo in Sage.
        /// </summary>
        public string InvoiceNumber { get; init; } = string.Empty;

        public DateTime TransactionDateUtc { get; init; }
        public DateTime? ExpectedDateUtc { get; init; }

        public int AccountId { get; init; }

        /// <summary>
        /// Maps from SCrm.Accounts.Code.
        /// </summary>
        public string AccountCode { get; init; } = string.Empty;

        public string AccountName { get; init; } = string.Empty;

        public int JobId { get; init; }
        public Guid JobGuid { get; init; }
        public string JobNumber { get; init; } = string.Empty;
        public string JobDescription { get; init; } = string.Empty;

        public int OrganisationalUnitId { get; init; }
        public Guid OrganisationalUnitGuid { get; init; }

        public int CreditTermsId { get; init; }
        public int CreatedByUserId { get; init; }
        public int SurveyorUserId { get; init; }

        public string PurchaseOrderNumber { get; init; } = string.Empty;

        /// <summary>
        /// Optional free-text notes to appear on the order header if the wrapper supports it.
        /// </summary>
        public string? HeaderNarrative { get; init; }

        public IReadOnlyList<ApprovedTransactionForSageLineReadModel> Lines { get; init; }
            = Array.Empty<ApprovedTransactionForSageLineReadModel>();
    }

    public sealed class ApprovedTransactionForSageLineReadModel
    {
        public long TransactionDetailId { get; init; }
        public Guid TransactionDetailGuid { get; init; }

        public long? InvoiceRequestItemId { get; init; }

        public long? ActivityId { get; init; }
        public long? MilestoneId { get; init; }

        public string Description { get; init; } = string.Empty;

        /// <summary>
        /// Quantity is explicit in the read model so the mapper stays deterministic.
        /// If CymBuild currently treats each detail row as a single charge line, populate as 1m.
        /// </summary>
        public decimal Quantity { get; init; } = 1m;

        public decimal Net { get; init; }
        public decimal Vat { get; init; }
        public decimal Gross { get; init; }
        public decimal VatRatePercent { get; init; }

        /// <summary>
        /// Optional SKU / product / nominal reference if later added by the read model.
        /// </summary>
        public string? ItemCode { get; init; }

        public string? JobPaymentStageName { get; init; }
    }

    /// <summary>
    /// DTO posted to the Sage REST wrapper endpoint: POST /api/sales-orders
    /// </summary>
    public sealed class SageSalesOrderRequestDto
    {
        [JsonPropertyName("accountReference")]
        public string AccountReference { get; init; } = string.Empty;

        [JsonPropertyName("customerOrderNo")]
        public string CustomerOrderNo { get; init; } = string.Empty;

        [JsonPropertyName("orderDate")]
        public string OrderDate { get; init; } = string.Empty;

        [JsonPropertyName("requestedDeliveryDate")]
        public string? RequestedDeliveryDate { get; init; }

        [JsonPropertyName("purchaseOrderNo")]
        public string? PurchaseOrderNo { get; init; }

        [JsonPropertyName("reference")]
        public string Reference { get; init; } = string.Empty;

        [JsonPropertyName("notes")]
        public string? Notes { get; init; }

        [JsonPropertyName("currencyCode")]
        public string CurrencyCode { get; init; } = "GBP";

        [JsonPropertyName("sourceSystem")]
        public string SourceSystem { get; init; } = "CymBuild";

        [JsonPropertyName("externalCorrelationId")]
        public string ExternalCorrelationId { get; init; } = string.Empty;

        [JsonPropertyName("lines")]
        public IReadOnlyList<SageSalesOrderLineDto> Lines { get; init; }
            = Array.Empty<SageSalesOrderLineDto>();

        [JsonPropertyName("totals")]
        public SageSalesOrderTotalsDto Totals { get; init; } = new();

        [JsonPropertyName("audit")]
        public SageSalesOrderAuditDto Audit { get; init; } = new();
    }

    public sealed class SageSalesOrderLineDto
    {
        [JsonPropertyName("lineNo")]
        public int LineNo { get; init; }

        [JsonPropertyName("itemCode")]
        public string? ItemCode { get; init; }

        [JsonPropertyName("description")]
        public string Description { get; init; } = string.Empty;

        [JsonPropertyName("quantity")]
        public decimal Quantity { get; init; }

        [JsonPropertyName("unitPrice")]
        public decimal UnitPrice { get; init; }

        [JsonPropertyName("netAmount")]
        public decimal NetAmount { get; init; }

        [JsonPropertyName("vatAmount")]
        public decimal VatAmount { get; init; }

        [JsonPropertyName("grossAmount")]
        public decimal GrossAmount { get; init; }

        [JsonPropertyName("vatRatePercent")]
        public decimal VatRatePercent { get; init; }

        [JsonPropertyName("analysisReference")]
        public string AnalysisReference { get; init; } = string.Empty;

        [JsonPropertyName("externalLineId")]
        public string ExternalLineId { get; init; } = string.Empty;
    }

    public sealed class SageSalesOrderTotalsDto
    {
        [JsonPropertyName("netAmount")]
        public decimal NetAmount { get; init; }

        [JsonPropertyName("vatAmount")]
        public decimal VatAmount { get; init; }

        [JsonPropertyName("grossAmount")]
        public decimal GrossAmount { get; init; }
    }

    public sealed class SageSalesOrderAuditDto
    {
        [JsonPropertyName("transactionId")]
        public long TransactionId { get; init; }

        [JsonPropertyName("transactionGuid")]
        public Guid TransactionGuid { get; init; }

        [JsonPropertyName("jobId")]
        public int JobId { get; init; }

        [JsonPropertyName("jobGuid")]
        public Guid JobGuid { get; init; }

        [JsonPropertyName("jobNumber")]
        public string JobNumber { get; init; } = string.Empty;

        [JsonPropertyName("organisationalUnitId")]
        public int OrganisationalUnitId { get; init; }

        [JsonPropertyName("organisationalUnitGuid")]
        public Guid OrganisationalUnitGuid { get; init; }

        [JsonPropertyName("createdByUserId")]
        public int CreatedByUserId { get; init; }

        [JsonPropertyName("surveyorUserId")]
        public int SurveyorUserId { get; init; }
    }

    public interface ISageSalesOrderRequestMapper
    {
        SageSalesOrderRequestDto Map(ApprovedTransactionForSageReadModel source);
    }

    /// <summary>
    /// Deterministic CymBuild -> Sage sales-order mapper.
    /// Pure mapping only. No HTTP, DB or persistence logic belongs here.
    /// </summary>
    public sealed class SageSalesOrderRequestMapper : ISageSalesOrderRequestMapper
    {
        public SageSalesOrderRequestDto Map(ApprovedTransactionForSageReadModel source)
        {
            if (source is null)
                throw new ArgumentNullException(nameof(source));

            ValidateHeader(source);

            var mappedLines = MapLines(source).ToArray();

            if (mappedLines.Length == 0)
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid} cannot be submitted to Sage because it contains no active mapped lines.");

            var totals = new SageSalesOrderTotalsDto
            {
                NetAmount = Money.Round(mappedLines.Sum(x => x.NetAmount)),
                VatAmount = Money.Round(mappedLines.Sum(x => x.VatAmount)),
                GrossAmount = Money.Round(mappedLines.Sum(x => x.GrossAmount))
            };

            return new SageSalesOrderRequestDto
            {
                AccountReference = source.AccountCode.Trim(),
                CustomerOrderNo = source.InvoiceNumber.Trim(),
                OrderDate = FormatDate(source.TransactionDateUtc),
                RequestedDeliveryDate = source.ExpectedDateUtc.HasValue
                    ? FormatDate(source.ExpectedDateUtc.Value)
                    : null,
                PurchaseOrderNo = NullIfWhiteSpace(source.PurchaseOrderNumber),
                Reference = BuildHeaderReference(source),
                Notes = BuildHeaderNotes(source),
                CurrencyCode = "GBP",
                SourceSystem = "CymBuild",
                ExternalCorrelationId = source.TransactionGuid.ToString("D"),
                Lines = mappedLines,
                Totals = totals,
                Audit = new SageSalesOrderAuditDto
                {
                    TransactionId = source.TransactionId,
                    TransactionGuid = source.TransactionGuid,
                    JobId = source.JobId,
                    JobGuid = source.JobGuid,
                    JobNumber = source.JobNumber,
                    OrganisationalUnitId = source.OrganisationalUnitId,
                    OrganisationalUnitGuid = source.OrganisationalUnitGuid,
                    CreatedByUserId = source.CreatedByUserId,
                    SurveyorUserId = source.SurveyorUserId
                }
            };
        }

        private static void ValidateHeader(ApprovedTransactionForSageReadModel source)
        {
            if (string.IsNullOrWhiteSpace(source.AccountCode))
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid} cannot be submitted to Sage because AccountCode is missing.");

            if (string.IsNullOrWhiteSpace(source.InvoiceNumber))
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid} cannot be submitted to Sage because InvoiceNumber is missing.");

            if (source.TransactionDateUtc == default)
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid} cannot be submitted to Sage because TransactionDateUtc is not populated.");

            if (source.Lines is null)
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid} cannot be submitted to Sage because Lines is null.");
        }

        private static IEnumerable<SageSalesOrderLineDto> MapLines(ApprovedTransactionForSageReadModel source)
        {
            var lineNumber = 1;

            foreach (var line in source.Lines)
            {
                ValidateLine(source, line);

                var quantity = line.Quantity <= 0m ? 1m : Money.RoundQuantity(line.Quantity);
                var net = Money.Round(line.Net);
                var vat = Money.Round(line.Vat);

                // Gross is always normalised from net + vat to avoid drift.
                var gross = Money.Round(net + vat);

                var unitPrice = quantity == 0m
                    ? net
                    : Money.Round(net / quantity);

                var vatRatePercent = ResolveVatRate(line, net, vat);

                yield return new SageSalesOrderLineDto
                {
                    LineNo = lineNumber++,
                    ItemCode = NullIfWhiteSpace(line.ItemCode),
                    Description = BuildLineDescription(line),
                    Quantity = quantity,
                    UnitPrice = unitPrice,
                    NetAmount = net,
                    VatAmount = vat,
                    GrossAmount = gross,
                    VatRatePercent = vatRatePercent,
                    AnalysisReference = BuildAnalysisReference(source, line),
                    ExternalLineId = line.TransactionDetailGuid.ToString("D")
                };
            }
        }

        private static void ValidateLine(
            ApprovedTransactionForSageReadModel header,
            ApprovedTransactionForSageLineReadModel line)
        {
            if (line is null)
                throw new InvalidOperationException(
                    $"Transaction {header.TransactionGuid} contains a null line.");

            if (line.TransactionDetailGuid == Guid.Empty)
                throw new InvalidOperationException(
                    $"Transaction {header.TransactionGuid} contains a line with an empty TransactionDetailGuid.");

            if (string.IsNullOrWhiteSpace(line.Description))
                throw new InvalidOperationException(
                    $"Transaction {header.TransactionGuid}, line {line.TransactionDetailGuid} cannot be submitted because Description is missing.");

            if (line.Net < 0m || line.Vat < 0m || line.Gross < 0m)
                throw new InvalidOperationException(
                    $"Transaction {header.TransactionGuid}, line {line.TransactionDetailGuid} contains negative values. " +
                    "Negative sales-order lines are not permitted in this mapper.");
        }

        private static decimal ResolveVatRate(ApprovedTransactionForSageLineReadModel line, decimal net, decimal vat)
        {
            if (line.VatRatePercent > 0m)
                return Money.RoundRate(line.VatRatePercent);

            if (net == 0m || vat == 0m)
                return 0m;

            return Money.RoundRate((vat / net) * 100m);
        }

        private static string BuildHeaderReference(ApprovedTransactionForSageReadModel source)
        {
            var parts = new List<string>();

            if (!string.IsNullOrWhiteSpace(source.JobNumber))
                parts.Add($"Job {source.JobNumber.Trim()}");

            if (!string.IsNullOrWhiteSpace(source.InvoiceNumber))
                parts.Add($"Inv {source.InvoiceNumber.Trim()}");

            parts.Add(source.TransactionGuid.ToString("D"));

            return string.Join(" | ", parts);
        }

        private static string? BuildHeaderNotes(ApprovedTransactionForSageReadModel source)
        {
            var notes = new List<string>();

            if (!string.IsNullOrWhiteSpace(source.JobDescription))
                notes.Add($"Job Description: {source.JobDescription.Trim()}");

            if (!string.IsNullOrWhiteSpace(source.HeaderNarrative))
                notes.Add(source.HeaderNarrative.Trim());

            return notes.Count == 0 ? null : string.Join(Environment.NewLine, notes);
        }

        private static string BuildLineDescription(ApprovedTransactionForSageLineReadModel line)
        {
            var parts = new List<string>
            {
                line.Description.Trim()
            };

            if (!string.IsNullOrWhiteSpace(line.JobPaymentStageName))
                parts.Add($"Stage: {line.JobPaymentStageName!.Trim()}");

            if (line.ActivityId.HasValue && line.ActivityId.Value > 0)
                parts.Add($"ActivityId: {line.ActivityId.Value}");

            if (line.MilestoneId.HasValue && line.MilestoneId.Value > 0)
                parts.Add($"MilestoneId: {line.MilestoneId.Value}");

            if (line.InvoiceRequestItemId.HasValue && line.InvoiceRequestItemId.Value > 0)
                parts.Add($"InvoiceRequestItemId: {line.InvoiceRequestItemId.Value}");

            return string.Join(" | ", parts);
        }

        private static string BuildAnalysisReference(
            ApprovedTransactionForSageReadModel source,
            ApprovedTransactionForSageLineReadModel line)
        {
            return string.Create(
                CultureInfo.InvariantCulture,
                $"{source.JobNumber}|{source.TransactionGuid:D}|{line.TransactionDetailGuid:D}");
        }

        private static string FormatDate(DateTime valueUtc)
            => valueUtc.Date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

        private static string? NullIfWhiteSpace(string? value)
            => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

        private static class Money
        {
            public static decimal Round(decimal value)
                => Math.Round(value, 2, MidpointRounding.AwayFromZero);

            public static decimal RoundRate(decimal value)
                => Math.Round(value, 4, MidpointRounding.AwayFromZero);

            public static decimal RoundQuantity(decimal value)
                => Math.Round(value, 4, MidpointRounding.AwayFromZero);
        }
    }
}