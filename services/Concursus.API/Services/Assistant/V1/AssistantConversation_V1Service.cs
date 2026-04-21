using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Concursus.API.Assistant.V1;
using Concursus.API.Services.Assistant.Contracts;
using Grpc.Core;
using Microsoft.Extensions.Logging;

namespace Concursus.API.Services.Assistant.V1;

public sealed class AssistantConversation_V1Service
    : AssistantConversationService.AssistantConversationServiceBase
{
    private readonly IAssistantV1ApplicationService _assistantService;
    private readonly ILogger<AssistantConversation_V1Service> _logger;

    public AssistantConversation_V1Service(
        IAssistantV1ApplicationService assistantService,
        ILogger<AssistantConversation_V1Service> logger)
    {
        _assistantService = assistantService ?? throw new ArgumentNullException(nameof(assistantService));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public override Task<CreateAssistantConversationReply> CreateConversation(CreateAssistantConversationRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var command = new CreateAssistantConversationCommand(
                UserId: AssistantConversationServiceMapper.RequirePositiveInt(request.UserId, nameof(request.UserId)),
                Title: AssistantConversationServiceMapper.RequireText(request.Title, nameof(request.Title), 250),
                Mode: AssistantConversationServiceMapper.MapMode(request.Mode),
                LanguageCode: AssistantConversationServiceMapper.Unwrap(request.LanguageCode),
                StartedFromWorkflowTemplateGuid: AssistantConversationServiceMapper.ParseOptionalGuid(request.StartedFromWorkflowTemplateGuid, nameof(request.StartedFromWorkflowTemplateGuid)));

            var conversation = await _assistantService.CreateConversationAsync(command, context.CancellationToken).ConfigureAwait(false);

            return new CreateAssistantConversationReply
            {
                Conversation = AssistantConversationServiceMapper.ToProto(conversation)
            };
        }, _logger, nameof(CreateConversation));

    public override Task<GetAssistantConversationReply> GetConversation(GetAssistantConversationRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var conversationGuid = AssistantConversationServiceMapper.ParseRequiredGuid(request.ConversationGuid, nameof(request.ConversationGuid));
            var conversation = await _assistantService.GetConversationAsync(conversationGuid, context.CancellationToken).ConfigureAwait(false);

            if (conversation is null)
            {
                throw AssistantConversationServiceMapper.CreateRpcException(StatusCode.NotFound, "Conversation not found.");
            }

            return new GetAssistantConversationReply
            {
                Conversation = AssistantConversationServiceMapper.ToProto(conversation)
            };
        }, _logger, nameof(GetConversation));

    public override Task<ListAssistantConversationsForUserReply> ListConversationsForUser(ListAssistantConversationsForUserRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var userId = AssistantConversationServiceMapper.RequirePositiveInt(request.UserId, nameof(request.UserId));
            var items = await _assistantService.ListConversationsForUserAsync(userId, request.IncludeArchived, context.CancellationToken).ConfigureAwait(false);

            var reply = new ListAssistantConversationsForUserReply();
            reply.Conversations.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(ListConversationsForUser));

    public override Task<RenameAssistantConversationReply> RenameConversation(RenameAssistantConversationRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var conversation = await _assistantService.RenameConversationAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.ConversationGuid, nameof(request.ConversationGuid)),
                AssistantConversationServiceMapper.RequireText(request.Title, nameof(request.Title), 250),
                context.CancellationToken).ConfigureAwait(false);

            return new RenameAssistantConversationReply
            {
                Conversation = AssistantConversationServiceMapper.ToProto(conversation)
            };
        }, _logger, nameof(RenameConversation));

    public override Task<ArchiveAssistantConversationReply> ArchiveConversation(ArchiveAssistantConversationRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var conversation = await _assistantService.ArchiveConversationAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.ConversationGuid, nameof(request.ConversationGuid)),
                request.IsArchived,
                context.CancellationToken).ConfigureAwait(false);

            return new ArchiveAssistantConversationReply
            {
                Conversation = AssistantConversationServiceMapper.ToProto(conversation)
            };
        }, _logger, nameof(ArchiveConversation));

    public override Task<DeleteAssistantConversationReply> DeleteConversation(DeleteAssistantConversationRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var success = await _assistantService.DeleteConversationAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.ConversationGuid, nameof(request.ConversationGuid)),
                context.CancellationToken).ConfigureAwait(false);

            return new DeleteAssistantConversationReply { Success = success };
        }, _logger, nameof(DeleteConversation));

    public override Task<GetAssistantConversationMessagesReply> GetConversationMessages(GetAssistantConversationMessagesRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var items = await _assistantService.GetConversationMessagesAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.ConversationGuid, nameof(request.ConversationGuid)),
                context.CancellationToken).ConfigureAwait(false);

            var reply = new GetAssistantConversationMessagesReply();
            reply.Messages.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(GetConversationMessages));
}
