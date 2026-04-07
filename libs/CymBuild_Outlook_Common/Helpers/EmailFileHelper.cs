using CymBuild_Outlook_Common.Data;
using MimeKit;

namespace CymBuild_Outlook_Common.Helpers;

/// <summary>
/// Helper Classes, used to assist with email manipulation.
/// </summary>
public static class EmailFileHelper
{
    #region Public Methods

    /// <summary>
    /// Save the relevent MailMessage to a physical folder of choice, this will be saved as an .eml file
    /// </summary>
    public static void SaveTo(Stream mimeStream, FilePath filePath)
    {
        //MimeMessage message = MimeMessage.Load(mimeStream);

        //MemoryStream stream = new MemoryStream();

        //message.WriteTo(stream);

        if (string.IsNullOrEmpty(filePath.FileName)) filePath.FileName = Guid.NewGuid().ToString() + ".eml";

        if (!filePath.FileName.EndsWith(".eml")) filePath.FileName += ".eml";

        Storage.SaveFileTo(mimeStream, filePath);
    }

    /// <summary>
    /// Save the relevent MailMessage to a physical folder of choice, this will be saved as an .eml file
    /// </summary>
    public static void SaveToPickupDirectory(MimeMessage message, string pickupDirectory, string fileName = "")
    {
        if (string.IsNullOrEmpty(fileName)) fileName = Guid.NewGuid().ToString();
        do
        {
            // Note: this will require that you know where the specified pickup directory is.
            var path = Path.Combine(pickupDirectory, fileName + ".eml");

            if (File.Exists(path))
                continue;

            try
            {
                using (var stream = new FileStream(path, FileMode.CreateNew))
                {
                    message.WriteTo(stream);
                    return;
                }
            }
            catch (IOException)
            {
                // The file may have been created between our File.Exists() check and our attempt to
                // create the stream.
            }
        } while (true);
    }

    #endregion Public Methods
}