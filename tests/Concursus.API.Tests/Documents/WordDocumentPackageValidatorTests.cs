using Concursus.API.Classes;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using Xunit;
using OpenXmlPowerTools = Codeuctivity.OpenXmlPowerTools;
using OpenXmlDocumentBuilder = Codeuctivity.OpenXmlPowerTools.DocumentBuilder.DocumentBuilder;
using OpenXmlDocumentSource = Codeuctivity.OpenXmlPowerTools.DocumentBuilder.Source;

namespace Concursus.API.Tests.Documents;

public sealed class WordDocumentPackageValidatorTests
{
    [Fact]
    public void Validate_AcceptsValidFirstAndDefaultHeaders()
    {
        var document = CreateDocument(
            includeFirstHeader: true,
            firstHeaderText: "Fee proposal cover",
            includeDefaultHeader: true,
            defaultHeaderText: "Quote reference");

        var requirements = WordDocumentPackageValidator.CaptureHeaderFooterRequirements(document);

        WordDocumentPackageValidator.Validate(document, requirements);
    }

    [Fact]
    public void Validate_RejectsMissingHeaderRelationship()
    {
        var document = CreateDocument(
            includeFirstHeader: true,
            firstHeaderText: "Fee proposal cover",
            includeDefaultHeader: false,
            defaultHeaderText: string.Empty,
            useMissingFirstHeaderRelationship: true);

        var exception = Assert.Throws<InvalidDataException>(
            () => WordDocumentPackageValidator.Validate(document));

        Assert.True(
            exception.Message.Contains("does not resolve", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void Validate_RejectsLossOfRequiredFirstPageCoverContent()
    {
        var sourceDocument = CreateDocument(
            includeFirstHeader: true,
            firstHeaderText: "Fee proposal cover",
            includeDefaultHeader: true,
            defaultHeaderText: "Quote reference");

        var generatedDocument = CreateDocument(
            includeFirstHeader: false,
            firstHeaderText: string.Empty,
            includeDefaultHeader: true,
            defaultHeaderText: "Quote reference");

        var requirements = WordDocumentPackageValidator.CaptureHeaderFooterRequirements(sourceDocument);

        Assert.Throws<InvalidDataException>(
            () => WordDocumentPackageValidator.Validate(generatedDocument, requirements));
    }

    [Fact]
    public void DocumentBuilder_WithBodyOnlyInclude_PreservesParentCoverHeaders()
    {
        var parentBytes = CreateDocument(
            includeFirstHeader: true,
            firstHeaderText: "Fee proposal cover",
            includeDefaultHeader: true,
            defaultHeaderText: "Quote reference");

        var includedBytes = CreateDocument(
            includeFirstHeader: true,
            firstHeaderText: "Included document header",
            includeDefaultHeader: false,
            defaultHeaderText: string.Empty);

        var requirements = WordDocumentPackageValidator.CaptureHeaderFooterRequirements(parentBytes);
        var parent = new OpenXmlPowerTools.WmlDocument("Parent.docx", parentBytes);
        var included = new OpenXmlPowerTools.WmlDocument("Included.docx", includedBytes);

        var merged = OpenXmlDocumentBuilder.BuildDocument(
        [
            new OpenXmlDocumentSource(parent, 0, 1, true),
            new OpenXmlDocumentSource(included, false),
            new OpenXmlDocumentSource(parent, 2, true)
        ]);

        WordDocumentPackageValidator.Validate(merged.DocumentByteArray, requirements);

        using var stream = new MemoryStream(merged.DocumentByteArray, writable: false);
        using var mergedDocument = WordprocessingDocument.Open(stream, false);
        var mainPart = mergedDocument.MainDocumentPart!;
        var mergedHeaderText = string.Join(
            " ",
            mainPart.Document.Descendants<HeaderReference>()
                .Select(reference => mainPart.GetPartById(reference.Id!.Value!) as HeaderPart)
                .Where(part => part != null)
                .SelectMany(part => part!.Header.Descendants<Text>())
                .Select(text => text.Text));

        Assert.True(mergedHeaderText.Contains("Fee proposal cover", StringComparison.Ordinal));
        Assert.False(mergedHeaderText.Contains("Included document header", StringComparison.Ordinal));
    }

    private static byte[] CreateDocument(
        bool includeFirstHeader,
        string firstHeaderText,
        bool includeDefaultHeader,
        string defaultHeaderText,
        bool useMissingFirstHeaderRelationship = false)
    {
        using var stream = new MemoryStream();

        using (var document = WordprocessingDocument.Create(
                   stream,
                   WordprocessingDocumentType.Document,
                   autoSave: true))
        {
            var mainPart = document.AddMainDocumentPart();
            var section = new SectionProperties();
            var body = new Body(
                new Paragraph(new Run(new Text("Document start"))),
                new Paragraph(new Run(new Text("Include bookmark"))),
                new Paragraph(new Run(new Text("Document end"))),
                section);

            mainPart.Document = new Document(body);

            if (includeFirstHeader)
            {
                var firstHeaderPart = mainPart.AddNewPart<HeaderPart>();
                firstHeaderPart.Header = new Header(
                    new Paragraph(new Run(new Text(firstHeaderText))));

                section.Append(new HeaderReference
                {
                    Type = HeaderFooterValues.First,
                    Id = useMissingFirstHeaderRelationship
                        ? "rIdMissingHeader"
                        : mainPart.GetIdOfPart(firstHeaderPart)
                });
            }

            if (includeDefaultHeader)
            {
                var defaultHeaderPart = mainPart.AddNewPart<HeaderPart>();
                defaultHeaderPart.Header = new Header(
                    new Paragraph(new Run(new Text(defaultHeaderText))));

                section.Append(new HeaderReference
                {
                    Type = HeaderFooterValues.Default,
                    Id = mainPart.GetIdOfPart(defaultHeaderPart)
                });
            }

            mainPart.Document.Save();
        }

        return stream.ToArray();
    }
}
