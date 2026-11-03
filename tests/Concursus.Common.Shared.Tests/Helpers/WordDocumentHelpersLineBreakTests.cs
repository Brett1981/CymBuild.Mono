using Concursus.Common.Shared.Helpers;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using Xunit;

namespace Concursus.Common.Shared.Tests.Helpers;

/// <summary>
/// Merge values with line breaks (addresses use CR, quote item Details use CRLF) must render as
/// Word line breaks, not as the space Word shows for a line break inside w:t.
/// </summary>
public sealed class WordDocumentHelpersLineBreakTests
{
    [Theory]
    [InlineData("137-145 Church Road\rHarold Wood\rRM3 0SH")]   // SCrm.Addresses.FormattedAddressCR
    [InlineData("137-145 Church Road\r\nHarold Wood\r\nRM3 0SH")]
    [InlineData("137-145 Church Road\nHarold Wood\nRM3 0SH")]
    public void ReplaceAllMergeContent_SplitsMultiLineValuesIntoWordBreaks(string value)
    {
        var run = MergeSingleRun("«Address»", value);

        Assert.Equal(new[] { "137-145 Church Road", "Harold Wood", "RM3 0SH" }, run.Elements<Text>().Select(t => t.Text));
        Assert.Equal(2, run.Elements<Break>().Count());
        Assert.DoesNotContain(run.Elements<Text>(), t => t.Text.Contains('\r') || t.Text.Contains('\n'));
    }

    [Fact]
    public void ReplaceAllMergeContent_KeepsSurroundingTextAroundAMultiLineValue()
    {
        var run = MergeSingleRun("Deliverables: «Details» (see note)", "RS2 - FS Markups\r\n4 x Online meetings");

        Assert.Equal(new[] { "Deliverables: RS2 - FS Markups", "4 x Online meetings (see note)" }, run.Elements<Text>().Select(t => t.Text));
        Assert.Single(run.Elements<Break>());
    }

    [Fact]
    public void ReplaceAllMergeContent_LeavesSingleLineValuesAsOneText()
    {
        var run = MergeSingleRun("«Name»", "Marantz (22)");

        Assert.Equal("Marantz (22)", Assert.Single(run.Elements<Text>()).Text);
        Assert.Empty(run.Elements<Break>());
    }

    [Fact]
    public void ReplaceAllMergeContent_SplitsMultiLineValuesInTaggedContentControls()
    {
        using var stream = new MemoryStream();
        using (var doc = WordprocessingDocument.Create(stream, DocumentFormat.OpenXml.WordprocessingDocumentType.Document))
        {
            var main = doc.AddMainDocumentPart();
            main.Document = new Document(new Body(new Paragraph(
                new SdtRun(
                    new SdtProperties(new Tag { Val = "Address" }),
                    new SdtContentRun(new Run(new Text("Address")))))));

            WordDocumentHelpers.ReplaceAllMergeContent(doc, Fields("Address", "1 Hills Place\rLondon\rW1F 7SA"));

            var texts = main.Document.Body!.Descendants<Text>().Select(t => t.Text).Where(t => t.Length > 0).ToList();
            Assert.Equal(new[] { "1 Hills Place", "London", "W1F 7SA" }, texts);
            Assert.Equal(2, main.Document.Body!.Descendants<Break>().Count());
        }
    }

    private static Run MergeSingleRun(string templateText, string value)
    {
        using var stream = new MemoryStream();
        using var doc = WordprocessingDocument.Create(stream, DocumentFormat.OpenXml.WordprocessingDocumentType.Document);
        var main = doc.AddMainDocumentPart();
        main.Document = new Document(new Body(new Paragraph(new Run(new Text(templateText)))));

        var name = templateText[(templateText.IndexOf('«') + 1)..templateText.IndexOf('»')];
        WordDocumentHelpers.ReplaceAllMergeContent(doc, Fields(name, value));

        return (Run)main.Document.Body!.Descendants<Run>().Single().CloneNode(true);
    }

    private static List<Dictionary<string, string>> Fields(string name, string value) =>
    [
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) { ["Name"] = name, ["Value"] = value }
    ];
}
