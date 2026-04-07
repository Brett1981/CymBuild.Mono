using Concursus.API.Core;

namespace Concursus.API.Client;

public class MenuItem
{
    #region Public Properties

    public string? DocumentGuid { get; set; }
    public string? DocumentId { get; set; }
    public string? DriveId { get; set; }
    public string? EntityQueryGuid { get; set; }
    public string? EntityTypeGuid { get; set; }
    public string? FilenameTemplate { get; set; }
    public bool AllowPDFOnly { get; set; }
    public bool AllowExcelOutputOnly { get; set; }
    public object? Icon { get; set; }
    public bool? IsReadOnly { get; set; } = false;
    public bool IsSeparator { get; set; }
    public List<MenuItem>? Items { get; set; }
    public string? LinkedEntityTypeGuid { get; set; }
    public string? ObjectGuid { get; set; }
    public bool OpenInNewTab { get; set; } = false;
    public string _Guid { get; set; } = Guid.Empty.ToString();
    public string? RecordGuid { get; set; }
    public string? Text { get; set; }
    public string? Type { get; set; }
    public string? Url { get; set; }

    public int SortOrder { get; set; } = 0;
    public bool RedirectToTargetGuid { get; set; } = false;
    public List<MergeDocumentItem> MergeDocumentItems { get; set; } = new List<MergeDocumentItem>();

    #endregion Public Properties
}