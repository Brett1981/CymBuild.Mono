using Concursus.API.Components;
using Concursus.API.Core;
using Concursus.Common.Shared.Helpers;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Drawing.Wordprocessing;

//using DocumentFormat.OpenXml.Drawing;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using Microsoft.Graph;
using OfficeOpenXml;
using System.Data;
using static Org.BouncyCastle.Math.EC.ECCurve;

namespace Concursus.API.Classes
{
    public class WordDocumentService
    {
        #region Private Fields

        private const string SiteId = "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e";

        // Define supported photo file extensions using HashSet for faster lookups
        private static readonly HashSet<string> photoFileExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".png", ".gif", ".tiff", ".tif",
        ".bmp", ".svg", ".webp", ".heic", ".heif",
        ".raw", ".cr2", ".nef", ".arw", ".dng",
        ".ico", ".jfif"
    };

        private static GraphServiceClient graphServiceClient;
        private IConfiguration _config;

        private List<string> processedIncludes = new List<string>();

        #endregion Private Fields

        #region Public Constructors

        public WordDocumentService(GraphServiceClient _graphServiceClient)
        {
            graphServiceClient = _graphServiceClient;
        }

        #endregion Public Constructors

        #region Public Methods

        public static async Task<SharepointDocumentsGetResponse> SharepointDocumentsGet(
        SharepointDocumentsGetRequest request, Concursus.EF.Core efCore, IConfiguration _config, Services.ServiceBase _serviceBase)
        {
            try
            {
                // Initialize SharePoint instance
                var sharePoint = new SharePoint(_config);

                // Retrieve data object and entity type
                var dataObject = await efCore.DataObjectGet(
                                    Functions.ParseAndReturnEmptyGuidIfInvalid(request.RecordGuid), Guid.Empty, Functions.ParseAndReturnEmptyGuidIfInvalid(request.LinkedEntityTypeGuid), false);
                var entityType = await efCore.GetEntityType(Functions.ParseAndReturnEmptyGuidIfInvalid(request.LinkedEntityTypeGuid), false, false);

                // Get merge data based on the retrieved data object and entity type
                var mergeData = Functions.GetMergeData(dataObject, entityType);

                // Retrieve SharePoint information for the specified record
                var point = new SharePoint(_config);
                var dataObjectSharePoint = await efCore.DataObjectGet(
                    Functions.ParseAndReturnEmptyGuidIfInvalid(request.RecordGuid), Functions.ParseAndReturnEmptyGuidIfInvalid(Guid.Empty.ToString()), Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid), false);
                var dataObjectUpdateResponse = await point.GetSharePointLocation(
                Functions.ParseAndReturnEmptyGuidIfInvalid(request.EntityTypeGuid).ToString(), dataObjectSharePoint, efCore, _serviceBase, null);

                dataObject = dataObjectUpdateResponse.DataObject;
                // Initialize response object
                var sharepointDocumentsGetResponse = new SharepointDocumentsGetResponse();

                //OE: The dataobject gets upserted in here.

                var UserId = _serviceBase._entityFramework.UserId;
                sharepointDocumentsGetResponse = await sharePoint.GetSharePointDocumentsWithMergeDocument(_serviceBase._entityFramework, request.RecordGuid,
                    request.SiteId, request.FilenameTemplate, dataObject.SharePointUrl, request.DocumentId, mergeData,
                    request.MergeDocument, request.OutputType, UserId, true);

                //OE - Added on 25/07/24
                sharePoint.Dispose();

                return sharepointDocumentsGetResponse;
            }
            catch (Exception ex)
            {
                // Log exception and rethrow
                _serviceBase.logger.LogException(ex);
                return new SharepointDocumentsGetResponse() { ErrorReturned = ex.Message };
                // throw;
            }
        }

        public async Task<int> CheckForPhotosAsync(string sharePointUrl)
        {
            try
            {
                if (string.IsNullOrEmpty(sharePointUrl))
                {
                    Console.Error.WriteLine("SharePoint URL is required.");
                    return 0;
                }
                var SiteId = "";
                var _AppConfig = new AppConfiguration(_config);
                switch (_AppConfig.EnvironmentType)
                {
                    case "DEV":
                        SiteId = _AppConfig.DevSharepointIdentifier;
                        break;

                    case "TEST":
                        SiteId = _AppConfig.DevSharepointIdentifier;
                        break;

                    default:
                        SiteId = "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e";
                        break;
                }

                var result = Functions.ExtractLastFourSegmentsFromUrl(sharePointUrl);
                var parentFolder = result.Item1;
                var mainFolder = result.Item2;
                var subfolder = result.Item3;
                var subsubfolder = result.Item4;

                // Construct the relative path without including the parentFolder twice
                var relativePath = $"{mainFolder}/{subfolder}/{subsubfolder}";

                Console.WriteLine($"Relative Path: {relativePath}");
                // Get the SharePoint drives
                var drives = await graphServiceClient.Sites[SiteId].Drives.GetAsync();

                // Assume the drive ID is the one associated with the first drive
                var driveItem = drives.Value.FirstOrDefault(d => d.Name == parentFolder);
                Console.WriteLine($"Drive ID: {driveItem?.Id}");

                if (driveItem != null)
                {
                    // Fetch folder contents
                    var folderContents = await graphServiceClient
                        .Drives[driveItem.Id]
                        .Root
                        .ItemWithPath($"{relativePath}")
                        .Children
                        .GetAsync();

                    // Check if folderContents or Value is null
                    if (folderContents?.Value == null)
                    {
                        return 0; // Return 0 if there are no items or the folder couldn't be accessed
                    }

                    // Count the items with photo file extensions, ensuring each item is not null
                    var photoFileCount = folderContents.Value
                        .Count(item => item != null && photoFileExtensions.Contains(Path.GetExtension(item?.Name ?? string.Empty)));

                    return photoFileCount;
                }
                else
                {
                    Console.WriteLine($"Drive not found for parent folder: {parentFolder}");
                    return 0;
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error checking for photos at {sharePointUrl}: {ex.Message}");
                throw;
            }
        }

        public async Task<SharepointDocumentsGetResponse> DownloadAndModifyDocumentWithMergeDocument(
                    EF.Core efCore,
    string recordGuid,
    string siteId,
    string? driveId,
    string filenameTemplate,
    string sharePointUrl,
    string documentId,
    List<Dictionary<string, string>> mergeData,
    IConfiguration config,
    MergeDocument mergeDocument,
    string outputType = "Word",
    int userId = -1,
    bool isIncludedDocument = false,
    Services.ServiceBase serviceBase = null)
        {
            try
            {
                _config = config;
                // Step 1: Download the main document content
                using (var documentStream = await DownloadDocumentContent(driveId, documentId))
                {
                    byte[] documentContent;
                    using (var memoryStream = new MemoryStream())
                    {
                        await documentStream.CopyToAsync(memoryStream);
                        documentContent = memoryStream.ToArray();
                    }

                    Console.WriteLine("[INFO] Processing all includes before modifying the main document.");

                    // Step 2: Process Includes First
                    var includeMergeItems = mergeDocument.Items.Where(m => m.MergeDocumentItemType == "Includes").ToList();
                    if (includeMergeItems.Count > 0)
                    {
                        documentContent = await ProcessIncludesRecursively(
                            siteId,
                            driveId,
                            sharePointUrl,
                            filenameTemplate,
                            recordGuid,
                            documentContent,
                            includeMergeItems,
                            new Dictionary<string, List<Dictionary<string, string>>>(),
                            new Dictionary<string, List<Dictionary<string, string>>>(),
                            config,
                            efCore,
                            documentContent,
                            userId
                        );

                        Console.WriteLine("[SUCCESS] All include documents processed successfully.");
                    }

                    // Step 3: Save and Reload Main Document
                    documentContent = await ReloadMainDocument(documentContent);
                    Console.WriteLine("[INFO] Main document reloaded after includes processing.");

                    // Step 4: Process Table Content Controls
                    var tableMergeItems = mergeDocument.Items.Where(m => m.MergeDocumentItemType == "Data Table").ToList();
                    if (tableMergeItems.Any())
                    {
                        using (var inputStream = new MemoryStream())
                        {
                            inputStream.Write(documentContent, 0, documentContent.Length);
                            inputStream.Position = 0;

                            using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(inputStream, true))
                            {
                                var mainPart = wordDoc.MainDocumentPart;
                                if (mainPart == null) throw new Exception("[ERROR] MainDocumentPart is missing.");
                                Console.WriteLine($"[INFO] Processing table content controls in the main document. with RECORD GUID: {recordGuid}");
                                var tableDataDict = await GenerateRowDataByBookmarkAsync(tableMergeItems, efCore, recordGuid);

                                foreach (var tableItem in tableMergeItems)
                                {
                                    if (tableDataDict.TryGetValue(tableItem.BookmarkName, out var tableDataList))
                                    {
                                        List<List<string>> tableData = tableDataList
                                        .Select(row => row.Values.ToList()) // ❌ Converts Dictionary to List<List<string>> (incorrect format)
                                        .ToList();

                                        ReplaceContentControlWithTable(mainPart, tableItem.BookmarkName, tableDataList); // ✅ Directly pass List<Dictionary<string, string>>
                                    }
                                    else
                                    {
                                        Console.WriteLine($"[ERROR] No table data found for '{tableItem.BookmarkName}'.");
                                    }
                                }

                                mainPart.Document.Save();
                            }

                            documentContent = inputStream.ToArray();
                        }
                    }

                    // Step 5: Process Image Tags
                    var imageMergeItems = mergeDocument.Items.Where(m => m.MergeDocumentItemType == "Image Table").ToList();
                    if (imageMergeItems.Any())
                    {
                        using (var inputStream = new MemoryStream())
                        {
                            inputStream.Write(documentContent, 0, documentContent.Length);
                            inputStream.Position = 0;

                            using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(inputStream, true))
                            {
                                var mainPart = wordDoc.MainDocumentPart;
                                if (mainPart == null) throw new Exception("[ERROR] MainDocumentPart is missing.");
                                Console.WriteLine($"[INFO] Processing table content controls in the main document. with RECORD GUID: {recordGuid}");
                                var imageDataDict = await GenerateImageRowDataByTagAsync(imageMergeItems, sharePointUrl, efCore, recordGuid);
                                foreach (var imageItem in imageMergeItems)
                                {
                                    if (imageDataDict.TryGetValue(imageItem.BookmarkName, out var imageDataList))
                                    {
                                        InsertImagesAtTags(imageDataDict, mainPart, sharePointUrl);
                                    }
                                    else
                                    {
                                        Console.WriteLine($"[ERROR] No table data found for '{imageItem.BookmarkName}'.");
                                    }
                                }
                            }
                            documentContent = inputStream.ToArray();
                        }

                        Console.WriteLine("[SUCCESS] Image bookmarks replaced in main document.");
                    }

                    // Step 6: Process Merge Fields
                    Console.WriteLine("[INFO] Replacing merge fields in the final document.");
                    documentContent = await ProcessMergeFields(documentContent, mergeData);
                    Console.WriteLine("[SUCCESS] Merge fields replaced in main document.");

                    // Step 7: Validate `documentContent` Before Upload
                    if (documentContent == null || documentContent.Length == 0)
                    {
                        Console.WriteLine("[ERROR] Document content is empty or null before upload.");
                        throw new Exception("Document content is null or empty before uploading.");
                    }

                    // Step 8: Upload Final Document to SharePoint
                    var uploadResponse = await UploadModifiedDocument(siteId, filenameTemplate, sharePointUrl, documentId, new MemoryStream(documentContent), config, "Activities", outputType);

                    // Validate Upload Response
                    if (uploadResponse == null)
                    {
                        Console.WriteLine("[ERROR] UploadModifiedDocument returned null.");
                        throw new Exception("UploadModifiedDocument returned null.");
                    }

                    Console.WriteLine("[SUCCESS] Final document uploaded successfully.");
                    return uploadResponse;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ERROR] An error occurred in DownloadAndModifyDocumentWithMergeDocument: {ex.Message}");
                throw;
            }
        }

        public async Task<SharepointDocumentsGetResponse> DownloadDriveItem(string parentDriveId, string driveItemId)
        {
            try
            {
                var driveItemInfo = await graphServiceClient.Drives[parentDriveId].Items[driveItemId].GetAsync();
                if (driveItemInfo != null && driveItemInfo.AdditionalData.TryGetValue("@microsoft.graph.downloadUrl", out var downloadUrl))
                {
                    using var httpClient = new HttpClient();
                    var response = await httpClient.GetAsync(downloadUrl.ToString());

                    if (response.IsSuccessStatusCode)
                    {
                        return new SharepointDocumentsGetResponse
                        {
                            DriveItem = Converters.ConvertMicrosoftGraphDriveItemToCoreDriveItem(driveItemInfo, parentDriveId),
                            DownloadUrl = downloadUrl.ToString(),
                        };
                    }

                    throw new Exception($"Request failed with status code {response.StatusCode}. Reason: {response.ReasonPhrase}");
                }

                throw new Exception("Download URL not available.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
                return new SharepointDocumentsGetResponse();
            }
        }

        public async Task<Dictionary<string, byte[]>> DownloadImagesFromSharePointAsync(string sharePointUrl)
        {
            try
            {
                if (string.IsNullOrEmpty(sharePointUrl))
                {
                    Console.Error.WriteLine("SharePoint URL is required.");
                    return new Dictionary<string, byte[]>(); // Return empty dictionary
                }

                var SiteId = "";
                var _AppConfig = new AppConfiguration(_config);
                switch (_AppConfig.EnvironmentType)
                {
                    case "DEV":
                    case "TEST":
                        SiteId = _AppConfig.DevSharepointIdentifier;
                        break;

                    default:
                        SiteId = "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e";
                        break;
                }

                var result = Functions.ExtractLastFourSegmentsFromUrl(sharePointUrl);
                var parentFolder = result.Item1;
                var mainFolder = result.Item2;
                var subfolder = result.Item3;
                var subsubfolder = result.Item4;

                // Construct the relative path without including the parentFolder twice
                var relativePath = $"{mainFolder}/{subfolder}/{subsubfolder}";

                Console.WriteLine($"Relative Path: {relativePath}");

                // Get the SharePoint drives
                var drives = await graphServiceClient.Sites[SiteId].Drives.GetAsync();
                var driveItem = drives.Value.FirstOrDefault(d => d.Name == parentFolder);

                if (driveItem == null)
                {
                    Console.WriteLine($"[ERROR] Drive not found for parent folder: {parentFolder}");
                    return new Dictionary<string, byte[]>(); // Return empty if drive not found
                }

                // Fetch folder contents
                var folderContents = await graphServiceClient
                    .Drives[driveItem.Id]
                    .Root
                    .ItemWithPath($"{relativePath}")
                    .Children
                    .GetAsync();

                if (folderContents?.Value == null)
                {
                    Console.WriteLine("[WARNING] No images found in the specified SharePoint folder.");
                    return new Dictionary<string, byte[]>(); // Return empty if no images found
                }

                // ✅ Dictionary to store file names and image data
                var imageDictionary = new Dictionary<string, byte[]>();

                foreach (var item in folderContents.Value)
                {
                    if (item != null && photoFileExtensions.Contains(Path.GetExtension(item?.Name ?? string.Empty)))
                    {
                        try
                        {
                            var fileStream = await graphServiceClient
                                .Drives[driveItem.Id]
                                .Items[item.Id]
                                .Content
                                .GetAsync();

                            using (MemoryStream ms = new MemoryStream())
                            {
                                await fileStream.CopyToAsync(ms);
                                imageDictionary[item.Name] = ms.ToArray();
                            }

                            Console.WriteLine($"[INFO] Successfully downloaded image: {item.Name}");
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"[ERROR] Failed to download image '{item.Name}': {ex.Message}");
                        }
                    }
                }

                return imageDictionary;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[ERROR] Error downloading images from SharePoint: {ex.Message}");
                return new Dictionary<string, byte[]>(); // Return empty in case of failure
            }
        }

        public MergeDocument GenerateDocumentAsync(MenuItem menuItem, string recordGuid)
        {
            try
            {
                var mergeDocument = new MergeDocument
                {
                    Name = menuItem.Text ?? "",
                    FilenameTemplate = menuItem.FilenameTemplate ?? "",
                    DriveId = menuItem.DriveId ?? "",
                    DocumentId = menuItem.DocumentId ?? "",
                    EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(menuItem.EntityTypeGuid).ToString(),
                    LinkedEntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(menuItem.LinkedEntityTypeGuid).ToString(),
                    Guid = Functions.ParseAndReturnEmptyGuidIfInvalid(menuItem.DocumentGuid).ToString(),
                    RecordGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(recordGuid).ToString(),
                    ParentRecordGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(menuItem.Guid).ToString()
                };

                // Populate Items using AddRange
                var items = menuItem.MergeDocumentItems;
                mergeDocument.Items.AddRange(items);

                return mergeDocument;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Unable to generate Included Document {menuItem.Text}, Error received: {ex.Message}");
                return new MergeDocument();
            }
        }

        public async Task<Dictionary<string, List<List<string>>>> GenerateImageRowDataByTagAsync(
            List<MergeDocumentItem> imageMergeItems, string sharePointUrl, EF.Core efCore, string recordGuid)
        {
            var imageTableData = new Dictionary<string, List<List<string>>>();

            foreach (var imageItem in imageMergeItems)
            {
                // Ensure entry exists for the table
                if (!imageTableData.ContainsKey(imageItem.BookmarkName))
                {
                    imageTableData[imageItem.BookmarkName] = new List<List<string>>();
                }

                int numColumns = imageItem.ImageColumns > 0 ? imageItem.ImageColumns : 1; // Default to 1 column if zero
                var imagePaths = new List<string>();

                // Get image paths from SharePoint
                string folderPath = $"{sharePointUrl}/{imageItem.SubFolderPath}";
                //https://environmentalscientifics.sharepoint.com/sites/ConcursusSystem/TestSite/6150/Activities
                var folders = await GetSubfoldersFromUrl(folderPath);

                //List Folders found
                Console.WriteLine($"[INFO] Found {folders.Count} Sub folders for '{imageItem.BookmarkName}'.");

                if (folders.Count == 0)
                {
                    Console.WriteLine($"[WARNING] No Sub folders found for '{imageItem.BookmarkName}'. Skipping...");
                    continue;
                }

                for (int i = 0; i < folders.Count; i++)
                {
                    imagePaths.Add($"{folderPath}/image_{i + 1}.jpg"); // Placeholder for SharePoint images
                }

                // Organize images into rows based on column count
                for (int i = 0; i < imagePaths.Count; i += numColumns)
                {
                    var row = new List<string>();
                    for (int j = 0; j < numColumns; j++)
                    {
                        row.Add(i + j < imagePaths.Count ? imagePaths[i + j] : ""); // Empty slot if not enough images
                    }
                    imageTableData[imageItem.BookmarkName].Add(row);
                }
            }

            return imageTableData;
        }

        public async Task<List<string>> GetSubfoldersFromUrl(string folderUrl)
        {
            var subfolders = new List<string>();

            try
            {
                // 1. Parse the complete URL to get drive-relative path
                var uri = new Uri(folderUrl);
                var pathSegments = uri.AbsolutePath.Split(new[] { '/' }, StringSplitOptions.RemoveEmptyEntries).ToList();

                // 2. Extract site-relative components (assuming standard SharePoint URL structure)
                var siteRootIndex = pathSegments.IndexOf("sites") + 2;
                var documentLibraryIndex = siteRootIndex + 1;


                if (documentLibraryIndex >= pathSegments.Count)
                {
                    throw new ArgumentException("Invalid SharePoint folder URL structure");
                }

                // 3. Get site ID and drive name from URL components
                var sitePath = string.Join("/", pathSegments.Take(siteRootIndex + 1));
                var driveName = pathSegments[documentLibraryIndex];
                var relativePath = "/" + driveName + "/" + string.Join("/", pathSegments.Skip(documentLibraryIndex + 1));

                Console.WriteLine($"Site Path: {sitePath}");
                Console.WriteLine($"Drive Name: {driveName}");
                Console.WriteLine($"Relative Path: {relativePath}");

                // 4. Get the target drive (document library)
                var siteId = "";
                var _AppConfig = new AppConfiguration(_config);
                switch (_AppConfig.EnvironmentType)
                {
                    case "DEV":
                        siteId = _AppConfig.DevSharepointIdentifier;
                        break;

                    case "TEST":
                        siteId = _AppConfig.DevSharepointIdentifier;
                        break;

                    default:
                        siteId = "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e";
                        break;
                }
                
                // Get the SharePoint drives
                var drives = await graphServiceClient.Sites[SiteId].Drives.GetAsync();
                var driveItem = drives.Value.FirstOrDefault(d => d.Name == "TestSite");

                Console.WriteLine($"Site: {siteId}");
                Console.WriteLine($"DriveId: {driveItem.Id}");

                // 5. Get children using the correct API format
                var children = await graphServiceClient.Drives[driveItem.Id]
                    .Root
                    .ItemWithPath(relativePath)
                    .Children
                    .GetAsync();

                subfolders.AddRange(children.Value
                    .Where(item => item.Folder != null)
                    .Select(item => item.Name));
            }
            catch (ServiceException ex) when (ex.ResponseStatusCode == 404)
            {
                Console.WriteLine($"Folder not found: {folderUrl}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }

            return subfolders;
        }


        public Dictionary<string, List<Dictionary<string, string>>> GenerateRowDataByBookmark(IEnumerable<MergeDocumentItem> mergeItems)
        {
            var bookmarkTableData = new Dictionary<string, List<Dictionary<string, string>>>();

            foreach (var tableItem in mergeItems)
            {
                // Ensure the bookmark entry exists in the dictionary
                if (!bookmarkTableData.ContainsKey(tableItem.BookmarkName))
                {
                    bookmarkTableData[tableItem.BookmarkName] = new List<Dictionary<string, string>>();
                }

                // Generate the row data for this table item
                var itemRow = new Dictionary<string, string>
                {
                    { "ItemGuid", tableItem.Guid },
                    { "MergeDocumentItemType", tableItem.MergeDocumentItemType },
                    { "BookmarkName", tableItem.BookmarkName },
                    { "EntityType", tableItem.EntityType },
                    { "EntityTypeGuid", tableItem.EntityTypeGuid.ToString() },
                    { "LinkedEntityTypeGuid", tableItem.LinkedEntityTypeGuid.ToString() },
                    { "SubFolderPath", tableItem.SubFolderPath },
                    { "ImageColumns", tableItem.ImageColumns.ToString() },
                    { "RowStatus", tableItem.RowStatus },
                    { "RowVersion", tableItem.RowVersion }
                };

                // Add row data for includes
                foreach (var include in tableItem.Includes)
                {
                    var includeRow = new Dictionary<string, string>
                    {
                        { "IncludeGuid", include.Guid },
                        { "SortOrder", include.SortOrder.ToString() },
                        { "SourceDocumentEntityProperty", include.SourceDocumentEntityProperty },
                        { "SourceSharePointItemEntityProperty", include.SourceSharepointItemEntityProperty },
                        { "IncludedMergeDocument", include.IncludedMergeDocument },
                        { "MergeDocumentItemGuid", include.MergeDocumentItemGuid },
                        { "RowStatus", include.RowStatus },
                        { "RowVersion", include.RowVersion }
                    };

                    // Add include row data to the same bookmark
                    bookmarkTableData[tableItem.BookmarkName].Add(includeRow);
                }

                // Add the row for the current table item itself
                bookmarkTableData[tableItem.BookmarkName].Add(itemRow);
            }

            return bookmarkTableData;
        }

        public async Task<Dictionary<string, List<Dictionary<string, string>>>> GenerateRowDataByBookmarkAsync(
            IEnumerable<MergeDocumentItem> mergeItems, EF.Core efCore, string recordGuid)
        {
            var bookmarkTableData = new Dictionary<string, List<Dictionary<string, string>>>();

            foreach (var tableItem in mergeItems)
            {
                if (!bookmarkTableData.ContainsKey(tableItem.BookmarkName))
                {
                    bookmarkTableData[tableItem.BookmarkName] = new List<Dictionary<string, string>>();
                }

                if (Functions.ParseAndReturnEmptyGuidIfInvalid(tableItem.LinkedEntityTypeGuid) != Guid.Empty)
                {
                    var entityType = await efCore.GetEntityType(
                        Functions.ParseAndReturnEmptyGuidIfInvalid(tableItem.LinkedEntityTypeGuid),
                        true, false, false, false, true
                    );

                    var defaultQuery = entityType.EntityQueries.FirstOrDefault(q => q.IsDefaultRead);

                    if (defaultQuery != null)
                    {
                        DataTable entityTypeRows = await efCore.GetEntityTypeRows(defaultQuery, recordGuid);

                        if (entityTypeRows != null && entityTypeRows.Rows.Count > 0)
                        {
                            // ✅ Sort columns based on SortOrder
                            var orderedProperties = entityType.EntityProperties
                                .Where(p => !p.IsHidden)
                                .OrderBy(p => p.SortOrder)
                                .ToList();
                            // ✅ Convert DataTable rows to Dictionary and populate with Labels as Headers
                            foreach (DataRow row in entityTypeRows.Rows)
                            {
                                var rowData = new Dictionary<string, string>();

                                foreach (var property in orderedProperties)
                                {
                                    if (entityTypeRows.Columns.Contains(property.Name))
                                    {
                                        string columnHeader = property.Label ?? property.Name; // Use Label or Name
                                        rowData[columnHeader] = row[property.Name].ToString();
                                    }
                                }

                                if (rowData.Any())
                                {
                                    bookmarkTableData[tableItem.BookmarkName].Add(rowData);
                                }
                            }
                        }
                    }
                }
            }

            return bookmarkTableData;
        }

        public async Task<SharepointDocumentsGetResponse> GetSharePointDocumentsAsync(MergeDocument mergeDocument, Concursus.EF.Core efCore,
            IConfiguration config, Services.ServiceBase _serviceBase, string OutputType = "Word")
        {
            var sharePointDocumentsGetRequest = new SharepointDocumentsGetRequest
            {
                SiteId = mergeDocument.DriveId,
                DocumentId = mergeDocument.DocumentId,
                DocumentGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.Guid).ToString(),
                RecordGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.RecordGuid).ToString(),
                ParentRecordGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.ParentRecordGuid).ToString(),
                EntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.EntityTypeGuid).ToString(),
                LinkedEntityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(mergeDocument.LinkedEntityTypeGuid).ToString(),
                FilenameTemplate = mergeDocument.FilenameTemplate,
                MergeDocument = mergeDocument, //Pass the entire MergeDocument no need to get getting it later
                OutputType = OutputType
            };

            var response = await SharepointDocumentsGet(sharePointDocumentsGetRequest, efCore, config, _serviceBase);

            return response;
        }

        public void InsertImagesAtBookmarks(
            Dictionary<string, List<Dictionary<string, string>>> bookmarkImageTableData,
            MainDocumentPart mainPart)
        {
            foreach (var bookmarkEntry in bookmarkImageTableData)
            {
                string bookmarkName = bookmarkEntry.Key;
                List<Dictionary<string, string>> imageRows = bookmarkEntry.Value;

                foreach (var row in imageRows)
                {
                    if (row.TryGetValue("ImageUrl", out string imageUrl) && !string.IsNullOrEmpty(imageUrl))
                    {
                        try
                        {
                            //if (row.TryGetValue("Source", out string source) && source == "SharePoint")
                            //{
                            //    // Insert images from SharePoint using the existing method
                            //    await InsertImagesFromSharePointAtBookmark(
                            //        imageUrl,
                            //        bookmarkName,
                            //        outputStream
                            //    );
                            //}
                            //else
                            //{
                            //    // Insert images without bookmarks
                            //    await InsertImagesWithoutBookmark(
                            //        imageUrl,
                            //        outputStream,
                            //        600  // Max width (example)
                            //    );
                            //}
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"Failed to insert image for bookmark {bookmarkName}: {ex.Message}");
                        }
                    }
                }

                // Save changes to the document
                mainPart.Document.Save();
            }
        }

        public async Task InsertImagesAtTags(
    Dictionary<string, List<List<string>>> imageDataDict,
    MainDocumentPart mainPart,
    string sharePointUrl)
        {
            BookmarkReplacer bookmarkReplacer = new BookmarkReplacer();
            foreach (var tag in imageDataDict.Keys)
            {
                var sdt = mainPart.Document.Body.Descendants<SdtElement>()
                            .FirstOrDefault(s => s.SdtProperties.GetFirstChild<Tag>()?.Val == tag);

                if (sdt == null)
                {
                    Console.WriteLine($"[ERROR] Content control with tag '{tag}' not found.");
                    continue;
                }

                Console.WriteLine($"[INFO] Inserting image table at tag '{tag}'...");

                // ✅ Add SocotecStyle
                bookmarkReplacer.AddSocotecStyle(mainPart);

                // ✅ Create a table with SOCOTEC styling
                Table newTable = new Table();
                TableProperties tblProps = new TableProperties(new TableStyle { Val = "SOCOTEC" });
                newTable.AppendChild(tblProps);

                // ✅ Insert images into table cells
                foreach (var rowData in imageDataDict[tag])
                {
                    TableRow row = new TableRow();
                    foreach (var imagePath in rowData)
                    {
                        TableCell cell = new TableCell();
                        if (!string.IsNullOrEmpty(imagePath))
                        {
                            var imagePart = await InsertImageIntoDocument(mainPart, imagePath);
                            cell.AppendChild(new Paragraph(new Run(imagePart)));
                        }
                        row.Append(cell);
                    }
                    newTable.Append(row);
                }

                // ✅ Replace content control with table
                sdt.RemoveAllChildren();
                sdt.Append(newTable);
                Console.WriteLine($"[SUCCESS] Image table inserted at content control '{tag}'.");
            }
        }

        public async Task<byte[]> InsertImagesAtTags(
    Dictionary<string, List<Dictionary<string, string>>> tagImageTableData,
    Stream documentStream)
        {
            using (var outputStream = new MemoryStream())
            {
                documentStream.Position = 0;
                await documentStream.CopyToAsync(outputStream);
                outputStream.Position = 0;

                using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(outputStream, true))
                {
                    var mainPart = wordDoc.MainDocumentPart;

                    foreach (var tagEntry in tagImageTableData)
                    {
                        string tagName = tagEntry.Key;
                        List<Dictionary<string, string>> imageRows = tagEntry.Value;

                        foreach (var row in imageRows)
                        {
                            if (row.TryGetValue("ImageUrl", out string imageUrl) && !string.IsNullOrEmpty(imageUrl))
                            {
                                try
                                {
                                    if (row.TryGetValue("Source", out string source) && source == "SharePoint")
                                    {
                                        // Insert images from SharePoint using new Tag-based method
                                        await InsertImagesFromSharePointAtTag(imageUrl, tagName, outputStream);
                                    }
                                    else
                                    {
                                        // Insert images directly without bookmarks
                                        await InsertImagesWithoutTag(imageUrl, tagName, outputStream, 600);
                                    }
                                }
                                catch (Exception ex)
                                {
                                    Console.WriteLine($"Failed to insert image for tag {tagName}: {ex.Message}");
                                }
                            }
                        }
                    }

                    mainPart.Document.Save();
                }

                return outputStream.ToArray();
            }
        }

        public async Task<MemoryStream> InsertImagesFromSharePointAtBookmark(string folderUrl, string bookmarkName, Stream documentStream)
        {
            MemoryStream outputStream = new MemoryStream();

            using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(documentStream, true))
            {
                var mainPart = wordDoc.MainDocumentPart;

                // Download all images from the SharePoint folder
                List<byte[]> images = await DownloadAllImagesFromSharePointFolder(folderUrl);

                // Insert each image at the specified bookmark
                foreach (var imageBytes in images)
                {
                    InsertImageAtBookmark(mainPart, bookmarkName, imageBytes);
                }

                // Save the document changes
                wordDoc.MainDocumentPart.Document.Save();

                // Copy the modified document to the output stream
                documentStream.Position = 0;
                documentStream.CopyTo(outputStream);
            }

            outputStream.Position = 0;
            return outputStream;
        }

        public async Task InsertImagesFromSharePointAtTag(string folderUrl, string tagName, Stream documentStream)
        {
            using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(documentStream, true))
            {
                var mainPart = wordDoc.MainDocumentPart;

                // Download all images from the SharePoint folder
                List<byte[]> images = await DownloadAllImagesFromSharePointFolder(folderUrl);

                // Find the Content Control Tag
                var tagControl = mainPart.Document.Body.Descendants<SdtElement>()
                    .FirstOrDefault(s => s.SdtProperties.GetFirstChild<Tag>()?.Val == tagName);

                if (tagControl == null)
                {
                    Console.WriteLine($"[ERROR] Content Control with tag '{tagName}' not found.");
                    return;
                }

                // Insert each image inside the content control
                foreach (var imageBytes in images)
                {
                    InsertImageAtTag(mainPart, tagControl, imageBytes);
                }

                mainPart.Document.Save();
            }
        }

        // Method to insert images without bookmarks (e.g., at the end of the document or in a table)
        public async Task<MemoryStream> InsertImagesWithoutBookmark(string folderUrl, Stream documentStream, int maxImageWidth)
        {
            MemoryStream outputStream = new MemoryStream();

            using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(documentStream, true))
            {
                var mainPart = wordDoc.MainDocumentPart;
                List<byte[]> images = await DownloadAllImagesFromSharePointFolder(folderUrl);

                Table imageTable = new Table();

                foreach (var imageBytes in images)
                {
                    TableRow imageRow = new TableRow();
                    TableCell imageCell = new TableCell();

                    ImagePart imagePart = mainPart.AddImagePart(ImagePartType.Jpeg);
                    using (var stream = new MemoryStream(imageBytes))
                    {
                        imagePart.FeedData(stream);
                    }

                    long imageWidthEmus = 990000;
                    long imageHeightEmus = 792000;

                    using (var imageStream = new MemoryStream(imageBytes))
                    {
                        using (var image = System.Drawing.Image.FromStream(imageStream))
                        {
                            if (image.Width > maxImageWidth)
                            {
                                double aspectRatio = (double)image.Height / image.Width;
                                imageWidthEmus = maxImageWidth * 9525;
                                imageHeightEmus = (long)(maxImageWidth * aspectRatio * 9525);
                            }
                        }
                    }

                    var imageElement = WordDocumentHelpers.CreateImageElement(mainPart.GetIdOfPart(imagePart), imageWidthEmus, imageHeightEmus);

                    imageCell.Append(new Paragraph(new Run(imageElement)));
                    imageRow.Append(imageCell);
                    imageTable.Append(imageRow);
                }

                var body = wordDoc.MainDocumentPart.Document.Body;
                body.Append(imageTable);

                wordDoc.MainDocumentPart.Document.Save();
                documentStream.Position = 0;
                documentStream.CopyTo(outputStream);
            }

            outputStream.Position = 0;
            return outputStream;
        }

        public async Task InsertImagesWithoutTag(string imageUrl, string tagName, Stream documentStream, int maxWidth)
        {
            using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(documentStream, true))
            {
                var mainPart = wordDoc.MainDocumentPart;

                // Download the image
                byte[] imageBytes = await DownloadImageFromUrl(imageUrl);
                if (imageBytes == null || imageBytes.Length == 0)
                {
                    Console.WriteLine($"[ERROR] Failed to download image from {imageUrl}.");
                    return;
                }

                // Find the Content Control with the specified tag
                var tagControl = mainPart.Document.Body.Descendants<SdtElement>()
                    .FirstOrDefault(s => s.SdtProperties.GetFirstChild<Tag>()?.Val == tagName);

                if (tagControl == null)
                {
                    Console.WriteLine($"[ERROR] Content Control with tag '{tagName}' not found.");
                    return;
                }

                // Insert the image into the content control
                InsertImageAtTag(mainPart, tagControl, imageBytes, maxWidth);

                mainPart.Document.Save();
            }
        }

        // Method to replace the "Signature_User" bookmark with a user signature image from binary data
        public async Task<MemoryStream> InsertUserSignatureAtBookmark(string bookmarkName, byte[] signatureImageBytes, Stream documentStream)
        {
            MemoryStream outputStream = new MemoryStream();

            using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(documentStream, true))
            {
                var mainPart = wordDoc.MainDocumentPart;

                // Replace the bookmark content with the signature image
                InsertImageAtBookmark(mainPart, bookmarkName, signatureImageBytes);

                // Save the document changes
                wordDoc.MainDocumentPart.Document.Save();

                // Copy the modified document to the output stream
                documentStream.Position = 0;
                documentStream.CopyTo(outputStream);
            }

            outputStream.Position = 0;
            return outputStream;
        }

        public async Task<byte[]> ProcessIncludesRecursively(
    string siteId,
    string driveId,
    string sharePointUrl,
    string filenameTemplate,
    string recordGuid,
    byte[] parentDocumentContent,
    List<MergeDocumentItem> includeMergeItems,
    Dictionary<string, List<Dictionary<string, string>>> bookmarkTableData,
    Dictionary<string, List<Dictionary<string, string>>> bookmarkImageTableData,
    IConfiguration config,
    EF.Core efCore,
    byte[] documentContent, // parent document content
    int userId)
        {
            var processedIncludes = new Dictionary<string, byte[]>(); // Store processed include documents
            var unprocessedItems = includeMergeItems.Where(include => !processedIncludes.ContainsKey(include.Guid)).ToList();

            Console.WriteLine("[INFO] Fully processing all includes before inserting them.");

            // **Step 1: Process Each Include One by One**
            foreach (var include in unprocessedItems)
            {
                Console.WriteLine($"[DEBUG] Processing Include: {include.BookmarkName}");

                var processedInclude = await ProcessSingleInclude(
                    include, siteId, driveId, sharePointUrl, filenameTemplate, recordGuid,
                    parentDocumentContent, bookmarkTableData, bookmarkImageTableData, config, efCore, userId
                );

                processedIncludes[include.Guid] = processedInclude;

                // **Step 2: Insert Each Include and Save/Reload the Main Document**
                Console.WriteLine($"[DEBUG] Inserting processed include at '{include.BookmarkName}'...");
                parentDocumentContent = await InsertContentAtBookmark(
                    include.BookmarkName,
                    new MemoryStream(processedInclude),
                    parentDocumentContent
                );

                // **Step 3: Save and Reload the Document after Each Insert**
                Console.WriteLine($"[INFO] Saving and reloading main document after inserting '{include.BookmarkName}'...");
                parentDocumentContent = await ReloadMainDocument(parentDocumentContent);

                //// **Step 4: Verify that the Bookmark Still Exists After Reload**
                //Console.WriteLine($"[DEBUG] Rechecking bookmark '{include.BookmarkName}' after reload...");
                //parentDocumentContent = await VerifyBookmarkExistsAfterInsertion(parentDocumentContent, include.BookmarkName);
            }

            Console.WriteLine("[SUCCESS] All include documents processed and inserted correctly.");
            return parentDocumentContent;
        }

        public async Task<byte[]> ProcessMergeFields(
    byte[] documentContent,
    List<Dictionary<string, string>> mergeFields)
        {
            byte[] modifiedDocument;

            // Sort merge data by "value" field
            var sortedMergeData = mergeFields.OrderBy(d => d.ContainsKey("value") ? d["value"] : string.Empty).ToList();

            using (MemoryStream memoryStream = new MemoryStream())
            {
                memoryStream.Write(documentContent, 0, documentContent.Length);
                using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(memoryStream, true))
                {
                    MainDocumentPart mainPart = wordDoc.MainDocumentPart;

                    foreach (var field in mainPart.Document.Body.Descendants<FieldCode>())
                    {
                        string fieldText = field.Text.Trim();

                        if (fieldText.StartsWith("MERGEFIELD"))
                        {
                            string mergeFieldName = WordDocumentHelpers.ExtractMergeFieldName(fieldText);

                            foreach (var dataSet in sortedMergeData)
                            {
                                string fieldKey = dataSet.ContainsKey("name") ? dataSet["name"] : null;
                                string fieldValue = dataSet.ContainsKey("value") ? dataSet["value"] : null;

                                if (!string.IsNullOrEmpty(fieldKey) && fieldKey == mergeFieldName)
                                {
                                    var parentRun = field.Parent as Run;
                                    var nextSibling = parentRun.NextSibling<Run>();

                                    if (nextSibling != null && nextSibling.GetFirstChild<Text>() != null)
                                    {
                                        nextSibling.GetFirstChild<Text>().Text = fieldValue;
                                    }
                                    else
                                    {
                                        WordDocumentHelpers.ReplaceMergeFieldWithText(field, fieldValue);
                                    }

                                    break; // Exit once the field is replaced
                                }
                            }
                        }
                    }

                    WordDocumentHelpers.ReplacePlainTextPlaceholders(wordDoc, sortedMergeData);
                    mainPart.Document.Save();
                }

                modifiedDocument = memoryStream.ToArray();
            }

            return modifiedDocument;
        }

        public async Task<SharepointDocumentsGetResponse> ReplaceMergeFields(string siteId,
            string driveId,
            string targetSharePointUrl,
            string filenameTemplate,
            string itemId,
            byte[] documentContent,
            List<Dictionary<string, string>> mergeFields,
            IConfiguration config,
            string outputType)
        {
            byte[] modifiedDocument;
            // Sort merge data by "value" field
            var sortedMergeData = mergeFields.OrderBy(d => d.ContainsKey("value") ? d["value"] : string.Empty).ToList();

            using (MemoryStream memoryStream = new MemoryStream())
            {
                memoryStream.Write(documentContent, 0, documentContent.Length);
                using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(memoryStream, true))
                {
                    MainDocumentPart mainPart = wordDoc.MainDocumentPart;

                    foreach (var field in mainPart.Document.Body.Descendants<FieldCode>())
                    {
                        string fieldText = field.Text.Trim();

                        if (fieldText.StartsWith("MERGEFIELD"))
                        {
                            string mergeFieldName = WordDocumentHelpers.ExtractMergeFieldName(fieldText);

                            foreach (var dataSet in sortedMergeData)
                            {
                                string fieldKey = dataSet.ContainsKey("name") ? dataSet["name"] : null;
                                string fieldValue = dataSet.ContainsKey("value") ? dataSet["value"] : null;

                                if (!string.IsNullOrEmpty(fieldKey) && fieldKey == mergeFieldName)
                                {
                                    var parentRun = field.Parent as Run;
                                    var nextSibling = parentRun.NextSibling<Run>();

                                    if (nextSibling != null && nextSibling.GetFirstChild<Text>() != null)
                                    {
                                        nextSibling.GetFirstChild<Text>().Text = fieldValue;
                                    }
                                    else
                                    {
                                        WordDocumentHelpers.ReplaceMergeFieldWithText(field, fieldValue);
                                    }

                                    break; // Exit once the field is replaced
                                }
                            }
                        }
                    }
                    WordDocumentHelpers.ReplacePlainTextPlaceholders(wordDoc, sortedMergeData);
                    mainPart.Document.Save();
                }

                modifiedDocument = memoryStream.ToArray();
            }
            // Check if its Dev or live to change SiteId for SharePoint
            var appConfig = new AppConfiguration(config);
            if (appConfig.EnvironmentType == "DEV" || appConfig.EnvironmentType == "TEST")
            {
                siteId = appConfig.DevSharepointIdentifier;
            }
            // Upload the modified document back to SharePoint
            using (var stream = new MemoryStream(modifiedDocument))
            {
                return await UploadModifiedDocument(siteId, filenameTemplate, targetSharePointUrl, itemId, stream, config, "Activities", outputType);
            }
        }

        public async Task<byte[]> ReplaceMergeFields(string siteId,
            string driveId,
            string targetSharePointUrl,
            string filenameTemplate,
            string itemId,
            byte[] documentContent,
            List<Dictionary<string, string>> mergeFields,
            IConfiguration config)
        {
            byte[] modifiedDocument;
            // Sort merge data by "value" field
            var sortedMergeData = mergeFields.OrderBy(d => d.ContainsKey("value") ? d["value"] : string.Empty).ToList();

            using (MemoryStream memoryStream = new MemoryStream())
            {
                memoryStream.Write(documentContent, 0, documentContent.Length);
                using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(memoryStream, true))
                {
                    MainDocumentPart mainPart = wordDoc.MainDocumentPart;

                    foreach (var field in mainPart.Document.Body.Descendants<FieldCode>())
                    {
                        string fieldText = field.Text.Trim();

                        if (fieldText.StartsWith("MERGEFIELD"))
                        {
                            string mergeFieldName = WordDocumentHelpers.ExtractMergeFieldName(fieldText);

                            foreach (var dataSet in sortedMergeData)
                            {
                                string fieldKey = dataSet.ContainsKey("name") ? dataSet["name"] : null;
                                string fieldValue = dataSet.ContainsKey("value") ? dataSet["value"] : null;

                                if (!string.IsNullOrEmpty(fieldKey) && fieldKey == mergeFieldName)
                                {
                                    var parentRun = field.Parent as Run;
                                    var nextSibling = parentRun.NextSibling<Run>();

                                    if (nextSibling != null && nextSibling.GetFirstChild<Text>() != null)
                                    {
                                        nextSibling.GetFirstChild<Text>().Text = fieldValue;
                                    }
                                    else
                                    {
                                        WordDocumentHelpers.ReplaceMergeFieldWithText(field, fieldValue);
                                    }

                                    break; // Exit once the field is replaced
                                }
                            }
                        }
                    }
                    WordDocumentHelpers.ReplacePlainTextPlaceholders(wordDoc, sortedMergeData);
                    mainPart.Document.Save();
                }

                modifiedDocument = memoryStream.ToArray();
            }

            return modifiedDocument;
        }

        #endregion Public Methods

        #region Private Methods

        private static async Task<List<byte[]>> DownloadAllImagesFromSharePointFolder(string folderUrl)
        {
            string siteId = Functions.ExtractSiteIdFromUrl(folderUrl);
            string relativePath = Functions.ExtractRelativePathFromUrl(folderUrl);

            var drives = await graphServiceClient.Sites[siteId].Drives.GetAsync();
            var drive = drives.Value.FirstOrDefault();

            if (drive == null) throw new Exception("Drive not found.");

            var folderItems = await graphServiceClient.Drives[drive.Id].Root.ItemWithPath(relativePath).Children.GetAsync();
            List<byte[]> imageBytesList = new List<byte[]>();

            foreach (var item in folderItems.Value)
            {
                if (item.Name.EndsWith(".jpg") || item.Name.EndsWith(".jpeg") || item.Name.EndsWith(".png"))
                {
                    var imageStream = await graphServiceClient.Drives[drive.Id].Items[item.Id].Content.GetAsync();
                    using (var memoryStream = new MemoryStream())
                    {
                        await imageStream.CopyToAsync(memoryStream);
                        imageBytesList.Add(memoryStream.ToArray());
                    }
                }
            }

            return imageBytesList;
        }

        private static void InsertImageAtBookmark(MainDocumentPart mainPart, string bookmarkName, byte[] imageBytes)
        {
            var bookmarks = mainPart.Document.Body.Descendants<BookmarkStart>()
                             .Where(b => b.Name == bookmarkName)
                             .ToList();

            foreach (var bookmark in bookmarks)
            {
                var parentElement = bookmark.Parent;

                ImagePart imagePart = mainPart.AddImagePart(ImagePartType.Jpeg);
                using (var stream = new MemoryStream(imageBytes))
                {
                    imagePart.FeedData(stream);
                }

                var imageId = mainPart.GetIdOfPart(imagePart);
                var element = WordDocumentHelpers.CreateImageElement(imageId, 990000, 792000);

                parentElement.InsertAfterSelf(element);
            }
        }

        // Remap IDs for conflicts
        private static void ProcessAllPartsRecursively(OpenXmlPart part, HashSet<string> existingIds)
        {
            if (part == null) return;

            Console.WriteLine($"Processing part: {part.Uri} with relationships");
            foreach (var rel in part.Parts.ToList())
            {
                var relId = part.GetIdOfPart(rel.OpenXmlPart);
                if (existingIds.Contains(relId))
                {
                    Console.WriteLine($"Duplicate Key Found: {relId} in {part.Uri}");
                    string newRelId;
                    int counter = 1;
                    do
                    {
                        newRelId = $"rId{counter++}";
                    }
                    while (existingIds.Contains(newRelId));

                    // Remap the relationship without deleting parts
                    part.ChangeIdOfPart(rel.OpenXmlPart, newRelId);

                    Console.WriteLine($"Remapped {relId} to {newRelId} in {part.ContentType}");

                    // Update the ID tracking to prevent further conflicts
                    existingIds.Add(newRelId);
                }
            }

            // Recursively process child parts
            foreach (var childPart in part.Parts)
            {
                ProcessAllPartsRecursively(childPart.OpenXmlPart, existingIds);
            }
        }

        private async Task<Stream> ConvertWordToExcel(Stream documentStream)
        {
            List<List<string>> tables = ExtractTablesFromWord(documentStream);

            using (var package = new ExcelPackage())
            {
                var worksheet = package.Workbook.Worksheets.Add("ExtractedData");

                int rowNumber = 1;

                foreach (var table in tables)
                {
                    foreach (var row in table)
                    {
                        string[] columns = row.Split(',');

                        for (int col = 0; col < columns.Length; col++)
                        {
                            worksheet.Cells[rowNumber, col + 1].Value = columns[col];
                        }

                        rowNumber++;
                    }

                    rowNumber++; // Add space between tables
                }

                MemoryStream excelStream = new MemoryStream();
                await package.SaveAsAsync(excelStream);
                excelStream.Position = 0; // Reset stream position
                return excelStream;
            }
        }

        private async Task<Stream> ConvertWordToPdfWithGraphAPI(GraphServiceClient graphServiceClient, string driveId, string itemId)
        {
            try
            {
                Console.WriteLine($"Converting Word document to PDF. DriveId={driveId}, ItemId={itemId}");

                // Make the request to convert the document to PDF
                var pdfStream = await graphServiceClient
                    .Drives[driveId]
                    .Items[itemId]
                    .Content
                    .GetAsync(requestConfiguration =>
                    {
                        requestConfiguration.QueryParameters.Format = "pdf";
                    });

                Console.WriteLine("PDF conversion successful.");
                return pdfStream;
            }
            catch (Microsoft.Graph.ServiceException ex)
            {
                Console.WriteLine($"Error during Word to PDF conversion: BadRequest. Details: {ex.Message}");
                throw new Exception("The document may contain unsupported elements or invalid data. Please review and try again.", ex);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error during Word to PDF conversion: {ex.Message}");
                throw;
            }
        }

        private async Task<Stream> DownloadDocumentContent(string driveId, string itemId)
        {
            int retryCount = 3;
            while (retryCount > 0)
            {
                try
                {
                    Console.WriteLine($"Downloading document content. Drive ID: {driveId}, Item ID: {itemId}");
                    var stream = await graphServiceClient?.Drives[driveId].Items[itemId].Content.GetAsync();
                    if (stream != null)
                        return stream;

                    Console.WriteLine("Document content is null.");
                    return Stream.Null;
                }
                catch (Microsoft.Graph.Models.ODataErrors.ODataError ex) when (ex.Message.Contains("The resource could not be found"))
                {
                    Console.WriteLine($"Resource not found. Drive ID: {driveId}, Item ID: {itemId}. Error: {ex.Message}");
                    throw new FileNotFoundException($"The specified document could not be found. Drive ID: {driveId}, Item ID: {itemId}", ex);
                }
                catch (HttpRequestException ex) when (retryCount > 1)
                {
                    Console.WriteLine($"Transient error occurred: {ex.Message}. Retrying...");
                    retryCount--;
                    await Task.Delay(1000); // Wait before retrying
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error in DownloadDocumentContent: {ex}");
                    throw;
                }
            }
            return Stream.Null;
        }

        private async Task<byte[]> DownloadImageFromUrl(string imageUrl)
        {
            using (HttpClient client = new HttpClient())
            {
                try
                {
                    return await client.GetByteArrayAsync(imageUrl);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[ERROR] Failed to download image from {imageUrl}: {ex.Message}");
                    return null;
                }
            }
        }

        private List<List<string>> ExtractTablesFromWord(Stream documentStream)
        {
            List<List<string>> extractedTables = new List<List<string>>();

            using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(documentStream, false))
            {
                var tables = wordDoc.MainDocumentPart.Document.Body.Elements<Table>();

                foreach (var table in tables)
                {
                    List<string> tableData = new List<string>();

                    foreach (var row in table.Elements<TableRow>())
                    {
                        List<string> rowData = new List<string>();

                        foreach (var cell in row.Elements<TableCell>())
                        {
                            string cellText = cell.InnerText.Trim();
                            rowData.Add(cellText);
                        }

                        tableData.Add(string.Join(",", rowData)); // Convert row to CSV-like format
                    }

                    extractedTables.Add(tableData);
                }
            }

            return extractedTables;
        }

        private Table GenerateTableForBookmark(string bookmarkName, Body includedDocumentBody)
        {
            var table = new Table();

            var tableProperties = new TableProperties(
                new TableWidth { Width = "100%", Type = TableWidthUnitValues.Pct },
                new TableBorders(
                    new TopBorder() { Val = BorderValues.Single, Color = "000000", Size = 4 },
                    new LeftBorder() { Val = BorderValues.Single, Color = "000000", Size = 4 },
                    new BottomBorder() { Val = BorderValues.Single, Color = "000000", Size = 4 },
                    new RightBorder() { Val = BorderValues.Single, Color = "000000", Size = 4 },
                    new InsideHorizontalBorder() { Val = BorderValues.Single, Color = "000000", Size = 4 },
                    new InsideVerticalBorder() { Val = BorderValues.Single, Color = "000000", Size = 4 }
                )
            );

            table.AppendChild(tableProperties);

            var rows = includedDocumentBody.Descendants<TableRow>().ToList();

            if (rows.Count == 0)
            {
                var emptyRow = new TableRow();
                var emptyCell = new TableCell(new Paragraph(new Run(new Text("No data available"))));
                emptyRow.AppendChild(emptyCell);
                table.AppendChild(emptyRow);
            }
            else
            {
                foreach (var row in rows)
                {
                    table.AppendChild(row.CloneNode(true));
                }
            }

            return table;
        }

        private async Task<byte[]> InsertContentAtBookmark(
    string bookmarkName,
    Stream includedContentStream,
    byte[] mainDocumentContent)
        {
            using (var mainDocumentStream = new MemoryStream())
            {
                mainDocumentStream.Write(mainDocumentContent, 0, mainDocumentContent.Length);
                mainDocumentStream.Position = 0;

                var mainDocument = new OpenXmlPowerTools.WmlDocument("MainDocument", mainDocumentStream.ToArray());
                var includedDocumentBytes = await WordDocumentHelpers.StreamToByteArrayAsync(includedContentStream);
                var includedDocument = new OpenXmlPowerTools.WmlDocument("IncludedDocument", includedDocumentBytes);

                using (var wordDoc = WordprocessingDocument.Open(mainDocumentStream, true))
                {
                    Console.WriteLine($"[DEBUG] Searching for bookmark '{bookmarkName}' before insertion...");

                    var bookmark = wordDoc.MainDocumentPart.Document.Body
                        .Descendants<BookmarkStart>()
                        .FirstOrDefault(b => b.Name == bookmarkName);

                    if (bookmark == null)
                    {
                        Console.WriteLine($"[ERROR] Bookmark '{bookmarkName}' not found before insertion.");
                        throw new Exception($"Bookmark '{bookmarkName}' not found.");
                    }

                    var parentElement = bookmark.Parent;
                    while (parentElement != null && !(parentElement is Paragraph))
                    {
                        parentElement = parentElement.Parent;
                    }

                    if (parentElement == null)
                    {
                        Console.WriteLine($"[ERROR] No valid parent found for bookmark '{bookmarkName}'.");
                        throw new Exception($"Failed to find valid parent for bookmark '{bookmarkName}'.");
                    }

                    // ✅ Step 2: Extract the body content of the included document
                    using (var includedDoc = WordprocessingDocument.Open(new MemoryStream(includedDocumentBytes), false))
                    {
                        var includedBody = includedDoc.MainDocumentPart.Document.Body;
                        if (includedBody == null)
                        {
                            Console.WriteLine($"[ERROR] Included document '{bookmarkName}' has no body content.");
                            throw new Exception($"Included document '{bookmarkName}' has no body content.");
                        }

                        var extractedElements = includedBody.Elements().ToList();
                        if (!extractedElements.Any())
                        {
                            Console.WriteLine($"[ERROR] Included document '{bookmarkName}' contains no valid content.");
                            throw new Exception($"Included document '{bookmarkName}' contains no valid content.");
                        }
                    }

                    // ✅ Step 3: Correctly find the bookmark’s paragraph index
                    var paragraphs = wordDoc.MainDocumentPart.Document.Body.Descendants<Paragraph>().ToList();
                    int bookmarkIndex = paragraphs.FindIndex(p => p.Descendants<BookmarkStart>().Any(b => b.Name == bookmarkName));

                    if (bookmarkIndex == -1)
                    {
                        Console.WriteLine($"[ERROR] Could not determine paragraph index for '{bookmarkName}'.");
                        throw new Exception($"Could not determine paragraph index for '{bookmarkName}'.");
                    }

                    Console.WriteLine($"[SUCCESS] Found valid paragraph index {bookmarkIndex} for tag '{bookmarkName}'.");

                    // ✅ Step 4: Merge included document at the correct paragraph index
                    var sources = new List<OpenXmlPowerTools.Source>
            {
                new OpenXmlPowerTools.Source(mainDocument, 0, bookmarkIndex, true),
                new OpenXmlPowerTools.Source(includedDocument, true),
                new OpenXmlPowerTools.Source(mainDocument, bookmarkIndex + 1, true)
            };

                    var mergedDocument = OpenXmlPowerTools.DocumentBuilder.BuildDocument(sources);
                    Console.WriteLine($"[SUCCESS] Successfully inserted included document at bookmark '{bookmarkName}'.");

                    return mergedDocument.DocumentByteArray;
                }
            }
        }

        private void InsertDocumentAtBookmark(Stream parentStream, Stream includedStream, string bookmarkName, Stream outputStream)
        {
            using (var parentDoc = WordprocessingDocument.Open(parentStream, true))
            {
                var mainPart = parentDoc.MainDocumentPart;
                var bookmark = mainPart.Document.Body.Descendants<BookmarkStart>()
                    .FirstOrDefault(b => b.Name == bookmarkName);

                if (bookmark == null)
                {
                    Console.WriteLine($"Bookmark '{bookmarkName}' not found in the parent document.");
                    return;
                }

                var parentParagraph = bookmark.Parent as Paragraph;

                using (var includedDoc = WordprocessingDocument.Open(includedStream, true))
                {
                    var includedBody = includedDoc.MainDocumentPart.Document.Body;

                    if (parentParagraph != null)
                    {
                        foreach (var element in includedBody.Elements())
                        {
                            // Clone the elements to avoid relationship issues
                            parentParagraph.InsertAfterSelf(element.CloneNode(true));
                        }

                        Console.WriteLine($"Inserted content of included document into bookmark '{bookmarkName}'.");
                    }
                }

                // Save changes to the parent document
                parentDoc.MainDocumentPart.Document.Save();
            }

            // Ensure the output stream is writable and reset
            if (!(outputStream is MemoryStream) || !outputStream.CanWrite)
            {
                throw new InvalidOperationException("The output stream must be a writable MemoryStream.");
            }

            parentStream.Position = 0;
            parentStream.CopyTo(outputStream);
            outputStream.Position = 0;
        }

        private void InsertImageAtTag(MainDocumentPart mainPart, SdtElement tagControl, byte[] imageBytes, int maxWidth = 300)
        {
            /*
             * MaxWidth values for different image types:
                "HeaderImage" => 800, // Large banner
                "CompanyLogo" => 200, // Small logo
                "Signature" => 300, // Signature-sized image
                _ => 600 // Default size
             */
            ImagePart imagePart = mainPart.AddImagePart(ImagePartType.Jpeg);
            using (MemoryStream imageStream = new MemoryStream(imageBytes))
            {
                imagePart.FeedData(imageStream);
            }
            // **Set max width while maintaining aspect ratio**
            long cx = maxWidth * 9525L; // Convert pixels to EMUs
            long cy = (long)(cx * 0.75); // Maintain aspect ratio (assuming 4:3)

            var element = new Drawing(
                new Inline(
                    new Extent() { Cx = cx, Cy = cy }, // Apply max width
                    new EffectExtent() { LeftEdge = 19050L, TopEdge = 0L, RightEdge = 9525L, BottomEdge = 0L },
                    new DocProperties() { Id = (UInt32Value)1U, Name = "Picture 1" },
                    new NonVisualGraphicFrameDrawingProperties(new DocumentFormat.OpenXml.Drawing.GraphicFrameLocks() { NoChangeAspect = true }),
                    new DocumentFormat.OpenXml.Drawing.Graphic(new DocumentFormat.OpenXml.Drawing.GraphicData(
                        new Picture(
                            new DocumentFormat.OpenXml.Drawing.NonVisualPictureProperties(
                                new DocumentFormat.OpenXml.Drawing.NonVisualDrawingProperties() { Id = (UInt32Value)0U, Name = "New Image.jpg" },
                                new DocumentFormat.OpenXml.Drawing.NonVisualPictureDrawingProperties()
                            ),
                            new DocumentFormat.OpenXml.Drawing.BlipFill(new DocumentFormat.OpenXml.Drawing.Blip() { Embed = mainPart.GetIdOfPart(imagePart) },
                                new DocumentFormat.OpenXml.Drawing.Stretch(new DocumentFormat.OpenXml.Drawing.FillRectangle())),
                            new DocumentFormat.OpenXml.Drawing.ShapeProperties(
                        new DocumentFormat.OpenXml.Drawing.Transform2D(new DocumentFormat.OpenXml.Drawing.Offset() { X = 0L, Y = 0L },
                            new DocumentFormat.OpenXml.Drawing.Extents() { Cx = cx, Cy = cy }),
                        new DocumentFormat.OpenXml.Drawing.PresetGeometry(new DocumentFormat.OpenXml.Drawing.AdjustValueList()) { Preset = DocumentFormat.OpenXml.Drawing.ShapeTypeValues.Rectangle }
                    )
                        )
                    )
                    { Uri = "http://schemas.openxmlformats.org/drawingml/2006/picture" }
                )
            ));

            tagControl.RemoveAllChildren<Paragraph>(); // Remove existing text
            tagControl.AppendChild(new Paragraph(new Run(element)));
        }

        private async Task<Drawing> InsertImageIntoDocument(MainDocumentPart mainPart, string imageUrl)
        {
            // ✅ Fetch all images from SharePoint
            var imageDictionary = await DownloadImagesFromSharePointAsync(imageUrl);

            if (!imageDictionary.Any())
            {
                Console.WriteLine($"[ERROR] No images found for {imageUrl}.");
                return null;
            }

            // ✅ Select the first image (or modify logic if specific selection is needed)
            var firstImage = imageDictionary.FirstOrDefault().Value;

            if (firstImage == null || firstImage.Length == 0)
            {
                Console.WriteLine($"[ERROR] Failed to retrieve image data from SharePoint.");
                return null;
            }

            ImagePart imagePart = mainPart.AddImagePart(ImagePartType.Jpeg);
            using (MemoryStream imageStream = new MemoryStream(firstImage))
            {
                imagePart.FeedData(imageStream);
            }

            long cx = 3000000L; // Approx 3cm width
            long cy = 3000000L; // Approx 3cm height

            return new Drawing(
                new Inline(
                    new Extent() { Cx = cx, Cy = cy },
                    new EffectExtent() { LeftEdge = 19050L, TopEdge = 0L, RightEdge = 9525L, BottomEdge = 0L },
                    new DocProperties() { Id = (UInt32Value)1U, Name = "Image" },
                    new NonVisualGraphicFrameDrawingProperties(new DocumentFormat.OpenXml.Drawing.GraphicFrameLocks() { NoChangeAspect = true }),
                    new DocumentFormat.OpenXml.Drawing.Graphic(new DocumentFormat.OpenXml.Drawing.GraphicData(
                        new Picture(
                            new DocumentFormat.OpenXml.Drawing.NonVisualPictureProperties(
                                new DocumentFormat.OpenXml.Drawing.NonVisualDrawingProperties() { Id = (UInt32Value)0U, Name = "Inserted Image" },
                                new DocumentFormat.OpenXml.Drawing.NonVisualPictureDrawingProperties()
                            ),
                            new DocumentFormat.OpenXml.Drawing.BlipFill(new DocumentFormat.OpenXml.Drawing.Blip() { Embed = mainPart.GetIdOfPart(imagePart) }, new DocumentFormat.OpenXml.Drawing.Stretch(new DocumentFormat.OpenXml.Drawing.FillRectangle())),
                            new DocumentFormat.OpenXml.Drawing.ShapeProperties(
                                new DocumentFormat.OpenXml.Drawing.Transform2D(new DocumentFormat.OpenXml.Drawing.Offset() { X = 0L, Y = 0L }, new DocumentFormat.OpenXml.Drawing.Extents() { Cx = cx, Cy = cy }),
                                new DocumentFormat.OpenXml.Drawing.PresetGeometry(new DocumentFormat.OpenXml.Drawing.AdjustValueList()) { Preset = DocumentFormat.OpenXml.Drawing.ShapeTypeValues.Rectangle }
                            )
                        )
                    )
                    { Uri = "http://schemas.openxmlformats.org/drawingml/2006/picture" })
                )
            );
        }

        private void InsertImagesAtTag(Dictionary<string, List<Dictionary<string, string>>> imageDataDict, MainDocumentPart mainPart, string sharePointUrl)
        {
            throw new NotImplementedException();
        }

        private async Task<byte[]> ProcessMergeFieldsInInclude(
    string siteId, string driveId, string sharePointUrl, string filenameTemplate,
    string recordGuid, byte[] includedDocumentBytes, MergeDocument includedMergeDocument,
    EF.Core efCore, IConfiguration config, int userId)
        {
            var entityType = await efCore.GetEntityType(
                Functions.ParseAndReturnEmptyGuidIfInvalid(includedMergeDocument.EntityTypeGuid),
                true, false, false, false, true
            );

            if (entityType == null)
            {
                throw new Exception($"EntityType not found for included document {includedMergeDocument.Guid}");
            }

            var mergeData = Functions.GetMergeData(
                await efCore.DataObjectGet(
                    Functions.ParseAndReturnEmptyGuidIfInvalid(recordGuid),
                    Guid.Empty,
                    Functions.ParseAndReturnEmptyGuidIfInvalid(includedMergeDocument.EntityTypeGuid),
                    false
                ),
                entityType
            );

            return await ReplaceMergeFields(
                siteId, driveId, sharePointUrl, filenameTemplate,
                includedMergeDocument.DocumentId, includedDocumentBytes,
                mergeData, config
            );
        }

        private async Task<byte[]> ProcessSingleInclude(
    MergeDocumentItem include,
    string siteId,
    string driveId,
    string sharePointUrl,
    string filenameTemplate,
    string recordGuid,
    byte[] parentDocumentContent,
    Dictionary<string, List<Dictionary<string, string>>> bookmarkTableData,
    Dictionary<string, List<Dictionary<string, string>>> bookmarkImageTableData,
    IConfiguration config,
    EF.Core efCore,
    int userId)
        {
            foreach (var includedDocument in include.Includes)
            {
                if (includedDocument == null || string.IsNullOrEmpty(includedDocument.Guid)) continue;

                var includedMergeDocument = await efCore.GetMergeDocumentForItemIncludeByGuid(
                    Functions.ParseAndReturnEmptyGuidIfInvalid(includedDocument.Guid));

                if (includedMergeDocument == null || string.IsNullOrEmpty(includedMergeDocument.DocumentId)) continue;

                var parentDrive = await graphServiceClient.Sites[includedMergeDocument.DriveId].Drive.GetAsync();
                if (parentDrive == null) continue;

                using (var includedDocumentStream = await DownloadDocumentContent(parentDrive.Id, includedMergeDocument.DocumentId))
                {
                    var APIIncludedMergeDocument = Converters.ConvertEfMergeDocumentToCoreMergeDocument(includedMergeDocument);

                    var GetMergeDocumentItems = await efCore.GetMergeDocumentItems(includedMergeDocument.Guid, userId);

                    APIIncludedMergeDocument.Items.AddRange(Converters.ConvertEfMergeDocumentItemsToCoreMergeDocumentItems(GetMergeDocumentItems));
                    //var tableMergeItems = APIIncludedMergeDocument.Items.Where(m => m.MergeDocumentItemType == "Data Table").ToList();

                    //// **Step 1: Get tables Data in Include Document**
                    //foreach (var tableMergeItem in tableMergeItems)
                    //{
                    //    var tableData = await efCore.GetMergeDocumentItemData(tableMergeItem.Guid, userId);
                    //    if (tableData != null && tableData.Count > 0)
                    //    {
                    //        bookmarkTableData[tableMergeItem.BookmarkName] = tableData;
                    //    }
                    //}

                    byte[] includedDocumentBytes;
                    using (var memoryStream = new MemoryStream())
                    {
                        await includedDocumentStream.CopyToAsync(memoryStream);
                        includedDocumentBytes = memoryStream.ToArray();
                    }

                    // **Step 2: Process Merge Fields**
                    includedDocumentBytes = await ProcessMergeFieldsInInclude(
                        siteId, driveId, sharePointUrl, filenameTemplate, recordGuid,
                        includedDocumentBytes, APIIncludedMergeDocument, efCore, config, userId
                    );

                    //**Step 3: Process Content Control Tables**
                    includedDocumentBytes = ReplaceContentControlTablesInInclude(
                        includedDocumentBytes, bookmarkTableData, efCore
                    );

                    // **Step 4: Process Image Content Control Tags**
                    includedDocumentBytes = await InsertImagesAtTags(
                        bookmarkImageTableData, new MemoryStream(includedDocumentBytes)
                    );

                    return includedDocumentBytes;
                }
            }

            return parentDocumentContent;
        }

        private async Task<byte[]> ReloadMainDocument(byte[] documentContent)
        {
            using (var memoryStream = new MemoryStream())
            {
                memoryStream.Write(documentContent, 0, documentContent.Length);
                memoryStream.Position = 0;

                using (var wordDoc = WordprocessingDocument.Open(memoryStream, true))
                {
                    wordDoc.MainDocumentPart.Document.Save();
                    Console.WriteLine($"[SUCCESS] Document saved successfully after insertion.");
                }

                return memoryStream.ToArray();
            }
        }

        private async Task<byte[]> ReplaceAndInsert(
            string siteId,
            string driveId,
            string sharePointUrl,
            string filenameTemplate,
            MergeDocument includedMergeDocument,
            byte[] includedDocumentBytes,
            string recordGuid,
            IConfiguration config,
            EF.Core efCore,
            Dictionary<string, List<Dictionary<string, string>>> bookmarkTableData,
            Dictionary<string, List<Dictionary<string, string>>> bookmarkImageTableData,
            string bookmarkName,
            byte[] parentDocumentContent
        )
        {
            // Retrieve data for merging
            var dataObject = await efCore.DataObjectGet(
                Functions.ParseAndReturnEmptyGuidIfInvalid(recordGuid),
                Guid.Empty,
                Functions.ParseAndReturnEmptyGuidIfInvalid(includedMergeDocument.EntityTypeGuid.ToString()),
                false);

            var entityType = await efCore.GetEntityType(
                Functions.ParseAndReturnEmptyGuidIfInvalid(includedMergeDocument.EntityTypeGuid.ToString()),
                false, false);

            var includesMergeData = Functions.GetMergeData(dataObject, entityType);

            // Step 1: Process Tables for the Child Document using BookmarkReplacer
            if (bookmarkTableData.Count > 0)
            {
                using (var inputStream = new MemoryStream(includedDocumentBytes))
                using (var outputStream = new MemoryStream())
                {
                    var bookmarkReplacer = new BookmarkReplacer();

                    Console.WriteLine($"Replacing bookmarks with tables in included document...");
                    bookmarkReplacer.ReplaceBookmarksWithTables(inputStream, bookmarkTableData, outputStream);
                    outputStream.Position = 0;
                    includedDocumentBytes = outputStream.ToArray();
                    Console.WriteLine("Table replacements completed successfully.");
                }
            }

            // Step 2: Replace merge fields and tables within the included document
            var updatedIncludedContent = await ReplaceMergeFields(
                siteId,
                driveId,
                sharePointUrl,
                filenameTemplate,
                includedMergeDocument.DocumentId,
                includedDocumentBytes,
                includesMergeData,
                config
            );

            // Wrap updated content in a MemoryStream for insertion
            using var updatedIncludedContentStream = new MemoryStream(updatedIncludedContent, writable: true);

            // Step 3: Insert the processed included document into the parent document
            return await InsertContentAtBookmark(
                bookmarkName,
                updatedIncludedContentStream,
                parentDocumentContent
            );
        }

        private byte[] ReplaceContentControlTablesInInclude(byte[] documentBytes, Dictionary<string, List<Dictionary<string, string>>> tableData, EF.Core efCore)
        {
            using (var memoryStream = new MemoryStream())
            {
                memoryStream.Write(documentBytes, 0, documentBytes.Length);
                memoryStream.Position = 0;

                using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(memoryStream, true))
                {
                    var mainPart = wordDoc.MainDocumentPart;
                    if (mainPart == null) throw new Exception("[ERROR] MainDocumentPart is missing.");

                    // **Loop Through Each Content Control in Document**
                    foreach (var contentControl in mainPart.Document.Body.Descendants<SdtElement>())
                    {
                        var tag = contentControl.SdtProperties.GetFirstChild<Tag>()?.Val;
                        if (tag != null && tableData.ContainsKey(tag))
                        {
                            Console.WriteLine($"[INFO] Replacing content control '{tag}' with a table.");

                            // Generate the table from the existing method
                            var bookmarkReplacer = new BookmarkReplacer();
                            Table newTable = bookmarkReplacer.GenerateTable(tableData[tag], mainPart, tag);

                            // Replace the content control with the new table
                            contentControl.InsertAfterSelf(newTable);
                            contentControl.Remove();
                        }
                    }

                    mainPart.Document.Save();
                }

                return memoryStream.ToArray();
            }
        }

        private void ReplaceContentControlWithTable(MainDocumentPart mainPart, string controlTag, List<Dictionary<string, string>> tableData)
        {
            var sdt = mainPart.Document.Body.Descendants<SdtElement>()
                        .FirstOrDefault(s => s.SdtProperties.GetFirstChild<Tag>()?.Val == controlTag);

            if (sdt == null)
            {
                Console.WriteLine($"[ERROR] Content control with tag '{controlTag}' not found.");
                return;
            }

            Console.WriteLine($"[INFO] Found Content Control '{controlTag}', preparing to insert table...");

            // ✅ Step 1: Log Table Data Before Insertion
            Console.WriteLine("\n[DEBUG] Table Preview:");
            if (tableData.Count == 0)
            {
                Console.WriteLine("[WARNING] Table data is empty. No rows to insert.");
            }
            else
            {
                // Print header row
                var headers = tableData[0].Keys.ToList();
                Console.WriteLine("+" + string.Join("+", headers.Select(h => new string('-', h.Length + 4))) + "+");
                Console.WriteLine("| " + string.Join(" | ", headers) + " |");
                Console.WriteLine("+" + string.Join("+", headers.Select(h => new string('-', h.Length + 4))) + "+");

                // Print table rows
                foreach (var row in tableData)
                {
                    Console.WriteLine("| " + string.Join(" | ", row.Values) + " |");
                }
                Console.WriteLine("+" + string.Join("+", headers.Select(h => new string('-', h.Length + 4))) + "+\n");
            }
            // Ensure SOCOTEC style is added before inserting the table
            var bookmarkReplacer = new BookmarkReplacer();
            bookmarkReplacer.AddSocotecStyle(mainPart);

            // Generate the table using the existing `GenerateTable` method
            Table newTable = bookmarkReplacer.GenerateTable(tableData, mainPart, controlTag);

            // **Apply SOCOTEC style explicitly to table properties**
            newTable.GetFirstChild<TableProperties>()?.Append(new TableStyle { Val = "SOCOTEC" });

            // Replace Content Control with Table
            sdt.InsertAfterSelf(newTable);
            sdt.Remove(); // Remove the old content control

            Console.WriteLine($"[SUCCESS] Table inserted at content control '{controlTag}' with SOCOTEC style and header row.");
        }

        private async Task<SharepointDocumentsGetResponse> UploadModifiedDocument(
    string siteId,
    string FilenameTemplate,
    string targetSharePointUrl,
    string itemId,
    Stream modifiedContent,
    IConfiguration config,
    string subFolder = "",
    string outputType = "Word")
        {
            try
            {
                Console.WriteLine("[INFO] Checking if environment is Dev, Test, or Live...");

                // **Check if running in Dev/Test and update Site ID**
                var appConfig = new AppConfiguration(config);
                if (appConfig.EnvironmentType == "DEV" || appConfig.EnvironmentType == "TEST")
                {
                    Console.WriteLine($"[INFO] Running in {appConfig.EnvironmentType} mode. Updating Site ID...");
                    siteId = appConfig.DevSharepointIdentifier;
                    Console.WriteLine($"[SUCCESS] Updated Site ID for {appConfig.EnvironmentType}: {siteId}");
                }

                Console.WriteLine("[INFO] Extracting last two segments from SharePoint URL...");
                var result = Functions.ExtractLastTwoSegmentsFromUrl(targetSharePointUrl);
                var parentFolder = result.Item1;
                var mainFolder = result.Item2;

                Console.WriteLine($"[DEBUG] Extracted Parent Folder: {parentFolder}, Main Folder: {mainFolder}");

                if (string.IsNullOrEmpty(parentFolder) || string.IsNullOrEmpty(mainFolder))
                {
                    throw new Exception($"[ERROR] ExtractLastTwoSegmentsFromUrl returned an invalid folder structure: {targetSharePointUrl}");
                }

                Console.WriteLine("[INFO] Retrieving site drives...");
                var drives = await graphServiceClient.Sites[siteId].Drives.GetAsync();

                if (drives == null || drives.Value == null || drives.Value.Count == 0)
                {
                    throw new Exception($"[ERROR] No drives found for Site ID: {siteId}");
                }

                var driveItem = drives.Value.FirstOrDefault(d => d.Name == parentFolder);
                if (driveItem == null)
                {
                    throw new Exception($"[ERROR] Parent folder '{parentFolder}' not found in SharePoint drives.");
                }

                Console.WriteLine($"[SUCCESS] Parent folder '{parentFolder}' found. Drive ID: {driveItem.Id}");

                var rootFolder = await graphServiceClient.Drives[driveItem.Id].Root.GetAsync();
                if (rootFolder == null)
                {
                    throw new Exception("[ERROR] Failed to obtain root folder.");
                }

                Console.WriteLine("[INFO] Retrieving target folder...");
                var itemCollection = await graphServiceClient
                    .Drives[driveItem.Id]
                    .Items[rootFolder.Id]
                    .Children
                    .GetAsync(
                        requestConfig => { requestConfig.QueryParameters.Filter = $"(name eq '{mainFolder}')"; }
                    );

                var targetFolder = itemCollection?.Value?.FirstOrDefault();
                if (targetFolder == null)
                {
                    throw new Exception($"[ERROR] Target folder '{mainFolder}' not found in SharePoint.");
                }

                Console.WriteLine($"[SUCCESS] Target folder '{mainFolder}' found. Folder ID: {targetFolder.Id}");

                string _fileName = Functions.GetFileNameText(FilenameTemplate);
                if (string.IsNullOrEmpty(_fileName))
                {
                    throw new Exception("[ERROR] FilenameTemplate returned an empty filename.");
                }

                Console.WriteLine($"[INFO] Uploading document as '{_fileName}.{outputType.ToLower()}'...");

                if (outputType == "Word")
                {
                    var uploadedItem = await graphServiceClient
                        .Drives[driveItem.Id]
                        .Items[targetFolder.Id].ItemWithPath($"{_fileName}.docx")
                        .Content
                        .PutAsync(modifiedContent);

                    if (uploadedItem == null || string.IsNullOrEmpty(uploadedItem.Id))
                    {
                        throw new Exception("[ERROR] Failed to upload Word document.");
                    }

                    Console.WriteLine($"[SUCCESS] Uploaded item ID: {uploadedItem.Id}, FileName: {_fileName}.docx");
                    return await DownloadDriveItem(driveItem.Id, uploadedItem.Id);
                }
                else if (outputType == "PDF")
                {
                    Console.WriteLine($"[INFO] Uploading Word document for PDF conversion...");

                    var uploadedWordItem = await graphServiceClient
                        .Drives[driveItem.Id]
                        .Items[targetFolder.Id].ItemWithPath($"{_fileName}.docx")
                        .Content
                        .PutAsync(modifiedContent);

                    if (uploadedWordItem == null || string.IsNullOrEmpty(uploadedWordItem.Id))
                    {
                        throw new Exception("[ERROR] Failed to upload Word document for PDF conversion.");
                    }

                    Console.WriteLine($"[SUCCESS] Word document uploaded for conversion: {_fileName}.docx");

                    Console.WriteLine("[INFO] Converting to PDF...");
                    var pdfStream = await ConvertWordToPdfWithGraphAPI(graphServiceClient, driveItem.Id, uploadedWordItem.Id);

                    var uploadedPdfItem = await graphServiceClient
                        .Drives[driveItem.Id]
                        .Items[targetFolder.Id]
                        .ItemWithPath($"{_fileName}.pdf")
                        .Content
                        .PutAsync(pdfStream);

                    if (uploadedPdfItem == null || string.IsNullOrEmpty(uploadedPdfItem.Id))
                    {
                        throw new Exception("[ERROR] Failed to upload converted PDF document.");
                    }

                    Console.WriteLine($"[SUCCESS] Uploaded item ID: {uploadedPdfItem.Id}, FileName: {_fileName}.pdf");
                    return await DownloadDriveItem(driveItem.Id, uploadedPdfItem.Id);
                }
                else if (outputType == "Excel")
                {
                    Console.WriteLine($"[INFO] Converting Word document to Excel...");

                    var excelStream = await ConvertWordToExcel(modifiedContent);

                    var uploadedExcelItem = await graphServiceClient
                        .Drives[driveItem.Id]
                        .Items[targetFolder.Id].ItemWithPath($"{_fileName}.xlsx")
                        .Content
                        .PutAsync(excelStream);

                    if (uploadedExcelItem == null || string.IsNullOrEmpty(uploadedExcelItem.Id))
                    {
                        throw new Exception("[ERROR] Failed to upload converted Excel document.");
                    }

                    Console.WriteLine($"[SUCCESS] Uploaded item ID: {uploadedExcelItem.Id}, FileName: {_fileName}.xlsx");
                    return await DownloadDriveItem(driveItem.Id, uploadedExcelItem.Id);
                }
                throw new Exception("[ERROR] Unsupported output type.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ERROR] UploadModifiedDocument failed: {ex.Message}");
                throw;
            }
        }

        private async Task<byte[]> VerifyBookmarkExistsAfterInsertion(byte[] documentContent, string bookmarkName)
        {
            using (var memoryStream = new MemoryStream())
            {
                memoryStream.Write(documentContent, 0, documentContent.Length);
                memoryStream.Position = 0;

                using (var wordDoc = WordprocessingDocument.Open(memoryStream, true))
                {
                    var bookmark = wordDoc.MainDocumentPart.Document.Body
                        .Descendants<BookmarkStart>()
                        .FirstOrDefault(b => b.Name == bookmarkName);

                    if (bookmark == null)
                    {
                        Console.WriteLine($"[ERROR] Bookmark '{bookmarkName}' is missing after insertion!");
                        throw new Exception($"Bookmark '{bookmarkName}' is missing after processing.");
                    }
                    else
                    {
                        Console.WriteLine($"[SUCCESS] Bookmark '{bookmarkName}' exists after insertion.");
                    }
                }

                return memoryStream.ToArray();
            }
        }

        #endregion Private Methods
    }
}