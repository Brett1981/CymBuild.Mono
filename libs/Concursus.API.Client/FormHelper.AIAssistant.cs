using Concursus.API.Core;

namespace Concursus.API.Client;

public partial class FormHelper
{
    #region AI Assistant

    public async Task<AIAssistantConversation> AIAssistantConversationCreateAsync(
        int userId,
        string title,
        string modeCode = "BEGINNER",
        string languageCode = "",
        string startedFromWorkflowTemplateGuid = "",
        CancellationToken cancellationToken = default)
    {
        var response = await _coreClient.AIAssistantConversationCreateAsync(
            new AIAssistantConversationCreateRequest
            {
                UserId = userId,
                Title = title ?? string.Empty,
                ModeCode = NormaliseAIAssistantModeCode(modeCode),
                LanguageCode = languageCode ?? string.Empty,
                StartedFromWorkflowTemplateGuid = startedFromWorkflowTemplateGuid ?? string.Empty
            },
            cancellationToken: cancellationToken);

        ThrowIfAIAssistantError(response.ErrorReturned);

        return response.Conversation;
    }

    public async Task<IReadOnlyList<AIAssistantConversation>> AIAssistantConversationListAsync(
        int userId,
        bool includeArchived = false,
        CancellationToken cancellationToken = default)
    {
        var response = await _coreClient.AIAssistantConversationListAsync(
            new AIAssistantConversationListRequest
            {
                UserId = userId,
                IncludeArchived = includeArchived
            },
            cancellationToken: cancellationToken);

        ThrowIfAIAssistantError(response.ErrorReturned);

        return response.Conversations.ToList();
    }

    public async Task<IReadOnlyList<AIAssistantMessage>> AIAssistantMessageListAsync(
        Guid conversationGuid,
        CancellationToken cancellationToken = default)
    {
        var response = await _coreClient.AIAssistantMessageListAsync(
            new AIAssistantMessageListRequest
            {
                ConversationGuid = conversationGuid.ToString()
            },
            cancellationToken: cancellationToken);

        ThrowIfAIAssistantError(response.ErrorReturned);

        return response.Messages.ToList();
    }

    public async Task<AIAssistantMessageSendResponse> AIAssistantMessageSendAsync(
        int userId,
        Guid conversationGuid,
        string message,
        string modeCode = "BEGINNER",
        string workflowTemplateGuid = "",
        string languageCode = "",
        IEnumerable<string>? attachedUploadGuids = null,
        CancellationToken cancellationToken = default)
    {
        var request = new AIAssistantMessageSendRequest
        {
            UserId = userId,
            ConversationGuid = conversationGuid.ToString(),
            Message = message ?? string.Empty,
            ModeCode = NormaliseAIAssistantModeCode(modeCode),
            WorkflowTemplateGuid = workflowTemplateGuid ?? string.Empty,
            LanguageCode = languageCode ?? string.Empty
        };

        if (attachedUploadGuids is not null)
        {
            request.AttachedUploadGuids.AddRange(
                attachedUploadGuids
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Select(x => x.Trim()));
        }

        var response = await _coreClient.AIAssistantMessageSendAsync(
            request,
            cancellationToken: cancellationToken);

        ThrowIfAIAssistantError(response.ErrorReturned);

        return response;
    }

    public async Task<IReadOnlyList<AIAssistantKnowledgeItem>> AIAssistantKnowledgeSearchAsync(
        string searchText,
        string categoryGuid = "",
        bool publishedOnly = true,
        bool authoritativeFirst = true,
        CancellationToken cancellationToken = default)
    {
        var response = await _coreClient.AIAssistantKnowledgeSearchAsync(
            new AIAssistantKnowledgeSearchRequest
            {
                SearchText = searchText ?? string.Empty,
                CategoryGuid = categoryGuid ?? string.Empty,
                PublishedOnly = publishedOnly,
                AuthoritativeFirst = authoritativeFirst
            },
            cancellationToken: cancellationToken);

        ThrowIfAIAssistantError(response.ErrorReturned);

        return response.Items.ToList();
    }

