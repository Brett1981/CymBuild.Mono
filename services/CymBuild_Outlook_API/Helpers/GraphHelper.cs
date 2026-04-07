// ==============================
// FILE: CymBuild_Outlook_Common/Helpers/GraphHelper.cs
// ==============================
using CymBuild_Outlook_Common.Models;
using CymBuild_Outlook_Common.Models.SharePoint;
using Microsoft.Graph;
using Microsoft.Graph.Models;
using Microsoft.Graph.Models.ODataErrors;
using Microsoft.Graph.Users.Item.Messages.Item.Move;
using Newtonsoft.Json;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using DriveItem = Microsoft.Graph.Models.DriveItem;
using Message = Microsoft.Graph.Models.Message;

namespace CymBuild_Outlook_Common.Helpers
{
    public class GraphHelper : IDisposable
    {
        private readonly LoggingHelper _loggingHelper;
        private readonly IConfiguration _configuration;
        private bool _disposed;

        public GraphHelper(LoggingHelper loggingHelper, IConfiguration configuration)
        {
            _loggingHelper = loggingHelper;
            _configuration = configuration;
        }

        // ------------------------------------------------------------
        // Diagnostics helpers
        // ------------------------------------------------------------

        private void Info(string corr, string member, string stage, string msg)
            => _loggingHelper.LogInfo($"[{corr}] [{stage}] {msg}", $"{member}()");

        private void Warn(string corr, string member, string stage, string msg)
            => _loggingHelper.LogWarning($"[{corr}] [{stage}] {msg}", $"{member}()");

        private void Error(string corr, string member, string stage, string msg, Exception ex)
            => _loggingHelper.LogError($"[{corr}] [{stage}] {msg}", ex, $"{member}()");

        private static string SafeText(string? s, int max)
        {
            if (string.IsNullOrWhiteSpace(s)) return "";
            s = s.Replace("\r", " ").Replace("\n", " ").Trim();
            return s.Length <= max ? s : s.Substring(0, max) + "…";
        }

        private static string Hash10(string? s)
        {
            if (string.IsNullOrEmpty(s)) return "(empty)";
            using var sha = SHA256.Create();
            var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(s));
            return Convert.ToHexString(bytes).Substring(0, 10).ToLowerInvariant();
        }

        private static string DescribeMsg(string? messageId)
            => $"messageIdLen={(messageId?.Length ?? 0)} messageIdHash={Hash10(messageId)}";

        private static string DescribeServiceException(ServiceException ex)
        {
            var status = ex.ResponseStatusCode;
            var code = "";
            try
            {
                // Try to extract error code from the message if possible
                // Example: "Error code: X" in message
                var msgText = ex.Message ?? "";
                var codePrefix = "Error code:";
                var idx = msgText.IndexOf(codePrefix, StringComparison.OrdinalIgnoreCase);
                if (idx >= 0)
                {
                    var after = msgText.Substring(idx + codePrefix.Length).Trim();
                    var spaceIdx = after.IndexOf(' ');
                    code = spaceIdx > 0 ? after.Substring(0, spaceIdx) : after;
                }
            }
            catch
            {
                // ignore
            }
            return $"status={(int)status} code='{code}' msg='{SafeText(ex.Message, 600)}'";
        }

        // ------------------------------------------------------------
        // Categories
        // ------------------------------------------------------------

        public async Task AddOrUpdateCategoryAsync(
            GraphServiceClient graphClient,
            string userId,
            string messageId,
            string category,
            CategoryColor color,
            string? corr = null)
        {
            var c = corr ?? $"GraphHelper-{DateTime.UtcNow:HHmmssfff}-{Guid.NewGuid():N}".Substring(0, 28);
            var sw = Stopwatch.StartNew();

            try
            {
                Info(c, nameof(AddOrUpdateCategoryAsync), "START",
                    $"userIdLen={(userId?.Length ?? 0)} {DescribeMsg(messageId)} category='{category}' color='{color}'");

                if (graphClient == null) throw new ArgumentNullException(nameof(graphClient));
                if (string.IsNullOrWhiteSpace(userId)) throw new ArgumentException("userId is required", nameof(userId));
                if (string.IsNullOrWhiteSpace(messageId)) throw new ArgumentException("messageId is required", nameof(messageId));
                if (string.IsNullOrWhiteSpace(category)) throw new ArgumentException("category is required", nameof(category));

                var swMaster = Stopwatch.StartNew();
                await EnsureMasterCategoryAsync(graphClient, userId, category, color, c);
                swMaster.Stop();
                Info(c, nameof(AddOrUpdateCategoryAsync), "MASTER", $"Ensured master category ElapsedMs={swMaster.ElapsedMilliseconds}");

                var swPatch = Stopwatch.StartNew();
                await PatchMessageCategoriesWithRetryAsync(graphClient, userId, messageId, add: category, remove: null, c);
                swPatch.Stop();
                Info(c, nameof(AddOrUpdateCategoryAsync), "PATCH", $"Patched message categories ElapsedMs={swPatch.ElapsedMilliseconds}");

                Info(c, nameof(AddOrUpdateCategoryAsync), "END", $"OK totalElapsedMs={sw.ElapsedMilliseconds}");
            }
            catch (ServiceException ex)
            {
                Error(c, nameof(AddOrUpdateCategoryAsync), "GRAPH_ERR",
                    $"{DescribeServiceException(ex)} {DescribeMsg(messageId)}", ex);
            }
            catch (Exception ex)
            {
                Error(c, nameof(AddOrUpdateCategoryAsync), "ERR",
                    $"Unexpected error {DescribeMsg(messageId)}", ex);
            }
        }

