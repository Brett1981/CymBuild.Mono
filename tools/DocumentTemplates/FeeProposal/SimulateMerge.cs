#:project ../../../services/Concursus.API/Concursus.API.csproj
// CYB-323: runs the engine's real conditional-row pass over the edited template for one
// sample quote: ConditionalRowMergeEvaluator decides keep/remove/repeat and builds the fields,
// WordDocumentService.RemoveTableRowAtBookmark / RepeatTableRowAtBookmark change the table, and
// WordDocumentHelpers.ReplaceAllMergeContent merges. Internal members are called via reflection.
// The gating rules mirror CYB-323_FireEngineeringFeeProposal_MergeDocumentItems.sql, with
// symbolic product and RIBA stage ids. Writes <outDir>\FeeProposal_simulated.docx.
// Sample quote: QDR; GW1 + D12 at stage 2 (no MKD); a Site Visit at stage 2 (no row of its own);
// two stage 1 items; DFS at stage 3; nothing at stage 4; one stage 5 item; one Construction
// (non-RIBA) item.
using System.Reflection;
using Concursus.API.Classes;
using Concursus.Common.Shared.Helpers;
using Concursus.EF.Types;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;

var dir = args[0];
var bytes = File.ReadAllBytes(Path.Combine(dir, "FeeProposal_CYB-323.docx"));

const int Qdr = 1, Mkd = 2, Gw1 = 3, D12 = 4, Dfs = 5, Sit = 6, Cdm = 7, AnyProduct = -1;
// RIBA stage id per stage number, as in SJob.RibaStages (999 = Construction).
var stageId = new Dictionary<int, int> { [0] = 1, [1] = 2, [2] = 3, [3] = 4, [4] = 5, [5] = 7, [6] = 8, [7] = 9, [999] = 11 };
MergeDocumentItemGatingRule R(int product, int? stage = null) => new() { ProductId = product, RibaStageId = stage is int n ? stageId[n] : -1 };

var items = new List<(string Bookmark, MergeDocumentItemGatingRule[] Rules)>
{
    ("FP_T1_QDR", [R(Qdr)]),
    ("FP_T1_S2_MKD", [R(Mkd, 2)]), ("FP_T1_S2_GW1D12", [R(Gw1, 2), R(D12, 2)]), ("FP_T1_S2_MTG", [R(Mkd, 2), R(Gw1, 2), R(D12, 2)]),
    ("FP_T1_S3_DFS", [R(Dfs, 3), R(Mkd, 3)]), ("FP_T1_S3_MTG", [R(Dfs, 3), R(Mkd, 3)]),
    ("FP_T1_S4_DFS", [R(Dfs, 4), R(Mkd, 4)]), ("FP_T1_S4_MTG", [R(Dfs, 4), R(Mkd, 4)]),
    ("FP_T1_S2_EACH", [R(AnyProduct, 2)]), ("FP_T1_S3_EACH", [R(AnyProduct, 3)]), ("FP_T1_S4_EACH", [R(AnyProduct, 4)]),
};
foreach (var (key, stage) in new[] { ("S0", (int?)0), ("S1", 1), ("S5", 5), ("S6", 6), ("S7", 7), ("OTHER", null) })
    foreach (var part in new[] { "EACH", "SUB", "GAP" })
        items.Add(($"FP_T1_{key}_{part}", [R(AnyProduct, stage)]));
items.AddRange(new (string, MergeDocumentItemGatingRule[])[]
{
    ("FP_T2_QDR_KEEP", [R(Qdr)]), ("FP_T2_S2_MKD_KEEP", [R(Mkd, 2)]), ("FP_T2_S2_D12_KEEP", [R(D12, 2)]), ("FP_T2_S2_GW1_KEEP", [R(Gw1, 2)]),
    ("FP_T2_S3_MKD_KEEP", [R(Mkd, 3)]), ("FP_T2_S3_DFS_KEEP", [R(Dfs, 3)]), ("FP_T2_S4_MKD_KEEP", [R(Mkd, 4)]), ("FP_T2_S4_DFS_KEEP", [R(Dfs, 4)]),
});

