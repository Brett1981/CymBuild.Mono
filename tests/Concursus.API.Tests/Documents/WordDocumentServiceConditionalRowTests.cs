using Concursus.API.Classes;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using Xunit;

namespace Concursus.API.Tests.Documents;

/// <summary>
/// CYB-323: covers the two pure, DB/SharePoint-free pieces of the new "Conditional Row"
/// mechanism - the MergeDocument.Guid routing check, and the OpenXML table-row removal
/// itself. ProcessConditionalRowsAsync (which calls EF.Core.GetQuoteItemMergeLines /
/// GetGatingRulesForMergeDocumentItem) is not covered here - its decision logic is covered by
/// ConditionalRowMergeEvaluatorTests, but the SQL itself needs a real SQL Server
/// with Quotes/QuoteItems/MergeDocumentItemGatingProducts data, which is not currently stubbed
/// in CymBuild.Database.IntegrationTests (only SCore.Identities is). See the Phase 1 plan doc
/// for that gap.
/// </summary>
public sealed class WordDocumentServiceConditionalRowTests
{
    private const string FireEngineeringFeeProposalGuid = "c26adae4-cbd1-44a6-876a-1f51d7733ae6";

    [Theory]
    [InlineData("c26adae4-cbd1-44a6-876a-1f51d7733ae6", true)]
    [InlineData("C26ADAE4-CBD1-44A6-876A-1F51D7733AE6", true)] // case-insensitive Guid parsing
    [InlineData("00000000-0000-0000-0000-000000000000", false)]
    [InlineData("11111111-1111-1111-1111-111111111111", false)]
    [InlineData("not-a-guid", false)]
    [InlineData("", false)]
    public void IsFireEngineeringFeeProposalDocument_OnlyMatchesTheFeeProposalMergeDocumentGuid(
        string mergeDocumentGuid, bool expected)
    {
        Assert.Equal(expected, WordDocumentService.IsFireEngineeringFeeProposalDocument(mergeDocumentGuid));
    }

    [Fact]
    public void RemoveTableRowAtBookmark_RemovesOnlyTheBookmarkedRow()
    {
        var document = CreateDocumentWithTable(bookmarkInSecondRow: true);

        var result = WordDocumentService.RemoveTableRowAtBookmark(document, "GatedRow");

        using var stream = new MemoryStream(result, writable: false);
        using var wordDoc = WordprocessingDocument.Open(stream, false);
        var rows = wordDoc.MainDocumentPart!.Document.Body!.Descendants<TableRow>().ToList();

        Assert.Single(rows);
        Assert.Contains("Keep me", rows[0].InnerText);
        Assert.DoesNotContain("Remove me", rows[0].InnerText);
    }

    [Fact]
    public void RemoveTableRowAtBookmark_LeavesDocumentUnchangedWhenBookmarkNotFound()
    {
        var document = CreateDocumentWithTable(bookmarkInSecondRow: true);

        var result = WordDocumentService.RemoveTableRowAtBookmark(document, "NoSuchBookmark");

        using var stream = new MemoryStream(result, writable: false);
        using var wordDoc = WordprocessingDocument.Open(stream, false);
        var rows = wordDoc.MainDocumentPart!.Document.Body!.Descendants<TableRow>().ToList();

        Assert.Equal(2, rows.Count);
    }

    [Fact]
    public void RemoveTableRowAtBookmark_HandsVerticalMergeRestartToTheNextRow()
    {
        // Fee Proposal Table 1 shape: the stage label starts a vertical merge in the stage's
        // first (conditional) row and continues down the rows below it.
        var document = CreateDocumentWithStageTable();

        var result = WordDocumentService.RemoveTableRowAtBookmark(document, "FirstRow");

        var rows = ReadRows(result);
        Assert.Equal(2, rows.Count);
        var labelCell = rows[0].Elements<TableCell>().First();
        Assert.Equal(MergedCellValues.Restart, labelCell.TableCellProperties!.VerticalMerge!.Val!.Value);
        Assert.Equal("Stage 2 label", labelCell.InnerText);
        Assert.Contains("Second deliverable", rows[0].InnerText);
        Assert.Null(rows[1].Elements<TableCell>().First().TableCellProperties!.VerticalMerge!.Val);
    }

