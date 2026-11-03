using Concursus.Common.Shared.Models.Finance;
using Xunit;

namespace Concursus.Common.Shared.Tests.Finance;

public sealed class SageInboundDiagnosticsRowModelTests
{
    private static SageInboundDiagnosticsRowModel CreateRow(
        int? lastMatchedExternalTransactionTypeCode,
        decimal? lastMatchedExternalTransactionAllocatedValue,
        bool hasMaterialisedReceipt = false)
    {
        var row = new SageInboundDiagnosticsRowModel
        {
            LastMatchedExternalTransactionId = 1,
            LastMatchedExternalTransactionTypeCode = lastMatchedExternalTransactionTypeCode,
            LastMatchedExternalTransactionAllocatedValue = lastMatchedExternalTransactionAllocatedValue
        };

        if (hasMaterialisedReceipt)
        {
            row.MaterialisedReceiptTransactionGuid = Guid.NewGuid();
        }

        return row;
    }

    // CYB-555: a materialised Credit Note was labelled "Receipt" on the diagnostics page.
    [Theory]
    [InlineData(5, "Credit Note")]
    [InlineData(1, "Receipt")]
    [InlineData(4, "Receipt")]
    [InlineData(null, "Receipt")]
    public void MaterialisedTransactionLabel_FollowsTheMatchedSageType(int? typeCode, string expectedLabel)
    {
        var row = CreateRow(typeCode, 100m, hasMaterialisedReceipt: true);

        Assert.Equal(expectedLabel, row.MaterialisedTransactionLabel);
    }

    // CYB-555: an unresolved Sage counterpart is settled, method unknown; Fix
    // Receipt would invent a Receipt for it.
    [Fact]
    public void UnresolvedCounterpart_IsSettledMethodUnknown_AndCannotBeFixedAsAReceipt()
    {
        var row = CreateRow(-1, 900m);

        Assert.True(row.IsSettledMethodUnknown);
        Assert.False(row.CanFixReceipt);
    }

    [Theory]
    [InlineData(5, 100.00)]
    [InlineData(1, -50.00)]
    public void CanFixReceipt_TrueForUnmaterialisedCreditNoteOrReceiptWithAllocation(
        int typeCode, decimal allocatedValue)
    {
        var row = CreateRow(typeCode, allocatedValue);

        Assert.True(row.CanFixReceipt);
    }

    [Fact]
    public void CanFixReceipt_TrueForUnmaterialisedInvoiceFallbackWithAllocation()
    {
        // CYB-543: Sage sources that never send a distinct Credit Note/Receipt (1/5) row
        // represent a settlement purely on the invoice's own (4) row. Materialise falls
        // back to that row (see SFin.SageInboundReceiptAndAllocation_Materialise), so it
        // must also be a fixable candidate here.
        var row = CreateRow(lastMatchedExternalTransactionTypeCode: 4, lastMatchedExternalTransactionAllocatedValue: 100.00m);

        Assert.True(row.CanFixReceipt);
    }

    [Theory]
    [InlineData(2)]
    [InlineData(3)]
    [InlineData(6)]
    [InlineData(7)]
    public void CanFixReceipt_FalseForUnsupportedTransactionTypes(int typeCode)
    {
        var row = CreateRow(lastMatchedExternalTransactionTypeCode: typeCode, lastMatchedExternalTransactionAllocatedValue: 100.00m);

        Assert.False(row.CanFixReceipt);
    }

    [Fact]
    public void CanFixReceipt_FalseWhenNoMatchedExternalTransaction()
    {
        var row = CreateRow(lastMatchedExternalTransactionTypeCode: null, lastMatchedExternalTransactionAllocatedValue: null);
        row.LastMatchedExternalTransactionId = null;

        Assert.False(row.CanFixReceipt);
    }

    [Fact]
    public void CanFixReceipt_FalseWhenAllocatedValueIsZero()
    {
        var row = CreateRow(lastMatchedExternalTransactionTypeCode: 1, lastMatchedExternalTransactionAllocatedValue: 0m);

        Assert.False(row.CanFixReceipt);
    }

    [Fact]
    public void CanFixReceipt_FalseWhenReceiptAlreadyMaterialised()
    {
        var row = CreateRow(
            lastMatchedExternalTransactionTypeCode: 1,
            lastMatchedExternalTransactionAllocatedValue: 100.00m,
            hasMaterialisedReceipt: true);

        Assert.False(row.CanFixReceipt);
    }
}
