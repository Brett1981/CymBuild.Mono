using Concursus.API.Core;

namespace Concursus.API.Client.Tests.FormHelper;

public sealed class DuplicateCheckFormHelperTests
{
    [Fact]
    public async Task DuplicateAssetsGet_SendsAllAddressFieldsOnTheRequest()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DuplicateAssetsRes()
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.DuplicateAssetsGet(
            name: "Some Name",
            number: "12",
            addressLine1: "1 Test Street",
            addressLine2: "Suite 2",
            addressLine3: "Industrial Estate",
            town: "Testville",
            countyGuid: "44444444-4444-4444-4444-444444444444",
            postcode: "TS1 1ST");

        var sentRequest = Assert.IsType<DuplicateAssetsReq>(invoker.LastRequest);
        Assert.Equal("Some Name", sentRequest.Name);
        Assert.Equal("12", sentRequest.Number);
        Assert.Equal("1 Test Street", sentRequest.Addressline1);
        Assert.Equal("Suite 2", sentRequest.Addressline2);
        Assert.Equal("Industrial Estate", sentRequest.Addressline3);
        Assert.Equal("Testville", sentRequest.Town);
        Assert.Equal("44444444-4444-4444-4444-444444444444", sentRequest.CountyGuid);
        Assert.Equal("TS1 1ST", sentRequest.Postcode);
        Assert.EndsWith("/DuplicateAssetsGet", Assert.IsType<string>(invoker.LastMethodFullName));
    }

    [Fact]
    public async Task DuplicateAssetsGet_DefaultsUnsuppliedFieldsToEmptyString()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DuplicateAssetsRes()
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.DuplicateAssetsGet();

        var sentRequest = Assert.IsType<DuplicateAssetsReq>(invoker.LastRequest);
        Assert.Equal(string.Empty, sentRequest.Name);
        Assert.Equal(string.Empty, sentRequest.Number);
        Assert.Equal(string.Empty, sentRequest.Addressline1);
        Assert.Equal(string.Empty, sentRequest.Postcode);
    }

    [Fact]
    public async Task DuplicateAssetsGet_ReturnsDuplicatesFromServer()
    {
        var expected = new DuplicateAssetsRes
        {
            Duplicates = { new DuplicateAssets { Guid = "guid-1", FormattedAddress = "1 Test Street" } }
        };
        var invoker = new RecordingCallInvoker { UnaryHandler = request => expected };
        var helper = FormHelperTestFactory.Create(invoker);

        var result = await helper.DuplicateAssetsGet(addressLine1: "1 Test Street");

        Assert.Same(expected, result);
        Assert.Single(result.Duplicates);
        Assert.Equal("1 Test Street", result.Duplicates[0].FormattedAddress);
    }

    [Fact]
    public async Task DuplicateAccountsGet_SendsDisplayNameOnTheRequest()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DuplicateAccountsRes()
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.DuplicateAccountsGet("Acme Ltd");

        var sentRequest = Assert.IsType<DuplicateAccountsReq>(invoker.LastRequest);
        Assert.Equal("Acme Ltd", sentRequest.Displayname);
        Assert.EndsWith("/DuplicateAccountsGet", Assert.IsType<string>(invoker.LastMethodFullName));
    }

    [Fact]
    public async Task DuplicateContactsGet_SendsAllNameFieldsOnTheRequest()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DuplicateContactsRes()
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.DuplicateContactsGet(
            DisplayName: "Jane Doe",
            FirstName: "Jane",
            SurName: "Doe",
            Initials: "JD");

        var sentRequest = Assert.IsType<DuplicateContactsReq>(invoker.LastRequest);
        Assert.Equal("Jane Doe", sentRequest.Displayname);
        Assert.Equal("Jane", sentRequest.Firstname);
        Assert.Equal("Doe", sentRequest.Surname);
        Assert.Equal("JD", sentRequest.Initials);
        Assert.EndsWith("/DuplicateContactsGet", Assert.IsType<string>(invoker.LastMethodFullName));
    }
}
