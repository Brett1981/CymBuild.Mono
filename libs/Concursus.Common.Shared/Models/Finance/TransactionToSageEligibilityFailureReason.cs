namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Structured reason explaining why a transaction cannot be submitted to Sage.
    /// </summary>
    public enum TransactionToSageEligibilityFailureReason
    {
        None = 0,
        TransitionNotFound = 1,
        TransactionNotFound = 2,
        TransactionInactive = 3,
        TransactionStillBatched = 4,
        MissingTransactionNumber = 5,
        MissingInvoiceNumber = 6,
        MissingCustomerMapping = 7,
        MissingLines = 8,
        InvalidLineData = 9,
        AlreadySubmitted = 10,
        SageIntegrationDisabled = 11,
        MissingRequiredFinancialData = 12
    }
}