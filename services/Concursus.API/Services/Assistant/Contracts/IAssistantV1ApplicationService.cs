using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Concursus.API.Services.Assistant.Contracts;

public interface IAssistantV1ApplicationService
{
    Task<AssistantConversationDto> CreateConversationAsync(CreateAssistantConversationCommand command, CancellationToken cancellationToken);
    Task<AssistantConversationDto?> GetConversationAsync(Guid conversationGuid, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantConversationDto>> ListConversationsForUserAsync(int userId, bool includeArchived, CancellationToken cancellationToken);
    Task<AssistantConversationDto> RenameConversationAsync(Guid conversationGuid, string title, CancellationToken cancellationToken);
    Task<AssistantConversationDto> ArchiveConversationAsync(Guid conversationGuid, bool isArchived, CancellationToken cancellationToken);
    Task<bool> DeleteConversationAsync(Guid conversationGuid, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantMessageDto>> GetConversationMessagesAsync(Guid conversationGuid, CancellationToken cancellationToken);

    IAsyncEnumerable<AssistantStreamEventDto> SendMessageAsync(SendAssistantMessageCommand command, CancellationToken cancellationToken);
    IAsyncEnumerable<AssistantStreamEventDto> RegenerateAnswerAsync(RegenerateAssistantAnswerCommand command, CancellationToken cancellationToken);
    Task<string> ConvertAnswerToChecklistAsync(Guid messageGuid, CancellationToken cancellationToken);
    Task<Guid> SaveAnswerAsPlaybookAsync(Guid messageGuid, string title, AssistantVisibilityDto visibility, CancellationToken cancellationToken);

    Task<IReadOnlyList<AssistantKnowledgeItemDto>> SearchKnowledgeAsync(SearchAssistantKnowledgeCommand command, CancellationToken cancellationToken);
    Task<AssistantKnowledgeItemDto?> GetKnowledgeItemAsync(Guid knowledgeItemGuid, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantKnowledgeCategoryDto>> GetKnowledgeCategoriesAsync(CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantKnowledgeItemDto>> GetFeaturedKnowledgeAsync(int take, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantKnowledgeItemDto>> GetRelatedKnowledgeAsync(Guid knowledgeItemGuid, int take, CancellationToken cancellationToken);
    Task<AssistantKnowledgeItemDto> CreateKnowledgeItemAsync(CreateAssistantKnowledgeItemCommand command, CancellationToken cancellationToken);
    Task<AssistantKnowledgeItemDto> UpdateKnowledgeItemAsync(UpdateAssistantKnowledgeItemCommand command, CancellationToken cancellationToken);
    Task<AssistantKnowledgeItemDto> PublishKnowledgeItemAsync(Guid knowledgeItemGuid, bool isPublished, int updatedByUserId, CancellationToken cancellationToken);
    Task<AssistantKnowledgeVersionDto> ReplaceKnowledgeItemVersionAsync(ReplaceAssistantKnowledgeItemVersionCommand command, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantKnowledgeVersionDto>> ListKnowledgeVersionsAsync(Guid knowledgeItemGuid, CancellationToken cancellationToken);

    Task<IReadOnlyList<AssistantWorkflowTemplateDto>> ListWorkflowTemplatesAsync(ListAssistantWorkflowTemplatesCommand command, CancellationToken cancellationToken);
    Task<AssistantWorkflowTemplateDto?> GetWorkflowTemplateAsync(Guid workflowTemplateGuid, CancellationToken cancellationToken);
    Task<AssistantWorkflowRunDto> StartWorkflowRunAsync(StartAssistantWorkflowRunCommand command, CancellationToken cancellationToken);
    Task<AssistantWorkflowRunDto> AdvanceWorkflowRunAsync(Guid workflowRunGuid, string? outputJson, CancellationToken cancellationToken);
    Task<AssistantWorkflowRunDto> CompleteWorkflowRunAsync(Guid workflowRunGuid, string? outputJson, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantPlaybookDto>> ListPlaybooksAsync(int userId, bool includeFeatured, CancellationToken cancellationToken);
    Task<AssistantPlaybookDto?> GetPlaybookAsync(Guid playbookGuid, CancellationToken cancellationToken);
    Task<AssistantWorkflowTemplateDto> CreateWorkflowTemplateAsync(CreateAssistantWorkflowTemplateCommand command, CancellationToken cancellationToken);
    Task<AssistantWorkflowTemplateDto> UpdateWorkflowTemplateAsync(UpdateAssistantWorkflowTemplateCommand command, CancellationToken cancellationToken);
    Task<AssistantWorkflowTemplateDto> PublishWorkflowTemplateAsync(Guid workflowTemplateGuid, bool isPublished, CancellationToken cancellationToken);
    Task<AssistantWorkflowTemplateDto> FeatureWorkflowTemplateAsync(Guid workflowTemplateGuid, bool isFeatured, CancellationToken cancellationToken);

    Task<AssistantBookmarkDto> CreateBookmarkAsync(CreateAssistantBookmarkCommand command, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantBookmarkDto>> ListBookmarksAsync(int userId, CancellationToken cancellationToken);
    Task<bool> DeleteBookmarkAsync(Guid bookmarkGuid, CancellationToken cancellationToken);
    Task<AssistantBookmarkDto> UpdateBookmarkAsync(UpdateAssistantBookmarkCommand command, CancellationToken cancellationToken);

    Task<CreateAssistantUploadSessionResultDto> CreateUploadSessionAsync(CreateAssistantUploadSessionCommand command, CancellationToken cancellationToken);
    Task<AssistantUploadDto> CompleteUploadAsync(CompleteAssistantUploadCommand command, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantUploadDto>> ListUserUploadsAsync(int userId, CancellationToken cancellationToken);
    Task<AnalyzeAssistantScreenshotResultDto> AnalyzeScreenshotAsync(AnalyzeAssistantScreenshotCommand command, CancellationToken cancellationToken);
    Task<AssistantUploadDto> AttachUploadToConversationAsync(Guid uploadGuid, Guid conversationGuid, CancellationToken cancellationToken);

    Task<AssistantDashboardSummaryDto> GetAdminDashboardSummaryAsync(CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantFeedbackDto>> ListFeedbackAsync(bool includeHelpful, bool includeUnhelpful, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantFailedAnswerDto>> ListFailedAnswersAsync(double maxConfidenceScore, int take, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantContentGapDto>> ListContentGapsAsync(AssistantContentGapStatusDto status, CancellationToken cancellationToken);
    Task<AssistantContentGapDto> AssignContentGapAsync(Guid contentGapGuid, Guid? suggestedKnowledgeItemGuid, AssistantContentGapStatusDto status, CancellationToken cancellationToken);
    Task<AssistantContentGapDto> ResolveContentGapAsync(Guid contentGapGuid, AssistantContentGapStatusDto status, CancellationToken cancellationToken);

    Task<IReadOnlyList<AssistantTopicMetricDto>> GetTopQuestionsAsync(int take, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantTopicMetricDto>> GetTopicTrendsAsync(int days, CancellationToken cancellationToken);
    Task<AssistantFailedAnswerSummaryDto> GetFailedAnswerSummaryAsync(int days, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantSourceUsageMetricDto>> GetSourceUsageSummaryAsync(int take, CancellationToken cancellationToken);
    Task<IReadOnlyList<AssistantWorkflowUsageMetricDto>> GetWorkflowUsageSummaryAsync(int take, CancellationToken cancellationToken);
}