    public async Task<Guid> AIAssistantBookmarkCreateAsync(
        int userId,
        Guid conversationGuid,
        Guid messageGuid,
        string title,
        string notes = "",
        string tagsJson = "",
        CancellationToken cancellationToken = default)
    {
        var response = await _coreClient.AIAssistantBookmarkCreateAsync(
            new AIAssistantBookmarkCreateRequest
            {
                UserId = userId,
                ConversationGuid = conversationGuid.ToString(),
                MessageGuid = messageGuid.ToString(),
                Title = title ?? string.Empty,
                Notes = notes ?? string.Empty,
                TagsJson = tagsJson ?? string.Empty
            },
            cancellationToken: cancellationToken);

        ThrowIfAIAssistantError(response.ErrorReturned);

        return ParseAIAssistantGuid(response.BookmarkGuid, "bookmark");
    }

    public async Task<Guid> AIAssistantFeedbackCreateAsync(
        int userId,
        Guid conversationGuid,
        Guid messageGuid,
        string feedbackCode,
        string comment = "",
        CancellationToken cancellationToken = default)
    {
        var response = await _coreClient.AIAssistantFeedbackCreateAsync(
            new AIAssistantFeedbackCreateRequest
            {
                UserId = userId,
                ConversationGuid = conversationGuid.ToString(),
                MessageGuid = messageGuid.ToString(),
                FeedbackCode = NormaliseAIAssistantFeedbackCode(feedbackCode),
                Comment = comment ?? string.Empty
            },
            cancellationToken: cancellationToken);

        ThrowIfAIAssistantError(response.ErrorReturned);

        return ParseAIAssistantGuid(response.FeedbackGuid, "feedback");
    }

    public async Task<AIAssistantConversation> AIAssistantConversationEnsureAsync(
        int userId,
        string title = "New assistant conversation",
        string modeCode = "BEGINNER",
        CancellationToken cancellationToken = default)
    {
        var conversations = await AIAssistantConversationListAsync(
            userId,
            includeArchived: false,
            cancellationToken);

        var latest = conversations
            .OrderByDescending(x => DateTime.TryParse(x.LastActivityUtc, out var dt) ? dt : DateTime.MinValue)
            .FirstOrDefault();

        if (latest is not null)
        {
            return latest;
        }

        return await AIAssistantConversationCreateAsync(
            userId,
            title,
            modeCode,
            cancellationToken: cancellationToken);
    }

    private static void ThrowIfAIAssistantError(string? errorReturned)
    {
        if (!string.IsNullOrWhiteSpace(errorReturned))
        {
            throw new InvalidOperationException(errorReturned);
        }
    }

    private static string NormaliseAIAssistantModeCode(string? modeCode)
    {
        return string.Equals(modeCode, "EXPERT", StringComparison.OrdinalIgnoreCase)
            ? "EXPERT"
            : "BEGINNER";
    }

    private static string NormaliseAIAssistantFeedbackCode(string? feedbackCode)
    {
        if (string.Equals(feedbackCode, "HELPFUL", StringComparison.OrdinalIgnoreCase)
            || string.Equals(feedbackCode, "helpful", StringComparison.OrdinalIgnoreCase))
        {
            return "helpful";
        }

        if (string.Equals(feedbackCode, "UNHELPFUL", StringComparison.OrdinalIgnoreCase)
            || string.Equals(feedbackCode, "unhelpful", StringComparison.OrdinalIgnoreCase))
        {
            return "unhelpful";
        }

        return string.Empty;
    }

    private static Guid ParseAIAssistantGuid(string value, string label)
    {
        if (Guid.TryParse(value, out var guid) && guid != Guid.Empty)
        {
            return guid;
        }

        throw new InvalidOperationException($"The AI assistant returned an invalid {label} Guid.");
    }

    #endregion AI Assistant
}
