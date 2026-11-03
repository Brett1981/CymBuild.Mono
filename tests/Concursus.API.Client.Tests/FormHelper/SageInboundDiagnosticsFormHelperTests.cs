using Concursus.API.Core;
using Concursus.Common.Shared.Models.Finance;

namespace Concursus.API.Client.Tests.FormHelper;

/// <summary>
/// CYB-568: the Inbound Diagnostics "Fix Receipt" action must send the matched
/// SFin.SageExternalTransactions ID. The gRPC row did not carry it, so the page's
/// LastMatchedExternalTransactionId was always null and Fix Receipt never ran.
/// </summary>
public sealed class SageInboundDiagnosticsFormHelperTests
{
    [Fact]
    public async Task SageInboundDiagnosticsGetAsync_MapsMatchedExternalTransactionSoFixReceiptCanRun()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = _ => new SageInboundDiagnosticsGetReply
            {
                TotalCount = 1,
                Rows =
                {
                    new SageInboundDiagnosticsRow
                    {
                        Id = 296,
                        LastMatchedExternalTransactionId = 293,
                        LastMatchedExternalTransactionTypeCode = 4,
                        LastMatchedExternalTransactionAllocatedValue = 200d
                    }
                }
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var result = await helper.SageInboundDiagnosticsGetAsync(new SageInboundDiagnosticsGetRequestModel());

        var row = Assert.Single(result.Rows);
        Assert.Equal(296, row.Id);
        Assert.Equal(293, row.LastMatchedExternalTransactionId);
        Assert.Equal(4, row.LastMatchedExternalTransactionTypeCode);
        Assert.Equal(200m, row.LastMatchedExternalTransactionAllocatedValue);
        Assert.True(row.CanFixReceipt);
    }

    [Fact]
    public async Task SageInboundDiagnosticsGetAsync_NoMatchedExternalTransaction_LeavesFixReceiptUnavailable()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = _ => new SageInboundDiagnosticsGetReply
            {
                TotalCount = 1,
                Rows = { new SageInboundDiagnosticsRow { Id = 22 } }
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var result = await helper.SageInboundDiagnosticsGetAsync(new SageInboundDiagnosticsGetRequestModel());

        var row = Assert.Single(result.Rows);
        Assert.Null(row.LastMatchedExternalTransactionId);
        Assert.Null(row.LastMatchedExternalTransactionTypeCode);
        Assert.Null(row.LastMatchedExternalTransactionAllocatedValue);
        Assert.False(row.CanFixReceipt);
    }
}
