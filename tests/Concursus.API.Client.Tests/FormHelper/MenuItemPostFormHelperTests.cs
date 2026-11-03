using Concursus.API.Core;

namespace Concursus.API.Client.Tests.FormHelper;

public sealed class MenuItemPostFormHelperTests
{
    [Fact]
    public async Task MenuItemPostAsync_DefaultsCopyQuoteItemsToTrue()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new ExecuteMenuItemResponse { DataObject = new DataObject() }
        };
        var helper = FormHelperTestFactory.Create(invoker);
        var dataObject = new DataObject { Guid = Guid.NewGuid().ToString() };
        var entityQueryGuid = Guid.NewGuid().ToString();

        await helper.MenuItemPostAsync(entityQueryGuid, dataObject);

        var request = Assert.IsType<ExecuteMenuItemRequest>(invoker.LastRequest);
        Assert.True(request.CopyQuoteItems);
        Assert.Equal(entityQueryGuid, request.EntityQueryGuid);
        Assert.EndsWith(
            "/ExecuteMenuItemPost",
            Assert.IsType<string>(invoker.LastMethodFullName));
    }

    [Fact]
    public async Task MenuItemPostAsync_MapsCopyQuoteItemsFalse()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new ExecuteMenuItemResponse { DataObject = new DataObject() }
        };
        var helper = FormHelperTestFactory.Create(invoker);
        var dataObject = new DataObject { Guid = Guid.NewGuid().ToString() };

        await helper.MenuItemPostAsync(Guid.NewGuid().ToString(), dataObject, copyQuoteItems: false);

        var request = Assert.IsType<ExecuteMenuItemRequest>(invoker.LastRequest);
        Assert.False(request.CopyQuoteItems);
    }

    [Fact]
    public async Task MenuItemPostAsync_MapsAllowQuoteItemStageFallbackAlongsideCopyQuoteItems()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new ExecuteMenuItemResponse { DataObject = new DataObject() }
        };
        var helper = FormHelperTestFactory.Create(invoker);
        var dataObject = new DataObject { Guid = Guid.NewGuid().ToString() };

        await helper.MenuItemPostAsync(
            Guid.NewGuid().ToString(),
            dataObject,
            allowQuoteItemStageFallback: true,
            copyQuoteItems: false);

        var request = Assert.IsType<ExecuteMenuItemRequest>(invoker.LastRequest);
        Assert.True(request.AllowQuoteItemStageFallback);
        Assert.False(request.CopyQuoteItems);
    }
}
