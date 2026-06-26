using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using System.Text;

namespace Concursus.API.Services.AIAssistant;

public interface IKnowledgeTextExtractor
{
    Task<string> ExtractTextAsync(string fileName, Stream content, CancellationToken cancellationToken);
}

public sealed class KnowledgeTextExtractor : IKnowledgeTextExtractor
{
    public async Task<string> ExtractTextAsync(string fileName, Stream content, CancellationToken cancellationToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(fileName);
        ArgumentNullException.ThrowIfNull(content);

        var extension = Path.GetExtension(fileName).ToLowerInvariant();

        if (extension is ".txt" or ".md")
        {
            using var reader = new StreamReader(content, Encoding.UTF8, detectEncodingFromByteOrderMarks: true, leaveOpen: false);
            return await reader.ReadToEndAsync(cancellationToken);
        }

        if (extension == ".docx")
        {
            return ExtractDocxText(content);
        }

        throw new NotSupportedException($"File type '{extension}' is not supported by the phase 1 extractor.");
    }

    private static string ExtractDocxText(Stream content)
    {
        using var document = WordprocessingDocument.Open(content, false);
        var body = document.MainDocumentPart?.Document?.Body;
        if (body is null)
        {
            return string.Empty;
        }

        var builder = new StringBuilder();
        foreach (var paragraph in body.Descendants<Paragraph>())
        {
            var text = string.Concat(paragraph.Descendants<Text>().Select(t => t.Text)).Trim();
            if (!string.IsNullOrWhiteSpace(text))
            {
                builder.AppendLine(text);
                builder.AppendLine();
            }
        }

        foreach (var table in body.Descendants<Table>())
        {
            foreach (var row in table.Descendants<TableRow>())
            {
                var cells = row.Descendants<TableCell>()
                    .Select(cell => string.Join(" ", cell.Descendants<Text>().Select(t => t.Text)).Trim())
                    .Where(value => !string.IsNullOrWhiteSpace(value));

                var line = string.Join(" | ", cells);
                if (!string.IsNullOrWhiteSpace(line))
                {
                    builder.AppendLine(line);
                }
            }
        }

        return builder.ToString().Trim();
    }
}
