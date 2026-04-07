namespace Concursus.EF.Types
{
    public class WidgetLayoutGetResponse
    {
        #region Public Properties

        public string WidgetLayout { get; set; } = "";
        public List<DashboardMetricForWidgets> DashboardMetrics { get; set; } = new();
        public List<GridViewDefinitionForWidgets> GridViewDefinitions { get; set; } = new();

        #endregion Public Properties
    }

    public class GridViewDefinitionForWidgets : GridViewDefinition
    {
        public string GridViewCode { get; set; }
    }

    public class DashboardMetricForWidgets : DashboardMetric
    {
        public string Code { get; set; }
        public string GridViewCode { get; set; }
    }
}