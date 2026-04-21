using System;
using System.Collections.Generic;

namespace Concursus.API.Services.Assistant.Contracts;

public enum AssistantModeDto { Unspecified = 0, Beginner = 1, Expert = 2 }
public enum AssistantVisibilityDto { Unspecified = 0, Private = 1, AdminFeatured = 2, Shared = 3 }
public enum AssistantUploadPurposeDto { Unspecified = 0, Screenshot = 1, Knowledge = 2, Attachment = 3 }
public enum AssistantProcessingStatusDto { Unspecified = 0, PendingUpload = 1, Uploaded = 2, QueuedForExtraction = 3, Extracted = 4, ExtractionFailed = 5, Published = 6 }
public enum AssistantWorkflowRunStatusDto { Unspecified = 0, Started = 1, InProgress = 2, Completed = 3, Cancelled = 4 }
public enum AssistantContentGapStatusDto { Unspecified = 0, New = 1, Reviewing = 2, Assigned = 3, Addressed = 4, Closed = 5 }
public enum AssistantAnswerTypeDto { Unspecified = 0, TrustedKnowledge = 1, AdminWorkflowGuide = 2, GeneratedSuggestion = 3 }
public enum AssistantMessageRoleDto { Unspecified = 0, User = 1, Assistant = 2, System = 3 }
public enum AssistantFeedbackTypeDto { Unspecified = 0, Helpful = 1, Unhelpful = 2 }

public sealed record CreateAssistantConversationCommand(int UserId, string Title, AssistantModeDto Mode, string? LanguageCode, Guid? StartedFromWorkflowTemplateGuid);
public sealed record SendAssistantMessageCommand(Guid ConversationGuid, int UserId, string UserMessage, AssistantModeDto Mode, Guid? WorkflowTemplateGuid, IReadOnlyList<Guid> AttachedUploadGuids, string? LanguageCode);
public sealed record RegenerateAssistantAnswerCommand(Guid ConversationGuid, Guid ParentMessageGuid, AssistantModeDto Mode);
public sealed record SearchAssistantKnowledgeCommand(string SearchText, Guid? CategoryGuid, bool PublishedOnly, bool AuthoritativeFirst);
public sealed record CreateAssistantKnowledgeItemCommand(string Title, string Slug, Guid? KnowledgeCategoryGuid, string ContentTypeCode, string SourceTypeCode, string StorageUrl, string? PreviewUrl, string? Summary, bool IsAuthoritative, bool IsPublished, int CreatedByUserId);
public sealed record UpdateAssistantKnowledgeItemCommand(Guid KnowledgeItemGuid, string Title, string Slug, Guid? KnowledgeCategoryGuid, string ContentTypeCode, string SourceTypeCode, string StorageUrl, string? PreviewUrl, string? Summary, bool IsAuthoritative, bool IsPublished, int UpdatedByUserId);
public sealed record ReplaceAssistantKnowledgeItemVersionCommand(Guid KnowledgeItemGuid, string StorageUrl, string? ExtractedText, string ExtractionStatusCode, string? MetadataJson, string? FileHash, int CreatedByUserId);
public sealed record ListAssistantWorkflowTemplatesCommand(bool PublishedOnly, bool FeaturedOnly, string? AudienceCode);
public sealed record StartAssistantWorkflowRunCommand(int UserId, Guid WorkflowTemplateGuid, Guid? ConversationGuid, string? InputJson);
public sealed record CreateAssistantWorkflowTemplateCommand(string Code, string Title, string? Summary, string? AudienceCode, string TemplatePrompt, string? ClarificationSchemaJson, string OutputFormatCode, bool IsPublished, bool IsFeatured, int CreatedByUserId);
public sealed record UpdateAssistantWorkflowTemplateCommand(Guid WorkflowTemplateGuid, string Code, string Title, string? Summary, string? AudienceCode, string TemplatePrompt, string? ClarificationSchemaJson, string OutputFormatCode, bool IsPublished, bool IsFeatured);
public sealed record CreateAssistantBookmarkCommand(int UserId, Guid ConversationGuid, Guid MessageGuid, string Title, string? Notes, string? TagsJson);
public sealed record UpdateAssistantBookmarkCommand(Guid BookmarkGuid, string Title, string? Notes, string? TagsJson);
public sealed record CreateAssistantUploadSessionCommand(int UserId, AssistantUploadPurposeDto UploadPurpose, string FileName, string ContentType, long FileSizeBytes);
public sealed record CompleteAssistantUploadCommand(Guid UploadGuid, Guid? ConversationGuid, Guid? KnowledgeItemGuid, string StorageUrl, string FileName, string ContentType, long FileSizeBytes, AssistantUploadPurposeDto UploadPurpose, AssistantProcessingStatusDto ProcessingStatus);
public sealed record AnalyzeAssistantScreenshotCommand(Guid UploadGuid, Guid? ConversationGuid, AssistantModeDto Mode);

public abstract record AssistantStreamEventDto;
public sealed record AssistantMessageChunkDto(Guid AssistantMessageGuid, string? ContentDelta) : AssistantStreamEventDto;
public sealed record AssistantMessageCompletedDto(AssistantMessageDto Message) : AssistantStreamEventDto;

public sealed record AssistantSourceDto(string? Title, string? TypeCode, string? Url, Guid? KnowledgeItemGuid, int VersionNumber, string? Excerpt, bool IsAuthoritative, DateTime? LastUpdatedUtc);
public sealed record AssistantFollowUpSuggestionDto(string? Text, string? Prompt);

