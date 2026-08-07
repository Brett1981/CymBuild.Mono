using Concursus.API.Core;

namespace Concursus.API.Client.Tests.FormHelper;

public sealed class AIAssistantUploadFormHelperTests
{
    [Theory]
    [InlineData("knowledge", "KNOWLEDGE")]
    [InlineData("ATTACHMENT", "ATTACHMENT")]
    [InlineData("screenshot", "SCREENSHOT")]
    [InlineData("unexpected", "SCREENSHOT")]
    [InlineData(null, "SCREENSHOT")]
    public async Task PresignAsync_NormalisesUploadPurpose(string? suppliedPurpose, string expectedPurpose)
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new AIAssistantUploadPresignResponse()
        };
        var helper = FormHelperTestFactory.Create(invoker);

        await helper.AIAssistantUploadPresignAsync(
            7,
            "evidence.png",
            "image/png",
            1234,
            suppliedPurpose!);

        var request = Assert.IsType<AIAssistantUploadPresignRequest>(invoker.LastRequest);
        Assert.Equal(expectedPurpose, request.UploadPurposeCode);
        Assert.Equal("evidence.png", request.FileName);
        Assert.Equal("image/png", request.ContentType);
        Assert.Equal(1234, request.FileSizeBytes);
    }

    [Fact]
    public async Task CompleteAsync_NormalisesBlankProcessingStatusAndNullStrings()
    {
        var invoker = new RecordingCallInvoker
        {
            UnaryHandler = request => new AIAssistantUploadCompleteResponse
            {
                Upload = new AIAssistantUpload()
            }
        };
        var helper = FormHelperTestFactory.Create(invoker);

        var upload = await helper.AIAssistantUploadCompleteAsync(
            userId: 8,
            uploadGuid: null!,
            storageUrl: null!,
            fileName: null!,
            contentType: null!,
            fileSizeBytes: 0,
            uploadPurposeCode: "attachment",
            processingStatusCode: "   ",
            conversationGuid: null!,
            knowledgeItemGuid: null!);

        Assert.NotNull(upload);
        var request = Assert.IsType<AIAssistantUploadCompleteRequest>(invoker.LastRequest);
        Assert.Equal(string.Empty, request.UploadGuid);
        Assert.Equal(string.Empty, request.StorageUrl);
        Assert.Equal(string.Empty, request.FileName);
        Assert.Equal(string.Empty, request.ContentType);
        Assert.Equal("ATTACHMENT", request.UploadPurposeCode);
        Assert.Equal("UPLOADED", request.ProcessingStatusCode);
        Assert.Equal(string.Empty, request.ConversationGuid);
        Assert.Equal(string.Empty, request.KnowledgeItemGuid);
    }
}
