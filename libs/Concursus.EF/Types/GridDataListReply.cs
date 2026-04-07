namespace Concursus.EF.Types;

public class GridDataListReply
{
    #region Public Fields

    public List<GridDataRow> DataTable = new();

    #endregion Public Fields

    #region Public Properties

    public int TotalRows { get; set; }

    #endregion Public Properties
}