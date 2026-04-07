#nullable enable

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Deterministic Phase 5 mapper from CymBuild approved transaction read model
    /// to the Sage REST-wrapper POST /api/sales-orders contract.
    /// </summary>
    public sealed class SageSalesOrderRequestMapper : ISageSalesOrderRequestMapper
    {
        private readonly SageSalesOrderMappingOptions _options;
        private readonly ILogger<SageSalesOrderRequestMapper> _logger;

        public SageSalesOrderRequestMapper(
            IOptions<SageSalesOrderMappingOptions> options,
            ILogger<SageSalesOrderRequestMapper> logger)
        {
            _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public SageCreateSalesOrderRequest Map(ApprovedTransactionForSageReadModel source)
        {
            if (source is null)
            {
                throw new ArgumentNullException(nameof(source));
            }

            ValidateHeader(source);

            var request = new SageCreateSalesOrderRequest
            {
                Dataset = ResolveDataset(source),
                AccountReference = source.SageCustomerReference.Trim(),
                CustomerOrderNo = ResolveCustomerOrderNumber(source),
                DocumentDate = ResolveDocumentDate(source),
                UseInvoiceAddress = ResolveUseInvoiceAddress(source),
                AllowCreditLimitException = ResolveAllowCreditLimitException(source),
                OverrideOnHold = ResolveOverrideOnHold(source),
                AnalysisCode01Value = ResolveAnalysisCode01(source),
                AnalysisCode02Value = ResolveAnalysisCode02(source),
                AnalysisCode03Value = ResolveAnalysisCode03(source),
                Lines = MapLines(source).ToList()
            };

            if (request.Lines.Count == 0)
            {
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid} cannot be submitted because no valid lines were produced.");
            }

            return request;
        }

        private IEnumerable<SageCreateSalesOrderLineRequest> MapLines(ApprovedTransactionForSageReadModel source)
        {
            foreach (var line in source.Lines.Where(x => x is not null))
            {
                if (!line.IsUsableForSubmission())
                {
                    _logger.LogWarning(
                        "Skipping non-usable Sage submission line. TransactionGuid={TransactionGuid}, LineId={LineId}",
                        source.TransactionGuid,
                        line.LineId);

                    continue;
                }

                var quantity = ResolveQuantity(line, source);
                var unitPrice = ResolveUnitPrice(line, quantity, source);

                yield return new SageCreateSalesOrderLineRequest
                {
                    ItemDescription = BuildLineDescription(line),
                    LineType = ResolveLineType(line),
                    NominalRef = ResolveNominalRef(line, source),
                    NominalCC = ResolveNominalCC(line),
                    NominalDept = ResolveNominalDept(line),
                    Quantity = quantity,
                    UnitPrice = unitPrice,
                    TaxCode = ResolveTaxCode(line)
                };
            }
        }

        private void ValidateHeader(ApprovedTransactionForSageReadModel source)
        {
            if (!source.IsUsableForSubmission())
            {
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid} is not usable for submission.");
            }

            if (string.IsNullOrWhiteSpace(source.SageCustomerReference))
            {
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid} is missing Sage customer reference.");
            }

            if (string.IsNullOrWhiteSpace(source.GetPreferredExternalReference()))
            {
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid} is missing an external reference/customer order number.");
            }

            if (source.Lines.Count == 0)
            {
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid} has no lines.");
            }

            if (string.IsNullOrWhiteSpace(_options.DefaultDataset) && string.IsNullOrWhiteSpace(source.Dataset))
            {
                throw new InvalidOperationException(
                    "Sage sales-order mapping configuration is missing DefaultDataset and the transaction does not provide a dataset override.");
            }

            if (string.IsNullOrWhiteSpace(_options.DefaultNominalRef))
            {
                throw new InvalidOperationException(
                    "Sage sales-order mapping configuration is missing DefaultNominalRef.");
            }

            if (!_options.DefaultTaxCode.HasValue)
            {
                throw new InvalidOperationException(
                    "Sage sales-order mapping configuration is missing DefaultTaxCode.");
            }
        }

        private string ResolveDataset(ApprovedTransactionForSageReadModel source)
        {
            var dataset = !string.IsNullOrWhiteSpace(source.Dataset)
                ? source.Dataset.Trim()
                : (_options.DefaultDataset ?? string.Empty).Trim();

            dataset = dataset.ToLowerInvariant();

            return dataset switch
            {
                "group" => "group",
                "asbestos" => "asbestos",
                _ => throw new InvalidOperationException(
                    $"Unsupported Sage dataset '{dataset}'. Valid values are 'group' or 'asbestos'.")
            };
        }

        private static string? ResolveCustomerOrderNumber(ApprovedTransactionForSageReadModel source)
        {
            var reference = source.GetPreferredExternalReference();
            return string.IsNullOrWhiteSpace(reference) ? null : reference;
        }

        private static DateTime? ResolveDocumentDate(ApprovedTransactionForSageReadModel source)
        {
            var preferred = source.GetPreferredDocumentDateUtc();

            if (!preferred.HasValue)
            {
                return null;
            }

            return DateTime.SpecifyKind(preferred.Value.Date, DateTimeKind.Utc);
        }

        private bool ResolveUseInvoiceAddress(ApprovedTransactionForSageReadModel source)
        {
            return source.UseInvoiceAddress ?? _options.UseInvoiceAddress;
        }

        private bool ResolveAllowCreditLimitException(ApprovedTransactionForSageReadModel source)
        {
            return source.AllowCreditLimitException ?? _options.AllowCreditLimitException;
        }

        private bool ResolveOverrideOnHold(ApprovedTransactionForSageReadModel source)
        {
            return source.OverrideOnHold ?? _options.OverrideOnHold;
        }

        private string? ResolveAnalysisCode01(ApprovedTransactionForSageReadModel source)
        {
            if (!string.IsNullOrWhiteSpace(source.AnalysisCode01Value))
            {
                return source.AnalysisCode01Value.Trim();
            }

            if (!string.IsNullOrWhiteSpace(_options.AnalysisCode01Value))
            {
                return _options.AnalysisCode01Value.Trim();
            }

            return null;
        }

        private string? ResolveAnalysisCode02(ApprovedTransactionForSageReadModel source)
        {
            if (!string.IsNullOrWhiteSpace(source.AnalysisCode02Value))
            {
                return source.AnalysisCode02Value.Trim();
            }

            if (!string.IsNullOrWhiteSpace(_options.AnalysisCode02Value))
            {
                return _options.AnalysisCode02Value.Trim();
            }

            return null;
        }

        private string? ResolveAnalysisCode03(ApprovedTransactionForSageReadModel source)
        {
            if (!string.IsNullOrWhiteSpace(source.AnalysisCode03Value))
            {
                return source.AnalysisCode03Value.Trim();
            }

            if (!string.IsNullOrWhiteSpace(source.JobNumber))
            {
                return source.JobNumber.Trim();
            }

            if (!string.IsNullOrWhiteSpace(_options.AnalysisCode03Value))
            {
                return _options.AnalysisCode03Value.Trim();
            }

            return null;
        }

        private string ResolveLineType(ApprovedTransactionForSageLineReadModel line)
        {
            if (!string.IsNullOrWhiteSpace(line.LineType))
            {
                return line.LineType.Trim();
            }

            if (!string.IsNullOrWhiteSpace(_options.DefaultLineType))
            {
                return _options.DefaultLineType.Trim();
            }

            return "Free Text";
        }

        private int ResolveQuantity(
            ApprovedTransactionForSageLineReadModel line,
            ApprovedTransactionForSageReadModel source)
        {
            if (line.Quantity <= 0)
            {
                return 1;
            }

            var rounded = decimal.Round(line.Quantity, 0, MidpointRounding.AwayFromZero);

            if (rounded < 1)
            {
                return 1;
            }

            if (rounded > int.MaxValue)
            {
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid}, line {line.LineId} quantity exceeds Int32 range.");
            }

            return Convert.ToInt32(rounded, CultureInfo.InvariantCulture);
        }

        private decimal ResolveUnitPrice(
            ApprovedTransactionForSageLineReadModel line,
            int quantity,
            ApprovedTransactionForSageReadModel source)
        {
            decimal unitPrice;

            if (line.UnitPrice > 0)
            {
                unitPrice = line.UnitPrice;
            }
            else if (line.NetAmount > 0 && quantity > 0)
            {
                unitPrice = line.NetAmount / quantity;
            }
            else
            {
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid}, line {line.LineId} has no valid unit price basis.");
            }

            unitPrice = decimal.Round(unitPrice, 2, MidpointRounding.AwayFromZero);

            if (unitPrice <= 0)
            {
                throw new InvalidOperationException(
                    $"Transaction {source.TransactionGuid}, line {line.LineId} resolved unitPrice must be greater than zero.");
            }

            return unitPrice;
        }

        private string ResolveNominalRef(
            ApprovedTransactionForSageLineReadModel line,
            ApprovedTransactionForSageReadModel source)
        {
            if (!string.IsNullOrWhiteSpace(line.NominalCode))
            {
                return line.NominalCode.Trim();
            }

            return _options.DefaultNominalRef.Trim();
        }

        private string? ResolveNominalCC(ApprovedTransactionForSageLineReadModel line)
        {
            if (!string.IsNullOrWhiteSpace(line.CostCentreCode))
            {
                return line.CostCentreCode.Trim();
            }

            return TrimOrNull(_options.DefaultNominalCC);
        }

        private string? ResolveNominalDept(ApprovedTransactionForSageLineReadModel line)
        {
            if (!string.IsNullOrWhiteSpace(line.DepartmentCode))
            {
                return line.DepartmentCode.Trim();
            }

            return TrimOrNull(_options.DefaultNominalDept);
        }

        private int? ResolveTaxCode(ApprovedTransactionForSageLineReadModel line)
        {
            if (!string.IsNullOrWhiteSpace(line.VatCode)
                && int.TryParse(line.VatCode.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed))
            {
                return parsed;
            }

            return _options.DefaultTaxCode;
        }

        private static string BuildLineDescription(ApprovedTransactionForSageLineReadModel line)
        {
            return line.Description.Trim();
        }

        private static string? TrimOrNull(string? value)
        {
            return string.IsNullOrWhiteSpace(value)
                ? null
                : value.Trim();
        }
    }
}