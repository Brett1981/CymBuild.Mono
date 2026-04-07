namespace Concursus.Components.Shared.Services
{
    public class SyncQueueState
    {
        public int Count { get; set; }

        public event Action? OnChange;

        public void SetCount(int newCount)
        {
            if (Count != newCount)
            {
                Count = newCount;
                OnChange?.Invoke();
            }
        }
    }
}