        public async Task RemoveCategoryFromEmailAsync(
            GraphServiceClient graphClient,
            string userId,
            string messageId,
            string category,
            string? corr = null)
        {
            var c = corr ?? $"GraphHelper-{DateTime.UtcNow:HHmmssfff}-{Guid.NewGuid():N}".Substring(0, 28);
            var sw = Stopwatch.StartNew();

            try
            {
                Info(c, nameof(RemoveCategoryFromEmailAsync), "START",
                    $"userIdLen={(userId?.Length ?? 0)} {DescribeMsg(messageId)} category='{category}'");

                if (graphClient == null) throw new ArgumentNullException(nameof(graphClient));
                if (string.IsNullOrWhiteSpace(userId)) throw new ArgumentException("userId is required", nameof(userId));
                if (string.IsNullOrWhiteSpace(messageId)) throw new ArgumentException("messageId is required", nameof(messageId));
                if (string.IsNullOrWhiteSpace(category)) throw new ArgumentException("category is required", nameof(category));

                var swPatch = Stopwatch.StartNew();
                await PatchMessageCategoriesWithRetryAsync(graphClient, userId, messageId, add: null, remove: category, c);
                swPatch.Stop();

                Info(c, nameof(RemoveCategoryFromEmailAsync), "END", $"OK totalElapsedMs={sw.ElapsedMilliseconds} patchElapsedMs={swPatch.ElapsedMilliseconds}");
            }
            catch (ServiceException ex)
            {
                Error(c, nameof(RemoveCategoryFromEmailAsync), "GRAPH_ERR",
                    $"{DescribeServiceException(ex)} {DescribeMsg(messageId)}", ex);
            }
            catch (Exception ex)
            {
                Error(c, nameof(RemoveCategoryFromEmailAsync), "ERR",
                    $"Unexpected error {DescribeMsg(messageId)}", ex);
            }
        }

        private async Task EnsureMasterCategoryAsync(GraphServiceClient graphClient, string userId, string category, CategoryColor color, string corr)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                await Task.Delay(50);

                var categories = await graphClient.Users[userId].Outlook.MasterCategories.GetAsync();
                var existing = categories?.Value?.FirstOrDefault(c =>
                    string.Equals(c.DisplayName, category, StringComparison.OrdinalIgnoreCase));

                if (existing != null)
                {
                    Info(corr, nameof(EnsureMasterCategoryAsync), "HIT", $"Master category exists '{category}' ElapsedMs={sw.ElapsedMilliseconds}");
                    return;
                }

                var newCategory = new OutlookCategory
                {
                    DisplayName = category,
                    Color = color,
                    AdditionalData = new Dictionary<string, object>()
                };

                await Task.Delay(50);
                await graphClient.Users[userId].Outlook.MasterCategories.PostAsync(newCategory);

