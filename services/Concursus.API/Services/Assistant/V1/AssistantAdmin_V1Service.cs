using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Concursus.API.Assistant.V1;
using Concursus.API.Services.Assistant.Contracts;
using Grpc.Core;
using Microsoft.Extensions.Logging;

namespace Concursus.API.Services.Assistant.V1;

public sealed class AssistantAdmin_V1Service
    : AssistantAdminService.AssistantAdminServiceBase
{
    private readonly IAssistantV1ApplicationService _assistantService;
    private readonly ILogger<AssistantAdmin_V1Service> _logger;

    public AssistantAdmin_V1Service(
        IAssistantV1ApplicationService assistantService,
        ILogger<AssistantAdmin_V1Service> logger)
    {
        _assistantService = assistantService ?? throw new ArgumentNullException(nameof(assistantService));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public override Task<GetAssistantAdminDashboardSummaryReply> GetAdminDashboardSummary(GetAssistantAdminDashboardSummaryRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var summary = await _assistantService.GetAdminDashboardSummaryAsync(context.CancellationToken).ConfigureAwait(false);
            return new GetAssistantAdminDashboardSummaryReply { Summary = AssistantConversationServiceMapper.ToProto(summary) };
        }, _logger, nameof(GetAdminDashboardSummary));

    public override Task<ListAssistantFeedbackReply> ListFeedback(ListAssistantFeedbackRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var items = await _assistantService.ListFeedbackAsync(request.IncludeHelpful, request.IncludeUnhelpful, context.CancellationToken).ConfigureAwait(false);
            var reply = new ListAssistantFeedbackReply();
            reply.Feedback.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(ListFeedback));

    public override Task<ListAssistantFailedAnswersReply> ListFailedAnswers(ListAssistantFailedAnswersRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var take = request.Take <= 0 ? 25 : request.Take;
            var items = await _assistantService.ListFailedAnswersAsync(request.MaxConfidenceScore, take, context.CancellationToken).ConfigureAwait(false);

            var reply = new ListAssistantFailedAnswersReply();
            reply.FailedAnswers.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(ListFailedAnswers));

    public override Task<ListAssistantContentGapsReply> ListContentGaps(ListAssistantContentGapsRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var items = await _assistantService.ListContentGapsAsync(
                AssistantConversationServiceMapper.MapContentGapStatus(request.Status),
                context.CancellationToken).ConfigureAwait(false);

            var reply = new ListAssistantContentGapsReply();
            reply.Gaps.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(ListContentGaps));

    public override Task<AssignAssistantContentGapReply> AssignContentGap(AssignAssistantContentGapRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var gap = await _assistantService.AssignContentGapAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.ContentGapGuid, nameof(request.ContentGapGuid)),
                AssistantConversationServiceMapper.ParseOptionalGuid(request.SuggestedKnowledgeItemGuid, nameof(request.SuggestedKnowledgeItemGuid)),
                AssistantConversationServiceMapper.MapContentGapStatus(request.Status),
                context.CancellationToken).ConfigureAwait(false);

            return new AssignAssistantContentGapReply { Gap = AssistantConversationServiceMapper.ToProto(gap) };
        }, _logger, nameof(AssignContentGap));

    public override Task<ResolveAssistantContentGapReply> ResolveContentGap(ResolveAssistantContentGapRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var gap = await _assistantService.ResolveContentGapAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.ContentGapGuid, nameof(request.ContentGapGuid)),
                AssistantConversationServiceMapper.MapContentGapStatus(request.Status),
                context.CancellationToken).ConfigureAwait(false);

            return new ResolveAssistantContentGapReply { Gap = AssistantConversationServiceMapper.ToProto(gap) };
        }, _logger, nameof(ResolveContentGap));
}
