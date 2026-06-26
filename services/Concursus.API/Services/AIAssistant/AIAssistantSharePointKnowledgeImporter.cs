using Concursus.API.Classes;
using Microsoft.Data.SqlClient;
using Microsoft.Graph;
using Microsoft.Graph.Models;
using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace Concursus.API.Services.AIAssistant;

public interface IAIAssistantSharePointKnowledgeImporter
{
    Task<AIAssistantKnowledgeImportResult> ImportTrainingMaterialAsync(
        int userId,
        bool publishImmediately,
        bool authoritative,
        CancellationToken cancellationToken);
}

public sealed class AIAssistantSharePointKnowledgeImporter : IAIAssistantSharePointKnowledgeImporter
{
    private readonly GraphServiceClient _graphClient;
    private readonly IConfiguration _configuration;
    private readonly IKnowledgeTextExtractor _extractor;
    private readonly ILogger<AIAssistantSharePointKnowledgeImporter> _logger;

    public AIAssistantSharePointKnowledgeImporter(
        GraphServiceClient graphClient,
        IConfiguration configuration,
        IKnowledgeTextExtractor extractor,
        ILogger<AIAssistantSharePointKnowledgeImporter> logger)
    {
        _graphClient = graphClient ?? throw new ArgumentNullException(nameof(graphClient));
        _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
        _extractor = extractor ?? throw new ArgumentNullException(nameof(extractor));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task<AIAssistantKnowledgeImportResult> ImportTrainingMaterialAsync(
        int userId,
        bool publishImmediately,
        bool authoritative,
        CancellationToken cancellationToken)
    {
        if (userId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(userId), "A valid CymBuild user id is required.");
        }

        var options = LoadOptions();
        ValidateOptions(options);

        var result = new AIAssistantKnowledgeImportResult();
        var files = await LoadCandidateFilesAsync(options, cancellationToken);
        result = result with { FilesFound = files.Count };

        await using var sqlConnection = new SqlConnection(_configuration.GetConnectionString("ShoreDB"));
        await sqlConnection.OpenAsync(cancellationToken);

        var processedFiles = 0;
        foreach (var file in files)
        {
            cancellationToken.ThrowIfCancellationRequested();

            if (++processedFiles > options.MaxFilesPerRun)
            {
                result.Log.Add(new AIAssistantKnowledgeImportLogEntry
                {
                    Level = "WARN",
                    FileName = file.Name ?? string.Empty,
                    Message = $"Run stopped after MaxFilesPerRun={options.MaxFilesPerRun}."
                });
                break;
            }

            try
            {
                var extension = Path.GetExtension(file.Name).ToLowerInvariant();
                _logger.LogInformation(
                    "Found file {Name} ({Extension})",
                    file.Name,
                    extension);
                if (!options.SupportedExtensions.Contains(extension, StringComparer.OrdinalIgnoreCase))
                {
                    result = result with { FilesSkipped = result.FilesSkipped + 1 };
                    result.Log.Add(new AIAssistantKnowledgeImportLogEntry
                    {
                        Level = "INFO",
                        FileName = file.Name ?? string.Empty,
                        Message = $"Skipped unsupported file type '{extension}'."
                    });
                    continue;
                }

                await using var content = await _graphClient
                    .Drives[file.ParentReference!.DriveId]
                    .Items[file.Id]
                    .Content
                    .GetAsync(cancellationToken: cancellationToken);

                if (content is null)
                {
                    result = result with { FilesSkipped = result.FilesSkipped + 1 };
                    result.Log.Add(new AIAssistantKnowledgeImportLogEntry
                    {
                        Level = "WARN",
                        FileName = file.Name ?? string.Empty,
                        Message = "Graph returned no file stream."
                    });
                    continue;
                }

                var extractedText = await _extractor.ExtractTextAsync(file.Name ?? string.Empty, content, cancellationToken);
                if (string.IsNullOrWhiteSpace(extractedText))
                {
                    result = result with { FilesSkipped = result.FilesSkipped + 1 };
                    result.Log.Add(new AIAssistantKnowledgeImportLogEntry
                    {
                        Level = "WARN",
                        FileName = file.Name ?? string.Empty,
                        Message = "No text was extracted."
                    });
                    continue;
                }

                var sourceUrl = file.WebUrl ?? string.Empty;
                var folderPath = file.ParentReference?.Path ?? string.Empty;
                var document = new ExtractedKnowledgeDocument(
                    Title: Path.GetFileNameWithoutExtension(file.Name),
                    SourceUrl: sourceUrl,
                    PreviewUrl: sourceUrl,
                    FolderPath: folderPath,
                    Extension: extension.TrimStart('.').ToUpperInvariant(),
                    ExtractedText: extractedText);

                var chunks = ChunkDocument(document, options.MaxChunkCharacters);
                foreach (var chunk in chunks)
                {
                    var guid = CreateDeterministicGuid($"CYMBUILD-AI-KNOWLEDGE|{chunk.Slug}");
                    await UpsertKnowledgeItemAsync(
                        sqlConnection,
                        userId,
                        guid,
                        chunk,
                        document,
                        publishImmediately,
                        authoritative,
                        cancellationToken);

                    result = result with { ItemsUpserted = result.ItemsUpserted + 1 };
                    result.Log.Add(new AIAssistantKnowledgeImportLogEntry
                    {
                        Level = "INFO",
                        FileName = file.Name ?? string.Empty,
                        Message = $"Upserted knowledge item '{chunk.Title}'.",
                        KnowledgeItemGuid = guid.ToString()
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "AI Assistant knowledge import failed for {FileName}", file.Name);
                result = result with { Failures = result.Failures + 1 };
                result.Log.Add(new AIAssistantKnowledgeImportLogEntry
                {
                    Level = "ERROR",
                    FileName = file.Name ?? string.Empty,
                    Message = ex.Message
                });
            }
        }

        return result;
    }

    private AIAssistantKnowledgeImportOptions LoadOptions()
    {
        var section = _configuration.GetSection("AIAssistant:KnowledgeImport:SharePointTrainingMaterial");
        var options = section.Get<AIAssistantKnowledgeImportOptions>() ?? new AIAssistantKnowledgeImportOptions();
        if (string.IsNullOrWhiteSpace(options.SiteId))
        {
            var appConfig = new AppConfiguration(_configuration);
            options = options with
            {
                SiteId = appConfig.EnvironmentType is "DEV" or "TEST"
                    ? appConfig.DevSharepointIdentifier
                    : "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e"
            };
        }
        return options;
    }

    private static void ValidateOptions(AIAssistantKnowledgeImportOptions options)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(options.SiteId);
        ArgumentException.ThrowIfNullOrWhiteSpace(options.DriveName);
        ArgumentException.ThrowIfNullOrWhiteSpace(options.RootFolderPath);
    }

    private async Task<List<DriveItem>> LoadCandidateFilesAsync(AIAssistantKnowledgeImportOptions options, CancellationToken cancellationToken)
    {
        var rootFolder = await ResolveRootFolderAsync(options, cancellationToken);

        _logger.LogInformation(
            "AI knowledge import resolved SharePoint root folder. DriveId={DriveId}, ItemId={ItemId}, DisplayName={DisplayName}",
            rootFolder.DriveId,
            rootFolder.ItemId,
            rootFolder.DisplayName);

        var results = new List<DriveItem>();

        if (options.IncludeFolderNames.Count == 0)
        {
            await AddFilesRecursivelyAsync(rootFolder.DriveId, rootFolder.ItemId, results, cancellationToken);
            return results;
        }
        _logger.LogInformation(
            "Attempting to enumerate children. DriveId={DriveId}, ItemId={ItemId}",
            rootFolder.DriveId,
            rootFolder.ItemId);

        var rootChildren = await GetChildrenAsync(rootFolder.DriveId, rootFolder.ItemId, cancellationToken);
        var rootFolderChildren = rootChildren
            .Where(item => item.Folder is not null && !string.IsNullOrWhiteSpace(item.Id) && !string.IsNullOrWhiteSpace(item.Name))
            .ToList();

        foreach (var includeFolder in options.IncludeFolderNames)
        {
            var folder = rootFolderChildren.FirstOrDefault(item =>
                string.Equals(item.Name, includeFolder, StringComparison.OrdinalIgnoreCase));

            if (folder?.Id is null)
            {
                _logger.LogWarning(
                    "AI knowledge import include folder was not found under root folder. IncludeFolder={IncludeFolder}, RootFolder={RootFolder}",
                    includeFolder,
                    rootFolder.DisplayName);

                continue;
            }

            await AddFilesRecursivelyAsync(rootFolder.DriveId, folder.Id, results, cancellationToken);
        }

        return results;
    }

    private async Task<SharePointFolderReference> ResolveRootFolderAsync(
     AIAssistantKnowledgeImportOptions options,
     CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "AI Import Config: DriveId={DriveId}, SiteId={SiteId}, SitePath={SitePath}, RootFolderPath={RootFolderPath}",
            options.DriveId,
            options.SiteId,
            options.SitePath,
            options.RootFolderPath);
        ArgumentNullException.ThrowIfNull(options);

        var pathCandidates = BuildRootFolderPathCandidates(options.RootFolderPath);

        if (!string.IsNullOrWhiteSpace(options.DriveId))
        {
            foreach (var pathCandidate in pathCandidates)
            {
                try
                {
                    _logger.LogInformation(
                        "Attempting DriveId shortcut. DriveId={DriveId}",
                        options.DriveId);
                    var folder = await _graphClient
                        .Drives[options.DriveId]
                        .Root
                        .ItemWithPath(pathCandidate)
                        .GetAsync(cancellationToken: cancellationToken);

                    if (folder?.Id is not null && folder.Folder is not null)
                    {
                        return new SharePointFolderReference(
                            options.DriveId,
                            folder.Id,
                            pathCandidate);
                    }
                }
                catch (Microsoft.Graph.Models.ODataErrors.ODataError ex)
                    when (IsGraphNotFound(ex))
                {
                    _logger.LogDebug(
                        ex,
                        "AI knowledge import SharePoint path candidate was not found using configured DriveId. DriveId={DriveId}, Path={PathCandidate}",
                        options.DriveId,
                        pathCandidate);
                }
            }

            throw new InvalidOperationException(
                $"Configured SharePoint DriveId was found, but RootFolderPath '{options.RootFolderPath}' could not be resolved as a folder.");
        }

        if (!string.IsNullOrWhiteSpace(options.RootFolderSharingUrl))
        {
            var shareId = CreateGraphShareId(options.RootFolderSharingUrl);

            var sharedDriveItem = await _graphClient
                .Shares[shareId]
                .DriveItem
                .GetAsync(cancellationToken: cancellationToken);

            if (sharedDriveItem?.Id is null || sharedDriveItem.ParentReference?.DriveId is null)
            {
                throw new InvalidOperationException(
                    "The configured SharePoint training-material sharing URL was resolved, but Microsoft Graph did not return a drive item id and drive id.");
            }

            if (sharedDriveItem.Folder is null)
            {
                throw new InvalidOperationException(
                    $"The configured SharePoint training-material sharing URL points to '{sharedDriveItem.Name}', but it is not a folder.");
            }

            return new SharePointFolderReference(
                sharedDriveItem.ParentReference.DriveId,
                sharedDriveItem.Id,
                sharedDriveItem.Name ?? options.RootFolderPath);
        }

        var siteIdentifier = options.SiteId;

        if (!string.IsNullOrWhiteSpace(options.SitePath))
        {
            var site = await _graphClient
                .Sites[options.SitePath]
                .GetAsync(cancellationToken: cancellationToken);

            if (string.IsNullOrWhiteSpace(site?.Id))
            {
                throw new InvalidOperationException(
                    $"Microsoft Graph could not resolve SharePoint site path '{options.SitePath}'.");
            }

            siteIdentifier = site.Id;
        }

        if (string.IsNullOrWhiteSpace(siteIdentifier))
        {
            throw new InvalidOperationException(
                "SharePoint SiteId or SitePath must be configured for AI Assistant knowledge import.");
        }

        var drives = await _graphClient
            .Sites[siteIdentifier]
            .Drives
            .GetAsync(cancellationToken: cancellationToken);

        var availableDrives = drives?.Value ?? new List<Drive>();

        var drive = availableDrives.FirstOrDefault(d =>
                        string.Equals(d.Name, options.DriveName, StringComparison.OrdinalIgnoreCase))
                    ?? availableDrives.FirstOrDefault(d =>
                        string.Equals(d.Name, "Documents", StringComparison.OrdinalIgnoreCase))
                    ?? availableDrives.FirstOrDefault(d =>
                        string.Equals(d.Name, "Shared Documents", StringComparison.OrdinalIgnoreCase))
                    ?? availableDrives.FirstOrDefault();

        if (drive?.Id is null)
        {
            var driveNames = string.Join(
                ", ",
                availableDrives
                    .Select(d => d.Name)
                    .Where(name => !string.IsNullOrWhiteSpace(name)));

            throw new InvalidOperationException(
                $"No SharePoint document library could be resolved for site '{siteIdentifier}'. Requested DriveName='{options.DriveName}'. Available drives: {driveNames}");
        }

        foreach (var pathCandidate in pathCandidates)
        {
            try
            {
                var folder = await _graphClient
                    .Drives[drive.Id]
                    .Root
                    .ItemWithPath(pathCandidate)
                    .GetAsync(cancellationToken: cancellationToken);

                if (folder?.Id is not null && folder.Folder is not null)
                {
                    return new SharePointFolderReference(
                        drive.Id,
                        folder.Id,
                        pathCandidate);
                }
            }
            catch (Microsoft.Graph.Models.ODataErrors.ODataError ex)
                when (IsGraphNotFound(ex))
            {
                _logger.LogDebug(
                    ex,
                    "AI knowledge import SharePoint path candidate was not found. DriveName={DriveName}, DriveId={DriveId}, Path={PathCandidate}",
                    drive.Name,
                    drive.Id,
                    pathCandidate);
            }
        }

        throw new InvalidOperationException(
            $"SharePoint training-material folder was not found. SiteId='{siteIdentifier}', DriveName='{drive.Name}', DriveId='{drive.Id}', RootFolderPath='{options.RootFolderPath}'.");
    }

