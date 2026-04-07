// FILE: Concursus.API/Services/CoreService.Documents.cs
// TEMPORARY: App-only Graph browsing/upload/delete to unblock UI delivery.
// NOTE: This bypasses delegated/OBO and does NOT enforce per-user SharePoint permissions.
//       Before broad rollout of write actions, pair this with explicit CymBuild permission checks
//       or move the write path to delegated Graph / OBO.

using Concursus.API.Classes;
using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using Microsoft.Graph;
using Microsoft.Graph.Models;
using System.Data;
using System.Net;

namespace Concursus.API.Services;

[Authorize]
public partial class CoreService
{
    private Guid ParseGuidOrEmpty(string guidString)
    {
        if (Guid.TryParse(guidString, out var guid))
        {
            return guid;
        }

        return Guid.Empty;
    }

    public override async Task<DocumentsNavigationGetResponse> DocumentsNavigationGet(
        DocumentsNavigationGetRequest request,
        ServerCallContext context)
    {
        var response = new DocumentsNavigationGetResponse();

        try
        {
            if (request.UserId <= 0)
            {
                response.ErrorReturned = "UserId is required.";
                return response;
            }

            if (!Guid.TryParse(request.RecordGuid, out var recordGuid) || recordGuid == Guid.Empty)
            {
                response.ErrorReturned = "RecordGuid is required and must be a valid GUID.";
                return response;
            }

            if (request.EntityTypeId <= 0)
            {
                response.ErrorReturned = "EntityTypeId is required.";
                return response;
            }

            var connectionString = _config.GetConnectionString("ShoreDB");
            if (string.IsNullOrWhiteSpace(connectionString))
            {
                response.ErrorReturned = "ShoreDB is not configured.";
                return response;
            }

            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync(context.CancellationToken);

            const string sql = """
SELECT
    ProjectId,
    ProjectGuid,
    ProjectNumber,
    ProjectEntityTypeId,
    ProjectEntityTypeName,
    EntityTypeId,
    EntityTypeName,
    EntityTypeGuid,
    HasDocuments,
    NavigationGroup,
    NavigationSortOrder,
    NavigationKey,
    RecordId,
    RecordGuid,
    RecordNumber,
    RecordTitle,
    RecordSubtitle,
    RecordSortValue,
    RelatedAccountId,
    RelatedAssetId,
    AccountRole,
    SharepointStructureId,
    SharePointSiteID,
    SharepointSiteName,
    SharepointSiteIdentifier,
    SharepointSiteUrl,
    HasSharepointStructure,
    CanBrowseDocuments
FROM SSop.tvf_ProjectDocumentNavigation(@UserId, @EntityTypeId, @RecordGuid)
ORDER BY NavigationSortOrder, RecordSortValue, RecordTitle;
""";

            await using var command = new SqlCommand(sql, connection)
            {
                CommandType = CommandType.Text
            };

            command.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = request.UserId });
            command.Parameters.Add(new SqlParameter("@EntityTypeId", SqlDbType.Int) { Value = request.EntityTypeId });
            command.Parameters.Add(new SqlParameter("@RecordGuid", SqlDbType.UniqueIdentifier) { Value = recordGuid });

            await using var reader = await command.ExecuteReaderAsync(context.CancellationToken);

