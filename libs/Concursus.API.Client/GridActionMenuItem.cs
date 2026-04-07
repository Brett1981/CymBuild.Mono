namespace Concursus.API.Client;

//CBLD-265
public class GridActionMenuItem
{
    #region Public Properties

    public string Text { get; set; }
    public string Icon { get; set; } = "";
    public string Query { get; set; } = "";

    public List<GridActionMenuItem> Items { get; set; }
    public FormHelper FormHelper { get; set; }

    #endregion Public Properties
}