    private static IReadOnlyList<string> BuildRootFolderPathCandidates(string rootFolderPath)
    {
        var normalised = (rootFolderPath ?? string.Empty)
            .Replace('\\', '/')
            .Trim('/');

        var candidates = new List<string>();

        if (!string.IsNullOrWhiteSpace(normalised))
        {
            candidates.Add(normalised);
        }

        // SharePoint URLs often include "Shared Documents", but Graph drive paths are relative to the library root.
        const string sharedDocumentsPrefix = "Shared Documents/";
        if (normalised.StartsWith(sharedDocumentsPrefix, StringComparison.OrdinalIgnoreCase))
        {
            candidates.Add(normalised[sharedDocumentsPrefix.Length..].Trim('/'));
        }

        // In some existing CymBuild URLs the channel folder has already been stripped.
        if (normalised.StartsWith("General/", StringComparison.OrdinalIgnoreCase))
        {
            candidates.Add(normalised["General/".Length..].Trim('/'));
        }

        return candidates
            .Where(candidate => !string.IsNullOrWhiteSpace(candidate))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private async Task<List<DriveItem>> GetChildrenAsync(
        string driveId,
        string folderItemId,
        CancellationToken cancellationToken)
    {
        var results = new List<DriveItem>();
        var page = await _graphClient
            .Drives[driveId]
            .Items[folderItemId]
            .Children
            .GetAsync(cancellationToken: cancellationToken);

        while (page?.Value is not null)
        {
            results.AddRange(page.Value);

            if (string.IsNullOrWhiteSpace(page.OdataNextLink))
            {
                break;
            }

            page = await _graphClient
                .Drives[driveId]
                .Items[folderItemId]
                .Children
                .WithUrl(page.OdataNextLink)
                .GetAsync(cancellationToken: cancellationToken);
        }

        return results;
    }

    private async Task AddFilesRecursivelyAsync(
        string driveId,
        string folderItemId,
        List<DriveItem> results,
        CancellationToken cancellationToken)
    {
        var children = await GetChildrenAsync(driveId, folderItemId, cancellationToken);

        foreach (var item in children)
        {
            if (item.Folder is not null && item.Id is not null)
            {
                await AddFilesRecursivelyAsync(driveId, item.Id, results, cancellationToken);
            }
            else if (item.File is not null)
            {
                results.Add(item);
            }
        }
    }

    private static string CreateGraphShareId(string sharingUrl)
    {
        var bytes = Encoding.UTF8.GetBytes(sharingUrl.Trim());
        var base64 = Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('/', '_')
            .Replace('+', '-');

        return $"u!{base64}";
    }

    private static bool IsGraphNotFound(Microsoft.Graph.Models.ODataErrors.ODataError ex)
    {
        return string.Equals(ex.Error?.Code, "itemNotFound", StringComparison.OrdinalIgnoreCase)
            || string.Equals(ex.Error?.Code, "ResourceNotFound", StringComparison.OrdinalIgnoreCase)
            || ex.ResponseStatusCode == 404;
    }

    private static IReadOnlyList<KnowledgeChunk> ChunkDocument(ExtractedKnowledgeDocument document, int maxChunkCharacters)
    {
        var normalised = Regex.Replace(document.ExtractedText, @"\r\n?", "\n").Trim();
        var paragraphs = normalised.Split("\n\n", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var chunks = new List<KnowledgeChunk>();
        var builder = new StringBuilder();
        var chunkNumber = 1;

        foreach (var paragraph in paragraphs)
        {
            if (builder.Length > 0 && builder.Length + paragraph.Length + 2 > maxChunkCharacters)
            {
                AddChunk(document, chunks, builder.ToString(), chunkNumber++);
                builder.Clear();
            }
            builder.AppendLine(paragraph);
            builder.AppendLine();
        }

        if (builder.Length > 0)
        {
            AddChunk(document, chunks, builder.ToString(), chunkNumber);
        }

        return chunks;
    }

    private static void AddChunk(ExtractedKnowledgeDocument document, List<KnowledgeChunk> chunks, string text, int chunkNumber)
    {
        var title = chunkNumber == 1 ? document.Title : $"{document.Title} - Part {chunkNumber}";
        var slug = CreateSlug($"sharepoint-{document.FolderPath}-{document.Title}-{chunkNumber}");
        var summary = text.Length <= 800 ? text.Trim() : text[..800].Trim() + "...";
        chunks.Add(new KnowledgeChunk(title, slug, summary, text.Trim()));
    }

    private static async Task UpsertKnowledgeItemAsync(
        SqlConnection connection,
        int userId,
        Guid guid,
        KnowledgeChunk chunk,
        ExtractedKnowledgeDocument document,
        bool publishImmediately,
        bool authoritative,
        CancellationToken cancellationToken)
    {
        await using var command = new SqlCommand("SAi.AssistantKnowledgeItemUpsert", connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 120
        };

        command.Parameters.Add(new SqlParameter("@Title", SqlDbType.NVarChar, 500) { Value = chunk.Title });
        command.Parameters.Add(new SqlParameter("@Slug", SqlDbType.NVarChar, 500) { Value = chunk.Slug });
        command.Parameters.Add(new SqlParameter("@KnowledgeCategoryGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value });
        command.Parameters.Add(new SqlParameter("@ContentTypeCode", SqlDbType.NVarChar, 30) { Value = "TRAINING" });
        command.Parameters.Add(new SqlParameter("@SourceTypeCode", SqlDbType.NVarChar, 30) { Value = "SHAREPOINT" });
        command.Parameters.Add(new SqlParameter("@StorageUrl", SqlDbType.NVarChar, 1000) { Value = document.SourceUrl });
        command.Parameters.Add(new SqlParameter("@PreviewUrl", SqlDbType.NVarChar, 1000) { Value = string.IsNullOrWhiteSpace(document.PreviewUrl) ? DBNull.Value : document.PreviewUrl });
        command.Parameters.Add(new SqlParameter("@Summary", SqlDbType.NVarChar, -1) { Value = $"{chunk.Summary}\n\n--- Extracted Text ---\n{chunk.Text}" });
        command.Parameters.Add(new SqlParameter("@IsAuthoritative", SqlDbType.Bit) { Value = authoritative });
        command.Parameters.Add(new SqlParameter("@IsPublished", SqlDbType.Bit) { Value = publishImmediately });
        command.Parameters.Add(new SqlParameter("@CreatedByUserId", SqlDbType.Int) { Value = userId });
        command.Parameters.Add(new SqlParameter("@UpdatedByUserId", SqlDbType.Int) { Value = userId });

        var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
        {
            Direction = ParameterDirection.InputOutput,
            Value = guid
        };
        command.Parameters.Add(guidParameter);

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static string CreateSlug(string value)
    {
        var lower = value.ToLowerInvariant();
        var slug = Regex.Replace(lower, @"[^a-z0-9]+", "-").Trim('-');
        return slug.Length <= 500 ? slug : slug[..500].Trim('-');
    }

    private static Guid CreateDeterministicGuid(string value)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(value));
        var bytes = hash.Take(16).ToArray();
        bytes[7] = (byte)((bytes[7] & 0x0F) | 0x50);
        bytes[8] = (byte)((bytes[8] & 0x3F) | 0x80);
        return new Guid(bytes);
    }
}
