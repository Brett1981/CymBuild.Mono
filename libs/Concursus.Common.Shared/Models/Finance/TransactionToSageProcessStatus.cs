namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Overall outcome of an approved transaction Sage submission attempt.
    /// </summary>
    public enum TransactionToSageProcessStatus
    {
        Unknown = 0,
        Succeeded = 1,
        AlreadyProcessed = 2,
        NotEligible = 3,
        ValidationFailed = 4,
        FailedRetryable = 5,
        FailedNonRetryable = 6,
        Skipped = 7
    }
}