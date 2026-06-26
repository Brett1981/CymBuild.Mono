using Microsoft.AspNetCore.Components;
using System.Reflection;

namespace Concursus.PWA.Shared;

public partial class GridFilterButton : ComponentBase, IAsyncDisposable
{
    private const string ClearBtnTitle = "All Grids [Clear Filters]";

    private bool _menuOpen;
    private string? _toastMessage;
    private CancellationTokenSource? _toastCancellation;

    [Inject] public Helpers.LocalStorageAccessor LocalStorageAccessor { get; set; } = default!;

    /// <summary>
    /// Transitional compatibility parameter.
    /// Existing callers pass GridRef today. Keeping this as object avoids a third-party grid compile-time dependency
    /// while still allowing the button to clear the currently displayed grid via reflection during migration.
    /// Once DynamicGridView/FilteredDynamicGridView are fully native, replace usages with OnClearFilters.
    /// </summary>
    [Parameter] public object? GridRef { get; set; }

    /// <summary>
    /// Preferred native-grid callback. Parent grids should clear their own filter/search/sort state here.
    /// </summary>
    [Parameter] public EventCallback OnClearFilters { get; set; }

    [Parameter] public string ButtonText { get; set; } = "Filters";

    [Parameter] public string ClearText { get; set; } = ClearBtnTitle;

    private void ToggleMenu()
    {
        _menuOpen = !_menuOpen;
    }

    private async Task HandleFocusOutAsync()
    {
        await Task.Delay(150).ConfigureAwait(false);
        _menuOpen = false;
        await InvokeAsync(StateHasChanged).ConfigureAwait(false);
    }

    private async Task ClearAllFiltersAsync()
    {
        _menuOpen = false;

        try
        {
            await LocalStorageAccessor.ClearAllGridFilters().ConfigureAwait(false);

            if (OnClearFilters.HasDelegate)
            {
                await OnClearFilters.InvokeAsync().ConfigureAwait(false);
            }
            else if (GridRef is not null)
            {
                await TryClearLegacyGridStateAsync(GridRef).ConfigureAwait(false);
            }

            await ShowToastAsync("Clear filters for all grids").ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"GridFilterButton: failed to clear filters. {ex}");
            await ShowToastAsync("Unable to clear filters. Please refresh the page and try again.", isSuccess: false).ConfigureAwait(false);
        }
    }

    private static async Task TryClearLegacyGridStateAsync(object gridRef)
    {
        var gridType = gridRef.GetType();

        var getStateMethod = gridType.GetMethod("GetState", BindingFlags.Public | BindingFlags.Instance);
        var state = getStateMethod?.Invoke(gridRef, Array.Empty<object>());
        if (state is null)
            return;

        ClearPropertyIfPresent(state, "FilterDescriptors");
        ClearPropertyIfPresent(state, "SearchFilter");

        var setStateMethod = gridType
            .GetMethods(BindingFlags.Public | BindingFlags.Instance)
            .FirstOrDefault(m => string.Equals(m.Name, "SetStateAsync", StringComparison.Ordinal)
                              && m.GetParameters().Length == 1);

        if (setStateMethod is null)
            return;

        var result = setStateMethod.Invoke(gridRef, new[] { state });

        if (result is Task task)
            await task.ConfigureAwait(false);
    }

    private static void ClearPropertyIfPresent(object target, string propertyName)
    {
        var property = target.GetType().GetProperty(propertyName, BindingFlags.Public | BindingFlags.Instance);
        if (property is null || !property.CanWrite)
            return;

        if (property.PropertyType.IsValueType && Nullable.GetUnderlyingType(property.PropertyType) is null)
            property.SetValue(target, Activator.CreateInstance(property.PropertyType));
        else
            property.SetValue(target, null);
    }

    private async Task ShowToastAsync(string message, bool isSuccess = true)
    {
        _toastCancellation?.Cancel();
        _toastCancellation?.Dispose();
        _toastCancellation = new CancellationTokenSource();

        _toastMessage = message;
        await InvokeAsync(StateHasChanged).ConfigureAwait(false);

        try
        {
            await Task.Delay(TimeSpan.FromSeconds(isSuccess ? 2 : 4), _toastCancellation.Token).ConfigureAwait(false);
            _toastMessage = null;
            await InvokeAsync(StateHasChanged).ConfigureAwait(false);
        }
        catch (TaskCanceledException)
        {
            // Expected when a new toast replaces the current one or the component is disposed.
        }
    }

    public ValueTask DisposeAsync()
    {
        _toastCancellation?.Cancel();
        _toastCancellation?.Dispose();
        return ValueTask.CompletedTask;
    }
}
