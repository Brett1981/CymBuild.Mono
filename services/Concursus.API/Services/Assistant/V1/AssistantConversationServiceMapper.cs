using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Concursus.API.Assistant.V1;
using Concursus.API.Services.Assistant.Contracts;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using Timestamp = Google.Protobuf.WellKnownTypes.Timestamp;

namespace Concursus.API.Services.Assistant.V1;

internal static class AssistantConversationServiceMapper
{
    public static Task<T> ExecuteAsync<T>(Func<Task<T>> action, ILogger logger, string operationName)
        => AssistantGrpcServiceBase.ExecuteAsync(action, logger, operationName);

    public static RpcException CreateRpcException(StatusCode statusCode, string message)
        => AssistantGrpcServiceBase.CreateRpcException(statusCode, message);

    public static Guid ParseRequiredGuid(string value, string fieldName)
        => AssistantGrpcServiceBase.ParseRequiredGuid(value, fieldName);

    public static Guid? ParseOptionalGuid(string? value, string fieldName)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (!Guid.TryParse(value.Trim(), out var guid) || guid == Guid.Empty)
        {
            throw CreateRpcException(StatusCode.InvalidArgument, $"{fieldName} must be a valid non-empty GUID when supplied.");
        }

        return guid;
    }

    public static string RequireText(string? value, string fieldName, int? maxLength = null)
        => AssistantGrpcServiceBase.RequireText(value, fieldName, maxLength);

    public static int RequirePositiveInt(int value, string fieldName)
        => AssistantGrpcServiceBase.RequirePositiveInt(value, fieldName);

    public static string? NullIfWhiteSpace(string? value)
        => AssistantGrpcServiceBase.NullIfWhiteSpace(value);

    public static string? Unwrap(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    public static AssistantModeDto MapMode(AssistantMode mode) => mode switch
    {
        AssistantMode.Beginner => AssistantModeDto.Beginner,
        AssistantMode.Expert => AssistantModeDto.Expert,
        _ => AssistantModeDto.Unspecified
    };

    public static AssistantVisibilityDto MapVisibility(AssistantVisibility visibility) => visibility switch
    {
        AssistantVisibility.Private => AssistantVisibilityDto.Private,
        AssistantVisibility.AdminFeatured => AssistantVisibilityDto.AdminFeatured,
        AssistantVisibility.Shared => AssistantVisibilityDto.Shared,
        _ => AssistantVisibilityDto.Unspecified
    };

    public static AssistantUploadPurposeDto MapUploadPurpose(AssistantUploadPurpose purpose) => purpose switch
    {
        AssistantUploadPurpose.Screenshot => AssistantUploadPurposeDto.Screenshot,
        AssistantUploadPurpose.Knowledge => AssistantUploadPurposeDto.Knowledge,
        AssistantUploadPurpose.Attachment => AssistantUploadPurposeDto.Attachment,
        _ => AssistantUploadPurposeDto.Unspecified
    };

    public static AssistantProcessingStatusDto MapProcessingStatus(AssistantProcessingStatus status) => status switch
    {
        AssistantProcessingStatus.PendingUpload => AssistantProcessingStatusDto.PendingUpload,
        AssistantProcessingStatus.Uploaded => AssistantProcessingStatusDto.Uploaded,
        AssistantProcessingStatus.QueuedForExtraction => AssistantProcessingStatusDto.QueuedForExtraction,
        AssistantProcessingStatus.Extracted => AssistantProcessingStatusDto.Extracted,
        AssistantProcessingStatus.ExtractionFailed => AssistantProcessingStatusDto.ExtractionFailed,
        AssistantProcessingStatus.Published => AssistantProcessingStatusDto.Published,
        _ => AssistantProcessingStatusDto.Unspecified
    };

    public static AssistantContentGapStatusDto MapContentGapStatus(AssistantContentGapStatus status) => status switch
    {
        AssistantContentGapStatus.New => AssistantContentGapStatusDto.New,
        AssistantContentGapStatus.Reviewing => AssistantContentGapStatusDto.Reviewing,
        AssistantContentGapStatus.Assigned => AssistantContentGapStatusDto.Assigned,
        AssistantContentGapStatus.Addressed => AssistantContentGapStatusDto.Addressed,
        AssistantContentGapStatus.Closed => AssistantContentGapStatusDto.Closed,
        _ => AssistantContentGapStatusDto.Unspecified
    };

    public static AssistantWorkflowRunStatus MapWorkflowRunStatus(AssistantWorkflowRunStatusDto status) => status switch
    {
        AssistantWorkflowRunStatusDto.Started => AssistantWorkflowRunStatus.Started,
        AssistantWorkflowRunStatusDto.InProgress => AssistantWorkflowRunStatus.InProgress,
        AssistantWorkflowRunStatusDto.Completed => AssistantWorkflowRunStatus.Completed,
        AssistantWorkflowRunStatusDto.Cancelled => AssistantWorkflowRunStatus.Cancelled,
        _ => AssistantWorkflowRunStatus.Unspecified
    };

    public static AssistantFeedbackType MapFeedbackType(AssistantFeedbackTypeDto type) => type switch
    {
        AssistantFeedbackTypeDto.Helpful => AssistantFeedbackType.Helpful,
        AssistantFeedbackTypeDto.Unhelpful => AssistantFeedbackType.Unhelpful,
        _ => AssistantFeedbackType.Unspecified
    };

    public static AssistantAnswerType MapAnswerType(AssistantAnswerTypeDto type) => type switch
    {
        AssistantAnswerTypeDto.TrustedKnowledge => AssistantAnswerType.TrustedKnowledge,
        AssistantAnswerTypeDto.AdminWorkflowGuide => AssistantAnswerType.AdminWorkflowGuide,
        AssistantAnswerTypeDto.GeneratedSuggestion => AssistantAnswerType.GeneratedSuggestion,
        _ => AssistantAnswerType.Unspecified
    };

    public static AssistantMessageRole MapMessageRole(AssistantMessageRoleDto role) => role switch
    {
        AssistantMessageRoleDto.User => AssistantMessageRole.User,
        AssistantMessageRoleDto.Assistant => AssistantMessageRole.Assistant,
        AssistantMessageRoleDto.System => AssistantMessageRole.System,
        _ => AssistantMessageRole.Unspecified
    };

    public static AssistantConversationModel ToProto(AssistantConversationDto dto)
        => new()
        {
            Guid = dto.Guid.ToString(),
            UserId = dto.UserId,
            Title = dto.Title ?? string.Empty,
            Mode = dto.Mode switch
            {
                AssistantModeDto.Beginner => AssistantMode.Beginner,
                AssistantModeDto.Expert => AssistantMode.Expert,
                _ => AssistantMode.Unspecified
            },
            LanguageCode = Unwrap(dto.LanguageCode) ?? string.Empty,
            StartedFromWorkflowTemplateGuid = dto.StartedFromWorkflowTemplateGuid?.ToString() ?? string.Empty,
            LastMessageGuid = dto.LastMessageGuid?.ToString() ?? string.Empty,
            LastMessagePreview = dto.LastMessagePreview ?? string.Empty
        };

    public static AssistantMessageModel ToProto(AssistantMessageDto dto)
    {
        var message = new AssistantMessageModel
        {
            Guid = dto.Guid.ToString(),
            ConversationGuid = dto.ConversationGuid.ToString(),
            UserId = dto.UserId,
            Role = MapMessageRole(dto.Role),
            AnswerType = MapAnswerType(dto.AnswerType),
            ContentMarkdown = dto.ContentMarkdown ?? string.Empty,
            ContentPlainText = dto.ContentPlainText ?? string.Empty,
            ConfidenceScore = dto.ConfidenceScore,
            CreatedUtc = ToTimestamp(dto.CreatedUtc),
            ModelCode = dto.ModelCode ?? string.Empty,
            ParentMessageGuid = dto.ParentMessageGuid?.ToString() ?? string.Empty
        };

        message.Sources.AddRange(dto.Sources.Select(ToProto));
        message.FollowUps.AddRange(dto.FollowUps.Select(ToProto));

        return message;
    }

    public static AssistantSource ToProto(AssistantSourceDto dto)
        => new()
        {
            Title = dto.Title ?? string.Empty,
            TypeCode = dto.TypeCode ?? string.Empty,
            Url = dto.Url ?? string.Empty,
            KnowledgeItemGuid = dto.KnowledgeItemGuid?.ToString() ?? string.Empty,
            VersionNumber = dto.VersionNumber,
            Excerpt = dto.Excerpt ?? string.Empty,
            IsAuthoritative = dto.IsAuthoritative,
            LastUpdatedUtc = ToTimestamp(dto.LastUpdatedUtc)
        };

    public static AssistantFollowUpSuggestion ToProto(AssistantFollowUpSuggestionDto dto)
        => new()
        {
            Text = dto.Text ?? string.Empty,
            Prompt = dto.Prompt ?? string.Empty
        };

    public static SendAssistantMessageReply ToProto(AssistantStreamEventDto dto)
    {
        return dto switch
        {
            AssistantMessageChunkDto chunk => new SendAssistantMessageReply
            {
                Chunk = new AssistantMessageChunk
                {
                    AssistantMessageGuid = chunk.AssistantMessageGuid.ToString(),
                    ContentDelta = chunk.ContentDelta ?? string.Empty
                }
            },
            AssistantMessageCompletedDto completed => new SendAssistantMessageReply
            {
                Completed = new AssistantMessageCompleted
                {
                    Message = ToProto(completed.Message)
                }
            },
            _ => throw CreateRpcException(StatusCode.Internal, "Unknown assistant stream payload.")
        };
    }

    public static AssistantKnowledgeCategoryModel ToProto(AssistantKnowledgeCategoryDto dto)
        => new()
        {
            Guid = dto.Guid.ToString(),
            Name = dto.Name ?? string.Empty,
            Code = dto.Code ?? string.Empty,
            Description = dto.Description ?? string.Empty,
            DisplayOrder = dto.DisplayOrder,
            IsVisible = dto.IsVisible
        };

    public static AssistantKnowledgeItemModel ToProto(AssistantKnowledgeItemDto dto)
        => new()
        {
            Guid = dto.Guid.ToString(),
            Title = dto.Title ?? string.Empty,
            Slug = dto.Slug ?? string.Empty,
            KnowledgeCategoryGuid = dto.KnowledgeCategoryGuid?.ToString() ?? string.Empty,
            CategoryName = dto.CategoryName ?? string.Empty,
            ContentTypeCode = dto.ContentTypeCode ?? string.Empty,
            SourceTypeCode = dto.SourceTypeCode ?? string.Empty,
            StorageUrl = dto.StorageUrl ?? string.Empty,
            PreviewUrl = dto.PreviewUrl ?? string.Empty,
            Summary = dto.Summary ?? string.Empty,
            IsAuthoritative = dto.IsAuthoritative,
            IsPublished = dto.IsPublished,
            PublishedUtc = ToTimestamp(dto.PublishedUtc),
            CreatedUtc = ToTimestamp(dto.CreatedUtc),
            UpdatedUtc = ToTimestamp(dto.UpdatedUtc),
            CurrentVersionNumber = dto.CurrentVersionNumber,
            ExtractedText = dto.ExtractedText ?? string.Empty
        };

    public static AssistantKnowledgeVersionModel ToProto(AssistantKnowledgeVersionDto dto)
        => new()
        {
            Guid = dto.Guid.ToString(),
            KnowledgeItemGuid = dto.KnowledgeItemGuid.ToString(),
            VersionNumber = dto.VersionNumber,
            StorageUrl = dto.StorageUrl ?? string.Empty,
            ExtractedText = dto.ExtractedText ?? string.Empty,
            ExtractionStatusCode = dto.ExtractionStatusCode ?? string.Empty,
            MetadataJson = dto.MetadataJson ?? string.Empty,
            FileHash = dto.FileHash ?? string.Empty,
            IsCurrent = dto.IsCurrent,
            CreatedByUserId = dto.CreatedByUserId,
            CreatedUtc = ToTimestamp(dto.CreatedUtc)
        };

    public static AssistantWorkflowTemplateModel ToProto(AssistantWorkflowTemplateDto dto)
        => new()
        {
            Guid = dto.Guid.ToString(),
            Code = dto.Code ?? string.Empty,
            Title = dto.Title ?? string.Empty,
            Summary = dto.Summary ?? string.Empty,
            AudienceCode = dto.AudienceCode ?? string.Empty,
            TemplatePrompt = dto.TemplatePrompt ?? string.Empty,
            ClarificationSchemaJson = dto.ClarificationSchemaJson ?? string.Empty,
            OutputFormatCode = dto.OutputFormatCode ?? string.Empty,
            IsPublished = dto.IsPublished,
            IsFeatured = dto.IsFeatured,
            CreatedByUserId = dto.CreatedByUserId,
            CreatedUtc = ToTimestamp(dto.CreatedUtc),
            UpdatedUtc = ToTimestamp(dto.UpdatedUtc)
        };

    public static AssistantWorkflowRunModel ToProto(AssistantWorkflowRunDto dto)
        => new()
        {
            Guid = dto.Guid.ToString(),
            UserId = dto.UserId,
            WorkflowTemplateGuid = dto.WorkflowTemplateGuid.ToString(),
            ConversationGuid = dto.ConversationGuid?.ToString() ?? string.Empty,
            Status = MapWorkflowRunStatus(dto.Status),
            InputJson = dto.InputJson ?? string.Empty,
            OutputJson = dto.OutputJson ?? string.Empty,
            StartedUtc = ToTimestamp(dto.StartedUtc),
            CompletedUtc = ToTimestamp(dto.CompletedUtc)
        };

    public static AssistantPlaybookStepModel ToProto(AssistantPlaybookStepDto dto)
        => new()
        {
            Guid = dto.Guid.ToString(),
            PlaybookGuid = dto.PlaybookGuid.ToString(),
            StepOrder = dto.StepOrder,
            Title = dto.Title ?? string.Empty,
            InstructionMarkdown = dto.InstructionMarkdown ?? string.Empty,
            IsOptional = dto.IsOptional,
            ExpectedOutcome = dto.ExpectedOutcome ?? string.Empty
        };

    public static AssistantPlaybookModel ToProto(AssistantPlaybookDto dto)
    {
        var model = new AssistantPlaybookModel
        {
            Guid = dto.Guid.ToString(),
            UserId = dto.UserId,
            Title = dto.Title ?? string.Empty,
            Summary = dto.Summary ?? string.Empty,
            PlaybookTypeCode = dto.PlaybookTypeCode ?? string.Empty,
            Visibility = dto.Visibility switch
            {
                AssistantVisibilityDto.Private => AssistantVisibility.Private,
                AssistantVisibilityDto.AdminFeatured => AssistantVisibility.AdminFeatured,
                AssistantVisibilityDto.Shared => AssistantVisibility.Shared,
                _ => AssistantVisibility.Unspecified
            },
            SourceConversationGuid = dto.SourceConversationGuid?.ToString() ?? string.Empty,
            SourceWorkflowRunGuid = dto.SourceWorkflowRunGuid?.ToString() ?? string.Empty,
            CreatedByUserId = dto.CreatedByUserId,
            CreatedUtc = ToTimestamp(dto.CreatedUtc),
            UpdatedUtc = ToTimestamp(dto.UpdatedUtc),
            IsFeatured = dto.IsFeatured
        };

        model.Steps.AddRange(dto.Steps.Select(ToProto));
        return model;
    }

    public static AssistantBookmarkModel ToProto(AssistantBookmarkDto dto)
        => new()
        {
            Guid = dto.Guid.ToString(),
            UserId = dto.UserId,
            ConversationGuid = dto.ConversationGuid.ToString(),
            MessageGuid = dto.MessageGuid.ToString(),
            Title = dto.Title ?? string.Empty,
            Notes = dto.Notes ?? string.Empty,
            TagsJson = dto.TagsJson ?? string.Empty,
            CreatedUtc = ToTimestamp(dto.CreatedUtc)
        };

    public static AssistantUploadModel ToProto(AssistantUploadDto dto)
        => new()
        {
            Guid = dto.Guid.ToString(),
            UserId = dto.UserId,
            ConversationGuid = dto.ConversationGuid?.ToString() ?? string.Empty,
            KnowledgeItemGuid = dto.KnowledgeItemGuid?.ToString() ?? string.Empty,
            StorageUrl = dto.StorageUrl ?? string.Empty,
            FileName = dto.FileName ?? string.Empty,
            ContentType = dto.ContentType ?? string.Empty,
            FileSizeBytes = dto.FileSizeBytes,
            UploadPurpose = dto.UploadPurpose switch
            {
                AssistantUploadPurposeDto.Screenshot => AssistantUploadPurpose.Screenshot,
                AssistantUploadPurposeDto.Knowledge => AssistantUploadPurpose.Knowledge,
                AssistantUploadPurposeDto.Attachment => AssistantUploadPurpose.Attachment,
                _ => AssistantUploadPurpose.Unspecified
            },
            ProcessingStatus = dto.ProcessingStatus switch
            {
                AssistantProcessingStatusDto.PendingUpload => AssistantProcessingStatus.PendingUpload,
                AssistantProcessingStatusDto.Uploaded => AssistantProcessingStatus.Uploaded,
                AssistantProcessingStatusDto.QueuedForExtraction => AssistantProcessingStatus.QueuedForExtraction,
                AssistantProcessingStatusDto.Extracted => AssistantProcessingStatus.Extracted,
                AssistantProcessingStatusDto.ExtractionFailed => AssistantProcessingStatus.ExtractionFailed,
                AssistantProcessingStatusDto.Published => AssistantProcessingStatus.Published,
                _ => AssistantProcessingStatus.Unspecified
            },
            VisionSummary = dto.VisionSummary ?? string.Empty,
            CreatedUtc = ToTimestamp(dto.CreatedUtc)
        };

    public static AssistantFeedbackModel ToProto(AssistantFeedbackDto dto)
        => new()
        {
            Guid = dto.Guid.ToString(),
            UserId = dto.UserId,
            ConversationGuid = dto.ConversationGuid.ToString(),
            MessageGuid = dto.MessageGuid.ToString(),
            FeedbackType = MapFeedbackType(dto.FeedbackType),
            Comment = dto.Comment ?? string.Empty,
            CreatedUtc = ToTimestamp(dto.CreatedUtc)
        };

    public static AssistantDashboardSummaryModel ToProto(AssistantDashboardSummaryDto dto)
        => new()
        {
            TotalConversations = dto.TotalConversations,
            TotalMessages = dto.TotalMessages,
            PublishedKnowledgeItems = dto.PublishedKnowledgeItems,
            PublishedWorkflowTemplates = dto.PublishedWorkflowTemplates,
            UnhelpfulFeedbackCount = dto.UnhelpfulFeedbackCount,
            OpenContentGapCount = dto.OpenContentGapCount
        };

    public static AssistantFailedAnswerModel ToProto(AssistantFailedAnswerDto dto)
        => new()
        {
            ConversationGuid = dto.ConversationGuid.ToString(),
            MessageGuid = dto.MessageGuid.ToString(),
            ConversationTitle = dto.ConversationTitle ?? string.Empty,
            MessagePreview = dto.MessagePreview ?? string.Empty,
            ConfidenceScore = dto.ConfidenceScore,
            CreatedUtc = ToTimestamp(dto.CreatedUtc)
        };

    public static AssistantContentGapModel ToProto(AssistantContentGapDto dto)
        => new()
        {
            Guid = dto.Guid.ToString(),
            Title = dto.Title ?? string.Empty,
            Description = dto.Description ?? string.Empty,
            TopicCluster = dto.TopicCluster ?? string.Empty,
            OccurrenceCount = dto.OccurrenceCount,
            LastSeenUtc = ToTimestamp(dto.LastSeenUtc),
            Status = dto.Status switch
            {
                AssistantContentGapStatusDto.New => AssistantContentGapStatus.New,
                AssistantContentGapStatusDto.Reviewing => AssistantContentGapStatus.Reviewing,
                AssistantContentGapStatusDto.Assigned => AssistantContentGapStatus.Assigned,
                AssistantContentGapStatusDto.Addressed => AssistantContentGapStatus.Addressed,
                AssistantContentGapStatusDto.Closed => AssistantContentGapStatus.Closed,
                _ => AssistantContentGapStatus.Unspecified
            },
            SuggestedKnowledgeItemGuid = dto.SuggestedKnowledgeItemGuid?.ToString() ?? string.Empty,
            SuggestedKnowledgeItemTitle = dto.SuggestedKnowledgeItemTitle ?? string.Empty
        };

    public static AssistantTopicMetric ToProto(AssistantTopicMetricDto dto)
        => new()
        {
            Label = dto.Label ?? string.Empty,
            Count = dto.Count
        };

    public static AssistantSourceUsageMetric ToProto(AssistantSourceUsageMetricDto dto)
        => new()
        {
            SourceTitle = dto.SourceTitle ?? string.Empty,
            SourceTypeCode = dto.SourceTypeCode ?? string.Empty,
            UsageCount = dto.UsageCount
        };

    public static AssistantWorkflowUsageMetric ToProto(AssistantWorkflowUsageMetricDto dto)
        => new()
        {
            WorkflowTemplateGuid = dto.WorkflowTemplateGuid.ToString(),
            Title = dto.Title ?? string.Empty,
            UsageCount = dto.UsageCount
        };

    private static Timestamp ToTimestamp(DateTime? valueUtc)
        => AssistantGrpcServiceBase.ToTimestamp(valueUtc);

    private static StringValue? ToStringValue(string? value)
        => AssistantGrpcServiceBase.ToStringValue(value);
}
