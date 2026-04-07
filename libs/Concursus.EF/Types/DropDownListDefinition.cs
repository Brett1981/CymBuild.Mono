namespace Concursus.EF.Types;

public class DropDownListDefinition : IntTypeBase
{
    #region Public Properties

    public string Code { get; set; } = "";
    public string DefaultSortColumnName { get; set; } = "";
    public string DetailPageUrl { get; set; } = "";
    public string GroupColumn { get; set; } = "";
    public string InformationPageUrl { get; set; } = "";
    public bool IsDetailWindowed { get; set; }
    public string NameColumn { get; set; } = "";
    public string SqlQuery { get; set; } = "";
    public string ValueColumn { get; set; } = "";

    public string ColourHexColumn { get; set; } = ""; //CBLD-570

    #endregion Public Properties
}