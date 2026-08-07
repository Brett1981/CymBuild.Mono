using Concursus.Common.Shared.Models.Finance;
using Xunit;

namespace Concursus.Common.Shared.Tests.Finance;

public sealed class FinanceResultFactoryTests
{
    [Fact]
    public void EligibilityFactories_SetConsistentFlagsAndReason()
    {
        var eligible = TransactionToSageEligibilityResult.Eligible();
        var notEligible = TransactionToSageEligibilityResult.NotEligible(
            TransactionToSageEligibilityFailureReason.MissingLines,
            "No lines");

        Assert.True(eligible.IsEligible);
        Assert.Equal(TransactionToSageEligibilityFailureReason.None, eligible.FailureReason);
        Assert.Empty(eligible.Message);

        Assert.False(notEligible.IsEligible);
        Assert.Equal(TransactionToSageEligibilityFailureReason.MissingLines, notEligible.FailureReason);
        Assert.Equal("No lines", notEligible.Message);
    }

    [Fact]
    public void ProcessResultFactories_SetConsistentOutcomeFlags()
    {
        var transitionGuid = Guid.NewGuid();
        var transactionGuid = Guid.NewGuid();
        var cases = new[]
        {
            new ResultCase(
                TransactionToSageProcessResult.Success(
                    transitionGuid, transactionGuid, "ID", "NUMBER"),
                TransactionToSageProcessStatus.Succeeded, true, false, false),
            new ResultCase(
                TransactionToSageProcessResult.AlreadyProcessed(
                    transitionGuid, transactionGuid, "ID", "NUMBER"),
                TransactionToSageProcessStatus.AlreadyProcessed, true, true, false),
            new ResultCase(
                TransactionToSageProcessResult.NotEligible(
                    transitionGuid, transactionGuid, "Not eligible", "not_eligible"),
                TransactionToSageProcessStatus.NotEligible, false, false, false),
            new ResultCase(
                TransactionToSageProcessResult.RetryableFailure(
                    transitionGuid, transactionGuid, "Retry", "retry"),
                TransactionToSageProcessStatus.FailedRetryable, false, false, true),
            new ResultCase(
                TransactionToSageProcessResult.NonRetryableFailure(
                    transitionGuid, transactionGuid, "Stop", "stop"),
                TransactionToSageProcessStatus.FailedNonRetryable, false, false, false),
            new ResultCase(
                TransactionToSageProcessResult.Skipped(
                    transitionGuid, transactionGuid, "Skipped"),
                TransactionToSageProcessStatus.Skipped, true, false, false)
        };

        foreach (var testCase in cases)
        {
            Assert.Equal(testCase.ExpectedStatus, testCase.Result.Status);
            Assert.Equal(testCase.ExpectedSuccess, testCase.Result.IsSuccess);
            Assert.Equal(testCase.ExpectedAlreadyProcessed, testCase.Result.IsAlreadyProcessed);
            Assert.Equal(testCase.ExpectedRetryable, testCase.Result.IsRetryableFailure);
            Assert.Equal(transitionGuid, testCase.Result.TransitionGuid);
            Assert.Equal(transactionGuid, testCase.Result.TransactionGuid);
            Assert.NotEqual(default(DateTime), testCase.Result.CompletedOnUtc);
        }
    }

    private sealed record ResultCase(
        TransactionToSageProcessResult Result,
        TransactionToSageProcessStatus ExpectedStatus,
        bool ExpectedSuccess,
        bool ExpectedAlreadyProcessed,
        bool ExpectedRetryable);
}
