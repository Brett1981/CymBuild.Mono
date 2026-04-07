namespace Concursus.EF.Types;

public class DropDownDataListItem
{
    #region Public Properties

    public string Group { get; set; } = "";
    public string Name { get; set; } = "";
    public string Value { get; set; } = "";

    public string ColourHex { get; set; } = "#000000"; //CBLD-570

    #endregion Public Properties
}