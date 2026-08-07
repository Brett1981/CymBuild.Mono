using Concursus.API.Services.InvoiceAutomation;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Concursus.API.Tests.InvoiceAutomation;

public sealed class InvoiceAutomationRepositoryTests
{
    [Fact]
    public void Constructor_MissingConnectionStringFailsFast()
    {
        var configuration = new ConfigurationBuilder().Build();

        var exception = Assert.Throws<InvalidOperationException>(() => new InvoiceAutomationRepository(
            configuration,
            Mock.Of<ILogger<InvoiceAutomationRepository>>()));

        Assert.True(exception.Message.Contains("ConnectionStrings:ShoreDB", StringComparison.Ordinal));
    }

    [Fact]
    public async Task RunPhase4To6Async_EmptyRequesterGuidFailsBeforeSqlConnection()
    {
        var repository = CreateRepository();

        var exception = await Assert.ThrowsAsync<InvalidOperationException>(() => repository.RunPhase4To6Async(
            Guid.Parse("77777777-7777-7777-7777-777777777777"),
            Guid.Empty,
            defaultPaymentStatusGuid: null,
            notes: "test",
            nowUtc: new DateTime(2026, 8, 6, 8, 0, 0, DateTimeKind.Utc),
            ct: CancellationToken.None));

        Assert.True(exception.Message.Contains("RequesterUserGuid", StringComparison.Ordinal));
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
