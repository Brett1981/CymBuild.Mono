using System.Drawing;
using System.Drawing.Imaging;
using Telerik.Windows.Documents.Extensibility;
using Telerik.Windows.Documents.Fixed.FormatProviders.Pdf.Export;

namespace Concursus.PWA.Helpers;

internal class JpegImageConverter : JpegImageConverterBase
{
    public override bool TryConvertToJpegImageData(byte[] imageData, ImageQuality imageQuality, out byte[] jpegImageData)
    {
        jpegImageData = null;

        try
        {
            using (var ms = new MemoryStream(imageData))
            using (var image = Image.FromStream(ms))
            {
                // If the image is a PNG, ensure it has a white background
                if (image.RawFormat.Equals(ImageFormat.Png))
                {
                    using (var bitmap = new Bitmap(image.Width, image.Height))
                    using (var graphics = Graphics.FromImage(bitmap))
                    {
                        graphics.Clear(Color.White); // Set background to white
                        graphics.DrawImage(image, 0, 0, image.Width, image.Height); // Draw the original image on top

                        // Convert the bitmap to JPEG
                        using (var jpegMs = new MemoryStream())
                        {
                            var jpegEncoder = GetEncoder(ImageFormat.Jpeg);
                            var encoderParams = new EncoderParameters(1);
                            encoderParams.Param[0] = new EncoderParameter(Encoder.Quality, (long)imageQuality);

                            bitmap.Save(jpegMs, jpegEncoder, encoderParams);
                            jpegImageData = jpegMs.ToArray();
                        }
                    }
                }
                else
                {
                    // Convert non-PNG images directly to JPEG
                    using (var jpegMs = new MemoryStream())
                    {
                        var jpegEncoder = GetEncoder(ImageFormat.Jpeg);
                        var encoderParams = new EncoderParameters(1);
                        encoderParams.Param[0] = new EncoderParameter(Encoder.Quality, (long)imageQuality);

                        image.Save(jpegMs, jpegEncoder, encoderParams);
                        jpegImageData = jpegMs.ToArray();
                    }
                }
            }

            return true;
        }
        catch (Exception ex)
        {
            if (ex is ArgumentException || ex is InvalidOperationException) // Handle unsupported formats or processing errors
            {
                jpegImageData = null;
                return false;
            }
            else
            {
                throw; // Re-throw unexpected exceptions
            }
        }
    }

    private static ImageCodecInfo GetEncoder(ImageFormat format)
    {
        var codecs = ImageCodecInfo.GetImageEncoders();
        foreach (var codec in codecs)
        {
            if (codec.FormatID == format.Guid)
            {
                return codec;
            }
        }
        return null;
    }
}