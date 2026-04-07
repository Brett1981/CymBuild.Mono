using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;

namespace Concursus.API.Classes
{
    public static class WordDocumentFixer
    {
        public static byte[] FixBeforeUpload(byte[] documentContent, ILogger? logger = null)
        {
            using var fixedStream = ToExpandableStream(documentContent);

            using var wordDoc = WordprocessingDocument.Open(fixedStream, true);
            var mainPart = wordDoc.MainDocumentPart ?? throw new Exception("Missing MainDocumentPart");

            logger?.LogInformation("[FIX] Starting Word document fix...");

            EnsureUniqueBookmarkIds(mainPart, logger);
            RemoveBrokenHyperlinkReferences(mainPart, logger);
            RemoveInvalidTableLookAttributes(mainPart, logger);
            EnsureSectionProperties(mainPart, logger);
            RemoveOrphanedStyleDefinitions(wordDoc, logger);
            NormalizeParagraphSpacing(mainPart, logger);
            CleanUnexpectedNumberingElements(mainPart, logger);

            mainPart.Document.Save();

            logger?.LogInformation("[FIX] Document fix complete.");
            return fixedStream.ToArray();
        }

        private static void EnsureUniqueBookmarkIds(MainDocumentPart mainPart, ILogger? logger = null)
        {
            var usedIds = new HashSet<string>();
            uint nextId = 0;

            foreach (var bookmark in mainPart.Document.Descendants<BookmarkStart>())
            {
                if (usedIds.Contains(bookmark.Id))
                {
                    logger?.LogWarning($"[FIX] Duplicate BookmarkStart Id {bookmark.Id} found. Assigning new Id: {nextId}");
                    bookmark.Id = (nextId++).ToString();
                }
                else
                {
                    usedIds.Add(bookmark.Id);
                    nextId = Math.Max(nextId, uint.Parse(bookmark.Id) + 1);
                }
            }

            foreach (var bookmarkEnd in mainPart.Document.Descendants<BookmarkEnd>())
            {
                if (!usedIds.Contains(bookmarkEnd.Id))
                {
                    logger?.LogWarning($"[FIX] Orphaned BookmarkEnd Id {bookmarkEnd.Id}. Updating to {nextId}");
                    bookmarkEnd.Id = (nextId++).ToString();
                }
            }
        }

        private static void RemoveBrokenHyperlinkReferences(MainDocumentPart mainPart, ILogger? logger = null)
        {
            var validIds = mainPart.HyperlinkRelationships.Select(r => r.Id).ToHashSet();

            foreach (var hyperlink in mainPart.Document.Descendants<Hyperlink>().ToList())
            {
                if (!validIds.Contains(hyperlink.Id))
                {
                    logger?.LogWarning($"[FIX] Removing broken hyperlink with rId='{hyperlink.Id}'");
                    hyperlink.Remove();
                }
            }
        }

        private static MemoryStream ToExpandableStream(byte[] content)
        {
            var stream = new MemoryStream();
            stream.Write(content, 0, content.Length);
            stream.Position = 0;
            return stream;
        }

        private static void RemoveInvalidTableLookAttributes(MainDocumentPart mainPart, ILogger? logger = null)
        {
            // Define known bad attribute names (based on OpenXmlValidator results)
            var badAttributeNames = new HashSet<string>
    {
        "firstRow", "lastRow", "firstColumn", "lastColumn", "noHBand", "noVBand",
        "allStyles", "customStyles", "latentStyles", "stylesInUse",
        "headingStyles", "numberingStyles", "tableStyles", "directFormattingOnRuns",
        "directFormattingOnParagraphs", "directFormattingOnNumbering", "directFormattingOnTables",
        "clearFormatting", "top3HeadingStyles", "visibleStyles", "alternateStyleNames"
    };

            foreach (var element in mainPart.Document.Descendants())
            {
                var attrs = element.GetAttributes();
                var toRemove = attrs.Where(a => badAttributeNames.Contains(a.LocalName)).ToList();

                foreach (var attr in toRemove)
                {
                    logger?.LogWarning($"[FIX] Removing bad attribute '{attr.LocalName}' from element {element.LocalName}");
                    element.RemoveAttribute(attr.LocalName, attr.NamespaceUri);
                }
            }
        }

        private static void CleanUnexpectedNumberingElements(MainDocumentPart mainPart, ILogger? logger = null)
        {
            var numberingPart = mainPart.NumberingDefinitionsPart;
            if (numberingPart == null) return;

            var invalids = numberingPart.Numbering
                .Descendants()
                .Where(e => e.LocalName == "numIdMacAtCleanup")
                .ToList();

            foreach (var bad in invalids)
            {
                logger?.LogWarning($"[FIX] Removing invalid element <{bad.LocalName}> from numbering.xml");
                bad.Remove();
            }
        }

        private static void EnsureSectionProperties(MainDocumentPart mainPart, ILogger? logger = null)
        {
            var body = mainPart.Document.Body;
            if (!body.Elements<SectionProperties>().Any() &&
                !body.Descendants<SectionProperties>().Any())
            {
                logger?.LogWarning("[FIX] Document missing SectionProperties. Adding default one.");
                var section = new SectionProperties(new PageSize(), new PageMargin());
                body.Append(section);
            }
        }

        private static void RemoveOrphanedStyleDefinitions(WordprocessingDocument doc, ILogger? logger = null)
        {
            if (doc.MainDocumentPart.StyleDefinitionsPart != null)
            {
                var stylePart = doc.MainDocumentPart.StyleDefinitionsPart;
                var styles = stylePart.Styles;

                if (!styles.Elements<Style>().Any())
                {
                    logger?.LogWarning("[FIX] Removing orphaned StyleDefinitionsPart (no styles found).");
                    doc.MainDocumentPart.DeletePart(stylePart);
                }
            }
        }

        private static void NormalizeParagraphSpacing(MainDocumentPart mainPart, ILogger? logger = null)
        {
            var paragraphs = mainPart.Document.Descendants<Paragraph>();
            foreach (var para in paragraphs)
            {
                var props = para.GetFirstChild<ParagraphProperties>();
                if (props?.SpacingBetweenLines != null)
                {
                    props.SpacingBetweenLines.After = "0";
                    props.SpacingBetweenLines.Before = "0";
                    logger?.LogInformation("[FIX] Normalized paragraph spacing.");
                }
            }
        }
    }
}