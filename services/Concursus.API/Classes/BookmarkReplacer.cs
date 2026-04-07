using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;

namespace Concursus.API.Classes
{
    public class BookmarkReplacer
    {
        #region Public Methods

        // Method to add SOCOTEC style if it doesn't exist
        public void AddSocotecStyle(MainDocumentPart mainPart)
        {
            var stylesPart = mainPart.StyleDefinitionsPart;
            if (stylesPart == null)
            {
                stylesPart = mainPart.AddNewPart<StyleDefinitionsPart>();
                stylesPart.Styles = new Styles();
            }

            // Check if the style already exists
            if (StyleExists("SOCOTEC", mainPart))
            {
                Console.WriteLine("SOCOTEC style already exists. Skipping.");
                return;
            }

            var socotecStyle = new Style()
            {
                StyleId = "SOCOTEC",
                Type = StyleValues.Table,
                StyleName = new StyleName() { Val = "SOCOTEC" },
                BasedOn = new BasedOn() { Val = "TableNormal" },
                UIPriority = new UIPriority() { Val = 99 },
                PrimaryStyle = new PrimaryStyle()
            };

            var styleTableProperties = new StyleTableProperties(
                new TableBorders(
                    new TopBorder() { Val = BorderValues.Single, Size = 8, Color = "000000" },
                    new BottomBorder() { Val = BorderValues.Single, Size = 8, Color = "000000" },
                    new LeftBorder() { Val = BorderValues.Single, Size = 8, Color = "000000" },
                    new RightBorder() { Val = BorderValues.Single, Size = 8, Color = "000000" }
                ),
                new TableWidth { Width = "5000", Type = TableWidthUnitValues.Pct }
            );

            // **Apply Blue Header Background**
            var tableShading = new TableCellProperties(
                new Shading()
                {
                    Fill = "0070C0", // Blue for header background
                    Val = ShadingPatternValues.Clear
                }
            );

            socotecStyle.Append(styleTableProperties);
            socotecStyle.Append(tableShading);

            stylesPart.Styles.Append(socotecStyle);
            stylesPart.Styles.Save();

            Console.WriteLine("Added 'SOCOTEC' table style to the document.");
        }

        public Table GenerateTable(List<Dictionary<string, string>> rowData, MainDocumentPart mainPart, string bookmarkName)
        {
            var table = new Table();

            // Ensure SOCOTEC style exists, if not add it
            if (!StyleExists("SOCOTEC", mainPart))
            {
                AddSocotecStyle(mainPart);
            }

            // **Explicitly assign the SOCOTEC style to the table**
            var tableProperties = new TableProperties(
                new TableStyle { Val = "SOCOTEC" } // Assign SOCOTEC style
            );
            table.AppendChild(tableProperties);

            // Add header row
            if (rowData.Any())
            {
                var headerRow = new TableRow();
                foreach (var header in rowData[0].Keys)
                {
                    var headerCell = CreateHeaderCell(header, true); // Ensuring bold styling for headers
                    headerRow.AppendChild(headerCell);
                }
                table.AppendChild(headerRow);
            }

            // Add data rows
            foreach (var rowDict in rowData)
            {
                var row = new TableRow();
                foreach (var cellValue in rowDict.Values)
                {
                    var cell = new TableCell(new Paragraph(new Run(new Text(cellValue))));
                    row.AppendChild(cell);
                }
                table.AppendChild(row);
            }

            return table;
        }

