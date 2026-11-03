#:package DocumentFormat.OpenXml@3.5.1
// Read-only: what placeholders remain in a docx, and where.
using System.Text.RegularExpressions;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;

using var doc = WordprocessingDocument.Open(args[0], false);
var main = doc.MainDocumentPart!;
var body = main.Document.Body!;
var tables = body.Descendants<Table>().ToList();

string Where(OpenXmlElement e)
{
    var t = e.Ancestors<Table>().LastOrDefault();
    return t == null ? "body text" : $"Table {tables.IndexOf(t)} \"{Trim(t.Elements<TableRow>().First().InnerText, 30)}\"";
}
static string Trim(string s, int n) => s.Length > n ? s[..n] + "…" : s;

// Visible text only (ignores tracked deletions).
static string Visible(OpenXmlElement e) => string.Concat(e.Descendants<Text>().Select(t => t.Text));

var mergeFields = body.Descendants<FieldCode>().Where(f => f.Text.Contains("MERGEFIELD"))
    .Select(f => (Name: Regex.Match(f.Text, @"MERGEFIELD\s+""?([^\s""\\]+)").Groups[1].Value, Loc: Where(f))).ToList();
Console.WriteLine($"MERGEFIELD codes still in document: {mergeFields.Count}");
foreach (var g in mergeFields.GroupBy(m => m.Loc)) Console.WriteLine($"  {g.Key}: {string.Join(", ", g.Select(x => x.Name).Distinct())}");

var chevrons = body.Descendants<Text>().Where(t => t.Text.Contains('«'))
    .Select(t => (t.Text, Loc: Where(t))).ToList();
Console.WriteLine($"\nPlain «» text: {chevrons.Count}");
foreach (var g in chevrons.GroupBy(c => c.Loc)) Console.WriteLine($"  {g.Key}: {string.Join(", ", g.Select(x => x.Text).Distinct().Take(8))}");

var sdts = body.Descendants<SdtElement>().Select(s => (Tag: s.SdtProperties?.GetFirstChild<Tag>()?.Val?.Value ?? "(no tag)", Alias: s.SdtProperties?.GetFirstChild<SdtAlias>()?.Val?.Value, Text: Trim(Visible(s), 40))).ToList();
Console.WriteLine($"\nContent controls: {sdts.Count}");
foreach (var s in sdts.Take(25)) Console.WriteLine($"  tag={s.Tag} alias={s.Alias} text=\"{s.Text}\"");

Console.WriteLine("\n£X placeholders by table:");
foreach (var (t, i) in tables.Select((t, i) => (t, i)))
{
    var n = Regex.Matches(Visible(t), @"£X").Count;
    if (n > 0) Console.WriteLine($"  Table {i} \"{Trim(Visible(t.Elements<TableRow>().First()), 40)}\": {n}");
}

foreach (var hp in main.HeaderParts.Cast<OpenXmlPart>().Concat(main.FooterParts))
{
    var codes = hp.RootElement!.Descendants<FieldCode>().Where(f => f.Text.Contains("MERGEFIELD")).Count();
    var chev = hp.RootElement.Descendants<Text>().Count(t => t.Text.Contains('«'));
    if (codes + chev > 0) Console.WriteLine($"{hp.Uri}: {codes} MERGEFIELD, {chev} «»");
}
