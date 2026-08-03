using Concursus.API.Services.Finance;
using Concursus.Common.Shared.Models.Finance;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace Concursus.API.Tests.Finance;

public sealed class SageSalesOrderRequestMapperTests
{
    [Fact]
    public void Map_UsesPurchaseOrderNumberForCustomerOrderNo()
    {
        var mapper = CreateMapper();
        var source = CreateSource(
            transactionNumber: "BCCS 7718",
            purchaseOrderNumber: " PO-45021 ",
            vatCode: "10");

        var request = mapper.Map(source);

        Assert.Equal("PO-45021", request.CustomerOrderNo);
        Assert.NotEqual(source.TransactionNumber, request.CustomerOrderNo);
        Assert.Equal("BCCS 7718", source.GetPreferredExternalReference());
        Assert.Equal("9631", request.AnalysisCode03Value);
    }

    [Fact]
    public void Map_AllowsBlankPurchaseOrderNumberWithoutUsingTransactionNumber()
    {
        var mapper = CreateMapper();
        var source = CreateSource(
            transactionNumber: "BCCS 7718",
            purchaseOrderNumber: "   ",
            vatCode: "10");

        var request = mapper.Map(source);

        Assert.Null(request.CustomerOrderNo);
        Assert.Equal("BCCS 7718", source.GetPreferredExternalReference());
        Assert.Equal("9631", request.AnalysisCode03Value);
    }

    [Fact]
    public void Map_UsesStandardTwentyPercentSageTaxCodeIdentifier()
    {
        var mapper = CreateMapper();
        var source = CreateSource(
            transactionNumber: "BCCS 7718",
            purchaseOrderNumber: "PO-45021",
            vatCode: "10");

        var request = mapper.Map(source);

        Assert.Single(request.Lines);
        Assert.Equal(10, request.Lines[0].TaxCode);
    }

    [Fact]
    public void Map_UsesCorrectedDefaultTaxCodeWhenSourceMappingIsBlank()
    {
        var mapper = CreateMapper();
        var source = CreateSource(
            transactionNumber: "BCCS 7718",
            purchaseOrderNumber: "PO-45021",
            vatCode: string.Empty);

        var request = mapper.Map(source);

        Assert.Equal(10, request.Lines[0].TaxCode);
    }

    [Theory]
    [InlineData("E")]
    [InlineData("RC")]
    [InlineData("-1")]
    public void Map_RejectsInvalidSageTaxCodeInsteadOfSilentlyUsingTwentyPercentFallback(string vatCode)
    {
        var mapper = CreateMapper();
        var source = CreateSource(
            transactionNumber: "BCCS 7718",
            purchaseOrderNumber: "PO-45021",
            vatCode: vatCode);

        var exception = Assert.Throws<InvalidOperationException>(() => mapper.Map(source));

        Assert.Contains("not a valid non-negative Sage tax-code identifier", exception.Message);
    }

    private static SageSalesOrderRequestMapper CreateMapper()
    {
        var options = Options.Create(new SageSalesOrderMappingOptions
        {
            DefaultDataset = "group",
            DefaultLineType = "Free Text",
            DefaultNominalRef = "31010",
            DefaultTaxCode = 10
        });

        return new SageSalesOrderRequestMapper(
            options,
            NullLogger<SageSalesOrderRequestMapper>.Instance);
    }

    private static ApprovedTransactionForSageReadModel CreateSource(
        string transactionNumber,
        string purchaseOrderNumber,
        string vatCode)
    {
        return new ApprovedTransactionForSageReadModel
        {
            TransactionGuid = Guid.NewGuid(),
            TransactionId = 123,
            TransactionNumber = transactionNumber,
            InvoiceNumber = transactionNumber,
            PurchaseOrderNumber = purchaseOrderNumber,
            RowStatus = 1,
            Batched = false,
            SageCustomerReference = "CUST001",
            JobNumber = "9631",
            Lines =
            [
                new ApprovedTransactionForSageLineReadModel
                {
                    LineId = 1,
                    RowStatus = 1,
                    Description = "Professional services",
                    Quantity = 1,
                    UnitPrice = 100m,
                    NetAmount = 100m,
                    VatAmount = 20m,
                    GrossAmount = 120m,
                    VatCode = vatCode
                }
            ]
        };
    }
}
