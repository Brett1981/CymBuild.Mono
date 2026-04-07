using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.Components.Shared.Controls;
using Concursus.PWA.Classes;
using Microsoft.AspNetCore.Components;
using Microsoft.IdentityModel.Tokens;
using Microsoft.JSInterop;
using System.Dynamic;
using System.Text.Json;
using Telerik.Blazor.Components;
using Telerik.DataSource;
using static Concursus.Components.Shared.Controls.MessageDisplay;
using static Concursus.PWA.Shared.DynamicGrid;
using JsonSerializer = System.Text.Json.JsonSerializer;

namespace Concursus.PWA.Shared;

public partial class DynamicBatchGridView
{
  

    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = "";

    [Parameter] public EventCallback<InputUpdatedArgs> inputUpdated { get; set; }
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    // [Parameter] public EventCallback<Exception> OnError { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public DynamicGrid.DrawerItem SelectedItem { get; set; } = new();
    [Parameter]
    public EventCallback<DrawerItem> SelectedItemChanged { get; set; }
    public List<GridViewActions> GridViewActions { get; set; }

    [Parameter]
    public GridViewDefinition? ViewDefinition
    {
        get => _viewDefinition;
        set
        {
            _viewDefinition = value;
            if (GridRef is not null) RefreshMe().ConfigureAwait(true);
        }
    }

    //CBLD-260
    // Parameters for batch processing
    [Parameter] public bool IsBulkProcessing { get; set; }
    [Parameter] public EventCallback<IEnumerable<ExpandoObject>> OnSelectedItemsChanged { get; set; }
    [Parameter] public IEnumerable<ExpandoObject> Items { get; set; } = new List<ExpandoObject>();

    private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();
    private Type? _detailPageType;
    private MessageDisplay _messageDisplay = new();
    private List<string> _operationsWithMultipleStateChanged = new List<string>() {
        "FilterDescriptors",
        "GroupDescriptors",
        "SearchFilter"
    };

    private GridViewDefinition? _viewDefinition;
    // Ensure this is unique for each modal instance
    private string modalId = Guid.Empty.ToString();

    public bool HasChanges { get; private set; } = false;
    protected string ErrorMessage { get; set; } = "";
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";
    private int DebounceDelay { get; set; } = 100;
    private bool DoubleStateChanged { get; set; }
    private List<GridColumn>? GridColumns { get; set; }
    private TelerikGrid<ExpandoObject>? GridRef { get; set; }
    private IEnumerable<ExpandoObject> SelectedItems { get; set; } = new List<ExpandoObject>();

    private string GridStateChangedProperty { get; set; } = string.Empty;
    private string GridStateChangedPropertyClass { get; set; } = string.Empty;
    private string GridStateString { get; set; } = string.Empty;
    private TelerikWindow? ModalWindow { get; set; }
    private int OnStateChangedCount { get; set; }
    private string Placeholder { get; set; } = "Search...";

    private int? SearchBoxWidth { get; set; } = 200;
    private bool WindowIsClosable { get; set; } = true;
    private bool WindowIsVisible { get; set; }
    private string? WindowTitle { get; set; }
    private List<ExpandoObject> gridData = new List<ExpandoObject>();

    //START: CBLD-265 - Multi select.
    public BatchButtonMenu _buttonMenuRef { get; set; }
    protected FormHelper? formHelper;




    private bool reReadData { get; set; } = false;
    private string currentGridCode { get; set; } = "";




    //CBLD-260
    public IEnumerable<ExpandoObject> GetSelectionForBatch()
    {
        return SelectedItems ?? new List<ExpandoObject>(); 
    }

    private async Task SelectedItemsChanged(IEnumerable<ExpandoObject> selection)
    {
        SelectedItems = selection;
        await OnSelectedItemsChanged.InvokeAsync(selection);
    }
    private async Task ApplyChanges()
    {
        if (!SelectedItems.Any())
        {
            // Show error message if no items are selected
            var ex = new Exception("No items selected for bulk update.");
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Warning);
            OnError(ex);

            return;
        }

