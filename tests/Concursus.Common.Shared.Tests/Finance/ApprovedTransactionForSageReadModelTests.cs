using Concursus.Common.Shared.Models.Finance;
using Xunit;

namespace Concursus.Common.Shared.Tests.Finance;

public sealed class ApprovedTransactionForSageReadModelTests
{
    [Fact]
    public void ActiveLines_ExcludesNewAndDeletedRows()
    {
        var model = CreateValidTransaction();
        model.Lines =
        [
            CreateLine(1, rowStatus: 1),
            CreateLine(2, rowStatus: 0),
            CreateLine(3, rowStatus: 254),
            CreateLine(4, rowStatus: 2)
        ];

        Assert.Equal(new long[] { 1L, 4L }, model.ActiveLines.Select(line => line.LineId));
    }

    [Fact]
    public void UsableLines_RequiresActiveDescriptionAndPositiveQuantity()
    {
        var model = CreateValidTransaction();
        model.Lines =
        [
            CreateLine(1),
            CreateLine(2, description: "   "),
            CreateLine(3, quantity: 0),
            CreateLine(4, rowStatus: 254)
        ];

        Assert.Equal(new long[] { 1L }, model.UsableLines.Select(line => line.LineId));
    }

    [Fact]
    public void PreferredDocumentDate_UsesTransactionDateBeforeExpectedDate()
    {
        var model = CreateValidTransaction();
        var transactionDate = new DateTime(2026, 8, 5, 8, 30, 0, DateTimeKind.Utc);
        var expectedDate = transactionDate.AddDays(30);
        model.TransactionDateUtc = transactionDate;
        model.ExpectedDateUtc = expectedDate;

        Assert.Equal(transactionDate, model.GetPreferredDocumentDateUtc());

        model.TransactionDateUtc = null;
        Assert.Equal(expectedDate, model.GetPreferredDocumentDateUtc());

        model.ExpectedDateUtc = null;
        Assert.Null(model.GetPreferredDocumentDateUtc());
    }

    [Fact]
    public void PreferredExternalReference_UsesInvoiceThenTransactionThenGuid()
    {
        var model = CreateValidTransaction();
        model.InvoiceNumber = " INV-100 ";
        model.TransactionNumber = " TX-100 ";

        Assert.Equal("INV-100", model.GetPreferredExternalReference());

        model.InvoiceNumber = " ";
        Assert.Equal("TX-100", model.GetPreferredExternalReference());

        model.TransactionNumber = " ";
        Assert.Equal(model.TransactionGuid.ToString("D"), model.GetPreferredExternalReference());
    }

    [Fact]
    public void PreferredJobReference_UsesJobNumberBeforeTransactionReference()
    {
        var model = CreateValidTransaction();
        model.JobNumber = " 9631 ";

        Assert.Equal("9631", model.GetPreferredJobOrTransactionReference());

        model.JobNumber = string.Empty;
        Assert.Equal(model.InvoiceNumber, model.GetPreferredJobOrTransactionReference());
    }

    [Fact]
    public void IsUsableForSubmission_ReturnsTrueForValidTransaction()
    {
        Assert.True(CreateValidTransaction().IsUsableForSubmission());
    }

    [Theory]
    [InlineData(0, false, true, true, true)]
    [InlineData(254, false, true, true, true)]
    [InlineData(1, true, true, true, true)]
    [InlineData(1, false, false, true, true)]
    [InlineData(1, false, true, false, true)]
    [InlineData(1, false, true, true, false)]
    public void IsUsableForSubmission_RejectsInvalidHeaderOrLineConditions(
        byte rowStatus,
        bool batched,
        bool hasTransactionGuid,
        bool hasCustomerReference,
        bool hasUsableLine)
    {
        var model = CreateValidTransaction();
        model.RowStatus = rowStatus;
        model.Batched = batched;
        model.TransactionGuid = hasTransactionGuid ? Guid.NewGuid() : Guid.Empty;
        model.SageCustomerReference = hasCustomerReference ? "CUST001" : " ";
        model.Lines = hasUsableLine ? [CreateLine(1)] : [CreateLine(1, quantity: 0)];

        Assert.False(model.IsUsableForSubmission());
    }

    private static ApprovedTransactionForSageReadModel CreateValidTransaction()
    {
        return new ApprovedTransactionForSageReadModel
        {
            TransitionGuid = Guid.NewGuid(),
            TransitionId = 10,
            TransactionGuid = Guid.NewGuid(),
            TransactionId = 20,
            TransactionNumber = "TX-100",
            InvoiceNumber = "INV-100",
            RowStatus = 1,
            Batched = false,
            CustomerName = "Customer",
            SageCustomerReference = "CUST001",
            NetAmount = 100m,
            VatAmount = 20m,
            GrossAmount = 120m,
            Lines = [CreateLine(1)]
        };
    }

    private static ApprovedTransactionForSageLineReadModel CreateLine(
        long id,
        byte rowStatus = 1,
        string description = "Professional services",
        decimal quantity = 1m)
    {
        return new ApprovedTransactionForSageLineReadModel
        {
            LineId = id,
            RowStatus = rowStatus,
            Description = description,
            Quantity = quantity,
            UnitPrice = 100m,
            NetAmount = 100m,
            VatAmount = 20m,
            GrossAmount = 120m
        };
    }
}
