using Concursus.Common.Shared.Models.Finance;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Default implementation of the transaction-to-Sage eligibility validator.
    /// This validator applies deterministic business and technical rules before
    /// any idempotency claim or outbound Sage submission is attempted.
    /// </summary>
    public sealed class TransactionToSageEligibilityValidator : ITransactionToSageEligibilityValidator
    {
        /// <inheritdoc />
        public Task<TransactionToSageEligibilityResult> ValidateAsync(
            ApprovedTransactionForSageReadModel? transaction,
            bool sageIntegrationEnabled,
            bool alreadySubmitted,
            CancellationToken cancellationToken = default)
        {
            cancellationToken.ThrowIfCancellationRequested();

            if (transaction is null)
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.TransactionNotFound,
                        "The approved transaction could not be resolved from the transition record."));
            }

            if (!sageIntegrationEnabled)
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.SageIntegrationDisabled,
                        "Sage integration is currently disabled by configuration."));
            }

            if (transaction.TransitionGuid == Guid.Empty || transaction.TransitionId <= 0)
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.TransitionNotFound,
                        "The finance approval transition is missing or invalid."));
            }

            if (transaction.TransactionGuid == Guid.Empty || transaction.TransactionId <= 0)
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.TransactionNotFound,
                        "The finance transaction is missing or invalid."));
            }

            if (transaction.RowStatus == 0 || transaction.RowStatus == 254)
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.TransactionInactive,
                        "The finance transaction is inactive and cannot be submitted to Sage."));
            }

            if (transaction.Batched)
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.TransactionStillBatched,
                        "The finance transaction is still marked as batched and is not approved for Sage submission."));
            }

            if (string.IsNullOrWhiteSpace(transaction.TransactionNumber))
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.MissingTransactionNumber,
                        "The finance transaction number is required before Sage submission."));
            }

            if (string.IsNullOrWhiteSpace(transaction.InvoiceNumber))
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.MissingInvoiceNumber,
                        "The invoice number/reference is required before Sage submission."));
            }

            if (alreadySubmitted || !string.IsNullOrWhiteSpace(transaction.ExistingSageReference))
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.AlreadySubmitted,
                        "The finance transaction has already been submitted to Sage."));
            }

            if (string.IsNullOrWhiteSpace(transaction.CustomerName))
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.MissingCustomerMapping,
                        "The finance transaction is missing customer information required for Sage submission."));
            }

            if (string.IsNullOrWhiteSpace(transaction.SageCustomerReference))
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.MissingCustomerMapping,
                        "\"The finance transaction account is missing SCrm.Accounts.Code, which is required as the Sage customer reference.\""));
            }

            if (!transaction.HasLines || transaction.ActiveLines.Count == 0)
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.MissingLines,
                        "The finance transaction does not contain any active lines for Sage submission."));
            }

            foreach (ApprovedTransactionForSageLineReadModel line in transaction.ActiveLines)
            {
                if (!line.IsUsableForSubmission())
                {
                    return Task.FromResult(
                        TransactionToSageEligibilityResult.NotEligible(
                            TransactionToSageEligibilityFailureReason.InvalidLineData,
                            $"Transaction line {line.LineId} is not valid for Sage submission."));
                }

                if (line.NetAmount < 0m || line.VatAmount < 0m || line.GrossAmount < 0m)
                {
                    return Task.FromResult(
                        TransactionToSageEligibilityResult.NotEligible(
                            TransactionToSageEligibilityFailureReason.InvalidLineData,
                            $"Transaction line {line.LineId} contains negative financial values that are not supported for this submission flow."));
                }
            }

            if (transaction.NetAmount < 0m || transaction.VatAmount < 0m || transaction.GrossAmount < 0m)
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.MissingRequiredFinancialData,
                        "The finance transaction contains invalid negative totals for Sage submission."));
            }

            if (transaction.GrossAmount <= 0m)
            {
                return Task.FromResult(
                    TransactionToSageEligibilityResult.NotEligible(
                        TransactionToSageEligibilityFailureReason.MissingRequiredFinancialData,
                        "The finance transaction gross total must be greater than zero before Sage submission."));
            }

            return Task.FromResult(TransactionToSageEligibilityResult.Eligible());
        }
    }
}