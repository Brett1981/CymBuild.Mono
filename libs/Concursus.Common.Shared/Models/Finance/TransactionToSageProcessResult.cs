using System;

namespace Concursus.Common.Shared.Models.Finance
{
    /// <summary>
    /// Final structured result returned by the transaction-to-Sage orchestrator.
    /// </summary>
    public sealed class TransactionToSageProcessResult
    {
        /// <summary>
        /// Overall process status.
        /// </summary>
        public TransactionToSageProcessStatus Status { get; set; } = TransactionToSageProcessStatus.Unknown;

        /// <summary>
        /// True when the orchestration completed successfully.
        /// </summary>
        public bool IsSuccess { get; set; }

        /// <summary>
        /// True when the transaction had already been successfully processed earlier.
        /// </summary>
        public bool IsAlreadyProcessed { get; set; }

        /// <summary>
        /// True when the failure can be retried safely.
        /// </summary>
        public bool IsRetryableFailure { get; set; }

        /// <summary>
        /// Human-readable message for diagnostics and logging.
        /// </summary>
        public string Message { get; set; } = string.Empty;

        /// <summary>
        /// Optional machine-readable failure code.
        /// </summary>
        public string FailureCode { get; set; } = string.Empty;

        /// <summary>
        /// Approved transition guid that initiated processing.
        /// </summary>
        public Guid TransitionGuid { get; set; }

        /// <summary>
        /// Approved transaction guid that was processed.
        /// </summary>
        public Guid TransactionGuid { get; set; }

        /// <summary>
        /// Optional returned Sage order identifier/reference.
        /// </summary>
        public string SageOrderId { get; set; } = string.Empty;

        /// <summary>
        /// Optional returned Sage order/reference number.
        /// </summary>
        public string SageOrderNumber { get; set; } = string.Empty;

        /// <summary>
        /// UTC timestamp when processing finished.
        /// </summary>
        public DateTime CompletedOnUtc { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// Creates a success result.
        /// </summary>
        public static TransactionToSageProcessResult Success(
            Guid transitionGuid,
            Guid transactionGuid,
            string sageOrderId,
            string sageOrderNumber,
            string message = "")
        {
            return new TransactionToSageProcessResult
            {
                Status = TransactionToSageProcessStatus.Succeeded,
                IsSuccess = true,
                IsAlreadyProcessed = false,
                IsRetryableFailure = false,
                Message = message ?? string.Empty,
                TransitionGuid = transitionGuid,
                TransactionGuid = transactionGuid,
                SageOrderId = sageOrderId ?? string.Empty,
                SageOrderNumber = sageOrderNumber ?? string.Empty,
                CompletedOnUtc = DateTime.UtcNow
            };
        }

        /// <summary>
        /// Creates an already-processed result.
        /// </summary>
        public static TransactionToSageProcessResult AlreadyProcessed(
            Guid transitionGuid,
            Guid transactionGuid,
            string sageOrderId,
            string sageOrderNumber,
            string message = "")
        {
            return new TransactionToSageProcessResult
            {
                Status = TransactionToSageProcessStatus.AlreadyProcessed,
                IsSuccess = true,
                IsAlreadyProcessed = true,
                IsRetryableFailure = false,
                Message = message ?? string.Empty,
                TransitionGuid = transitionGuid,
                TransactionGuid = transactionGuid,
                SageOrderId = sageOrderId ?? string.Empty,
                SageOrderNumber = sageOrderNumber ?? string.Empty,
                CompletedOnUtc = DateTime.UtcNow
            };
        }

        /// <summary>
        /// Creates a non-eligible result.
        /// </summary>
        public static TransactionToSageProcessResult NotEligible(
            Guid transitionGuid,
            Guid transactionGuid,
            string message,
            string failureCode = "")
        {
            return new TransactionToSageProcessResult
            {
                Status = TransactionToSageProcessStatus.NotEligible,
                IsSuccess = false,
                IsAlreadyProcessed = false,
                IsRetryableFailure = false,
                Message = message ?? string.Empty,
                FailureCode = failureCode ?? string.Empty,
                TransitionGuid = transitionGuid,
                TransactionGuid = transactionGuid,
                CompletedOnUtc = DateTime.UtcNow
            };
        }

        /// <summary>
        /// Creates a retryable failure result.
        /// </summary>
        public static TransactionToSageProcessResult RetryableFailure(
            Guid transitionGuid,
            Guid transactionGuid,
            string message,
            string failureCode = "")
        {
            return new TransactionToSageProcessResult
            {
                Status = TransactionToSageProcessStatus.FailedRetryable,
                IsSuccess = false,
                IsAlreadyProcessed = false,
                IsRetryableFailure = true,
                Message = message ?? string.Empty,
                FailureCode = failureCode ?? string.Empty,
                TransitionGuid = transitionGuid,
                TransactionGuid = transactionGuid,
                CompletedOnUtc = DateTime.UtcNow
            };
        }

        /// <summary>
        /// Creates a non-retryable failure result.
        /// </summary>
        public static TransactionToSageProcessResult NonRetryableFailure(
            Guid transitionGuid,
            Guid transactionGuid,
            string message,
            string failureCode = "")
        {
            return new TransactionToSageProcessResult
            {
                Status = TransactionToSageProcessStatus.FailedNonRetryable,
                IsSuccess = false,
                IsAlreadyProcessed = false,
                IsRetryableFailure = false,
                Message = message ?? string.Empty,
                FailureCode = failureCode ?? string.Empty,
                TransitionGuid = transitionGuid,
                TransactionGuid = transactionGuid,
                CompletedOnUtc = DateTime.UtcNow
            };
        }

        /// <summary>
        /// Creates a skipped result.
        /// </summary>
        public static TransactionToSageProcessResult Skipped(
            Guid transitionGuid,
            Guid transactionGuid,
            string message)
        {
            return new TransactionToSageProcessResult
            {
                Status = TransactionToSageProcessStatus.Skipped,
                IsSuccess = true,
                IsAlreadyProcessed = false,
                IsRetryableFailure = false,
                Message = message ?? string.Empty,
                TransitionGuid = transitionGuid,
                TransactionGuid = transactionGuid,
                CompletedOnUtc = DateTime.UtcNow
            };
        }
    }
}