namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Result of validating whether an approved transaction remains eligible for Sage submission.
    /// </summary>
    public sealed class TransactionToSageEligibilityResult
    {
        /// <summary>
        /// True when the transaction can proceed to idempotency and submission.
        /// </summary>
        public bool IsEligible { get; set; }

        /// <summary>
        /// Structured reason for failure where not eligible.
        /// </summary>
        public TransactionToSageEligibilityFailureReason FailureReason { get; set; } =
            TransactionToSageEligibilityFailureReason.None;

        /// <summary>
        /// Human-readable explanation for logging and diagnostics.
        /// </summary>
        public string Message { get; set; } = string.Empty;

        /// <summary>
        /// Creates a success result.
        /// </summary>
        public static TransactionToSageEligibilityResult Eligible()
        {
            return new TransactionToSageEligibilityResult
            {
                IsEligible = true,
                FailureReason = TransactionToSageEligibilityFailureReason.None,
                Message = string.Empty
            };
        }

        /// <summary>
        /// Creates a failed eligibility result.
        /// </summary>
        public static TransactionToSageEligibilityResult NotEligible(
            TransactionToSageEligibilityFailureReason reason,
            string message)
        {
            return new TransactionToSageEligibilityResult
            {
                IsEligible = false,
                FailureReason = reason,
                Message = message ?? string.Empty
            };
        }
    }
}