namespace Concursus.Common.Shared.Data;

/// <summary>
/// </summary>
public class FilePath
{
    #region Public Properties

    /// <summary>
    /// The area with in the record's folder
    /// </summary>
    public Enums.AreaFolder AreaFolder { get; set; }

    /// <summary>
    /// </summary>
    public string Attributes { get; set; } = "";

    /// <summary>
    /// </summary>
    public Enums.CategoryFolder CategoryFolder { get; set; }

    /// <summary>
    /// </summary>
    public string Extension { get; set; }

    /// <summary>
    /// The filename to use
    /// </summary>
    public string FileName { get; set; }

    /// <summary>
    /// The storage system to be used for the file.
    /// </summary>
    public Enums.FilingLocation FilingLocation { get; set; } = Enums.FilingLocation.Local;

    /// <summary>
    /// </summary>
    public bool IsDirectory { get; set; }

    /// <summary>
    /// </summary>
    public bool IsReadOnly { get; set; }

    /// <summary>
    /// The ID / Job ID of the record to file against.
    /// </summary>
    public long RecordId { get; set; }

    /// <summary>
    /// The root folder within the storage system.
    /// </summary>
    public Enums.RootFolder RootFolder { get; set; }

    /// <summary>
    /// </summary>
    public string ServerBaseLocation { get; set; }

    /// <summary>
    /// The virtual path to use after the RootFolder and RecordId. Area and Category Folders will be ignored.
    /// </summary>
    public string VirtualPath { get; set; }

    #endregion Public Properties
}