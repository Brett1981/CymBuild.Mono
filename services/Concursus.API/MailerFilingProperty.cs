namespace Concursus.API;

public class MailerFilingProperty
{
    #region Public Properties

    public string? EntityType { get; set; }
    public int FilingStructureId { get; set; }
    public long RowId { get; set; }
    public bool Submitted { get; set; }
    public bool WasDraft { get; set; }

    #endregion Public Properties
}

public class ShoreMailerSingleValueExt
{
    #region Public Properties

    public string? DoNotFile { get; set; }
    public string? ShoreMailerFilingDestination { get; set; }
    public string? ShoreMailerFilingHistory { get; set; }

    #endregion Public Properties
}