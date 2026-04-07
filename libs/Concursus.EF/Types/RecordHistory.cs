namespace Concursus.EF.Types;

public class RecordHistory : BigIntTypeBase
{
    #region Public Properties

    public string ColumnName { get; set; } = "";
    public DateTime DateTimeUtc { get; set; } = new();
    public string NewValue { get; set; } = "";
    public string PreviousValue { get; set; } = "";
    public long RowId { get; set; }
    public string SchemaName { get; set; } = "";
    public string SqlUser { get; set; } = "";
    public string TableName { get; set; } = "";
    public int UserId { get; set; }
    public string UserName { get; set; } = "";

    #endregion Public Properties
}