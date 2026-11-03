using Concursus.API.Services.RecordExpiry;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using Xunit;

namespace Concursus.API.Tests.RecordExpiry;

public sealed class RecordExpiryScheduledWorkerTests
{
    private static readonly Guid ServiceUser = Guid.Parse("1E7A4894-54AA-4CB4-9E54-C697ABB32F74");

    [Fact]
    public async Task RunOnce_WhenDisabled_DoesNotCallTheDatabase()
    {
        var repo = new Mock<IRecordExpiryRepository>(MockBehavior.Strict);
        var worker = CreateWorker(repo.Object, new RecordExpiryOptions { Enabled = false, ServiceUserGuid = ServiceUser });

        var result = await worker.RunOnceAsync(CancellationToken.None);

        Assert.Null(result);
    }

    [Fact]
    public async Task RunOnce_WithoutServiceUser_DoesNotCallTheDatabase()
    {
        var repo = new Mock<IRecordExpiryRepository>(MockBehavior.Strict);
        var worker = CreateWorker(repo.Object, new RecordExpiryOptions { Enabled = true, ServiceUserGuid = Guid.Empty });

        var result = await worker.RunOnceAsync(CancellationToken.None);

        Assert.Null(result);
    }

    [Fact]
    public async Task RunOnce_PassesTheConfiguredLimitsToTheProcedure()
    {
        var expected = new RecordExpiryRunResult(true, 3, 1, 2, [new RecordExpiryFailure("Quote", Guid.NewGuid(), "boom")]);
        var repo = new Mock<IRecordExpiryRepository>(MockBehavior.Strict);
        repo.Setup(r => r.ExpireOverdueAsync(ServiceUser, 250, 14, 120, It.IsAny<CancellationToken>()))
            .ReturnsAsync(expected);

        var worker = CreateWorker(repo.Object, new RecordExpiryOptions
        {
            Enabled = true,
            ServiceUserGuid = ServiceUser,
            MaxRecordsPerRun = 250,
            NotifyWithinDays = 14,
            CommandTimeoutSeconds = 120
        });

        var result = await worker.RunOnceAsync(CancellationToken.None);

        Assert.Same(expected, result);
        repo.VerifyAll();
    }

    [Fact]
    public void OptionsDefaults_RunHourlyInBoundedBatchesWithAOneWeekNotifyWindow()
    {
        var options = new RecordExpiryOptions();

        Assert.True(options.Enabled);
        Assert.Equal(3600, options.IntervalSeconds);
        Assert.Equal(Guid.Empty, options.ServiceUserGuid);
        Assert.Equal(500, options.MaxRecordsPerRun);
        Assert.Equal(7, options.NotifyWithinDays);
        Assert.Equal(600, options.CommandTimeoutSeconds);
        Assert.Equal("RecordExpiry", RecordExpiryOptions.SectionName);
    }

    private static RecordExpiryScheduledWorker CreateWorker(IRecordExpiryRepository repo, RecordExpiryOptions configured)
    {
        var options = new Mock<IOptionsMonitor<RecordExpiryOptions>>();
        options.SetupGet(x => x.CurrentValue).Returns(configured);

        return new RecordExpiryScheduledWorker(repo, options.Object, Mock.Of<ILogger<RecordExpiryScheduledWorker>>());
    }
}
