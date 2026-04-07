namespace Concursus.EF.Types;

public class GridViewDefinition : IntTypeBase
{
    #region Public Fields

    public List<GridViewColumnDefinition> Columns = new();

    #endregion Public Fields

    #region Public Properties

    public bool AllowCsvExport { get; set; }
    public bool AllowExcelExport { get; set; }
    public bool AllowNew { get; set; }
    public bool AllowPdfExport { get; set; }
    public string Code { get; set; } = "";
    public string DefaultSortColumnName { get; set; } = "";
    public string DetailPageUri { get; set; } = "";
    public string DisplayGroupName { get; set; } = "";
    public int DisplayOrder { get; set; }
    public string DrawerIconCss { get; set; } = "";
    public Guid EntityTypeGuid { get; set; }
    public Guid Guid { get; set; } //OE - CBLD-265
    public int GridDefinitionId { get; set; }
    public bool IsDefaultSortDescending { get; set; }
    public bool IsDetailWindowed { get; set; }
    public string MetricSqlQuery { get; set; } = "";
    public string Name { get; set; } = "";
    public bool ShowMetric { get; set; }
    public string SqlQuery { get; set; } = "";
    public int GridViewTypeId { get; set; } //OE - CBLD-265
    public List<GridViewAction> GridViewActions { get; set; }

    public bool AllowBulkChange { get; set; } // [OE: CBLD-260]

    public bool ShowOnMobile { get; set; }

    public string TreeListFirstOrderBy { get; set; }
    public string TreeListSecondOrderBy { get; set; }

    public string TreeListThirdOrderBy { get; set; }
    public string TreeListGroupBy { get; set; }
    public string TreeListOrderBy { get; set; }

    public string FilteredListCreatedOnColumn { get; set; }
    public string FilteredListGroupBy { get; set; }
    public string FilteredListRedStatusIndicatorTxt { get; set; }
    public string FilteredListOrangeStatusIndicatorTxt { get; set; }
    public string FilteredListGreenStatusIndicatorTxt { get; set; }




    #endregion Public Properties
}