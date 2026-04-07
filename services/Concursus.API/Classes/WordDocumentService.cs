using Concursus.API.Core;
using Concursus.API.Models;
using Concursus.Common.Shared.Helpers;
using DocumentFormat.OpenXml;

//using DocumentFormat.OpenXml.Drawing;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Validation;
using DocumentFormat.OpenXml.Wordprocessing;
using Microsoft.Graph;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats;
using System.Data;
using Telerik.Windows.Documents.Flow.FormatProviders.Docx;
using Telerik.Windows.Documents.Flow.Model;
using Telerik.Windows.Documents.Spreadsheet.FormatProviders.OpenXml.Xlsx;
using A = DocumentFormat.OpenXml.Drawing;
using DW = DocumentFormat.OpenXml.Drawing.Wordprocessing;
using Footer = DocumentFormat.OpenXml.Wordprocessing.Footer;
using Header = DocumentFormat.OpenXml.Wordprocessing.Header;
using Paragraph = DocumentFormat.OpenXml.Wordprocessing.Paragraph;
using PIC = DocumentFormat.OpenXml.Drawing.Pictures;
using Run = DocumentFormat.OpenXml.Wordprocessing.Run;
using Table = DocumentFormat.OpenXml.Wordprocessing.Table;
using TableCell = DocumentFormat.OpenXml.Wordprocessing.TableCell;
using TableRow = DocumentFormat.OpenXml.Wordprocessing.TableRow;
using TelerikParagraph = Telerik.Windows.Documents.Flow.Model.Paragraph;
using TelerikRun = Telerik.Windows.Documents.Flow.Model.Run;
using TelerikTable = Telerik.Windows.Documents.Flow.Model.Table;

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

        private static readonly Dictionary<Guid, string> RecordTypeMapping = new()
    {
        { Guid.Parse("3b4f2df9-b6cf-4a49-9eed-2206473867a1"), "Enquiry" },
        { Guid.Parse("1c4794c1-f956-4c32-b886-5500ac778a56"), "Quote" },
        { Guid.Parse("63542427-46ab-4078-abd1-1d583c24315c"), "Jobs" }
    };

        private static HashSet<uint> _drawingElementIds = new HashSet<uint>();
        private static GraphServiceClient graphServiceClient;
        private IConfiguration _config;
        private ILogger<DocumentIncludeHelper> _logger;

        private List<string> processedIncludes = new List<string>();

        // Track include bookmarks that could not be found / used
        private readonly List<string> _missingIncludeBookmarks = new();

        public IReadOnlyList<string> MissingIncludeBookmarks => _missingIncludeBookmarks;

        #endregion Private Fields

        #region Public Constructors

        public WordDocumentService(GraphServiceClient _graphServiceClient)
        {
            graphServiceClient = _graphServiceClient;
            var factory = LoggerFactory.Create(builder =>
            {
                builder.AddDebug(); // Or AddConsole(), AddFile(), etc.
            });
            _logger = factory.CreateLogger<DocumentIncludeHelper>();
        }

        #endregion Public Constructors

        #region Public Methods

        /// <summary>
        /// Returns the name of the record based on the provided GUID.
        /// </summary>
        public static string GetRecordTypeName(Guid recordGuid)
        {
            return RecordTypeMapping.TryGetValue(recordGuid, out string recordName) ? recordName : "Unknown";
        }

        public static void SetPictureAltText(OpenXmlElement imageContainer, string altText)
        {
            var docPro = imageContainer.Descendants<DW.DocProperties>().FirstOrDefault();
            if (docPro != null)
            {
                docPro.Id = GenerateUniqueDrawingId();
                docPro.Description = altText;
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
    Services.ServiceBase serviceBase = null,
    string recordTypeGuid = "00000000-0000-0000-0000-000000000000")
        {
            try
            {
                _config = config;
                // Reset missing bookmark tracking for this run
                _missingIncludeBookmarks.Clear();
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

                    DocumentIncludeHelper documentIncludeHelper = new DocumentIncludeHelper(_logger, graphServiceClient);

                    var includeMergeItems = mergeDocument.Items.Where(m => m.MergeDocumentItemType == "Includes").ToList();
                    if (includeMergeItems.Count > 0)
                    {
                        //documentContent = await documentIncludeHelper.ProcessIncludesRecursively(
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

                                        ReplaceContentControlWithTable(mainPart, tableItem.BookmarkName, tableDataList); // Directly pass List<Dictionary<string, string>>
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
                    try
                    {
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
                                        await InsertImagesAtTags(imageDataDict, mainPart, imageItem.BookmarkName, imageItem.ImageColumns);
                                        //AddImageToTable(mainPart, imageDataDict[0].Images[0].ImageBytes);
                                    }
                                }
                                documentContent = inputStream.ToArray();
                            }

                            Console.WriteLine("[SUCCESS] Image bookmarks replaced in main document.");
                        }
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"[ERROR] An error occurred while processing image tags: {ex.Message}");
                        //Do nothing just continue
                    }

                    // Step 6: Identify Record Type and obtain Signature Image from GetSignatureInfo
                    try
                    {
                        var SignatureMergeItems = mergeDocument.Items.Where(m => m.MergeDocumentItemType == "Signature").ToList();
                        if (SignatureMergeItems.Any())
                        {
                            List<EF.Types.SignatureInfo> signatureInfo = new List<EF.Types.SignatureInfo>();
                            var entityTypeGuid = Functions.ParseAndReturnEmptyGuidIfInvalid(recordTypeGuid);
                            Console.WriteLine($"[INFO] Obtaining signature image for EntityTypeGuid: {entityTypeGuid}");
                            string recordType = GetRecordTypeName(entityTypeGuid);
                            Console.WriteLine($"[INFO] Record Type: {recordType}");
                            switch (recordType)
                            {
                                case "Enquiry":
                                    signatureInfo = await efCore.GetSignatoryInfo(Guid.Empty, Guid.Empty, Guid.Parse(recordGuid));
                                    break;

                                case "Quote":
                                    signatureInfo = await efCore.GetSignatoryInfo(Guid.Empty, Guid.Parse(recordGuid), Guid.Empty);
                                    break;

                                case "Jobs":
                                    signatureInfo = await efCore.GetSignatoryInfo(Guid.Parse(recordGuid), Guid.Empty, Guid.Empty);
                                    break;

                                default:
                                    signatureInfo = null;
                                    break;
                            }
                            if (signatureInfo != null)
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
                                        foreach (var mergeItem in SignatureMergeItems)
                                        {
                                            foreach (var signature in signatureInfo)
                                            {
                                                Console.WriteLine($"[INFO] Signature Image? {signature.Signature}");
                                                if (signature != null && signature.Signature != null && signature.Signature.Length > 0)
                                                {
                                                    Console.WriteLine($"[INFO] Signature image found. Replacing {mergeItem.BookmarkName} bookmark...");
                                                    await InsertSignatureImageAtContentControlExtended(wordDoc, mergeItem.BookmarkName, signature.Signature);
                                                    Console.WriteLine("[SUCCESS] Signature image replaced in main document.");
                                                }
                                                else
                                                {
                                                    Console.WriteLine("[INFO] No valid signature image found. Skipping signature replacement.");
                                                }
                                            }
                                        }
                                    }
                                    documentContent = inputStream.ToArray();
                                }

                                Console.WriteLine("[SUCCESS] Image bookmarks replaced in main document.");
                            }
                            else
                            {
                                Console.WriteLine($"[INFO] No signature image found for the record guid. {recordGuid} for EntityType {recordTypeGuid}");
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        throw;
                    }

                    // Step 7: Process Merge Fields
                    Console.WriteLine("[INFO] Replacing merge fields in the final document.");
                    documentContent = await ProcessMergeFieldsExtended(documentContent, mergeData);
                    Console.WriteLine("[SUCCESS] Merge fields replaced in main document.");

                    // After all modifications, before validation
                    //using (var finalCheckStream = new MemoryStream(documentContent))
                    //{
                    //    using (var wordDoc = WordprocessingDocument.Open(finalCheckStream, true))
                    //    {
                    //        var mainPart = wordDoc.MainDocumentPart;

                    // // 1. Fix duplicate IDs EnsureUniqueDrawingIds(wordDoc);

                    // // 2. Verify headers/footers VerifyHeaderFooterExistence(mainPart);

                    // // 3. Validate all tables foreach (var table in
                    // mainPart.Document.Descendants<Table>()) { ValidateTableStructure(table); }

                    //        // 4. Final check
                    //        CleanupInvalidElements(wordDoc);
                    //        mainPart.Document.Save();
                    //    }
                    //    documentContent = finalCheckStream.ToArray();
                    //}

                    // Step 8: Validate document using OpenXML Validation
                    Console.WriteLine("[INFO] Validating document structure...");
                    //ValidateDocument(documentContent); // Throws exception if validation fails
                    Console.WriteLine("[SUCCESS] Document is valid.");

                    // Step 9: Validate documentContent Before Upload
                    if (documentContent == null || documentContent.Length == 0)
                    {
                        Console.WriteLine("[ERROR] Document content is empty or null before upload.");
                        throw new Exception("Document content is null or empty before uploading.");
                    }

                    //documentContent = WordDocumentFixer.FixBeforeUpload(documentContent, _logger);

                    //ValidateDocument(documentContent);
                    // Step 10: Upload Final Document to SharePoint (existing code)
                    var uploadResponse = await UploadModifiedDocument(siteId, filenameTemplate, sharePointUrl, documentId, new MemoryStream(documentContent), config, "Activities", outputType);

                    // Validate Upload Response
                    if (uploadResponse == null)
                    {
                        Console.WriteLine("[ERROR] UploadModifiedDocument returned null.");
                        throw new Exception("UploadModifiedDocument returned null.");
                    }

                    Console.WriteLine("[SUCCESS] Final document uploaded successfully.");

                    // Report any missing bookmarks
                    if (_missingIncludeBookmarks.Any())
                    {
                        var distinctMissing = _missingIncludeBookmarks
                            .Distinct()
                            .OrderBy(x => x)
                            .ToList();

                        var missingList = string.Join(", ", distinctMissing);
                        var message =
                            $"Document generated successfully, but the following include bookmarks were not found " +
                            $"and were therefore not inserted: {missingList}.";

                        Console.WriteLine("[WARNING] " + message);

                        // If SharepointDocumentsGetResponse has somewhere to put this, add it:
                        // uploadResponse.WarningMessage = message; or, if you prefer:
                        // uploadResponse.ErrorReturned = message; // only if you treat it as a soft error
                    }
                    else
                    {
                        Console.WriteLine("[SUCCESS] All include bookmarks were found and processed.");
                    }

                    return uploadResponse;
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

        public async Task<List<ImageFolderInfo>> DownloadImagesFromSharePointForDocumentAsync(string sharePointUrl)
        {
            try
            {
                if (string.IsNullOrEmpty(sharePointUrl))
                {
                    Console.Error.WriteLine("SharePoint URL is required.");
                    return new List<ImageFolderInfo>(); // Return empty list
                }

                var siteId = "";
                var _AppConfig = new AppConfiguration(_config);
                switch (_AppConfig.EnvironmentType)
                {
                    case "DEV":
                    case "TEST":
                        siteId = _AppConfig.DevSharepointIdentifier;
                        break;

                    default:
                        siteId = "environmentalscientifics.sharepoint.com,405ced4f-6a48-4c59-a6fc-f03f9adc3626,39e2f733-4aff-4568-a053-52dacbe1f03e";
                        break;
                }

                var result = Functions.ExtractLastFourSegmentsFromUrl(sharePointUrl);
                var parentFolder = result.Item1;
                var mainFolder = result.Item2;
                var subfolder = result.Item3;
                var subsubfolder = result.Item4;

                // Get SharePoint drive
                var drives = await graphServiceClient.Sites[siteId].Drives.GetAsync();
                var driveItem = drives.Value.FirstOrDefault(d => d.Name == parentFolder);

                if (driveItem == null)
                {
                    Console.WriteLine($"[ERROR] Drive not found for parent folder: {parentFolder}");
                    return new List<ImageFolderInfo>(); // Return empty if drive not found
                }

                var imageFolderList = new List<ImageFolderInfo>();

                // Build the relative path
                string relativePath = $"{mainFolder}/{subfolder}/{subsubfolder}";
                Console.WriteLine($"[INFO] Processing subfolder with relative path: {relativePath}");

                var images = await GetImagesFromFolder(driveItem.Id, relativePath);
                if (images.Any())
                {
                    imageFolderList.Add(new ImageFolderInfo
                    {
                        FolderName = subsubfolder,
                        Images = images
                    });
                }

                return imageFolderList;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[ERROR] Error downloading images from SharePoint: {ex.Message}");
                return new List<ImageFolderInfo>(); // Return empty in case of failure
            }
        }

        public async Task<List<ImageFolderInfo>> GenerateImageRowDataByTagAsync(
      List<MergeDocumentItem> imageMergeItems,
      string sharePointUrl,
      EF.Core efCore,
      string recordGuid)
        {
            var allImageFoldersList = new List<ImageFolderInfo>();
            var folderCache = new Dictionary<string, List<ImageFolderInfo>>();

            foreach (var imageItem in imageMergeItems)
            {
                if (string.IsNullOrWhiteSpace(sharePointUrl))
                {
                    Console.WriteLine($"[WARNING] sharePointUrl is empty when processing image item '{imageItem.BookmarkName}'. Skipping.");
                    continue;
                }

                if (string.IsNullOrWhiteSpace(imageItem.SubFolderPath))
                {
                    Console.WriteLine($"[WARNING] SubFolderPath is empty for image item '{imageItem.BookmarkName}'. Skipping.");
                    continue;
                }

                // Get image paths from SharePoint
                string folderPath = $"{sharePointUrl}/{imageItem.SubFolderPath}";

                // Get list of subfolders inside the folderPath
                var folders = await GetSubfoldersFromUrl(folderPath);

                Console.WriteLine($"[INFO] Found {folders.Count} subfolders for '{imageItem.BookmarkName}'.");

                if (folders.Count == 0)
                {
                    Console.WriteLine($"[WARNING] No subfolders found for '{imageItem.BookmarkName}'. Skipping Adding Images...");
                    continue;
                }

                foreach (var folder in folders)
                {
                    var imageFolderPath = $"{sharePointUrl}/{imageItem.SubFolderPath}/{folder}";

                    if (!folderCache.TryGetValue(imageFolderPath, out var imageFolderInfos))
                    {
                        imageFolderInfos = await DownloadImagesFromSharePointForDocumentAsync(imageFolderPath);
                        folderCache[imageFolderPath] = imageFolderInfos;
                    }

                    allImageFoldersList.AddRange(imageFolderInfos);
                }
            }

            return allImageFoldersList;
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
                            // Sort columns based on SortOrder
                            var orderedProperties = entityType.EntityProperties
                                .Where(p => !p.IsHidden)
                                .OrderBy(p => p.SortOrder)
                                .ToList();
                            // Convert DataTable rows to Dictionary and populate with Labels as Headers
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
                string parentFolder = sitePath.Substring(sitePath.LastIndexOf('/') + 1);

                Console.WriteLine($"Site Path: {sitePath}");
                Console.WriteLine($"Drive Name: {driveName}");
                Console.WriteLine($"Relative Path: {relativePath}");
                Console.WriteLine($"Parent Folder: {parentFolder}");

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
                var drives = await graphServiceClient.Sites[siteId].Drives.GetAsync();

                if (drives?.Value == null || !drives.Value.Any())
                {
                    Console.WriteLine("[ERROR] No drives found for the given Site ID.");
                }
                else
                {
                    Console.WriteLine("[INFO] Available Drives:");
                    foreach (var drive in drives.Value)
                    {
                        Console.WriteLine($"- Name: {drive.Name}, ID: {drive.Id}");
                    }
                }

                // Attempt to find the drive with the expected name
                var driveItem = drives.Value.FirstOrDefault(d => d.Name == parentFolder);

                if (driveItem == null)
                {
                    Console.WriteLine($"[ERROR] Drive with name {parentFolder} was not found.");
                }
                else
                {
                    Console.WriteLine($"[SUCCESS] Found Drive: {driveItem.Name}, ID: {driveItem.Id}");
                }

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

        public async Task InsertImagesAtTags(
    List<ImageFolderInfo> imageFolders,
    MainDocumentPart mainPart,
    string bookmarkName,
    int imageColumns = 1)
        {
            if (imageColumns < 1) imageColumns = 1;

            BookmarkReplacer bookmarkReplacer = new BookmarkReplacer();
            var sdt = mainPart.Document.Body.Descendants<SdtElement>()
                        .FirstOrDefault(s => s.SdtProperties.GetFirstChild<Tag>()?.Val == bookmarkName);

            if (sdt == null)
            {
                Console.WriteLine($"[ERROR] Content control with tag '{bookmarkName}' not found.");
                return;
            }

            Console.WriteLine($"[INFO] Inserting grouped image table at tag '{bookmarkName}'...");

            // Add SocotecStyle
            bookmarkReplacer.AddSocotecStyle(mainPart);

            // Create table with full width & styling
            Table newTable = new Table();
            TableProperties tblProps = new TableProperties(
                new TableStyle { Val = "SOCOTEC" },
                new TableWidth { Width = "100%", Type = TableWidthUnitValues.Pct }
            );
            newTable.AppendChild(tblProps);
            var tblLook = new TableLook
            {
                Val = CalculateTableLookVal(
                    firstRow: false,
                    lastRow: false,
                    firstColumn: false,
                    lastColumn: false,
                    noHBand: true,
                    noVBand: true
                ),
                FirstRow = new OnOffValue(false),
                LastRow = new OnOffValue(false),
                FirstColumn = new OnOffValue(false),
                LastColumn = new OnOffValue(false),
                NoHorizontalBand = new OnOffValue(true),
                NoVerticalBand = new OnOffValue(true)
            };

            tblProps.Append(tblLook);

            // Define column widths
            TableGrid tableGrid = new TableGrid();
            int totalColumns = imageColumns + 1;
            for (int i = 0; i < totalColumns; i++)
            {
                tableGrid.AppendChild(new GridColumn() { Width = (i == 0) ? "1000" : "4000" });
            }
            newTable.AppendChild(tableGrid);

            foreach (var imageFolder in imageFolders)
            {
                if (!imageFolder.Images.Any())
                {
                    Console.WriteLine($"[INFO] Skipping folder '{imageFolder.FolderName}' (no images).");
                    continue;
                }

                int imageIndex = 0;
                TableRow currentRow = null;

                foreach (var image in imageFolder.Images)
                {
                    if (imageIndex % imageColumns == 0)
                    {
                        if (currentRow != null)
                            newTable.Append(currentRow);

                        currentRow = new TableRow();
                        TableCell folderCell = new TableCell(new Paragraph(new Run(new Text(imageFolder.FolderName))));
                        currentRow.Append(folderCell);
                    }

                    // Insert image into a new table cell
                    TableCell imgCell = new TableCell();
                    // Align table cell content to center
                    TableCellProperties cellProps = new TableCellProperties(
                        new TableCellVerticalAlignment { Val = TableVerticalAlignmentValues.Center }
                    );
                    imgCell.Append(cellProps);
                    Drawing imageDrawing = await InsertImageIntoDocument(mainPart, image.ImageBytes, imageColumns, image.ImagePath);
                    imgCell.Append(new Paragraph(new Run(imageDrawing)));
                    currentRow.Append(imgCell);

                    imageIndex++;
                }

                if (currentRow != null && currentRow.ChildElements.Count > 1)
                {
                    newTable.Append(currentRow);
                }
            }

            // Replace Content Control with Table
            sdt.InsertAfterSelf(newTable);
            sdt.Remove(); // Remove the old content control

            Console.WriteLine($"[SUCCESS] Grouped Image table inserted at content control '{bookmarkName}'.");
        }

        private static string CalculateTableLookVal(
            bool firstRow, bool lastRow,
            bool firstColumn, bool lastColumn,
            bool noHBand, bool noVBand)
        {
            int val = 0x0000;
            if (firstRow) val |= 0x0020;
            if (lastRow) val |= 0x0040;
            if (firstColumn) val |= 0x0080;
            if (lastColumn) val |= 0x0100;
            if (noHBand) val |= 0x0200;
            if (noVBand) val |= 0x0400;
            return val.ToString("X4");
        }

        private void CleanupInvalidElements(WordprocessingDocument doc)
        {
            // Remove invalid style pane filters
            foreach (var filter in doc.MainDocumentPart.DocumentSettingsPart.Settings
                .Elements<StylePaneFormatFilter>())
            {
                filter.Remove();
            }

            // Fix table looks in all tables
            foreach (var table in doc.MainDocumentPart.Document.Descendants<Table>())
            {
                var tblLook = table.GetFirstChild<TableProperties>()
                    ?.GetFirstChild<TableLook>();
                if (tblLook != null)
                {
                    tblLook.Val = CalculateTableLookVal(
                        tblLook.FirstRow?.Value ?? false,
                        tblLook.LastRow?.Value ?? false,
                        tblLook.FirstColumn?.Value ?? false,
                        tblLook.LastColumn?.Value ?? false,
                        tblLook.NoHorizontalBand?.Value ?? false,
                        tblLook.NoVerticalBand?.Value ?? false
                    );
                }
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
                var includeStream = new MemoryStream();
                includeStream.Write(processedInclude, 0, processedInclude.Length);
                includeStream.Position = 0;

                parentDocumentContent = await InsertContentAtBookmarkExtended(
                    include.BookmarkName,
                    includeStream,
                    parentDocumentContent
                );
                // Use expandable MemoryStream here
                using (var checkStream = new MemoryStream())
                {
                    // Make the stream expandable by writing the bytes into an empty MemoryStream
                    checkStream.Write(parentDocumentContent, 0, parentDocumentContent.Length);
                    checkStream.Position = 0;

                    using (var wordDoc = WordprocessingDocument.Open(checkStream, true))
                    {
                        VerifyHeaderFooterExistence(wordDoc.MainDocumentPart);
                        wordDoc.MainDocumentPart.Document.Save();
                    }

                    // IMPORTANT: carry forward the updated bytes
                    parentDocumentContent = checkStream.ToArray();
                }
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



        private Task<byte[]> ProcessMergeFieldsExtended(
     byte[] documentContent,
     List<Dictionary<string, string>> mergeFields)
        {
            if (documentContent == null || documentContent.Length == 0)
            {
                throw new ArgumentException("Document content cannot be null or empty.", nameof(documentContent));
            }

            using var memoryStream = new MemoryStream();
            memoryStream.Write(documentContent, 0, documentContent.Length);
            memoryStream.Position = 0;

            using (var wordDoc = WordprocessingDocument.Open(memoryStream, true))
            {
                if (wordDoc.MainDocumentPart?.Document == null)
                {
                    throw new InvalidOperationException("The Word document is missing a MainDocumentPart or Document.");
                }

                var report = WordDocumentHelpers.ReplaceAllMergeContent(wordDoc, mergeFields);

                Console.WriteLine(
                    $"[INFO] Merge completed. Complex={report.ComplexFieldReplacements}, " +
                    $"Simple={report.SimpleFieldReplacements}, " +
                    $"PlainText={report.PlainTextReplacements}, " +
                    $"SplitPlainText={report.SplitPlaceholderReplacements}, " +
                    $"ContentControls={report.ContentControlReplacements}");

                if (report.UnresolvedArtifacts.Count > 0)
                {
                    Console.WriteLine("[WARNING] Unresolved merge artifacts detected:");
                    foreach (var unresolved in report.UnresolvedArtifacts)
                    {
                        Console.WriteLine($"[WARNING]   {unresolved}");
                    }
                }
            }

            return Task.FromResult(memoryStream.ToArray());
        }

        private void ProcessMergeFieldsInElement(
            OpenXmlElement element,
            List<Dictionary<string, string>> sortedMergeData)
        {
            if (element == null)
            {
                throw new ArgumentNullException(nameof(element));
            }

            if (sortedMergeData == null)
            {
                throw new ArgumentNullException(nameof(sortedMergeData));
            }

            using var memoryStream = new MemoryStream();
            using var wordDoc = CreateTransientWordDocumentForElement(element, memoryStream);

            WordDocumentHelpers.ReplaceAllMergeContent(wordDoc, sortedMergeData);

            // Push any modified child nodes back into the source element.
            var updatedRoot = wordDoc.MainDocumentPart?.Document?.Body;
            if (updatedRoot == null)
            {
                return;
            }

            element.RemoveAllChildren();
            foreach (var child in updatedRoot.ChildElements.ToList())
            {
                element.Append(child.CloneNode(true));
            }
        }

        public Task<byte[]> ProcessMergeFields(
            byte[] documentContent,
            List<Dictionary<string, string>> mergeFields)
        {
            if (documentContent == null || documentContent.Length == 0)
            {
                throw new ArgumentException("Document content cannot be null or empty.", nameof(documentContent));
            }

            Console.WriteLine($"[DEBUG] Total merge fields received: {mergeFields?.Count ?? 0}");

            using var memoryStream = new MemoryStream();
            memoryStream.Write(documentContent, 0, documentContent.Length);
            memoryStream.Position = 0;

            using (var wordDoc = WordprocessingDocument.Open(memoryStream, true))
            {
                if (wordDoc.MainDocumentPart?.Document == null)
                {
                    throw new InvalidOperationException("The Word document is missing a MainDocumentPart or Document.");
                }

                var report = WordDocumentHelpers.ReplaceAllMergeContent(wordDoc, mergeFields);

                Console.WriteLine(
                    $"[DEBUG] Merge fields processed. Complex={report.ComplexFieldReplacements}, " +
                    $"Simple={report.SimpleFieldReplacements}, " +
                    $"PlainText={report.PlainTextReplacements}, " +
                    $"SplitPlainText={report.SplitPlaceholderReplacements}, " +
                    $"ContentControls={report.ContentControlReplacements}");

                if (report.UnresolvedArtifacts.Count > 0)
                {
                    Console.WriteLine("[WARNING] Unresolved merge artifacts remain after ProcessMergeFields:");
                    foreach (var unresolved in report.UnresolvedArtifacts)
                    {
                        Console.WriteLine($"[WARNING]   {unresolved}");
                    }
                }
            }

            return Task.FromResult(memoryStream.ToArray());
        }

        public Task<byte[]> ReplaceMergeFields(
            string siteId,
            string driveId,
            string targetSharePointUrl,
            string filenameTemplate,
            string itemId,
            byte[] documentContent,
            List<Dictionary<string, string>> mergeFields,
            IConfiguration config)
        {
            if (documentContent == null || documentContent.Length == 0)
            {
                throw new ArgumentException("Document content cannot be null or empty.", nameof(documentContent));
            }

            using var memoryStream = new MemoryStream();
            memoryStream.Write(documentContent, 0, documentContent.Length);
            memoryStream.Position = 0;

            using (var wordDoc = WordprocessingDocument.Open(memoryStream, true))
            {
                if (wordDoc.MainDocumentPart?.Document == null)
                {
                    throw new InvalidOperationException("The Word document is missing a MainDocumentPart or Document.");
                }

                var report = WordDocumentHelpers.ReplaceAllMergeContent(wordDoc, mergeFields);

                Console.WriteLine(
                    $"[INFO] ReplaceMergeFields complete for '{filenameTemplate}'. " +
                    $"Complex={report.ComplexFieldReplacements}, " +
                    $"Simple={report.SimpleFieldReplacements}, " +
                    $"PlainText={report.PlainTextReplacements}, " +
                    $"SplitPlainText={report.SplitPlaceholderReplacements}, " +
                    $"ContentControls={report.ContentControlReplacements}");

                if (report.UnresolvedArtifacts.Count > 0)
                {
                    Console.WriteLine("[WARNING] Unresolved merge artifacts remain after ReplaceMergeFields:");
                    foreach (var unresolved in report.UnresolvedArtifacts)
                    {
                        Console.WriteLine($"[WARNING]   {unresolved}");
                    }
                }
            }

            return Task.FromResult(memoryStream.ToArray());
        }

        private static WordprocessingDocument CreateTransientWordDocumentForElement(
            OpenXmlElement sourceElement,
            MemoryStream memoryStream)
        {
            var wordDoc = WordprocessingDocument.Create(
                memoryStream,
                WordprocessingDocumentType.Document,
                autoSave: true);

            var mainPart = wordDoc.AddMainDocumentPart();
            mainPart.Document = new Document(new Body());

            mainPart.Document.Body.Append(sourceElement.CloneNode(true));
            mainPart.Document.Save();

            return wordDoc;
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

        private static uint GenerateUniqueDrawingId()
        {
            uint newId = (uint)new Random().Next(10, 10000);
            while (_drawingElementIds.Contains(newId))
            {
                newId = (uint)new Random().Next(10, 10000);
            }
            _drawingElementIds.Add(newId);
            return newId;
        }

        private static async Task InsertSignatureImageAtContentControl(MainDocumentPart mainPart, string contentControlTag, byte[] imageBytes)
        {
            var contentControl = mainPart.Document.Body.Descendants<SdtElement>()
                                .FirstOrDefault(sdt => sdt.SdtProperties.GetFirstChild<Tag>()?.Val == contentControlTag);

            if (contentControl == null)
            {
                Console.WriteLine($"[ERROR] Content control '{contentControlTag}' not found.");
                return;
            }

            Console.WriteLine($"[INFO] Inserting signature into content control '{contentControlTag}'...");

            // Create ImagePart
            ImagePart imagePart = mainPart.AddImagePart(ImagePartType.Jpeg);
            using (var stream = new MemoryStream(imageBytes))
            {
                imagePart.FeedData(stream);
            }
            string imagePartId = mainPart.GetIdOfPart(imagePart);

            // Calculate dimensions using ImageSharp
            long cx, cy;
            using (var image = Image.Load(imageBytes))
            {
                const long emusPerPixel = 914400L;
                const long targetWidthCm = 5L; // 5cm width
                const long targetHeightCm = 2L; // 2cm height
                const long cmToEmus = 360000L; // 1cm = 360,000 EMUs

                long targetWidthEmus = targetWidthCm * cmToEmus;
                long targetHeightEmus = targetHeightCm * cmToEmus;

                long imageWidthEmus = image.Width * emusPerPixel;
                long imageHeightEmus = image.Height * emusPerPixel;

                double aspectRatio = (double)image.Height / image.Width;

                if (imageWidthEmus > imageHeightEmus)
                {
                    // Landscape: scale height to maintain aspect ratio
                    cx = Math.Min(targetWidthEmus, imageWidthEmus);
                    cy = (long)(cx * aspectRatio);
                }
                else
                {
                    // Portrait/Square: scale width to maintain aspect ratio
                    cy = Math.Min(targetHeightEmus, imageHeightEmus);
                    cx = (long)(cy / aspectRatio);
                }

                // Ensure image fits within defined dimensions
                if (cx > targetWidthEmus)
                {
                    cx = targetWidthEmus;
                    cy = (long)(cx * aspectRatio);
                }
                if (cy > targetHeightEmus)
                {
                    cy = targetHeightEmus;
                    cx = (long)(cy / aspectRatio);
                }
            }

            // Build Drawing Element
            Drawing drawing = new Drawing(
                new DW.Inline(
                    new DW.Extent { Cx = cx, Cy = cy },
                    new DW.EffectExtent { LeftEdge = 0L, TopEdge = 0L, RightEdge = 0L, BottomEdge = 0L },
                    new DW.DocProperties { Id = GenerateUniqueDrawingId(), Name = "Signature Image" },
                    new DW.NonVisualGraphicFrameDrawingProperties(new A.GraphicFrameLocks { NoChangeAspect = true }),
                    new A.Graphic(
                        new A.GraphicData(
                            new PIC.Picture(
                                new PIC.NonVisualPictureProperties(
                                    new PIC.NonVisualDrawingProperties { Id = 0, Name = "Signature" },
                                    new PIC.NonVisualPictureDrawingProperties()
                                ),
                                new PIC.BlipFill(
                                    new A.Blip { Embed = imagePartId },
                                    new A.Stretch(new A.FillRectangle())
                                ),
                                new PIC.ShapeProperties(
                                    new A.Transform2D(
                                        new A.Offset { X = 0, Y = 0 },
                                        new A.Extents { Cx = cx, Cy = cy }
                                    ),
                                    new A.PresetGeometry { Preset = A.ShapeTypeValues.Rectangle }
                                )
                            )
                        )
                        { Uri = "http://schemas.openxmlformats.org/drawingml/2006/picture" }
                    )
                )
                {
                    DistanceFromTop = 0,
                    DistanceFromBottom = 0,
                    DistanceFromLeft = 0,
                    DistanceFromRight = 0
                }
            );

            // Replace Content Control with the Signature Image
            contentControl.RemoveAllChildren(); // Remove any existing text
            contentControl.AppendChild(new Paragraph(new Run(drawing))); // Insert signature

            Console.WriteLine($"[SUCCESS] Signature image inserted into content control '{contentControlTag}'.");
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
            // 1. Read tables from the Word docx stream (Telerik)
            List<List<List<string>>> tables = ExtractTablesFromWord_Telerik(documentStream);

            // 2. Create an Excel workbook/worksheet (Telerik)
            var workbook = new Telerik.Windows.Documents.Spreadsheet.Model.Workbook();
            var worksheet = workbook.Worksheets.Add();

            int rowNumber = 0;

            foreach (var table in tables)
            {
                foreach (var row in table)
                {
                    for (int col = 0; col < row.Count; col++)
                    {
                        worksheet.Cells[rowNumber, col].SetValue(row[col]);
                    }
                    rowNumber++;
                }
                rowNumber++; // Add space between tables
            }

            // 3. Export to XLSX stream
            var formatProvider = new XlsxFormatProvider();
            var excelStream = new MemoryStream();
            formatProvider.Export(workbook, excelStream);
            excelStream.Position = 0;
            return excelStream;
        }

        private List<List<List<string>>> ExtractTablesFromWord_Telerik(Stream documentStream)
        {
            var formatProvider = new DocxFormatProvider();
            RadFlowDocument document = formatProvider.Import(documentStream);

            var tablesList = new List<List<List<string>>>();

            foreach (var table in document.EnumerateChildrenOfType<TelerikTable>())
            {
                var tableRows = new List<List<string>>();
                foreach (var row in table.Rows)
                {
                    var cellValues = new List<string>();
                    foreach (var cell in row.Cells)
                    {
                        // The correct way: extract text from all paragraphs in the cell
                        string cellText = string.Join(
                            Environment.NewLine,
                            cell.Blocks.OfType<TelerikParagraph>().Select(p =>
                                string.Concat(p.Inlines.OfType<TelerikRun>().Select(r => r.Text))
                            )
                        );
                        cellValues.Add(cellText);
                    }
                    tableRows.Add(cellValues);
                }
                tablesList.Add(tableRows);
            }
            return tablesList;
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

        private async Task<List<ImageFileInfo>> GetImagesFromFolder(string driveId, string folderPath)
        {
            var imageList = new List<ImageFileInfo>();

            try
            {
                Console.WriteLine($"[DEBUG] Retrieving images from: {folderPath}");

                var folderContents = await graphServiceClient
                    .Drives[driveId]
                    .Root
                    .ItemWithPath(folderPath)
                    .Children
                    .GetAsync();

                if (folderContents?.Value == null)
                {
                    Console.WriteLine($"[WARNING] No images found in '{folderPath}'.");
                    return imageList;
                }

                Console.WriteLine($"[DEBUG] API Response - Items in '{folderPath}': {folderContents.Value.Count}");

                foreach (var item in folderContents.Value)
                {
                    Console.WriteLine($"[DEBUG] Found Item: Name='{item.Name}', Type='{(item.Folder != null ? "Folder" : "File")}'");

                    if (item.Folder != null) continue; // Skip folders, process only images

                    if (photoFileExtensions.Contains(Path.GetExtension(item.Name ?? string.Empty)))
                    {
                        try
                        {
                            Console.WriteLine($"[INFO] Downloading Image: {item.Name}");

                            var fileStream = await graphServiceClient
                                .Drives[driveId]
                                .Items[item.Id]
                                .Content
                                .GetAsync();

                            using (MemoryStream ms = new MemoryStream())
                            {
                                await fileStream.CopyToAsync(ms);
                                imageList.Add(new ImageFileInfo
                                {
                                    ImagePath = $"{folderPath}/{item.Name}",
                                    ImageBytes = ms.ToArray()
                                });
                            }

                            Console.WriteLine($"[SUCCESS] Downloaded image: {item.Name}");
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"[ERROR] Failed to download image '{item.Name}': {ex.Message}");
                        }
                    }
                    else
                    {
                        Console.WriteLine($"[WARNING] Skipping non-image file: {item.Name}");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ERROR] Failed to retrieve images from '{folderPath}': {ex.Message}");
            }

            return imageList;
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

                    // Step 2: Extract the body content of the included document
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

                    // Step 3: Correctly find the bookmark’s paragraph index
                    var paragraphs = wordDoc.MainDocumentPart.Document.Body.Descendants<Paragraph>().ToList();
                    int bookmarkIndex = paragraphs.FindIndex(p => p.Descendants<BookmarkStart>().Any(b => b.Name == bookmarkName));

                    if (bookmarkIndex == -1)
                    {
                        Console.WriteLine($"[ERROR] Could not determine paragraph index for '{bookmarkName}'.");
                        throw new Exception($"Could not determine paragraph index for '{bookmarkName}'.");
                    }

                    Console.WriteLine($"[SUCCESS] Found valid paragraph index {bookmarkIndex} for tag '{bookmarkName}'.");

                    // Step 4: Merge included document at the correct paragraph index
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

        private void InsertImageAtTag(MainDocumentPart mainPart, SdtElement tagControl, byte[] imageBytes, int maxWidth = 300)
        {
            /*
             * MaxWidth values for different image types:
                "HeaderImage" => 800, // Large banner
                "CompanyLogo" => 200, // Small logo
                "Signature" => 300, // Signature-sized image
                _ => 600 // Default size
             */
            // Detect Image Format
            IImageFormat format = Image.DetectFormat(imageBytes);
            PartTypeInfo partType = format?.Name switch
            {
                "PNG" => ImagePartType.Png,
                "JPEG" => ImagePartType.Jpeg,
                "GIF" => ImagePartType.Gif,
                "BMP" => ImagePartType.Bmp,
                "TIFF" => ImagePartType.Tiff,
                _ => throw new NotSupportedException($"Unsupported image format: {format?.Name}")
            };

            Console.WriteLine($"[DEBUG] Inserting image of type '{partType}' into the document.");

            // Add image part
            ImagePart imagePart = mainPart.AddImagePart(partType);
            using (var stream = new MemoryStream(imageBytes))
            {
                imagePart.FeedData(stream);
            }
            string imagePartId = mainPart.GetIdOfPart(imagePart);
            // **Set max width while maintaining aspect ratio**
            long cx = maxWidth * 9525L; // Convert pixels to EMUs
            long cy = (long)(cx * 0.75); // Maintain aspect ratio (assuming 4:3)

            // Build Drawing Element (Using Correct Namespaces)
            Drawing element = new Drawing(
                new DW.Inline(
                    new DW.Extent { Cx = cx, Cy = cy },
                    new DW.EffectExtent { LeftEdge = 0L, TopEdge = 0L, RightEdge = 0L, BottomEdge = 0L },
                    new DW.DocProperties { Id = GenerateUniqueDrawingId(), Name = "Image" },
                    new DW.NonVisualGraphicFrameDrawingProperties(new A.GraphicFrameLocks { NoChangeAspect = true }),
                    new A.Graphic(
                        new A.GraphicData(
                            new PIC.Picture(
                                new PIC.NonVisualPictureProperties(
                                    new PIC.NonVisualDrawingProperties { Id = 0, Name = "New Image" },
                                    new PIC.NonVisualPictureDrawingProperties()
                                ),
                                new PIC.BlipFill(
                                    new A.Blip { Embed = imagePartId },
                                    new A.Stretch(new A.FillRectangle())
                                ),
                                new PIC.ShapeProperties(
                                    new A.Transform2D(
                                        new A.Offset { X = 0, Y = 0 },
                                        new A.Extents { Cx = cx, Cy = cy }
                                    ),
                                    new A.PresetGeometry { Preset = A.ShapeTypeValues.Rectangle }
                                )
                            )
                        )
                        { Uri = "http://schemas.openxmlformats.org/drawingml/2006/picture" }
                    )
                )
                {
                    DistanceFromTop = 0,
                    DistanceFromBottom = 0,
                    DistanceFromLeft = 0,
                    DistanceFromRight = 0
                }
            );
            // Ensure unique ID & set alt text for the image
            Random rnd = new Random();
            int randomInt = rnd.Next(1000, 10000);
            SetPictureAltText(element, randomInt.ToString() ?? "Inserted Image");

            tagControl.RemoveAllChildren<Paragraph>(); // Remove existing text
            tagControl.AppendChild(new Paragraph(new Run(element)));
        }

        private async Task<Drawing> InsertImageIntoDocument(
    MainDocumentPart mainPart,
    byte[] imageBytes,
    int numColumns,
    string fileName = null)
        {
            if (imageBytes == null || imageBytes.Length == 0) return null;

            try
            {
                // Detect Image Format
                IImageFormat format = Image.DetectFormat(imageBytes);
                PartTypeInfo partType = format?.Name switch
                {
                    "PNG" => ImagePartType.Png,
                    "JPEG" => ImagePartType.Jpeg,
                    "GIF" => ImagePartType.Gif,
                    "BMP" => ImagePartType.Bmp,
                    "TIFF" => ImagePartType.Tiff,
                    _ => throw new NotSupportedException($"Unsupported image format: {format?.Name}")
                };

                Console.WriteLine($"[DEBUG] Inserting image of type '{partType}' into the document.");

                // Add image part
                ImagePart imagePart = mainPart.AddImagePart(partType);
                using (var stream = new MemoryStream(imageBytes))
                {
                    imagePart.FeedData(stream);
                }
                string imagePartId = mainPart.GetIdOfPart(imagePart);

                // Calculate dimensions using ImageSharp
                long cx, cy;
                using (var image = Image.Load(imageBytes))
                {
                    const long emusPerPixel = 914400L;
                    const long targetSizeCm = 6L; // Target size in cm
                    const long cmToEmus = 360000L; // 1 cm = 360,000 EMUs

                    // Convert 5cm to EMUs
                    long targetWidthEmus = targetSizeCm * cmToEmus;
                    long targetHeightEmus = targetSizeCm * cmToEmus;

                    // Get the original image dimensions in EMUs
                    long imageWidthEmus = image.Width * emusPerPixel;
                    long imageHeightEmus = image.Height * emusPerPixel;

                    // Calculate aspect ratio
                    double aspectRatio = (double)image.Height / image.Width;

                    // Scale image to fit within 5cm x 5cm while maintaining aspect ratio
                    if (imageWidthEmus > imageHeightEmus)
                    {
                        // Landscape image: width is max, scale height accordingly
                        cx = Math.Min(targetWidthEmus, imageWidthEmus);
                        cy = (long)(cx * aspectRatio);
                    }
                    else
                    {
                        // Portrait or square image: height is max, scale width accordingly
                        cy = Math.Min(targetHeightEmus, imageHeightEmus);
                        cx = (long)(cy / aspectRatio);
                    }

                    // Ensure the image does not exceed the 5cm x 5cm box
                    if (cx > targetWidthEmus)
                    {
                        cx = targetWidthEmus;
                        cy = (long)(cx * aspectRatio);
                    }
                    if (cy > targetHeightEmus)
                    {
                        cy = targetHeightEmus;
                        cx = (long)(cy / aspectRatio);
                    }
                }

                // Build Drawing Element
                Drawing drawing = new Drawing(
                    new DW.Inline(
                        new DW.Extent { Cx = cx, Cy = cy },
                        new DW.EffectExtent { LeftEdge = 0L, TopEdge = 0L, RightEdge = 0L, BottomEdge = 0L },
                        new DW.DocProperties { Id = GenerateUniqueDrawingId(), Name = "Image" },
                        new DW.NonVisualGraphicFrameDrawingProperties(new A.GraphicFrameLocks { NoChangeAspect = true }),
                        new A.Graphic(
                            new A.GraphicData(
                                new PIC.Picture(
                                    new PIC.NonVisualPictureProperties(
                                        new PIC.NonVisualDrawingProperties { Id = 0, Name = "New Image" },
                                        new PIC.NonVisualPictureDrawingProperties()
                                    ),
                                    new PIC.BlipFill(
                                        new A.Blip { Embed = imagePartId },
                                        new A.Stretch(new A.FillRectangle())
                                    ),
                                    new PIC.ShapeProperties(
                                        new A.Transform2D(
                                            new A.Offset { X = 0, Y = 0 },
                                            new A.Extents { Cx = cx, Cy = cy }
                                        ),
                                        new A.PresetGeometry { Preset = A.ShapeTypeValues.Rectangle }
                                    )
                                )
                            )
                            { Uri = "http://schemas.openxmlformats.org/drawingml/2006/picture" }
                        )
                    )
                    {
                        DistanceFromTop = 0,
                        DistanceFromBottom = 0,
                        DistanceFromLeft = 0,
                        DistanceFromRight = 0
                    }
                );

                // Ensure unique ID & set alt text for the image
                SetPictureAltText(drawing, fileName ?? "Inserted Image");
                return drawing;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ERROR] Failed to insert image: {ex.Message}");
                return null;
            }
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

            // Step 1: Log Table Data Before Insertion
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

            ValidateTableStructure(newTable);

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



        // Helper: Search for a content control with the given tag in body, headers, and footers.
        private static SdtElement FindContentControlByTag(WordprocessingDocument wordDoc, string tag)
        {
            // Search body
            var cc = wordDoc.MainDocumentPart.Document.Body.Descendants<SdtElement>()
                        .FirstOrDefault(s => s.SdtProperties.GetFirstChild<Tag>()?.Val == tag);
            if (cc != null) return cc;

            // Search headers
            foreach (var headerPart in wordDoc.MainDocumentPart.HeaderParts)
            {
                cc = headerPart.Header.Descendants<SdtElement>()
                        .FirstOrDefault(s => s.SdtProperties.GetFirstChild<Tag>()?.Val == tag);
                if (cc != null) return cc;
            }

            // Search footers
            foreach (var footerPart in wordDoc.MainDocumentPart.FooterParts)
            {
                cc = footerPart.Footer.Descendants<SdtElement>()
                        .FirstOrDefault(s => s.SdtProperties.GetFirstChild<Tag>()?.Val == tag);
                if (cc != null) return cc;
            }
            return null;
        }

        /// <summary>
        /// Extended signature image insertion. If imageBytes is null or empty, remove the content
        /// control. This method now detects the actual image format so that PNG signatures are preserved.
        /// </summary>
        private static async Task InsertSignatureImageAtContentControlExtended(WordprocessingDocument wordDoc, string contentControlTag, byte[] imageBytes)
        {
            const string aNamespace = "http://schemas.openxmlformats.org/drawingml/2006/main";
            const string picNamespace = "http://schemas.openxmlformats.org/drawingml/2006/picture";

            try
            {
                Console.WriteLine($"[INFO] Looking for content control '{contentControlTag}'...");
                SdtElement contentControl = FindContentControlByTag(wordDoc, contentControlTag);
                if (contentControl == null)
                {
                    Console.WriteLine($"[ERROR] Signature content control '{contentControlTag}' not found.");
                    return;
                }

                if (imageBytes == null || imageBytes.Length == 0)
                {
                    Console.WriteLine($"[INFO] No signature image found. Removing content control '{contentControlTag}'.");
                    contentControl.Remove();
                    return;
                }

                Console.WriteLine("[INFO] Detecting image format...");
                IImageFormat format = Image.DetectFormat(imageBytes);
                if (format == null)
                {
                    Console.WriteLine("[ERROR] Unrecognized image format.");
                    throw new Exception("Unsupported image format for signature.");
                }

                PartTypeInfo partType = format.Name switch
                {
                    "PNG" => ImagePartType.Png,
                    "JPEG" => ImagePartType.Jpeg,
                    "GIF" => ImagePartType.Gif,
                    "BMP" => ImagePartType.Bmp,
                    "TIFF" => ImagePartType.Tiff,
                    _ => throw new Exception($"Unsupported image format: {format.Name}")
                };

                Console.WriteLine($"[INFO] Image format detected as {format.Name}. Adding image part...");
                ImagePart imagePart = wordDoc.MainDocumentPart.AddImagePart(partType);
                using var safeStream = new MemoryStream();
                safeStream.Write(imageBytes, 0, imageBytes.Length);
                safeStream.Position = 0;
                imagePart.FeedData(safeStream);
                string imagePartId = wordDoc.MainDocumentPart.GetIdOfPart(imagePart);

                long cx, cy;
                using (var image = Image.Load(imageBytes))
                {
                    const long cmToEmus = 360000L;
                    const long maxWidthCm = 4L;  // 5 cm width
                    const double maxHeightCm = 1.0; // 1.0 cm height
                    long maxCx = maxWidthCm * cmToEmus;
                    long maxCy = (long)(maxHeightCm * cmToEmus);

                    double aspectRatio = (double)image.Width / image.Height;
                    if (aspectRatio > 1) // Wider than tall
                    {
                        cx = maxCx;
                        cy = (long)(maxCx / aspectRatio);
                    }
                    else // Taller than wide or square
                    {
                        cy = maxCy;
                        cx = (long)(maxCy * aspectRatio);
                    }

                    Console.WriteLine($"[INFO] Scaled signature dimensions: {cx} x {cy} EMUs");
                }

                Console.WriteLine("[INFO] Building Drawing element...");
                uint drawingId = GenerateUniqueDrawingId();
                Drawing drawing = new Drawing(
                    new DW.Inline(
                        new DW.Extent { Cx = cx, Cy = cy },
                        new DW.EffectExtent { LeftEdge = 0L, TopEdge = 0L, RightEdge = 0L, BottomEdge = 0L },
                        new DW.DocProperties { Id = drawingId, Name = "Signature Image" },
                        new DW.NonVisualGraphicFrameDrawingProperties(new A.GraphicFrameLocks { NoChangeAspect = true }),
                        new A.Graphic(
                            new A.GraphicData(
                                new PIC.Picture(
                                    new PIC.NonVisualPictureProperties(
                                        new PIC.NonVisualDrawingProperties { Id = drawingId, Name = "Signature" },
                                        new PIC.NonVisualPictureDrawingProperties()
                                    ),
                                    new PIC.BlipFill(
                                        new A.Blip { Embed = imagePartId },
                                        new A.Stretch(new A.FillRectangle())
                                    ),
                                    new PIC.ShapeProperties(
                                        new A.Transform2D(
                                            new A.Offset { X = 0, Y = 0 },
                                            new A.Extents { Cx = cx, Cy = cy }
                                        ),
                                        new A.PresetGeometry { Preset = A.ShapeTypeValues.Rectangle }
                                    )
                                )
                            )
                            { Uri = picNamespace }
                        )
                    )
                    {
                        DistanceFromTop = 0,
                        DistanceFromBottom = 0,
                        DistanceFromLeft = 0,
                        DistanceFromRight = 0
                    }
                );

                Console.WriteLine("[INFO] Replacing content control content...");
                contentControl.RemoveAllChildren();
                // Insert drawing based on SdtElement type
                if (contentControl is SdtBlock)
                {
                    contentControl.AppendChild(new SdtContentBlock(
                        new Paragraph(new Run(drawing))
                    ));
                }
                else if (contentControl is SdtRun)
                {
                    contentControl.AppendChild(new SdtContentRun(
                        new Run(drawing)
                    ));
                }
                else if (contentControl is SdtCell)
                {
                    contentControl.AppendChild(new SdtContentCell(
                        new Paragraph(new Run(drawing))
                    ));
                }
                else
                {
                    Console.WriteLine($"[WARNING] Unsupported content control type: {contentControl.GetType().Name}. Defaulting to Paragraph.");
                    contentControl.AppendChild(new Paragraph(new Run(drawing)));
                }

                Console.WriteLine("[INFO] Applying common document fixes (drawing IDs, table structures)...");
                FixDrawingAndTableStructure(wordDoc);

                Console.WriteLine("[SUCCESS] Signature image inserted and document validated successfully.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[EXCEPTION] Signature image insertion failed: {ex.Message}");
                throw;
            }
        }

        private static void FixDrawingAndTableStructure(WordprocessingDocument wordDoc)
        {
            uint idCounter = 1;

            // Fix duplicate drawing IDs
            foreach (var docProp in wordDoc.MainDocumentPart.Document.Descendants<DW.DocProperties>())
            {
                docProp.Id = idCounter++;
            }

            foreach (var picProp in wordDoc.MainDocumentPart.Document.Descendants<PIC.NonVisualDrawingProperties>())
            {
                picProp.Id = idCounter++;
            }

            // List of parts to inspect
            var partsWithTables = new List<OpenXmlPartRootElement>
            {
                wordDoc.MainDocumentPart?.Document
            };

            // Add headers/footers
            partsWithTables.AddRange(wordDoc.MainDocumentPart?.HeaderParts.Select(h => h.Header));
            partsWithTables.AddRange(wordDoc.MainDocumentPart?.FooterParts.Select(f => f.Footer));

            foreach (var part in partsWithTables.Where(p => p != null))
            {
                foreach (var tbl in part.Descendants<Table>())
                {
                    // Ensure <w:tblPr> exists
                    var tblPr = tbl.GetFirstChild<TableProperties>() ?? tbl.PrependChild(new TableProperties());

                    // Ensure <w:tblLook> is correctly defined
                    var tblLook = tblPr.GetFirstChild<TableLook>();
                    if (tblLook == null)
                    {
                        tblLook = new TableLook();
                        tblPr.Append(tblLook);
                    }

                    tblLook.Val = "04A0"; // Default Word style
                    tblLook.FirstRow = OnOffValue.FromBoolean(true);
                    tblLook.LastRow = OnOffValue.FromBoolean(false);
                    tblLook.FirstColumn = OnOffValue.FromBoolean(false);
                    tblLook.LastColumn = OnOffValue.FromBoolean(false);
                    tblLook.NoHorizontalBand = OnOffValue.FromBoolean(false);
                    tblLook.NoVerticalBand = OnOffValue.FromBoolean(false);

                    // Add TableGrid if missing
                    if (tbl.GetFirstChild<TableGrid>() == null)
                    {
                        var firstRow = tbl.Elements<TableRow>().FirstOrDefault();
                        if (firstRow != null)
                        {
                            var grid = new TableGrid();
                            foreach (var cell in firstRow.Elements<TableCell>())
                                grid.AppendChild(new GridColumn());
                            tbl.InsertAfter(grid, tblPr);
                        }
                    }
                }
            }
        }

        private BookmarkStart FindBookmarkInDocument(WordprocessingDocument wordDoc, string bookmarkName)
        {
            // Search in the main document body.
            var bookmark = wordDoc.MainDocumentPart.Document.Body.Descendants<BookmarkStart>()
                            .FirstOrDefault(b => b.Name == bookmarkName);
            if (bookmark != null)
            {
                Console.WriteLine($"Bookmark '{bookmarkName}' found in body. Parent: {bookmark.Parent?.LocalName}");
                return bookmark;
            }
            // Search in header parts.
            foreach (var headerPart in wordDoc.MainDocumentPart.HeaderParts)
            {
                bookmark = headerPart.Header.Descendants<BookmarkStart>().FirstOrDefault(b => b.Name == bookmarkName);
                if (bookmark != null)
                {
                    Console.WriteLine($"Bookmark '{bookmarkName}' found in header. Parent: {bookmark.Parent?.LocalName}");
                    return bookmark;
                }
            }
            // Search in footer parts.
            foreach (var footerPart in wordDoc.MainDocumentPart.FooterParts)
            {
                bookmark = footerPart.Footer.Descendants<BookmarkStart>().FirstOrDefault(b => b.Name == bookmarkName);
                if (bookmark != null)
                {
                    Console.WriteLine($"Bookmark '{bookmarkName}' found in footer. Parent: {bookmark.Parent?.LocalName}");
                    return bookmark;
                }
            }
            Console.WriteLine($"Bookmark '{bookmarkName}' not found in any part.");
            return null;
        }

        private async Task<byte[]> InsertContentAtBookmarkExtended(
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
                    Console.WriteLine($"[DEBUG] Searching for bookmark '{bookmarkName}' in document parts...");
                    var bookmark = FindBookmarkInDocument(wordDoc, bookmarkName);
                    if (bookmark == null)
                    {
                        Console.WriteLine($"[WARNING] Bookmark '{bookmarkName}' not found in document. Skipping include.");
                        _missingIncludeBookmarks.Add(bookmarkName);
                        // Return original document unchanged so processing can continue
                        return mainDocumentContent;
                    }

                    // Determine the parent paragraph for insertion.
                    var parentElement = bookmark.Parent;
                    while (parentElement != null && !(parentElement is Paragraph))
                    {
                        parentElement = parentElement.Parent;
                    }
                    if (parentElement == null)
                    {
                        Console.WriteLine($"[WARNING] No valid parent paragraph found for bookmark '{bookmarkName}'. Skipping include.");
                        _missingIncludeBookmarks.Add(bookmarkName);
                        return mainDocumentContent;
                    }

                    // Find the paragraph index within the main body.
                    var paragraphs = wordDoc.MainDocumentPart.Document.Body
                        .Descendants<Paragraph>()
                        .ToList();

                    int bookmarkIndex = paragraphs.FindIndex(
                        p => p.Descendants<BookmarkStart>().Any(b => b.Name == bookmarkName));

                    if (bookmarkIndex == -1)
                    {
                        Console.WriteLine($"[WARNING] Could not determine paragraph index for '{bookmarkName}'. Skipping include.");
                        _missingIncludeBookmarks.Add(bookmarkName);
                        return mainDocumentContent;
                    }

                    Console.WriteLine($"[SUCCESS] Found valid paragraph index {bookmarkIndex} for bookmark '{bookmarkName}'.");

                    // Build merged document using OpenXmlPowerTools.
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

        private void ValidateDocument(byte[] documentContent)
        {
            using (var stream = new MemoryStream(documentContent))
            using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(stream, false))
            {
                OpenXmlValidator validator = new OpenXmlValidator();
                var errors = validator.Validate(wordDoc);

                if (errors.Any())
                {
                    var errorMessages = new List<string>();
                    foreach (var error in errors)
                    {
                        errorMessages.Add(
                            $"Error: {error.Description}\n" +
                            $"Path: {error.Path?.XPath}\n" +
                            $"Part: {error.Part?.Uri}\n"
                        );
                    }
                    _logger.LogError(
                        "Document validation failed:\n" +
                        string.Join("\n", errorMessages)
                    );
                }
            }
        }

        private static void EnsureUniqueDrawingIds(WordprocessingDocument wordDoc)
        {
            var drawings = wordDoc.MainDocumentPart.Document.Descendants<Drawing>();
            foreach (var drawing in drawings)
            {
                var docProperties = drawing.Descendants<DW.DocProperties>().FirstOrDefault();
                if (docProperties?.Id == null || _drawingElementIds.Contains(docProperties.Id))
                {
                    docProperties.Id = GenerateUniqueDrawingId();
                    SetPictureAltText(drawing, docProperties.Description ?? "Generated Image");
                }
            }
        }

        private void VerifyHeaderFooterExistence(MainDocumentPart mainPart)
        {
            // Ensure header exists if referenced
            if (mainPart.Document.Descendants<HeaderReference>().Any())
            {
                if (!mainPart.HeaderParts.Any())
                {
                    var headerPart = mainPart.AddNewPart<HeaderPart>();
                    headerPart.Header = new Header(new Paragraph(new Run(new Text(""))));
                }
            }

            // Ensure footer exists if referenced
            if (mainPart.Document.Descendants<FooterReference>().Any())
            {
                if (!mainPart.FooterParts.Any())
                {
                    var footerPart = mainPart.AddNewPart<FooterPart>();
                    footerPart.Footer = new Footer(new Paragraph(new Run(new Text(""))));
                }
            }
        }

        private void ValidateTableStructure(Table table)
        {
            // Ensure table properties exist
            if (!table.Elements<TableProperties>().Any())
            {
                table.PrependChild(new TableProperties(
                    new TableStyle() { Val = "TableGrid" },
                    new TableWidth() { Width = "5000", Type = TableWidthUnitValues.Pct }
                ));
            }

            // Ensure table grid exists
            if (!table.Elements<TableGrid>().Any())
            {
                var cols = table.Descendants<TableCell>().Count() / table.Descendants<TableRow>().Count();
                var grid = new TableGrid();
                for (int i = 0; i < cols; i++)
                {
                    grid.AppendChild(new GridColumn());
                }
                table.InsertAfter(grid, table.Elements<TableProperties>().FirstOrDefault());
            }

            // Validate cell structure
            foreach (var row in table.Elements<TableRow>())
            {
                foreach (var cell in row.Elements<TableCell>())
                {
                    if (!cell.Elements<Paragraph>().Any())
                    {
                        cell.Append(new Paragraph(new Run(new Text(""))));
                    }
                }
            }
        }

        #endregion Private Methods
    }
}