using Concursus.Components.Shared.Services;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;

namespace Concursus.PWA.Shared;

public partial class MainLayout
{
    private const int MaximumVisibleToastCount = 5;

    private readonly List<ToastNotification> _toastNotifications = [];
    private bool showDiagnostics;
    private DotNetObjectReference<MainLayout>? dotNetRef;

    private bool IsDebug
    {
        get
        {
#if DEBUG
            return true;
#else
            return false;
#endif
        }
    }

    protected override void OnInitialized()
    {
        if (ToastService is NativeToastService nativeToastService)
        {
            nativeToastService.ToastRequested += OnToastRequested;
        }
    }

    [JSInvokable]
    public void ToggleDiagnostics()
    {
        showDiagnostics = !showDiagnostics;
        StateHasChanged();
    }

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (!firstRender)
        {
            return;
        }

        // Register key-handler only in RELEASE.
        if (!IsDebug)
        {
            dotNetRef = DotNetObjectReference.Create(this);
            await JS.InvokeVoidAsync("registerDiagnosticsToggle", dotNetRef);
        }
    }

    private void OnToastRequested(object? sender, ToastNotification toast)
    {
        _ = InvokeAsync(async () =>
        {
            _toastNotifications.Add(toast);

            while (_toastNotifications.Count > MaximumVisibleToastCount)
            {
                _toastNotifications.RemoveAt(0);
            }

            StateHasChanged();

            await Task.Delay(toast.TimeoutMilliseconds);

            if (RemoveToast(toast.Id))
            {
                StateHasChanged();
            }
        });
    }

    private void DismissToast(Guid id)
    {
        if (RemoveToast(id))
        {
            StateHasChanged();
        }
    }

    private bool RemoveToast(Guid id)
    {
        var toast = _toastNotifications.FirstOrDefault(x => x.Id == id);
        if (toast is null)
        {
            return false;
        }

        _toastNotifications.Remove(toast);
        return true;
    }

    private static string GetToastCssClass(ToastNotificationKind kind) => kind switch
    {
        ToastNotificationKind.Success => "success",
        ToastNotificationKind.Warning => "warning",
        ToastNotificationKind.Error => "error",
        ToastNotificationKind.Info => "info",
        _ => "info"
    };

    private static string GetToastAgeText(DateTimeOffset createdOn)
    {
        var elapsed = DateTimeOffset.Now - createdOn;

        if (elapsed.TotalSeconds < 60)
        {
            return "just now";
        }

        if (elapsed.TotalMinutes < 60)
        {
            var minutes = Math.Max(1, (int)Math.Floor(elapsed.TotalMinutes));
            return minutes == 1 ? "1 minute ago" : $"{minutes} minutes ago";
        }

        var hours = Math.Max(1, (int)Math.Floor(elapsed.TotalHours));
        return hours == 1 ? "1 hour ago" : $"{hours} hours ago";
    }

    public void Dispose()
    {
        if (ToastService is NativeToastService nativeToastService)
        {
            nativeToastService.ToastRequested -= OnToastRequested;
        }

        dotNetRef?.Dispose();
    }
}
