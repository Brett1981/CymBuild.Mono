using Concursus.API.Core;

namespace Concursus.API.Client.Tests.FormHelper;

public sealed class AddressLookupFormHelperTests
{
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task SearchAsync_RejectsBlankSearchWithoutCallingGrpc(string? searchText)
    {
        var invoker = new RecordingCallInvoker();
        var helper = FormHelperTestFactory.Create(invoker);

        var response = await helper.AddressLookupSearchAsync(searchText!, "GBR");

        Assert.Equal("Search text is required.", response.ErrorReturned);
        Assert.Null(invoker.LastRequest);
    }

    [Fact]
    public async Task SearchAsync_TrimsValuesAndDefaultsBlankContextToGreatBritain()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new AddressLookupSearchResponse()
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.AddressLookupSearchAsync("  10 High Street  ", "   ", forceApi: true);

        var request = Assert.IsType<AddressLookupSearchRequest>(invoker.LastRequest);
        Assert.Equal("10 High Street", request.SearchText);
        Assert.Equal("GBR", request.Context);
        Assert.True(request.ForceApi);
        Assert.EndsWith("/AddressLookupSearch", Assert.IsType<string>(invoker.LastMethodFullName));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task ResolveAsync_RejectsBlankIdWithoutCallingGrpc(string? id)
    {
        var invoker = new RecordingCallInvoker();
        var helper = FormHelperTestFactory.Create(invoker);

        var response = await helper.AddressLookupResolveAsync(id!, "GBR");

        Assert.Equal("Address id is required.", response.ErrorReturned);
        Assert.Null(invoker.LastRequest);
    }

    [Fact]
    public async Task ResolveAsync_TrimsValuesAndPreservesExplicitContext()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new AddressLookupResolveResponse()
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.AddressLookupResolveAsync("  address-id  ", "  IRL  ");

        var request = Assert.IsType<AddressLookupResolveRequest>(invoker.LastRequest);
        Assert.Equal("address-id", request.Id);
        Assert.Equal("IRL", request.Context);
        Assert.EndsWith("/AddressLookupResolve", Assert.IsType<string>(invoker.LastMethodFullName));
    }
}
