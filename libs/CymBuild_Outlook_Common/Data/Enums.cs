using System.ComponentModel;

namespace CymBuild_Outlook_Common.Data;

public static class Enums
{
    #region Public Enums

    /// <summary>
    /// Returns the default 'Area' type sub locations per ID provided
    /// </summary>
    public enum AreaFolder
    {
        [Description("Admin")] Admin = 1,

        [Description("Certs")] Certs = 2,

        [Description("Design Information")] Designinformation = 3,

        [Description("Design Risk")] Designrisk = 8,

        [Description("Emails")] Emails = 9,

        [Description("Finance")] Finance = 10,

        [Description("Fire Consultation")] Fireconsultation = 14,

        [Description("Photos")] Photos = 11,

        [Description("Quote Documents")] Quotedocuments = 12,

        [Description("Site Documents")] Sitedocuments = 13
    }

    /// <summary>
    /// Used in conjunction with the 'Area' type sub location, Provides a list of Sub 'Sub'
    /// Locations per ID provided
    /// </summary>
    public enum CategoryFolder
    {
        [Description("None")] None = 0,

        [Description("Architectural")] Architectural = 4,

        [Description("MEP")] Mep = 5,

        [Description("Other")] Other = 6,

        [Description("Structural")] Structural = 7
    }

    public enum FilingLocation
    {
        [Description("Local")] Local,

        [Description("SharePoint")] Sharepoint
    }

    /// <summary>
    /// Returns Root Folder selected, used to determine type and location of file requirements
    /// </summary>
    /// <returns> 0 = BC Folders, 1 = Shore Folders, 2 = Quote Folders </returns>
    public enum RootFolder
    {
        [Description(Constants.BuildingControlFolderName)]
        Bcfolder,

        [Description(Constants.ShoreJobFolderName)]
        Shorefolder,

        [Description(Constants.QuotesFolderName)]
        Quotefolder,

        [Description(Constants.UsersFolderName)]
        Usersfolder,

        [Description(Constants.TicketsFolderName)]
        Ticketsfolder
    }

    public enum SubCategoryFolder
    {
        [Description("None")] None = 0,

        [Description("Other")] Other
    }

    #endregion Public Enums
}