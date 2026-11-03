using Concursus.API.Classes;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using Xunit;
// Narrow aliases (not a blanket "using DocumentFormat.OpenXml.Spreadsheet") - that namespace
// has Cell/Row/Table/Run/Text names that collide with the Wordprocessing types used to build
// the sample .docx below. Mirrors the alias pattern in WordDocumentService.cs itself.
using XlsxCell = DocumentFormat.OpenXml.Spreadsheet.Cell;
using XlsxRow = DocumentFormat.OpenXml.Spreadsheet.Row;
using XlsxSheetData = DocumentFormat.OpenXml.Spreadsheet.SheetData;

namespace Concursus.API.Tests.Documents;

/// <summary>
/// CYB-537: WordDocumentService.ConvertWordToExcel/ExtractTablesFromWord were rewritten from
/// Telerik Document Processing (RadFlowDocument/Workbook) to plain DocumentFormat.OpenXml, as
/// part of removing Telerik from the solution. These cover the pure, DB/SharePoint/Graph-free
/// table-extraction and Excel-writing logic.
/// </summary>
public sealed class WordDocumentServiceExcelExportTests
{
    [Theory]
    [InlineData(0, "A")]
    [InlineData(1, "B")]
    [InlineData(25, "Z")]
    [InlineData(26, "AA")]
    [InlineData(27, "AB")]
    [InlineData(51, "AZ")]
    [InlineData(52, "BA")]
    [InlineData(701, "ZZ")]
    [InlineData(702, "AAA")]
    public void GetExcelColumnName_ConvertsZeroBasedIndexToExcelColumnLetters(int index, string expected)
    {
        Assert.Equal(expected, WordDocumentService.GetExcelColumnName(index));
    }

    [Fact]
    public void ExtractTablesFromWord_ReturnsCellTextGroupedByTableThenRow()
    {
        var docBytes = CreateWordDocumentWithTables(
            new[]
            {
                new[] { "Header1", "Header2" },
                new[] { "A1", "B1" }
            },
            new[]
            {
                new[] { "X1", "Y1" }
            });

        using var stream = new MemoryStream(docBytes, writable: false);

        var tables = WordDocumentService.ExtractTablesFromWord(stream);

        Assert.Equal(2, tables.Count);
        Assert.Equal(new List<List<string>> { new() { "Header1", "Header2" }, new() { "A1", "B1" } }, tables[0]);
        Assert.Equal(new List<List<string>> { new() { "X1", "Y1" } }, tables[1]);
    }

    [Fact]
    public void ExtractTablesFromWord_JoinsMultipleParagraphsInACellWithNewline()
    {
        using var stream = new MemoryStream();
        using (var document = WordprocessingDocument.Create(stream, WordprocessingDocumentType.Document, autoSave: true))
        {
            var mainPart = document.AddMainDocumentPart();

            var cell = new TableCell(
                new Paragraph(new Run(new Text("Line one"))),
                new Paragraph(new Run(new Text("Line two"))));
            var table = new Table(new TableRow(cell));
            var body = new Body(table, new SectionProperties());

            mainPart.Document = new Document(body);
            mainPart.Document.Save();
        }

        using var readStream = new MemoryStream(stream.ToArray(), writable: false);
        var tables = WordDocumentService.ExtractTablesFromWord(readStream);

        Assert.Equal("Line one" + Environment.NewLine + "Line two", tables[0][0][0]);
    }

    [Fact]
    public async Task ConvertWordToExcel_WritesTableCellsIntoXlsxLeavingABlankRowBetweenTables()
    {
        var docBytes = CreateWordDocumentWithTables(
            new[] { new[] { "Name", "Amount" }, new[] { "Widget", "10" } },
            new[] { new[] { "Other", "5" } });

        using var docStream = new MemoryStream(docBytes, writable: false);

        using var excelStream = await WordDocumentService.ConvertWordToExcel(docStream);

        using var spreadsheet = SpreadsheetDocument.Open(excelStream, false);
        var worksheetPart = spreadsheet.WorkbookPart!.WorksheetParts.Single();
        var sheetData = worksheetPart.Worksheet.Elements<XlsxSheetData>().Single();
        var rows = sheetData.Elements<XlsxRow>().ToList();

        // Table 1 occupies rows 1-2, row 3 is the blank spacer (no <row> element emitted for it),
        // table 2 resumes at row 4.
        Assert.Equal(3, rows.Count);
        Assert.Equal(new[] { "Name", "Amount" }, GetRowValues(rows[0]));
        Assert.Equal(new[] { "Widget", "10" }, GetRowValues(rows[1]));
        Assert.Equal(new[] { "Other", "5" }, GetRowValues(rows[2]));
        Assert.Equal(4u, rows[2].RowIndex!.Value);
    }

    private static string[] GetRowValues(XlsxRow row) =>
        row.Elements<XlsxCell>().Select(c => c.InlineString?.Text?.Text ?? string.Empty).ToArray();

    private static byte[] CreateWordDocumentWithTables(params string[][][] tables)
    {
        using var stream = new MemoryStream();

        using (var document = WordprocessingDocument.Create(stream, WordprocessingDocumentType.Document, autoSave: true))
        {
            var mainPart = document.AddMainDocumentPart();
            var body = new Body();

            foreach (var tableRows in tables)
            {
                var table = new Table();
                foreach (var rowValues in tableRows)
                {
                    var row = new TableRow();
                    foreach (var cellText in rowValues)
                    {
                        row.Append(new TableCell(new Paragraph(new Run(new Text(cellText)))));
                    }
                    table.Append(row);
                }
                body.Append(table);
            }

            body.Append(new SectionProperties());
            mainPart.Document = new Document(body);
            mainPart.Document.Save();
        }

        return stream.ToArray();
    }
}
