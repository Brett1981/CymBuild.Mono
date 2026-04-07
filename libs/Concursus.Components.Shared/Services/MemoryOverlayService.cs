public class MemoryOverlayService
{
    public event Action? OnChanged;

    public bool IsVisible { get; private set; }

    public void Show()
    {
        IsVisible = true;
        OnChanged?.Invoke();
    }

    public void Hide()
    {
        IsVisible = false;
        OnChanged?.Invoke();
    }

    public void Toggle()
    {
        IsVisible = !IsVisible;
        OnChanged?.Invoke();
    }
}