int sort = 0;
QuoteItemMergeLine L(int product, int stage, decimal net, string text) =>
    new() { ProductId = product, RibaStageId = stageId[stage], RibaStageNumber = stage, LineNet = net, Deliverable = text, SortOrder = ++sort };
// Optional second argument "3757": QA2 quote 3757's four lines. Every Table 2 row is _KEEP,
// so the rows for unquoted items (QDR, D12, Gateway One, Stage 3/4 markups) stay with a
// blank fee - Jira 810439, AC9.
var lines = args.Length > 1 && args[1] == "3757"
    ? new List<QuoteItemMergeLine>
    {
        L(Sit, 2, 1800m, "Site visit and report"),
        L(Mkd, 2, 4000m, "RS2 - FS Markups"),
        L(Dfs, 3, 5500m, "RS3 - FSS report"),
        L(Dfs, 4, 6000m, "RS4 - FSS report"),
    }
    : new List<QuoteItemMergeLine>
{
    L(Qdr, 2, 1500m, "QDR workshop and report (quote item text)"),
    L(Gw1, 2, 2000m, "RS2 - FS Markups\r\n4 x Online meetings"),
    L(D12, 2, 1250m, "D12 fire statement"),
    L(Sit, 2, 1800m, "Site visit and report"),
    L(Sit, 1, 1800m, "Initial site visit"),
    L(Mkd, 1, 2500m, "FS markups of existing drawings"),
    L(Dfs, 3, 6000m, "RIBA 3 fire safety strategy (quote item text)"),
    L(Cdm, 5, 700m, "Construction stage support"),
    L(Cdm, 999, 2000m, "Construction phase site audit"),
};

var api = typeof(WordDocumentService).Assembly;
var evaluator = api.GetType("Concursus.API.Classes.ConditionalRowMergeEvaluator")!;
T Call<T>(Type type, string name, params object?[] a) => (T)type.GetMethods(BindingFlags.Static | BindingFlags.NonPublic)
    .Single(m => m.Name == name && m.GetParameters().Length == a.Length
                 && (a.Length == 0 || m.GetParameters()[0].ParameterType.IsInstanceOfType(a[0])))
    .Invoke(null, a)!;

var documentRules = items.SelectMany(i => i.Rules).ToList();
var mergeFields = Call<List<Dictionary<string, string>>>(evaluator, "BuildStageSubtotalMergeFields", lines);
foreach (var (bookmark, rules) in items)
{
    var matched = Call<List<QuoteItemMergeLine>>(evaluator, "GetMatchingLines", rules, lines, documentRules);
    if (!Call<bool>(evaluator, "ShouldKeepRow", bookmark, rules, lines, documentRules))
    {
        bytes = Call<byte[]>(typeof(WordDocumentService), "RemoveTableRowAtBookmark", bytes, bookmark);
        Console.WriteLine($"  remove {bookmark}");
    }
    else if (Call<bool>(evaluator, "IsRepeatRow", bookmark))
    {
        bytes = Call<byte[]>(typeof(WordDocumentService), "RepeatTableRowAtBookmark", bytes, bookmark, matched.Count);
        mergeFields.AddRange(Call<List<Dictionary<string, string>>>(evaluator, "BuildRepeatedRowMergeFields", bookmark, matched));
        Console.WriteLine($"  repeat {bookmark} x{matched.Count}");
    }
    else
    {
        mergeFields.AddRange(Call<List<Dictionary<string, string>>>(evaluator, "BuildRowMergeFields", bookmark, matched));
        Console.WriteLine($"  keep   {bookmark} ({matched.Sum(l => l.LineNet):N0})");
    }
}
Console.WriteLine($"Quote total {lines.Sum(l => l.LineNet):N2}");

