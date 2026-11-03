using Concursus.API.Core;

namespace Concursus.API.Client.Tests.FormHelper;

public sealed class InvoiceScheduleConfigurationTotalsFormHelperTests
{
    [Fact]
    public async Task GetAsync_EmptyGuidReturnsDefaultWithoutCallingGrpc()
    {
        var invoker = new RecordingCallInvoker();
        var helper = FormHelperTestFactory.Create(invoker);

        var result = await helper.InvoiceScheduleConfigurationTotalsGetAsync(
            Guid.Empty,
            ct: TestContext.Current.CancellationToken);

        Assert.Equal(0m, result.MonthlyTotalAmount);
        Assert.Equal(0m, result.PercentageTotalPercentage);
        Assert.Equal(0m, result.PercentageTotalAmount);
        Assert.Equal(0m, result.ScheduleAmount);
        Assert.Null(result.Frequency);
        Assert.Null(invoker.LastRequest);
    }

    [Fact]
    public async Task GetAsync_MapsRequestUsingInvariantValues()
    {
        var scheduleGuid = Guid.Parse("E51A1736-149D-4519-90B6-82129F5A1C44");
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new InvoiceScheduleConfigurationTotalsGetResponse
            {
                MonthlyTotalAmount = 0,
                PercentageTotalPercentage = 0,
                PercentageTotalAmount = 0,
                ScheduleAmount = 0,
                Frequency = string.Empty
            }
        };
        var userService = new Concursus.API.Client.Models.UserService { UserId = 42 };
        var helper = FormHelperTestFactory.Create(invoker, userService);

        await helper.InvoiceScheduleConfigurationTotalsGetAsync(
            scheduleGuid,
            ct: TestContext.Current.CancellationToken);

        var request = Assert.IsType<InvoiceScheduleConfigurationTotalsGetRequest>(invoker.LastRequest);
        Assert.Equal(42, request.UserId);
        Assert.Equal(scheduleGuid.ToString(), request.InvoiceScheduleGuid);
        Assert.EndsWith(
            "/InvoiceScheduleConfigurationTotalsGet",
            Assert.IsType<string>(invoker.LastMethodFullName));
    }

    [Fact]
    public async Task GetAsync_MapsSuccessfulResponseIncludingFrequency()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new InvoiceScheduleConfigurationTotalsGetResponse
            {
                MonthlyTotalAmount = 1234.56,
                PercentageTotalPercentage = 50,
                PercentageTotalAmount = 617.28,
                ScheduleAmount = 2469.12,
                Frequency = "Quarterly"
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var result = await helper.InvoiceScheduleConfigurationTotalsGetAsync(
            Guid.NewGuid(),
            ct: TestContext.Current.CancellationToken);

        Assert.Equal(1234.56m, result.MonthlyTotalAmount);
        Assert.Equal(50m, result.PercentageTotalPercentage);
        Assert.Equal(617.28m, result.PercentageTotalAmount);
        Assert.Equal(2469.12m, result.ScheduleAmount);
        Assert.Equal("Quarterly", result.Frequency);
    }

    [Fact]
    public async Task GetAsync_MapsBlankFrequencyToNull()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new InvoiceScheduleConfigurationTotalsGetResponse
            {
                MonthlyTotalAmount = 0,
                PercentageTotalPercentage = 0,
                PercentageTotalAmount = 0,
                ScheduleAmount = 0,
                Frequency = string.Empty
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var result = await helper.InvoiceScheduleConfigurationTotalsGetAsync(
            Guid.NewGuid(),
            ct: TestContext.Current.CancellationToken);

        Assert.Null(result.Frequency);
    }

    [Fact]
    public async Task GetAsync_PropagatesServerError()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new InvoiceScheduleConfigurationTotalsGetResponse
            {
                ErrorReturned = "invoiceScheduleGuid must be a valid GUID."
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var exception = await Assert.ThrowsAsync<Exception>(() =>
            helper.InvoiceScheduleConfigurationTotalsGetAsync(
                Guid.NewGuid(),
                ct: TestContext.Current.CancellationToken));

        Assert.Equal("invoiceScheduleGuid must be a valid GUID.", exception.Message);
    }
}
