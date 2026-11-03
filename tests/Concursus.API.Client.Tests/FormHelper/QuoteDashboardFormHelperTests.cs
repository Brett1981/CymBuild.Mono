using Concursus.API.Core;

namespace Concursus.API.Client.Tests.FormHelper;

public sealed class QuoteDashboardFormHelperTests
{
    [Fact]
    public async Task GetQuoteDashboardDataAsync_ReturnsMappedRecordsOnSuccess()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new GetQuoteDashboardDataRes
            {
                Res =
                {
                    new QuoteDashboardData
                    {
                        QuoteID = 1,
                        QuoteNumber = "Q-1",
                        Guid = Guid.NewGuid().ToString(),
                        Status = "Sent",
                        Client = "Acme Ltd",
                        QuoteType = "CDM PD",
                        QuoteValue = 1234.56,
                        BusinessUnit = "Building Surveying",
                        Department = "CDM"
                    }
                }
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var records = await helper.GetQuoteDashboardDataAsync();

        var record = Assert.Single(records);
        Assert.Equal("Q-1", record.QuoteNumber);
        Assert.Equal("Building Surveying", record.BusinessUnit);
        Assert.Equal("CDM", record.Department);
        Assert.IsType<GetQuoteDashboardDataReq>(invoker.LastRequest);
        Assert.EndsWith("/GetQuoteDashboardData", Assert.IsType<string>(invoker.LastMethodFullName));
    }

    [Fact]
    public async Task GetQuoteDashboardDataAsync_ThrowsWhenApiReturnsAnError()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new GetQuoteDashboardDataRes
            {
                ErrorReturned = "Quote dashboard data could not be retrieved."
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var exception = await Assert.ThrowsAsync<Exception>(() => helper.GetQuoteDashboardDataAsync());

        Assert.Equal("Quote dashboard data could not be retrieved.", exception.Message);
    }
}
