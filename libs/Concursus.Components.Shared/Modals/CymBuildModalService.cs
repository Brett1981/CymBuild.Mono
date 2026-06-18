using Concursus.API.Client.Models;
using Concursus.Components.Shared.Classes;
using Microsoft.AspNetCore.Components;
using Newtonsoft.Json;
using System.Web;

namespace Concursus.Components.Shared.Modals;

public sealed class CymBuildModalService
{
    private readonly ModalService _legacyModalService;
    private TaskCompletionSource<CymBuildModalResult>? _completionSource;
    private string? _registeredModalId;

    public CymBuildModalService(ModalService legacyModalService)
    {
        _legacyModalService = legacyModalService ?? throw new ArgumentNullException(nameof(legacyModalService));
    }

    public event Func<Task>? OnChanged;

    public Type? ComponentType { get; private set; }
    public string Title { get; private set; } = string.Empty;
    public string SizeCssClass { get; private set; } = "cb-v2-modal-lg";
    public Dictionary<string, object?> Parameters { get; private set; } = new();
    public bool IsVisible { get; private set; }

    public async Task<CymBuildModalResult> ShowAsync<TComponent>(
        string title,
        Dictionary<string, object?>? parameters = null,
        string sizeCssClass = "cb-v2-modal-lg")
        where TComponent : IComponent
    {
        ComponentType = typeof(TComponent);
        Title = title;
        SizeCssClass = sizeCssClass;
        Parameters = parameters ?? new Dictionary<string, object?>();
        IsVisible = true;

        _completionSource = new TaskCompletionSource<CymBuildModalResult>();

        await NotifyChangedAsync();
        return await _completionSource.Task.ConfigureAwait(false);
    }

    public Task<CymBuildModalResult> ShowWindowedEntityAsync<TComponent>(
    object eventReceiver,
    string title,
    Guid recordGuid,
    Guid entityTypeGuid,
    string returnUrl,
    bool isInformationPage = false,
    bool isMainRecordContext = true)
    where TComponent : IComponent
    {
        var modalId = Guid.NewGuid().ToString();

        var dataObjectReference = new DataObjectReference(
            recordGuid.ToString(),
            entityTypeGuid.ToString());

        var serializedDataObjectReference = HttpUtility.UrlEncode(
            JsonConvert.SerializeObject(dataObjectReference));

        var parameters = new Dictionary<string, object?>
        {
            ["EntityTypeGuid"] = entityTypeGuid.ToString(),
            ["Windowed"] = true,
            ["CloseWindow"] = EventCallback.Factory.Create(eventReceiver, CloseAsync),
            ["RecordGuid"] = recordGuid.ToString(),
            ["SerializedDataObjectReference"] = serializedDataObjectReference,
            ["ParentDataObjectReference"] = dataObjectReference,
            ["ReturnUrl"] = returnUrl,
            ["ModalId"] = modalId
        };

        if (isInformationPage)
            parameters["IsInformationPage"] = true;

        if (!isMainRecordContext)
            parameters["IsMainRecordContext"] = false;

        _registeredModalId = modalId;
        _legacyModalService.RegisterModal(modalId, dataObjectReference);

        return ShowAsync<TComponent>(title, parameters);
    }

    public async Task CloseAsync(object? data = null)
    {
        TryUnregisterLegacyModal();

        IsVisible = false;
        ComponentType = null;
        Parameters.Clear();

        _completionSource?.TrySetResult(CymBuildModalResult.Ok(data));

        await NotifyChangedAsync();
    }

    public async Task CancelAsync()
    {
        TryUnregisterLegacyModal();

        IsVisible = false;
        ComponentType = null;
        Parameters.Clear();

        _completionSource?.TrySetResult(CymBuildModalResult.Cancel());

        await NotifyChangedAsync();
    }

    private void TryUnregisterLegacyModal()
    {
        if (string.IsNullOrWhiteSpace(_registeredModalId))
            return;

        try
        {
            _legacyModalService.UnregisterModal(_registeredModalId);
        }
        finally
        {
            _registeredModalId = null;
        }
    }

    private Task NotifyChangedAsync()
    {
        return OnChanged?.Invoke() ?? Task.CompletedTask;
    }
}

public sealed class CymBuildModalResult
{
    public bool Cancelled { get; init; }
    public object? Data { get; init; }

    public static CymBuildModalResult Ok(object? data = null)
    {
        return new CymBuildModalResult
        {
            Cancelled = false,
            Data = data
        };
    }

    public static CymBuildModalResult Cancel()
    {
        return new CymBuildModalResult
        {
            Cancelled = true
        };
    }
}