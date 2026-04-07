namespace Concursus.EF.Types;

public class GridViewColumnDefinition : IntTypeBase
{
    #region Public Properties

    public int ColumnOrder { get; set; }
    public string DisplayFormat { get; set; } = "";
    public int GridViewDefinitionId { get; set; }
    public bool IsCombo { get; set; }
    public bool IsFiltered { get; set; }
    public bool IsHidden { get; set; }
    public bool IsPrimaryKey { get; set; }
    public string Name { get; set; } = "";
    public string Title { get; set; } = "";
    public string Width { get; set; } = "";

    //CBLD-338
    public string TopHeaderCategory { get; set; }

    public int TopHeaderCategoryOrder { get; set; }

    #endregion Public Properties
}