using Concursus.API.Client;
using Concursus.API.Core;
using Concursus.PWA.Classes;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using System.Dynamic;
using Telerik.Blazor.Components;
using static Concursus.PWA.Shared.MessageDisplay;


namespace Concursus.PWA.Shared;

public partial class BatchButtonMenu
{
    protected FormHelper? formHelper;

    private IDictionary<string, object> DetailPageParameters = new Dictionary<string, object>();

    public GridActionMenuItem? ClickedItem { get; set; }
    public List<GridActionMenuItem>? MenuItems { get; set; }
    public TelerikWindow ModalWindow { get; set; }

    [Parameter] public EventCallback<Exception> OnError { get; set; }

    private GridViewDefinition _value;

    [Parameter] public GridViewDefinition GridRef { get; set; }

    [Parameter] public TelerikGrid<ExpandoObject>? GridReference { get; set; }
    [Parameter] public EventCallback OnRefreshRequested { get; set; }




    [Parameter] public EventCallback<GridViewDefinition> GridRefChanged { get; set; }
    [Parameter] public EventCallback<GridActionMenuItem> PerformGridAction { get; set; }
    [Parameter] public string EntityTypeGuid { get; set; } = Guid.Empty.ToString();

    [Parameter] public IEnumerable<ExpandoObject> SelectedItems { get; set; }
    [Parameter] public EventCallback<IEnumerable<ExpandoObject>> SelectedItemsChanged { get; set; }


    private string? GridCodeSelection { get; set; }
    private string HeaderCssIcon { get; set; } = "";
    private string HeaderText { get; set; } = "";
    private string? LoadPageUrl { get; set; }
    private bool ModalWindowIsVisible { get; set; } = false;
    private bool windowIsClosable { get; set; } = true;
    private string? WindowTitle { get; set; }

    protected void CloseWindowCross()
    {
        ModalWindowIsVisible = false;
    }

    //CBLD-265
    protected async Task<Task> OnClickHandler(GridActionMenuItem item)
    {
        try
        {
            formHelper = new FormHelper(coreClient, sageIntegrationService, EntityTypeGuid, userService);

            if (item.Text == "Create Invoice")
            {
                try
                {
                    //Display information such as "Preparing to...".
                    var infoMessage = PWAFunctions.GetMessageDisplayFromGridViewAction(item, new Exception(), ShowMessageType.Information);
                    await OnError.InvokeAsync(infoMessage);

                    item.FormHelper = formHelper;
                    await PerformGridAction.InvokeAsync(item);
                }
                catch (Exception ex)
                {
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "An error occurred while trying to create an invoice.");
                    ex.Data.Add("PageMethod", "BatchButtonMenu/OnClickHandler(Create Invoice)");
                    _ = OnError.InvokeAsync(ex);
                }
            }
            else if (item.Text == "Invoice Request → Create Invoice (Batch)")
            {
                var infoMessage = PWAFunctions.GetMessageDisplayFromGridViewAction(item, new Exception(), ShowMessageType.Information);
                await OnError.InvokeAsync(infoMessage);

                item.FormHelper = formHelper;
                await PerformGridAction.InvokeAsync(item);
            }
            else if(item.Text == "Batch Delete")
            {
                var infoMessage = PWAFunctions.GetMessageDisplayFromGridViewAction(item, new Exception(), ShowMessageType.Information);
                await OnError.InvokeAsync(infoMessage);

                item.FormHelper = formHelper;
                await PerformGridAction.InvokeAsync(item);
            }
            else if (item.Text == "Approve Invoice(s)")
            {
                bool isConfirmed = await JSRuntime.InvokeAsync<bool>("confirm", "Are you sure? This will prevent the transaction from being modified.");
                if (isConfirmed)
                {
                    var infoMessage = PWAFunctions.GetMessageDisplayFromGridViewAction(item, new Exception(), ShowMessageType.Information);
                    await OnError.InvokeAsync(infoMessage);

                    item.FormHelper = formHelper;
                    await PerformGridAction.InvokeAsync(item);
                }
                   
            }
            else if (item.Text == "Quote Assignment")
            {

                if (SelectedItems == null || !SelectedItems.Any())
                {
                    await JSRuntime.InvokeVoidAsync("alert", "No records selected for update!");


                }
                else
                {
                    DetailPageParameters.Add("OnRefreshRequested", OnRefreshRequested);
                    DetailPageParameters.Add("SelectedItems", SelectedItems);
                    ModalWindowIsVisible = true;
                }

            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to create an invoice.");
            ex.Data.Add("PageMethod", "BatchButtonMenu/OnClickHandler()");
            _ = OnError.InvokeAsync(ex);
            throw;
        }

        return Task.CompletedTask;
    }

    /**
      * CBLD-265: Ensures that the actions for the action button are always the right ones.
      * **/

    protected override void OnParametersSet()
    {
        reloadButton();

        base.OnParametersSet();
    }

    public async void reloadButton()
    {
        try
        {
            MenuItems = new List<GridActionMenuItem>
                {
                    new()
                    {
                        Text = "Actions",
                        Items = new List<GridActionMenuItem>()
                    }
                };

            if (MenuItems != null && MenuItems[0].Items == null) MenuItems[0].Items = new List<GridActionMenuItem>();
            {
                if (GridRef != null && GridRef?.GridViewActions?.Count != 0)
                    //Loop through dataObject.ActionMenuItems adding a new MenuItem
                    foreach (var item in GridRef?.GridViewActions?.OrderBy(o => o.Title))
                    {
                        string icon = "";
                        if (item.Title == "Create Invoice")
                            icon = "bi bi-currency-dollar";
                        else if (item.Title == "Invoice Request → Create Invoice (Batch)")
                            icon = "bi bi-receipt";
                        else if (item.Title == "Batch Delete")
                            icon = "bi bi-trash";
                        else if (item.Title == "Approve Invoice(s)")
                            icon = "bi bi-link-45deg";

                        MenuItems?[0].Items.Add(new GridActionMenuItem()
                            {
                                Text = item.Title,
                                Query = item.Statement,
                                Icon = icon
                            });


                    }

                if(GridRef?.Code == "AUTHASSIGN")
                    MenuItems?[0].Items.Add(new GridActionMenuItem()
                    {
                        Text = "Quote Assignment",
                        Icon = "bi bi-person-check",
                        Query = ""
                    });
            }

            StateHasChanged();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to reload the button.");
            ex.Data.Add("PageMethod", "BatchButtonMenu/OnInitialized()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    private string GetParentGuid()
    {
        try
        {
            // Retrieve the value associated with the "RecordGuid (ParentDataObjectReference)" key
            // when loading a DynamicGrid
            if (DetailPageParameters.TryGetValue("RecordGuid", out var parentGuid))
                return parentGuid?.ToString();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to get the parent guid.");
            ex.Data.Add("PageMethod", "ButtonMenu/GetParentGuid()");
            _ = OnError.InvokeAsync(ex);
        }

        // If the key is not found, you can return a default value or handle it as needed
        return Guid.Empty.ToString();
    }
}