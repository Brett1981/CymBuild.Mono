using Concursus.API.Client.Models;
using System.Diagnostics;
using Concursus.API.Core;
using Concursus.Components.Shared.Services;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using static Concursus.API.Core.Core;

namespace Concursus.PWA.Shared;

public partial class DynamicGrid : ComponentBase
{
    public List<DrawerItem> Data { get; set; } = new();

    public dynamic? Dgv { get; set; }

    [Parameter] public Dictionary<string, Any> TransientVirtualProperties { get; set; } = new();

    // Optional FormHelper boundary for metadata calls. Existing callers can omit this;
    // main record pages should pass it so the flow remains UI -> FormHelper -> gRPC -> EF -> SQL.
    [Parameter] public Concursus.API.Client.FormHelper? FormHelper { get; set; }

    // Safety net for grids rendered inside EditPage where FormHelper is available as the active
    // record helper but was not explicitly passed to the grid. This reduces DirectFallback use
    // without forcing every existing DynamicGrid call site to change in one pass.
    [CascadingParameter] public EditPage? ParentEditPage { get; set; }

    [Parameter] public string? DisabledMessage { get; set; }
    [Parameter] public string? DrawerGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = string.Empty;
    [Parameter] public bool IsLoading { get; set; }
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    [Parameter] public EventCallback<Exception> OnError { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public EventCallback<string> ParentGuidChanged { get; set; }
    [Parameter] public int ParentRowStatus { get; set; } = -1;
    [Parameter] public bool DoubleClickDisabled { get; set; }
    [Parameter] public bool Disabled { get; set; }
    [Parameter] public EventCallback<bool> DisabledChanged { get; set; }
    [Parameter] public EventCallback ResyncDataObject { get; set; }

    public DrawerItem? selectedItem { get; set; }

    private string? GridName { get; set; }
    private GridViewDefinition? BatchedTransactionsGvd { get; set; }
    private bool _drawerExpanded = false;
    private AllTransactionsTab _allTransactionsTab = AllTransactionsTab.Transactions;

    private bool ShouldRenderForDevice =>
        !DeviceInfoService.IsMobile ||
        (DeviceInfoService.IsMobile && selectedItem?.ViewDefinition?.ShowOnMobile == true);

    private enum AllTransactionsTab
    {
        Batched,
        Transactions
    }

    public class GridDrawerSessionData
    {
        public string Key { get; set; } = string.Empty;
        public string Value { get; set; } = string.Empty;
    }

    protected override async Task OnInitializedAsync()
    {
        try
        {
            IsLoading = true;

            if (!string.IsNullOrWhiteSpace(GridCode))
            {
                var gridDefinitionListReply = await GridDefinitionListGetAsync(GridCode).ConfigureAwait(false);

                var gd = gridDefinitionListReply.Grids.FirstOrDefault();
                if (gd is not null)
                {
                    GridName = gd.Name;
                    LoadDrawerItems(gd);
                    await RestoreSelectedDrawerItemAsync().ConfigureAwait(false);
                    await EnsureSpecialViewDataLoadedAsync().ConfigureAwait(false);
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "An error occurred while initializing the DynamicGrid component.";
            ex.Data["PageMethod"] = "DynamicGrid/OnInitializedAsync()";
            await OnError.InvokeAsync(ex).ConfigureAwait(false);
        }
        finally
        {
            if (ParentRowStatus != 999)
                IsLoading = false;
        }

        await base.OnInitializedAsync().ConfigureAwait(false);
    }

    private async Task<GridDefinitionListReply> GridDefinitionListGetAsync(string gridCode)
    {
        var stopwatch = Stopwatch.StartNew();

        var effectiveFormHelper = FormHelper ?? ParentEditPage?.ActiveFormHelper;

        if (effectiveFormHelper is not null)
        {
            return await effectiveFormHelper.GridDefinitionListGetAsync(gridCode).ConfigureAwait(false);
        }

        // Compatibility fallback for existing pages that have not yet passed a FormHelper through.
        // New main-record work should pass FormHelper so the UI does not own metadata retrieval.
        var reply = await coreClient.GridDefinitionListAsync(new GridDefinitionListRequest
        {
            Code = gridCode,
            ForUi = true
        }).ConfigureAwait(false);

        try
        {
            Console.WriteLine($"[CymBuildPerf] Layer=UI Method=DynamicGrid Step=GridDefinitionList Grid={gridCode} DurationMs={stopwatch.ElapsedMilliseconds} CacheHit=False Boundary=DirectFallback");
        }
        catch
        {
            // Logging must never affect user workflows.
        }

        return reply ?? new GridDefinitionListReply();
    }

    private void LoadDrawerItems(GridDefinition gridDefinition)
    {
        Data.Clear();

        var views = gridDefinition.Views
            .OrderBy(m => m.DisplayOrder)
            .Where(m => m.RowVersion != "254" && !m.IsHidden);

        if (DeviceInfoService.IsMobile)
            views = views.Where(m => m.ShowOnMobile);

        foreach (var gvd in views)
        {
            Data.Add(new DrawerItem
            {
                Text = gvd.Name,
                Icon = string.IsNullOrWhiteSpace(gvd.DrawIconCss) ? "bi bi-grid-3x3-gap" : gvd.DrawIconCss,
                ViewDefinition = gvd
            });
        }
    }

    private async Task RestoreSelectedDrawerItemAsync()
    {
        if (Data.Count == 0)
        {
            selectedItem = null;
            return;
        }

        var sessionCode = await SessionStorageAccessor.GetValueAsync<string>("Drawer").ConfigureAwait(false);

        selectedItem = string.IsNullOrWhiteSpace(sessionCode)
            ? Data.FirstOrDefault(x => x.ViewDefinition?.Guid == DrawerGuid) ?? Data.First()
            : Data.FirstOrDefault(x => x.ViewDefinition?.Code == sessionCode) ?? Data.First();
    }

    public async Task SelectedItemChangedHandlerAsync(DrawerItem item)
    {
        selectedItem = item;

        if (FullGrid && !string.IsNullOrWhiteSpace(item.ViewDefinition?.Code))
        {
            await SessionStorageAccessor.SetValueAsync("Drawer", item.ViewDefinition.Code).ConfigureAwait(false);
            InteractionTracker.Log(NavManager.Uri ?? "Drawer Selection", $"User changed Grid Draw - '{item.ViewDefinition.Code}'");
        }

        await EnsureSpecialViewDataLoadedAsync().ConfigureAwait(false);
        await InvokeAsync(StateHasChanged).ConfigureAwait(false);
    }

    public Task ToggleDrawer()
    {
        _drawerExpanded = !_drawerExpanded;
        InteractionTracker.Log(NavManager.Uri ?? "DynamicGrid.ToggleDrawer", "Toggled the drawer in the DynamicGrid component.");
        return Task.CompletedTask;
    }

    private async Task EnsureSpecialViewDataLoadedAsync()
    {
        if (selectedItem?.ViewDefinition?.Code == "ALLTRANSACTIONS")
            await LoadBatchedTransactionsAsync().ConfigureAwait(false);
    }

    private void SetAllTransactionsTab(AllTransactionsTab tab)
    {
        _allTransactionsTab = tab;
    }

    private bool IsSelected(DrawerItem item)
    {
        return string.Equals(
            selectedItem?.ViewDefinition?.Code,
            item.ViewDefinition?.Code,
            StringComparison.OrdinalIgnoreCase);
    }

    private void HandleActionCompleted()
    {
        _ = OnActionCompleted.InvokeAsync();
    }

    private async Task LoadBatchedTransactionsAsync()
    {
        if (BatchedTransactionsGvd is not null)
            return;

        var reply = await GridDefinitionListGetAsync("BATCHEDTRANSACTIONS").ConfigureAwait(false);

        BatchedTransactionsGvd = reply.Grids
            .FirstOrDefault()?
            .Views
            .FirstOrDefault(x => x.Code == "BATCHEDTRANSACTIONS");

        if (BatchedTransactionsGvd is not null)
            _allTransactionsTab = AllTransactionsTab.Batched;
    }

    public void RefreshGrid()
    {
        try
        {
            Dgv?.RefreshGrid();
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "An error occurred while refreshing the DynamicGrid child grid.";
            ex.Data["PageMethod"] = "DynamicGrid/RefreshGrid()";
            _ = OnError.InvokeAsync(ex);
        }
    }

    public class DrawerItem
    {
        public string DrawIconCss { get; set; } = string.Empty;
        public string? Icon { get; set; }
        public bool Separator { get; set; }
        public string? Text { get; set; }
        public string? Url { get; set; }
        public GridViewDefinition? ViewDefinition { get; set; }
    }
}
