using Concursus.API.Core;
using DocumentFormat.OpenXml;

// NEW: Open XML SDK
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Spreadsheet;
using Microsoft.Graph;

namespace Concursus.API.Classes
{
    public class ExcelDocumentService
    {
        private static GraphServiceClient graphServiceClient;
        private IConfiguration _config;

        public ExcelDocumentService(GraphServiceClient _graphServiceClient)
        {
            graphServiceClient = _graphServiceClient;
        }

        /// <summary>
        /// Downloads the Excel template, replaces [[name]] placeholders with merge data, and
        /// uploads the modified document.
        /// </summary>
        public async Task<SharepointDocumentsGetResponse> DownloadAndModifyExcelDocumentWithMergeData(
            string siteId,
            string driveId,
            string documentId,
            List<Dictionary<string, string>> mergeData,
            IConfiguration config,
            string sharePointUrl,
            string filenameTemplate)
        {
            _config = config;

            // 1) Download
            using (var documentStream = await DownloadDocumentContent(driveId, documentId))
            {
                byte[] documentContent;
                using (var ms = new MemoryStream())
                {
                    await documentStream.CopyToAsync(ms);
                    documentContent = ms.ToArray();
                }

                // 2) Process (now via Open XML; we only touch strings, never formulas)
                byte[] modifiedDocument = ProcessMergeDataInExcel(documentContent, mergeData);

                // 3) Upload
                var uploadResponse = await UploadModifiedDocument(
                    siteId,
                    filenameTemplate,
                    sharePointUrl,
                    documentId,
                    new MemoryStream(modifiedDocument),
                    config,
                    "",
                    "Excel");

                return uploadResponse;
            }
        }

        /// <summary>
        /// Minimal-change replacement: Use Open XML SDK to replace [[Field]] placeholders ONLY
        /// inside string content (Shared Strings and Inline Strings). We do NOT import/export the
        /// workbook through a formatter, which preserves all formulas, tables, and structured
        /// references intact.
        /// </summary>
        private byte[] ProcessMergeDataInExcel(byte[] documentContent, List<Dictionary<string, string>> mergeData)
        {
            // Build a fast lookup of [[name]] -> value
            var replacements = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var m in mergeData)
            {
                if (m.TryGetValue("name", out var name))
                {
                    m.TryGetValue("value", out var value);
                    replacements[$"[[{name}]]"] = value ?? string.Empty;
                }
            }

            // Work on a copy of the original bytes
            using var input = new MemoryStream(documentContent, writable: false);
            using var output = new MemoryStream();

            // Copy original to output then open with Open XML in Editable mode
            input.CopyTo(output);
            output.Position = 0;

            using (var doc = SpreadsheetDocument.Open(output, true))
            {
                var wbPart = doc.WorkbookPart;
                if (wbPart == null)
                    return output.ToArray();

                // 1) Replace in Shared String Table (most text cells reference this)
                var sstPart = wbPart.SharedStringTablePart;
                if (sstPart?.SharedStringTable != null)
                {
                    foreach (var ssi in sstPart.SharedStringTable.Elements<SharedStringItem>())
                    {
                        ReplaceTextInSharedStringItem(ssi, replacements);
                    }
                    sstPart.SharedStringTable.Save();
                }

                // 2) Replace in Inline Strings (cells that store text inline instead of via shared strings)
                foreach (var wsPart in wbPart.WorksheetParts)
                {
                    var sheetData = wsPart.Worksheet?.GetFirstChild<SheetData>();
                    if (sheetData == null) continue;

                    foreach (var row in sheetData.Elements<Row>())
                    {
                        foreach (var cell in row.Elements<Cell>())
                        {
                            // Only touch inline strings (t="inlineStr"); leave formula cells alone
                            if (cell.DataType != null && cell.DataType.Value == CellValues.InlineString && cell.InlineString != null)
                            {
                                ReplaceTextInInlineString(cell.InlineString, replacements);
                            }
                            // If the cell is a shared string (t="s"), we already handled it via the
                            // shared string table. If the cell is a formula or number, we do nothing.
                        }
                    }

                    wsPart.Worksheet.Save();
                }
            }

            // Return the modified bytes
            return output.ToArray();
        }

        // ---------- Helpers: safe text replacement without touching formulas ----------

        private static void ReplaceTextInSharedStringItem(SharedStringItem ssi, IDictionary<string, string> replacements)
        {
            if (ssi == null) return;

            // SharedStringItem may be plain <t> or rich text <r><t> runs.
            string current = GetText(ssi);
            if (string.IsNullOrEmpty(current)) return;

            string replaced = ReplaceAll(current, replacements);
            if (replaced == current) return;

            SetPlainText(ssi, replaced);
        }

        private static void ReplaceTextInInlineString(InlineString inline, IDictionary<string, string> replacements)
        {
            if (inline == null) return;

            // InlineString can also be plain or rich text.
            string current = GetText(inline);
            if (string.IsNullOrEmpty(current)) return;

            string replaced = ReplaceAll(current, replacements);
            if (replaced == current) return;

            SetPlainText(inline, replaced);
        }

