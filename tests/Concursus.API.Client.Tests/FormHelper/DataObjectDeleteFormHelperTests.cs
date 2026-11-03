using Concursus.API.Core;

namespace Concursus.API.Client.Tests.FormHelper;

public sealed class DataObjectDeleteFormHelperTests
{
    /// <summary>
    /// FormHelper.DataObjectDeleteAsync currently ignores its entityQueryGuid parameter and
    /// always sends Guid.Empty to the server, regardless of what the caller passes in. This
    /// looks like an existing bug, but this test documents current behaviour rather than
    /// silently changing production code - flag it for review rather than "fixing" it here.
    /// </summary>
    [Fact]
    public async Task DataObjectDeleteAsync_SendsDataObject_ButAlwaysUsesEmptyEntityQueryGuid()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DataObjectDeleteResponse { Success = true }
        };
        var helper = FormHelperTestFactory.Create(invoker);
        var dataObject = new DataObject { Guid = Guid.NewGuid().ToString() };
        var suppliedEntityQueryGuid = Guid.NewGuid().ToString();

        var response = await helper.DataObjectDeleteAsync(dataObject, suppliedEntityQueryGuid);

        var request = Assert.IsType<DataObjectDeleteRequest>(invoker.LastRequest);
        Assert.Same(dataObject, request.DataObject);
        Assert.Equal(Guid.Empty.ToString(), request.EntityQueryGuid);
        Assert.NotEqual(suppliedEntityQueryGuid, request.EntityQueryGuid);
        Assert.True(response.Success);
    }

    [Fact]
    public async Task DataObjectDeleteAsync_PropagatesServerFailureAndErrorMessage()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DataObjectDeleteResponse
            {
                Success = false,
                ErrorReturned = "Cannot delete: record is referenced elsewhere."
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var response = await helper.DataObjectDeleteAsync(new DataObject(), Guid.NewGuid().ToString());

        Assert.False(response.Success);
        Assert.Equal("Cannot delete: record is referenced elsewhere.", response.ErrorReturned);
    }
}
