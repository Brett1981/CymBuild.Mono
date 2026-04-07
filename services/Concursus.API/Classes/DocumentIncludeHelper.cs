using Concursus.API.Core;
using Concursus.Common.Shared.Helpers;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using Microsoft.Graph;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats;
using A = DocumentFormat.OpenXml.Drawing;
using DW = DocumentFormat.OpenXml.Drawing.Wordprocessing;
using PIC = DocumentFormat.OpenXml.Drawing.Pictures;

namespace Concursus.API.Classes
{
    public class DocumentIncludeHelper
    {
        private readonly ILogger<DocumentIncludeHelper> _logger;
        private static GraphServiceClient graphServiceClient;
        private static HashSet<uint> _drawingElementIds = new HashSet<uint>();

        public DocumentIncludeHelper(ILogger<DocumentIncludeHelper> logger, GraphServiceClient _graphServiceClient)
        {
            _logger = logger;
            graphServiceClient = _graphServiceClient;
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
            byte[] documentContent,
            int userId)
        {
            var processedIncludes = new Dictionary<string, byte[]>();
            var unprocessedItems = includeMergeItems.Where(i => !processedIncludes.ContainsKey(i.Guid)).ToList();

            foreach (var include in unprocessedItems)
            {
                _logger.LogInformation($"Processing include: {include.BookmarkName}");

                var processedInclude = await ProcessSingleInclude(
                    include, siteId, driveId, sharePointUrl, filenameTemplate, recordGuid,
                    parentDocumentContent, bookmarkTableData, bookmarkImageTableData, config, efCore, userId
                );

                // Recursively check if the included document has more includes
                var nestedIncludes = ExtractIncludesFromDocument(processedInclude);
                if (nestedIncludes.Count > 0)
                {
                    _logger.LogInformation($"Recursively processing nested includes for {include.BookmarkName}");
                    processedInclude = await ProcessIncludesRecursively(
                        siteId, driveId, sharePointUrl, filenameTemplate, recordGuid,
                        processedInclude, nestedIncludes,
                        bookmarkTableData, bookmarkImageTableData,
                        config, efCore, processedInclude, userId
                    );
                }

                processedIncludes[include.Guid] = processedInclude;

                using var includeStream = new MemoryStream(processedInclude);
                parentDocumentContent = await InsertContentAtBookmarkOrTag(
                    include.BookmarkName,
                    includeStream,
                    parentDocumentContent
                );

                _logger.LogInformation($"Inserted content at '{include.BookmarkName}'");
                // FIX: Apply WordDocumentFixer and update the result
                parentDocumentContent = WordDocumentFixer.FixBeforeUpload(parentDocumentContent);
            }

            return parentDocumentContent;
        }