    [Fact]
    public void RemoveTableRowAtBookmark_HandsVerticalMergeRestartDownThroughSuccessiveRemovals()
    {
        var document = CreateDocumentWithStageTable();

        var result = WordDocumentService.RemoveTableRowAtBookmark(
            WordDocumentService.RemoveTableRowAtBookmark(document, "FirstRow"),
            "SecondRow");

        var rows = ReadRows(result);
        var labelCell = Assert.Single(rows).Elements<TableCell>().First();
        Assert.Equal(MergedCellValues.Restart, labelCell.TableCellProperties!.VerticalMerge!.Val!.Value);
        Assert.Equal("Stage 2 label", labelCell.InnerText);
        Assert.Contains("Subtotal", rows[0].InnerText);
    }

    [Fact]
    public void RemoveTableRowAtBookmark_LeavesMergeAloneWhenRemovingAContinuationRow()
    {
        var document = CreateDocumentWithStageTable();

        var result = WordDocumentService.RemoveTableRowAtBookmark(document, "SecondRow");

        var rows = ReadRows(result);
        Assert.Equal(2, rows.Count);
        var labelCell = rows[0].Elements<TableCell>().First();
        Assert.Equal(MergedCellValues.Restart, labelCell.TableCellProperties!.VerticalMerge!.Val!.Value);
        Assert.Equal("Stage 2 label", labelCell.InnerText);
        Assert.Contains("First deliverable", rows[0].InnerText);
    }

    [Fact]
    public void RepeatTableRowAtBookmark_AddsOneCopyPerLineWithNumberedFields()
    {
        var document = CreateDocumentWithRepeatRow();

        var result = WordDocumentService.RepeatTableRowAtBookmark(document, "FP_T1_S1_EACH", 3);

        var rows = ReadRows(result);
        Assert.Equal(5, rows.Count);
        for (int copy = 1; copy <= 3; copy++)
        {
            Assert.Contains($"«FP_T1_S1_EACH_Deliverables_{copy}»", rows[copy - 1].InnerText);
            Assert.Contains($"«FP_T1_S1_EACH_Fee_{copy}»", rows[copy - 1].InnerText);
        }
        Assert.Contains("Subtotal", rows[3].InnerText);
        Assert.Contains("After", rows[4].InnerText);
    }

    [Fact]
    public void RepeatTableRowAtBookmark_KeepsTheBookmarkOnTheFirstCopyOnly()
    {
        var result = WordDocumentService.RepeatTableRowAtBookmark(CreateDocumentWithRepeatRow(), "FP_T1_S1_EACH", 2);

        var rows = ReadRows(result);
        Assert.Single(rows[0].Descendants<BookmarkStart>());
        Assert.Empty(rows[1].Descendants<BookmarkStart>());
        Assert.Empty(rows[1].Descendants<BookmarkEnd>());
    }

    [Fact]
    public void RepeatTableRowAtBookmark_StageLabelSpansEveryCopy()
    {
        var result = WordDocumentService.RepeatTableRowAtBookmark(CreateDocumentWithRepeatRow(), "FP_T1_S1_EACH", 2);

        var rows = ReadRows(result);
        var firstLabel = rows[0].Elements<TableCell>().First();
        var copyLabel = rows[1].Elements<TableCell>().First();
        Assert.Equal(MergedCellValues.Restart, firstLabel.TableCellProperties!.VerticalMerge!.Val!.Value);
        Assert.Equal("Stage 1 label", firstLabel.InnerText);
        Assert.Equal(MergedCellValues.Continue, copyLabel.TableCellProperties!.VerticalMerge!.Val!.Value);
        Assert.Equal(string.Empty, copyLabel.InnerText);
    }

    [Fact]
    public void RepeatTableRowAtBookmark_SingleLineOnlyNumbersTheFields()
    {
        var result = WordDocumentService.RepeatTableRowAtBookmark(CreateDocumentWithRepeatRow(), "FP_T1_S1_EACH", 1);

        var rows = ReadRows(result);
        Assert.Equal(3, rows.Count);
        Assert.Contains("«FP_T1_S1_EACH_Fee_1»", rows[0].InnerText);
    }

    [Fact]
    public void RepeatTableRowAtBookmark_LeavesDocumentUnchangedWhenBookmarkNotFound()
    {
        var document = CreateDocumentWithRepeatRow();

        var result = WordDocumentService.RepeatTableRowAtBookmark(document, "NoSuchBookmark", 3);

        Assert.Equal(3, ReadRows(result).Count);
    }

