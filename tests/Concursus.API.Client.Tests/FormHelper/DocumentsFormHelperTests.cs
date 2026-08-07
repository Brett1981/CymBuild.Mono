using Concursus.API.Core;

namespace Concursus.API.Client.Tests.FormHelper;

public sealed class DocumentsFormHelperTests
{
    [Theory]
    [InlineData(0, "11111111-1111-1111-1111-111111111111", 1, "userId")]
    [InlineData(1, "not-a-guid", 1, "recordGuid")]
    [InlineData(1, "00000000-0000-0000-0000-000000000000", 1, "recordGuid")]
    [InlineData(1, "11111111-1111-1111-1111-111111111111", 0, "entityTypeId")]
    public async Task NavigationGetAsync_ValidatesRequiredInputs(
        int userId,
        string recordGuid,
        int entityTypeId,
        string parameterName)
    {
        var helper = FormHelperTestFactory.Create(new RecordingCallInvoker());

        var exception = await Assert.ThrowsAsync<ArgumentException>(() =>
            helper.DocumentsNavigationGetAsync(userId, recordGuid, entityTypeId));

        Assert.Equal(parameterName, exception.ParamName);
    }

    [Fact]
    public async Task NavigationGetAsync_MapsValidatedRequest()
    {
        var recordGuid = Guid.NewGuid();
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DocumentsNavigationGetResponse()
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.DocumentsNavigationGetAsync(17, recordGuid.ToString("B"), 31);

        var request = Assert.IsType<DocumentsNavigationGetRequest>(invoker.LastRequest);
        Assert.Equal(17, request.UserId);
        Assert.Equal(recordGuid.ToString(), request.RecordGuid);
        Assert.Equal(31, request.EntityTypeId);
    }

    [Fact]
    public async Task NavigationGetAsync_ThrowsReturnedApiError()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DocumentsNavigationGetResponse
            {
                ErrorReturned = "documents unavailable"
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var exception = await Assert.ThrowsAsync<Exception>(() =>
            helper.DocumentsNavigationGetAsync(1, Guid.NewGuid().ToString(), 2));

        Assert.Equal("documents unavailable", exception.Message);
    }

    [Fact]
    public async Task ResolveAsync_MapsOptionalValuesToEmptyStrings()
    {
        var recordGuid = Guid.NewGuid();
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new DocumentsResolveResponse
            {
                Location = new DocumentsLocation()
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var location = await helper.DocumentsResolveAsync(
            recordGuid.ToString(),
            9,
            null!,
            null);

        Assert.NotNull(location);
        var request = Assert.IsType<DocumentsResolveRequest>(invoker.LastRequest);
        Assert.Equal(recordGuid.ToString(), request.RecordGuid);
        Assert.Equal(9, request.EntityTypeId);
        Assert.Equal(string.Empty, request.EntityQueryGuid);
        Assert.Equal(string.Empty, request.SharePointUrlHint);
    }
}
