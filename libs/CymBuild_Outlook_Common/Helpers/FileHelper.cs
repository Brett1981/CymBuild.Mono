namespace CymBuild_Outlook_Common.Helpers;

/// <summary>
/// File Helper, Used to assist with Folder Structures and File Manipulation
/// </summary>
public static class FileHelper
{
    #region Public Methods

    /// <summary>
    /// Generated the Root Folder of a numberstructer divided by 100, for determining the parent
    /// folder of a Job Number
    /// </summary>
    /// <returns> Parent Folder used by SharePoint </returns>
    public static string RootDividerFolder(long folderIdentifier)
    {
        try
        {
            if (folderIdentifier.ToString().Length <= 2)
            {
                return Convert.ToString(0);
            }
            else
            {
                var folderSeperator = "";
                var folderIdentified = Convert.ToInt32(folderIdentifier.ToString().Trim()
                    .Substring(0, folderIdentifier.ToString().Length - 2));

                var subFolderNo =
                    Convert.ToInt32(folderIdentifier.ToString().Substring(folderIdentifier.ToString().Length - 2));

                return Convert.ToString(folderIdentified) + folderSeperator;
            }
        }
        catch
        {
            return Convert.ToString(0);
        }
    }

    #endregion Public Methods
}