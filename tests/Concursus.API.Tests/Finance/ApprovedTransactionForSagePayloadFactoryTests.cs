using System.Text.Json;
using Concursus.API.Services.Finance;
using Concursus.Common.Shared.Models.Finance;
using Xunit;

namespace Concursus.API.Tests.Finance;

public sealed class ApprovedTransactionForSagePayloadFactoryTests
{
    [Fact]
    public void Build_ReturnsMapperResultWithoutRemapping()
    {
        var expected = CreateMappedRequest();
        var mapper = new RecordingMapper(expected);
        var factory = new ApprovedTransactionForSagePayloadFactory(mapper);
        var source = new ApprovedTransactionForSageReadModel { TransactionGuid = Guid.NewGuid() };

        var actual = factory.Build(source);

        Assert.Same(expected, actual);
        Assert.Same(source, mapper.LastSource);
        Assert.Equal(1, mapper.CallCount);
    }

    [Fact]
    public void BuildJson_UsesWrapperPropertyNamesAndOmitsNullOptionalValues()
    {
        var request = CreateMappedRequest();
        request.CustomerOrderNo = null;
        request.AnalysisCode01Value = null;
        var factory = new ApprovedTransactionForSagePayloadFactory(new RecordingMapper(request));

        var json = factory.BuildJson(new ApprovedTransactionForSageReadModel());
        using var document = JsonDocument.Parse(json);
        var root = document.RootElement;

        Assert.Equal("group", root.GetProperty("dataset").GetString());
        Assert.Equal("CUST001", root.GetProperty("accountReference").GetString());
        Assert.False(root.TryGetProperty("customerOrderNo", out _));
        Assert.False(root.TryGetProperty("analysisCode01Value", out _));
        Assert.True(root.GetProperty("allowCreditLimitException").GetBoolean());

        var line = Assert.Single(root.GetProperty("lines").EnumerateArray());
        Assert.Equal("Professional services", line.GetProperty("itemDescription").GetString());
        Assert.Equal("31010", line.GetProperty("nominalRef").GetString());
        Assert.Equal(1, line.GetProperty("quantity").GetInt32());
        Assert.Equal(100m, line.GetProperty("unitPrice").GetDecimal());
        Assert.False(json.Contains("HttpStatusCode", StringComparison.Ordinal));
    }

    [Fact]
    public void Constructor_NullMapperThrowsArgumentNullException()
    {
        Assert.Throws<ArgumentNullException>(() => new ApprovedTransactionForSagePayloadFactory(null!));
    }

    private static SageCreateSalesOrderRequest CreateMappedRequest()
    {
        return new SageCreateSalesOrderRequest
        {
            Dataset = "group",
            AccountReference = "CUST001",
            CustomerOrderNo = "PO-100",
            UseInvoiceAddress = false,
            AllowCreditLimitException = true,
            OverrideOnHold = true,
            AnalysisCode03Value = "9631",
            Lines =
            [
                new SageCreateSalesOrderLineRequest
                {
                    ItemDescription = "Professional services",
                    LineType = "Free Text",
                    NominalRef = "31010",
                    Quantity = 1,
                    UnitPrice = 100m,
                    TaxCode = 10
                }
            ]
        };
    }

    private sealed class RecordingMapper(SageCreateSalesOrderRequest result) : ISageSalesOrderRequestMapper
    {
        public int CallCount { get; private set; }

        public ApprovedTransactionForSageReadModel? LastSource { get; private set; }

        public SageCreateSalesOrderRequest Map(ApprovedTransactionForSageReadModel source)
        {
            CallCount++;
            LastSource = source;
            return result;
        }
    }
}
