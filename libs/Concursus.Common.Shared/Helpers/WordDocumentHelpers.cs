using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Drawing.Pictures;
using DocumentFormat.OpenXml.Drawing.Wordprocessing;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace Concursus.Common.Shared.Helpers
{
    public static class WordDocumentHelpers
    {
        #region Public Methods

        public static Stream AddMarkOfTheWebToStream(Stream originalStream)
        {
            var memoryStream = new MemoryStream();
            using (var writer = new StreamWriter(memoryStream, leaveOpen: true))
            {
                writer.Write("<!-- Mark of the Web: zone=3 -->\r\n");
                writer.Flush();
                originalStream.CopyTo(memoryStream);
            }
            memoryStream.Position = 0;
            return memoryStream;
        }

        public static void CollectRelationshipIds(OpenXmlPart part)
        {
            if (part == null) return;

            foreach (var rel in part.Parts)
            {
                string relId = part.GetIdOfPart(rel.OpenXmlPart);
                string newRelId = ""; Random randNum = new Random();

                try { part.ChangeIdOfPart(rel.OpenXmlPart, $"rId{randNum.Next()}"); }
                catch (Exception ex)
                {
                    switch (ex)
                    {
                        case ArgumentException:
                            part.ChangeIdOfPart(rel.OpenXmlPart,
                $"rId{randNum.Next()}"); break;

                        default: return;
                    }
                }

                // Recursively collect from child parts
                CollectRelationshipIds(rel.OpenXmlPart);
            }
        }

        // Collect all relationship IDs recursively
        public static void CollectRelationshipIds(OpenXmlPart part, HashSet<string> existingIds)
        {
            if (part == null) return;

            foreach (var rel in part.Parts)
            {
                var relId = part.GetIdOfPart(rel.OpenXmlPart);
                existingIds.Add(relId);
                // Recursively collect from child parts
                CollectRelationshipIds(rel.OpenXmlPart, existingIds);
            }
        }

        public static void CopyDocumentContent(
    Stream includedDocumentStream,
    Stream mainDocumentStream,
    string bookmarkName)
        {
            using (var mainDocument = WordprocessingDocument.Open(mainDocumentStream, true))
            using (var includedDocument = WordprocessingDocument.Open(includedDocumentStream, false))
            {
                var mainPart = mainDocument.MainDocumentPart;
                var includedPart = includedDocument.MainDocumentPart;

                // Locate the bookmark in the main document
                var bookmark = mainPart.Document.Body.Descendants<BookmarkStart>()
                                 .FirstOrDefault(b => b.Name == bookmarkName);
                if (bookmark == null)
                {
                    throw new Exception($"Bookmark '{bookmarkName}' not found in the main document.");
                }

                var bookmarkParent = bookmark.Parent;

                // Clone the body content of the included document
                var includedBody = includedPart.Document.Body.CloneNode(true) as Body;
                if (includedBody == null)
                {
                    throw new InvalidOperationException("Failed to clone the body of the included document.");
                }

                // Get SectionProperties of the current section in the main document
                var mainSectionProps = GetSectionProperties(mainPart.Document.Body);

                // Remove SectionProperties from the included document
                foreach (var sectionProps in includedBody.Descendants<SectionProperties>())
                {
                    sectionProps.Remove();
                }

                // Insert a continuous section break with main document's SectionProperties
                var sectionBreak = new Paragraph(
                    new Run(new Break() { Type = BreakValues.Page }),
                    mainSectionProps?.CloneNode(true)
                );

                bookmarkParent.InsertAfterSelf(sectionBreak);

                // Append included content after the section break
                foreach (var element in includedBody.Elements())
                {
                    bookmarkParent.InsertAfterSelf(element.CloneNode(true));
                }

                // Copy styles, numbering, headers, and other relationships
                CopyRelationships(includedPart, mainPart);

                // Save the changes to the main document
                mainPart.Document.Save();
            }
        }

        public static void CopyHeadersFooters(MainDocumentPart sourcePart, MainDocumentPart targetPart)
        {
            foreach (var headerPart in sourcePart.HeaderParts)
            {
                var targetHeaderPart = targetPart.AddNewPart<HeaderPart>();
                targetHeaderPart.FeedData(headerPart.GetStream());
            }

            foreach (var footerPart in sourcePart.FooterParts)
            {
                var targetFooterPart = targetPart.AddNewPart<FooterPart>();
                targetFooterPart.FeedData(footerPart.GetStream());
            }
        }

        public static void CopyImages(MainDocumentPart sourcePart, MainDocumentPart targetPart)
        {
            foreach (var imagePart in sourcePart.ImageParts)
            {
                var targetImagePart = targetPart.AddImagePart(imagePart.ContentType);
                targetImagePart.FeedData(imagePart.GetStream());
            }
        }

        public static void CopyImagesAndCharts(MainDocumentPart sourcePart, MainDocumentPart targetPart)
        {
            foreach (var imagePart in sourcePart.ImageParts)
            {
                var targetImagePart = targetPart.AddImagePart(imagePart.ContentType);
                targetImagePart.FeedData(imagePart.GetStream());
            }

            foreach (var chartPart in sourcePart.ChartParts)
            {
                var targetChartPart = targetPart.AddNewPart<ChartPart>();
                targetChartPart.FeedData(chartPart.GetStream());
            }
        }

        public static void CopyNumbering(MainDocumentPart sourcePart, MainDocumentPart targetPart)
        {
            if (sourcePart.NumberingDefinitionsPart != null)
            {
                if (targetPart.NumberingDefinitionsPart == null)
                {
                    targetPart.AddNewPart<NumberingDefinitionsPart>();
                }
                targetPart.NumberingDefinitionsPart.FeedData(sourcePart.NumberingDefinitionsPart.GetStream());
            }
        }

        public static void CopyNumberingAndHeaders(MainDocumentPart sourcePart, MainDocumentPart targetPart)
        {
            // Copy Numbering (for lists)
            if (sourcePart.NumberingDefinitionsPart != null)
            {
                if (targetPart.NumberingDefinitionsPart == null)
                {
                    targetPart.AddNewPart<NumberingDefinitionsPart>();
                    targetPart.NumberingDefinitionsPart.FeedData(sourcePart.NumberingDefinitionsPart.GetStream());
                }
            }
        }

        public static void CopyRelationships(MainDocumentPart sourcePart, MainDocumentPart targetPart)
        {
            // Copy styles
            if (sourcePart.StyleDefinitionsPart != null)
            {
                if (targetPart.StyleDefinitionsPart == null)
                {
                    targetPart.AddNewPart<StyleDefinitionsPart>().FeedData(sourcePart.StyleDefinitionsPart.GetStream());
                }
                else
                {
                    MergeStyles(sourcePart.StyleDefinitionsPart, targetPart.StyleDefinitionsPart);
                }
            }

            // Copy numbering
            if (sourcePart.NumberingDefinitionsPart != null)
            {
                if (targetPart.NumberingDefinitionsPart == null)
                {
                    targetPart.AddNewPart<NumberingDefinitionsPart>().FeedData(sourcePart.NumberingDefinitionsPart.GetStream());
                }
            }

            // Copy headers and footers
            CopyHeadersFooters(sourcePart, targetPart);

            // Copy images and charts
            CopyImagesAndCharts(sourcePart, targetPart);
        }

        public static void CopyStyles(MainDocumentPart sourcePart, MainDocumentPart targetPart)
        {
            if (sourcePart.StyleDefinitionsPart != null)
            {
                if (targetPart.StyleDefinitionsPart == null)
                {
                    targetPart.AddNewPart<StyleDefinitionsPart>();
                }
                targetPart.StyleDefinitionsPart.FeedData(sourcePart.StyleDefinitionsPart.GetStream());
            }
        }

        public static Drawing CreateImageElement(string relationshipId, long width, long height, string imageName = "Image")
        {
            var element =
                 new Drawing(
                     new Inline(
                         new Extent() { Cx = width, Cy = height },
                         new EffectExtent()
                         {
                             LeftEdge = 0L,
                             TopEdge = 0L,
                             RightEdge = 0L,
                             BottomEdge = 0L
                         },
                         new DocProperties()
                         {
                             Id = (UInt32Value)1U,
                             Name = imageName
                         },
                         new NonVisualGraphicFrameDrawingProperties(
                             new DocumentFormat.OpenXml.Drawing.GraphicFrameLocks() { NoChangeAspect = true }
                         ),
                         new DocumentFormat.OpenXml.Drawing.Graphic(
                             new DocumentFormat.OpenXml.Drawing.GraphicData(
                                 new DocumentFormat.OpenXml.Drawing.Pictures.Picture(
                                     new NonVisualPictureProperties(
                                         new NonVisualDrawingProperties()
                                         {
                                             Id = (UInt32Value)0U,
                                             Name = imageName
                                         },
                                         new NonVisualPictureDrawingProperties()
                                     ),
                                     new BlipFill(
                                         new DocumentFormat.OpenXml.Drawing.Blip(
                                             new DocumentFormat.OpenXml.Drawing.BlipExtensionList(
                                                 new DocumentFormat.OpenXml.Drawing.BlipExtension()
                                                 {
                                                     Uri = "{28A0092B-C50C-407E-A947-70E740481C1C}"
                                                 }
                                             )
                                         )
                                         {
                                             Embed = relationshipId,
                                             CompressionState = DocumentFormat.OpenXml.Drawing.BlipCompressionValues.Print
                                         },
                                         new DocumentFormat.OpenXml.Drawing.Stretch(
                                             new DocumentFormat.OpenXml.Drawing.FillRectangle()
                                         )
                                     ),
                                     new ShapeProperties(
                                         new DocumentFormat.OpenXml.Drawing.Transform2D(
                                             new DocumentFormat.OpenXml.Drawing.Offset() { X = 0L, Y = 0L },
                                             new DocumentFormat.OpenXml.Drawing.Extents() { Cx = width, Cy = height }
                                         ),
                                         new DocumentFormat.OpenXml.Drawing.PresetGeometry(
                                             new DocumentFormat.OpenXml.Drawing.AdjustValueList()
                                         )
                                         { Preset = DocumentFormat.OpenXml.Drawing.ShapeTypeValues.Rectangle }
                                     )
                                 )
                             )
                             { Uri = "http://schemas.openxmlformats.org/drawingml/2006/picture" }
                         )
                     )
                     {
                         DistanceFromTop = (UInt32Value)0U,
                         DistanceFromBottom = (UInt32Value)0U,
                         DistanceFromLeft = (UInt32Value)0U,
                         DistanceFromRight = (UInt32Value)0U,
                         EditId = "50D07946"
                     }
                 );

            return element;
        }

        public static bool EndsWithPageBreak(Paragraph paragraph)
        {
            var lastRun = paragraph.Elements<Run>().LastOrDefault();
            if (lastRun != null)
            {
                var lastBreak = lastRun.Elements<Break>().LastOrDefault();
                return lastBreak != null && lastBreak.Type == BreakValues.Page;
            }
            return false;
        }

        public static string ExtractContentFromZip(Stream zipStream)
        {
            using var archive = new ZipArchive(zipStream, ZipArchiveMode.Read);
            var entry = archive.Entries.FirstOrDefault();
            if (entry == null) return "";
            using var entryStream = entry.Open();
            using var reader = new StreamReader(entryStream, Encoding.UTF8);
            return reader.ReadToEnd();
        }


        public static string GenerateUniqueRelId(MainDocumentPart mainPart)
        {
            int counter = 1;
            string newRelId;

            do
            {
                newRelId = $"rId{counter++}";
            }
            while (mainPart.Parts.Any(p => mainPart.GetIdOfPart(p.OpenXmlPart) == newRelId));

            return newRelId;
        }

        public static List<string> GetAllBookmarks(Stream documentStream)
        {
            List<string> bookmarks = new List<string>();

            using (WordprocessingDocument wordDoc = WordprocessingDocument.Open(documentStream, false))
            {
                var bookmarkStarts = wordDoc.MainDocumentPart.Document.Body.Descendants<BookmarkStart>();

                foreach (var bookmark in bookmarkStarts)
                {
                    bookmarks.Add(bookmark.Name);
                }
            }

            return bookmarks;
        }

        public static bool IsValidWordDocument(Stream documentStream)
        {
            try
            {
                using (var doc = WordprocessingDocument.Open(documentStream, false))
                {
                    return doc.MainDocumentPart?.Document != null;
                }
            }
            catch
            {
                return false; // Document is not valid
            }
        }

        // Merges styles to avoid duplication
        public static void MergeStyles(StyleDefinitionsPart sourceStyles, StyleDefinitionsPart targetStyles)
        {
            var sourceDoc = sourceStyles.Styles;
            var targetDoc = targetStyles.Styles;

            foreach (var style in sourceDoc.Elements<Style>())
            {
                if (!targetDoc.Elements<Style>().Any(s => s.StyleId == style.StyleId))
                {
                    targetDoc.Append(style.CloneNode(true));
                }
            }
        }

        public static void RemoveGlossaryPart(WordprocessingDocument document)
        {
            var glossaryPart = document.MainDocumentPart.GlossaryDocumentPart;

            if (glossaryPart != null)
            {
                document.MainDocumentPart.DeletePart(glossaryPart);
                Console.WriteLine("Glossary part removed successfully.");
            }
            else
            {
                Console.WriteLine("No glossary part found.");
            }
        }

        public static async Task<byte[]> StreamToByteArrayAsync(Stream stream)
        {
            using (var memoryStream = new MemoryStream())
            {
                await stream.CopyToAsync(memoryStream);
                return memoryStream.ToArray();
            }
        }

        // Method to check if a style exists in the document
        public static bool StyleExists(string styleId, MainDocumentPart mainPart)
        {
            var stylesPart = mainPart.StyleDefinitionsPart;
            if (stylesPart != null)
            {
                var styles = stylesPart.Styles.Elements<Style>()
                    .Where(s => string.Equals(s.StyleId, styleId, StringComparison.OrdinalIgnoreCase));

                return styles.Any();
            }
            return false;
        }

        public static string ExtractMergeFieldName(string fieldText)
        {
            if (string.IsNullOrWhiteSpace(fieldText))
            {
                return string.Empty;
            }

            // Handles:
            // MERGEFIELD  FieldName  \* MERGEFORMAT
            // MERGEFIELD "Field Name" \* MERGEFORMAT
            // MERGEFIELD  FieldName
            var match = Regex.Match(
                fieldText,
                @"MERGEFIELD\s+(?:""(?<name>[^""]+)""|(?<name>[^\s\\]+))",
                RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

            return match.Success
                ? match.Groups["name"].Value.Trim()
                : string.Empty;
        }

        public static Dictionary<string, string> BuildMergeFieldMap(List<Dictionary<string, string>> mergeFields)
        {
            var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            if (mergeFields == null)
            {
                return map;
            }

            foreach (var item in mergeFields)
            {
                if (item == null)
                {
                    continue;
                }

                item.TryGetValue("name", out var name);
                item.TryGetValue("value", out var value);

                if (string.IsNullOrWhiteSpace(name))
                {
                    continue;
                }

                if (!map.ContainsKey(name))
                {
                    map[name] = value ?? string.Empty;
                }
            }

            return map;
        }

        /// <summary>
        /// Main entry point for merge replacement. Supports:
        /// 1) Complex MERGEFIELD fields (FieldCode / FieldChar sequence)
        /// 2) Simple MERGEFIELD fields (w:fldSimple)
        /// 3) Plain text chevron placeholders «FieldName»
        /// 4) Text content controls matched by Tag or Alias
        /// </summary>
        public static MergeReplacementReport ReplaceAllMergeContent(
            WordprocessingDocument wordDoc,
            List<Dictionary<string, string>> mergeFields)
        {
            if (wordDoc == null)
            {
                throw new ArgumentNullException(nameof(wordDoc));
            }

            var map = BuildMergeFieldMap(mergeFields);
            var report = new MergeReplacementReport();

            if (map.Count == 0)
            {
                report.UnresolvedArtifacts.AddRange(GetUnresolvedMergeArtifacts(wordDoc));
                return report;
            }

            foreach (var root in GetAllSearchRoots(wordDoc))
            {
                report.ComplexFieldReplacements += ReplaceComplexMergeFields(root, map);
                report.SimpleFieldReplacements += ReplaceSimpleMergeFields(root, map);
                report.ContentControlReplacements += ReplaceTaggedContentControls(root, map);
                report.PlainTextReplacements += ReplacePlainTextPlaceholders(root, map);
                report.SplitPlaceholderReplacements += ReplaceSplitPlainTextPlaceholders(root, map);
            }

            wordDoc.MainDocumentPart?.Document?.Save();

            foreach (var headerPart in wordDoc.MainDocumentPart?.HeaderParts ?? Enumerable.Empty<HeaderPart>())
            {
                headerPart.Header?.Save();
            }

            foreach (var footerPart in wordDoc.MainDocumentPart?.FooterParts ?? Enumerable.Empty<FooterPart>())
            {
                footerPart.Footer?.Save();
            }

            report.UnresolvedArtifacts.AddRange(GetUnresolvedMergeArtifacts(wordDoc));
            return report;
        }

        public static void ReplaceMergeFieldWithText(FieldCode field, string replacementText)
        {
            if (field == null)
            {
                return;
            }

            var instructionRun = field.Ancestors<Run>().FirstOrDefault();
            if (instructionRun == null)
            {
                return;
            }

            var parent = instructionRun.Parent as OpenXmlCompositeElement;
            if (parent == null)
            {
                return;
            }

            var beginRun = FindMergeFieldBoundaryRun(instructionRun, FieldCharValues.Begin, searchBackwards: true);
            var endRun = FindMergeFieldBoundaryRun(instructionRun, FieldCharValues.End, searchBackwards: false);
            var separateRun = FindMergeFieldBoundaryRun(instructionRun, FieldCharValues.Separate, searchBackwards: false);

            if (beginRun == null || endRun == null)
            {
                // Fallback to original-style behaviour if the field structure is irregular.
                instructionRun.RemoveAllChildren<FieldCode>();
                instructionRun.RemoveAllChildren<Text>();
                instructionRun.Append(CreateTextElement(replacementText));
                return;
            }

            var replacementRun = CreateReplacementRun(
                GetRunPropertiesClone(separateRun?.NextSibling<Run>() ?? instructionRun),
                replacementText);

            var childElements = parent.ChildElements.ToList();
            var startIndex = childElements.IndexOf(beginRun);
            var endIndex = childElements.IndexOf(endRun);

            if (startIndex < 0 || endIndex < startIndex)
            {
                instructionRun.RemoveAllChildren<FieldCode>();
                instructionRun.RemoveAllChildren<Text>();
                instructionRun.Append(CreateTextElement(replacementText));
                return;
            }

            var nodesToRemove = parent.ChildElements
                .Skip(startIndex)
                .Take(endIndex - startIndex + 1)
                .ToList();

            parent.InsertAt(replacementRun, startIndex);

            foreach (var node in nodesToRemove)
            {
                node.Remove();
            }
        }

        /// <summary>
        /// Retained for compatibility with existing callers.
        /// This now replaces chevron placeholders across body, headers and footers.
        /// </summary>
        public static void ReplacePlainTextPlaceholders(
            WordprocessingDocument wordDoc,
            List<Dictionary<string, string>> mergeFields)
        {
            if (wordDoc == null)
            {
                throw new ArgumentNullException(nameof(wordDoc));
            }

            var map = BuildMergeFieldMap(mergeFields);

            foreach (var root in GetAllSearchRoots(wordDoc))
            {
                ReplacePlainTextPlaceholders(root, map);
                ReplaceSplitPlainTextPlaceholders(root, map);
            }

            wordDoc.MainDocumentPart?.Document?.Save();
        }

        public static IReadOnlyList<string> GetUnresolvedMergeArtifacts(WordprocessingDocument wordDoc)
        {
            if (wordDoc == null)
            {
                throw new ArgumentNullException(nameof(wordDoc));
            }

            var unresolved = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var root in GetAllSearchRoots(wordDoc))
            {
                foreach (var simpleField in root.Descendants<SimpleField>())
                {
                    var instruction = simpleField.Instruction?.Value ?? string.Empty;
                    if (instruction.IndexOf("MERGEFIELD", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        var fieldName = ExtractMergeFieldName(instruction);
                        if (!string.IsNullOrWhiteSpace(fieldName))
                        {
                            unresolved.Add($"MERGEFIELD:{fieldName}");
                        }
                    }
                }

                foreach (var fieldCode in root.Descendants<FieldCode>())
                {
                    var fieldName = ExtractMergeFieldName(fieldCode.Text ?? string.Empty);
                    if (!string.IsNullOrWhiteSpace(fieldName))
                    {
                        unresolved.Add($"MERGEFIELD:{fieldName}");
                    }
                }

                foreach (var text in root.Descendants<Text>())
                {
                    if (string.IsNullOrWhiteSpace(text.Text))
                    {
                        continue;
                    }

                    foreach (Match match in Regex.Matches(text.Text, "«(?<name>[^»]+)»"))
                    {
                        unresolved.Add($"PLACEHOLDER:{match.Groups["name"].Value}");
                    }
                }

                foreach (var sdt in root.Descendants<SdtElement>())
                {
                    var tag = sdt.SdtProperties?.GetFirstChild<Tag>()?.Val?.Value;
                    var alias = sdt.SdtProperties?.GetFirstChild<SdtAlias>()?.Val?.Value;

                    if (!string.IsNullOrWhiteSpace(tag) && ContentControlLooksUnresolved(sdt, tag))
                    {
                        unresolved.Add($"CONTENTCONTROL:{tag}");
                    }

                    if (!string.IsNullOrWhiteSpace(alias) && ContentControlLooksUnresolved(sdt, alias))
                    {
                        unresolved.Add($"CONTENTCONTROL:{alias}");
                    }
                }
            }

            return unresolved.OrderBy(x => x).ToList();
        }

        public sealed class MergeReplacementReport
        {
            public int ComplexFieldReplacements { get; set; }
            public int SimpleFieldReplacements { get; set; }
            public int PlainTextReplacements { get; set; }
            public int SplitPlaceholderReplacements { get; set; }
            public int ContentControlReplacements { get; set; }
            public List<string> UnresolvedArtifacts { get; } = new();
        }

        private static IEnumerable<OpenXmlElement> GetAllSearchRoots(WordprocessingDocument wordDoc)
        {
            if (wordDoc.MainDocumentPart?.Document != null)
            {
                yield return wordDoc.MainDocumentPart.Document;
            }

            foreach (var headerPart in wordDoc.MainDocumentPart?.HeaderParts ?? Enumerable.Empty<HeaderPart>())
            {
                if (headerPart.Header != null)
                {
                    yield return headerPart.Header;
                }
            }

            foreach (var footerPart in wordDoc.MainDocumentPart?.FooterParts ?? Enumerable.Empty<FooterPart>())
            {
                if (footerPart.Footer != null)
                {
                    yield return footerPart.Footer;
                }
            }
        }

        private static int ReplaceComplexMergeFields(OpenXmlElement root, IReadOnlyDictionary<string, string> mergeMap)
        {
            var replacements = 0;

            var fieldCodes = root.Descendants<FieldCode>().ToList();
            foreach (var fieldCode in fieldCodes)
            {
                var instruction = fieldCode.Text?.Trim();
                if (string.IsNullOrWhiteSpace(instruction) ||
                    instruction.IndexOf("MERGEFIELD", StringComparison.OrdinalIgnoreCase) < 0)
                {
                    continue;
                }

                var fieldName = ExtractMergeFieldName(instruction);
                if (string.IsNullOrWhiteSpace(fieldName))
                {
                    continue;
                }

                if (!mergeMap.TryGetValue(fieldName, out var replacement))
                {
                    continue;
                }

                ReplaceMergeFieldWithText(fieldCode, replacement);
                replacements++;
            }

            return replacements;
        }

        private static int ReplaceSimpleMergeFields(OpenXmlElement root, IReadOnlyDictionary<string, string> mergeMap)
        {
            var replacements = 0;

            var simpleFields = root.Descendants<SimpleField>().ToList();
            foreach (var simpleField in simpleFields)
            {
                var instruction = simpleField.Instruction?.Value?.Trim();
                if (string.IsNullOrWhiteSpace(instruction) ||
                    instruction.IndexOf("MERGEFIELD", StringComparison.OrdinalIgnoreCase) < 0)
                {
                    continue;
                }

                var fieldName = ExtractMergeFieldName(instruction);
                if (string.IsNullOrWhiteSpace(fieldName))
                {
                    continue;
                }

                if (!mergeMap.TryGetValue(fieldName, out var replacement))
                {
                    continue;
                }

                ReplaceSimpleFieldWithText(simpleField, replacement);
                replacements++;
            }

            return replacements;
        }

        private static int ReplaceTaggedContentControls(OpenXmlElement root, IReadOnlyDictionary<string, string> mergeMap)
        {
            var replacements = 0;

            foreach (var sdt in root.Descendants<SdtElement>().ToList())
            {
                var tag = sdt.SdtProperties?.GetFirstChild<Tag>()?.Val?.Value;
                var alias = sdt.SdtProperties?.GetFirstChild<SdtAlias>()?.Val?.Value;

                string? matchedKey = null;

                if (!string.IsNullOrWhiteSpace(tag) && mergeMap.ContainsKey(tag))
                {
                    matchedKey = tag;
                }
                else if (!string.IsNullOrWhiteSpace(alias) && mergeMap.ContainsKey(alias))
                {
                    matchedKey = alias;
                }

                if (matchedKey == null)
                {
                    continue;
                }

                ReplaceContentControlText(sdt, mergeMap[matchedKey]);
                replacements++;
            }

            return replacements;
        }

        private static int ReplacePlainTextPlaceholders(OpenXmlElement root, IReadOnlyDictionary<string, string> mergeMap)
        {
            var replacements = 0;

            foreach (var textElement in root.Descendants<Text>())
            {
                var original = textElement.Text;
                if (string.IsNullOrEmpty(original))
                {
                    continue;
                }

                var updated = original;
                foreach (var kvp in mergeMap)
                {
                    updated = updated.Replace($"«{kvp.Key}»", kvp.Value ?? string.Empty, StringComparison.OrdinalIgnoreCase);
                }

                if (!string.Equals(original, updated, StringComparison.Ordinal))
                {
                    textElement.Text = updated;
                    ApplySpacePreserveIfNeeded(textElement);
                    replacements++;
                }
            }

            return replacements;
        }

        private static int ReplaceSplitPlainTextPlaceholders(OpenXmlElement root, IReadOnlyDictionary<string, string> mergeMap)
        {
            var replacements = 0;

            foreach (var paragraph in root.Descendants<Paragraph>())
            {
                var textNodes = paragraph.Descendants<Text>().ToList();
                if (textNodes.Count < 2)
                {
                    continue;
                }

                var combined = string.Concat(textNodes.Select(t => t.Text));
                if (string.IsNullOrEmpty(combined))
                {
                    continue;
                }

                var replaced = combined;
                foreach (var kvp in mergeMap)
                {
                    replaced = replaced.Replace($"«{kvp.Key}»", kvp.Value ?? string.Empty, StringComparison.OrdinalIgnoreCase);
                }

                if (string.Equals(combined, replaced, StringComparison.Ordinal))
                {
                    continue;
                }

                textNodes[0].Text = replaced;
                ApplySpacePreserveIfNeeded(textNodes[0]);

                for (var i = 1; i < textNodes.Count; i++)
                {
                    textNodes[i].Text = string.Empty;
                    textNodes[i].Space = null;
                }

                replacements++;
            }

            return replacements;
        }

        private static void ReplaceSimpleFieldWithText(SimpleField simpleField, string replacementText)
        {
            if (simpleField == null)
            {
                return;
            }

            var parent = simpleField.Parent as OpenXmlCompositeElement;
            if (parent == null)
            {
                return;
            }

            var firstRun = simpleField.Descendants<Run>().FirstOrDefault();
            var replacementRun = CreateReplacementRun(GetRunPropertiesClone(firstRun), replacementText);

            parent.InsertBefore(replacementRun, simpleField);
            simpleField.Remove();
        }

        private static void ReplaceContentControlText(SdtElement sdtElement, string replacementText)
        {
            if (sdtElement == null)
            {
                return;
            }

            if (sdtElement is SdtRun sdtRun)
            {
                var content = sdtRun.GetFirstChild<SdtContentRun>();
                if (content == null)
                {
                    content = sdtRun.AppendChild(new SdtContentRun());
                }

                content.RemoveAllChildren();
                content.Append(CreateReplacementRun(null, replacementText));
                return;
            }

            if (sdtElement is SdtBlock sdtBlock)
            {
                var content = sdtBlock.GetFirstChild<SdtContentBlock>();
                if (content == null)
                {
                    content = sdtBlock.AppendChild(new SdtContentBlock());
                }

                content.RemoveAllChildren();
                content.Append(new Paragraph(CreateReplacementRun(null, replacementText)));
                return;
            }

            if (sdtElement is SdtCell sdtCell)
            {
                var content = sdtCell.GetFirstChild<SdtContentCell>();
                if (content == null)
                {
                    content = sdtCell.AppendChild(new SdtContentCell());
                }

                content.RemoveAllChildren();
                content.Append(new TableCell(new Paragraph(CreateReplacementRun(null, replacementText))));
            }
        }

        private static Run? FindMergeFieldBoundaryRun(Run startRun, FieldCharValues boundaryType, bool searchBackwards)
        {
            OpenXmlElement? current = startRun;

            while (current != null)
            {
                var run = current as Run;
                var fieldChar = run?.GetFirstChild<FieldChar>();

                if (fieldChar?.FieldCharType?.Value == boundaryType)
                {
                    return run;
                }

                current = searchBackwards ? current.PreviousSibling() : current.NextSibling();
            }

            return null;
        }

        private static Run CreateReplacementRun(RunProperties? runProperties, string? replacementText)
        {
            var run = new Run();

            if (runProperties != null)
            {
                run.Append((RunProperties)runProperties.CloneNode(true));
            }

            run.Append(CreateTextElement(replacementText));
            return run;
        }

        private static Text CreateTextElement(string? value)
        {
            var text = new Text(value ?? string.Empty);
            ApplySpacePreserveIfNeeded(text);
            return text;
        }

        private static RunProperties? GetRunPropertiesClone(Run? run)
        {
            return run?.RunProperties?.CloneNode(true) as RunProperties;
        }

        private static void ApplySpacePreserveIfNeeded(Text text)
        {
            if (text == null)
            {
                return;
            }

            var value = text.Text ?? string.Empty;

            if (value.StartsWith(" ", StringComparison.Ordinal) ||
                value.EndsWith(" ", StringComparison.Ordinal) ||
                value.Contains("  ", StringComparison.Ordinal))
            {
                text.Space = SpaceProcessingModeValues.Preserve;
            }
            else
            {
                text.Space = null;
            }
        }

        private static bool ContentControlLooksUnresolved(SdtElement sdt, string fieldName)
        {
            var rawText = sdt.InnerText ?? string.Empty;
            return rawText.Contains($"«{fieldName}»", StringComparison.OrdinalIgnoreCase)
                   || string.Equals(rawText.Trim(), fieldName.Trim(), StringComparison.OrdinalIgnoreCase);
        }

        #endregion Public Methods

        #region Private Methods

        private static void CopyRelationships(OpenXmlPart sourcePart, OpenXmlPart targetPart, WordprocessingDocument targetDoc)
        {
            // Copy external relationships
            foreach (var externalRelationship in sourcePart.ExternalRelationships)
            {
                targetPart.AddExternalRelationship(externalRelationship.RelationshipType, externalRelationship.Uri);
            }

            // Copy child parts recursively
            foreach (var relationship in sourcePart.Parts)
            {
                var sourceChildPart = relationship.OpenXmlPart;
                var targetChildPart = targetPart.AddPart(sourceChildPart, relationship.RelationshipId);
                CopyRelationships(sourceChildPart, targetChildPart, targetDoc);
            }
        }

        private static SectionProperties GetSectionProperties(Body body)
        {
            return body.Elements<SectionProperties>().LastOrDefault()?.CloneNode(true) as SectionProperties;
        }

        #endregion Private Methods
    }
}