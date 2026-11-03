#:package DocumentFormat.OpenXml@3.5.1
// CYB-323: scripted edit of the Fire Engineering Fee Proposal template (local copy only).
// Usage: dotnet run EditTemplate.cs -- <extractDir> <outDir>
// Builds <outDir>\FeeProposal_original.docx from the extract, then writes
// <outDir>\FeeProposal_CYB-323.docx with the Table 1/2 bookmarks + merge fields and the
// single dynamic signature block. Every edit asserts the row/paragraph text it expects first.
using System.IO.Compression;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;

var extractDir = args[0];
var outDir = args[1];
Directory.CreateDirectory(outDir);
var original = Path.Combine(outDir, "FeeProposal_original.docx");
var edited = Path.Combine(outDir, "FeeProposal_CYB-323.docx");
File.Delete(original);
ZipFile.CreateFromDirectory(extractDir, original, CompressionLevel.Optimal, includeBaseDirectory: false);
File.Copy(original, edited, overwrite: true);

using (var doc = WordprocessingDocument.Open(edited, true))
{
    var body = doc.MainDocumentPart!.Document.Body!;
    int nextBookmarkId = body.Descendants<BookmarkStart>()
        .Select(b => int.TryParse(b.Id?.Value, out var i) ? i : 0)
        .DefaultIfEmpty(0).Max() + 1;

    var tables = body.Descendants<Table>().ToList();
    var t1 = tables[1];
    var t2 = tables[2];
    Expect(Row(t1, 0).InnerText, "Stage (approximate duration)");
    Expect(Row(t2, 0).InnerText, "Invoice schedule");

    // ---- Table 1: fee breakdown. Bookmark goes in the Deliverables cell (c2): never a
    // vertically merged cell, so the bookmark can't travel with a merge handover.
    ConditionalRow(t1, 2, "FP_T1_QDR", "One workshop with the design team", deliverablesCell: 2, feeCell: 3);
    ConditionalRow(t1, 3, "FP_T1_S2_MKD", "One set of fire safety marked-up drawings", deliverablesCell: 2, feeCell: 3);
    ConditionalRow(t1, 4, "FP_T1_S2_GW1D12", "One Gateway One fire statement", deliverablesCell: 2, feeCell: 3);
    ConditionalRow(t1, 5, "FP_T1_S2_MTG", "Attendance at up to two online meetings", bookmarkCell: 2);
    LastCellField(t1, 6, "Subtotal RIBA Stage 2", "FeeProposal_Stage2Subtotal");
    ConditionalRow(t1, 9, "FP_T1_S3_DFS", "One fire safety strategy report", deliverablesCell: 2, feeCell: 3);
    ConditionalRow(t1, 10, "FP_T1_S3_MTG", "Attendance at up to eight online meetings", bookmarkCell: 2);
    LastCellField(t1, 11, "Subtotal RIBA Stage 3", "FeeProposal_Stage3Subtotal");
    ConditionalRow(t1, 15, "FP_T1_S4_DFS", "One fire safety strategy report", deliverablesCell: 2, feeCell: 3);
    ConditionalRow(t1, 16, "FP_T1_S4_MTG", "Attendance at up to eight online meetings", bookmarkCell: 2);
    LastCellField(t1, 17, "Subtotal RIBA Stage 4", "FeeProposal_Stage4Subtotal");
    LastCellField(t1, 30, "Grand Total for in-scope services", "FeeProposal_TotalNet");

    // ---- Table 1, CYB-323 Q1 option B (Jira 809245/809875): every quote item gets a row.
    // Quote lines that no product row claims are shown in "_EACH" rows, which the engine
    // repeats once per line (gated by catch-all rules, ProductId -1, in the seed script).
    // Stages 2-4 get an _EACH row above their subtotal. Stages 0, 1, 5, 6 and 7 and an "Other
    // fees" section (non-RIBA stages) get a whole section - label + _EACH row, _SUB subtotal row,
    // _GAP spacer - that the engine removes when nothing is quoted there.
    // Rows are captured before any insertion so the indices above still hold.
    var s2Meetings = Row(t1, 5); var s2Subtotal = Row(t1, 6);
    var s3First = Row(t1, 9); var s3Meetings = Row(t1, 10); var s3Subtotal = Row(t1, 11);
    var s4Meetings = Row(t1, 16); var s4Subtotal = Row(t1, 17);
    var spacer = Row(t1, 8); var stage2First = Row(t1, 3); var recommended = Row(t1, 21);
    if (spacer.Elements<TableCell>().Count() != 1 || spacer.InnerText.Trim().Length != 0)
        throw new InvalidOperationException("T1 r8: expected the empty one-cell spacer row.");
    Expect(recommended.InnerText, "Recommended Additional Services");

    StageEachRow(s2Meetings, s2Subtotal, "FP_T1_S2_EACH");
    StageEachRow(s3Meetings, s3Subtotal, "FP_T1_S3_EACH");
    StageEachRow(s4Meetings, s4Subtotal, "FP_T1_S4_EACH");

    foreach (var (key, label, subtotal) in new[]
             {
                 ("S0", new[] { "Strategic Definition", "RIBA Stage 0" }, "Subtotal RIBA Stage 0"),
                 ("S1", new[] { "Preparation and Briefing", "RIBA Stage 1" }, "Subtotal RIBA Stage 1"),
             })
        Section(stage2First, key, label, subtotal);
    foreach (var (key, label, subtotal) in new[]
             {
                 ("S5", new[] { "Manufacturing and Construction", "RIBA Stage 5" }, "Subtotal RIBA Stage 5"),
                 ("S6", new[] { "Handover", "RIBA Stage 6" }, "Subtotal RIBA Stage 6"),
                 ("S7", new[] { "Use", "RIBA Stage 7" }, "Subtotal RIBA Stage 7"),
                 ("OTHER", new[] { "Other fees" }, "Subtotal other fees"),
             })
        Section(recommended, key, label, subtotal);

    // Stage 2-4: an _EACH row cloned from the meetings row (stage label continues through it),
    // placed above the subtotal. The fee cell is its own, not part of the strategy fee merge.
    void StageEachRow(TableRow meetings, TableRow subtotal, string bookmark)
    {
        var row = CleanClone(meetings);
        var cells = row.Elements<TableCell>().ToList();
        SetCellText(cells[1], "I");
        SetCellText(cells[2], $"«{bookmark}_Deliverables»");
        SetCellText(cells[3], $"«{bookmark}_Fee»");
        cells[3].TableCellProperties?.VerticalMerge?.Remove();
        AddBookmark(cells[2], bookmark);
        subtotal.InsertBeforeSelf(row);
        Console.WriteLine($"T1: {bookmark} above \"{subtotal.InnerText.Trim()}\"");
    }

    // A whole section inserted before `before`: the label + _EACH row (from the Stage 3 first
    // row, so the label starts a vertical merge), the _SUB subtotal row (from the Stage 3
    // subtotal row) and the _GAP spacer.
    void Section(TableRow before, string key, string[] labelLines, string subtotalText)
    {
        string each = $"FP_T1_{key}_EACH", sub = $"FP_T1_{key}_SUB", gap = $"FP_T1_{key}_GAP";

        var first = CleanClone(s3First);
        var cells = first.Elements<TableCell>().ToList();
        SetCellLines(cells[0], labelLines);
        SetCellText(cells[1], "I");
        SetCellText(cells[2], $"«{each}_Deliverables»");
        SetCellText(cells[3], $"«{each}_Fee»");
        cells[3].TableCellProperties?.VerticalMerge?.Remove();
        AddBookmark(cells[2], each);

        var subtotalRow = CleanClone(s3Subtotal);
        var subCells = subtotalRow.Elements<TableCell>().ToList();
        SetCellText(subCells[2], subtotalText);
        SetCellText(subCells[3], $"«{sub}_Fee»");
        AddBookmark(subCells[2], sub);

        var gapRow = CleanClone(spacer);
        AddBookmark(gapRow.Elements<TableCell>().First(), gap);

        before.InsertBeforeSelf(first);
        before.InsertBeforeSelf(subtotalRow);
        before.InsertBeforeSelf(gapRow);
        Console.WriteLine($"T1: section {key} ({string.Join(" / ", labelLines)}) before \"{before.InnerText.Trim()[..Math.Min(30, before.InnerText.Trim().Length)]}\"");
    }

    // A copy of a template row with no bookmarks, comments or revision history of its own: the
    // template's unaccepted tracked changes would otherwise be duplicated, ids and all, into
    // rows that are new anyway. Current formatting is kept; tracked insertions are accepted.
    static TableRow CleanClone(TableRow source)
    {
        var row = (TableRow)source.CloneNode(true);
        foreach (var e in row.Descendants().Where(e => e is BookmarkStart or BookmarkEnd
                     or CommentRangeStart or CommentRangeEnd or CommentReference or DeletedRun
                     or TableRowPropertiesChange or TableCellPropertiesChange or ParagraphPropertiesChange
                     or RunPropertiesChange or ParagraphMarkRunPropertiesChange or Inserted or Deleted).ToList())
            e.Remove();
        foreach (var ins in row.Descendants<InsertedRun>().ToList())
        {
            foreach (var child in ins.ChildElements.ToList()) ins.InsertBeforeSelf(child.CloneNode(true));
            ins.Remove();
        }
        return row;
    }

    void AddBookmark(TableCell cell, string bookmark)
    {
        if (cell.TableCellProperties?.VerticalMerge != null)
            throw new InvalidOperationException($"{bookmark}: bookmark cell is vertically merged.");
        var p = cell.Elements<Paragraph>().First();
        var id = (nextBookmarkId++).ToString();
        var firstContent = p.ChildElements.FirstOrDefault(e => e is not ParagraphProperties);
        var start = new BookmarkStart { Name = bookmark, Id = id };
        if (firstContent != null) firstContent.InsertBeforeSelf(start); else p.AppendChild(start);
        p.AppendChild(new BookmarkEnd { Id = id });
    }

    // ---- Table 2: invoicing schedule. Bookmark in the Invoice schedule cell (c1), fee in c2.
    // Deliverable labels stay static (they're schedule labels, not quote item text).
    // Every row is _KEEP: always shown, fee filled only when that item is quoted, so users
    // delete the rows they don't need (Jira 810439, AC9).
    // CYB-323 Q3 (Jira 809245): the D12 row carries the whole sentence, so it still reads
    // correctly when the drawings row is removed. Set before the bookmark goes into this cell.
    // The drawings row (r4) keeps its text until the BA confirms its wording (Jira 809875 Q4).
    ScheduleText(t2, 5, "(minus mobilisation fee)",
        "Upon delivery of initial issue of D12 Fire Statement (minus mobilisation fee)");
    ConditionalRow(t2, 3, "FP_T2_QDR_KEEP", "Stage 2 QDR report", feeCell: 2, bookmarkCell: 1);
    ConditionalRow(t2, 4, "FP_T2_S2_MKD_KEEP", "Stage 2 marked-up drawings", feeCell: 2, bookmarkCell: 1);
    ConditionalRow(t2, 5, "FP_T2_S2_D12_KEEP", "D12 statement", feeCell: 2, bookmarkCell: 1);
    ConditionalRow(t2, 6, "FP_T2_S2_GW1_KEEP", "Gateway One statement", feeCell: 2, bookmarkCell: 1);
    ConditionalRow(t2, 8, "FP_T2_S3_MKD_KEEP", "Stage 3 Fire Safety Markups", feeCell: 2, bookmarkCell: 1);
    ConditionalRow(t2, 9, "FP_T2_S3_DFS_KEEP", "Stage 3 Fire Safety Strategy", feeCell: 2, bookmarkCell: 1);
    ConditionalRow(t2, 11, "FP_T2_S4_MKD_KEEP", "Stage 4 Fire Safety Markups", feeCell: 2, bookmarkCell: 1);
    ConditionalRow(t2, 12, "FP_T2_S4_DFS_KEEP", "Stage 4 Fire Safety Strategy", feeCell: 2, bookmarkCell: 1);

    // ---- Signature: replace the static roster with one dynamic block.
    var blocks = body.ChildElements.ToList();
    int ys = blocks.FindIndex(e => e is Paragraph && e.InnerText.Trim() == "Yours sincerely,");
    int last = blocks.FindIndex(e => e is Paragraph && e.InnerText.Contains("zara.vermeulen@socotec.co.uk"));
    if (ys < 0 || last <= ys) throw new InvalidOperationException("Signature roster bounds not found.");
    var roster = blocks.GetRange(ys + 1, last - ys);
    Expect(roster[1].InnerText, "Stephen Kavanagh");
    Expect(roster[4].InnerText, "stephen.kavanagh@socotec.co.uk");

    // Guard: nothing in the roster may own a bookmark/comment that continues outside it.
    var rosterSet = roster.SelectMany(e => e.Descendants().Prepend(e)).ToHashSet();
    var outsideBookmarkEnds = body.Descendants<BookmarkEnd>().Where(b => !rosterSet.Contains(b)).Select(b => b.Id?.Value).ToHashSet();
    foreach (var b in roster.SelectMany(e => e.Descendants<BookmarkStart>()))
        if (outsideBookmarkEnds.Contains(b.Id?.Value)) throw new InvalidOperationException($"Bookmark {b.Name} spans the roster boundary.");
    // Comments wholly inside the roster (the obsolete "Put your signature" thread) go with it;
    // one that crosses the boundary stops the run.
    static IEnumerable<string> CommentIds(IEnumerable<OpenXmlElement> els) => els.SelectMany(e =>
        e.Descendants<CommentRangeStart>().Select(c => c.Id!.Value!)
         .Concat(e.Descendants<CommentRangeEnd>().Select(c => c.Id!.Value!))
         .Concat(e.Descendants<CommentReference>().Select(c => c.Id!.Value!)));
    var rosterCommentIds = CommentIds(roster).ToHashSet();
    var outsideCommentIds = CommentIds(blocks.Where(b => !roster.Contains(b))).ToHashSet();
    if (rosterCommentIds.Overlaps(outsideCommentIds))
        throw new InvalidOperationException("A comment spans the roster boundary.");
    RemoveComments(doc.MainDocumentPart!, rosterCommentIds);

    var nameTemplate = (Paragraph)roster[1];
    var titleTemplate = (Paragraph)roster[2];
    var phoneTemplate = (Paragraph)roster[3];
    var emailTemplate = (Paragraph)roster[4];

    var signaturePara = (Paragraph)nameTemplate.CloneNode(true);
    // Empty on purpose: when the consultant has no signature image the engine skips the
    // control and leaves its content as-is, so any text here would print.
    SetParagraphText(signaturePara, string.Empty);
    var signatureControl = new SdtBlock(
        new SdtProperties(
            new SdtAlias { Val = "Consultant signature" },
            new Tag { Val = "ConsultantSignature" },
            new SdtId { Val = new Random(323).Next(1, int.MaxValue) }),
        new SdtContentBlock(signaturePara));

    var newBlock = new OpenXmlElement[]
    {
        signatureControl,
        Field(nameTemplate, "QuotingConsultantPostNominals"),
        Field(titleTemplate, "QuotingConsultantJobTitle"),
        Field(phoneTemplate, "QuotingConsultantMobile"),
        Field(phoneTemplate, "QuotingConsultantPhone"),
        Field(emailTemplate, "QuotingConsultantEmail"),
    };

    var anchor = blocks[ys];
    foreach (var e in roster) e.Remove();
    foreach (var e in newBlock.Reverse()) anchor.InsertAfterSelf(e);

    // Images only the roster used become unreferenced parts; drop them.
    var mainPart = doc.MainDocumentPart;
    var usedIds = mainPart.Document.Descendants<DocumentFormat.OpenXml.Drawing.Blip>()
        .Select(b => b.Embed?.Value).Where(v => v != null).ToHashSet();
    var removed = 0;
    foreach (var ip in mainPart.ImageParts.ToList())
    {
        var id = mainPart.GetIdOfPart(ip);
        if (!usedIds.Contains(id) && !mainPart.Document.OuterXml.Contains($"\"{id}\""))
        {
            mainPart.DeletePart(ip);
            removed++;
        }
    }
    Console.WriteLine($"Signature roster: removed {roster.Count} elements and {removed} now-unused images; inserted ConsultantSignature block.");

    // ---- Cover page / letter: Word document-property controls -> CymBuild merge fields.
    // They are data-bound to the file's own properties (Company, Subject...), which no merge
    // field matches, and Word would re-sync the bound text on open. Unbind and retag them; the
    // engine replaces a content control's text when its Tag matches a merge field name.
    var propertyMap = new Dictionary<string, string>
    {
        ["Company"] = "ClientName",
        ["Subject"] = "ProjectName",
        ["Title"] = "QuoteNumber",
        ["Publish Date"] = "FeeProposal_GeneratedDate",
    };
    var converted = new Dictionary<string, int>();
    foreach (var sdt in body.Descendants<SdtElement>().ToList())
    {
        var props = sdt.SdtProperties;
        var alias = props?.GetFirstChild<SdtAlias>()?.Val?.Value;
        if (props == null || alias == null || (!propertyMap.ContainsKey(alias) && alias != "Status")) continue;

        // Plain rich-text control: no binding, no placeholder doc part, no date picker.
        foreach (var e in props.ChildElements.Where(e =>
                     e is DataBinding or ShowingPlaceholder or SdtPlaceholder or SdtContentDate or Tag or SdtContentText).ToList())
            e.Remove();

        if (alias == "Status")
        {
            props.GetFirstChild<SdtAlias>()!.Val = "Issue number";
            var texts = sdt.Descendants<Text>().ToList();
            texts[0].Text = "Issue «FeeProposal_IssueNumber»";
            texts[0].Space = SpaceProcessingModeValues.Preserve;
            foreach (var t in texts.Skip(1)) t.Remove();
        }
        else
        {
            props.GetFirstChild<SdtAlias>()!.Val = propertyMap[alias];
            props.AppendChild(new Tag { Val = propertyMap[alias] });
        }
        converted[alias] = converted.GetValueOrDefault(alias) + 1;
    }
    Console.WriteLine("Property controls converted: " + string.Join(", ", converted.Select(kv => $"{kv.Key}={kv.Value}")));
    if (converted.Values.Sum() != 14) throw new InvalidOperationException("Expected 14 document-property controls.");

    // ---- Static placeholder text -> merge fields (letter, cover, project description).
    Paragraph Para(string startsWith) =>
        body.Descendants<Paragraph>().Single(p => string.Concat(p.Descendants<Text>().Select(t => t.Text)).StartsWith(startsWith, StringComparison.Ordinal));
    static Text RunText(Paragraph p, string exact) =>
        p.Elements<Run>().SelectMany(r => r.Elements<Text>()).Single(t => t.Text == exact);

    // Cover: "Project address: Address" (inside the 'address' bookmark).
    RunText(Para("Project address:"), "Address").Text = "«PropertyAddress»";

    // Letter recipient block: Name Surname / Company Name (ClientName control) / Address x3 / POST CODE.
    // The quote's client is used: the Recipient* fields are blank unless the quote is marked
    // send-to-client or has an agent, which almost no quote is.
    var recipient = Para("Name Surname");
    var nameRuns = recipient.Elements<Run>().TakeWhile(r => !r.Elements<Break>().Any()).ToList();
    nameRuns[0].GetFirstChild<Text>()!.Text = "«ClientContactName»";
    foreach (var r in nameRuns.Skip(1)) r.Remove();
    var addressRun = recipient.Elements<Run>().First(r => r.Elements<Break>().Any() && r.Elements<Text>().Any(t => t.Text == "Address"));
    addressRun.GetFirstChild<Text>()!.Text = "«ClientAddressBlock»";
    foreach (var e in addressRun.ElementsAfter().ToList()) e.Remove();   // Address 2, Address 3, POST CODE

    // Salutation.
    RunText(Para("Dear Name"), "Name").Text = "«ClientFirstName»";

    // Project description: "Located at xxxxx, the project consists of..." (rest stays manual).
    RunText(Para("Located at xxxxx"), "xxxxx").Text = "«PropertyAddress»";
    Console.WriteLine("Static placeholders converted: project address x2, recipient block, salutation.");

    mainPart.Document.Save();

    // ---------------------------------------------------------------------------------
    void ConditionalRow(Table table, int rowIndex, string bookmark, string expectedText,
        int? deliverablesCell = null, int? feeCell = null, int bookmarkCell = -1)
    {
        var row = Row(table, rowIndex);
        Expect(row.InnerText, expectedText);
        var cells = row.Elements<TableCell>().ToList();
        if (deliverablesCell is int d) SetCellText(cells[d], $"«{bookmark}_Deliverables»");
        if (feeCell is int f) SetCellText(cells[f], $"«{bookmark}_Fee»");

        var target = cells[bookmarkCell >= 0 ? bookmarkCell : deliverablesCell!.Value];
        if (target.TableCellProperties?.VerticalMerge != null)
            throw new InvalidOperationException($"{bookmark}: bookmark cell is vertically merged.");
        var p = target.Elements<Paragraph>().First();
        var id = (nextBookmarkId++).ToString();
        var firstContent = p.ChildElements.FirstOrDefault(e => e is not ParagraphProperties);
        var start = new BookmarkStart { Name = bookmark, Id = id };
        if (firstContent != null) firstContent.InsertBeforeSelf(start); else p.AppendChild(start);
        p.AppendChild(new BookmarkEnd { Id = id });
        Console.WriteLine($"T{tables.IndexOf(table)} r{rowIndex}: {bookmark}{(deliverablesCell != null ? " +Deliverables" : "")}{(feeCell != null ? " +Fee" : "")}");
    }

    void ScheduleText(Table table, int rowIndex, string expectedText, string newText)
    {
        var cell = Row(table, rowIndex).Elements<TableCell>().ElementAt(1);
        if (cell.InnerText.Trim() != expectedText)
            throw new InvalidOperationException($"T{tables.IndexOf(table)} r{rowIndex}: expected schedule text '{expectedText}', found '{cell.InnerText}'.");
        SetCellText(cell, newText);
        Console.WriteLine($"T{tables.IndexOf(table)} r{rowIndex}: schedule text -> \"{newText}\"");
    }

    void LastCellField(Table table, int rowIndex, string expectedText, string field)
    {
        var row = Row(table, rowIndex);
        Expect(row.InnerText, expectedText);
        SetCellText(row.Elements<TableCell>().Last(), $"«{field}»");
        Console.WriteLine($"T{tables.IndexOf(table)} r{rowIndex}: «{field}»");
    }
}

