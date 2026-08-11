using Concursus.API.Core;

namespace Concursus.API.Client.Tests.FormHelper;

public sealed class InvoiceScheduleMonthlySeriesFormHelperTests
{
    [Fact]
    public async Task GenerateAsync_RejectsEmptyScheduleGuidWithoutCallingGrpc()
    {
        var invoker = new RecordingCallInvoker();
        var helper = FormHelperTestFactory.Create(invoker);

        var exception = await Assert.ThrowsAsync<ArgumentException>(() =>
            helper.InvoiceScheduleMonthlySeriesGenerateAsync(
                Guid.Empty,
                new DateOnly(2026, 8, 1),
                new DateOnly(2026, 10, 1),
                3000m,
                overwriteExisting: false));

        Assert.Equal("invoiceScheduleGuid", exception.ParamName);
        Assert.Null(invoker.LastRequest);
    }

    [Fact]
    public async Task GenerateAsync_RejectsInvalidDateRangeWithoutCallingGrpc()
    {
        var invoker = new RecordingCallInvoker();
        var helper = FormHelperTestFactory.Create(invoker);

        var exception = await Assert.ThrowsAsync<ArgumentException>(() =>
            helper.InvoiceScheduleMonthlySeriesGenerateAsync(
                Guid.NewGuid(),
                new DateOnly(2026, 10, 1),
                new DateOnly(2026, 8, 1),
                3000m,
                overwriteExisting: false));

        Assert.Equal("startDate", exception.ParamName);
        Assert.Null(invoker.LastRequest);
    }

    [Fact]
    public async Task GenerateAsync_RejectsNonPositiveTotalWithoutCallingGrpc()
    {
        var invoker = new RecordingCallInvoker();
        var helper = FormHelperTestFactory.Create(invoker);

        var exception = await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() =>
            helper.InvoiceScheduleMonthlySeriesGenerateAsync(
                Guid.NewGuid(),
                new DateOnly(2026, 8, 1),
                new DateOnly(2026, 10, 1),
                0m,
                overwriteExisting: false));

        Assert.Equal("totalValueNet", exception.ParamName);
        Assert.Null(invoker.LastRequest);
    }

    [Fact]
    public async Task GenerateAsync_MapsRequestUsingInvariantValues()
    {
        var scheduleGuid = Guid.Parse("E51A1736-149D-4519-90B6-82129F5A1C44");
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new InvoiceScheduleMonthlySeriesGenerateResponse
            {
                Success = true,
                InsertedCount = 3,
                MonthsCount = 3
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.InvoiceScheduleMonthlySeriesGenerateAsync(
            scheduleGuid,
            new DateOnly(2026, 8, 31),
            new DateOnly(2026, 10, 31),
            1234.56m,
            overwriteExisting: true);

        var request = Assert.IsType<InvoiceScheduleMonthlySeriesGenerateRequest>(invoker.LastRequest);
        Assert.Equal(scheduleGuid.ToString(), request.InvoiceScheduleGuid);
        Assert.Equal("2026-08-31", request.StartDate);
        Assert.Equal("2026-10-31", request.EndDate);
        Assert.Equal("1234.56", request.TotalValueNet);
        Assert.True(request.OverwriteExisting);
        Assert.EndsWith(
            "/InvoiceScheduleMonthlySeriesGenerate",
            Assert.IsType<string>(invoker.LastMethodFullName));
    }

    [Fact]
    public async Task GenerateAsync_MapsSuccessfulResponse()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new InvoiceScheduleMonthlySeriesGenerateResponse
            {
                Success = true,
                InsertedCount = 4,
                MonthsCount = 4,
                Message = "Generated 4 monthly periods."
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var result = await helper.InvoiceScheduleMonthlySeriesGenerateAsync(
            Guid.NewGuid(),
            new DateOnly(2026, 8, 1),
            new DateOnly(2026, 11, 1),
            4000m,
            overwriteExisting: false);

        Assert.Equal(4, result.InsertedCount);
        Assert.Equal(4, result.MonthsCount);
    }

    [Fact]
    public async Task GenerateAsync_PropagatesServerError()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new InvoiceScheduleMonthlySeriesGenerateResponse
            {
                Success = false,
                ErrorReturned = "Monthly schedule rows already exist."
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var exception = await Assert.ThrowsAsync<Exception>(() =>
            helper.InvoiceScheduleMonthlySeriesGenerateAsync(
                Guid.NewGuid(),
                new DateOnly(2026, 8, 1),
                new DateOnly(2026, 10, 1),
                3000m,
                overwriteExisting: false));

        Assert.Equal("Monthly schedule rows already exist.", exception.Message);
    }
}
