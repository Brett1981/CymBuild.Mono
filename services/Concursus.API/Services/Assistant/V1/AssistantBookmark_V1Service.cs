using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Concursus.API.Assistant.V1;
using Concursus.API.Services.Assistant.Contracts;
using Grpc.Core;
using Microsoft.Extensions.Logging;

namespace Concursus.API.Services.Assistant.V1;

public sealed class AssistantBookmark_V1Service
    : AssistantBookmarkService.AssistantBookmarkServiceBase
{
    private readonly IAssistantV1ApplicationService _assistantService;
    private readonly ILogger<AssistantBookmark_V1Service> _logger;

    public AssistantBookmark_V1Service(
        IAssistantV1ApplicationService assistantService,
        ILogger<AssistantBookmark_V1Service> logger)
    {
        _assistantService = assistantService ?? throw new ArgumentNullException(nameof(assistantService));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public override Task<CreateAssistantBookmarkReply> CreateBookmark(CreateAssistantBookmarkRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var bookmark = await _assistantService.CreateBookmarkAsync(
                new CreateAssistantBookmarkCommand(
                    UserId: AssistantConversationServiceMapper.RequirePositiveInt(request.UserId, nameof(request.UserId)),
                    ConversationGuid: AssistantConversationServiceMapper.ParseRequiredGuid(request.ConversationGuid, nameof(request.ConversationGuid)),
                    MessageGuid: AssistantConversationServiceMapper.ParseRequiredGuid(request.MessageGuid, nameof(request.MessageGuid)),
                    Title: AssistantConversationServiceMapper.RequireText(request.Title, nameof(request.Title), 250),
                    Notes: AssistantConversationServiceMapper.Unwrap(request.Notes),
                    TagsJson: AssistantConversationServiceMapper.Unwrap(request.TagsJson)),
                context.CancellationToken).ConfigureAwait(false);

            return new CreateAssistantBookmarkReply { Bookmark = AssistantConversationServiceMapper.ToProto(bookmark) };
        }, _logger, nameof(CreateBookmark));

    public override Task<ListAssistantBookmarksReply> ListBookmarks(ListAssistantBookmarksRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var items = await _assistantService.ListBookmarksAsync(
                AssistantConversationServiceMapper.RequirePositiveInt(request.UserId, nameof(request.UserId)),
                context.CancellationToken).ConfigureAwait(false);

            var reply = new ListAssistantBookmarksReply();
            reply.Bookmarks.AddRange(items.Select(AssistantConversationServiceMapper.ToProto));
            return reply;
        }, _logger, nameof(ListBookmarks));

    public override Task<DeleteAssistantBookmarkReply> DeleteBookmark(DeleteAssistantBookmarkRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var success = await _assistantService.DeleteBookmarkAsync(
                AssistantConversationServiceMapper.ParseRequiredGuid(request.BookmarkGuid, nameof(request.BookmarkGuid)),
                context.CancellationToken).ConfigureAwait(false);

            return new DeleteAssistantBookmarkReply { Success = success };
        }, _logger, nameof(DeleteBookmark));

    public override Task<UpdateAssistantBookmarkReply> UpdateBookmark(UpdateAssistantBookmarkRequest request, ServerCallContext context)
        => AssistantConversationServiceMapper.ExecuteAsync(async () =>
        {
            var bookmark = await _assistantService.UpdateBookmarkAsync(
                new UpdateAssistantBookmarkCommand(
                    BookmarkGuid: AssistantConversationServiceMapper.ParseRequiredGuid(request.BookmarkGuid, nameof(request.BookmarkGuid)),
                    Title: AssistantConversationServiceMapper.RequireText(request.Title, nameof(request.Title), 250),
                    Notes: AssistantConversationServiceMapper.Unwrap(request.Notes),
                    TagsJson: AssistantConversationServiceMapper.Unwrap(request.TagsJson)),
                context.CancellationToken).ConfigureAwait(false);

            return new UpdateAssistantBookmarkReply { Bookmark = AssistantConversationServiceMapper.ToProto(bookmark) };
        }, _logger, nameof(UpdateBookmark));
}
