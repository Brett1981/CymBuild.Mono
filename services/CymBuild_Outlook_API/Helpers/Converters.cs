using CymBuild_Outlook_Common.Models.SharePoint;
using Google.Protobuf.WellKnownTypes;

namespace CymBuild_Outlook_API.Helpers;

public static class Converters
{
    #region Public Methods

    public static string GetModifiedUrl(string url)
    {
        // Check if the URL is not empty or null
        if (string.IsNullOrEmpty(url))
            return url;

        try
        {
            // Create a Uri object from the URL
            var uri = new Uri(url);

            // Get the directory name (this will exclude the filename and extension)
            var modifiedPath = System.IO.Path.GetDirectoryName(uri.AbsolutePath)?.Replace('\\', '/');

            // If modifiedPath is null or empty, return the original URL
            if (string.IsNullOrEmpty(modifiedPath))
                return url;

            // Construct the modified URL
            var modifiedUrl = $"{uri.Scheme}://{uri.Host}{modifiedPath}";

            return modifiedUrl;
        }
        catch (UriFormatException)
        {
            // Handle the case where the URL format is invalid
            return url;
        }
    }

    public static DriveItem ConvertMicrosoftGraphDriveItemToCoreDriveItem(Microsoft.Graph.Models.DriveItem driveItemInfo, string driveId)
    {
        //Convert Microsoft Graph DriveItem To Core DriveItem
        DriveItem rsl = new()
        {
            Id = driveItemInfo.Id,
            Name = driveItemInfo.Name,
            WebUrl = driveItemInfo.WebUrl,
            ParentReference = new DriveItem.ItemReference
            {
                DriveId = driveItemInfo.ParentReference.DriveId,
                DriveType = driveItemInfo.ParentReference.DriveType,
                Id = driveItemInfo.ParentReference.Id,
                Path = driveItemInfo.ParentReference.Path,
            },
            DriveId = driveId,
            CreatedDateTime = (DateTime)DateTimeOffsetToDateTime(driveItemInfo.CreatedDateTime),
            LastModifiedDateTime = (DateTime)DateTimeOffsetToDateTime(driveItemInfo.LastModifiedDateTime),
            Size = (long)driveItemInfo.Size,
            CTag = driveItemInfo.CTag
        };
        return rsl;
    }

    public static DateTime? DateTimeOffsetToDateTime(this DateTimeOffset? dateTimeOffset)
    {
        return dateTimeOffset?.DateTime ?? new DateTime();
    }

    // Helper function for converting DateTimeOffset? to Timestamp
    public static Timestamp? ConvertDateTimeOffsetToTimestamp(DateTimeOffset? dateTimeOffset)
    {
        return dateTimeOffset.HasValue
            ? Timestamp.FromDateTimeOffset(dateTimeOffset.Value.ToUniversalTime())
            : (Timestamp?)null;  // Handle the case where dateTimeOffset is null
    }

    #endregion Public Methods
}