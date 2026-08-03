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
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Graph;
using Microsoft.Graph.Models;
using System.Data;
using System.Net;
using System.Runtime.Caching;

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
    public override async Task<DocumentsResolveResponse> DocumentsResolve(
        DocumentsResolveRequest request,
        ServerCallContext context)
    {
        var response = new DocumentsResolveResponse();

        try
        {
            if (!Guid.TryParse(request.RecordGuid, out var recordGuid) ||
                recordGuid == Guid.Empty)
            {
                response.ErrorReturned = "RecordGuid is required.";
                return response;
            }

            if (request.EntityTypeId <= 0)
            {
                response.ErrorReturned = "EntityTypeId is required.";
                return response;
            }

            /*
             * SDI-139290
             *
             * A successfully resolved SharePoint location is effectively static.
             * Cache it by record and entity type so repeated tab opens avoid:
             *
             *   - resolving the EntityType GUID;
             *   - loading the complete DataObject;
             *   - resolving the SharePoint metadata/site;
             *   - enumerating Graph drives; and
             *   - resolving the Graph folder.
             *
             * A resync supplies SharePointUrlHint. That deliberately bypasses the
             * cache and refreshes it with the newly resolved location.
             *
             * SiteIdentifier is held inside the cached value rather than in the
             * key because the authoritative site is database-driven and is not
             * known until the first uncached resolve has completed.
             */
            var cacheKey = $"{recordGuid:N}|{request.EntityTypeId}";
            var bypassCache = !string.IsNullOrWhiteSpace(request.SharePointUrlHint);

            if (!bypassCache &&
                TryGetCachedDocumentsLocation(cacheKey, out var cachedLocation))
            {
                response.Location = BuildDocumentsLocation(
                    request,
                    cachedLocation);

                return response;
            }

            var connectionString = _config.GetConnectionString("ShoreDB");
            if (string.IsNullOrWhiteSpace(connectionString))
            {
                response.ErrorReturned = "ShoreDB is not configured.";
                return response;
            }

            Guid entityTypeGuid;

            await using (var connection = new SqlConnection(connectionString))
            {
                await connection.OpenAsync(context.CancellationToken);

                const string entityTypeSql = """
SELECT TOP (1)
       et.Guid
FROM SCore.EntityTypes AS et
WHERE et.ID = @EntityTypeId
  AND et.RowStatus <> 0
  AND et.RowStatus <> 254;
""";

                await using var command = new SqlCommand(entityTypeSql, connection)
                {
                    CommandType = CommandType.Text
                };

                command.Parameters.Add(
                    new SqlParameter("@EntityTypeId", SqlDbType.Int)
                    {
                        Value = request.EntityTypeId
                    });

                var scalar = await command.ExecuteScalarAsync(
                    context.CancellationToken);

                if (scalar is null || scalar == DBNull.Value)
                {
                    response.ErrorReturned =
                        $"EntityTypeId {request.EntityTypeId} could not be resolved.";

                    return response;
                }

                entityTypeGuid = (Guid)scalar;
            }

            var dataObject = await _serviceBase._entityFramework.DataObjectGet(
                recordGuid,
                Guid.Empty,
                entityTypeGuid,
                false);

            if (dataObject is null || dataObject.Guid == Guid.Empty)
            {
                response.ErrorReturned =
                    $"Record {recordGuid} could not be loaded.";

                return response;
            }

            /*
             * The resync operation supplies the latest URL as a hint. When present,
             * it must take priority over the currently persisted URL.
             */
            var sharePointUrl =
                !string.IsNullOrWhiteSpace(request.SharePointUrlHint)
                    ? request.SharePointUrlHint.Trim()
                    : (dataObject.SharePointUrl ?? string.Empty).Trim();

            if (string.IsNullOrWhiteSpace(sharePointUrl))
            {
                response.ErrorReturned =
                    "DataObject.SharePointUrl is empty; " +
                    "the document location cannot be resolved.";

                return response;
            }

            /*
             * Prefer the site identifier persisted for this record. When absent,
             * resolve it through the source-controlled SharePoint structure:
             *
             * Entity type / object ID
             *   -> SCore.tvf_GetSharePointDetailsForObject
             *   -> SCore.SharepointEntityStructure
             *   -> SCore.SharepointSites.SiteIdentifier
             *
             * This prevents Quotes and Enquiries being incorrectly resolved against
             * the ConcursusJobs site.
             */
            var siteId =
                (dataObject.SharePointSiteIdentifier ?? string.Empty).Trim();

            if (string.IsNullOrWhiteSpace(siteId))
            {
                var sharePointDetails = await _serviceBase
                    ._entityFramework
                    .GetSharePointDetailsForObject(dataObject);

                var matchingSiteIdentifiers = sharePointDetails
                    .Select(detail => detail.SiteIdentifier?.Trim())
                    .Where(identifier => !string.IsNullOrWhiteSpace(identifier))
                    .Cast<string>()
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList();

                if (matchingSiteIdentifiers.Count == 0)
                {
                    response.ErrorReturned =
                        $"No active SharePoint site mapping was found for " +
                        $"EntityTypeId {request.EntityTypeId}, " +
                        $"EntityTypeGuid {entityTypeGuid}, " +
                        $"RecordGuid {recordGuid}.";

                    return response;
                }

                if (matchingSiteIdentifiers.Count > 1)
                {
                    response.ErrorReturned =
                        $"Multiple active SharePoint sites were resolved for " +
                        $"EntityTypeId {request.EntityTypeId}: " +
                        $"{string.Join(", ", matchingSiteIdentifiers)}. " +
                        $"The SharePoint entity structure must resolve to one site.";

                    return response;
                }

                siteId = matchingSiteIdentifiers[0];
            }

            var graph = GetAppOnlyGraphClient();
            var (driveName, relativePath) =
                ParseDriveAndPathFromSharePointUrl(sharePointUrl);

            var drives = await graph
                .Sites[siteId]
                .Drives
                .GetAsync(
                    requestConfiguration =>
                    {
                        requestConfiguration.QueryParameters.Top = 999;
                    },
                    context.CancellationToken);

            var drive = drives?.Value?.FirstOrDefault(candidate =>
                string.Equals(
                    candidate.Name,
                    driveName,
                    StringComparison.OrdinalIgnoreCase));

            if (drive?.Id is null)
            {
                var availableDrives = string.Join(
                    ", ",
                    drives?.Value?
                        .Select(candidate => candidate.Name)
                        .Where(name => !string.IsNullOrWhiteSpace(name))
                    ?? Array.Empty<string>());

                response.ErrorReturned =
                    $"Drive/library '{driveName}' was not found on " +
                    $"SharePoint site '{siteId}'. " +
                    $"Available drives: {availableDrives}";

                return response;
            }

            Microsoft.Graph.Models.DriveItem? folderItem;

            if (string.IsNullOrWhiteSpace(relativePath))
            {
                folderItem = await graph
                    .Drives[drive.Id]
                    .Root
                    .GetAsync(
                        cancellationToken: context.CancellationToken);
            }
            else
            {
                folderItem = await graph
                    .Drives[drive.Id]
                    .Root
                    .ItemWithPath(relativePath)
                    .GetAsync(
                        cancellationToken: context.CancellationToken);
            }

            if (folderItem?.Id is null)
            {
                response.ErrorReturned =
                    $"Folder '{relativePath}' was not found in " +
                    $"drive '{driveName}' on site '{siteId}'.";

                return response;
            }

            var resolvedLocation = new ResolvedDocumentsLocation(
                siteId,
                drive.Id,
                folderItem.Id,
                folderItem.Name ?? driveName,
                folderItem.WebUrl ?? string.Empty);

            StoreCachedDocumentsLocation(
                cacheKey,
                resolvedLocation);

            response.Location = BuildDocumentsLocation(
                request,
                resolvedLocation);

            // CymBuild's custom logger accepts one completed string rather than
            // Microsoft.Extensions.Logging structured-message arguments.
            _serviceBase.logger.LogInformation(
                $"DocumentsResolve succeeded. " +
                $"RecordGuid={recordGuid}, " +
                $"EntityTypeId={request.EntityTypeId}, " +
                $"SiteIdentifier={siteId}, " +
                $"Drive={driveName}, " +
                $"RelativePath={relativePath}.");
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(
                ex,
                "DocumentsResolve failed.");

            response.ErrorReturned = ex.Message;
        }

        return response;
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

    // SDI-139290: short-TTL cache of resolved SharePoint document locations.
    // The CoreService is scoped, while IMemoryCache is shared by dependency injection, so
    // entries survive across repeated tab opens. Only immutable primitive values are cached;
    // a fresh protobuf DocumentsLocation is built for each response.
    private sealed record ResolvedDocumentsLocation(
        string SiteId,
        string DriveId,
        string RootFolderId,
        string RootFolderName,
        string SharePointWebUrl);

    private const string DocumentsLocationCacheKeyPrefix = "docs-location:";

    private static readonly TimeSpan DocumentsLocationCacheTtl =
        TimeSpan.FromMinutes(15);

    private bool TryGetCachedDocumentsLocation(
        string cacheKey,
        out ResolvedDocumentsLocation location)
    {
        if (_memoryCache.TryGetValue(
                DocumentsLocationCacheKeyPrefix + cacheKey,
                out ResolvedDocumentsLocation? cached) &&
            cached is not null)
        {
            location = cached;
            return true;
        }

        location = default!;
        return false;
    }

    private void StoreCachedDocumentsLocation(
        string cacheKey,
        ResolvedDocumentsLocation location)
    {
        _memoryCache.Set(
            DocumentsLocationCacheKeyPrefix + cacheKey,
            location,
            new MemoryCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = DocumentsLocationCacheTtl
            });
    }

    private static DocumentsLocation BuildDocumentsLocation(
        DocumentsResolveRequest request,
        ResolvedDocumentsLocation resolved)
    {
        return new DocumentsLocation
        {
            RecordGuid = request.RecordGuid ?? string.Empty,
            EntityQueryGuid = request.EntityQueryGuid ?? string.Empty,
            SiteId = resolved.SiteId,
            DriveId = resolved.DriveId,
            RootFolderId = resolved.RootFolderId,
            RootFolderName = resolved.RootFolderName,
            SharePointWebUrl = resolved.SharePointWebUrl,
            Capabilities = new DocumentCapabilities
            {
                CanDownload = true,
                CanUpload = true,
                CanDelete = true,
                CanCreateFolder = true
            }
        };
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

    private static (string driveName, string relativePath)
        ParseDriveAndPathFromSharePointUrl(string sharePointUrl)
    {
        if (string.IsNullOrWhiteSpace(sharePointUrl))
        {
            throw new InvalidOperationException("SharePointUrl is empty.");
        }

        if (!Uri.TryCreate(sharePointUrl, UriKind.Absolute, out var uri))
        {
            throw new InvalidOperationException(
                $"SharePointUrl is not a valid absolute URL: {sharePointUrl}");
        }

        /*
         * Modern SharePoint library links commonly use:
         *
         * /Forms/AllItems.aspx?id=<server-relative-folder-path>
         *
         * RootFolder is retained as a fallback for older SharePoint links.
         */
        var effectivePath =
            GetSharePointQueryParameter(uri, "id")
            ?? GetSharePointQueryParameter(uri, "RootFolder")
            ?? uri.AbsolutePath;

        var segments = effectivePath
            .Split('/', StringSplitOptions.RemoveEmptyEntries)
            .Select(WebUtility.UrlDecode)
            .Where(segment => !string.IsNullOrWhiteSpace(segment))
            .ToList();

        if (segments.Count == 0)
        {
            throw new InvalidOperationException(
                $"SharePointUrl has no usable path segments: {sharePointUrl}");
        }

        /*
         * Remove Forms/AllItems.aspx when no query-string folder path was
         * available and the absolute URL path is being used.
         */
        if (segments.Count >= 2 &&
            segments[^2].Equals(
                "Forms",
                StringComparison.OrdinalIgnoreCase))
        {
            segments.RemoveRange(segments.Count - 2, 2);
        }

        int libraryIndex;

        if (segments[0].Equals(
                "sites",
                StringComparison.OrdinalIgnoreCase) ||
            segments[0].Equals(
                "teams",
                StringComparison.OrdinalIgnoreCase))
        {
            if (segments.Count < 3)
            {
                throw new InvalidOperationException(
                    $"SharePointUrl does not contain a library after " +
                    $"/{segments[0]}/<site-name>/: {sharePointUrl}");
            }

            libraryIndex = 2;
        }
        else
        {
            libraryIndex = 0;
        }

        var driveName = segments[libraryIndex];
        var relativePath = string.Join(
            "/",
            segments.Skip(libraryIndex + 1));

        return (driveName, relativePath);
    }

    private static string? GetSharePointQueryParameter(
        Uri uri,
        string parameterName)
    {
        var query = uri.Query;

        if (string.IsNullOrWhiteSpace(query))
        {
            return null;
        }

        foreach (var pair in query
                     .TrimStart('?')
                     .Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var separatorIndex = pair.IndexOf('=');

            var rawName = separatorIndex >= 0
                ? pair[..separatorIndex]
                : pair;

            var rawValue = separatorIndex >= 0
                ? pair[(separatorIndex + 1)..]
                : string.Empty;

            var decodedName = WebUtility.UrlDecode(rawName);

            if (!string.Equals(
                    decodedName,
                    parameterName,
                    StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var decodedValue = WebUtility.UrlDecode(rawValue);

            return string.IsNullOrWhiteSpace(decodedValue)
                ? null
                : decodedValue;
        }

        return null;
    }
}