        private static string ReplaceAll(string input, IDictionary<string, string> replacements)
        {
            string result = input;
            foreach (var kvp in replacements)
            {
                if (!string.IsNullOrEmpty(kvp.Key))
                    result = result.Replace(kvp.Key, kvp.Value ?? string.Empty, StringComparison.Ordinal);
            }
            return result;
        }

        // --- Text extraction & setters that normalize to a single plain <t> node to keep things
        // simple ---

        private static string GetText(SharedStringItem ssi)
        {
            if (ssi.Text != null) return ssi.Text.Text ?? string.Empty;

            if (ssi.HasChildren)
            {
                // Concatenate all run texts
                var runs = ssi.Elements<Run>();
                return string.Concat(runs.Select(r => r.Text?.Text ?? string.Empty));
            }

            return string.Empty;
        }

        private static void SetPlainText(SharedStringItem ssi, string text)
        {
            // Remove rich text runs if present and set a single <t>
            ssi.RemoveAllChildren<Run>();
            ssi.Text = new Text(text) { Space = SpaceProcessingModeValues.Preserve };
        }

        private static string GetText(InlineString inline)
        {
            if (inline.Text != null) return inline.Text.Text ?? string.Empty;

            if (inline.HasChildren)
            {
                var runs = inline.Elements<Run>();
                return string.Concat(runs.Select(r => r.Text?.Text ?? string.Empty));
            }

            return string.Empty;
        }

        private static void SetPlainText(InlineString inline, string text)
        {
            inline.RemoveAllChildren<Run>();
            inline.Text = new Text(text) { Space = SpaceProcessingModeValues.Preserve };
        }

        // ---------------------------------------------------------------------------

        /// <summary>
        /// Downloads a document from SharePoint using the Microsoft Graph client.
        /// </summary>
        private async Task<Stream> DownloadDocumentContent(string driveId, string itemId)
        {
            int retryCount = 3;
            while (retryCount > 0)
            {
                try
                {
                    var stream = await graphServiceClient.Drives[driveId].Items[itemId].Content.GetAsync();
                    if (stream != null)
                        return stream;

                    return Stream.Null;
                }
                catch (Exception)
                {
                    retryCount--;
                    await Task.Delay(1000);
                }
            }
            return Stream.Null;
        }

        private async Task<SharepointDocumentsGetResponse> UploadModifiedDocument(
            string siteId,
            string filenameTemplate,
            string targetSharePointUrl,
            string itemId,
            Stream modifiedContent,
            IConfiguration config,
            string subFolder = "",
            string outputType = "Excel")
        {
            try
            {
                Console.WriteLine("[INFO] Checking if environment is Dev, Test, or Live...");

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
                    .GetAsync(requestConfig =>
                    {
                        requestConfig.QueryParameters.Filter = $"(name eq '{mainFolder}')";
                    });

                var targetFolder = itemCollection?.Value?.FirstOrDefault();
                if (targetFolder == null)
                {
                    throw new Exception($"[ERROR] Target folder '{mainFolder}' not found in SharePoint.");
                }

                Console.WriteLine($"[SUCCESS] Target folder '{mainFolder}' found. Folder ID: {targetFolder.Id}");

                string _fileName = Functions.GetFileNameText(filenameTemplate);
                if (string.IsNullOrEmpty(_fileName))
                {
                    throw new Exception("[ERROR] FilenameTemplate returned an empty filename.");
                }

                Console.WriteLine($"[INFO] Uploading document as '{_fileName}.xlsx'...");

                var uploadedExcelItem = await graphServiceClient
                    .Drives[driveItem.Id]
                    .Items[targetFolder.Id].ItemWithPath($"{_fileName}.xlsx")
                    .Content
                    .PutAsync(modifiedContent);

                if (uploadedExcelItem == null || string.IsNullOrEmpty(uploadedExcelItem.Id))
                {
                    throw new Exception("[ERROR] Failed to upload modified Excel document.");
                }

                Console.WriteLine($"[SUCCESS] Uploaded item ID: {uploadedExcelItem.Id}, FileName: {_fileName}.xlsx");
                return await DownloadDriveItem(driveItem.Id, uploadedExcelItem.Id);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ERROR] UploadModifiedDocument failed: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Downloads a drive item from SharePoint.
        /// </summary>
        private async Task<SharepointDocumentsGetResponse> DownloadDriveItem(string driveId, string driveItemId)
        {
            try
            {
                var driveItemInfo = await graphServiceClient.Drives[driveId].Items[driveItemId].GetAsync();
                if (driveItemInfo != null && driveItemInfo.AdditionalData.TryGetValue("@microsoft.graph.downloadUrl", out var downloadUrl))
                {
                    return new SharepointDocumentsGetResponse
                    {
                        DriveItem = Converters.ConvertMicrosoftGraphDriveItemToCoreDriveItem(driveItemInfo, driveId),
                        DownloadUrl = downloadUrl.ToString(),
                    };
                }
                throw new Exception("Download URL not available.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
                return new SharepointDocumentsGetResponse();
            }
        }
    }
}