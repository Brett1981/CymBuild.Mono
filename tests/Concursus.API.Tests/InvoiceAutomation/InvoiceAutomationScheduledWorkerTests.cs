using Concursus.API.Services.InvoiceAutomation;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using Xunit;

namespace Concursus.API.Tests.InvoiceAutomation;

public sealed class InvoiceAutomationScheduledWorkerTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Constructor_AcceptsDisabledOrMissingRequesterConfiguration(bool enabled)
    {
        var repository = CreateRepository();
        var configuredOptions = new InvoiceAutomationOptions
        {
            Enabled = enabled,
            RequesterUserGuid = Guid.Empty,
            IntervalSeconds = 1
        };
        var options = new Mock<IOptionsMonitor<InvoiceAutomationOptions>>();
        options.SetupGet(x => x.CurrentValue).Returns(configuredOptions);

        var worker = new InvoiceAutomationScheduledWorker(
            repository,
            options.Object,
            Mock.Of<ILogger<InvoiceAutomationScheduledWorker>>());

        Assert.NotNull(worker);
        Assert.Equal(enabled, options.Object.CurrentValue.Enabled);
        Assert.Equal(Guid.Empty, options.Object.CurrentValue.RequesterUserGuid);
    }

    private static InvoiceAutomationRepository CreateRepository()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:ShoreDB"] = "Server=not-used;Database=not-used;Integrated Security=true;TrustServerCertificate=true"
            })
            .Build();

        return new InvoiceAutomationRepository(
            configuration,
            Mock.Of<ILogger<InvoiceAutomationRepository>>());
    }
}
