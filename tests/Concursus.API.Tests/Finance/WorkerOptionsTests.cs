using System.ComponentModel.DataAnnotations;
using Concursus.API.Services.Finance;
using Concursus.API.Services.InvoiceAutomation;
using Xunit;

namespace Concursus.API.Tests.Finance;

public sealed class WorkerOptionsTests
{
    [Fact]
    public void SageTransactionSubmissionWorkerOptions_DefaultsAreSafeAndEnabled()
    {
        var options = new SageTransactionSubmissionWorkerOptions();

        Assert.True(options.Enabled);
        Assert.Equal(10, options.IntervalSeconds);
        Assert.Equal(10, options.MaxAttempts);
        Assert.Equal(15, options.ClaimTimeoutMinutes);
        Assert.Equal("TransactionApprovedForSageSubmission", options.EventType);
        Assert.Empty(Validate(options));
    }

    [Theory]
    [InlineData(0, 10, 15)]
    [InlineData(10, 0, 15)]
    [InlineData(10, 10, 0)]
    public void SageTransactionSubmissionWorkerOptions_RejectsInvalidRanges(
        int intervalSeconds,
        int maxAttempts,
        int claimTimeoutMinutes)
    {
        var options = new SageTransactionSubmissionWorkerOptions
        {
            IntervalSeconds = intervalSeconds,
            MaxAttempts = maxAttempts,
            ClaimTimeoutMinutes = claimTimeoutMinutes
        };

        Assert.NotEmpty(Validate(options));
    }

    [Fact]
    public void SageInboundPaymentSyncWorkerOptions_DefaultsAreValid()
    {
        var options = new SageInboundPaymentSyncWorkerOptions();

        Assert.True(options.Enabled);
        Assert.Equal(60, options.IntervalSeconds);
        Assert.Equal(20, options.BatchSize);
        Assert.Equal(15, options.ClaimStaleAfterMinutes);
        Assert.Empty(Validate(options));
    }

    [Theory]
    [InlineData(0, 20, 15)]
    [InlineData(60, 0, 15)]
    [InlineData(60, 20, 0)]
    public void SageInboundPaymentSyncWorkerOptions_RejectsInvalidRanges(
        int intervalSeconds,
        int batchSize,
        int claimStaleAfterMinutes)
    {
        var options = new SageInboundPaymentSyncWorkerOptions
        {
            IntervalSeconds = intervalSeconds,
            BatchSize = batchSize,
            ClaimStaleAfterMinutes = claimStaleAfterMinutes
        };

        Assert.NotEmpty(Validate(options));
    }

    [Fact]
    public void InvoiceAutomationOptions_DefaultsRetainScheduledWorkerContract()
    {
        var options = new InvoiceAutomationOptions();

        Assert.True(options.Enabled);
        Assert.Equal(300, options.IntervalSeconds);
        Assert.Equal(Guid.Empty, options.RequesterUserGuid);
        Assert.Null(options.DefaultPaymentStatusGuid);
        Assert.Equal("Scheduled automation run", options.Notes);
        Assert.Equal("SFin.InvoiceAutomation.ScheduledWorker", options.SqlAppLockName);
        Assert.Equal(2000, options.SqlAppLockTimeoutMs);
        Assert.True(options.RunMaterialiseSweepEachTick);
    }

    private static IReadOnlyCollection<ValidationResult> Validate(object instance)
    {
        var results = new List<ValidationResult>();
        Validator.TryValidateObject(instance, new ValidationContext(instance), results, validateAllProperties: true);
        return results;
    }
}
