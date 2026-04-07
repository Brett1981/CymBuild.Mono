using System;

namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Line-level read model for an approved transaction submitted to Sage.
    ///
    /// Phase 5 note:
    /// This model intentionally remains richer than the immediate mock/live wrapper contract.
    /// The downstream mapper will normalise these values into the specific
    /// POST /api/sales-orders line request shape expected by the Sage REST-wrapper.
    ///
    /// Existing fields and annotations have been preserved.
    /// Additional fields are additive only and exist to support deterministic
    /// finance mapping without losing backward compatibility.
    /// </summary>
    public sealed class ApprovedTransactionForSageLineReadModel
    {
        /// <summary>
        /// Database identifier of the source line/item.
        /// </summary>
        public long LineId { get; set; }

        /// <summary>
        /// Guid of the source line/item where available.
        /// </summary>
        public Guid? LineGuid { get; set; }

        /// <summary>
        /// Current row status of the line/item.
        /// </summary>
        public byte RowStatus { get; set; }

        /// <summary>
        /// Human-readable line reference/code where available.
        /// </summary>
        public string LineReference { get; set; } = string.Empty;

        /// <summary>
        /// Line description that should appear in Sage.
        /// This maps directly to the wrapper itemDescription field.
        /// </summary>
        public string Description { get; set; } = string.Empty;

        /// <summary>
        /// Optional product/service code.
        /// Not currently required by the wrapper sales-order contract,
        /// but retained for future use and richer finance mappings.
        /// </summary>
        public string ProductCode { get; set; } = string.Empty;

        /// <summary>
        /// Quantity to submit.
        ///
        /// Note:
        /// The wrapper contract currently expects an integer quantity >= 1.
        /// This model deliberately keeps decimal precision so that no original
        /// read-model capability is lost. The mapper is responsible for
        /// deterministic normalisation to an integer for outbound submission.
        /// </summary>
        public decimal Quantity { get; set; }

        /// <summary>
        /// Unit price excluding VAT/tax.
        ///
        /// For wrapper submission this maps to unitPrice.
        /// </summary>
        public decimal UnitPrice { get; set; }

        /// <summary>
        /// Net amount excluding VAT/tax.
        /// Retained for auditability, validation, and deterministic recalculation.
        /// </summary>
        public decimal NetAmount { get; set; }

        /// <summary>
        /// VAT/tax amount.
        /// Retained for auditability and downstream tax validation.
        /// </summary>
        public decimal VatAmount { get; set; }

        /// <summary>
        /// Gross amount including VAT/tax.
        /// Retained for auditability and cross-checking of line totals.
        /// </summary>
        public decimal GrossAmount { get; set; }

        /// <summary>
        /// VAT code to use in Sage where applicable.
        ///
        /// The wrapper contract currently expects an integer taxCode.
        /// This model deliberately keeps the original string representation so
        /// that raw source values are not lost. The mapper will parse or default it.
        /// </summary>
        public string VatCode { get; set; } = string.Empty;

        /// <summary>
        /// Nominal / ledger code where required by downstream finance mapping.
        ///
        /// This maps to the wrapper nominalRef field.
        /// </summary>
        public string NominalCode { get; set; } = string.Empty;

        /// <summary>
        /// Cost centre / department code where required by downstream finance mapping.
        ///
        /// This maps primarily to the wrapper nominalCC field unless overridden.
        /// </summary>
        public string CostCentreCode { get; set; } = string.Empty;

        /// <summary>
        /// Optional service date for the line.
        /// Retained for future reporting / enrichment even though it is not currently
        /// part of the wrapper line contract.
        /// </summary>
        public DateTime? ServiceDateUtc { get; set; }

        /// <summary>
        /// Optional department code for downstream finance mapping.
        ///
        /// This is additive for Phase 5 and supports mapping to the wrapper nominalDept field
        /// without overloading CostCentreCode.
        /// </summary>
        public string DepartmentCode { get; set; } = string.Empty;

        /// <summary>
        /// Optional invoice request item identifier where the line originated from
        /// invoice automation or manual invoice request item generation.
        ///
        /// This is retained for audit, troubleshooting, and payload traceability.
        /// </summary>
        public long? InvoiceRequestItemId { get; set; }

        /// <summary>
        /// Optional activity identifier where the transaction line originated
        /// from an activity-based invoice event.
        /// </summary>
        public long? ActivityId { get; set; }

        /// <summary>
        /// Optional milestone identifier where the transaction line originated
        /// from a milestone-based invoice event.
        /// </summary>
        public long? MilestoneId { get; set; }

        /// <summary>
        /// Optional payment stage / commercial stage label.
        /// This is not required by the wrapper contract but is useful for audit
        /// and deterministic line description enrichment where appropriate.
        /// </summary>
        public string JobPaymentStageName { get; set; } = string.Empty;

        /// <summary>
        /// Optional explicit line type override for the wrapper contract.
        ///
        /// When blank, the mapper should fall back to the configured default
        /// (typically "Free Text").
        /// </summary>
        public string LineType { get; set; } = string.Empty;

        /// <summary>
        /// Returns true when the line contains enough information to attempt mapping.
        ///
        /// Notes:
        /// - Quantity is validated here as per the existing model behaviour.
        /// - UnitPrice is not enforced here because some legacy/read scenarios derive it
        ///   from NetAmount during mapping.
        /// - Nominal/tax values are not enforced here because mapper defaults/configuration
        ///   may legally supply them.
        /// </summary>
        public bool IsUsableForSubmission()
        {
            return RowStatus != 0
                && RowStatus != 254
                && !string.IsNullOrWhiteSpace(Description)
                && Quantity > 0;
        }

        /// <summary>
        /// Returns true when the line is active according to CymBuild RowStatus rules.
        /// </summary>
        public bool IsActive()
        {
            return RowStatus != 0 && RowStatus != 254;
        }

        /// <summary>
        /// Returns the most appropriate outward-facing reference for diagnostics and audit.
        /// </summary>
        public string GetPreferredReference()
        {
            if (!string.IsNullOrWhiteSpace(LineReference))
            {
                return LineReference.Trim();
            }

            if (LineGuid.HasValue && LineGuid.Value != Guid.Empty)
            {
                return LineGuid.Value.ToString("D");
            }

            return LineId.ToString();
        }
    }
}