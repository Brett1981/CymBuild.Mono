using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Concursus.API.Assistant.V1;
using Concursus.API.Services.Assistant.Contracts;
using Grpc.Core;
using Microsoft.Extensions.Logging;

namespace Concursus.API.Services.Assistant.V1;

public sealed class AssistantUpload_V1Service
    : AssistantUploadService.AssistantUploadServiceBase
{
    private readonly IAssistantV1ApplicationService _assistantService;
    private readonly ILogger<AssistantUpload_V1Service> _logger;

    public AssistantUpload_V1Service(
        IAssistantV1ApplicationService assistantService,
        ILogger<AssistantUpload_V1Service> logger)
    {
        _assistantService = assistantService ?? throw new ArgumentNullException(nameof(assistantService));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public override Task<CreateAssistantUploadSessionReply> CreateUploadSession(CreateAssistantUploadSessionRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var result = await _assistantService.CreateUploadSessionAsync(
                new CreateAssistantUploadSessionCommand(
                    UserId: AssistantConversationServiceMapper.RequirePositiveInt(request.UserId, nameof(request.UserId)),
                    UploadPurpose: AssistantConversationServiceMapper.MapUploadPurpose(request.UploadPurpose),
                    FileName: AssistantConversationServiceMapper.RequireText(request.FileName, nameof(request.FileName), 500),
                    ContentType: AssistantConversationServiceMapper.RequireText(request.ContentType, nameof(request.ContentType), 200),
                    FileSizeBytes: request.FileSizeBytes),
                context.CancellationToken).ConfigureAwait(false);

            var reply = new CreateAssistantUploadSessionReply
            {
                UploadGuid = result.UploadGuid.ToString(),
                UploadUrl = result.UploadUrl
            };

            reply.UploadHeaders.Add((IDictionary<string, string>)result.UploadHeaders);
            return reply;
        }, _logger, nameof(CreateUploadSession));

    public override Task<CompleteAssistantUploadReply> CompleteUpload(CompleteAssistantUploadRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var upload = await _assistantService.CompleteUploadAsync(
                new CompleteAssistantUploadCommand(
                    UploadGuid: AssistantConversationServiceMapper.ParseRequiredGuid(request.UploadGuid, nameof(request.UploadGuid)),
                    ConversationGuid: AssistantConversationServiceMapper.ParseOptionalGuid(request.ConversationGuid, nameof(request.ConversationGuid)),
                    KnowledgeItemGuid: AssistantConversationServiceMapper.ParseOptionalGuid(request.KnowledgeItemGuid, nameof(request.KnowledgeItemGuid)),
                    StorageUrl: AssistantConversationServiceMapper.RequireText(request.StorageUrl, nameof(request.StorageUrl), 1000),
                    FileName: AssistantConversationServiceMapper.RequireText(request.FileName, nameof(request.FileName), 500),
                    ContentType: AssistantConversationServiceMapper.RequireText(request.ContentType, nameof(request.ContentType), 200),
                    FileSizeBytes: request.FileSizeBytes,
                    UploadPurpose: AssistantConversationServiceMapper.MapUploadPurpose(request.UploadPurpose),
                    ProcessingStatus: AssistantConversationServiceMapper.MapProcessingStatus(request.ProcessingStatus)),
                context.CancellationToken).ConfigureAwait(false);

            return new CompleteAssistantUploadReply { Upload = AssistantConversationServiceMapper.ToProto(upload) };
        }, _logger, nameof(CompleteUpload));

    public override Task<ListAssistantUserUploadsReply> ListUserUploads(ListAssistantUserUploadsRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var items = await _assistantService.ListUserUploadsAsync(
                AssistantConversationServiceMapper.RequirePositiveInt(request.UserId, nameof(request.UserId)),
                context.CancellationToken).ConfigureAwait(false);

            var reply = new ListAssistantUserUploadsReply();
            reply.Uploads.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(ListUserUploads));

    public override Task<AnalyzeAssistantScreenshotReply> AnalyzeScreenshot(AnalyzeAssistantScreenshotRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var result = await _assistantService.AnalyzeScreenshotAsync(
                new AnalyzeAssistantScreenshotCommand(
                    UploadGuid: AssistantConversationServiceMapper.ParseRequiredGuid(request.UploadGuid, nameof(request.UploadGuid)),
                    ConversationGuid: AssistantConversationServiceMapper.ParseOptionalGuid(request.ConversationGuid, nameof(request.ConversationGuid)),
                    Mode: AssistantConversationServiceMapper.MapMode(request.Mode)),
                context.CancellationToken).ConfigureAwait(false);

            var reply = new AnalyzeAssistantScreenshotReply
            {
                UploadGuid = result.UploadGuid.ToString(),
                DetectedScreenSummary = result.DetectedScreenSummary ?? string.Empty,
                ConfidenceScore = result.ConfidenceScore
            };

            reply.NotableSections.AddRange(result.NotableSections);
            reply.LikelyNextActions.AddRange(result.LikelyNextActions);
            reply.PossibleMistakes.AddRange(result.PossibleMistakes);

            return reply;
        }, _logger, nameof(AnalyzeScreenshot));

    public override Task<AttachAssistantUploadToConversationReply> AttachUploadToConversation(AttachAssistantUploadToConversationRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var upload = await _assistantService.AttachUploadToConversationAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.UploadGuid, nameof(request.UploadGuid)),
                AssistantConversationServiceMapper.ParseRequiredGuid(request.ConversationGuid, nameof(request.ConversationGuid)),
                context.CancellationToken).ConfigureAwait(false);

            return new AttachAssistantUploadToConversationReply { Upload = AssistantConversationServiceMapper.ToProto(upload) };
        }, _logger, nameof(AttachUploadToConversation));
}
