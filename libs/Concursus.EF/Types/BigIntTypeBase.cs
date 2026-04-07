namespace Concursus.EF.Types;

public class BigIntTypeBase
{
    #region Public Properties

    public Guid Guid { get; set; }
    public long Id { get; set; }
    public Enums.RowStatus RowStatus { get; set; }
    public string RowVersion { get; set; } = "";

    #endregion Public Properties
}