    private static List<TableRow> ReadRows(byte[] document)
    {
        using var stream = new MemoryStream(document, writable: false);
        using var wordDoc = WordprocessingDocument.Open(stream, false);
        return wordDoc.MainDocumentPart!.Document.Body!.Descendants<TableRow>()
            .Select(r => (TableRow)r.CloneNode(true))
            .ToList();
    }

    private static byte[] CreateDocumentWithStageTable()
    {
        static TableCell LabelCell(MergedCellValues? merge, string text) =>
            new(
                new TableCellProperties(merge == null
                    ? new VerticalMerge()
                    : new VerticalMerge { Val = merge }),
                new Paragraph(new Run(new Text(text))));

        static TableCell BodyCell(string text, string? bookmark = null, string bookmarkId = "1")
        {
            var paragraph = bookmark == null
                ? new Paragraph(new Run(new Text(text)))
                : new Paragraph(
                    new BookmarkStart { Name = bookmark, Id = bookmarkId },
                    new Run(new Text(text)),
                    new BookmarkEnd { Id = bookmarkId });
            return new TableCell(paragraph);
        }

        using var stream = new MemoryStream();

        using (var document = WordprocessingDocument.Create(
                   stream,
                   WordprocessingDocumentType.Document,
                   autoSave: true))
        {
            var mainPart = document.AddMainDocumentPart();

            var table = new Table(
                new TableRow(LabelCell(MergedCellValues.Restart, "Stage 2 label"), BodyCell("First deliverable", "FirstRow")),
                new TableRow(LabelCell(null, string.Empty), BodyCell("Second deliverable", "SecondRow", "2")),
                new TableRow(LabelCell(null, string.Empty), BodyCell("Subtotal")));

            mainPart.Document = new Document(new Body(table, new SectionProperties()));
            mainPart.Document.Save();
        }

        return stream.ToArray();
    }

    // A new-style Fee Proposal section: the stage label starts a vertical merge in the repeated
    // row and continues into the subtotal row; a row outside the section follows.
    private static byte[] CreateDocumentWithRepeatRow()
    {
        static TableCell Cell(string text, MergedCellValues? merge = null, bool merged = false) =>
            merged
                ? new TableCell(new TableCellProperties(merge == null ? new VerticalMerge() : new VerticalMerge { Val = merge }),
                    new Paragraph(new Run(new Text(text))))
                : new TableCell(new Paragraph(new Run(new Text(text))));

        var repeatParagraph = new Paragraph(
            new BookmarkStart { Name = "FP_T1_S1_EACH", Id = "1" },
            new Run(new Text("«FP_T1_S1_EACH_Deliverables»")),
            new BookmarkEnd { Id = "1" });

        using var stream = new MemoryStream();
        using (var document = WordprocessingDocument.Create(stream, WordprocessingDocumentType.Document, autoSave: true))
        {
            var mainPart = document.AddMainDocumentPart();
            var table = new Table(
                new TableRow(Cell("Stage 1 label", MergedCellValues.Restart, merged: true),
                    new TableCell(repeatParagraph),
                    Cell("«FP_T1_S1_EACH_Fee»")),
                new TableRow(Cell(string.Empty, merged: true), Cell("Subtotal RIBA Stage 1"), Cell("«FP_T1_S1_SUB_Fee»")),
                new TableRow(Cell("After"), Cell(string.Empty), Cell(string.Empty)));

            mainPart.Document = new Document(new Body(table, new SectionProperties()));
            mainPart.Document.Save();
        }

        return stream.ToArray();
    }

    private static byte[] CreateDocumentWithTable(bool bookmarkInSecondRow)
    {
        using var stream = new MemoryStream();

        using (var document = WordprocessingDocument.Create(
                   stream,
                   WordprocessingDocumentType.Document,
                   autoSave: true))
        {
            var mainPart = document.AddMainDocumentPart();

            var keepRow = new TableRow(
                new TableCell(new Paragraph(new Run(new Text("Keep me")))));

            var gatedRowParagraph = new Paragraph(
                new BookmarkStart { Name = "GatedRow", Id = "1" },
                new Run(new Text("Remove me")),
                new BookmarkEnd { Id = "1" });
            var gatedRow = new TableRow(new TableCell(gatedRowParagraph));

            var table = bookmarkInSecondRow
                ? new Table(keepRow, gatedRow)
                : new Table(gatedRow, keepRow);

            var body = new Body(table, new SectionProperties());
            mainPart.Document = new Document(body);
            mainPart.Document.Save();
        }

        return stream.ToArray();
    }
}
