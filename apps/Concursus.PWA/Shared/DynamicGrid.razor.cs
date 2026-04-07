using Concursus.API.Client.Models;
using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Telerik.Blazor.Components;
using static Concursus.API.Core.Core;

namespace Concursus.PWA.Shared;

public partial class DynamicGrid
{
    public List<DrawerItem> Data { get; set; } = new();

    public dynamic Dgv { get; set; }
    public TelerikDrawer<DrawerItem>? Drawer { get; set; }
    [Parameter] public Dictionary<string, Any> TransientVirtualProperties { get; set; } = new();
    [Parameter] public string? DisabledMessage { get; set; }
    [Parameter] public string? DrawerGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public bool FullGrid { get; set; }

    [Parameter] public string GridCode { get; set; } = "";
    [Parameter] public bool IsLoading { get; set; }
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    [Parameter] public EventCallback<Exception> OnError { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public EventCallback<string> ParentGuidChanged { get; set; }

    [Parameter] public int ParentRowStatus { get; set; } = -1;
    [Parameter] public bool DoubleClickDisabled { get; set; } = false;

    [Parameter] public bool Disabled { get; set; } = false;

    [Parameter] public EventCallback ResyncDataObject { get; set; }

    public DrawerItem selectedItem { get; set; } = new();

    // [Parameter] public EventCallback<DrawerItem> SelectedItemChanged { get; set; }
    private string? ErrorMessage { get; set; }

    private string? GridName { get; set; }

    public class GridDrawerSessionData
    {
        public string Key { get; set; }
        public string Value { get; set; }
    }


    private GridViewDefinition? BatchedTransactionsGvd { get; set; }

    public async void SelectedItemChangedHandler(DrawerItem item)
    {
        selectedItem = item;

        //Only save the last visited drawer when working with a full grid.
        if (FullGrid)
        {
            //string page = NavManager.Uri;
            string page = "Drawer";
            string gridViewCode = item.ViewDefinition.Code;

            //CBLD-12: Save the drawer code in the session.
            if (page != "" && gridViewCode != "")
            {
                SessionStorageAccessor.SetValueAsync<string>(page, gridViewCode);
                InteractionTracker.Log(NavManager.Uri ?? "Drawer Selection", $"User changed Grid Draw - '{gridViewCode}'");
            }
        }
    }

    public async Task ToggleDrawer()
    {
        if (Drawer != null) await Drawer.ToggleAsync();

        InteractionTracker.Log(NavManager.Uri ?? "DynamicGrid.ToggleDrawer", "Toggled the drawer in the DynamicGrid component.");
    }

    protected override Task OnAfterRenderAsync(bool firstRender)
    {
        return base.OnAfterRenderAsync(firstRender);
    }

    protected override async Task OnInitializedAsync()
    {
        try
        {
            IsLoading = true;

            if (GridCode != "")
            {
                var gridDefinitionListReply = await coreClient.GridDefinitionListAsync(new GridDefinitionListRequest()
                {
                    Code = GridCode,
                    ForUi = true
                });

                var gd = gridDefinitionListReply.Grids[0];
                GridName = gd.Name;

                if (DeviceInfoService.IsMobile)
                {
                    foreach (var gvd in gd.Views.OrderBy(m => m.DisplayOrder).Where(m => m.RowVersion != "254"))
                    {
                        if (gvd?.ShowOnMobile == true)
                        {
                            Data.Add(new DrawerItem()
                            {
                                Text = gvd.Name,
                                Icon = string.IsNullOrEmpty(gvd.DrawIconCss) ? "bi bi-grid-3x3-gap" : gvd.DrawIconCss,
                                ViewDefinition = gvd
                            });
                        }
                    }

                    var isSelectedItemInSession = await SessionStorageAccessor.GetValueAsync<string>("Drawer");
                    if (isSelectedItemInSession == null)
                    {
                        selectedItem = Data.FirstOrDefault(x => x.ViewDefinition?.Guid == DrawerGuid) ?? Data.First();
                    }
                    else
                    {
                        selectedItem = Data.FirstOrDefault(x => x.ViewDefinition?.Code == isSelectedItemInSession) ?? Data.First();
                    }
                }
                else
                {
                    foreach (var gvd in gd.Views.OrderBy(m => m.DisplayOrder).Where(m => m.RowVersion != "254"))
                    {
                        Data.Add(new DrawerItem()
                        {
                            Text = gvd.Name,
                            Icon = string.IsNullOrEmpty(gvd.DrawIconCss) ? "bi bi-grid-3x3-gap" : gvd.DrawIconCss,
                            ViewDefinition = gvd
                        });
                    }

                    var isSelectedItemInSession = await SessionStorageAccessor.GetValueAsync<string>("Drawer");
                    if (isSelectedItemInSession == null)
                    {
                        selectedItem = Data.FirstOrDefault(x => x.ViewDefinition?.Guid == DrawerGuid) ?? Data.First();
                    }
                    else
                    {
                        selectedItem = Data.FirstOrDefault(x => x.ViewDefinition?.Code == isSelectedItemInSession) ?? Data.First();
                    }

                    if (selectedItem.ViewDefinition.Code == "ALLTRANSACTIONS")
                    {
                        var BatchedTransactionGridViewReply = await coreClient.GridDefinitionListAsync(new GridDefinitionListRequest()
                        {
                            Code = "BATCHEDTRANSACTIONS",
                            ForUi = true
                        });

                        var BatchedTransactionGridViewReplyGrid = BatchedTransactionGridViewReply.Grids[0];

                        BatchedTransactionsGvd = BatchedTransactionGridViewReplyGrid.Views
                            .Where(x => x.Code == "BATCHEDTRANSACTIONS")
                            .FirstOrDefault();

                        Console.WriteLine(BatchedTransactionsGvd);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while initializing the DynamicGrid component.");
            ex.Data.Add("PageMethod", "DynamicGrid/OnInitializedAsync()");
            _ = OnError.InvokeAsync(ex);
        }
        finally
        {
            if (ParentRowStatus != 999)
            {
                IsLoading = false;
            }
        }

        await base.OnInitializedAsync();
    }

    private void HandleActionCompleted()
    {
        // Once completed, trigger the callback
        _ = OnActionCompleted.InvokeAsync();
    }

    //private async Task SelectedItemChangedHandler(DrawerItem item)
    //{
    //    selectedItem = item;

    // if (selectedItem.ViewDefinition.GridViewTypeId == 1) { Dgv = new DynamicGridView(); } else {
    // Dgv = new DynamicBatchGridView(); }

    // refreshService.RequestGridRefresh(selectedItem.Text ?? ""); // if you don't update the
    // view-model, the event will effectively be cancelled

    //    Console.WriteLine($"The user selected {item.Text}");
    //    // Drawer?.SelectedItemChanged.InvokeAsync(selectedItem);
    //}

    public void RefreshGrid()
    {
        Dgv.RefreshGrid();
    }

    public class DrawerItem
    {
        public string DrawIconCss { get; set; }
        public string? Icon { get; set; }
        public bool Separator { get; set; }
        public string? Text { get; set; }
        public string? Url { get; set; }
        public GridViewDefinition? ViewDefinition { get; set; }
    }
}