        public void ReplaceBookmarksWithTables(Stream inputStream, Dictionary<string, List<Dictionary<string, string>>> bookmarkTableData, Stream outputStream)
        {
            // Use a temporary writable memory stream
            using (var tempStream = new MemoryStream())
            {
                // Copy the inputStream into a writable temporary stream
                inputStream.CopyTo(tempStream);
                tempStream.Position = 0;

                // Open the Word document from the temporary stream
                using (var wordDoc = WordprocessingDocument.Open(tempStream, true))
                {
                    var mainPart = wordDoc.MainDocumentPart;

                    // Log all bookmarks found in the document
                    Console.WriteLine("Found Bookmarks:");
                    foreach (var bookmark in mainPart.Document.Body.Descendants<BookmarkStart>())
                    {
                        Console.WriteLine($"Bookmark: {bookmark.Name}, Parent: {bookmark.Parent?.LocalName}");
                    }

                    foreach (var bookmarkName in bookmarkTableData.Keys)
                    {
                        Console.WriteLine($"Processing bookmark: {bookmarkName}");

                        var bookmark = FindBookmark(mainPart, bookmarkName);

                        if (bookmark != null)
                        {
                            Console.WriteLine($"Bookmark '{bookmarkName}' found. Parent: {bookmark.Parent?.LocalName}");
                            Console.WriteLine($"Attempting to replace bookmark '{bookmarkName}'...");

                            var tableData = bookmarkTableData[bookmarkName];
                            LogTableData(bookmarkName, tableData);

                            var table = GenerateTable(tableData, mainPart, bookmarkName);

                            try
                            {
                                ReplaceBookmarkWithTable(bookmark, table);
                                Console.WriteLine($"Successfully replaced bookmark '{bookmarkName}' with a table.");
                            }
                            catch (Exception ex)
                            {
                                Console.WriteLine($"Error replacing bookmark '{bookmarkName}': {ex.Message}");
                            }
                        }
                        else
                        {
                            Console.WriteLine($"Bookmark '{bookmarkName}' not found.");
                        }
                    }

                    // Save the changes back to the temporary stream
                    wordDoc.MainDocumentPart.Document.Save();
                }

                // Copy the modified document to the output stream
                tempStream.Position = 0;
                tempStream.CopyTo(outputStream);
                outputStream.Position = 0;
            }
        }

        #endregion Public Methods

        #region Private Methods

        //    return table;
        //}
        private TableCell CreateHeaderCell(string headerText, bool socotecStyleExists)
        {
            var headerCell = new TableCell(new Paragraph(new Run(new Text(headerText))
            {
                RunProperties = new RunProperties(new Bold())  // Bold text for headers
            }));

            if (!socotecStyleExists)  // Apply shading if SOCOTEC style is not present
            {
                var cellProperties = new TableCellProperties(
                    new Shading
                    {
                        Fill = "B0C4DE",  // Light Blue (#B0C4DE)
                        Val = ShadingPatternValues.Clear
                    }
                );
                headerCell.Append(cellProperties);
            }

            return headerCell;
        }

        private BookmarkStart FindBookmark(MainDocumentPart mainPart, string bookmarkName)
        {
            // Search in the document body
            var bookmark = mainPart.Document.Body.Descendants<BookmarkStart>()
                .FirstOrDefault(b => b.Name == bookmarkName);

            if (bookmark != null)
            {
                Console.WriteLine($"Bookmark '{bookmarkName}' found in body. Parent: {bookmark.Parent?.LocalName}");
                return bookmark;
            }

            // Search within drawings or text boxes
            var drawingBookmarks = mainPart.Document.Body.Descendants<Drawing>()
                .SelectMany(d => d.Descendants<BookmarkStart>())
                .FirstOrDefault(b => b.Name == bookmarkName);

            if (drawingBookmarks != null)
            {
                Console.WriteLine($"Bookmark '{bookmarkName}' found in a drawing or text box. Parent: {drawingBookmarks.Parent?.LocalName}");
            }
            else
            {
                Console.WriteLine($"Bookmark '{bookmarkName}' not found.");
            }

            return drawingBookmarks;
        }

        //private Table GenerateTable(List<Dictionary<string, string>> rowData, MainDocumentPart mainPart)
        //{
        //    var table = new Table();
        //    // Check if the "SOCOTEC" style exists in the document
        //    bool socotecStyleExists = StyleExists("SOCOTEC", mainPart);
        //    // Set table width and borders
        //    var tableProperties = new TableProperties(
        //        new TableWidth { Width = "100%", Type = TableWidthUnitValues.Pct }  // Auto-fit to page width
        //    );

        // if (socotecStyleExists) { Console.WriteLine("Applying 'SOCOTEC' table style.");
        // tableProperties.Append(new TableStyle { Val = "SOCOTEC" }); } else {
        // Console.WriteLine("SOCOTEC style not found. Adding and applying custom styling.");
        // AddSocotecStyle(mainPart); // Add SOCOTEC style to the document
        // tableProperties.Append(new TableStyle { Val = "SOCOTEC" });

