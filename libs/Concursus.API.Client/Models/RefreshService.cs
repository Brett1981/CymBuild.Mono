namespace Concursus.API.Client.Models
{
    public class RefreshService
    {
        public event Action RefreshRequested;

        public event Action GridRefreshRequested;

        public string GridCodeSelected { get; set; } = "";

        public void RequestRefresh()
        {
            RefreshRequested?.Invoke();
        }

        public void RequestGridRefresh(string GridCode)
        {
            GridRefreshRequested?.Invoke();
            GridCodeSelected = GridCode;
        }
    }
}