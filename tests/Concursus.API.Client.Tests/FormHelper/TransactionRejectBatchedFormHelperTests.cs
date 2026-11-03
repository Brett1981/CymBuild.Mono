using Concursus.API.Core;

namespace Concursus.API.Client.Tests.FormHelper;

public sealed class TransactionRejectBatchedFormHelperTests
{
    [Fact]
    public async Task TransactionRejectBatchedAsync_MapsRequest()
    {
        var transactionGuid = Guid.Parse("E51A1736-149D-4519-90B6-82129F5A1C44");
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new TransactionRejectBatchedResponse { Success = true }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.TransactionRejectBatchedAsync(
            transactionGuid,
            "Customer disputes charge",
            ct: TestContext.Current.CancellationToken);

        var request = Assert.IsType<TransactionRejectBatchedRequest>(invoker.LastRequest);
        Assert.Equal(transactionGuid.ToString(), request.TransactionGuid);
        Assert.Equal("Customer disputes charge", request.RejectionReason);
        Assert.EndsWith(
            "/TransactionRejectBatched",
            Assert.IsType<string>(invoker.LastMethodFullName));
    }

    [Fact]
    public async Task TransactionRejectBatchedAsync_SendsEmptyStringWhenRejectionReasonIsNull()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new TransactionRejectBatchedResponse { Success = true }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.TransactionRejectBatchedAsync(
            Guid.NewGuid(),
            rejectionReason: null!,
            ct: TestContext.Current.CancellationToken);

        var request = Assert.IsType<TransactionRejectBatchedRequest>(invoker.LastRequest);
        Assert.Equal(string.Empty, request.RejectionReason);
    }

    [Fact]
    public async Task TransactionRejectBatchedAsync_MapsSuccessfulResponse()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new TransactionRejectBatchedResponse { Success = true }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var response = await helper.TransactionRejectBatchedAsync(
            Guid.NewGuid(),
            "Duplicate entry",
            ct: TestContext.Current.CancellationToken);

        Assert.True(response.Success);
        Assert.Equal(string.Empty, response.ErrorReturned);
    }

    [Fact]
    public async Task TransactionRejectBatchedAsync_PropagatesServerFailureWithoutThrowing()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new TransactionRejectBatchedResponse
            {
                Success = false,
                ErrorReturned = "A valid Transaction Guid is required to reject a batched transaction."
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var response = await helper.TransactionRejectBatchedAsync(
            Guid.Empty,
            "Duplicate entry",
            ct: TestContext.Current.CancellationToken);

        Assert.False(response.Success);
        Assert.Equal(
            "A valid Transaction Guid is required to reject a batched transaction.",
            response.ErrorReturned);
    }
}
