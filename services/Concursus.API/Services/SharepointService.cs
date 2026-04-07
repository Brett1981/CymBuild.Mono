using Concursus.API.Classes;
using Concursus.API.Interfaces;
using Microsoft.Graph;
using Microsoft.Graph.Models;
using Microsoft.Kiota.Abstractions;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Concursus.API.Services
{
    public sealed class SharepointService : ISharepointService
    {
        private static readonly StringComparer FolderNameComparer = StringComparer.OrdinalIgnoreCase;

        private static readonly List<string> DefaultFireStructuralBuildingFolders =
        [
            "Emails (Incoming)",
            "Emails (Outgoing)"
        ];

        public SharepointDirectory GetFoldersForFireStructuralBuildingInJobs()
        {
            return new SharepointDirectory
            {
                FolderNames =
                [
                    "Fees",
                    "Correspondence",
                    ..DefaultFireStructuralBuildingFolders,
                    "Drawings",
                    "Photographs",
                    "Reports",
                    "Technical Documents"
                ],
                SubFoldersToCreate = new Dictionary<string, List<string>>(FolderNameComparer)
                {
                    ["Fees"] = ["Quotations"],
                    ["Fees/Quotations"] = ["POs"],
                    ["Correspondence"] = ["Contracts"]
                }
            };
        }

        public SharepointDirectory GetFoldersForFireStructuralBuildingInQuotes()
        {
            return new SharepointDirectory
            {
                FolderNames =
                [
                    "Fees",
                    ..DefaultFireStructuralBuildingFolders
                ],
                SubFoldersToCreate = new Dictionary<string, List<string>>(FolderNameComparer)
                {
                    ["Fees"] = ["Quotations"],
                    ["Fees/Quotations"] = ["POs"]
                }
            };
        }

        public SharepointDirectory GetFoldersForFireStructuralBuildingInEnquiry()
        {
            return new SharepointDirectory
            {
                FolderNames =
                [
                    "Correspondence",
                    ..DefaultFireStructuralBuildingFolders,
                    "Drawings",
                    "Technical Documents"
                ],
                SubFoldersToCreate = new Dictionary<string, List<string>>(FolderNameComparer)
                {
                    ["Fees"] = ["Quotations"],
                    ["Fees/Quotations"] = ["POs"]
                }
            };
        }

        public async Task EnsureFolderStructureExists(
            GraphServiceClient graphServiceClient,
            string siteId,
            string baseUrl,
            List<string> folderNames,
            Drive drive,
            DriveItem driveItem,
            string jobNumber,
            string QuoteNo = "",
            string QuoteURL = "",
            bool isEnquiry = false,
            Dictionary<string, List<string>>? subFoldersToCreate = null)
        {
            ArgumentNullException.ThrowIfNull(graphServiceClient);
            ArgumentNullException.ThrowIfNull(drive);
            ArgumentNullException.ThrowIfNull(driveItem);

            if (string.IsNullOrWhiteSpace(drive.Id))
            {
                throw new ArgumentException("Drive Id is required.", nameof(drive));
            }

            if (string.IsNullOrWhiteSpace(driveItem.Id))
            {
                throw new ArgumentException("DriveItem Id is required.", nameof(driveItem));
            }

            var requiredTopLevelFolders = (folderNames ?? [])
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct(FolderNameComparer)
                .ToList();

            var requiredSubFolders = CloneFolderRules(subFoldersToCreate);

            try
            {
                var rootChildren = await GetChildrenAsync(graphServiceClient, drive.Id, driveItem.Id).ConfigureAwait(false);

                var rootFolderLookup = rootChildren
                    .Where(IsFolder)
                    .GroupBy(x => x.Name ?? string.Empty, FolderNameComparer)
                    .ToDictionary(g => g.Key, g => g.First(), FolderNameComparer);

                var rootFileLookup = rootChildren
                    .Where(x => !IsFolder(x))
                    .GroupBy(x => x.Name ?? string.Empty, FolderNameComparer)
                    .ToDictionary(g => g.Key, g => g.First(), FolderNameComparer);

                foreach (var folderName in requiredTopLevelFolders)
                {
                    var topLevelFolder = await EnsureFolderExistsAsync(
                        graphServiceClient,
                        siteId,
                        drive,
                        driveItem.Id!,
                        rootFolderLookup,
                        folderName)
                        .ConfigureAwait(false);

                    await EnsureConfiguredChildFoldersRecursiveAsync(
                        graphServiceClient,
                        siteId,
                        drive,
                        topLevelFolder,
                        folderName,
                        requiredSubFolders)
                        .ConfigureAwait(false);
                }

                await EnsureJobMarkerFileExistsAsync(
                    graphServiceClient,
                    drive,
                    driveItem.Id!,
                    rootFileLookup,
                    jobNumber)
                    .ConfigureAwait(false);

                await EnsureShortcutFileExistsAsync(
                    graphServiceClient,
                    drive,
                    driveItem.Id!,
                    QuoteNo,
                    QuoteURL,
                    isEnquiry)
                    .ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(
                    $"Error ensuring SharePoint folder structure for drive '{drive.Id}', item '{driveItem.Id}', baseUrl '{baseUrl}': {ex}");
                throw;
            }
        }

        private static Dictionary<string, List<string>> CloneFolderRules(Dictionary<string, List<string>>? source)
        {
            var result = new Dictionary<string, List<string>>(FolderNameComparer);

            if (source == null || source.Count == 0)
            {
                return result;
            }

            foreach (var pair in source)
            {
                var key = NormaliseFolderRuleKey(pair.Key);

                if (string.IsNullOrWhiteSpace(key))
                {
                    continue;
                }

                var values = (pair.Value ?? [])
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Distinct(FolderNameComparer)
                    .ToList();

                result[key] = values;
            }

            return result;
        }

        private static string NormaliseFolderRuleKey(string? key)
        {
            if (string.IsNullOrWhiteSpace(key))
            {
                return string.Empty;
            }

            var parts = key
                .Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Where(x => !string.IsNullOrWhiteSpace(x));

            return string.Join("/", parts);
        }

        private static bool IsFolder(DriveItem item)
        {
            return item.Folder != null;
        }

        private static async Task<List<DriveItem>> GetChildrenAsync(
            GraphServiceClient graphServiceClient,
            string driveId,
            string parentItemId)
        {
            var results = new List<DriveItem>();

            var response = await graphServiceClient
                .Drives[driveId]
                .Items[parentItemId]
                .Children
                .GetAsync()
                .ConfigureAwait(false);

            if (response?.Value != null)
            {
                results.AddRange(response.Value);
            }

            var nextLink = response?.OdataNextLink;

            while (!string.IsNullOrWhiteSpace(nextLink))
            {
                var nextRequest = new RequestInformation
                {
                    HttpMethod = Method.GET,
                    UrlTemplate = nextLink
                };

                var nextResponse = await graphServiceClient.RequestAdapter
                    .SendAsync<DriveItemCollectionResponse>(
                        nextRequest,
                        DriveItemCollectionResponse.CreateFromDiscriminatorValue)
                    .ConfigureAwait(false);

                if (nextResponse?.Value != null)
                {
                    results.AddRange(nextResponse.Value);
                }

                nextLink = nextResponse?.OdataNextLink;
            }

            return results;
        }

        private static async Task<DriveItem> EnsureFolderExistsAsync(
            GraphServiceClient graphServiceClient,
            string siteId,
            Drive drive,
            string parentItemId,
            Dictionary<string, DriveItem> existingFolders,
            string folderName)
        {
            if (existingFolders.TryGetValue(folderName, out var existingFolder) &&
                existingFolder != null &&
                !string.IsNullOrWhiteSpace(existingFolder.Id))
            {
                return existingFolder;
            }

            var requestBody = new DriveItem
            {
                Name = folderName,
                Folder = new Folder(),
                AdditionalData = new Dictionary<string, object>
                {
                    ["@microsoft.graph.conflictBehavior"] = "rename"
                }
            };

            var createdFolder = await graphServiceClient
                .Drives[drive.Id]
                .Items[parentItemId]
                .Children
                .PostAsync(requestBody)
                .ConfigureAwait(false);

            if (createdFolder == null || string.IsNullOrWhiteSpace(createdFolder.Id))
            {
                throw new InvalidOperationException(
                    $"SharePoint folder '{folderName}' could not be created under parent '{parentItemId}'.");
            }

            await TryPatchRecordTitleAsync(graphServiceClient, siteId, drive, createdFolder, folderName).ConfigureAwait(false);

            existingFolders[folderName] = createdFolder;

            Console.WriteLine($"Created SharePoint folder '{folderName}'.");
            return createdFolder;
        }

        private static async Task TryPatchRecordTitleAsync(
            GraphServiceClient graphServiceClient,
            string siteId,
            Drive drive,
            DriveItem folderItem,
            string recordTitle)
        {
            try
            {
                if (drive.List == null ||
                    string.IsNullOrWhiteSpace(drive.List.Id) ||
                    folderItem.ListItem == null ||
                    string.IsNullOrWhiteSpace(folderItem.ListItem.Id))
                {
                    return;
                }

                var patchRequestBody = new ListItem
                {
                    Fields = new FieldValueSet
                    {
                        AdditionalData = new Dictionary<string, object>
                        {
                            ["RecordTitle"] = recordTitle
                        }
                    }
                };

                await graphServiceClient
                    .Sites[siteId]
                    .Lists[drive.List.Id]
                    .Items[folderItem.ListItem.Id]
                    .PatchAsync(patchRequestBody)
                    .ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(
                    $"Failed to patch RecordTitle for SharePoint folder '{folderItem.Name}': {ex.Message}");
            }
        }

        private static async Task EnsureConfiguredChildFoldersRecursiveAsync(
            GraphServiceClient graphServiceClient,
            string siteId,
            Drive drive,
            DriveItem parentFolder,
            string parentRelativePath,
            Dictionary<string, List<string>> folderRules)
        {
            var normalisedParentPath = NormaliseFolderRuleKey(parentRelativePath);

            if (!folderRules.TryGetValue(normalisedParentPath, out var childFolderNames) ||
                childFolderNames == null ||
                childFolderNames.Count == 0)
            {
                return;
            }

            var childItems = await GetChildrenAsync(graphServiceClient, drive.Id!, parentFolder.Id!).ConfigureAwait(false);

            var existingChildFolders = childItems
                .Where(IsFolder)
                .GroupBy(x => x.Name ?? string.Empty, FolderNameComparer)
                .ToDictionary(g => g.Key, g => g.First(), FolderNameComparer);

            foreach (var childFolderName in childFolderNames.Distinct(FolderNameComparer))
            {
                var childFolder = await EnsureFolderExistsAsync(
                    graphServiceClient,
                    siteId,
                    drive,
                    parentFolder.Id!,
                    existingChildFolders,
                    childFolderName)
                    .ConfigureAwait(false);

                var childRelativePath = $"{normalisedParentPath}/{childFolderName}";

                await EnsureConfiguredChildFoldersRecursiveAsync(
                    graphServiceClient,
                    siteId,
                    drive,
                    childFolder,
                    childRelativePath,
                    folderRules)
                    .ConfigureAwait(false);
            }
        }

        private static async Task EnsureJobMarkerFileExistsAsync(
            GraphServiceClient graphServiceClient,
            Drive drive,
            string parentItemId,
            Dictionary<string, DriveItem> existingFiles,
            string jobNumber)
        {
            var sanitizedJobNumber = Functions.SanitizeFileName(jobNumber)?.Trim() ?? string.Empty;

            if (string.IsNullOrWhiteSpace(sanitizedJobNumber))
            {
                return;
            }

            var markerFileName = $"__{sanitizedJobNumber}";

            if (existingFiles.ContainsKey(markerFileName))
            {
                Console.WriteLine($"SharePoint marker file '{markerFileName}' already exists.");
                return;
            }

            var fileRequestBody = new DriveItem
            {
                Name = markerFileName,
                File = new FileObject(),
                AdditionalData = new Dictionary<string, object>
                {
                    ["@microsoft.graph.conflictBehavior"] = "rename"
                }
            };

            var createdFile = await graphServiceClient
                .Drives[drive.Id]
                .Items[parentItemId]
                .Children
                .PostAsync(fileRequestBody)
                .ConfigureAwait(false);

            if (createdFile == null)
            {
                throw new InvalidOperationException(
                    $"SharePoint marker file '{markerFileName}' could not be created.");
            }

            Console.WriteLine($"Created SharePoint marker file '{markerFileName}'.");
        }

        private static async Task EnsureShortcutFileExistsAsync(
            GraphServiceClient graphServiceClient,
            Drive drive,
            string parentItemId,
            string quoteNo,
            string quoteUrl,
            bool isEnquiry)
        {
            if (string.IsNullOrWhiteSpace(quoteNo) || string.IsNullOrWhiteSpace(quoteUrl))
            {
                return;
            }

            var sanitizedQuoteNumber = Functions.SanitizeFileName(quoteNo)?.Trim() ?? string.Empty;

            if (string.IsNullOrWhiteSpace(sanitizedQuoteNumber))
            {
                return;
            }

            var fileName = isEnquiry
                ? $"Enquiry Link - {sanitizedQuoteNumber}.url"
                : $"Quote Link - {sanitizedQuoteNumber}.url";

            var fileCheckCollection = await graphServiceClient
                .Drives[drive.Id]
                .Items[parentItemId]
                .Children
                .GetAsync(requestConfig =>
                {
                    requestConfig.QueryParameters.Filter = $"name eq '{EscapeODataString(fileName)}'";
                })
                .ConfigureAwait(false);

            var existingFile = fileCheckCollection?.Value?.FirstOrDefault();

            if (existingFile != null)
            {
                Console.WriteLine($"SharePoint shortcut file '{fileName}' already exists.");
                return;
            }

            var contentBytes = Encoding.UTF8.GetBytes($"[InternetShortcut]\r\nURL={quoteUrl}");

            using var memoryStream = new MemoryStream(contentBytes);

            var createdFile = await graphServiceClient
                .Drives[drive.Id]
                .Items[parentItemId]
                .ItemWithPath(fileName)
                .Content
                .PutAsync(memoryStream)
                .ConfigureAwait(false);

            if (createdFile == null)
            {
                throw new InvalidOperationException(
                    $"SharePoint shortcut file '{fileName}' could not be created.");
            }

            Console.WriteLine($"Created SharePoint shortcut file '{fileName}'.");
        }

        private static string EscapeODataString(string input)
        {
            return (input ?? string.Empty).Replace("'", "''", StringComparison.Ordinal);
        }
    }

    public sealed class SharepointDirectory
    {
        public List<string> FolderNames { get; set; } = [];

        public Dictionary<string, List<string>> SubFoldersToCreate { get; set; } =
            new(StringComparer.OrdinalIgnoreCase);
    }
}