        // Logic to apply changes on selected items
        foreach (var item in SelectedItems)
        {
            // Use FormHelper or another helper to apply bulk changes if needed
            // Example:
            // await formHelper.UpdateItemAsync(item);
        }

        // Close modal or proceed to the next step
    }

    private void CancelBulkEdit()
    {
        // Logic to cancel bulk edit mode
        IsBulkProcessing = false;
        SelectedItems = new List<ExpandoObject>();
    }

    //CBLD-265: Ensures the grid data is reloaded with updated data after an invoice is created.
    private async Task reloadGridData()
    {
        SelectedItems = null;
        await RefreshMe();
    }

    /*
     * Re-sorts the grid after a row item has been selected by pushing them to the top of griData.
     * **/
    private async void SortGridAfterSelection()
    {
        gridData = gridData.OrderByDescending(item => SelectedItems.Contains(item)).ToList();
        GridRef.Rebind();
    }

    //CBLD-265
    public async void PerformAction(GridActionMenuItem _item)
    {
        try
        {

            if (SelectedItems == null)
                throw new Exception("No item has been selected.");

            string action = _item.Text;
            string statement = _item.Query;
            FormHelper formHelper = _item.FormHelper;


            foreach (var item in SelectedItems)
            {
                //Transform into IDictionary so that we can read the values.
                var expandoDict = item as IDictionary<string, object>;

                if (expandoDict != null)
                {
                    foreach (var kvp in expandoDict)
                    {
                        if (kvp.Key == "Guid" && kvp.Value != "")
                        {
                            //We only need the Guids - add them to the list. We will pass this variable.
                            var resp = await formHelper.GridMenuItemPostAsync(statement, kvp.Value.ToString());

                            if (resp.ErrorReturned != "")
                                throw new Exception(resp.ErrorReturned);
                        }
                    }
                }
            }

            var infoMessage = PWAFunctions.GetMessageDisplayFromGridViewAction(_item, new Exception(), ShowMessageType.Success);
            OnError(infoMessage);

            await reloadGridData();

        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            OnError(ex);
        }

    }


    private void AddProperty(ExpandoObject expando, string propertyName, object propertyValue)
    {
        try
        {
            var expandoDict = expando as IDictionary<string, object>;
            if (expandoDict.ContainsKey(propertyName))
                expandoDict[propertyName] = propertyValue;
            else
                expandoDict.Add(propertyName, propertyValue);
        }
        catch (Exception ex)
        {
            OnError(ex);
        }
    }
    public RenderFragment<object> GetColumnTemplate(string propName)
    {
        try
        {
            RenderFragment ColumnTemplate(object context) =>
                builder =>
                {
                    if (context is not ExpandoObject expandoObject) return;
                    var dictionary = expandoObject as IDictionary<string, object>;

                    if (dictionary.TryGetValue(propName, out var propValue))
                    {
                        //return the value of the property which will be rendered in the grid inside the <div> element
                        builder.AddContent(0, propValue);
                    }
                };
            return ColumnTemplate;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/GetColumnTemplate()");
            OnError(ex);
        }

        return null;
    }

    public async void OnError(Exception error)
    {
        if (string.IsNullOrEmpty(error.Message)) return;

        ErrorMessage = error.Message;
        PageMethod = error.Data.Contains("PageMethod") ? error.Data["PageMethod"].ToString() : "Not Set";

        if (error.Data.Contains("MessageType"))
            MessageType = (MessageDisplay.ShowMessageType)(error.Data["MessageType"] ?? MessageDisplay.ShowMessageType.Information);
        else
            MessageType = MessageDisplay.ShowMessageType.Error;

        _messageDisplay.ShowError(true);
        StateHasChanged();
    }

    public async Task RefreshMe()
    {
        try
        {
            var state = await CalcGridStateAsync();
            if (GridRef != null)
                await GridRef.SetStateAsync(state);

            await RebindGrid();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/RefreshMe()");
            OnError(ex);
        }
    }

    protected async Task AddNew()
    {
        try
        {
            if (ViewDefinition != null) // Check for null
            {
                if (ViewDefinition == null) return; // Check for null
                //Below is the code to get the ParentDataObjectReference and make sure it is set with the latest Modal windows saved details
                var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, ParentGuid, ViewDefinition.EntityTypeGuid);
                if (ViewDefinition.IsDetailWindowed)
                {
                    if (string.IsNullOrEmpty(ViewDefinition.DetailPageUri))
                    {
                        var ex = new Exception("DetailPageUri is not set in the ViewDefinition");
                        ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                        ex.Data.Add("PageMethod", "DynamicGridView/AddNew()");
                        OnError(ex);
                        return;
                    }
                    //Get new ModalId, add it to Parameter and register it
                    modalId = Guid.NewGuid().ToString();
                    _detailPageParameters.Clear();
                    _detailPageParameters.Add("EntityTypeGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
                    _detailPageParameters.Add("Windowed", true);
                    _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
                    _detailPageParameters.Add("RecordGuid", Guid.Empty.ToString());
                    _detailPageParameters.Add("GridUpdated", EventCallback.Factory.Create(this, GridUpdated));
                    _detailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
                    _detailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                    _detailPageParameters.Add("ModalId", modalId);
                    _detailPageParameters.Add("IsDetailWindowed", true);

                    modalService.RegisterModal(modalId, parentDataObjectReference);

                    WindowIsVisible = true;
                }
                else
                {
                    if (ViewDefinition.DetailPageUri == "DynamicEdit")
                        NavManager.NavigateTo(ViewDefinition.DetailPageUri + "/" + PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString() + "/" +
                                              parentDataObjectReference.DataObjectGuid + "/" + serializedParentDataObjectReference + "/" + System.Web.HttpUtility.UrlEncode(NavManager.Uri));
                    else
                        NavManager.NavigateTo(ViewDefinition.DetailPageUri + "/" + Guid.Empty.ToString() + "/" +
                                              serializedParentDataObjectReference + "/" + System.Web.HttpUtility.UrlEncode(NavManager.Uri));
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/AddNew()");
            OnError(ex);
        }
        StateHasChanged();
        _ = RefreshMe();
    }

    protected async Task CloseWindow()
    {
        try
        {
            object? value;
            if (_detailPageParameters.TryGetValue("ModalId", out value))
            {
                if (value is string modalId)
                {
                    modalService.UnregisterModal(modalId);
                }
            }

            WindowIsVisible = false;
            GridRef?.Rebind();
           
            await RefreshMe();

            StateHasChanged();
            await OnActionCompleted.InvokeAsync();  // Notify that an action has completed
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/CloseWindow()");
            OnError(ex);
        }
    }

    protected async Task GridUpdated()
    {
        try
        {
            var modal = modalService.RetrieveModalByEntityTypeGuid(ParentDataObjectReference.EntityTypeGuid);
            if (modal.HasValue)
            {
                _ = Task.Run(async () =>
                {
                    await ParentDataObjectReferenceChanged.InvokeAsync(modal.Value.DataObjectReference);
                });
            }

            GridRef?.Rebind();
            StateHasChanged();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/GridUpdated()");
            OnError(ex);
        }
    }

    protected override void OnAfterRender(bool firstRender)
    {
        if (!firstRender && ViewDefinition != null)
            GridViewActions = ViewDefinition.GridViewActions.ToList();


        base.OnAfterRender(firstRender);
    }

    public void HideUnselected(List<string> GuidsToHide)
    {
       
    }

    private async Task ReadItems(GridReadEventArgs args)
    {
        try
        {
            // Check if Items parameter has data
            if (Items != null && Items.Any())
            {
                // Use the provided Items directly for the grid data
                args.Data = Items;
                args.Total = Items.Count();
            }
            else
            {
                if (ViewDefinition != null)
                {
                    var gridDataListRequest = new GridDataListRequest
                    {
                        GridCode = GridCode,
                        GridViewCode = ViewDefinition.Code,
                        Page = args.Request.Page,
                        PageSize = args.Request.PageSize,
                        ParentGuid = ParentGuid
                    };

                    // Fetch data from the core client
                    var response = await coreClient.GridDataListAsync(gridDataListRequest);

                    // Populate gridData
                    var gridData = new List<ExpandoObject>();
                    foreach (var r in response.DataTable)
                    {
                        dynamic dataObj = new ExpandoObject();
                        foreach (var c in r.Columns)
                        {
                            var value = c.Value;
                            var name = c.Name;

                            if (DateTime.TryParse(value, out var dateTimeValue) && !name.ToLower().Contains("utc"))
                            {
                                dateTimeValue = DateTime.SpecifyKind(dateTimeValue, DateTimeKind.Utc);
                                value = dateTimeValue.ToUniversalTime().ToString();
                            }
                            AddProperty(dataObj, name, value);
                        }
                        gridData.Add(dataObj);
                    }

                    args.Data = gridData;
                    args.Total = response.TotalRows;
                }
            }
        }
        catch (Exception ex)
        {
            OnError(ex);
        }
    }



    private Task<GridState<ExpandoObject>> CalcGridStateAsync()
    {
        try
        {
            if (ViewDefinition == null) return Task.FromResult(new GridState<ExpandoObject>()); // Return a default state if ViewDefinition is null
            var defaultSortColumnName = ViewDefinition.DefaultSortColumnName;

            if (currentGridCode != ViewDefinition.Code)
                reReadData = true;

   
            var state = new GridState<ExpandoObject>
            {
                SortDescriptors = new List<SortDescriptor>
                {
                    new()
                    {
                        Member = defaultSortColumnName,
                        SortDirection = ViewDefinition.IsDefaultSortDescending ? ListSortDirection.Descending : ListSortDirection.Ascending
                    }
                },
                FilterDescriptors = new List<IFilterDescriptor>()
                {
                    new CompositeFilterDescriptor()
                    {
                        FilterDescriptors = new FilterDescriptorCollection()
                    }
                }
            };

            return Task.FromResult(state);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/CalcGridState()");
            OnError(ex);
        }
        return Task.FromResult(new GridState<ExpandoObject>());
    }




    private async Task OnGridStateChanged(GridStateEventArgs<ExpandoObject> args)
    {
        try
        {
            if (DoubleStateChanged)
            {
                DoubleStateChanged = false;
                await Task.Delay(1500);
                GridStateChangedPropertyClass = string.Empty;
            }

            ++OnStateChangedCount;

            GridStateChangedProperty = args.PropertyName;

            // serialize the GridState and highlight the changed property
            GridStateString = JsonSerializer.Serialize(args.GridState, new JsonSerializerOptions() { WriteIndented = true })
                .Replace($"\"{GridStateChangedProperty}\"", $"\"<strong class='latest-changed-property'>{GridStateChangedProperty}</strong>\"");

            // highlight first GridStateChangedProperty during filtering,
            // grouping and search
            if (_operationsWithMultipleStateChanged.Contains(GridStateChangedProperty))
            {
                DoubleStateChanged = true;
                GridStateChangedPropertyClass = "first-of-two";
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/OnGridStateChanged()");
            OnError(ex);
        }
    }




    private async Task OnStateInitHandler(GridStateEventArgs<ExpandoObject> args)
    {
        try
        {
            var state = await CalcGridStateAsync();
            if (ViewDefinition is not null)
            {
                state.SortDescriptors.Clear();
                state.SortDescriptors.Add(new SortDescriptor
                {
                    Member = ViewDefinition.DefaultSortColumnName,
                    SortDirection = ViewDefinition.IsDefaultSortDescending
                        ? ListSortDirection.Descending
                        : ListSortDirection.Ascending
                });
            }

            args.GridState = state;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/OnStateInitHandler()");
            OnError(ex);
        }
    }

    private async Task RebindGrid()
    {
        try
        {
            GridRef?.Rebind();
            //StateHasChanged();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/RebindGrid()");
            OnError(ex);
        }
    }

    private void ScrollToTop()
    {
        // Scroll to the top of the page
        JsRuntime.InvokeVoidAsync("window.scrollTo", 0, 0);
    }



    private void WindowVisibleChangedHandler(bool currVisible)
    {
        if (WindowIsClosable)
            WindowIsVisible = currVisible; // if you don't do this, the window won't close because of the user action
        else
            Console.WriteLine("The user tried to close the window but the code didn't let them");
    }
}