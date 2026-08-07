using Concursus.Common.Shared.Models.Finance;
using Xunit;

namespace Concursus.Common.Shared.Tests.Finance;

public sealed class ApprovedTransactionForSageLineReadModelTests
{
    [Theory]
    [InlineData(1, "Description", 1, true)]
    [InlineData(2, "Description", 1, true)]
    [InlineData(0, "Description", 1, false)]
    [InlineData(254, "Description", 1, false)]
    [InlineData(1, "", 1, false)]
    [InlineData(1, "Description", 0, false)]
    public void IsUsableForSubmission_AppliesActiveDescriptionAndQuantityRules(
        byte rowStatus,
        string description,
        int quantity,
        bool expected)
    {
        var line = new ApprovedTransactionForSageLineReadModel
        {
            RowStatus = rowStatus,
            Description = description,
            Quantity = quantity
        };

        Assert.Equal(expected, line.IsUsableForSubmission());
    }

    [Theory]
    [InlineData(0, false)]
    [InlineData(1, true)]
    [InlineData(2, true)]
    [InlineData(254, false)]
    public void IsActive_UsesCymBuildRowStatusRules(byte rowStatus, bool expected)
    {
        Assert.Equal(expected, new ApprovedTransactionForSageLineReadModel { RowStatus = rowStatus }.IsActive());
    }

    [Fact]
    public void PreferredReference_UsesReferenceThenGuidThenId()
    {
        var lineGuid = Guid.NewGuid();
        var line = new ApprovedTransactionForSageLineReadModel
        {
            LineId = 42,
            LineGuid = lineGuid,
            LineReference = " LINE-42 "
        };

        Assert.Equal("LINE-42", line.GetPreferredReference());

        line.LineReference = string.Empty;
        Assert.Equal(lineGuid.ToString("D"), line.GetPreferredReference());

        line.LineGuid = null;
        Assert.Equal("42", line.GetPreferredReference());
    }
}
