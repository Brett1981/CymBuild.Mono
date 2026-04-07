#nullable enable

using System.ComponentModel.DataAnnotations;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Phase 5 deterministic mapping defaults for CymBuild -> Sage REST-wrapper.
    ///
    /// These defaults intentionally hold the finance values that are fixed across
    /// the current implementation so the mapper remains deterministic and easy to audit.
    /// </summary>
    public sealed class SageSalesOrderMappingOptions
    {
        /// <summary>
        /// Wrapper dataset. Valid values are currently "group" or "asbestos".
        /// </summary>
        [Required]
        public string DefaultDataset { get; set; } = "group";

        /// <summary>
        /// Default line type for wrapper sales-order submission.
        /// </summary>
        [Required]
        public string DefaultLineType { get; set; } = "Free Text";

        /// <summary>
        /// Default nominal/ledger code.
        ///
        /// Per current finance rules this is fixed as 31010.
        /// </summary>
        [Required]
        public string DefaultNominalRef { get; set; } = "31010";

        /// <summary>
        /// Optional fallback cost centre.
        ///
        /// In the corrected implementation this should normally come from
        /// SCore.OrganisationalUnits.CostCentreCode via the related Job OU.
        /// </summary>
        public string DefaultNominalCC { get; set; } = string.Empty;

        /// <summary>
        /// Optional fallback department.
        ///
        /// In the corrected implementation this should normally come from
        /// SCore.OrganisationalUnits.CostCentreCode via the related Job OU.
        /// </summary>
        public string DefaultNominalDept { get; set; } = string.Empty;

        /// <summary>
        /// Default tax/VAT code.
        ///
        /// Per current finance rules this is fixed as 22.
        /// </summary>
        public int? DefaultTaxCode { get; set; } = 22;

        /// <summary>
        /// Whether the wrapper should use the invoice address.
        /// </summary>
        public bool UseInvoiceAddress { get; set; } = false;

        /// <summary>
        /// Whether the wrapper should allow credit limit exceptions.
        /// </summary>
        public bool AllowCreditLimitException { get; set; } = true;

        /// <summary>
        /// Whether the wrapper should override on-hold status.
        /// </summary>
        public bool OverrideOnHold { get; set; } = true;

        /// <summary>
        /// Optional static fallback for analysis code 1.
        /// </summary>
        public string AnalysisCode01Value { get; set; } = string.Empty;

        /// <summary>
        /// Optional static fallback for analysis code 2.
        /// </summary>
        public string AnalysisCode02Value { get; set; } = string.Empty;

        /// <summary>
        /// Optional static fallback for analysis code 3.
        /// If blank, the mapper should prefer the JobNumber where available.
        /// </summary>
        public string AnalysisCode03Value { get; set; } = string.Empty;
    }
}