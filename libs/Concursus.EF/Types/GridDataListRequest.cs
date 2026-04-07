namespace Concursus.EF.Types;

public class GridDataListRequest
{
    #region Public Properties

    public List<DataObjectCompositeFilter> Filters { get; set; } = new();
    public string GridCode { get; set; } = "";
    public string GridViewCode { get; set; } = "";
    public int Page { get; set; }
    public int PageSize { get; set; }
    public Guid ParentGuid { get; set; }
    public List<DataSort> Sort { get; set; } = new();

    #endregion Public Properties
}