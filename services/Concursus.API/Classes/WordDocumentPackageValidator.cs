using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;

namespace Concursus.API.Classes;

internal static class WordDocumentPackageValidator
{
    internal static HeaderFooterContentRequirements CaptureHeaderFooterRequirements(byte[] documentContent)
    {
        ArgumentNullException.ThrowIfNull(documentContent);

        using var stream = new MemoryStream(documentContent, writable: false);
        using var document = WordprocessingDocument.Open(stream, false);

        ValidateHeaderFooterRelationships(document);

        var requirements = new HeaderFooterContentRequirements();
        var mainPart = document.MainDocumentPart
            ?? throw new InvalidDataException("The Word document does not contain a main document part.");

        foreach (var section in mainPart.Document.Descendants<SectionProperties>())
        {
            foreach (var reference in section.Elements<HeaderReference>())
            {
                if (ResolvePart(mainPart, reference.Id?.Value, typeof(HeaderPart)) is HeaderPart headerPart &&
                    HasMeaningfulContent(headerPart.Header))
                {
                    requirements.RequireHeader(reference.Type?.Value ?? HeaderFooterValues.Default);
                }
            }

            foreach (var reference in section.Elements<FooterReference>())
            {
                if (ResolvePart(mainPart, reference.Id?.Value, typeof(FooterPart)) is FooterPart footerPart &&
                    HasMeaningfulContent(footerPart.Footer))
                {
                    requirements.RequireFooter(reference.Type?.Value ?? HeaderFooterValues.Default);
                }
            }
        }

        return requirements;
    }

    internal static void Validate(
        byte[] documentContent,
        HeaderFooterContentRequirements? requirements = null)
    {
        ArgumentNullException.ThrowIfNull(documentContent);

        using var stream = new MemoryStream(documentContent, writable: false);
        using var document = WordprocessingDocument.Open(stream, false);

        ValidateHeaderFooterRelationships(document);

        if (requirements != null)
        {
            ValidateRequiredContent(document, requirements);
        }
    }

    private static void ValidateHeaderFooterRelationships(WordprocessingDocument document)
    {
        var mainPart = document.MainDocumentPart
            ?? throw new InvalidDataException("The Word document does not contain a main document part.");

        foreach (var section in mainPart.Document.Descendants<SectionProperties>())
        {
            foreach (var reference in section.Elements<HeaderReference>())
            {
                var headerPart = ResolvePart(mainPart, reference.Id?.Value, typeof(HeaderPart)) as HeaderPart;

                if (headerPart?.Header == null)
                {
                    throw new InvalidDataException(
                        $"Header relationship '{reference.Id?.Value}' does not contain a valid header part.");
                }
            }

            foreach (var reference in section.Elements<FooterReference>())
            {
                var footerPart = ResolvePart(mainPart, reference.Id?.Value, typeof(FooterPart)) as FooterPart;

                if (footerPart?.Footer == null)
                {
                    throw new InvalidDataException(
                        $"Footer relationship '{reference.Id?.Value}' does not contain a valid footer part.");
                }
            }
        }
    }

    private static void ValidateRequiredContent(
        WordprocessingDocument document,
        HeaderFooterContentRequirements requirements)
    {
        var mainPart = document.MainDocumentPart!;
        var foundHeaders = new HashSet<HeaderFooterValues>();
        var foundFooters = new HashSet<HeaderFooterValues>();

        foreach (var section in mainPart.Document.Descendants<SectionProperties>())
        {
            foreach (var reference in section.Elements<HeaderReference>())
            {
                if (ResolvePart(mainPart, reference.Id?.Value, typeof(HeaderPart)) is HeaderPart headerPart &&
                    HasMeaningfulContent(headerPart.Header))
                {
                    foundHeaders.Add(reference.Type?.Value ?? HeaderFooterValues.Default);
                }
            }

            foreach (var reference in section.Elements<FooterReference>())
            {
                if (ResolvePart(mainPart, reference.Id?.Value, typeof(FooterPart)) is FooterPart footerPart &&
                    HasMeaningfulContent(footerPart.Footer))
                {
                    foundFooters.Add(reference.Type?.Value ?? HeaderFooterValues.Default);
                }
            }
        }

        var missingHeaders = requirements.RequiredHeaders.Except(foundHeaders).ToList();
        var missingFooters = requirements.RequiredFooters.Except(foundFooters).ToList();

        if (missingHeaders.Count == 0 && missingFooters.Count == 0)
        {
            return;
        }

        var missing = new List<string>();
        missing.AddRange(missingHeaders.Select(value => $"{value} header"));
        missing.AddRange(missingFooters.Select(value => $"{value} footer"));

        throw new InvalidDataException(
            "Document generation removed required header/footer content: " + string.Join(", ", missing) + ".");
    }

    private static OpenXmlPart ResolvePart(
        MainDocumentPart mainPart,
        string? relationshipId,
        Type expectedPartType)
    {
        if (string.IsNullOrWhiteSpace(relationshipId))
        {
            throw new InvalidDataException(
                $"A {expectedPartType.Name} reference is missing its relationship id.");
        }

        OpenXmlPart part;

        try
        {
            part = mainPart.GetPartById(relationshipId);
        }
        catch (ArgumentOutOfRangeException ex)
        {
            throw new InvalidDataException(
                $"Relationship '{relationshipId}' does not resolve to a package part.",
                ex);
        }
        catch (KeyNotFoundException ex)
        {
            throw new InvalidDataException(
                $"Relationship '{relationshipId}' does not resolve to a package part.",
                ex);
        }

        if (!expectedPartType.IsInstanceOfType(part))
        {
            throw new InvalidDataException(
                $"Relationship '{relationshipId}' resolves to '{part.GetType().Name}' instead of " +
                $"'{expectedPartType.Name}'.");
        }

        return part;
    }

    private static bool HasMeaningfulContent(OpenXmlPartRootElement? root)
    {
        if (root == null)
        {
            return false;
        }

        return root.Descendants<Text>().Any(text => !string.IsNullOrWhiteSpace(text.Text)) ||
               root.Descendants().Any(element =>
                   element.LocalName.Equals("blip", StringComparison.OrdinalIgnoreCase) ||
                   element.LocalName.Equals("imagedata", StringComparison.OrdinalIgnoreCase) ||
                   element.LocalName.Equals("pict", StringComparison.OrdinalIgnoreCase));
    }
}

internal sealed class HeaderFooterContentRequirements
{
    private readonly HashSet<HeaderFooterValues> _requiredHeaders = [];
    private readonly HashSet<HeaderFooterValues> _requiredFooters = [];

    internal IReadOnlySet<HeaderFooterValues> RequiredHeaders => _requiredHeaders;
    internal IReadOnlySet<HeaderFooterValues> RequiredFooters => _requiredFooters;

    internal void RequireHeader(HeaderFooterValues type) => _requiredHeaders.Add(type);
    internal void RequireFooter(HeaderFooterValues type) => _requiredFooters.Add(type);
}