public sealed record AssistantConversationDto(Guid Guid, int UserId, string? Title, AssistantModeDto Mode, string? LanguageCode, DateTime? LastActivityUtc, bool IsPinned, bool IsArchived, Guid? StartedFromWorkflowTemplateGuid, Guid? LastMessageGuid, string? LastMessagePreview);
public sealed record AssistantMessageDto(Guid Guid, Guid ConversationGuid, int UserId, AssistantMessageRoleDto Role, AssistantAnswerTypeDto AnswerType, string? ContentMarkdown, string? ContentPlainText, double ConfidenceScore, DateTime? CreatedUtc, IReadOnlyList<AssistantSourceDto> Sources, IReadOnlyList<AssistantFollowUpSuggestionDto> FollowUps, string? ModelCode, Guid? ParentMessageGuid);
public sealed record AssistantBookmarkDto(Guid Guid, int UserId, Guid ConversationGuid, Guid MessageGuid, string? Title, string? Notes, string? TagsJson, DateTime? CreatedUtc);
public sealed record AssistantKnowledgeCategoryDto(Guid Guid, string? Name, string? Code, string? Description, int DisplayOrder, bool IsVisible);
public sealed record AssistantKnowledgeItemDto(Guid Guid, string? Title, string? Slug, Guid? KnowledgeCategoryGuid, string? CategoryName, string? ContentTypeCode, string? SourceTypeCode, string? StorageUrl, string? PreviewUrl, string? Summary, bool IsAuthoritative, bool IsPublished, DateTime? PublishedUtc, DateTime? CreatedUtc, DateTime? UpdatedUtc, int CurrentVersionNumber, string? ExtractedText);
public sealed record AssistantKnowledgeVersionDto(Guid Guid, Guid KnowledgeItemGuid, int VersionNumber, string? StorageUrl, string? ExtractedText, string? ExtractionStatusCode, string? MetadataJson, string? FileHash, bool IsCurrent, int CreatedByUserId, DateTime? CreatedUtc);
public sealed record AssistantWorkflowTemplateDto(Guid Guid, string? Code, string? Title, string? Summary, string? AudienceCode, string? TemplatePrompt, string? ClarificationSchemaJson, string? OutputFormatCode, bool IsPublished, bool IsFeatured, int CreatedByUserId, DateTime? CreatedUtc, DateTime? UpdatedUtc);
public sealed record AssistantWorkflowRunDto(Guid Guid, int UserId, Guid WorkflowTemplateGuid, Guid? ConversationGuid, AssistantWorkflowRunStatusDto Status, string? InputJson, string? OutputJson, DateTime? StartedUtc, DateTime? CompletedUtc);
public sealed record AssistantPlaybookStepDto(Guid Guid, Guid PlaybookGuid, int StepOrder, string? Title, string? InstructionMarkdown, bool IsOptional, string? ExpectedOutcome);
public sealed record AssistantPlaybookDto(Guid Guid, int? UserId, string? Title, string? Summary, string? PlaybookTypeCode, AssistantVisibilityDto Visibility, Guid? SourceConversationGuid, Guid? SourceWorkflowRunGuid, int CreatedByUserId, DateTime? CreatedUtc, DateTime? UpdatedUtc, bool IsFeatured, IReadOnlyList<AssistantPlaybookStepDto> Steps);
public sealed record AssistantUploadDto(Guid Guid, int UserId, Guid? ConversationGuid, Guid? KnowledgeItemGuid, string? StorageUrl, string? FileName, string? ContentType, long FileSizeBytes, AssistantUploadPurposeDto UploadPurpose, AssistantProcessingStatusDto ProcessingStatus, string? VisionSummary, DateTime? CreatedUtc);
public sealed record AssistantFeedbackDto(Guid Guid, int UserId, Guid ConversationGuid, Guid MessageGuid, AssistantFeedbackTypeDto FeedbackType, string? Comment, DateTime? CreatedUtc);
public sealed record AssistantContentGapDto(Guid Guid, string? Title, string? Description, string? TopicCluster, int OccurrenceCount, DateTime? LastSeenUtc, AssistantContentGapStatusDto Status, Guid? SuggestedKnowledgeItemGuid, string? SuggestedKnowledgeItemTitle);
public sealed record AssistantDashboardSummaryDto(int TotalConversations, int TotalMessages, int PublishedKnowledgeItems, int PublishedWorkflowTemplates, int UnhelpfulFeedbackCount, int OpenContentGapCount);
public sealed record AssistantTopicMetricDto(string? Label, int Count);
public sealed record AssistantSourceUsageMetricDto(string? SourceTitle, string? SourceTypeCode, int UsageCount);
public sealed record AssistantWorkflowUsageMetricDto(Guid WorkflowTemplateGuid, string? Title, int UsageCount);
public sealed record AssistantFailedAnswerDto(Guid ConversationGuid, Guid MessageGuid, string? ConversationTitle, string? MessagePreview, double ConfidenceScore, DateTime? CreatedUtc);
public sealed record AssistantFailedAnswerSummaryDto(int FailedAnswerCount, int UnhelpfulFeedbackCount);
public sealed record CreateAssistantUploadSessionResultDto(Guid UploadGuid, string UploadUrl, IReadOnlyDictionary<string, string> UploadHeaders);
public sealed record AnalyzeAssistantScreenshotResultDto(Guid UploadGuid, string? DetectedScreenSummary, IReadOnlyList<string> NotableSections, IReadOnlyList<string> LikelyNextActions, IReadOnlyList<string> PossibleMistakes, double ConfidenceScore);