        // // Apply custom borders if SOCOTEC does not exist tableProperties.Append( new
        // TableBorders( new TopBorder() { Val = BorderValues.Single, Color = "000000", Size = 4,
        // Space = 0 }, new LeftBorder() { Val = BorderValues.Single, Color = "000000", Size = 4,
        // Space = 0 }, new BottomBorder() { Val = BorderValues.Single, Color = "000000", Size = 4,
        // Space = 0 }, new RightBorder() { Val = BorderValues.Single, Color = "000000", Size = 4,
        // Space = 0 }, new InsideHorizontalBorder() { Val = BorderValues.Single, Color = "000000",
        // Size = 4, Space = 0 }, new InsideVerticalBorder() { Val = BorderValues.Single, Color =
        // "000000", Size = 4, Space = 0 } ) ); }

        // table.AppendChild(tableProperties);

        // // Add header row if (rowData.Count > 0) { var headerRow = new TableRow(); foreach (var
        // header in rowData[0].Keys) { var headerCell = new TableCell(new Paragraph(new Run(new
        // Text(header)) { RunProperties = new RunProperties(new Bold()) // Bold text for headers
        // })); if (!socotecStyleExists) // Apply blue shading only if SOCOTEC is not found { var
        // cellProperties = new TableCellProperties( new Shading { Fill = "00B8502F", // Light Blue
        // (hex: #B0C4DE) Val = ShadingPatternValues.Clear } ); headerCell.Append(cellProperties); }
        // headerRow.AppendChild(headerCell); } table.AppendChild(headerRow); }

        // // Add data rows foreach (var rowDict in rowData) { var row = new TableRow(); foreach
        // (var cellValue in rowDict.Values) { var cell = new TableCell(new Paragraph(new Run(new
        // Text(cellValue)))); row.AppendChild(cell); } table.AppendChild(row); }
        private void LogTableData(string bookmarkName, List<Dictionary<string, string>> tableData)
        {
            Console.WriteLine($"Content for table at bookmark '{bookmarkName}':");

            if (tableData.Count == 0)
            {
                Console.WriteLine("No rows found for this table.");
                return;
            }

            // Log headers
            Console.WriteLine(string.Join(" | ", tableData[0].Keys));

            // Log each row
            foreach (var row in tableData)
            {
                Console.WriteLine(string.Join(" | ", row.Values));
            }
        }

        private void ReplaceBookmarkWithTable(BookmarkStart bookmark, Table table)
        {
            var parentElement = bookmark.Parent;

            // Handle TextBox (Drawing) content
            if (parentElement is Run && parentElement.Parent is Paragraph paragraph)
            {
                if (paragraph.Parent is Drawing drawing)
                {
                    // Locate the TextBox content
                    var textBoxContent = drawing.Descendants<Paragraph>().FirstOrDefault();
                    if (textBoxContent != null)
                    {
                        Console.WriteLine($"Replacing content in TextBox for bookmark '{bookmark.Name}'...");
                        textBoxContent.RemoveAllChildren(); // Clear existing content
                        textBoxContent.AppendChild(new Paragraph(new Run(table))); // Wrap the table in a paragraph
                        return;
                    }
                }
            }

            // Handle normal bookmark replacement
            Console.WriteLine($"Replacing normal bookmark '{bookmark.Name}'...");
            var elementsToRemove = new List<OpenXmlElement>();
            var currentElement = bookmark.NextSibling();

            while (currentElement != null && !(currentElement is BookmarkEnd))
            {
                elementsToRemove.Add(currentElement);
                currentElement = currentElement.NextSibling();
            }

            foreach (var element in elementsToRemove)
            {
                element.Remove();
            }

            if (parentElement is Paragraph parentParagraph)
            {
                parentParagraph.Parent.InsertAfterSelf(table);

                // Remove the BookmarkEnd to avoid conflicts
                var bookmarkEnd = parentParagraph.Descendants<BookmarkEnd>()
                                                 .FirstOrDefault(b => b.Id == bookmark.Id);
                bookmarkEnd?.Remove();

                bookmark.Remove();
            }
            else
            {
                throw new InvalidOperationException("Bookmark is not inside a valid Paragraph.");
            }
        }

        // Method to check if a style exists in the document
        private bool StyleExists(string styleId, MainDocumentPart mainPart)
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

        #endregion Private Methods
    }
}