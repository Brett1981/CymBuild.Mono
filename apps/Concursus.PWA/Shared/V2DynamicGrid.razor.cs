using Concursus.API.Client.Models;
using Concursus.API.Core;
using Microsoft.AspNetCore.Components;

namespace Concursus.PWA.Shared;

/// <summary>
/// V2 replacement for DynamicGrid:
/// - Removes Telerik Drawer/Button/Loader UI (Bootstrap/native only)
/// - Preserves all existing DynamicGrid behaviour and public parameters
/// - Still hosts existing GridView components for now (until V2DynamicGridView is implemented)
/// </summary>
public partial class V2DynamicGrid
{
    public List<DrawerItem> Data { get; set; } = new();

    // Keep same "dynamic Dgv" pattern so callers can still call RefreshGrid()
    public dynamic? Dgv { get; set; }

    [Parameter] public string? DrawerGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public bool FullGrid { get; set; }

    [Parameter] public string GridCode { get; set; } = string.Empty;
    [Parameter] public bool IsLoading { get; set; }
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    [Parameter] public EventCallback<Exception> OnError { get; set; }

    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }

    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public int ParentRowStatus { get; set; } = -1;
    [Parameter] public bool DoubleClickDisabled { get; set; } = false;
    [Parameter] public bool Disabled { get; set; } = false;

    [Parameter] public EventCallback ResyncDataObject { get; set; }

    public DrawerItem selectedItem { get; set; } = new();

    private string? GridName { get; set; }

    // Bootstrap drawer state
    private bool IsDrawerOpen { get; set; }

    public async Task ToggleDrawer()
    {
        IsDrawerOpen = !IsDrawerOpen;
        InteractionTracker.Log(NavManager.Uri ?? "V2DynamicGrid.ToggleDrawer", $"Drawer toggled: {IsDrawerOpen}");
        await InvokeAsync(StateHasChanged);
    }

    public async Task SelectedItemChangedHandler(DrawerItem item)
    {
        selectedItem = item;

        // Only save the last visited drawer when working with a full grid (parity)
        if (FullGrid)
        {
            var page = "Drawer";
            var gridViewCode = item.ViewDefinition?.Code ?? string.Empty;

            if (!string.IsNullOrWhiteSpace(page) && !string.IsNullOrWhiteSpace(gridViewCode))
            {
                await SessionStorageAccessor.SetValueAsync(page, gridViewCode);
                InteractionTracker.Log(NavManager.Uri ?? "Drawer Selection", $"User changed Grid Draw - '{gridViewCode}'");
            }
        }

        // Auto close drawer after selecting
        IsDrawerOpen = false;
        await InvokeAsync(StateHasChanged);
    }

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            if (ParentRowStatus != 999)
            {
                IsLoading = false;
            }
        }

        await base.OnAfterRenderAsync(firstRender);
    }

    protected override async Task OnInitializedAsync()
    {
        try
        {
            IsLoading = true;

            if (!string.IsNullOrWhiteSpace(GridCode))
            {
                var gridDefinitionListReply = await coreClient.GridDefinitionListAsync(new GridDefinitionListRequest
                {
                    Code = GridCode,
                    ForUi = true
                });

                var gd = gridDefinitionListReply.Grids[0];
                GridName = gd.Name;

                // Build drawer items, respecting mobile visibility and excluding RowVersion "254"
                var views = gd.Views
                    .OrderBy(m => m.DisplayOrder)
                    .Where(m => m.RowVersion != "254");

                foreach (var gvd in views)
                {
                    if (DeviceInfoService.IsMobile && gvd.ShowOnMobile != true)
                        continue;

                    Data.Add(new DrawerItem
                    {
                        Text = gvd.Name,
                        Icon = string.IsNullOrEmpty(gvd.DrawIconCss) ? "bi bi-grid-3x3-gap" : gvd.DrawIconCss,
                        ViewDefinition = gvd
                    });
                }

                // Restore last visited drawer from session
                var fromSession = await SessionStorageAccessor.GetValueAsync<string>("Drawer");

                if (string.IsNullOrWhiteSpace(fromSession))
                {
                    selectedItem = Data.FirstOrDefault(x => x.ViewDefinition?.Guid == DrawerGuid) ?? Data.FirstOrDefault() ?? new DrawerItem();
                }
                else
                {
                    selectedItem = Data.FirstOrDefault(x => x.ViewDefinition?.Code == fromSession) ?? Data.FirstOrDefault() ?? new DrawerItem();
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "An error occurred while initializing the V2DynamicGrid component.";
            ex.Data["PageMethod"] = "V2DynamicGrid/OnInitializedAsync()";
            _ = OnError.InvokeAsync(ex);
        }
        finally
        {
            IsLoading = false;
        }

        await base.OnInitializedAsync();
    }

    private void HandleActionCompleted()
    {
        _ = OnActionCompleted.InvokeAsync();
    }

    public async Task RefreshGrid(bool resetToFirstPage = false)
    {
        if (Dgv != null)
            await Dgv.RefreshGrid(resetToFirstPage);
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
