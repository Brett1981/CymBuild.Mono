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
            // Set before raising so subscribers can read which grid was requested.
            GridCodeSelected = GridCode;
            GridRefreshRequested?.Invoke();
        }
    }
}