                Info(corr, nameof(EnsureMasterCategoryAsync), "CREATE", $"Master category created '{category}' color='{color}' ElapsedMs={sw.ElapsedMilliseconds}");
            }
            catch (ServiceException ex)
            {
                Error(corr, nameof(EnsureMasterCategoryAsync), "GRAPH_ERR", DescribeServiceException(ex), ex);
                throw;
            }
        }

        private async Task PatchMessageCategoriesWithRetryAsync(
            GraphServiceClient graphClient,
            string userId,
            string messageId,
            string? add,
            string? remove,
            string corr)
        {
            for (var attempt = 1; attempt <= 2; attempt++)
            {
                var sw = Stopwatch.StartNew();
                try
                {
                    await Task.Delay(75);

                    Info(corr, nameof(PatchMessageCategoriesWithRetryAsync), "GET",
                        $"attempt={attempt} {DescribeMsg(messageId)} add='{add ?? ""}' remove='{remove ?? ""}'");

                    var msg = await graphClient.Users[userId].Messages[messageId].GetAsync(rc =>
                    {
                        rc.QueryParameters.Select = new[] { "id", "categories", "changeKey" };
                    });

                    if (msg == null)
                    {
                        Warn(corr, nameof(PatchMessageCategoriesWithRetryAsync), "GET", "Message GET returned null.");
                        return;
                    }

                    msg.Categories ??= new List<string>();

                    if (!string.IsNullOrWhiteSpace(add) && !msg.Categories.Any(x => x.Equals(add, StringComparison.OrdinalIgnoreCase)))
                        msg.Categories.Add(add);

                    if (!string.IsNullOrWhiteSpace(remove))
                    {
                        var existing = msg.Categories.FirstOrDefault(x => x.Equals(remove, StringComparison.OrdinalIgnoreCase));
                        if (existing != null) msg.Categories.Remove(existing);
                    }

                    var patch = new Message
                    {
                        Categories = msg.Categories
                    };

                    await Task.Delay(75);

                    Info(corr, nameof(PatchMessageCategoriesWithRetryAsync), "PATCH",
                        $"attempt={attempt} patchCategoryCount={patch.Categories?.Count ?? 0}");

                    await graphClient.Users[userId].Messages[messageId].PatchAsync(patch);

                    Info(corr, nameof(PatchMessageCategoriesWithRetryAsync), "OK",
                        $"attempt={attempt} ElapsedMs={sw.ElapsedMilliseconds}");
                    return;
                }
                catch (ServiceException ex) when (attempt == 1 && IsChangeKeyMismatch(ex))
                {
                    Warn(corr, nameof(PatchMessageCategoriesWithRetryAsync), "RETRY",
                        $"ChangeKey mismatch; retrying once. {DescribeServiceException(ex)}");
                    await Task.Delay(200);
                    continue;
                }
                catch (ServiceException ex)
                {
                    Error(corr, nameof(PatchMessageCategoriesWithRetryAsync), "GRAPH_ERR",
                        $"{DescribeServiceException(ex)} {DescribeMsg(messageId)} attempt={attempt}", ex);
                    throw;
                }
            }
        }

        private static bool IsChangeKeyMismatch(ServiceException ex)
        {
            var msg = ex?.Message ?? string.Empty;
            return msg.Contains("change key", StringComparison.OrdinalIgnoreCase) ||
                   msg.Contains("ChangeKey", StringComparison.OrdinalIgnoreCase);
        }

        // ------------------------------------------------------------
        // SharePoint Upload (MIME)
        // ------------------------------------------------------------

        public async Task<SaveToSharePointResponse> UploadEmailToSharePoint(
    GraphServiceClient graphClient,
    string siteId,
    string folderPath,
    string subFolderPath,
    Stream mimeContentStream,
    string subject,
    SaveToSharePointRequest request,
    string fromName,
    DateTime utcNow,
    string? corr = null)
        {
            var c = corr ?? $"Upload-{DateTime.UtcNow:HHmmssfff}-{Guid.NewGuid():N}".Substring(0, 24);
            var sw = Stopwatch.StartNew();

            // Graph correlation (useful when cross-checking request logs)
            var clientRequestId = Guid.NewGuid().ToString();

            try
            {
                Info(c, nameof(UploadEmailToSharePoint), "START",
                    $"siteIdLen={(siteId?.Length ?? 0)} folderPath='{SafeText(folderPath, 200)}' subFolder='{SafeText(subFolderPath, 120)}' " +
                    $"{DescribeMsg(request?.MessageId)} subjectLen={(subject?.Length ?? 0)} clientRequestId={clientRequestId}");

                // -------------------------
                // Guard clauses
                // -------------------------
                if (graphClient == null)
                    return FailUpload(c, "Init", "NullGraphClient", "graphClient was null", clientRequestId);

                if (string.IsNullOrWhiteSpace(siteId))
                    return FailUpload(c, "Init", "EmptySiteId", "siteId was empty", clientRequestId);

                if (mimeContentStream == null)
                    return FailUpload(c, "Init", "NullStream", "MIME stream was null", clientRequestId);

                if (mimeContentStream.CanSeek)
                    mimeContentStream.Position = 0;

                // -------------------------
                // 1) Resolve Drive (library) + drive-relative folder
                //    Example folderPath: "TestSite/7923" => driveName="TestSite", relative="7923"
                //    If folderPath has no leading library segment, fallback to default site drive.
                // -------------------------
                var swDrive = Stopwatch.StartNew();
                var (driveId, driveName, driveRelativeBasePath) = await ResolveDriveAndBasePathAsync(
                    graphClient, siteId, folderPath, c, clientRequestId);
                swDrive.Stop();

                if (string.IsNullOrWhiteSpace(driveId))
                {
                    Warn(c, nameof(UploadEmailToSharePoint), "DRIVE",
                        $"Drive could not be resolved. driveName='{SafeText(driveName, 80)}' folderPath='{SafeText(folderPath, 200)}' ElapsedMs={swDrive.ElapsedMilliseconds}");

                    return FailUpload(c, "DriveResolve", "DriveNotFound",
                        $"Could not resolve document library/drive for folderPath='{folderPath}'.",
                        clientRequestId);
                }

                Info(c, nameof(UploadEmailToSharePoint), "DRIVE",
                    $"Drive resolved. driveId='{SafeText(driveId, 60)}' driveName='{SafeText(driveName, 80)}' basePath='{SafeText(driveRelativeBasePath, 200)}' ElapsedMs={swDrive.ElapsedMilliseconds}");

                // -------------------------
                // 2) Build final folder path (drive-relative)
                //    basePath + subFolder (if any)
                // -------------------------
                var normalizedFolder = CombinePaths(driveRelativeBasePath, subFolderPath);
                normalizedFolder = normalizedFolder.Replace("\\", "/");
                while (normalizedFolder.Contains("//"))
                    normalizedFolder = normalizedFolder.Replace("//", "/");

                Info(c, nameof(UploadEmailToSharePoint), "PATH",
                    $"Drive-relative folder='{SafeText(normalizedFolder, 240)}' (drive='{SafeText(driveName, 80)}')");

                // -------------------------
                // 3) Build file name (safe + bounded length)
                // -------------------------
                var safeSubject = SanitizeFileName(subject);
                if (string.IsNullOrWhiteSpace(safeSubject))
                    safeSubject = "Email";

                var fileName = $"{utcNow:yyyy-MM-dd_HH-mm} - {safeSubject}.eml";
                fileName = EnsureMaxFileNameLength(fileName, 180);

                Info(c, nameof(UploadEmailToSharePoint), "FILENAME",
                    $"fileName='{SafeText(fileName, 220)}' fromName='{SafeText(fromName, 80)}'");

                // -------------------------
                // 4) Ensure folder path exists (segment-by-segment)
                // -------------------------
                if (!string.IsNullOrWhiteSpace(normalizedFolder))
                {
                    var swEnsure = Stopwatch.StartNew();
                    await EnsureFolderPathExistsAsync(graphClient, driveId, normalizedFolder, c, clientRequestId);
                    swEnsure.Stop();

                    Info(c, nameof(UploadEmailToSharePoint), "FOLDERS",
                        $"Ensured folder path exists. ElapsedMs={swEnsure.ElapsedMilliseconds} path='{SafeText(normalizedFolder, 240)}'");
                }

                // -------------------------
                // 5) Upload path (drive-relative)
                // -------------------------
                var uploadPath = string.IsNullOrWhiteSpace(normalizedFolder)
                    ? fileName
                    : $"{normalizedFolder}/{fileName}";

                uploadPath = uploadPath.Replace("\\", "/");
                while (uploadPath.Contains("//"))
                    uploadPath = uploadPath.Replace("//", "/");

                if (mimeContentStream.CanSeek)
                    mimeContentStream.Position = 0;

                Info(c, nameof(UploadEmailToSharePoint), "PUT",
                    $"Uploading driveId='{SafeText(driveId, 60)}' path='{SafeText(uploadPath, 260)}' clientRequestId={clientRequestId}");

                // -------------------------
                // 6) Upload (PUT content)
                // -------------------------
                var swPut = Stopwatch.StartNew();

                var uploadedItem = await graphClient
                    .Drives[driveId]
                    .Root
                    .ItemWithPath(uploadPath)
                    .Content
                    .PutAsync(mimeContentStream, rc =>
                    {
                        rc.Headers.Add("client-request-id", clientRequestId);
                        rc.Headers.Add("return-client-request-id", "true");
                    });

                swPut.Stop();

                if (uploadedItem == null)
                {
                    Warn(c, nameof(UploadEmailToSharePoint), "PUT",
                        $"Upload returned null DriveItem. ElapsedMs={swPut.ElapsedMilliseconds}");

                    return FailUpload(c, "Upload", "NullDriveItem",
                        "Upload returned null DriveItem.",
                        clientRequestId, driveId: driveId);
                }

                Info(c, nameof(UploadEmailToSharePoint), "UPLOAD_OK",
                    $"Uploaded OK. putElapsedMs={swPut.ElapsedMilliseconds} itemIdLen={(uploadedItem.Id?.Length ?? 0)} webUrlLen={(uploadedItem.WebUrl?.Length ?? 0)}");

                // -------------------------
                // 7) Update SharePoint metadata (description) 
                // -------------------------
                if (!string.IsNullOrWhiteSpace(request.Description) && !string.IsNullOrWhiteSpace(uploadedItem.Id))
                {
                    await UpdateSharePointDescriptionAsync(
                        graphClient,
                        siteId,
                        driveId,
                        uploadedItem.Id,
                        request.Description,
                        c,
                        clientRequestId).ConfigureAwait(false);
                }

                Info(c, nameof(UploadEmailToSharePoint), "END",
                    $"SUCCESS totalElapsedMs={sw.ElapsedMilliseconds} driveId='{SafeText(driveId, 60)}' itemId='{SafeText(uploadedItem.Id, 80)}'");

                return new SaveToSharePointResponse
                {
                    Status = "Success",
                    FullUrl = uploadedItem.WebUrl ?? "",
                    DriveId = driveId,
                    ItemId = uploadedItem.Id ?? "",
                    CorrelationId = c,
                    Stage = "UploadComplete",
                    ErrorCode = "",
                    ErrorMessage = "",
                    GraphClientRequestId = clientRequestId,
                    GraphRequestId = ""
                };
            }
            catch (ODataError odata)
            {
                var msg = odata?.Error?.Message ?? "Unknown ODataError";
                Warn(c, nameof(UploadEmailToSharePoint), "ODATA",
                    $"Failed - ODataError: '{SafeText(msg, 900)}' totalElapsedMs={sw.ElapsedMilliseconds}");

                return new SaveToSharePointResponse
                {
                    Status = "Failed",
                    FullUrl = "",
                    CorrelationId = c,
                    Stage = "ODataError",
                    ErrorCode = "ODataError",
                    ErrorMessage = msg,
                    GraphClientRequestId = clientRequestId
                };
            }
            catch (ServiceException ex)
            {
                var requestId = TryGetGraphHeader(ex, "request-id") ?? "";
                var returnedClientRequestId = TryGetGraphHeader(ex, "client-request-id") ?? "";

                Error(c, nameof(UploadEmailToSharePoint), "GRAPH_ERR",
                    $"{DescribeServiceException(ex)} request-id='{SafeText(requestId, 80)}' client-request-id='{SafeText(returnedClientRequestId, 80)}' totalElapsedMs={sw.ElapsedMilliseconds}", ex);

                var isNotFound =
                    (int?)ex.ResponseStatusCode == 404 ||
                    ex.Message.Contains("resource could not be found", StringComparison.OrdinalIgnoreCase) ||
                    ex.Message.Contains("itemNotFound", StringComparison.OrdinalIgnoreCase);

                return new SaveToSharePointResponse
                {
                    Status = "Failed",
                    FullUrl = "",
                    CorrelationId = c,
                    Stage = isNotFound ? "UploadTargetNotFound" : "GraphException",
                    ErrorCode = $"ServiceException:{(int?)ex.ResponseStatusCode}",
                    ErrorMessage = ex.Message,
                    GraphRequestId = requestId,
                    GraphClientRequestId = string.IsNullOrWhiteSpace(returnedClientRequestId) ? clientRequestId : returnedClientRequestId
                };
            }
            catch (Exception ex)
            {
                Error(c, nameof(UploadEmailToSharePoint), "ERR",
                    $"Failed - Exception: '{SafeText(ex.Message, 900)}' totalElapsedMs={sw.ElapsedMilliseconds}", ex);

                return new SaveToSharePointResponse
                {
                    Status = "Failed",
                    FullUrl = "",
                    CorrelationId = c,
                    Stage = "Exception",
                    ErrorCode = "Exception",
                    ErrorMessage = ex.Message,
                    GraphClientRequestId = clientRequestId
                };
            }
        }

        private async Task<(string DriveId, string DriveName, string DriveRelativeBasePath)> ResolveDriveAndBasePathAsync(
            GraphServiceClient graphClient,
            string siteId,
            string folderPath,
            string corr,
            string clientRequestId)
        {
            // folderPath examples we’ve seen:
            // - "TestSite/7923"
            // - "7923"
            // - ""  (rare)
            var cleaned = (folderPath ?? "").Trim().Replace("\\", "/");
            while (cleaned.Contains("//"))
                cleaned = cleaned.Replace("//", "/");

            if (string.IsNullOrWhiteSpace(cleaned))
            {
                // fallback to default drive
                var d = await graphClient.Sites[siteId].Drive.GetAsync(rc =>
                {
                    rc.Headers.Add("client-request-id", clientRequestId);
                    rc.Headers.Add("return-client-request-id", "true");
                });

                return (d?.Id ?? "", d?.Name ?? "Default", "");
            }

            var parts = cleaned.Split('/', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length >= 2)
            {
                // assume first segment is drive/library name
                var driveName = parts[0];
                var basePath = string.Join("/", parts.Skip(1));

                // find drive by name
                var drives = await graphClient.Sites[siteId].Drives.GetAsync(rc =>
                {
                    rc.Headers.Add("client-request-id", clientRequestId);
                    rc.Headers.Add("return-client-request-id", "true");
                });

                var match = drives?.Value?.FirstOrDefault(d =>
                    string.Equals(d.Name, driveName, StringComparison.OrdinalIgnoreCase));

                if (match?.Id != null)
                    return (match.Id, match.Name ?? driveName, basePath);

                // fallback: if it wasn't a library name after all, use default drive and keep original path
                var def = await graphClient.Sites[siteId].Drive.GetAsync(rc =>
                {
                    rc.Headers.Add("client-request-id", clientRequestId);
                    rc.Headers.Add("return-client-request-id", "true");
                });

                return (def?.Id ?? "", def?.Name ?? "Default", cleaned);
            }
            else
            {
                // single segment path, use default drive
                var def = await graphClient.Sites[siteId].Drive.GetAsync(rc =>
                {
                    rc.Headers.Add("client-request-id", clientRequestId);
                    rc.Headers.Add("return-client-request-id", "true");
                });

                return (def?.Id ?? "", def?.Name ?? "Default", cleaned);
            }
        }

        private static string CombinePaths(string a, string b)
        {
            var left = (a ?? "").Trim().Trim('/');
            var right = (b ?? "").Trim().Trim('/');

            if (string.IsNullOrWhiteSpace(left)) return right;
            if (string.IsNullOrWhiteSpace(right)) return left;
            return $"{left}/{right}";
        }

        private async Task EnsureFolderPathExistsAsync(
            GraphServiceClient graphClient,
            string driveId,
            string folderPath,
            string corr,
            string clientRequestId)
        {
            // Create each segment under the previous folder (avoid ItemWithPath ambiguity + easier debugging)
            var cleaned = (folderPath ?? "").Trim().Replace("\\", "/").Trim('/');
            if (string.IsNullOrWhiteSpace(cleaned))
                return;

            // Start at root
            var root = await graphClient.Drives[driveId].Root.GetAsync(rc =>
            {
                rc.Headers.Add("client-request-id", clientRequestId);
                rc.Headers.Add("return-client-request-id", "true");
            });

            if (root?.Id == null)
                throw new Exception("Drive root could not be resolved (root.Id was null).");

            var parentId = root.Id;
            var segments = cleaned.Split('/', StringSplitOptions.RemoveEmptyEntries);

            foreach (var seg in segments)
            {
                var safeName = seg.Replace("'", "''");

                // Look for existing folder
                var children = await graphClient.Drives[driveId].Items[parentId].Children.GetAsync(rc =>
                {
                    rc.Headers.Add("client-request-id", clientRequestId);
                    rc.Headers.Add("return-client-request-id", "true");
                    rc.QueryParameters.Filter = $"name eq '{safeName}'";
                });

                var existing = children?.Value?.FirstOrDefault(i => i.Folder != null);

                if (existing?.Id != null)
                {
                    parentId = existing.Id;
                    continue;
                }

                // Create missing folder
                var create = new DriveItem
                {
                    Name = seg,
                    Folder = new Folder(),
                    AdditionalData = new Dictionary<string, object>
                    {
                        ["@microsoft.graph.conflictBehavior"] = "rename"
                    }
                };

                var created = await graphClient.Drives[driveId].Items[parentId].Children.PostAsync(create, rc =>
                {
                    rc.Headers.Add("client-request-id", clientRequestId);
                    rc.Headers.Add("return-client-request-id", "true");
                });

                if (created?.Id == null)
                    throw new Exception($"Failed to create folder segment '{seg}' under parentId '{parentId}'.");

                parentId = created.Id;
            }
        }




        private static string NormalizeDriveRelativePath(string folderPath, string subFolderPath)
        {
            string Clean(string s) => (s ?? "").Replace("\\", "/").Trim().Trim('/');

            var fp = Clean(folderPath);
            var sf = Clean(subFolderPath);

            // If folderPath includes a site-ish prefix like "TestSite/7923",
            // strip the first segment so we end up with "7923".
            if (fp.Contains("/"))
            {
                var parts = fp.Split('/', StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length >= 2)
                    fp = string.Join("/", parts.Skip(1)); // drop the "TestSite" prefix
            }

            if (string.IsNullOrWhiteSpace(fp))
                return sf;

            if (string.IsNullOrWhiteSpace(sf))
                return fp;

            return $"{fp}/{sf}";
        }



        // -----------------------------------------------------------------------------
        // Helper: consistent failure response for this method
        // -----------------------------------------------------------------------------
        private SaveToSharePointResponse FailUpload(
            string corr,
            string stage,
            string code,
            string message,
            string clientRequestId,
            string? driveId = null,
            string? itemId = null)
        {
            return new SaveToSharePointResponse
            {
                Status = "Failed",
                FullUrl = "",
                CorrelationId = corr,
                Stage = stage,
                ErrorCode = code,
                ErrorMessage = message,
                DriveId = driveId ?? "",
                ItemId = itemId ?? "",
                GraphClientRequestId = clientRequestId,
                GraphRequestId = ""
            };
        }


        private string? TryGetGraphHeader(ServiceException ex, string headerName)
        {
            try
            {
                if (ex?.ResponseHeaders == null) return null;
                foreach (var kv in ex.ResponseHeaders)
                {
                    if (kv.Key.Equals(headerName, StringComparison.OrdinalIgnoreCase))
                        return kv.Value?.FirstOrDefault();
                }
            }
            catch { /* ignore */ }
            return null;
        }

        private static string NormalizeSharePointFolderPath(string folderPath, string subFolderPath)
        {
            var p1 = (folderPath ?? "").Trim().Trim('/').Replace("\\", "/");
            var p2 = (subFolderPath ?? "").Trim().Trim('/').Replace("\\", "/");

            if (string.IsNullOrWhiteSpace(p1) && string.IsNullOrWhiteSpace(p2))
                return "";

            if (string.IsNullOrWhiteSpace(p1))
                return p2;

            if (string.IsNullOrWhiteSpace(p2))
                return p1;

            return $"{p1}/{p2}";
        }

        private async Task EnsureFolderPathExistsAsync(GraphServiceClient graphClient, string driveId, string folderPath, string corr)
        {
            if (string.IsNullOrWhiteSpace(folderPath))
                return;

            // drive-relative path, split into segments: "TestSite/7923/Emails"
            var segments = folderPath
                .Replace("\\", "/")
                .Split(new[] { '/' }, StringSplitOptions.RemoveEmptyEntries);

            // Build incrementally: "TestSite", then "TestSite/7923", then "TestSite/7923/Emails"
            var currentPath = "";

            foreach (var segRaw in segments)
            {
                var seg = segRaw.Trim();
                if (string.IsNullOrWhiteSpace(seg))
                    continue;

                currentPath = string.IsNullOrWhiteSpace(currentPath) ? seg : $"{currentPath}/{seg}";

                // Does this folder exist?
                try
                {
                    _ = await graphClient
                        .Drives[driveId]
                        .Root
                        .ItemWithPath(currentPath)
                        .GetAsync();

                    // Exists
                    continue;
                }
                catch (ServiceException ex) when ((int?)ex.ResponseStatusCode == 404)
                {
                    // Need to create it under its parent
                }

                // Determine parent path
                var lastSlash = currentPath.LastIndexOf('/');
                var parentPath = lastSlash > 0 ? currentPath.Substring(0, lastSlash) : "";
                var childName = lastSlash > 0 ? currentPath[(lastSlash + 1)..] : currentPath;

                // Parent item: root or ItemWithPath(parentPath)
                DriveItem? parentItem;

                if (string.IsNullOrWhiteSpace(parentPath))
                {
                    parentItem = await graphClient.Drives[driveId].Root.GetAsync();
                }
                else
                {
                    parentItem = await graphClient.Drives[driveId].Root.ItemWithPath(parentPath).GetAsync();
                }

                if (parentItem?.Id == null)
                    throw new Exception($"EnsureFolderPathExistsAsync: Parent folder could not be resolved for '{parentPath}'.");

                // Create folder
                var newFolder = new DriveItem
                {
                    Name = childName,
                    Folder = new Folder(),
                    AdditionalData = new Dictionary<string, object>
                    {
                        // If the folder already exists due to race, rename is not what we want.
                        // We want "fail" (then caller will re-check). But Graph supports conflictBehavior.
                        ["@microsoft.graph.conflictBehavior"] = "fail"
                    }
                };

                try
                {
                    await graphClient.Drives[driveId].Items[parentItem.Id].Children.PostAsync(newFolder);
                }
                catch (ServiceException ex) when ((int?)ex.ResponseStatusCode == 409)
                {
                    // Folder already exists (race) - safe to continue
                }
            }
        }

        private static string SanitizeFileName(string input)
        {
            if (string.IsNullOrWhiteSpace(input))
                return "";

            var s = input.Replace("\r", " ").Replace("\n", " ").Trim();
            s = Regex.Replace(s, @"\s+", " ");

            var invalid = Path.GetInvalidFileNameChars();
            var sb = new StringBuilder(s.Length);
            foreach (var ch in s)
                sb.Append(invalid.Contains(ch) ? '_' : ch);

            return sb.ToString().Trim().TrimEnd('.', ' ');
        }

        private static string EnsureMaxFileNameLength(string fileName, int maxLength)
        {
            if (string.IsNullOrWhiteSpace(fileName)) return "Email.eml";
            if (fileName.Length <= maxLength) return fileName;

            var ext = Path.GetExtension(fileName);
            var name = Path.GetFileNameWithoutExtension(fileName);

            var maxNameLen = Math.Max(10, maxLength - ext.Length);
            if (name.Length > maxNameLen)
                name = name.Substring(0, maxNameLen);

            return $"{name}{ext}";
        }

        // ------------------------------------------------------------
        // Extended Properties (Filed Records)
        // ------------------------------------------------------------

        private string GetExtendedFiledRecordPropertyName()
        {
            var cfg = _configuration.GetSection("FiledRecords");

            // Support array form: "Extended": [ "PropName" ]
            var arr = cfg.GetValue<string[]>("Extended");
            var fromArr = arr?.FirstOrDefault(x => !string.IsNullOrWhiteSpace(x));
            if (!string.IsNullOrWhiteSpace(fromArr))
                return fromArr.Trim();

            // Support string form: "Extended": "PropName"
            var single = cfg.GetValue<string>("Extended");
            if (!string.IsNullOrWhiteSpace(single))
                return single.Trim();

            // Support nested object form if ever used: "Extended": { "PropertyName": "PropName" }
            var nested = cfg.GetSection("Extended").GetValue<string>("PropertyName");
            if (!string.IsNullOrWhiteSpace(nested))
                return nested.Trim();

            return string.Empty;
        }

        public async Task AddCustomPropertiesToEmail(GraphServiceClient graphClient, string userId, string messageId, List<RecordSearchResult> selectedRecords, string? corr = null)
        {
            var c = corr ?? $"Props-{DateTime.UtcNow:HHmmssfff}-{Guid.NewGuid():N}".Substring(0, 22);
            var sw = Stopwatch.StartNew();

            try
            {
                Info(c, nameof(AddCustomPropertiesToEmail), "START", $"userIdLen={(userId?.Length ?? 0)} {DescribeMsg(messageId)} records={selectedRecords?.Count ?? 0}");

                if (graphClient == null) throw new ArgumentNullException(nameof(graphClient));
                if (string.IsNullOrWhiteSpace(userId)) throw new ArgumentException("userId is required", nameof(userId));
                if (string.IsNullOrWhiteSpace(messageId)) throw new ArgumentException("messageId is required", nameof(messageId));

                var propName = GetExtendedFiledRecordPropertyName();
                if (string.IsNullOrWhiteSpace(propName))
                    throw new InvalidOperationException("FiledRecords:Extended config missing (property name).");

                var filedRecordsJson = JsonConvert.SerializeObject(selectedRecords);

                var customProps = new List<SingleValueLegacyExtendedProperty>
                {
                    new SingleValueLegacyExtendedProperty
                    {
                        Id = $"String {{00020329-0000-0000-C000-000000000046}} Name {propName}",
                        Value = filedRecordsJson
                    }
                };

                var patch = new Message
                {
                    SingleValueExtendedProperties = customProps
                };

                await Task.Delay(75);
                await graphClient.Users[userId].Messages[messageId].PatchAsync(patch);

                Info(c, nameof(AddCustomPropertiesToEmail), "END", $"OK totalElapsedMs={sw.ElapsedMilliseconds}");
            }
            catch (ServiceException ex)
            {
                Error(c, nameof(AddCustomPropertiesToEmail), "GRAPH_ERR", $"{DescribeServiceException(ex)} {DescribeMsg(messageId)}", ex);
            }
            catch (Exception ex)
            {
                Error(c, nameof(AddCustomPropertiesToEmail), "ERR", $"Unexpected error {DescribeMsg(messageId)}", ex);
            }
        }

        public async Task<Message> GetEmailWithCustomProperties(GraphServiceClient graphClient, string userId, string messageId, string? corr = null)
        {
            var c = corr ?? $"GetMsg-{DateTime.UtcNow:HHmmssfff}-{Guid.NewGuid():N}".Substring(0, 22);
            var sw = Stopwatch.StartNew();

            try
            {
                Info(c, nameof(GetEmailWithCustomProperties), "START", $"userIdLen={(userId?.Length ?? 0)} {DescribeMsg(messageId)}");

                if (graphClient == null) throw new ArgumentNullException(nameof(graphClient));
                if (string.IsNullOrWhiteSpace(userId)) throw new ArgumentException("userId is required", nameof(userId));
                if (string.IsNullOrWhiteSpace(messageId)) throw new ArgumentException("messageId is required", nameof(messageId));

                var propName = GetExtendedFiledRecordPropertyName();
                if (string.IsNullOrWhiteSpace(propName))
                    throw new InvalidOperationException("FiledRecords:Extended config missing (property name).");

                var expand = $"singleValueExtendedProperties($filter=id eq 'String {{00020329-0000-0000-C000-000000000046}} Name {propName}')";

                var message = await graphClient.Users[userId].Messages[messageId].GetAsync(rc =>
                {
                    rc.QueryParameters.Expand = new[] { expand };
                });

                Info(c, nameof(GetEmailWithCustomProperties), "END", $"OK totalElapsedMs={sw.ElapsedMilliseconds} subject='{SafeText(message?.Subject, 80)}'");
                return message!;
            }
            catch (ServiceException ex)
            {
                Error(c, nameof(GetEmailWithCustomProperties), "GRAPH_ERR", $"{DescribeServiceException(ex)} {DescribeMsg(messageId)}", ex);
                throw;
            }
            catch (Exception ex)
            {
                Error(c, nameof(GetEmailWithCustomProperties), "ERR", $"Unexpected error {DescribeMsg(messageId)}", ex);
                throw;
            }
        }

        // ------------------------------------------------------------
        // Move + ensure folder
        // ------------------------------------------------------------

        public async Task MoveEmailToFolderAsync(
            GraphServiceClient graphClient,
            string userId,
            string messageId,
            string folderName,
            List<RecordSearchResult> selectedRecordsJson,
            string? corr = null)
        {
            var c = corr ?? $"Move-{DateTime.UtcNow:HHmmssfff}-{Guid.NewGuid():N}".Substring(0, 20);
            var sw = Stopwatch.StartNew();

            try
            {
                Info(c, nameof(MoveEmailToFolderAsync), "START",
                    $"userIdLen={(userId?.Length ?? 0)} {DescribeMsg(messageId)} folder='{folderName}' records={selectedRecordsJson?.Count ?? 0}");

                if (graphClient == null) throw new ArgumentNullException(nameof(graphClient));
                if (string.IsNullOrWhiteSpace(userId)) throw new ArgumentException("userId is required", nameof(userId));
                if (string.IsNullOrWhiteSpace(messageId)) throw new ArgumentException("messageId is required", nameof(messageId));
                if (string.IsNullOrWhiteSpace(folderName)) throw new ArgumentException("folderName is required", nameof(folderName));

                await Task.Delay(75);

                var folders = await graphClient.Users[userId].MailFolders.GetAsync(rc =>
                {
                    rc.QueryParameters.Top = 200;
                    rc.QueryParameters.Select = new[] { "id", "displayName" };
                });

                var targetFolder = folders?.Value?.FirstOrDefault(f =>
                    string.Equals(f.DisplayName, folderName, StringComparison.OrdinalIgnoreCase));

                if (targetFolder == null)
                {
                    var created = await graphClient.Users[userId].MailFolders.PostAsync(new MailFolder
                    {
                        DisplayName = folderName
                    });

                    if (created?.Id == null)
                        throw new Exception($"Failed to create folder '{folderName}'.");

                    targetFolder = created;
                    Info(c, nameof(MoveEmailToFolderAsync), "FOLDER", $"Created folder idLen={created.Id.Length}");
                }

                var moveRequestBody = new MovePostRequestBody
                {
                    DestinationId = targetFolder.Id
                };

                await Task.Delay(75);

                var swMove = Stopwatch.StartNew();
                var movedMessage = await graphClient.Users[userId].Messages[messageId].Move.PostAsync(moveRequestBody);
                swMove.Stop();

                if (movedMessage?.Id == null)
                    throw new Exception("Move returned null message id.");

                Info(c, nameof(MoveEmailToFolderAsync), "MOVE",
                    $"Moved OK moveElapsedMs={swMove.ElapsedMilliseconds} newMsgIdHash={Hash10(movedMessage.Id)} newMsgIdLen={movedMessage.Id.Length}");

                await AddCustomPropertiesToEmail(graphClient, userId, movedMessage.Id, selectedRecordsJson, c);

                Info(c, nameof(MoveEmailToFolderAsync), "END", $"OK totalElapsedMs={sw.ElapsedMilliseconds}");
            }
            catch (ServiceException ex)
            {
                Error(c, nameof(MoveEmailToFolderAsync), "GRAPH_ERR", $"{DescribeServiceException(ex)} {DescribeMsg(messageId)}", ex);
            }
            catch (Exception ex)
            {
                Error(c, nameof(MoveEmailToFolderAsync), "ERR", $"Unexpected error {DescribeMsg(messageId)}", ex);
            }
        }

        // ------------------------------------------------------------
        // SharePoint Metadata Update
        // ------------------------------------------------------------

        private async Task UpdateSharePointDescriptionAsync(
            GraphServiceClient graphClient,
            string siteId,
            string driveId,
            string itemId,
            string description,
            string corr,
            string clientRequestId)
        {
            var sw = Stopwatch.StartNew();

            try
            {
                Info(corr, nameof(UpdateSharePointDescriptionAsync), "START",
                    $"itemIdLen={itemId?.Length ?? 0} descriptionLen={description?.Length ?? 0}");

                // Get the item with listItem expanded to access SharePoint list fields
                var itemWithList = await graphClient
                    .Drives[driveId]
                    .Items[itemId]
                    .GetAsync(rc =>
                    {
                        rc.QueryParameters.Expand = new[] { "listItem($select=id)" };
                        rc.Headers.Add("client-request-id", clientRequestId);
                        rc.Headers.Add("return-client-request-id", "true");
                    }).ConfigureAwait(false);

                if (itemWithList?.ListItem?.Id == null)
                {
                    Warn(corr, nameof(UpdateSharePointDescriptionAsync), "SKIP",
                        $"ListItem not available. ElapsedMs={sw.ElapsedMilliseconds}");
                    return;
                }

                // Get the list ID from the drive
                var drive = await graphClient
                    .Drives[driveId]
                    .GetAsync(rc =>
                    {
                        rc.QueryParameters.Select = new[] { "id", "name" };
                        rc.QueryParameters.Expand = new[] { "list" };
                        rc.Headers.Add("client-request-id", clientRequestId);
                        rc.Headers.Add("return-client-request-id", "true");
                    }).ConfigureAwait(false);

                if (drive?.List?.Id == null)
                {
                    Warn(corr, nameof(UpdateSharePointDescriptionAsync), "SKIP",
                        $"Drive.List not available. ElapsedMs={sw.ElapsedMilliseconds}");
                    return;
                }

                // Update the Description field (internal name: _ExtendedDescription)
                var listItem = new Microsoft.Graph.Models.ListItem
                {
                    Fields = new FieldValueSet
                    {
                        AdditionalData = new Dictionary<string, object>
                        {
                            { "_ExtendedDescription", description }
                        }
                    }
                };

                await graphClient
                    .Sites[siteId]
                    .Lists[drive.List.Id]
                    .Items[itemWithList.ListItem.Id]
                    .PatchAsync(listItem, rc =>
                    {
                        rc.Headers.Add("client-request-id", clientRequestId);
                        rc.Headers.Add("return-client-request-id", "true");
                    }).ConfigureAwait(false);

                sw.Stop();
                Info(corr, nameof(UpdateSharePointDescriptionAsync), "END",
                    $"Description field updated successfully. ElapsedMs={sw.ElapsedMilliseconds}");
            }
            catch (ServiceException ex) when ((int?)ex.ResponseStatusCode == 400 ||
                                             ex.Message.Contains("does not exist", StringComparison.OrdinalIgnoreCase) ||
                                             ex.Message.Contains("column", StringComparison.OrdinalIgnoreCase))
            {
                sw.Stop();
                Warn(corr, nameof(UpdateSharePointDescriptionAsync), "FIELD_NOT_EXIST",
                    $"Description column likely does not exist in this library (continuing). ElapsedMs={sw.ElapsedMilliseconds} {SafeText(ex.Message, 400)}");
            }
            catch (Exception ex)
            {
                sw.Stop();
                Warn(corr, nameof(UpdateSharePointDescriptionAsync), "FAILED",
                    $"Failed to update description field (continuing). ElapsedMs={sw.ElapsedMilliseconds} {SafeText(ex.Message, 400)}");
            }
        }

        // ------------------------------------------------------------
        // IDisposable
        // ------------------------------------------------------------

        protected virtual void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                _disposed = true;
            }
        }

        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }
    }
}
