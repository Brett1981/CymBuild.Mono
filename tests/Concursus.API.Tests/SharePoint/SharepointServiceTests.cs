using Concursus.API.Services;
using Xunit;

namespace Concursus.API.Tests.SharePoint;

public sealed class SharepointServiceTests
{
    [Theory]
    [InlineData("Emails (Incoming)")]
    [InlineData("Emails (Outgoing)")]
    public void CreateCanonicalFolderRequest_DisablesAutomaticRename(string folderName)
    {
        var request = SharepointService.CreateCanonicalFolderRequest(folderName);

        Assert.Equal(folderName, request.Name);
        Assert.NotNull(request.Folder);
        Assert.True(
            request.AdditionalData.TryGetValue("@microsoft.graph.conflictBehavior", out var conflictBehaviour));
        Assert.Equal("fail", conflictBehaviour);
    }
}
