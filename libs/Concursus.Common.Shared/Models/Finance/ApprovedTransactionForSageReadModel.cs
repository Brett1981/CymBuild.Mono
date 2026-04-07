using System;
using System.Collections.Generic;
using System.Linq;

namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Deterministic read model containing all data required to assess and submit
    /// an approved finance transaction to Sage.
    ///
    /// Phase 5 note:
    /// This remains a CymBuild-facing read model, not the direct wrapper request contract.
    /// The downstream mapper is responsible for converting this richer model into the exact
    /// POST /api/sales-orders payload required by the Sage REST-wrapper.
    ///
    /// Existing fields and annotations have been preserved.
    /// Additional fields are additive only and support the corrected wrapper mapping.
    /// </summary>
    public sealed class ApprovedTransactionForSageReadModel
    {
        /// <summary>
        /// Guid of the transaction batch transition that triggered processing.
        /// </summary>
        public Guid TransitionGuid { get; set; }

        /// <summary>
        /// Database identifier of the transaction batch transition that triggered processing.
        /// </summary>
        public long TransitionId { get; set; }

        /// <summary>
        /// UTC timestamp when the approval transition occurred.
        /// </summary>
        public DateTime TransitionOccurredOnUtc { get; set; }

        /// <summary>
        /// Guid of the approved finance transaction.
        /// </summary>
        public Guid TransactionGuid { get; set; }

        /// <summary>
        /// Database identifier of the approved finance transaction.
        /// </summary>
        public long TransactionId { get; set; }

        /// <summary>
        /// Finance transaction number/reference.
        /// </summary>
        public string TransactionNumber { get; set; } = string.Empty;

        /// <summary>
        /// Whether the transaction is currently batched.
        /// Expected to be false for an approved transaction ready for Sage submission.
        /// </summary>
        public bool Batched { get; set; }

        /// <summary>
        /// Current row status of the transaction.
        /// </summary>
        public byte RowStatus { get; set; }

        /// <summary>
        /// Optional job identifier linked to the transaction.
        /// </summary>
        public int? JobId { get; set; }

        /// <summary>
        /// Optional account identifier linked to the transaction.
        /// </summary>
        public int? AccountId { get; set; }

        /// <summary>
        /// Related organisational unit identifier.
        /// </summary>
        public int? OrganisationalUnitId { get; set; }

        /// <summary>
        /// Transaction date in UTC or local persisted date context as supplied by source data.
        ///
        /// This is the primary source for the wrapper documentDate value.
        /// </summary>
        public DateTime? TransactionDateUtc { get; set; }

        /// <summary>
        /// Optional due/expected date.
        /// </summary>
        public DateTime? ExpectedDateUtc { get; set; }

        /// <summary>
        /// Optional CymBuild invoice/reference number used for Sage submission.
        ///
        /// In the corrected Phase 5 mapping this is the preferred source for
        /// customerOrderNo on the wrapper contract.
        /// </summary>
        public string InvoiceNumber { get; set; } = string.Empty;

        /// <summary>
        /// Optional existing Sage transaction/order reference if one has already been recorded.
        /// </summary>
        public string ExistingSageReference { get; set; } = string.Empty;

        /// <summary>
        /// Related customer/account display name.
        /// </summary>
        public string CustomerName { get; set; } = string.Empty;

        /// <summary>
        /// Optional mapped Sage customer account/reference code.
        ///
        /// In the corrected Phase 5 mapping this is the source for accountReference
        /// and should come from SCrm.Accounts.Code.
        /// </summary>
        public string SageCustomerReference { get; set; } = string.Empty;

        /// <summary>
        /// Customer email where available.
        /// </summary>
        public string CustomerEmail { get; set; } = string.Empty;

        /// <summary>
        /// Customer contact/display name where available.
        /// </summary>
        public string CustomerContactName { get; set; } = string.Empty;

        /// <summary>
        /// Primary address line.
        /// </summary>
        public string BillingAddressLine1 { get; set; } = string.Empty;

        /// <summary>
        /// Secondary address line.
        /// </summary>
        public string BillingAddressLine2 { get; set; } = string.Empty;

        /// <summary>
        /// Tertiary address line.
        /// </summary>
        public string BillingAddressLine3 { get; set; } = string.Empty;

        /// <summary>
        /// Billing town/city.
        /// </summary>
        public string BillingTown { get; set; } = string.Empty;

        /// <summary>
        /// Billing county/state.
        /// </summary>
        public string BillingCounty { get; set; } = string.Empty;

        /// <summary>
        /// Billing postcode/zip.
        /// </summary>
        public string BillingPostCode { get; set; } = string.Empty;

        /// <summary>
        /// Billing country.
        /// </summary>
        public string BillingCountry { get; set; } = string.Empty;

        /// <summary>
        /// Net total for the transaction.
        /// </summary>
        public decimal NetAmount { get; set; }

        /// <summary>
        /// VAT/tax total for the transaction.
        /// </summary>
        public decimal VatAmount { get; set; }

        /// <summary>
        /// Gross total for the transaction.
        /// </summary>
        public decimal GrossAmount { get; set; }

        /// <summary>
        /// Currency code where applicable. Defaults to GBP.
        ///
        /// Note:
        /// The current wrapper contract does not require this field,
        /// but it is retained because it remains useful for auditability
        /// and future expansion.
        /// </summary>
        public string CurrencyCode { get; set; } = "GBP";

        /// <summary>
        /// User id responsible for the approval transition where available.
        /// </summary>
        public int? ActorIdentityId { get; set; }

        /// <summary>
        /// Surveyor identity id where available.
        /// </summary>
        public int? SurveyorIdentityId { get; set; }

        /// <summary>
        /// Approval transition comment or finance note where available.
        /// </summary>
        public string ApprovalComment { get; set; } = string.Empty;

        /// <summary>
        /// All transaction lines to be mapped into Sage sales order lines.
        /// </summary>
        public List<ApprovedTransactionForSageLineReadModel> Lines { get; set; } = new();

        /// <summary>
        /// Optional job guid linked to the transaction.
        /// Additive for Phase 5 to support deterministic audit and downstream traceability.
        /// </summary>
        public Guid? JobGuid { get; set; }

        /// <summary>
        /// Optional CymBuild job number/reference.
        /// Commonly useful as an analysis code or audit reference.
        /// </summary>
        public string JobNumber { get; set; } = string.Empty;

        /// <summary>
        /// Optional job description / title.
        /// Retained for enrichment, audit and diagnostics.
        /// </summary>
        public string JobDescription { get; set; } = string.Empty;

        /// <summary>
        /// Optional purchase order number from the CymBuild transaction/header.
        /// Retained even though the current wrapper contract does not require it directly,
        /// because it may be useful for future wrapper expansion or audit persistence.
        /// </summary>
        public string PurchaseOrderNumber { get; set; } = string.Empty;

        /// <summary>
        /// Optional explicit dataset override for the wrapper submission.
        /// When blank, the mapper should use configured defaults.
        /// Valid wrapper values are expected to be things like "group" or "asbestos".
        /// </summary>
        public string Dataset { get; set; } = string.Empty;

        /// <summary>
        /// Optional wrapper/header analysis code 1 override.
        /// </summary>
        public string AnalysisCode01Value { get; set; } = string.Empty;

        /// <summary>
        /// Optional wrapper/header analysis code 2 override.
        /// </summary>
        public string AnalysisCode02Value { get; set; } = string.Empty;

        /// <summary>
        /// Optional wrapper/header analysis code 3 override.
        /// This is commonly a good place to pass JobNumber when present.
        /// </summary>
        public string AnalysisCode03Value { get; set; } = string.Empty;

        /// <summary>
        /// Optional wrapper flag override to use the invoice address.
        /// When null, the mapper should fall back to configuration defaults.
        /// </summary>
        public bool? UseInvoiceAddress { get; set; }

        /// <summary>
        /// Optional wrapper flag override to allow credit limit exceptions.
        /// When null, the mapper should fall back to configuration defaults.
        /// </summary>
        public bool? AllowCreditLimitException { get; set; }

        /// <summary>
        /// Optional wrapper flag override to override on-hold restrictions.
        /// When null, the mapper should fall back to configuration defaults.
        /// </summary>
        public bool? OverrideOnHold { get; set; }

        /// <summary>
        /// Returns true when the transaction has at least one active line.
        /// </summary>
        public bool HasLines => Lines.Any();

        /// <summary>
        /// Returns only active lines.
        /// </summary>
        public IReadOnlyList<ApprovedTransactionForSageLineReadModel> ActiveLines =>
            Lines.Where(x => x.RowStatus != 0 && x.RowStatus != 254).ToList();

        /// <summary>
        /// Returns only lines that are active and pass the submission usability check.
        /// </summary>
        public IReadOnlyList<ApprovedTransactionForSageLineReadModel> UsableLines =>
            Lines.Where(x => x.IsUsableForSubmission()).ToList();

        /// <summary>
        /// Returns the preferred document date for downstream submission.
        ///
        /// Priority:
        /// 1. TransactionDateUtc
        /// 2. ExpectedDateUtc
        /// 3. null
        /// </summary>
        public DateTime? GetPreferredDocumentDateUtc()
        {
            if (TransactionDateUtc.HasValue)
            {
                return TransactionDateUtc.Value;
            }

            if (ExpectedDateUtc.HasValue)
            {
                return ExpectedDateUtc.Value;
            }

            return null;
        }

        /// <summary>
        /// Returns true when the transaction contains enough information to attempt
        /// wrapper submission.
        ///
        /// This does not validate every downstream mapping rule. It is intended as a
        /// light-weight guard before mapper-level validation.
        /// </summary>
        public bool IsUsableForSubmission()
        {
            return RowStatus != 0
                && RowStatus != 254
                && !Batched
                && TransactionGuid != Guid.Empty
                && !string.IsNullOrWhiteSpace(SageCustomerReference)
                && !string.IsNullOrWhiteSpace(GetPreferredExternalReference())
                && UsableLines.Count > 0;
        }

        /// <summary>
        /// Normalised external reference for downstream submission.
        /// </summary>
        public string GetPreferredExternalReference()
        {
            if (!string.IsNullOrWhiteSpace(InvoiceNumber))
            {
                return InvoiceNumber.Trim();
            }

            if (!string.IsNullOrWhiteSpace(TransactionNumber))
            {
                return TransactionNumber.Trim();
            }

            return TransactionGuid.ToString("D");
        }

        /// <summary>
        /// Returns the best available job or transaction reference for analysis/audit purposes.
        /// </summary>
        public string GetPreferredJobOrTransactionReference()
        {
            if (!string.IsNullOrWhiteSpace(JobNumber))
            {
                return JobNumber.Trim();
            }

            return GetPreferredExternalReference();
        }
    }
}