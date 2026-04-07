using Concursus.Common.Shared.Models.Finance;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Validates whether an approved transaction remains eligible for Sage submission.
    /// </summary>
    public interface ITransactionToSageEligibilityValidator
    {
        /// <summary>
        /// Validates the supplied approved transaction read model and returns a structured result.
        /// </summary>
        /// <param name="transaction">The approved transaction read model to validate.</param>
        /// <param name="sageIntegrationEnabled">True when Sage integration is enabled in configuration.</param>
        /// <param name="alreadySubmitted">True when the transaction has already been successfully submitted to Sage.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>A structured eligibility result.</returns>
        Task<TransactionToSageEligibilityResult> ValidateAsync(
            ApprovedTransactionForSageReadModel? transaction,
            bool sageIntegrationEnabled,
            bool alreadySubmitted,
            CancellationToken cancellationToken = default);
    }
}