var fields = mergeFields.ToDictionary(f => f["Name"], f => f["Value"]);
foreach (var (k, v) in new Dictionary<string, string>
{
    ["QuotingConsultantPostNominals"] = "Test Consultant BEng AIFireE", ["QuotingConsultantJobTitle"] = "Fire Engineer",
    ["QuotingConsultantMobile"] = "+44 (0) 7000 000000", ["QuotingConsultantPhone"] = "+44 (0) 1869 366 545",
    ["QuotingConsultantEmail"] = "test.consultant@socotec.co.uk",
    ["ClientContactName"] = "Cherlyn Humphrey", ["ClientFirstName"] = "Obdulia",
    ["ClientAddressBlock"] = "137-145 Church Road, \rHarold Wood\rRM3 0SH", ["PropertyAddress"] = "915 Parsons Street",
    ["ClientName"] = "Sample Client Ltd", ["ProjectName"] = "Sample Project, Bicester", ["QuoteNumber"] = "260123",
    ["RevisionNumber"] = "0", ["FeeProposal_IssueNumber"] = "1", ["FeeProposal_GeneratedDate"] = "01/10/2026",
})
    fields[k] = v;

using var stream = new MemoryStream();
stream.Write(bytes);
using (var doc = WordprocessingDocument.Open(stream, true))
{
    var report = WordDocumentHelpers.ReplaceAllMergeContent(doc, fields.Select(kv => new Dictionary<string, string> { ["name"] = kv.Key, ["value"] = kv.Value }).ToList());
    Console.WriteLine($"Merge: plain={report.PlainTextReplacements} split={report.SplitPlaceholderReplacements} unresolved={report.UnresolvedArtifacts.Count}");
    doc.MainDocumentPart!.Document.Save();

    var tables = doc.MainDocumentPart.Document.Body!.Descendants<Table>().ToList();
    foreach (var ti in new[] { 1, 2 })
    {
        Console.WriteLine($"\n=== T{ti}");
        int r = 0;
        foreach (var row in tables[ti].Elements<TableRow>())
        {
            var cells = row.Elements<TableCell>().Select(c =>
            {
                var vm = c.TableCellProperties?.VerticalMerge;
                var tag = vm == null ? "" : vm.Val?.Value == MergedCellValues.Restart ? "[R]" : "[c]";
                var t = c.InnerText;
                return tag + (t.Length > 45 ? t[..45] + "…" : t);
            });
            Console.WriteLine($"  r{r++}: " + string.Join(" | ", cells));
        }
    }

    var body = doc.MainDocumentPart.Document.Body!.ChildElements.ToList();
    int ys = body.FindIndex(e => e.InnerText.Trim() == "Yours sincerely,");
    Console.WriteLine("\n=== Signature block");
    foreach (var e in body.Skip(ys).Take(9)) Console.WriteLine($"  {e.LocalName}: {e.InnerText}");

    Console.WriteLine("\n=== Cover/letter content controls");
    foreach (var sdt in doc.MainDocumentPart.Document.Body!.Descendants<SdtElement>()) Console.WriteLine($"  {sdt.SdtProperties?.GetFirstChild<SdtAlias>()?.Val?.Value}: {string.Concat(sdt.Descendants<Text>().Select(t => t.Text))}");

    Console.WriteLine("\n=== Letter / cover paragraphs (| = Word line break)");
    foreach (var p in doc.MainDocumentPart.Document.Body!.Descendants<Paragraph>())
    {
        var shown = string.Concat(p.Descendants().Select(e => e is Text t ? t.Text : e is Break ? "|" : ""));
        if (shown.StartsWith("Project address") || shown.StartsWith("Cherlyn") || shown.StartsWith("Dear") || shown.StartsWith("Located at") || shown.StartsWith("RS2"))
            Console.WriteLine($"  {(shown.Length > 110 ? shown[..110] + "…" : shown)}");
    }

    var leftovers = System.Text.RegularExpressions.Regex.Matches(doc.MainDocumentPart.Document.InnerText, "«[^»]+»").Select(m => m.Value).Distinct().ToList();
    Console.WriteLine($"\nUnresolved «» placeholders in body: {(leftovers.Count == 0 ? "none" : string.Join(", ", leftovers))}");
}
File.WriteAllBytes(Path.Combine(dir, "FeeProposal_simulated.docx"), stream.ToArray());
