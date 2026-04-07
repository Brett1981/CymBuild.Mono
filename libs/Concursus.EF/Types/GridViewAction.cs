namespace Concursus.EF.Types
{
    public class GridViewAction
    {
        public Guid Guid { get; set; }
        public string Statement { get; set; } = "";
        public string Title { get; set; } = "";

        public List<GridViewAction> Items { get; set; }
    }
}