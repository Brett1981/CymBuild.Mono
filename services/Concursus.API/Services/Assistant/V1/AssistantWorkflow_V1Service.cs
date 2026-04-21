using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Concursus.API.Assistant.V1;
using Concursus.API.Services.Assistant.Contracts;
using Grpc.Core;
using Microsoft.Extensions.Logging;

namespace Concursus.API.Services.Assistant.V1;

public sealed class AssistantWorkflow_V1Service
    : AssistantWorkflowService.AssistantWorkflowServiceBase
{
    private readonly IAssistantV1ApplicationService _assistantService;
    private readonly ILogger<AssistantWorkflow_V1Service> _logger;

    public AssistantWorkflow_V1Service(
        IAssistantV1ApplicationService assistantService,
        ILogger<AssistantWorkflow_V1Service> logger)
    {
        _assistantService = assistantService ?? throw new ArgumentNullException(nameof(assistantService));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public override Task<ListAssistantWorkflowTemplatesReply> ListWorkflowTemplates(ListAssistantWorkflowTemplatesRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var items = await _assistantService.ListWorkflowTemplatesAsync(
                new ListAssistantWorkflowTemplatesCommand(
                    PublishedOnly: request.PublishedOnly,
                    FeaturedOnly: request.FeaturedOnly,
                    AudienceCode: AssistantConversationServiceMapper.Unwrap(request.AudienceCode)),
                context.CancellationToken).ConfigureAwait(false);

            var reply = new ListAssistantWorkflowTemplatesReply();
            reply.Templates.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(ListWorkflowTemplates));

    public override Task<GetAssistantWorkflowTemplateReply> GetWorkflowTemplate(GetAssistantWorkflowTemplateRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var item = await _assistantService.GetWorkflowTemplateAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.WorkflowTemplateGuid, nameof(request.WorkflowTemplateGuid)),
                context.CancellationToken).ConfigureAwait(false);

            if (item is null)
            {
                throw AssistantConversationServiceMapper.CreateRpcException(StatusCode.NotFound, "Workflow template not found.");
            }

            return new GetAssistantWorkflowTemplateReply { Template = AssistantConversationServiceMapper.ToProto(item) };
        }, _logger, nameof(GetWorkflowTemplate));

    public override Task<StartAssistantWorkflowRunReply> StartWorkflowRun(StartAssistantWorkflowRunRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var run = await _assistantService.StartWorkflowRunAsync(
                new StartAssistantWorkflowRunCommand(
                    UserId: AssistantConversationServiceMapper.RequirePositiveInt(request.UserId, nameof(request.UserId)),
                    WorkflowTemplateGuid: AssistantConversationServiceMapper.ParseRequiredGuid(request.WorkflowTemplateGuid, nameof(request.WorkflowTemplateGuid)),
                    ConversationGuid: AssistantConversationServiceMapper.ParseOptionalGuid(request.ConversationGuid, nameof(request.ConversationGuid)),
                    InputJson: AssistantConversationServiceMapper.Unwrap(request.InputJson)),
                context.CancellationToken).ConfigureAwait(false);

            return new StartAssistantWorkflowRunReply { Run = AssistantConversationServiceMapper.ToProto(run) };
        }, _logger, nameof(StartWorkflowRun));

    public override Task<AdvanceAssistantWorkflowRunReply> AdvanceWorkflowRun(AdvanceAssistantWorkflowRunRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var run = await _assistantService.AdvanceWorkflowRunAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.WorkflowRunGuid, nameof(request.WorkflowRunGuid)),
                AssistantConversationServiceMapper.Unwrap(request.OutputJson),
                context.CancellationToken).ConfigureAwait(false);

            return new AdvanceAssistantWorkflowRunReply { Run = AssistantConversationServiceMapper.ToProto(run) };
        }, _logger, nameof(AdvanceWorkflowRun));

    public override Task<CompleteAssistantWorkflowRunReply> CompleteWorkflowRun(CompleteAssistantWorkflowRunRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var run = await _assistantService.CompleteWorkflowRunAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.WorkflowRunGuid, nameof(request.WorkflowRunGuid)),
                AssistantConversationServiceMapper.Unwrap(request.OutputJson),
                context.CancellationToken).ConfigureAwait(false);

            return new CompleteAssistantWorkflowRunReply { Run = AssistantConversationServiceMapper.ToProto(run) };
        }, _logger, nameof(CompleteWorkflowRun));

    public override Task<ListAssistantPlaybooksReply> ListPlaybooks(ListAssistantPlaybooksRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var items = await _assistantService.ListPlaybooksAsync(
                AssistantConversationServiceMapper.RequirePositiveInt(request.UserId, nameof(request.UserId)),
                request.IncludeFeatured,
                context.CancellationToken).ConfigureAwait(false);

            var reply = new ListAssistantPlaybooksReply();
            reply.Playbooks.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(ListPlaybooks));

    public override Task<GetAssistantPlaybookReply> GetPlaybook(GetAssistantPlaybookRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var item = await _assistantService.GetPlaybookAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.PlaybookGuid, nameof(request.PlaybookGuid)),
                context.CancellationToken).ConfigureAwait(false);

            if (item is null)
            {
                throw AssistantConversationServiceMapper.CreateRpcException(StatusCode.NotFound, "Playbook not found.");
            }

            return new GetAssistantPlaybookReply { Playbook = AssistantConversationServiceMapper.ToProto(item) };
        }, _logger, nameof(GetPlaybook));

    public override Task<CreateAssistantWorkflowTemplateReply> CreateWorkflowTemplate(CreateAssistantWorkflowTemplateRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var item = await _assistantService.CreateWorkflowTemplateAsync(
                new CreateAssistantWorkflowTemplateCommand(
                    Code: AssistantConversationServiceMapper.RequireText(request.Code, nameof(request.Code), 50),
                    Title: AssistantConversationServiceMapper.RequireText(request.Title, nameof(request.Title), 250),
                    Summary: AssistantConversationServiceMapper.Unwrap(request.Summary),
                    AudienceCode: AssistantConversationServiceMapper.Unwrap(request.AudienceCode),
                    TemplatePrompt: AssistantConversationServiceMapper.RequireText(request.TemplatePrompt, nameof(request.TemplatePrompt)),
                    ClarificationSchemaJson: AssistantConversationServiceMapper.Unwrap(request.ClarificationSchemaJson),
                    OutputFormatCode: AssistantConversationServiceMapper.RequireText(request.OutputFormatCode, nameof(request.OutputFormatCode), 30),
                    IsPublished: request.IsPublished,
                    IsFeatured: request.IsFeatured,
                    CreatedByUserId: AssistantConversationServiceMapper.RequirePositiveInt(request.CreatedByUserId, nameof(request.CreatedByUserId))),
                context.CancellationToken).ConfigureAwait(false);

            return new CreateAssistantWorkflowTemplateReply { Template = AssistantConversationServiceMapper.ToProto(item) };
        }, _logger, nameof(CreateWorkflowTemplate));

    public override Task<UpdateAssistantWorkflowTemplateReply> UpdateWorkflowTemplate(UpdateAssistantWorkflowTemplateRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var item = await _assistantService.UpdateWorkflowTemplateAsync(
                new UpdateAssistantWorkflowTemplateCommand(
                    WorkflowTemplateGuid: AssistantConversationServiceMapper.ParseRequiredGuid(request.WorkflowTemplateGuid, nameof(request.WorkflowTemplateGuid)),
                    Code: AssistantConversationServiceMapper.RequireText(request.Code, nameof(request.Code), 50),
                    Title: AssistantConversationServiceMapper.RequireText(request.Title, nameof(request.Title), 250),
                    Summary: AssistantConversationServiceMapper.Unwrap(request.Summary),
                    AudienceCode: AssistantConversationServiceMapper.Unwrap(request.AudienceCode),
                    TemplatePrompt: AssistantConversationServiceMapper.RequireText(request.TemplatePrompt, nameof(request.TemplatePrompt)),
                    ClarificationSchemaJson: AssistantConversationServiceMapper.Unwrap(request.ClarificationSchemaJson),
                    OutputFormatCode: AssistantConversationServiceMapper.RequireText(request.OutputFormatCode, nameof(request.OutputFormatCode), 30),
                    IsPublished: request.IsPublished,
                    IsFeatured: request.IsFeatured),
                context.CancellationToken).ConfigureAwait(false);

            return new UpdateAssistantWorkflowTemplateReply { Template = AssistantConversationServiceMapper.ToProto(item) };
        }, _logger, nameof(UpdateWorkflowTemplate));

    public override Task<PublishAssistantWorkflowTemplateReply> PublishWorkflowTemplate(PublishAssistantWorkflowTemplateRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var item = await _assistantService.PublishWorkflowTemplateAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.WorkflowTemplateGuid, nameof(request.WorkflowTemplateGuid)),
                request.IsPublished,
                context.CancellationToken).ConfigureAwait(false);

            return new PublishAssistantWorkflowTemplateReply { Template = AssistantConversationServiceMapper.ToProto(item) };
        }, _logger, nameof(PublishWorkflowTemplate));

    public override Task<FeatureAssistantWorkflowTemplateReply> FeatureWorkflowTemplate(FeatureAssistantWorkflowTemplateRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var item = await _assistantService.FeatureWorkflowTemplateAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.WorkflowTemplateGuid, nameof(request.WorkflowTemplateGuid)),
                request.IsFeatured,
                context.CancellationToken).ConfigureAwait(false);

            return new FeatureAssistantWorkflowTemplateReply { Template = AssistantConversationServiceMapper.ToProto(item) };
        }, _logger, nameof(FeatureWorkflowTemplate));
}
