using Concursus.API.Core;

namespace Concursus.API.Client;

public partial class FormHelper
{
    #region AI Assistant Uploads

    public async Task<AIAssistantUploadPresignResponse> AIAssistantUploadPresignAsync(
        int userId,
        string fileName,
        string contentType,
        long fileSizeBytes,
        string uploadPurposeCode = "SCREENSHOT",
        string conversationGuid = "",
        string knowledgeItemGuid = "",
        CancellationToken cancellationToken = default)
    {
        var response = await _coreClient.AIAssistantUploadPresignAsync(
            new AIAssistantUploadPresignRequest
            {
                UserId = userId,
                FileName = fileName ?? string.Empty,
                ContentType = contentType ?? string.Empty,
                FileSizeBytes = fileSizeBytes,
                UploadPurposeCode = NormaliseAIAssistantUploadPurpose(uploadPurposeCode),
                ConversationGuid = conversationGuid ?? string.Empty,
                KnowledgeItemGuid = knowledgeItemGuid ?? string.Empty
            },
            cancellationToken: cancellationToken);

        ThrowIfAIAssistantError(response.ErrorReturned);

        return response;
    }

    public async Task<AIAssistantUpload> AIAssistantUploadCompleteAsync(
        int userId,
        string uploadGuid,
        string storageUrl,
        string fileName,
        string contentType,
        long fileSizeBytes,
        string uploadPurposeCode = "SCREENSHOT",
        string processingStatusCode = "UPLOADED",
        string conversationGuid = "",
        string knowledgeItemGuid = "",
        CancellationToken cancellationToken = default)
    {
        var response = await _coreClient.AIAssistantUploadCompleteAsync(
            new AIAssistantUploadCompleteRequest
            {
                UserId = userId,
                UploadGuid = uploadGuid ?? string.Empty,
                ConversationGuid = conversationGuid ?? string.Empty,
                KnowledgeItemGuid = knowledgeItemGuid ?? string.Empty,
                StorageUrl = storageUrl ?? string.Empty,
                FileName = fileName ?? string.Empty,
                ContentType = contentType ?? string.Empty,
                FileSizeBytes = fileSizeBytes,
                UploadPurposeCode = NormaliseAIAssistantUploadPurpose(uploadPurposeCode),
                ProcessingStatusCode = string.IsNullOrWhiteSpace(processingStatusCode)
                    ? "UPLOADED"
                    : processingStatusCode.Trim().ToUpperInvariant()
            },
            cancellationToken: cancellationToken);

        ThrowIfAIAssistantError(response.ErrorReturned);

        return response.Upload;
    }

    public async Task<IReadOnlyList<AIAssistantUpload>> AIAssistantUploadListAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        var response = await _coreClient.AIAssistantUploadListAsync(
            new AIAssistantUploadListRequest
            {
                UserId = userId
            },
            cancellationToken: cancellationToken);

        ThrowIfAIAssistantError(response.ErrorReturned);

        return response.Uploads.ToList();
    }

    private static string NormaliseAIAssistantUploadPurpose(string? uploadPurposeCode)
    {
        if (string.Equals(uploadPurposeCode, "KNOWLEDGE", StringComparison.OrdinalIgnoreCase))
        {
            return "KNOWLEDGE";
        }

        if (string.Equals(uploadPurposeCode, "ATTACHMENT", StringComparison.OrdinalIgnoreCase))
        {
            return "ATTACHMENT";
        }

        return "SCREENSHOT";
    }

    #endregion AI Assistant Uploads
}