using (var check = WordprocessingDocument.Open(edited, false))
{
    var errors = new DocumentFormat.OpenXml.Validation.OpenXmlValidator(FileFormatVersions.Microsoft365)
        .Validate(check).ToList();
    using var orig = WordprocessingDocument.Open(original, false);
    var origErrors = new DocumentFormat.OpenXml.Validation.OpenXmlValidator(FileFormatVersions.Microsoft365)
        .Validate(orig).Count();
    Console.WriteLine($"Schema validation: original {origErrors} errors, edited {errors.Count} errors.");
    foreach (var e in errors.Take(10)) Console.WriteLine($"  {e.Path?.XPath}: {e.Description}");
}
Console.WriteLine($"Wrote {edited}");

// ---- Review copy: yellow = filled in by CymBuild, green row = shown only when its product
// (at that RIBA stage) is on the quote. For review only - never upload this one.
var review = Path.Combine(outDir, "FeeProposal_CYB-323_REVIEW.docx");
File.Copy(edited, review, overwrite: true);
using (var doc = WordprocessingDocument.Open(review, true))
{
    var body = doc.MainDocumentPart!.Document.Body!;

    static void Highlight(Run run)
    {
        var rp = run.RunProperties ??= new RunProperties();
        rp.Highlight = new Highlight { Val = HighlightColorValues.Yellow };
    }

    var autoTags = new HashSet<string> { "ClientName", "ProjectName", "QuoteNumber", "FeeProposal_GeneratedDate", "ConsultantSignature" };
    foreach (var sdt in body.Descendants<SdtElement>())
    {
        var tag = sdt.SdtProperties?.GetFirstChild<Tag>()?.Val?.Value;
        var alias = sdt.SdtProperties?.GetFirstChild<SdtAlias>()?.Val?.Value;
        if (tag == "ConsultantSignature")
            sdt.Descendants<Text>().First().Text = "[Consultant signature image]";
        if ((tag != null && autoTags.Contains(tag)) || alias == "Issue number")
            foreach (var r in sdt.Descendants<Run>()) Highlight(r);
    }
    foreach (var r in body.Descendants<Run>().Where(r => r.InnerText.Contains('«'))) Highlight(r);

    int gatedRows = 0;
    foreach (var row in body.Descendants<BookmarkStart>().Where(b => b.Name?.Value?.StartsWith("FP_") == true)
                 .Select(b => b.Ancestors<TableRow>().First()).Distinct())
    {
        foreach (var cell in row.Elements<TableCell>())
        {
            var tcPr = cell.TableCellProperties ??= new TableCellProperties();
            tcPr.Shading = new Shading { Val = ShadingPatternValues.Clear, Color = "auto", Fill = "C6EFCE" };
        }
        gatedRows++;
    }

    Paragraph Legend(string text, bool bold = false, string? highlight = null, string? fill = null)
    {
        var rp = new RunProperties();
        if (bold) rp.Bold = new Bold();
        if (highlight == "yellow") rp.Highlight = new Highlight { Val = HighlightColorValues.Yellow };
        if (fill != null) rp.Shading = new Shading { Val = ShadingPatternValues.Clear, Color = "auto", Fill = fill };
        return new Paragraph(new Run(rp, new Text(text) { Space = SpaceProcessingModeValues.Preserve }));
    }
    var first = body.ChildElements.First();
    foreach (var p in new[]
             {
                 Legend("CYB-323 REVIEW COPY - do not upload. Remove this note and the colours are the only differences from FeeProposal_CYB-323.docx.", bold: true),
                 Legend("Yellow = filled in automatically by CymBuild when the proposal is generated (client, project, proposal number, issue, date, fees, deliverables, subtotals, consultant details and signature).", highlight: "yellow"),
                 Legend("Green row = only appears if that product (at that RIBA stage) is on the quote; otherwise CymBuild removes the row.", fill: "C6EFCE"),
                 Legend("Everything else (including all £X,XXX amounts, optional rows, mobilisation fees and Tables 3-14) is unchanged template text that the consultant edits by hand."),
             }.Reverse())
        first.InsertBeforeSelf(p);

    doc.MainDocumentPart.Document.Save();
    Console.WriteLine($"Wrote {review} ({gatedRows} green rows).");
}

