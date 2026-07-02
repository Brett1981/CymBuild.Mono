namespace Concursus.Components.Shared.Services;

public interface IToastService
{
    void ShowSuccess(string message, string title = "Success");

    void ShowWarning(string message, string title = "Warning");

    void ShowError(string message, string title = "Error");

    void ShowInfo(string message, string title = "Info");
}

public enum ToastNotificationKind
{
    Success,
    Warning,
    Error,
    Info
}

public sealed record ToastNotification(
    Guid Id,
    string Message,
    string Title,
    ToastNotificationKind Kind,
    DateTimeOffset CreatedOn,
    int TimeoutMilliseconds);

public sealed class NativeToastService : IToastService
{
    public event EventHandler<ToastNotification>? ToastRequested;

    public void ShowSuccess(string message, string title = "Success") =>
        Show(message, title, ToastNotificationKind.Success);

    public void ShowWarning(string message, string title = "Warning") =>
        Show(message, title, ToastNotificationKind.Warning);

    public void ShowError(string message, string title = "Error") =>
        Show(message, title, ToastNotificationKind.Error);

    public void ShowInfo(string message, string title = "Info") =>
        Show(message, title, ToastNotificationKind.Info);

    private void Show(string message, string title, ToastNotificationKind kind)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            return;
        }

        var timeoutMilliseconds = kind is ToastNotificationKind.Error or ToastNotificationKind.Warning
            ? 8000
            : 6000;

        ToastRequested?.Invoke(
            this,
            new ToastNotification(
                Guid.NewGuid(),
                message.Trim(),
                string.IsNullOrWhiteSpace(title) ? kind.ToString() : title.Trim(),
                kind,
                DateTimeOffset.Now,
                timeoutMilliseconds));
    }
}