            while (await reader.ReadAsync(context.CancellationToken))
            {
                var item = new DocumentsNavigationItem
                {
                    ProjectId = reader.GetInt32(reader.GetOrdinal("ProjectId")),
                    ProjectGuid = reader.GetGuid(reader.GetOrdinal("ProjectGuid")).ToString(),
                    ProjectNumber = reader.GetInt32(reader.GetOrdinal("ProjectNumber")),
                    ProjectEntityTypeId = reader.GetInt32(reader.GetOrdinal("ProjectEntityTypeId")),
                    ProjectEntityTypeName = reader.GetString(reader.GetOrdinal("ProjectEntityTypeName")),

                    EntityTypeId = reader.GetInt32(reader.GetOrdinal("EntityTypeId")),
                    EntityTypeName = reader.GetString(reader.GetOrdinal("EntityTypeName")),
                    EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")).ToString(),
                    HasDocuments = reader.GetBoolean(reader.GetOrdinal("HasDocuments")),

                    NavigationGroup = reader.GetString(reader.GetOrdinal("NavigationGroup")),
                    NavigationSortOrder = reader.GetInt32(reader.GetOrdinal("NavigationSortOrder")),
                    NavigationKey = reader.GetString(reader.GetOrdinal("NavigationKey")),

                    RecordId = reader.GetInt32(reader.GetOrdinal("RecordId")),
                    RecordGuid = reader.GetGuid(reader.GetOrdinal("RecordGuid")).ToString(),
                    RecordNumber = reader.IsDBNull(reader.GetOrdinal("RecordNumber")) ? string.Empty : reader.GetString(reader.GetOrdinal("RecordNumber")),
                    RecordTitle = reader.IsDBNull(reader.GetOrdinal("RecordTitle")) ? string.Empty : reader.GetString(reader.GetOrdinal("RecordTitle")),
                    RecordSubtitle = reader.IsDBNull(reader.GetOrdinal("RecordSubtitle")) ? string.Empty : reader.GetString(reader.GetOrdinal("RecordSubtitle")),
                    RecordSortValue = reader.IsDBNull(reader.GetOrdinal("RecordSortValue")) ? string.Empty : reader.GetString(reader.GetOrdinal("RecordSortValue")),

                    AccountRole = reader.IsDBNull(reader.GetOrdinal("AccountRole")) ? string.Empty : reader.GetString(reader.GetOrdinal("AccountRole")),
                    SharepointSiteName = reader.IsDBNull(reader.GetOrdinal("SharepointSiteName")) ? string.Empty : reader.GetString(reader.GetOrdinal("SharepointSiteName")),
                    SharepointSiteIdentifier = reader.IsDBNull(reader.GetOrdinal("SharepointSiteIdentifier")) ? string.Empty : reader.GetString(reader.GetOrdinal("SharepointSiteIdentifier")),
                    SharepointSiteUrl = reader.IsDBNull(reader.GetOrdinal("SharepointSiteUrl")) ? string.Empty : reader.GetString(reader.GetOrdinal("SharepointSiteUrl")),
                    HasSharepointStructure = reader.GetBoolean(reader.GetOrdinal("HasSharepointStructure")),
                    CanBrowseDocuments = reader.GetBoolean(reader.GetOrdinal("CanBrowseDocuments"))
                };

                var relatedAccountOrdinal = reader.GetOrdinal("RelatedAccountId");
                if (!reader.IsDBNull(relatedAccountOrdinal))
                {
                    item.RelatedAccountId = reader.GetInt32(relatedAccountOrdinal);
                }

                var relatedAssetOrdinal = reader.GetOrdinal("RelatedAssetId");
                if (!reader.IsDBNull(relatedAssetOrdinal))
                {
                    item.RelatedAssetId = reader.GetInt32(relatedAssetOrdinal);
                }

                var sharepointStructureOrdinal = reader.GetOrdinal("SharepointStructureId");
                if (!reader.IsDBNull(sharepointStructureOrdinal))
                {
                    item.SharepointStructureId = reader.GetInt32(sharepointStructureOrdinal);
                }

                var sharepointSiteIdOrdinal = reader.GetOrdinal("SharePointSiteID");
                if (!reader.IsDBNull(sharepointSiteIdOrdinal))
                {
                    item.SharePointSiteId = reader.GetInt32(sharepointSiteIdOrdinal);
                }

                response.Items.Add(item);
            }
        }
        catch (Exception ex)
        {
            response.ErrorReturned = ex.Message;
        }

        return response;
    }
    public override async Task<DocumentsResolveResponse> DocumentsResolve(DocumentsResolveRequest request, ServerCallContext context)
    {
        var resp = new DocumentsResolveResponse();

        try
        {
            if (!Guid.TryParse(request.RecordGuid, out var recordGuid) || recordGuid == Guid.Empty)
            {
                resp.ErrorReturned = "RecordGuid is required.";
                return resp;
            }

            if (request.EntityTypeId <= 0)
            {
                resp.ErrorReturned = "EntityTypeId is required.";
                return resp;
            }

            Guid entityTypeGuid;

            await using (var cn = new SqlConnection(_config.GetConnectionString("ShoreDB")))
            {
                await cn.OpenAsync(context.CancellationToken);

                const string entityTypeSql = @"
SELECT TOP (1) et.Guid
FROM SCore.EntityTypes et
WHERE et.ID = @EntityTypeId
  AND et.RowStatus NOT IN (0,254);";

                await using var cmd = new SqlCommand(entityTypeSql, cn);
                cmd.Parameters.Add(new SqlParameter("@EntityTypeId", SqlDbType.Int) { Value = request.EntityTypeId });

                var scalar = await cmd.ExecuteScalarAsync(context.CancellationToken);
                if (scalar is null || scalar == DBNull.Value)
                {
                    resp.ErrorReturned = $"EntityTypeId {request.EntityTypeId} could not be resolved.";
                    return resp;
                }

                entityTypeGuid = (Guid)scalar;
            }

            var dataObject = await _serviceBase._entityFramework.DataObjectGet(
                recordGuid,
                Guid.Empty,
                entityTypeGuid,
                false);

            var sharePointUrl = dataObject?.SharePointUrl ?? request.SharePointUrlHint ?? string.Empty;
            if (string.IsNullOrWhiteSpace(sharePointUrl))
            {
                resp.ErrorReturned = "DataObject.SharePointUrl is empty; cannot resolve document location.";
                return resp;
            }

            var graph = GetAppOnlyGraphClient();
            var siteId = ResolveSiteIdFromEnvironment(_config);
            var (driveName, relativePath) = ParseDriveAndPathFromSharePointUrl(sharePointUrl);

            var drives = await graph.Sites[siteId].Drives.GetAsync(rc =>
            {
                rc.QueryParameters.Top = 999;
            }, context.CancellationToken);

            var drive = drives?.Value?.FirstOrDefault(d =>
                string.Equals(d.Name, driveName, StringComparison.OrdinalIgnoreCase));

            if (drive?.Id is null)
            {
                var available = string.Join(", ", drives?.Value?.Select(d => d.Name).Where(n => !string.IsNullOrWhiteSpace(n)) ?? Array.Empty<string>());
                resp.ErrorReturned = $"Drive/library '{driveName}' not found on site '{siteId}'. Available drives: {available}";
                return resp;
            }

            Microsoft.Graph.Models.DriveItem? folderItem;

            if (string.IsNullOrWhiteSpace(relativePath))
            {
                folderItem = await graph.Drives[drive.Id].Root.GetAsync(null, context.CancellationToken);
            }
            else
            {
                folderItem = await graph
                    .Drives[drive.Id]
                    .Root
                    .ItemWithPath(relativePath)
                    .GetAsync(null, context.CancellationToken);
            }

            if (folderItem?.Id is null)
            {
                resp.ErrorReturned = $"Folder not found at path '{relativePath}' in drive '{driveName}'.";
                return resp;
            }

            resp.Location = new DocumentsLocation
            {
                RecordGuid = request.RecordGuid ?? string.Empty,
                EntityQueryGuid = request.EntityQueryGuid ?? string.Empty,
                SiteId = siteId,
                DriveId = drive.Id,
                RootFolderId = folderItem.Id,
                RootFolderName = folderItem.Name ?? driveName ?? "Documents",
                SharePointWebUrl = folderItem.WebUrl ?? string.Empty,
                Capabilities = new DocumentCapabilities
                {
                    CanDownload = true,
                    CanUpload = true,
                    CanDelete = true,
                    CanCreateFolder = true
                }
            };
        }
        catch (Exception ex)
        {
            resp.ErrorReturned = ex.Message;
        }

        return resp;
    }

    public override async Task DocumentsDownloadFileStream(
    DocumentsDownloadFileStreamRequest request,
    IServerStreamWriter<DocumentsDownloadFileStreamResponse> responseStream,
    ServerCallContext context)
    {
        if (string.IsNullOrWhiteSpace(request.DriveId))
        {
            await responseStream.WriteAsync(new DocumentsDownloadFileStreamResponse
            {
                ErrorReturned = "DriveId is required."
            });
            return;
        }

        if (string.IsNullOrWhiteSpace(request.ItemId))
        {
            await responseStream.WriteAsync(new DocumentsDownloadFileStreamResponse
            {
                ErrorReturned = "ItemId is required."
            });
            return;
        }

        var chunkSize = request.ChunkSizeBytes <= 0
            ? 256 * 1024
            : Math.Min(request.ChunkSizeBytes, 1024 * 1024);

        try
        {
            var graph = GetAppOnlyGraphClient();

            var item = await graph
                .Drives[request.DriveId]
                .Items[request.ItemId]
                .GetAsync(cancellationToken: context.CancellationToken);

            if (item == null)
            {
                await responseStream.WriteAsync(new DocumentsDownloadFileStreamResponse
                {
                    ErrorReturned = "File not found."
                });
                return;
            }

            if (item.Folder != null)
            {
                await responseStream.WriteAsync(new DocumentsDownloadFileStreamResponse
                {
                    ErrorReturned = "Cannot download a folder."
                });
                return;
            }

            await using var stream = await graph
                .Drives[request.DriveId]
                .Items[request.ItemId]
                .Content
                .GetAsync(cancellationToken: context.CancellationToken);

            if (stream == null)
            {
                await responseStream.WriteAsync(new DocumentsDownloadFileStreamResponse
                {
                    ErrorReturned = "File stream returned null."
                });
                return;
            }

            var buffer = new byte[chunkSize];
            var isFirstChunk = true;

            while (true)
            {
                var bytesRead = await stream.ReadAsync(
                    buffer.AsMemory(0, buffer.Length),
                    context.CancellationToken);

                if (bytesRead <= 0)
                {
                    if (isFirstChunk)
                    {
                        await responseStream.WriteAsync(new DocumentsDownloadFileStreamResponse
                        {
                            FileName = item.Name ?? "download",
                            ContentType = item.File?.MimeType ?? "application/octet-stream",
                            Data = Google.Protobuf.ByteString.Empty
                        });
                    }

                    break;
                }

                var chunk = Google.Protobuf.ByteString.CopyFrom(buffer, 0, bytesRead);

                await responseStream.WriteAsync(new DocumentsDownloadFileStreamResponse
                {
                    FileName = isFirstChunk ? (item.Name ?? "download") : string.Empty,
                    ContentType = isFirstChunk ? (item.File?.MimeType ?? "application/octet-stream") : string.Empty,
                    Data = chunk
                });

                isFirstChunk = false;
            }
        }
        catch (Exception ex)
        {
            await responseStream.WriteAsync(new DocumentsDownloadFileStreamResponse
            {
                ErrorReturned = ex.Message
            });
        }
    }

    public override async Task<DocumentsDownloadFileResponse> DocumentsDownloadFile(
    DocumentsDownloadFileRequest request,
    ServerCallContext context)
    {
        var resp = new DocumentsDownloadFileResponse();

        try
        {
            if (string.IsNullOrWhiteSpace(request.DriveId))
            {
                resp.ErrorReturned = "DriveId is required.";
                return resp;
            }

            if (string.IsNullOrWhiteSpace(request.ItemId))
            {
                resp.ErrorReturned = "ItemId is required.";
                return resp;
            }

            var graph = GetAppOnlyGraphClient();

            // Get metadata first
            var item = await graph
                .Drives[request.DriveId]
                .Items[request.ItemId]
                .GetAsync(cancellationToken: context.CancellationToken);

            if (item == null)
            {
                resp.ErrorReturned = "File not found.";
                return resp;
            }

            if (item.Folder != null)
            {
                resp.ErrorReturned = "Cannot download a folder.";
                return resp;
            }

            // Download file stream
            await using var stream = await graph
                .Drives[request.DriveId]
                .Items[request.ItemId]
                .Content
                .GetAsync(cancellationToken: context.CancellationToken);

            if (stream == null)
            {
                resp.ErrorReturned = "File stream returned null.";
                return resp;
            }

            using var ms = new MemoryStream();
            await stream.CopyToAsync(ms, context.CancellationToken);

            resp.FileName = item.Name ?? "download";
            resp.ContentType = item.File?.MimeType ?? "application/octet-stream";
            resp.Data = Google.Protobuf.ByteString.CopyFrom(ms.ToArray());
        }
        catch (Exception ex)
        {
            resp.ErrorReturned = ex.Message;
        }

        return resp;
    }
    public override async Task<DocumentsListResponse> DocumentsList(DocumentsListRequest request, ServerCallContext context)
    {
        var resp = new DocumentsListResponse();

        try
        {
            if (string.IsNullOrWhiteSpace(request.DriveId))
            {
                resp.ErrorReturned = "DriveId is required.";
                return resp;
            }

            if (string.IsNullOrWhiteSpace(request.FolderId))
            {
                resp.ErrorReturned = "FolderId is required.";
                return resp;
            }

            var graph = GetAppOnlyGraphClient();
            var pageSize = request.PageSize <= 0 ? 100 : Math.Min(request.PageSize, 200);

            Microsoft.Graph.Models.DriveItemCollectionResponse? page;

            if (!string.IsNullOrWhiteSpace(request.PageToken))
            {
                var nextLink = request.PageToken;
                var nextPageBuilder =
                    new Microsoft.Graph.Drives.Item.Items.Item.Children.ChildrenRequestBuilder(nextLink, graph.RequestAdapter);

                page = await nextPageBuilder.GetAsync(null, context.CancellationToken);
            }
            else
            {
                page = await graph
                    .Drives[request.DriveId]
                    .Items[request.FolderId]
                    .Children
                    .GetAsync(rc =>
                    {
                        rc.QueryParameters.Top = pageSize;
                        rc.QueryParameters.Select = new[]
                        {
                            "id","name","size","file","folder","lastModifiedDateTime","createdDateTime","webUrl"
                        };
                    }, context.CancellationToken);
            }

            var items = page?.Value ?? new List<Microsoft.Graph.Models.DriveItem>();

            IEnumerable<Microsoft.Graph.Models.DriveItem> filtered = items;
            if (!string.IsNullOrWhiteSpace(request.SearchText))
            {
                var searchText = request.SearchText.Trim();
                filtered = filtered.Where(i => (i.Name ?? string.Empty).Contains(searchText, StringComparison.OrdinalIgnoreCase));
            }

            foreach (var item in filtered.OrderByDescending(i => i.Folder is not null).ThenBy(i => i.Name))
            {
                resp.Items.Add(MapDocumentsListItem(item));
            }

            resp.NextPageToken = page?.OdataNextLink ?? string.Empty;
        }
        catch (Exception ex)
        {
            resp.ErrorReturned = ex.Message;
        }

        return resp;
    }

    public override async Task<DocumentsCreateFolderResponse> DocumentsCreateFolder(DocumentsCreateFolderRequest request, ServerCallContext context)
    {
        var resp = new DocumentsCreateFolderResponse();

        try
        {
            if (string.IsNullOrWhiteSpace(request.DriveId))
            {
                resp.ErrorReturned = "DriveId is required.";
                return resp;
            }

            var folderName = SanitizeGraphName(request.FolderName, "Folder name is required.");
            var graph = GetAppOnlyGraphClient();

            var newFolder = new Microsoft.Graph.Models.DriveItem
            {
                Name = folderName,
                Folder = new Folder()
            };

            newFolder.AdditionalData = new Dictionary<string, object?>
            {
                ["@microsoft.graph.conflictBehavior"] = string.IsNullOrWhiteSpace(request.ConflictBehavior)
                    ? "rename"
                    : request.ConflictBehavior.Trim().ToLowerInvariant()
            };

            Microsoft.Graph.Models.DriveItem? created;

            if (string.IsNullOrWhiteSpace(request.ParentFolderId))
            {
                created = await graph
                    .Drives[request.DriveId]
                    .Items["root"]
                    .Children
                    .PostAsync(newFolder, cancellationToken: context.CancellationToken);
            }
            else
            {
                created = await graph
                    .Drives[request.DriveId]
                    .Items[request.ParentFolderId]
                    .Children
                    .PostAsync(newFolder, cancellationToken: context.CancellationToken);
            }

            if (created?.Id is null)
            {
                resp.ErrorReturned = "Graph did not return a created folder.";
                return resp;
            }

            resp.Folder = MapDocumentsListItem(created);
            resp.FolderId = created.Id;
            resp.FolderName = created.Name ?? folderName;
            resp.WebUrl = created.WebUrl ?? string.Empty;
        }
        catch (Exception ex)
        {
            resp.ErrorReturned = ex.Message;
        }

        return resp;
    }

    public override async Task<DocumentsUploadResponse> DocumentsUpload(DocumentsUploadRequest request, ServerCallContext context)
    {
        var resp = new DocumentsUploadResponse();

        try
        {
            if (string.IsNullOrWhiteSpace(request.DriveId))
            {
                resp.ErrorReturned = "DriveId is required.";
                return resp;
            }

            var fileName = SanitizeGraphName(request.FileName, "File name is required.");
            var bytes = request.Data?.Length > 0
                ? request.Data.ToByteArray()
                : request.Content?.Length > 0
                    ? request.Content.ToByteArray()
                    : Array.Empty<byte>();

            if (bytes.Length == 0)
            {
                resp.ErrorReturned = "Upload content is empty.";
                return resp;
            }

            var graph = GetAppOnlyGraphClient();

            await using var stream = new MemoryStream(bytes, writable: false);

            Microsoft.Graph.Models.DriveItem? uploaded;

            if (string.IsNullOrWhiteSpace(request.FolderId))
            {
                uploaded = await graph
                    .Drives[request.DriveId]
                    .Root
                    .ItemWithPath(fileName)
                    .Content
                    .PutAsync(stream, cancellationToken: context.CancellationToken);
            }
            else
            {
                uploaded = await graph
                    .Drives[request.DriveId]
                    .Items[request.FolderId]
                    .ItemWithPath(fileName)
                    .Content
                    .PutAsync(stream, cancellationToken: context.CancellationToken);
            }

            if (uploaded?.Id is null)
            {
                resp.ErrorReturned = "Graph did not return the uploaded item.";
                return resp;
            }

            resp.Item = MapDocumentsListItem(uploaded);
            resp.ItemId = uploaded.Id;
            resp.WebUrl = uploaded.WebUrl ?? string.Empty;
        }
        catch (Exception ex)
        {
            resp.ErrorReturned = ex.Message;
        }

        return resp;
    }

    public override async Task<DocumentsDeleteResponse> DocumentsDelete(DocumentsDeleteRequest request, ServerCallContext context)
    {
        var resp = new DocumentsDeleteResponse();

        try
        {
            if (string.IsNullOrWhiteSpace(request.DriveId))
            {
                resp.ErrorReturned = "DriveId is required.";
                return resp;
            }

            if (string.IsNullOrWhiteSpace(request.ItemId))
            {
                resp.ErrorReturned = "ItemId is required.";
                return resp;
            }

            var graph = GetAppOnlyGraphClient();

            await graph
                .Drives[request.DriveId]
                .Items[request.ItemId]
                .DeleteAsync(cancellationToken: context.CancellationToken);

            resp.Success = true;
        }
        catch (Exception ex)
        {
            resp.Success = false;
            resp.ErrorReturned = ex.Message;
        }

        return resp;
    }

    private GraphServiceClient GetAppOnlyGraphClient()
    {
        var sp = new Concursus.API.Components.SharePoint(_config, _sharepointService);
        return sp.GetGraphClient();
    }

    private static DocumentsListItem MapDocumentsListItem(Microsoft.Graph.Models.DriveItem item)
    {
        var isFolder = item.Folder is not null;

        return new DocumentsListItem
        {
            Id = item.Id ?? string.Empty,
            Name = item.Name ?? string.Empty,
            IsFolder = isFolder,
            HasChildren = (item.Folder?.ChildCount ?? 0) > 0,
            Size = isFolder ? 0 : (long)(item.Size ?? 0),
            CreatedUtc = item.CreatedDateTime.HasValue
                ? Timestamp.FromDateTimeOffset(item.CreatedDateTime.Value)
                : null,
            LastModifiedUtc = item.LastModifiedDateTime.HasValue
                ? Timestamp.FromDateTimeOffset(item.LastModifiedDateTime.Value)
                : null,
            MimeType = item.File?.MimeType ?? string.Empty,
            WebUrl = item.WebUrl ?? string.Empty,
            CanDownload = !isFolder,
            CanUpload = isFolder,
            CanDelete = true,
            CanCreateFolder = isFolder,
            Description = item.Description ?? string.Empty
        };
    }

    private static string SanitizeGraphName(string? rawValue, string emptyMessage)
    {
        var value = (rawValue ?? string.Empty).Trim();

        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException(emptyMessage);
        }

        var invalid = new[] { "\"", "*", ":", "<", ">", "?", "/", "\\", "|" };
        foreach (var token in invalid)
        {
            value = value.Replace(token, string.Empty, StringComparison.Ordinal);
        }

        value = value.Trim().TrimEnd('.');

        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException(emptyMessage);
        }

        return value;
    }

    private static (string driveName, string relativePath) ParseDriveAndPathFromSharePointUrl(string sharePointUrl)
    {
        if (string.IsNullOrWhiteSpace(sharePointUrl))
            throw new InvalidOperationException("SharePointUrl is empty.");

        if (!Uri.TryCreate(sharePointUrl, UriKind.Absolute, out var uri))
            throw new InvalidOperationException($"SharePointUrl is not a valid absolute URL: {sharePointUrl}");

        var segments = uri.AbsolutePath
            .Split('/', StringSplitOptions.RemoveEmptyEntries)
            .Select(s => WebUtility.UrlDecode(s))
            .ToList();

        if (segments.Count == 0)
            throw new InvalidOperationException($"SharePointUrl has no path segments: {sharePointUrl}");

        if (segments.Count >= 2 && segments[^2].Equals("Forms", StringComparison.OrdinalIgnoreCase))
        {
            segments.RemoveRange(segments.Count - 2, 2);
        }

        int libraryIndex;
        var first = segments[0];

        if (first.Equals("sites", StringComparison.OrdinalIgnoreCase) ||
            first.Equals("teams", StringComparison.OrdinalIgnoreCase))
        {
            if (segments.Count < 3)
                throw new InvalidOperationException($"SharePointUrl does not contain a library segment after /{first}/<name>/: {sharePointUrl}");

            libraryIndex = 2;
        }
        else
        {
            libraryIndex = 0;
        }

        var driveName = segments[libraryIndex];
        var relativeParts = segments.Skip(libraryIndex + 1).ToList();
        var relativePath = string.Join("/", relativeParts);

        return (driveName, relativePath);
    }

    private static string ResolveSiteIdFromEnvironment(IConfiguration config)
    {
        var appConfig = new AppConfiguration(config);

        switch ((appConfig.EnvironmentType ?? string.Empty).ToUpperInvariant())
        {
            case "DEV":
            case "TEST":
                return appConfig.DevSharepointIdentifier;

            default:
                return "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e";
        }
    }
}