static TableRow Row(Table t, int i) => t.Elements<TableRow>().ElementAt(i);

// Removes comments from comments.xml and their linked commentsExtended / commentsIds /
// commentsExtensible entries (linked by the comment paragraphs' w14:paraId, then durableId).
static void RemoveComments(MainDocumentPart main, HashSet<string> ids)
{
    if (ids.Count == 0) return;
    var comments = main.WordprocessingCommentsPart!.Comments;
    var doomed = comments.Elements<Comment>().Where(c => ids.Contains(c.Id!.Value!)).ToList();
    var paraIds = doomed.SelectMany(c => c.Descendants<Paragraph>())
        .Select(p => p.ParagraphId?.Value).Where(v => v != null).ToHashSet();
    foreach (var c in doomed) c.Remove();
    comments.Save();

    var durableIds = new HashSet<string?>();
    if (main.WordprocessingCommentsIdsPart?.CommentsIds is { } cids)
    {
        foreach (var c in cids.Elements<DocumentFormat.OpenXml.Office2019.Word.Cid.CommentId>().Where(c => paraIds.Contains(c.ParaId?.Value)).ToList())
        {
            durableIds.Add(c.DurableId?.Value);
            c.Remove();
        }
        cids.Save();
    }
    if (main.WordprocessingCommentsExPart?.CommentsEx is { } cex)
    {
        foreach (var c in cex.Elements<DocumentFormat.OpenXml.Office2013.Word.CommentEx>().Where(c => paraIds.Contains(c.ParaId?.Value)).ToList()) c.Remove();
        cex.Save();
    }
    if (main.WordCommentsExtensiblePart?.RootElement is { } cext)
    {
        foreach (var c in cext.ChildElements
                     .Where(c => c.LocalName == "commentExtensible" &&
                                 durableIds.Contains(c.GetAttributes().FirstOrDefault(a => a.LocalName == "durableId").Value))
                     .ToList())
            c.Remove();
        main.WordCommentsExtensiblePart.RootElement.Save();
    }
    Console.WriteLine($"Removed {doomed.Count} roster comments ({string.Join(", ", ids)}).");
}

