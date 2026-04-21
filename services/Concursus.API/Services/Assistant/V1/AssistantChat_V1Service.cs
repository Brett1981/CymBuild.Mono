using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Concursus.API.Assistant.V1;
using Concursus.API.Services.Assistant.Contracts;
using Grpc.Core;
using Microsoft.Extensions.Logging;

namespace Concursus.API.Services.Assistant.V1;

public sealed class AssistantChat_V1Service
    : AssistantChatService.AssistantChatServiceBase
{
    private readonly IAssistantV1ApplicationService _assistantService;
    private readonly ILogger<AssistantChat_V1Service> _logger;

    public AssistantChat_V1Service(
        IAssistantV1ApplicationService assistantService,
        ILogger<AssistantChat_V1Service> logger)
    {
        _assistantService = assistantService ?? throw new ArgumentNullException(nameof(assistantService));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public override async Task SendMessage(SendAssistantMessageRequest request, IServerStreamWriter<SendAssistantMessageReply> responseStream, ServerCallContext context)
    {
        await AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var command = new SendAssistantMessageCommand(
                ConversationGuid: AssistantConversationServiceMapper.ParseRequiredGuid(request.ConversationGuid, nameof(request.ConversationGuid)),
                UserId: AssistantConversationServiceMapper.RequirePositiveInt(request.UserId, nameof(request.UserId)),
                UserMessage: AssistantConversationServiceMapper.RequireText(request.UserMessage, nameof(request.UserMessage)),
                Mode: AssistantConversationServiceMapper.MapMode(request.Mode),
                WorkflowTemplateGuid: AssistantConversationServiceMapper.ParseOptionalGuid(request.WorkflowTemplateGuid, nameof(request.WorkflowTemplateGuid)),
                AttachedUploadGuids: request.AttachedUploadGuids
                    .Select(g => AssistantConversationServiceMapper.ParseRequiredGuid(g, nameof(request.AttachedUploadGuids)))
                    .ToArray(),
                LanguageCode: AssistantConversationServiceMapper.Unwrap(request.LanguageCode));

            await foreach (var evt in _assistantService.SendMessageAsync(command, context.CancellationToken).ConfigureAwait(false))
            {
                await responseStream.WriteAsync(AssistantConversationServiceMapper.ToProto(evt)).ConfigureAwait(false);
            }

            return true;
        }, _logger, nameof(SendMessage)).ConfigureAwait(false);
    }

    public override async Task RegenerateAnswer(RegenerateAssistantAnswerRequest request, IServerStreamWriter<SendAssistantMessageReply> responseStream, ServerCallContext context)
    {
        await AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var command = new RegenerateAssistantAnswerCommand(
                ConversationGuid: AssistantConversationServiceMapper.ParseRequiredGuid(request.ConversationGuid, nameof(request.ConversationGuid)),
                ParentMessageGuid: AssistantConversationServiceMapper.ParseRequiredGuid(request.ParentMessageGuid, nameof(request.ParentMessageGuid)),
                Mode: AssistantConversationServiceMapper.MapMode(request.Mode));

            await foreach (var evt in _assistantService.RegenerateAnswerAsync(command, context.CancellationToken).ConfigureAwait(false))
            {
                await responseStream.WriteAsync(AssistantConversationServiceMapper.ToProto(evt)).ConfigureAwait(false);
            }

            return true;
        }, _logger, nameof(RegenerateAnswer)).ConfigureAwait(false);
    }

    public override Task<ConvertAssistantAnswerToChecklistReply> ConvertAnswerToChecklist(ConvertAssistantAnswerToChecklistRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var checklist = await _assistantService.ConvertAnswerToChecklistAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.MessageGuid, nameof(request.MessageGuid)),
                context.CancellationToken).ConfigureAwait(false);

            return new ConvertAssistantAnswerToChecklistReply
            {
                ChecklistMarkdown = checklist ?? string.Empty
            };
        }, _logger, nameof(ConvertAnswerToChecklist));

    public override Task<SaveAssistantAnswerAsPlaybookReply> SaveAnswerAsPlaybook(SaveAssistantAnswerAsPlaybookRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var playbookGuid = await _assistantService.SaveAnswerAsPlaybookAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.MessageGuid, nameof(request.MessageGuid)),
                AssistantConversationServiceMapper.RequireText(request.Title, nameof(request.Title), 250),
                AssistantConversationServiceMapper.MapVisibility(request.Visibility),
                context.CancellationToken).ConfigureAwait(false);

            return new SaveAssistantAnswerAsPlaybookReply
            {
                PlaybookGuid = playbookGuid.ToString()
            };
        }, _logger, nameof(SaveAnswerAsPlaybook));
}
