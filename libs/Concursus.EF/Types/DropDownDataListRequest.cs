namespace Concursus.EF.Types;

public class DropDownDataListRequest
{
    #region Public Properties

    public Guid CurrentSelectedValueGuid { get; set; } = Guid.Empty;
    public List<DataObjectCompositeFilter> Filters { get; set; } = new();
    public Guid Guid { get; set; }
    public bool IsAddingAllowed { get; set; }
    public Guid ParentGuid { get; set; }
    public Guid RecordGuid { get; set; }

    #endregion Public Properties
}