static void Expect(string actual, string contains)
{
    if (!actual.Contains(contains, StringComparison.Ordinal))
        throw new InvalidOperationException($"Expected text '{contains}' not found in '{actual[..Math.Min(120, actual.Length)]}'.");
}

static Paragraph Field(Paragraph template, string field)
{
    var p = (Paragraph)template.CloneNode(true);
    SetParagraphText(p, $"«{field}»");
    return p;
}

// Keeps the paragraph's properties and its first run's formatting; replaces everything else
// with one run, so the «Field» placeholder sits in a single w:t the merge pass can match.
static void SetParagraphText(Paragraph p, string text)
{
    var runProps = p.Descendants<Run>().FirstOrDefault()?.RunProperties?.CloneNode(true);
    foreach (var e in p.ChildElements.Where(e => e is not ParagraphProperties).ToList()) e.Remove();
    var run = new Run();
    if (runProps != null) run.AppendChild(runProps);
    run.AppendChild(new Text(text) { Space = SpaceProcessingModeValues.Preserve });
    p.AppendChild(run);
}

static void SetCellText(TableCell cell, string text)
{
    var paragraphs = cell.Elements<Paragraph>().ToList();
    foreach (var extra in paragraphs.Skip(1)) extra.Remove();
    SetParagraphText(paragraphs[0], text);
}

// One paragraph per line, each formatted like the cell's first paragraph.
static void SetCellLines(TableCell cell, string[] lines)
{
    SetCellText(cell, lines[0]);
    var first = cell.Elements<Paragraph>().First();
    var previous = first;
    foreach (var line in lines.Skip(1))
    {
        var p = (Paragraph)first.CloneNode(true);
        SetParagraphText(p, line);
        previous.InsertAfterSelf(p);
        previous = p;
    }
}
