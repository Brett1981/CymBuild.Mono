using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using iText.Kernel.Pdf;

namespace Concursus.Common.Shared.Helpers
{
    public static class ConvertDocxToPdf
    {
        public static byte[] ConvertToPdf(byte[] docxBytes)
        {
            using var inputMemoryStream = new MemoryStream(docxBytes);
            using var wordDocument = WordprocessingDocument.Open(inputMemoryStream, false);
            using var outputMemoryStream = new MemoryStream();

            // Use iText or other libraries to convert DOCX to PDF
            var pdfWriter = new PdfWriter(outputMemoryStream);
            var pdfDocument = new PdfDocument(pdfWriter);
            var document = new iText.Layout.Document(pdfDocument);

            // Add text and formatting logic as per your document's structure For example, extract
            // paragraphs, tables, etc., from the WordprocessingDocument
            var body = wordDocument.MainDocumentPart.Document.Body;
            foreach (var paragraph in body.Elements<Paragraph>())
            {
                document.Add(new iText.Layout.Element.Paragraph(paragraph.InnerText));
            }

            document.Close();
            return outputMemoryStream.ToArray();
        }
    }
}