        public async Task<byte[]> InsertContentAtBookmarkOrTag(string name, Stream includedContentStream, byte[] mainDocumentContent)
        {
            using var mainStream = new MemoryStream();
            await mainStream.WriteAsync(mainDocumentContent, 0, mainDocumentContent.Length);
            mainStream.Position = 0;

            using var includeStream = new MemoryStream();
            await includedContentStream.CopyToAsync(includeStream);
            includeStream.Position = 0;

            var includedElements = new List<OpenXmlElement>();

            using (var includeDoc = WordprocessingDocument.Open(includeStream, false))
            {
                var includeBody = includeDoc.MainDocumentPart?.Document?.Body;
                if (includeBody == null) throw new Exception("Included document has no valid body.");

                includedElements = includeBody.Elements()
                    .Where(e => !(e is SectionProperties))
                    .Select(e => (OpenXmlElement)e.CloneNode(true))
                    .ToList();

                // Strip paragraph props and drawings (e.g., behind-text logo)
                foreach (var para in includedElements.OfType<Paragraph>())
                {
                    para.RemoveAllChildren<ParagraphProperties>();
                }

                foreach (var drawing in includedElements
                             .SelectMany(e => e.Descendants<Drawing>())
                             .ToList())
                {
                    var graphicData = drawing.Descendants<DocumentFormat.OpenXml.Drawing.GraphicData>().FirstOrDefault();
                    if (graphicData?.Uri?.Value?.Contains("picture") == true)
                    {
                        drawing.Remove();
                    }
                }
            }

            var insertionSuccessful = false;

            using (var wordDoc = WordprocessingDocument.Open(mainStream, true))
            {
                var mainPart = wordDoc.MainDocumentPart;
                if (mainPart == null) throw new Exception("Main document has no MainDocumentPart.");

                using (var includeDoc = WordprocessingDocument.Open(includeStream, false))
                {
                    // Merge styles
                    var includeStyles = includeDoc.MainDocumentPart.StyleDefinitionsPart?.Styles;
                    if (includeStyles != null)
                    {
                        if (mainPart.StyleDefinitionsPart == null)
                        {
                            mainPart.AddNewPart<StyleDefinitionsPart>();
                            mainPart.StyleDefinitionsPart.Styles = (Styles)includeStyles.CloneNode(true);
                        }
                        else
                        {
                            var mainStyles = mainPart.StyleDefinitionsPart.Styles;
                            foreach (var style in includeStyles.Elements<Style>())
                            {
                                if (!mainStyles.Elements<Style>().Any(s => s.StyleId == style.StyleId))
                                {
                                    mainStyles.Append((Style)style.CloneNode(true));
                                }
                            }
                        }
                    }

                    // Merge numbering (for bullets, numbered lists)
                    var includeNumbering = includeDoc.MainDocumentPart.NumberingDefinitionsPart?.Numbering;
                    if (includeNumbering != null)
                    {
                        if (mainPart.NumberingDefinitionsPart == null)
                        {
                            var numberingPart = mainPart.AddNewPart<NumberingDefinitionsPart>();
                            numberingPart.Numbering = (Numbering)includeNumbering.CloneNode(true);
                        }
                        else
                        {
                            var mainNumbering = mainPart.NumberingDefinitionsPart.Numbering;
                            foreach (var num in includeNumbering.Elements())
                            {
                                if (!mainNumbering.Elements().Any(existing =>
                                    (existing is AbstractNum abs1 && num is AbstractNum abs2 && abs1.AbstractNumberId == abs2.AbstractNumberId) ||
                                    (existing is NumberingInstance n1 && num is NumberingInstance n2 && n1.NumberID == n2.NumberID)))
                                {
                                    mainNumbering.Append((OpenXmlElement)num.CloneNode(true));
                                }
                            }
                        }
                    }
                }

                // 1️⃣ Bookmark insertion
                var bookmarkStart = FindAllParts(wordDoc)
                    .SelectMany(p => p.Descendants<BookmarkStart>())
                    .FirstOrDefault(b => b.Name == name);

                if (bookmarkStart != null)
                {
                    var parent = bookmarkStart.Parent;
                    var bookmarkId = bookmarkStart.Id.Value;
                    var bookmarkEnd = parent.Descendants<BookmarkEnd>().FirstOrDefault(be => be.Id?.Value == bookmarkId);

                    bookmarkStart.Remove();
                    bookmarkEnd?.Remove();

                    if (parent is Paragraph paraParent)
                    {
                        foreach (var el in includedElements.Reverse<OpenXmlElement>())
                            paraParent.InsertAfterSelf(el);
                    }
                    else
                    {
                        foreach (var el in includedElements.Reverse<OpenXmlElement>())
                            parent.InsertAfterSelf(el);
                    }

                    insertionSuccessful = true;
                }

                // 2️⃣ Content Control Tag fallback
                if (!insertionSuccessful)
                {
                    var sdt = FindAllParts(wordDoc)
                        .SelectMany(p => p.Descendants<SdtElement>())
                        .FirstOrDefault(s => s.SdtProperties?.GetFirstChild<Tag>()?.Val?.Value == name);

                    if (sdt != null)
                    {
                        var parent = sdt.Parent;
                        var index = parent?.ChildElements.ToList().IndexOf(sdt) ?? -1;
                        sdt.Remove();

                        if (parent != null && index >= 0)
                        {
                            foreach (var el in includedElements)
                            {
                                parent.InsertAt(el, index++);
                            }

                            insertionSuccessful = true;
                        }
                    }
                }

                if (!insertionSuccessful)
                {
                    _logger?.LogWarning($"No bookmark or tag named '{name}' was found.");
                    throw new Exception($"No insertion point found for '{name}'");
                }

                mainPart.Document.Save();
            }

            return mainStream.ToArray();
        }

        public List<OpenXmlPartRootElement> FindAllParts(WordprocessingDocument doc)
        {
            var parts = new List<OpenXmlPartRootElement>
        {
            doc.MainDocumentPart.Document
        };

            if (doc.MainDocumentPart.HeaderParts != null)
            {
                parts.AddRange(doc.MainDocumentPart.HeaderParts.Select(h => h.Header));
            }

            if (doc.MainDocumentPart.FooterParts != null)
            {
                parts.AddRange(doc.MainDocumentPart.FooterParts.Select(f => f.Footer));
            }

            return parts;
        }

        public List<MergeDocumentItem> ExtractIncludesFromDocument(byte[] docBytes)
        {
            var includes = new List<MergeDocumentItem>();

            using var stream = new MemoryStream(docBytes);
            using var doc = WordprocessingDocument.Open(stream, false);

            var allParts = FindAllParts(doc);

            foreach (var sdt in allParts.SelectMany(p => p.Descendants<SdtElement>()))
            {
                var tagVal = sdt.SdtProperties?.GetFirstChild<Tag>()?.Val?.Value;

                if (!string.IsNullOrEmpty(tagVal))
                {
                    includes.Add(new MergeDocumentItem
                    {
                        BookmarkName = tagVal, // Use the full tag value as-is
                        MergeDocumentItemType = "Includes",
                        Guid = Guid.NewGuid().ToString() // Use real GUID if mapped
                    });
                }
            }

            return includes;
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

                _logger?.LogInformation(
                    "Include merge completed for {FileName}. Complex={Complex}, Simple={Simple}, PlainText={PlainText}, SplitPlainText={SplitPlainText}, ContentControls={ContentControls}",
                    filenameTemplate,
                    report.ComplexFieldReplacements,
                    report.SimpleFieldReplacements,
                    report.PlainTextReplacements,
                    report.SplitPlaceholderReplacements,
                    report.ContentControlReplacements);

                if (report.UnresolvedArtifacts.Count > 0)
                {
                    foreach (var unresolved in report.UnresolvedArtifacts)
                    {
                        _logger?.LogWarning("Unresolved include merge artifact: {Artifact}", unresolved);
                    }
                }
            }

            return Task.FromResult(memoryStream.ToArray());
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

        public static void SetPictureAltText(OpenXmlElement imageContainer, string altText)
        {
            var docPro = imageContainer.Descendants<DW.DocProperties>().FirstOrDefault();
            if (docPro != null)
            {
                docPro.Id = GenerateUniqueDrawingId();
                docPro.Description = altText;
            }
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
    }
}