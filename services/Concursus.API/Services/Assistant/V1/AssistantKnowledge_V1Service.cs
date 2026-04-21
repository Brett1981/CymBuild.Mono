using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Concursus.API.Assistant.V1;
using Concursus.API.Services.Assistant.Contracts;
using Grpc.Core;
using Microsoft.Extensions.Logging;

namespace Concursus.API.Services.Assistant.V1;

public sealed class AssistantKnowledge_V1Service
    : AssistantKnowledgeService.AssistantKnowledgeServiceBase
{
    private readonly IAssistantV1ApplicationService _assistantService;
    private readonly ILogger<AssistantKnowledge_V1Service> _logger;

    public AssistantKnowledge_V1Service(
        IAssistantV1ApplicationService assistantService,
        ILogger<AssistantKnowledge_V1Service> logger)
    {
        _assistantService = assistantService ?? throw new ArgumentNullException(nameof(assistantService));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public override Task<SearchAssistantKnowledgeReply> SearchKnowledge(SearchAssistantKnowledgeRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var items = await _assistantService.SearchKnowledgeAsync(
                new SearchAssistantKnowledgeCommand(
                    SearchText: AssistantConversationServiceMapper.NullIfWhiteSpace(request.SearchText) ?? string.Empty,
                    CategoryGuid: AssistantConversationServiceMapper.ParseOptionalGuid(request.CategoryGuid, nameof(request.CategoryGuid)),
                    PublishedOnly: request.PublishedOnly,
                    AuthoritativeFirst: request.AuthoritativeFirst),
                context.CancellationToken).ConfigureAwait(false);

            var reply = new SearchAssistantKnowledgeReply();
            reply.Items.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(SearchKnowledge));

    public override Task<GetAssistantKnowledgeItemReply> GetKnowledgeItem(GetAssistantKnowledgeItemRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var item = await _assistantService.GetKnowledgeItemAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.KnowledgeItemGuid, nameof(request.KnowledgeItemGuid)),
                context.CancellationToken).ConfigureAwait(false);

            if (item is null)
            {
                throw AssistantConversationServiceMapper.CreateRpcException(StatusCode.NotFound, "Knowledge item not found.");
            }

            return new GetAssistantKnowledgeItemReply { Item = AssistantConversationServiceMapper.ToProto(item) };
        }, _logger, nameof(GetKnowledgeItem));

    public override Task<GetAssistantKnowledgeCategoriesReply> GetKnowledgeCategories(GetAssistantKnowledgeCategoriesRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var items = await _assistantService.GetKnowledgeCategoriesAsync(context.CancellationToken).ConfigureAwait(false);
            var reply = new GetAssistantKnowledgeCategoriesReply();
            reply.Categories.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(GetKnowledgeCategories));

    public override Task<GetAssistantFeaturedKnowledgeReply> GetFeaturedKnowledge(GetAssistantFeaturedKnowledgeRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var take = request.Take <= 0 ? 10 : request.Take;
            var items = await _assistantService.GetFeaturedKnowledgeAsync(take, context.CancellationToken).ConfigureAwait(false);
            var reply = new GetAssistantFeaturedKnowledgeReply();
            reply.Items.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(GetFeaturedKnowledge));

    public override Task<GetAssistantRelatedKnowledgeReply> GetRelatedKnowledge(GetAssistantRelatedKnowledgeRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var take = request.Take <= 0 ? 5 : request.Take;
            var items = await _assistantService.GetRelatedKnowledgeAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.KnowledgeItemGuid, nameof(request.KnowledgeItemGuid)),
                take,
                context.CancellationToken).ConfigureAwait(false);

            var reply = new GetAssistantRelatedKnowledgeReply();
            reply.Items.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(GetRelatedKnowledge));

    public override Task<CreateAssistantKnowledgeItemReply> CreateKnowledgeItem(CreateAssistantKnowledgeItemRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var item = await _assistantService.CreateKnowledgeItemAsync(
                new CreateAssistantKnowledgeItemCommand(
                    Title: AssistantConversationServiceMapper.RequireText(request.Title, nameof(request.Title), 500),
                    Slug: AssistantConversationServiceMapper.RequireText(request.Slug, nameof(request.Slug), 500),
                    KnowledgeCategoryGuid: AssistantConversationServiceMapper.ParseOptionalGuid(request.KnowledgeCategoryGuid, nameof(request.KnowledgeCategoryGuid)),
                    ContentTypeCode: AssistantConversationServiceMapper.RequireText(request.ContentTypeCode, nameof(request.ContentTypeCode), 30),
                    SourceTypeCode: AssistantConversationServiceMapper.RequireText(request.SourceTypeCode, nameof(request.SourceTypeCode), 30),
                    StorageUrl: AssistantConversationServiceMapper.RequireText(request.StorageUrl, nameof(request.StorageUrl), 1000),
                    PreviewUrl: AssistantConversationServiceMapper.Unwrap(request.PreviewUrl),
                    Summary: AssistantConversationServiceMapper.Unwrap(request.Summary),
                    IsAuthoritative: request.IsAuthoritative,
                    IsPublished: request.IsPublished,
                    CreatedByUserId: AssistantConversationServiceMapper.RequirePositiveInt(request.CreatedByUserId, nameof(request.CreatedByUserId))),
                context.CancellationToken).ConfigureAwait(false);

            return new CreateAssistantKnowledgeItemReply { Item = AssistantConversationServiceMapper.ToProto(item) };
        }, _logger, nameof(CreateKnowledgeItem));

    public override Task<UpdateAssistantKnowledgeItemReply> UpdateKnowledgeItem(UpdateAssistantKnowledgeItemRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var item = await _assistantService.UpdateKnowledgeItemAsync(
                new UpdateAssistantKnowledgeItemCommand(
                    KnowledgeItemGuid: AssistantConversationServiceMapper.ParseRequiredGuid(request.KnowledgeItemGuid, nameof(request.KnowledgeItemGuid)),
                    Title: AssistantConversationServiceMapper.RequireText(request.Title, nameof(request.Title), 500),
                    Slug: AssistantConversationServiceMapper.RequireText(request.Slug, nameof(request.Slug), 500),
                    KnowledgeCategoryGuid: AssistantConversationServiceMapper.ParseOptionalGuid(request.KnowledgeCategoryGuid, nameof(request.KnowledgeCategoryGuid)),
                    ContentTypeCode: AssistantConversationServiceMapper.RequireText(request.ContentTypeCode, nameof(request.ContentTypeCode), 30),
                    SourceTypeCode: AssistantConversationServiceMapper.RequireText(request.SourceTypeCode, nameof(request.SourceTypeCode), 30),
                    StorageUrl: AssistantConversationServiceMapper.RequireText(request.StorageUrl, nameof(request.StorageUrl), 1000),
                    PreviewUrl: AssistantConversationServiceMapper.Unwrap(request.PreviewUrl),
                    Summary: AssistantConversationServiceMapper.Unwrap(request.Summary),
                    IsAuthoritative: request.IsAuthoritative,
                    IsPublished: request.IsPublished,
                    UpdatedByUserId: AssistantConversationServiceMapper.RequirePositiveInt(request.UpdatedByUserId, nameof(request.UpdatedByUserId))),
                context.CancellationToken).ConfigureAwait(false);

            return new UpdateAssistantKnowledgeItemReply { Item = AssistantConversationServiceMapper.ToProto(item) };
        }, _logger, nameof(UpdateKnowledgeItem));

    public override Task<PublishAssistantKnowledgeItemReply> PublishKnowledgeItem(PublishAssistantKnowledgeItemRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var item = await _assistantService.PublishKnowledgeItemAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.KnowledgeItemGuid, nameof(request.KnowledgeItemGuid)),
                request.IsPublished,
                AssistantConversationServiceMapper.RequirePositiveInt(request.UpdatedByUserId, nameof(request.UpdatedByUserId)),
                context.CancellationToken).ConfigureAwait(false);

            return new PublishAssistantKnowledgeItemReply { Item = AssistantConversationServiceMapper.ToProto(item) };
        }, _logger, nameof(PublishKnowledgeItem));

    public override Task<ReplaceAssistantKnowledgeItemVersionReply> ReplaceKnowledgeItemVersion(ReplaceAssistantKnowledgeItemVersionRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var version = await _assistantService.ReplaceKnowledgeItemVersionAsync(
                new ReplaceAssistantKnowledgeItemVersionCommand(
                    KnowledgeItemGuid: AssistantConversationServiceMapper.ParseRequiredGuid(request.KnowledgeItemGuid, nameof(request.KnowledgeItemGuid)),
                    StorageUrl: AssistantConversationServiceMapper.RequireText(request.StorageUrl, nameof(request.StorageUrl), 1000),
                    ExtractedText: AssistantConversationServiceMapper.Unwrap(request.ExtractedText),
                    ExtractionStatusCode: AssistantConversationServiceMapper.RequireText(request.ExtractionStatusCode, nameof(request.ExtractionStatusCode), 30),
                    MetadataJson: AssistantConversationServiceMapper.Unwrap(request.MetadataJson),
                    FileHash: AssistantConversationServiceMapper.Unwrap(request.FileHash),
                    CreatedByUserId: AssistantConversationServiceMapper.RequirePositiveInt(request.CreatedByUserId, nameof(request.CreatedByUserId))),
                context.CancellationToken).ConfigureAwait(false);

            return new ReplaceAssistantKnowledgeItemVersionReply { Version = AssistantConversationServiceMapper.ToProto(version) };
        }, _logger, nameof(ReplaceKnowledgeItemVersion));

    public override Task<ListAssistantKnowledgeVersionsReply> ListKnowledgeVersions(ListAssistantKnowledgeVersionsRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var items = await _assistantService.ListKnowledgeVersionsAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.KnowledgeItemGuid, nameof(request.KnowledgeItemGuid)),
                context.CancellationToken).ConfigureAwait(false);

            var reply = new ListAssistantKnowledgeVersionsReply();
            reply.Versions.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(ListKnowledgeVersions));
}
