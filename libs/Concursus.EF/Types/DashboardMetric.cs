namespace Concursus.EF.Types;

public class DashboardMetric
{
    #region Public Properties

    public string DisplayGroupName { get; set; } = "";
    public int DisplayOrder { get; set; }
    public int EndAngle { get; set; }
    public Guid Guid { get; set; }
    public string Label { get; set; } = "";
    public int MajorUnit { get; set; }
    public int Max { get; set; }
    public string MetricSqlQuery { get; set; } = "";
    public string MetricTypeName { get; set; } = "";
    public int Min { get; set; }
    public int MinorUnit { get; set; }
    public string PageUri { get; set; } = "";
    public List<DashboardMetricRange> Ranges { get; set; } = new();
    public bool Reverse { get; set; }
    public int StartAngle { get; set; }
    public List<DashboardMetricValue> Values { get; set; } = new();

    #endregion Public Properties
}