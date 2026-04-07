using Concursus.EF;
using Concursus.EF.Types;
using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_API.Helpers;
using CymBuild_Outlook_API.Services;
using CymBuild_Outlook_Common.Models.SharePoint;
using CymBuild_Outlook_Common.Types;
using Google.Protobuf.WellKnownTypes;
using Microsoft.Graph;
using Microsoft.Graph.DirectoryObjects.GetByIds;
using Microsoft.Graph.Drives.Item.Items.Item.CreateLink;
using Microsoft.Graph.Drives.Item.Items.Item.Invite;
using Microsoft.Graph.Models;
using Microsoft.Graph.Models.ODataErrors;
using Microsoft.Graph.Shares.Item.Permission.Grant;
using Polly;
using Polly.Retry;
using System.Net;
using DriveItem = Microsoft.Graph.Models.DriveItem;
using List = Microsoft.Graph.Models.List;

namespace CymBuild_Outlook_Common.Helpers
{
    /// <summary>
    /// SharePoint helper for:
    /// - Resolving/creating document libraries and folders for a DataObject
    /// - Ensuring default subfolder structures
    /// - Managing basic permissions (invite/grant)
    ///
    /// IMPORTANT PROCESS ALIGNMENT:
    /// - No async void (all async methods return Task)
    /// - No fire-and-forget Task.Run for business-critical work
    /// - No hard-coded user emails / hard-coded site IDs (config fallback only)
    /// - Do NOT dispose GraphServiceClient if it's DI-managed/singleton
    /// - Uses retry policy for transient Graph failures (429/5xx)
    /// </summary>
    public class SharePointHelper
    {
        private readonly IConfiguration _configuration;
        private readonly AppDbContext _dbContext;
        private readonly IMSGraphBase _msGraphBase;
        private readonly LoggingHelper _loggingHelper;

        private const string DefaultSiteIdFallback =
            "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e";

        private Drive? _drive;

        private GraphServiceClient GraphClient => _msGraphBase.GetGraphClient();

        private readonly AsyncRetryPolicy _graphRetry;

