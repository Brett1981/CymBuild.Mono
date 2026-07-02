using Concursus.API.Client;
using Concursus.API.Core;
using Microsoft.AspNetCore.Components;

namespace Concursus.PWA.Shared.DeveloperInspector;

public sealed class DeveloperInspectorState
{
    private DeveloperInspectorResult? _currentResult;

    public event Action? OnChange;

    public bool IsEnabled { get; private set; }
    public bool IsPanelOpen { get; private set; }
    public DeveloperInspectorResult? CurrentResult => _currentResult;

    public void Toggle()
    {
        IsEnabled = !IsEnabled;
        if (!IsEnabled)
        {
            IsPanelOpen = false;
            _currentResult = null;
        }
        NotifyChanged();
    }

    public void ClosePanel()
    {
        IsPanelOpen = false;
        NotifyChanged();
    }

    public async Task InspectAsync(FormHelper? formHelper, DeveloperInspectorRequest request, CancellationToken cancellationToken = default)
    {
        if (!IsEnabled || formHelper is null)
        {
            return;
        }

        try
        {
            _currentResult = await formHelper.DeveloperInspectorGetAsync(request, cancellationToken).ConfigureAwait(false);
            IsPanelOpen = true;
        }
        catch (Exception ex)
        {
            _currentResult = new DeveloperInspectorResult
            {
                IsEnabled = IsEnabled,
                IsSuccess = false,
                Message = ex.Message,
                ComponentName = request.ComponentName,
                Route = request.Route
            };
            IsPanelOpen = true;
        }

        NotifyChanged();
    }

    private void NotifyChanged() => OnChange?.Invoke();
}
