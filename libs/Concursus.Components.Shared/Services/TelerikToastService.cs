// Ignore Spelling: Telerik

using Telerik.Blazor;
using Telerik.Blazor.Components;

namespace Concursus.Components.Shared.Services;

public interface IToastService
{
    void ShowSuccess(string message, string title = "Success");

    void ShowWarning(string message, string title = "Warning");

    void ShowError(string message, string title = "Error");

    void ShowInfo(string message, string title = "Info");
}

public class TelerikToastService : IToastService
{
    private TelerikNotification? _notification;

    public void Register(TelerikNotification notification)
    {
        _notification = notification;
    }

    public void ShowSuccess(string message, string title = "Success") =>
        _notification?.Show(new NotificationModel { Text = message, ThemeColor = ThemeConstants.Notification.ThemeColor.Success });

    public void ShowWarning(string message, string title = "Warning") =>
        _notification?.Show(new NotificationModel { Text = message, ThemeColor = ThemeConstants.Notification.ThemeColor.Warning });

    public void ShowError(string message, string title = "Error") =>
        _notification?.Show(new NotificationModel { Text = message, ThemeColor = ThemeConstants.Notification.ThemeColor.Error });

    public void ShowInfo(string message, string title = "Info") =>
        _notification?.Show(new NotificationModel { Text = message, ThemeColor = ThemeConstants.Notification.ThemeColor.Info });
}