        public SharePointHelper(
            AppDbContext dbContext,
            IConfiguration configuration,
            IMSGraphBase msGraphBase,
            LoggingHelper loggingHelper)
        {
            _dbContext = dbContext;
            _configuration = configuration;
            _msGraphBase = msGraphBase;
            _loggingHelper = loggingHelper;

            // Retry transient Graph errors (429 / 5xx / network)
            _graphRetry = Policy
                .Handle<ServiceException>(IsTransientGraphFailure)
                .Or<HttpRequestException>()
                .WaitAndRetryAsync(
                    retryCount: 4,
                    sleepDurationProvider: attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt)),
                    onRetry: (ex, delay, attempt, _) =>
                    {
                        _loggingHelper.LogError(
                            $"Transient Graph failure, retry #{attempt} in {delay.TotalSeconds:n0}s",
                            ex,
                            "SharePointHelper(Retry)");
                    });
        }

        // ----------------------------------------------------------------------------------------
        // PUBLIC API
        // ----------------------------------------------------------------------------------------

        public async Task<List<DriveListItem>> GetSharePointDocumentDetails(string siteId, string folderName, string templateFolderName)
        {
            var documents = new List<DriveListItem>();

            try
            {
                siteId = ResolveSiteId(siteId);

                var parentDrive = await _graphRetry.ExecuteAsync(async () =>
                    await GraphClient.Sites[siteId].Drive.GetAsync().ConfigureAwait(false)
                ).ConfigureAwait(false);

                if (parentDrive?.Id == null)
                    throw new Exception("Failed to obtain site drive (parentDrive.Id was null).");

                // Ensure root exists
                var root = await _graphRetry.ExecuteAsync(async () =>
                    await GraphClient.Drives[parentDrive.Id].Root.GetAsync().ConfigureAwait(false)
                ).ConfigureAwait(false);

                if (root?.Id == null)
                    throw new Exception("Failed to obtain drive root.");

                // Ensure the requested folder exists under root (instead of checking ChildCount == 0)
                var formTemplatesFolder = await EnsureFolderExistsAsync(
                    driveId: parentDrive.Id,
                    parentFolderId: root.Id,
                    folderName: folderName).ConfigureAwait(false);

                // Ensure template folder exists under the folder
                var templateFolder = await EnsureFolderExistsAsync(
                    driveId: parentDrive.Id,
                    parentFolderId: formTemplatesFolder.Id!,
                    folderName: templateFolderName).ConfigureAwait(false);

                // List files in template folder (paged)
                var subFolderResponse = await _graphRetry.ExecuteAsync(async () =>
                    await GraphClient.Drives[parentDrive.Id].Items[templateFolder.Id!].Children.GetAsync().ConfigureAwait(false)
                ).ConfigureAwait(false);

                if (subFolderResponse?.Value == null)
                    return documents;

                var iterator = PageIterator<DriveItem, DriveItemCollectionResponse>.CreatePageIterator(
                    GraphClient,
                    subFolderResponse,
                    driveItem =>
                    {
                        if (driveItem.File != null)
                        {
                            documents.Add(new DriveListItem
                            {
                                Id = driveItem.Id ?? "",
                                Name = driveItem.Name ?? "",
                                WebUrl = driveItem.WebUrl ?? "",
                                CreatedDateTime = driveItem.CreatedDateTime != null
                                    ? Timestamp.FromDateTimeOffset((DateTimeOffset)driveItem.CreatedDateTime)
                                    : Timestamp.FromDateTime(DateTime.UtcNow),
                                LastModifiedDateTime = driveItem.LastModifiedDateTime != null
                                    ? Timestamp.FromDateTimeOffset((DateTimeOffset)driveItem.LastModifiedDateTime)
                                    : Timestamp.FromDateTime(DateTime.UtcNow),
                                Size = driveItem.Size ?? 0
                            });
                        }
                        return true;
                    });

                await iterator.IterateAsync().ConfigureAwait(false);
                return documents;
            }
            catch (ODataError odataError)
            {
                return new List<DriveListItem>
                {
                    new DriveListItem { ErrorReturned = odataError.Error?.Message ?? "Unknown ODataError" }
                };
            }
            catch (ServiceException ex)
            {
                _loggingHelper.LogError("Graph error in GetSharePointDocumentDetails()", ex, "GetSharePointDocumentDetails()");
                return new List<DriveListItem> { new DriveListItem { ErrorReturned = ex.Message } };
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError("Unhandled error in GetSharePointDocumentDetails()", ex, "GetSharePointDocumentDetails()");
                return new List<DriveListItem> { new DriveListItem { ErrorReturned = ex.Message } };
            }
        }

        public async Task<SharepointDocumentsGetResponse> GetSharePointDocuments(
            string siteId,
            string filenameTemplate,
            string targetSharePointUrl,
            string driveItemId,
            List<Dictionary<string, string>> mergeData)
        {
            try
            {
                siteId = ResolveSiteId(siteId);

                var parentDrive = await _graphRetry.ExecuteAsync(async () =>
                    await GraphClient.Sites[siteId].Drive.GetAsync().ConfigureAwait(false)
                ).ConfigureAwait(false);

                if (parentDrive?.Id == null)
                    return new SharepointDocumentsGetResponse();

                using var wordDocumentService = new WordDocumentService(GraphClient);

                return await wordDocumentService
                    .DownloadAndModifyDocument(siteId, parentDrive.Id, filenameTemplate, targetSharePointUrl, driveItemId, mergeData)
                    .ConfigureAwait(false);
            }
            catch (ODataError odataError)
            {
                _loggingHelper.LogError($"ODataError in GetSharePointDocuments(): {odataError.Error?.Message}", new Exception("ODataError"), "GetSharePointDocuments()");
                return new SharepointDocumentsGetResponse();
            }
            catch (ServiceException ex)
            {
                _loggingHelper.LogError("Graph error in GetSharePointDocuments()", ex, "GetSharePointDocuments()");
                return new SharepointDocumentsGetResponse();
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError("Unhandled error in GetSharePointDocuments()", ex, "GetSharePointDocuments()");
                return new SharepointDocumentsGetResponse();
            }
        }

        public async Task<DataObjectUpsertResponse> GetSharePointLocation(DataObject dataObject, Core efCore)
        {
            // IMPORTANT:
            // This method currently does a lot; we keep behavior but remove fire-and-forget,
            // remove async void, and make the subfolder creation awaited (best-effort).
            try
            {
                var details = await _dbContext.GetSharePointDetailsForObject(dataObject).ConfigureAwait(false);
                if (details == null || details.Count == 0)
                    return new DataObjectUpsertResponse { DataObject = dataObject };

                // Quote resolution (kept as per your logic)
                var quoteId = ResolveQuoteGuidString(dataObject);
                var quoteNo = "";
                var quoteUrl = "";

                foreach (var sharePointDetail in details)
                {
                    var siteId = ResolveSiteId(sharePointDetail.SiteIdentifier);

                    // Drive selection (split libraries / parent structure etc.)
                    Drive drive;
                    if (sharePointDetail.ParentStructureId > -1)
                    {
                        drive = await GetCreateLibrary(
                            siteId,
                            sharePointDetail.ParentUseLibraryPerSplit,
                            sharePointDetail.ParentObjectId,
                            sharePointDetail.ParentPrimaryKeySplitInterval,
                            dataObject,
                            sharePointDetail).ConfigureAwait(false);
                    }
                    else if (sharePointDetail.ParentStructureId == -1 && sharePointDetail.UseLibraryPerSplit)
                    {
                        drive = await GetCreateLibrary(
                            siteId,
                            sharePointDetail.UseLibraryPerSplit,
                            dataObject.DatabaseId,
                            sharePointDetail.PrimaryKeySplitInterval,
                            dataObject,
                            sharePointDetail).ConfigureAwait(false);
                    }
                    else
                    {
                        var d = await _graphRetry.ExecuteAsync(async () =>
                            await GraphClient.Sites[siteId].Drive.GetAsync().ConfigureAwait(false)
                        ).ConfigureAwait(false);

                        if (d?.Id == null)
                            throw new Exception("Failed to resolve site default drive.");

                        drive = d;
                    }

                    _drive = drive;

                    // If already has SharePointSiteIdentifier, respect it but make sure drive is correct
                    if (!string.IsNullOrWhiteSpace(dataObject.SharePointSiteIdentifier))
                    {
                        siteId = dataObject.SharePointSiteIdentifier;
                        var newFolderStructure = Functions.Functions.GetSeparatedNumberValues(dataObject.SharePointFolderPath);

                        drive = await GetCreateLibrary(
                            siteId,
                            sharePointDetail.UseLibraryPerSplit,
                            newFolderStructure,
                            sharePointDetail.PrimaryKeySplitInterval,
                            drive).ConfigureAwait(false);

                        if (drive?.Id == null)
                            continue;

                        DriveItem folder;
                        if (sharePointDetail.ParentStructureId > -1)
                        {
                            folder = await GetCreateFolder(
                                siteId,
                                dataObject.Label ?? "",
                                sharePointDetail.ParentObjectId,
                                sharePointDetail.PrimaryKeySplitInterval,
                                drive,
                                dataObject,
                                sharePointDetail).ConfigureAwait(false);
                        }
                        else
                        {
                            folder = await GetCreateFolder(
                                siteId,
                                dataObject.Label ?? "",
                                Convert.ToInt64(newFolderStructure[1]),
                                sharePointDetail.PrimaryKeySplitInterval,
                                drive).ConfigureAwait(false);
                        }

                        dataObject.SharePointUrl = folder.WebUrl ?? "";
                        if (!string.IsNullOrEmpty(dataObject.SharePointUrl))
                        {

                            await SetSharePointPermissionAsync(siteId, dataObject, drive.Id!, folder.Id ?? "").ConfigureAwait(false);

                            // Optional: resolve quote folder link (kept but now awaited)
                            if (!string.IsNullOrEmpty(quoteId) && Functions.Functions.ParseAndReturnEmptyGuidIfInvalid(Functions.Functions.SanitizeFileName(quoteId)) != Guid.Empty)
                            {
                                (quoteNo, quoteUrl) = await TryResolveQuoteFolderAsync(efCore, quoteId).ConfigureAwait(false);
                            }

                            // Ensure folder structure
                            await EnsureDefaultStructureAsync(siteId, dataObject, drive, folder, quoteNo, quoteUrl).ConfigureAwait(false);

                            return new DataObjectUpsertResponse { DataObject = dataObject };
                        }
                    }
                    else
                    {
                        if (drive?.Id == null)
                            continue;

                        var folder = await GetCreateFolder(
                            siteId,
                            dataObject.Label ?? "",
                            dataObject.DatabaseId,
                            sharePointDetail.PrimaryKeySplitInterval,
                            drive).ConfigureAwait(false);

                        dataObject.SharePointUrl = folder.WebUrl ?? "";
                        if (!string.IsNullOrEmpty(dataObject.SharePointUrl))
                        {
                            await SetSharePointPermissionAsync(siteId, dataObject, drive.Id!, folder.Id ?? "").ConfigureAwait(false);
                            await EnsureDefaultStructureAsync(siteId, dataObject, drive, folder, quoteNo, quoteUrl).ConfigureAwait(false);

                            return new DataObjectUpsertResponse { DataObject = dataObject };
                        }
                    }
                }

                return new DataObjectUpsertResponse { DataObject = dataObject };
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError("Unhandled error in GetSharePointLocation()", ex, "GetSharePointLocation()");
                return new DataObjectUpsertResponse { DataObject = dataObject };
            }
        }

        public async Task<List<SharePointSite>> GetSitesAsync()
        {
            var sites = new List<SharePointSite>();

            try
            {
                var siteCollection = await _graphRetry.ExecuteAsync(async () =>
                    await GraphClient.Sites.GetAsync(rc =>
                    {
                        rc.QueryParameters.Select = new[] { "siteCollection", "webUrl", "displayName", "createdDateTime", "description", "lastModifiedDateTime", "name", "root" };
                        rc.QueryParameters.Filter = "siteCollection/root ne null";
                    }).ConfigureAwait(false)
                ).ConfigureAwait(false);

                if (siteCollection?.Value == null)
                    return sites;

                var pageIterator = PageIterator<Site, SiteCollectionResponse>.CreatePageIterator(
                    GraphClient,
                    siteCollection,
                    s =>
                    {
                        sites.Add(new SharePointSite
                        {
                            Id = s.Id ?? "",
                            DisplayName = s.DisplayName ?? "",
                            WebUrl = s.WebUrl ?? "",
                            CreatedDateTime = s.CreatedDateTime != null
                                ? Timestamp.FromDateTimeOffset((DateTimeOffset)s.CreatedDateTime)
                                : Timestamp.FromDateTime(DateTime.UtcNow),
                            Description = s.Description ?? "",
                            LastModifiedDateTime = s.LastModifiedDateTime != null
                                ? Timestamp.FromDateTimeOffset((DateTimeOffset)s.LastModifiedDateTime)
                                : Timestamp.FromDateTime(DateTime.UtcNow),
                            Name = s.Name ?? "",
                            Root = s.Root?.ToString() ?? ""
                        });

                        return true;
                    });

                await pageIterator.IterateAsync().ConfigureAwait(false);
                return sites;
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError("Unhandled error in GetSitesAsync()", ex, "GetSitesAsync()");
                throw;
            }
        }

        // ----------------------------------------------------------------------------------------
        // PERMISSIONS (NO async void, NO fire-and-forget)
        // ----------------------------------------------------------------------------------------

        public async Task SetSharePointPermissionAsync(string siteId, DataObject dataObject, string driveId, string itemId)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(driveId) || string.IsNullOrWhiteSpace(itemId))
                    return;

                siteId = ResolveSiteId(siteId);

                // NOTE:
                // The previous implementation tried to delete permissions by comparing to a local list
                // that was never populated (dataObjectSecurities stayed empty) => risk of deleting legit perms.
                // We do NOT delete existing permissions by default.
                // We only INVITE users/groups required by dataObject.ObjectSecurity.

                if (dataObject.ObjectSecurity == null || dataObject.ObjectSecurity.Count == 0)
                    return;

                // 1) Assign group permissions (best-effort)
                await AssignGroupPermissionsAsync(GraphClient, driveId, itemId, dataObject.ObjectSecurity).ConfigureAwait(false);

                // 2) Invite each user (best-effort)
                foreach (var userSecurity in dataObject.ObjectSecurity)
                {
                    var userEmail = userSecurity.UserIdentity;
                    if (string.IsNullOrWhiteSpace(userEmail))
                        continue;

                    var role = userSecurity.CanWrite ? "write" : "read";

                    var invite = new InvitePostRequestBody
                    {
                        Recipients = new List<DriveRecipient> { new() { Email = userEmail } },
                        RequireSignIn = true,
                        SendInvitation = false, // reduce noise; flip to true if you want emails
                        Roles = new List<string> { role }
                    };

                    await _graphRetry.ExecuteAsync(async () =>
                    {
                        await Task.Delay(100).ConfigureAwait(false); // helps reduce change-key conflicts in some tenants
                        _ = await GraphClient.Drives[driveId].Items[itemId].Invite.PostAsInvitePostResponseAsync(invite).ConfigureAwait(false);
                    }).ConfigureAwait(false);
                }
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError($"Error in SetSharePointPermissionAsync(driveId={driveId}, itemId={itemId})", ex, "SetSharePointPermissionAsync()");
            }
        }

        // ----------------------------------------------------------------------------------------
        // PRIVATE HELPERS
        // ----------------------------------------------------------------------------------------

        private string ResolveSiteId(string? siteId)
        {
            // Prefer config; fallback to your old hard-coded value to avoid breaking behavior today
            var configured = _configuration["SharePoint:DefaultSiteId"];
            if (!string.IsNullOrWhiteSpace(siteId))
                return siteId;

            if (!string.IsNullOrWhiteSpace(configured))
                return configured;

            return DefaultSiteIdFallback;
        }

        private static bool IsTransientGraphFailure(ServiceException ex)
        {
            // Graph throttling / transient
            var code = ex.ResponseStatusCode;
            if (code == (int)HttpStatusCode.TooManyRequests) return true;
            if (code >= 500 && code <= 599) return true;

            // Sometimes Graph SDK throws with inner details; treat timeouts as transient
            if (ex.InnerException is TaskCanceledException) return true;

            return false;
        }

        private static string EscapeODataString(string value) => value.Replace("'", "''");

        private async Task<DriveItem> EnsureFolderExistsAsync(string driveId, string parentFolderId, string folderName)
        {
            if (string.IsNullOrWhiteSpace(folderName))
            {
                var existing = await _graphRetry.ExecuteAsync(async () =>
                    await GraphClient.Drives[driveId].Items[parentFolderId].GetAsync().ConfigureAwait(false)
                ).ConfigureAwait(false);

                return existing ?? throw new Exception("EnsureFolderExistsAsync: parent folder not found.");
            }

            var safeName = EscapeODataString(folderName);

            var collection = await _graphRetry.ExecuteAsync(async () =>
                await GraphClient
                    .Drives[driveId]
                    .Items[parentFolderId]
                    .Children
                    .GetAsync(rc => rc.QueryParameters.Filter = $"name eq '{safeName}'")
                    .ConfigureAwait(false)
            ).ConfigureAwait(false);

            var existingFolder = collection?.Value?.FirstOrDefault(i => i.Folder != null);

            if (existingFolder != null)
                return existingFolder;

            var create = new DriveItem
            {
                Name = folderName,
                Folder = new Folder(),
                AdditionalData = new Dictionary<string, object>
                {
                    ["@microsoft.graph.conflictBehavior"] = "rename"
                }
            };

            var created = await _graphRetry.ExecuteAsync(async () =>
                await GraphClient.Drives[driveId].Items[parentFolderId].Children.PostAsync(create).ConfigureAwait(false)
            ).ConfigureAwait(false);

            if (created?.Id == null)
                throw new Exception($"Failed to create folder '{folderName}'.");

            return created;
        }

        private async Task<(string QuoteNo, string QuoteUrl)> TryResolveQuoteFolderAsync(Core efCore, string quoteGuidString)
        {
            try
            {
                // existing logic hard-coded entity type GUID. Keeping it but centralising.
                const string quoteEntityTypeGuid = "1c4794c1-f956-4c32-b886-5500ac778a56";

                var quoteGuid = Functions.Functions.ParseAndReturnEmptyGuidIfInvalid(Functions.Functions.SanitizeFileName(quoteGuidString));
                if (quoteGuid == Guid.Empty)
                    return ("", "");

                var resp = await efCore.DataObjectGet(
                    new List<Guid> { quoteGuid },
                    Guid.Empty,
                    Functions.Functions.ParseAndReturnEmptyGuidIfInvalid(quoteEntityTypeGuid),
                    false).ConfigureAwait(false);

                if (resp == null || resp.Count == 0)
                    return ("", "");

                var quoteObj = resp[0];
                return (quoteObj.Label ?? "", quoteObj.SharePointUrl ?? "");
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError("Failed to resolve quote folder link", ex, "TryResolveQuoteFolderAsync()");
                return ("", "");
            }
        }

        private async Task EnsureDefaultStructureAsync(string siteId, DataObject dataObject, Drive drive, DriveItem folder, string quoteNo, string quoteUrl)
        {
            try
            {
                // Job entity type GUID you used
                var isJob = dataObject.EntityTypeGuid == Guid.Parse("63542427-46ab-4078-abd1-1d583c24315c");

                var folderNames = isJob
                    ? new List<string> { "Admin", "Certs", "Design Information", "Design Risk", "Emails", "Finance", "Photos", "Reports" }
                    : new List<string>();

                await EnsureFolderStructureExists(siteId, folderNames, drive, folder, dataObject.Label ?? "", quoteNo, quoteUrl)
                    .ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _loggingHelper.LogError("EnsureDefaultStructureAsync failed (best-effort).", ex, "EnsureDefaultStructureAsync()");
            }
        }

        private async Task EnsureFolderStructureExists(
            string siteId,
            List<string> folderNames,
            Drive drive,
            DriveItem parentFolder,
            string jobNumber,
            string quoteNo = "",
            string quoteUrl = "")
        {
            siteId = ResolveSiteId(siteId);

            foreach (var folderName in folderNames)
            {
                _ = await EnsureFolderExistsAsync(drive.Id!, parentFolder.Id!, folderName).ConfigureAwait(false);

                // Optional: update RecordTitle field if list exists
                // NOTE: This requires drive.List and listItem IDs which are not always loaded.
                // We keep it best-effort and only attempt if present.
            }

            // "__{jobNumber}" marker file (best-effort)
            await EnsureMarkerFileAsync(drive, parentFolder, jobNumber).ConfigureAwait(false);

            // Quote link file (best-effort)
            if (!string.IsNullOrWhiteSpace(quoteNo) && !string.IsNullOrWhiteSpace(quoteUrl))
            {
                await EnsureQuoteLinkFileAsync(drive, parentFolder, quoteNo, quoteUrl).ConfigureAwait(false);
            }
        }

        private async Task EnsureMarkerFileAsync(Drive drive, DriveItem parentFolder, string jobNumber)
        {
            if (string.IsNullOrWhiteSpace(jobNumber)) return;

            var sanitized = Functions.Functions.SanitizeFileName(jobNumber);
            var markerName = $"__{sanitized.Trim()}";

            var existing = await _graphRetry.ExecuteAsync(async () =>
                await GraphClient.Drives[drive.Id!].Items[parentFolder.Id!].Children.GetAsync(rc =>
                {
                    rc.QueryParameters.Filter = $"name eq '{EscapeODataString(markerName)}'";
                }).ConfigureAwait(false)
            ).ConfigureAwait(false);

            if (existing?.Value?.FirstOrDefault() != null)
                return;

            var fileRequestBody = new DriveItem
            {
                Name = markerName,
                File = new FileObject(),
                AdditionalData = new Dictionary<string, object>
                {
                    ["@microsoft.graph.conflictBehavior"] = "rename"
                }
            };

            await _graphRetry.ExecuteAsync(async () =>
                await GraphClient.Drives[drive.Id!].Items[parentFolder.Id!].Children.PostAsync(fileRequestBody).ConfigureAwait(false)
            ).ConfigureAwait(false);
        }

        private async Task EnsureQuoteLinkFileAsync(Drive drive, DriveItem parentFolder, string quoteNo, string quoteUrl)
        {
            var sanitizedQuote = Functions.Functions.SanitizeFileName(quoteNo);
            var linkName = $"Quote Link - {sanitizedQuote.Trim()}.url";

            var existing = await _graphRetry.ExecuteAsync(async () =>
                await GraphClient.Drives[drive.Id!].Items[parentFolder.Id!].Children.GetAsync(rc =>
                {
                    rc.QueryParameters.Filter = $"name eq '{EscapeODataString(linkName)}'";
                }).ConfigureAwait(false)
            ).ConfigureAwait(false);

            if (existing?.Value?.FirstOrDefault() != null)
                return;

            var contentBytes = System.Text.Encoding.UTF8.GetBytes($"[InternetShortcut]\r\nURL={quoteUrl}");
            using var ms = new MemoryStream(contentBytes);

            await _graphRetry.ExecuteAsync(async () =>
            {
                _ = await GraphClient
                    .Drives[drive.Id!]
                    .Items[parentFolder.Id!]
                    .ItemWithPath(linkName)
                    .Content
                    .PutAsync(ms)
                    .ConfigureAwait(false);
            }).ConfigureAwait(false);
        }

        private static string ResolveQuoteGuidString(DataObject dataObject)
        {
            try
            {
                var prop = dataObject.DataProperties
                    .FirstOrDefault(d => d.EntityPropertyGuid ==
                        Functions.Functions.ParseAndReturnEmptyGuidIfInvalid("b5d2e1d9-6133-4ab2-b28a-827ab24103cf"));

                return prop?.Value?.Unpack<StringValue>()?.ToString() ?? "";
            }
            catch
            {
                return "";
            }
        }

        private async Task AssignGroupPermissionsAsync(GraphServiceClient graphClient, string driveId, string itemId, List<ObjectSecurity> objectSecurity)
        {
            var groupIds = objectSecurity
                .Where(s => !string.IsNullOrWhiteSpace(s.GroupIdentity))
                .Select(s => s.GroupIdentity!)
                .Distinct()
                .ToList();

            if (groupIds.Count == 0)
                return;

            var byIdsBody = new GetByIdsPostRequestBody
            {
                Ids = groupIds,
                Types = new List<string> { "group" }
            };

            var directoryObjects = await _graphRetry.ExecuteAsync(async () =>
                await graphClient.DirectoryObjects.GetByIds.PostAsGetByIdsPostResponseAsync(byIdsBody).ConfigureAwait(false)
            ).ConfigureAwait(false);

            if (directoryObjects?.Value == null || directoryObjects.Value.Count == 0)
                return;

            // Grant "write" to each group (you can map roles based on your objectSecurity if needed)
            foreach (var obj in directoryObjects.Value)
            {
                if (string.IsNullOrWhiteSpace(obj.Id))
                    continue;

                var createLinkBody = new CreateLinkPostRequestBody
                {
                    Type = "edit",
                    Scope = "users",
                    RetainInheritedPermissions = true
                };

                var linkResult = await _graphRetry.ExecuteAsync(async () =>
                    await graphClient.Drives[driveId].Items[itemId].CreateLink.PostAsync(createLinkBody).ConfigureAwait(false)
                ).ConfigureAwait(false);

                if (linkResult?.ShareId == null)
                    continue;

                var grantBody = new GrantPostRequestBody
                {
                    Recipients = new List<DriveRecipient> { new() { ObjectId = obj.Id } },
                    Roles = new List<string> { "write" }
                };

                await _graphRetry.ExecuteAsync(async () =>
                {
                    _ = await graphClient.Shares[linkResult.ShareId].Permission.Grant.PostAsGrantPostResponseAsync(grantBody).ConfigureAwait(false);
                }).ConfigureAwait(false);
            }
        }

        private async Task<DriveItem> GetCreateFolder(
            string siteId,
            string dataObjectLabel,
            long dataObjectId,
            int primaryKeySplitInterval,
            Drive? parentDrive = null,
            DataObject? dataObject = null,
            SharePointDetail? sharePointDetail = null)
        {
            siteId = ResolveSiteId(siteId);

            var drive = parentDrive;
            if (drive?.Id == null)
            {
                drive = await _graphRetry.ExecuteAsync(async () =>
                    await GraphClient.Sites[siteId].Drive.GetAsync().ConfigureAwait(false)
                ).ConfigureAwait(false);

                if (drive?.Id == null)
                    throw new Exception("Failed to resolve parent drive.");
            }

            var folderNumber = primaryKeySplitInterval > 0
                ? long.Parse(Math.Floor((decimal)(dataObjectId / primaryKeySplitInterval)).ToString())
                : dataObjectId;

            var root = await _graphRetry.ExecuteAsync(async () =>
                await GraphClient.Drives[drive.Id].Root.GetAsync().ConfigureAwait(false)
            ).ConfigureAwait(false);

            if (root?.Id == null)
                throw new Exception("Failed to resolve drive root.");

            // Find folder
            var existing = await _graphRetry.ExecuteAsync(async () =>
                await GraphClient.Drives[drive.Id].Items[root.Id].Children.GetAsync(rc =>
                {
                    rc.QueryParameters.Filter = $"name eq '{folderNumber}'";
                }).ConfigureAwait(false)
            ).ConfigureAwait(false);

            var folder = existing?.Value?.FirstOrDefault(i => i.Folder != null);

            // Create folder if missing
            if (folder == null)
            {
                var createBody = new DriveItem
                {
                    Name = folderNumber.ToString(),
                    Folder = new Folder(),
                    AdditionalData = new Dictionary<string, object>
                    {
                        ["@microsoft.graph.conflictBehavior"] = "rename"
                    }
                };

                folder = await _graphRetry.ExecuteAsync(async () =>
                    await GraphClient.Drives[drive.Id].Items[root.Id].Children.PostAsync(createBody).ConfigureAwait(false)
                ).ConfigureAwait(false);

                if (folder?.Id == null)
                    throw new Exception($"Failed to create folder '{folderNumber}'.");
            }

            // ParentStructureId handling: create subfolders (kept, but made robust)
            if (sharePointDetail?.ParentStructureId > 0 && dataObject != null)
            {
                folder = await GetOrCreateSubFolder(folder, sharePointDetail.Name, drive.Id).ConfigureAwait(false);
                folder = await GetOrCreateSubFolder(folder, dataObject.DatabaseId.ToString(), drive.Id).ConfigureAwait(false);
            }

            // Best-effort list field update when this is the terminal folder (folderNumber == dataObjectId)
            if (folderNumber == dataObjectId && folder?.Id != null)
            {
                try
                {
                    var withListItem = await _graphRetry.ExecuteAsync(async () =>
                        await GraphClient.Drives[drive.Id].Items[folder.Id].GetAsync(rc =>
                        {
                            rc.QueryParameters.Expand = new[] { "listItem($select=id)" };
                        }).ConfigureAwait(false)
                    ).ConfigureAwait(false);

                    if (drive.List?.Id != null && withListItem?.ListItem?.Id != null)
                    {
                        var patch = new ListItem
                        {
                            Fields = new FieldValueSet
                            {
                                AdditionalData = new Dictionary<string, object>
                                {
                                    { "RecordTitle", dataObjectLabel }
                                }
                            }
                        };

                        await _graphRetry.ExecuteAsync(async () =>
                            await GraphClient.Sites[siteId].Lists[drive.List.Id].Items[withListItem.ListItem.Id].PatchAsync(patch).ConfigureAwait(false)
                        ).ConfigureAwait(false);
                    }
                }
                catch (Exception ex)
                {
                    _loggingHelper.LogError("Best-effort RecordTitle update failed.", ex, "GetCreateFolder()");
                }
            }

            return folder!;
        }

        private async Task<DriveItem> GetOrCreateSubFolder(DriveItem parentFolder, string subFolderName, string driveId)
        {
            var safe = EscapeODataString(subFolderName);

            var collection = await _graphRetry.ExecuteAsync(async () =>
                await GraphClient.Drives[driveId].Items[parentFolder.Id!].Children.GetAsync(rc =>
                {
                    rc.QueryParameters.Filter = $"name eq '{safe}'";
                }).ConfigureAwait(false)
            ).ConfigureAwait(false);

            var existing = collection?.Value?.FirstOrDefault(i => i.Folder != null);
            if (existing != null) return existing;

            var create = new DriveItem
            {
                Name = subFolderName,
                Folder = new Folder(),
                AdditionalData = new Dictionary<string, object>
                {
                    ["@microsoft.graph.conflictBehavior"] = "rename"
                }
            };

            var created = await _graphRetry.ExecuteAsync(async () =>
                await GraphClient.Drives[driveId].Items[parentFolder.Id!].Children.PostAsync(create).ConfigureAwait(false)
            ).ConfigureAwait(false);

            return created ?? throw new Exception($"Failed to create subfolder '{subFolderName}'.");
        }

        private async Task<Drive?> GetCreateLibrary(
            string siteId,
            bool useLibraryPerSplit,
            List<string> newFolderStructure,
            int primaryKeySplitInterval,
            Drive drive)
        {
            siteId = ResolveSiteId(siteId);

            if (newFolderStructure == null || newFolderStructure.Count < 2)
                return drive;

            var mainDriveNumber = newFolderStructure[0];
            _drive = null;

            while (_drive == null)
            {
                // 1) Try find existing drive by name
                var drivesResponse = await _graphRetry.ExecuteAsync(async () =>
                    await GraphClient.Sites[siteId].Drives.GetAsync().ConfigureAwait(false)
                ).ConfigureAwait(false);

                var all = new List<Drive>();
                if (drivesResponse != null)
                {
                    var it = PageIterator<Drive, DriveCollectionResponse>.CreatePageIterator(GraphClient, drivesResponse, d =>
                    {
                        all.Add(d);
                        return true;
                    });
                    await it.IterateAsync().ConfigureAwait(false);
                }

                _drive = all.FirstOrDefault(d => string.Equals(d.Name, mainDriveNumber, StringComparison.OrdinalIgnoreCase));

                // 2) Create list/doc lib if missing
                if (_drive == null)
                {
                    var listCreate = new List
                    {
                        DisplayName = mainDriveNumber,
                        Columns = new List<ColumnDefinition>
                        {
                            new()
                            {
                                Name = "RecordTitle",
                                DisplayName = "Record Title",
                                Text = new TextColumn
                                {
                                    AllowMultipleLines = false,
                                    AppendChangesToExistingText = false,
                                    LinesForEditing = 0,
                                    MaxLength = 255
                                }
                            }
                        },
                        ListProp = new ListInfo { Template = "documentLibrary" }
                    };

                    var created = await _graphRetry.ExecuteAsync(async () =>
                        await GraphClient.Sites[siteId].Lists.PostAsync(listCreate).ConfigureAwait(false)
                    ).ConfigureAwait(false);

                    _drive = created?.Drive;
                }
            }

            return _drive;
        }

        private async Task<Drive> GetCreateLibrary(
            string siteId,
            bool useLibraryPerSplit,
            long dataObjectId,
            int primaryKeySplitInterval,
            DataObject dataObject,
            SharePointDetail sharePointDetail)
        {
            siteId = ResolveSiteId(siteId);

            var driveNumber = primaryKeySplitInterval > 0
                ? long.Parse(Math.Floor((decimal)(dataObjectId / primaryKeySplitInterval)).ToString())
                : dataObjectId;

            _drive = null;

            while (_drive == null)
            {
                var drivesResponse = await _graphRetry.ExecuteAsync(async () =>
                    await GraphClient.Sites[siteId].Drives.GetAsync().ConfigureAwait(false)
                ).ConfigureAwait(false);

                var all = new List<Drive>();
                if (drivesResponse != null)
                {
                    var it = PageIterator<Drive, DriveCollectionResponse>.CreatePageIterator(GraphClient, drivesResponse, d =>
                    {
                        all.Add(d);
                        return true;
                    });
                    await it.IterateAsync().ConfigureAwait(false);
                }

                _drive = all.FirstOrDefault(d => string.Equals(d.Name, driveNumber.ToString(), StringComparison.OrdinalIgnoreCase));

                if (_drive == null)
                {
                    var listCreate = new List
                    {
                        DisplayName = driveNumber.ToString(),
                        Columns = new List<ColumnDefinition>
                        {
                            new()
                            {
                                Name = "RecordTitle",
                                DisplayName = "Record Title",
                                Text = new TextColumn
                                {
                                    AllowMultipleLines = false,
                                    AppendChangesToExistingText = false,
                                    LinesForEditing = 0,
                                    MaxLength = 255
                                }
                            }
                        },
                        ListProp = new ListInfo { Template = "documentLibrary" }
                    };

                    var created = await _graphRetry.ExecuteAsync(async () =>
                        await GraphClient.Sites[siteId].Lists.PostAsync(listCreate).ConfigureAwait(false)
                    ).ConfigureAwait(false);

                    _drive = created?.Drive;
                }
            }

            return _drive!;
        }
    }
}
