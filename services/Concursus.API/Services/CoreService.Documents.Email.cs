using Concursus.API.Components;
using Concursus.API.Core;
using Concursus.API.Services.Graph;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Graph.Me.Messages.Item.Attachments.CreateUploadSession;
using Microsoft.Graph.Models;
using Microsoft.Graph.Models.ODataErrors;
using System.Net.Http.Headers;

namespace Concursus.API.Services;

[Authorize]
public partial class CoreService
{
    private const int SmallAttachmentThresholdBytes = 3 * 1024 * 1024;
    private const int LargeAttachmentChunkBytes = 4 * 1024 * 1024;

    public override async Task<DocumentsCreateEmailDraftResponse> DocumentsCreateEmailDraft(
        DocumentsCreateEmailDraftRequest request,
        ServerCallContext context)
    {
        var response = new DocumentsCreateEmailDraftResponse();

        try
        {
            if (string.IsNullOrWhiteSpace(request.Subject))
            {
                response.ErrorReturned = "Subject is required.";
                return response;
            }

            if (request.Attachments == null || request.Attachments.Count == 0)
            {
                response.ErrorReturned = "At least one attachment is required.";
                return response;
            }

            var user = context.GetHttpContext()?.User;
            if (user?.Identity?.IsAuthenticated != true)
            {
                response.ErrorReturned = "Authenticated user context is unavailable.";
                return response;
            }

            var graph = await _delegatedGraphClientFactory.CreateAsync(
                user,
                context.CancellationToken);

            var draftMessage = new Message
            {
                Subject = request.Subject,
                Body = new ItemBody
                {
                    ContentType = request.IsHtmlBody ? BodyType.Html : BodyType.Text,
                    Content = request.Body ?? string.Empty
                },
                ToRecipients = BuildRecipients(request.ToRecipients),
                CcRecipients = BuildRecipients(request.CcRecipients),
                BccRecipients = BuildRecipients(request.BccRecipients)
            };

            var createdDraft = await graph.Me.Messages.PostAsync(
                draftMessage,
                cancellationToken: context.CancellationToken);

            if (createdDraft?.Id == null)
            {
                response.ErrorReturned = "Graph did not return a draft message.";
                return response;
            }

            var draftId = createdDraft.Id;
            var attachedCount = 0;

            using var sharePoint = new SharePoint(_config, _sharepointService);

            foreach (var attachmentRef in request.Attachments)
            {
                context.CancellationToken.ThrowIfCancellationRequested();

                if (string.IsNullOrWhiteSpace(attachmentRef.DriveId) ||
                    string.IsNullOrWhiteSpace(attachmentRef.ItemId))
                {
                    continue;
                }

                var fileResult = await sharePoint.GetFileContentStreamDelegatedAsync(
                    graph,
                    attachmentRef.DriveId,
                    attachmentRef.ItemId,
                    context.CancellationToken);

                await using var sourceStream = fileResult.Stream;
                await using var memory = new MemoryStream();

                await sourceStream.CopyToAsync(memory, context.CancellationToken);
                var bytes = memory.ToArray();

                var resolvedFileName = !string.IsNullOrWhiteSpace(attachmentRef.FileName)
                    ? attachmentRef.FileName
                    : fileResult.FileName ?? "attachment";

                var resolvedContentType = !string.IsNullOrWhiteSpace(fileResult.ContentType)
                    ? fileResult.ContentType
                    : "application/octet-stream";

                if (bytes.Length < SmallAttachmentThresholdBytes)
                {
                    var fileAttachment = new FileAttachment
                    {
                        OdataType = "#microsoft.graph.fileAttachment",
                        Name = resolvedFileName,
                        ContentType = resolvedContentType,
                        ContentBytes = bytes
                    };

                    await graph.Me.Messages[draftId].Attachments.PostAsync(
                        fileAttachment,
                        cancellationToken: context.CancellationToken);
                }
                else
                {
                    await UploadLargeMessageAttachmentAsync(
                        graph,
                        draftId,
                        resolvedFileName,
                        resolvedContentType,
                        bytes,
                        context.CancellationToken);
                }

                attachedCount++;
            }

            var refreshedDraft = await graph.Me.Messages[draftId].GetAsync(
                cancellationToken: context.CancellationToken);

            response.Success = true;
            response.DraftId = draftId;
            response.WebLink = refreshedDraft?.WebLink ?? string.Empty;
            response.AttachedCount = attachedCount;

            return response;
        }
        catch (ODataError ex)
        {
            response.ErrorReturned = ex.Error?.Message ?? "Graph draft creation failed.";
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "DocumentsCreateEmailDraft failed.");
            response.ErrorReturned = ex.Message;
            return response;
        }
    }

    private static List<Recipient> BuildRecipients(IEnumerable<string> emailAddresses)
    {
        var recipients = new List<Recipient>();

        if (emailAddresses == null)
        {
            return recipients;
        }

        foreach (var email in emailAddresses.Where(x => !string.IsNullOrWhiteSpace(x)))
        {
            recipients.Add(new Recipient
            {
                EmailAddress = new EmailAddress
                {
                    Address = email.Trim()
                }
            });
        }

        return recipients;
    }

    private async Task UploadLargeMessageAttachmentAsync(
        Microsoft.Graph.GraphServiceClient graph,
        string messageId,
        string fileName,
        string contentType,
        byte[] content,
        CancellationToken cancellationToken)
    {
        var requestBody = new CreateUploadSessionPostRequestBody
        {
            AttachmentItem = new AttachmentItem
            {
                AttachmentType = AttachmentType.File,
                Name = fileName,
                Size = content.LongLength,
                ContentType = contentType
            }
        };

        var uploadSession = await graph.Me.Messages[messageId]
            .Attachments
            .CreateUploadSession
            .PostAsync(requestBody, cancellationToken: cancellationToken);

        if (uploadSession?.UploadUrl == null)
        {
            throw new InvalidOperationException(
                $"Failed to create upload session for attachment '{fileName}'.");
        }

        using var httpClient = new HttpClient();

        long offset = 0;
        while (offset < content.LongLength)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var chunkLength = (int)Math.Min(
                LargeAttachmentChunkBytes,
                content.LongLength - offset);

            using var chunk = new ByteArrayContent(content, (int)offset, chunkLength);
            chunk.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
            chunk.Headers.ContentRange = new ContentRangeHeaderValue(
                offset,
                offset + chunkLength - 1,
                content.LongLength);

            using var putRequest = new HttpRequestMessage(HttpMethod.Put, uploadSession.UploadUrl)
            {
                Content = chunk
            };

            using var putResponse = await httpClient.SendAsync(
                putRequest,
                cancellationToken);

            if (!putResponse.IsSuccessStatusCode &&
                putResponse.StatusCode != System.Net.HttpStatusCode.Accepted &&
                putResponse.StatusCode != System.Net.HttpStatusCode.Created &&
                putResponse.StatusCode != System.Net.HttpStatusCode.OK)
            {
                var errorBody = await putResponse.Content.ReadAsStringAsync(cancellationToken);

                throw new InvalidOperationException(
                    $"Large attachment upload failed for '{fileName}'. " +
                    $"Status: {(int)putResponse.StatusCode}. Body: {errorBody}");
            }

            offset += chunkLength;
        }
    }
}