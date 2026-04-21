using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Concursus.API.Assistant.V1;
using Concursus.API.Services.Assistant.Contracts;
using Grpc.Core;
using Microsoft.Extensions.Logging;

namespace Concursus.API.Services.Assistant.V1;

public sealed class AssistantAnalytics_V1Service
    : AssistantAnalyticsService.AssistantAnalyticsServiceBase
{
    private readonly IAssistantV1ApplicationService _assistantService;
    private readonly ILogger<AssistantAnalytics_V1Service> _logger;

    public AssistantAnalytics_V1Service(
        IAssistantV1ApplicationService assistantService,
        ILogger<AssistantAnalytics_V1Service> logger)
    {
        _assistantService = assistantService ?? throw new ArgumentNullException(nameof(assistantService));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public override Task<GetAssistantTopQuestionsReply> GetTopQuestions(GetAssistantTopQuestionsRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var take = request.Take <= 0 ? 10 : request.Take;
            var items = await _assistantService.GetTopQuestionsAsync(take, context.CancellationToken).ConfigureAwait(false);

            var reply = new GetAssistantTopQuestionsReply();
            reply.Topics.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(GetTopQuestions));

    public override Task<GetAssistantTopicTrendsReply> GetTopicTrends(GetAssistantTopicTrendsRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var days = request.Days <= 0 ? 30 : request.Days;
            var items = await _assistantService.GetTopicTrendsAsync(days, context.CancellationToken).ConfigureAwait(false);

            var reply = new GetAssistantTopicTrendsReply();
            reply.Topics.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(GetTopicTrends));

    public override Task<GetAssistantFailedAnswerSummaryReply> GetFailedAnswerSummary(GetAssistantFailedAnswerSummaryRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var days = request.Days <= 0 ? 30 : request.Days;
            var summary = await _assistantService.GetFailedAnswerSummaryAsync(days, context.CancellationToken).ConfigureAwait(false);

            return new GetAssistantFailedAnswerSummaryReply
            {
                FailedAnswerCount = summary.FailedAnswerCount,
                UnhelpfulFeedbackCount = summary.UnhelpfulFeedbackCount
            };
        }, _logger, nameof(GetFailedAnswerSummary));

    public override Task<GetAssistantSourceUsageSummaryReply> GetSourceUsageSummary(GetAssistantSourceUsageSummaryRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var take = request.Take <= 0 ? 10 : request.Take;
            var items = await _assistantService.GetSourceUsageSummaryAsync(take, context.CancellationToken). ConfigureAwait(false);

            var reply = new GetAssistantSourceUsageSummaryReply();
            reply.Sources.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(GetSourceUsageSummary));

    public override Task<GetAssistantWorkflowUsageSummaryReply> GetWorkflowUsageSummary(GetAssistantWorkflowUsageSummaryRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var take = request.Take <= 0 ? 10 : request.Take;
            var items = await _assistantService.GetWorkflowUsageSummaryAsync(take, context.CancellationToken).ConfigureAwait(false);

            var reply = new GetAssistantWorkflowUsageSummaryReply();
            reply.Workflows.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(GetWorkflowUsageSummary));
}
