namespace Concursus.PWA.Shared.Scheduler.Classes
{
    public class MenuItems
    {
        public string Text { get; set; }
        public string Url { get; set; }
        public List<MenuItems> Items { get; set; }
        public string Icon { get; set; }
    }
}