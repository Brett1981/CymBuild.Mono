namespace Concursus.EF.Types;

public class GridDefinition : IntTypeBase
{
    #region Public Fields

    public List<GridViewDefinition> Views = new();

    #endregion Public Fields

    #region Public Properties

    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
    public string PageUri { get; set; } = "";
    public bool ShowAsTiles { get; set; }
    public string TabName { get; set; } = "";

    #endregion Public Properties
}