using Concursus.API.Sage.SOAP;
using Concursus.API.Services.Finance;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using Xunit;

namespace Concursus.API.Tests.Finance;

public sealed class HostedWorkerLifecycleTests
{
    [Theory]
    [InlineData(false, true)]
    [InlineData(true, false)]
    public async Task SageTransactionSubmissionWorker_DisabledPathStartsAndStopsWithoutCreatingScope(
        bool workerEnabled,
        bool sageEnabled)
    {
        var scopeFactory = new Mock<IServiceScopeFactory>();
        var workerOptions = CreateOptionsMonitor(new SageTransactionSubmissionWorkerOptions
        {
            Enabled = workerEnabled,
            IntervalSeconds = 1
        });
        var sageOptions = CreateOptionsMonitor(new SageApiOptions
        {
            Enabled = sageEnabled,
            BaseUrl = "https://sage.test"
        });
        var worker = new SageTransactionSubmissionWorker(
            scopeFactory.Object,
            sageOptions.Object,
            workerOptions.Object,
            Mock.Of<ILogger<SageTransactionSubmissionWorker>>());

        await worker.StartAsync(CancellationToken.None);
        await Task.Delay(25);
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        await worker.StopAsync(timeout.Token);

        scopeFactory.Verify(x => x.CreateScope(), Times.Never);
    }

    [Theory]
    [InlineData(false, true)]
    [InlineData(true, false)]
    public async Task SageInboundPaymentSyncWorker_DisabledPathStartsAndStopsWithoutCreatingScope(
        bool workerEnabled,
        bool sageEnabled)
    {
        var scopeFactory = new Mock<IServiceScopeFactory>();
        var workerOptions = CreateOptionsMonitor(new SageInboundPaymentSyncWorkerOptions
        {
            Enabled = workerEnabled,
            IntervalSeconds = 1
        });
        var sageOptions = CreateOptionsMonitor(new SageApiOptions
        {
            Enabled = sageEnabled,
            BaseUrl = "https://sage.test"
        });
        var worker = new SageInboundPaymentSyncWorker(
            Mock.Of<ILogger<SageInboundPaymentSyncWorker>>(),
            scopeFactory.Object,
            workerOptions.Object,
            sageOptions.Object);

        await worker.StartAsync(CancellationToken.None);
        await Task.Delay(25);
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        await worker.StopAsync(timeout.Token);

        scopeFactory.Verify(x => x.CreateScope(), Times.Never);
    }

    private static Mock<IOptionsMonitor<T>> CreateOptionsMonitor<T>(T value)
        where T : class
    {
        var monitor = new Mock<IOptionsMonitor<T>>();
        monitor.SetupGet(x => x.CurrentValue).Returns(value);
        return monitor;
    }
}
