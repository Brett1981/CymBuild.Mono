using Concursus.API.Core;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using DocumentFormat.OpenXml.Drawing.Diagrams;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using System.Dynamic;
using System.Text.Json;
using Telerik.Blazor.Components;
using Telerik.DataSource;
using Telerik.DataSource.Extensions;

namespace Concursus.PWA.Shared;

public partial class MultiColumnDynamicGridView
{
    #region Privately Inherited Variables

    private TelerikGrid<ExpandoObject>? GridRef { get; set; }
    private IEnumerable<ExpandoObject>? CurrentGridItems { get; set; } // Exposes the grid data
    private bool BatchGridVisible { get; set; } = false;
    private TelerikWindow? ModalWindow { get; set; }
    private bool WindowIsVisible { get; set; }
    private bool WindowIsClosable { get; set; } = true;
    private string? WindowTitle { get; set; }
    private MessageDisplay _messageDisplay = new();
    private bool DoubleStateChanged { get; set; }
    private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();
    private string modalId = Guid.Empty.ToString();
    private string GridStateChangedPropertyClass { get; set; } = string.Empty;
    private string GridStateChangedProperty { get; set; } = string.Empty;
    private int OnStateChangedCount { get; set; }
    private string GridStateString { get; set; } = string.Empty;

    private List<string> _operationsWithMultipleStateChanged = new List<string>() {
        "FilterDescriptors",
        "GroupDescriptors",
        "SearchFilter"
    };

    #endregion Privately Inherited Variables

    #region Privately Inherited Functions

    private void OpenDynamicBatchGrid()
    {
        _ = GetScrollBarPos();
        BatchGridVisible = true;
    }

    private async Task GetScrollBarPos()
    {
        await JSRuntime.InvokeVoidAsync("GetScrollBarPos");
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

    private async void CloseBatchGridModal()
    {
        BatchGridVisible = false;
        await GridUpdated();
        StateHasChanged();

        _ = SetScrollBarPos();
    }

    private async Task SetScrollBarPos()
    {
        try
        {
            await JSRuntime.InvokeVoidAsync("SetScrollBarPos");
            await Task.Delay(100);
        }
        catch (Exception ex)
        {
            // OE - CBLD- Added catch so that it does throw an error message.
            Console.WriteLine(ex.Message);
        }
    }

    private async void OnRowRenderHandler(GridRowRenderEventArgs args)
    {
        // apply ellipsis to specific columns using OnRowRender
        args.Class = "custom-ellipsis";
    }

    private async Task EnsureCorrectParentGuid()
    {
        if (ParentGuid == Guid.Empty.ToString() && ViewDefinition.IsDetailWindowed)
        {
            var numberOfModals = modalService.GetOpenModals().Count();

            //OE: CBLD-467.
            if (numberOfModals == 0)
            {
                ParentGuid = Guid.NewGuid().ToString();
            }
            else
            {
                var modal = modalService.GetLatestModal();
                if (modal != null)
                {
                    ParentDataObjectReference.DataObjectGuid = modal.Value.DataObjectReference.DataObjectGuid;
                    ParentGuid = ParentDataObjectReference.DataObjectGuid.ToString();

                    await ParentGuidChanged.InvokeAsync(ParentGuid);
                }
            }
        }
    }

    private object FormatGridColumnValue(string columnName, string value)
    {
        // Try numeric parsing first
        if (int.TryParse(value, out var intValue)) return intValue;

        if (decimal.TryParse(value, out var decimalValue))
            return decimalValue.ToString("F2"); // Standard 2dp

        if (bool.TryParse(value, out var boolValue))
            return boolValue ? "Yes" : "No";

        if (Guid.TryParse(value, out var guidValue))
            return guidValue.ToString();

        // Handle DateTime with standardized logic
        if (DateTime.TryParse(value, out var dateTimeValue))
        {
            // Use UiFormattingHelper to normalize and format
            var localDateTime = UiFormattingHelper.NormalizeToLocal(dateTimeValue);

            // Smart formatting based on column name
            bool isDateOnly = columnName.ToLower().EndsWith("date") && !columnName.ToLower().Contains("time");

            return UiFormattingHelper.FormatDateForUI(localDateTime, isDateOnly);
        }

        // Default to raw string
        return value;
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

                //Check if there are gridSettings already present in the session.
                var isGradeStateSaved = await LocalStorageAccessor.GetValueAsync<string>("gridState");

                //cBLD-106: ensuring the filter and sort settings are rememebered.
                if (isGradeStateSaved != null && FullGrid) //Only on full grids.
                {
                    FilterAndSortSetting gridSetting = JsonSerializer.Deserialize<FilterAndSortSetting>(isGradeStateSaved);
                    //CBLD-532: Get the page number from the session - if there is one.
                    var savedPageNumber = await LocalStorageAccessor.GetValueAsync<string>("currentPageNumber");

                    //Only apply the settings when viewng the correct grid.
                    if (gridSetting.code == ViewDefinition.Code && gridSetting.gridCode == GridCode)
                    {
                        state.FilterDescriptors = gridSetting.filterDescriptor;
                        state.SortDescriptors = gridSetting.sortDescriptor;

                        //Extract the page number - if there is one.
                        //We are returning a string, we need to convert to int.
                        int pageNum;
                        if (savedPageNumber != null)
                        {
                            //Returns true if converted succesfully.
                            if (Int32.TryParse(savedPageNumber, out pageNum))
                            {
                                state.Page = pageNum;
                            }
                        }
                    }
                    //else
                    //{
                    //    //We have visited a new grid, therefore we should delete the old configuration - if exitst.
                    //    SessionStorageAccessor.RemoveAsync("gridState");
                    //    //Remove page number, too.
                    //    SessionStorageAccessor.RemoveAsync("currentPageNumber");
                    //}
                }
            }

            args.GridState = state;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while initializing the grid state in the DynamicGridView.");
            ex.Data.Add("PageMethod", "MultiColumnDynamicGridView/OnStateInitHandler()");
            OnError(ex);
        }
    }

    protected async Task ReadItems(GridReadEventArgs args)
    {
        try
        {
            if (ViewDefinition == null) return;

            await EnsureCorrectParentGuid(); // Ensure Parent GUID is properly set before API calls

            var gridDataListRequest = new GridDataListRequest
            {
                GridCode = GridCode,
                GridViewCode = ViewDefinition.Code,
                Page = args.Request.Page,
                PageSize = args.Request.PageSize,
                ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString()
            };

            if (gridDataListRequest.ParentGuid == Guid.Empty.ToString() && !FullGrid) return;

            // Ensure we handle single `DataCompositeFilter` properly
            var compositeFilter = API.Client.TypeHelpers.GridDataCompositeFilterFromKendoFilterDescriptor(args.Request.Filters);
            if (compositeFilter != null)
            {
                gridDataListRequest.Filters.Add(compositeFilter); // Add single filter correctly
            }

            gridDataListRequest.Sort.AddRange(
                API.Client.TypeHelpers.GridDataSortFromKendoSortDescriptor(args.Request.Sorts));

            var gridDataListReply = await coreClient.GridDataListAsync(gridDataListRequest);
            var gridData = new List<ExpandoObject>();

            foreach (var r in gridDataListReply.DataTable)
            {
                dynamic dataObj = new ExpandoObject();
                var dictionary = dataObj as IDictionary<string, object>;

                foreach (var c in r.Columns)
                {
                    var name = c.Name;
                    var value = FormatGridColumnValue(name, c.Value);
                    dictionary[name] = value;
                }

                gridData.Add(dataObj);
            }

            args.Data = gridData;
            args.Total = (int)gridDataListReply.TotalRows;
            CurrentGridItems = gridData;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/ReadItems()");
            OnError(ex);

            //Reset the grid filters.
            MyWorkFilterSettings = null;
            SendFilterAndSortSettingsToBoard();
        }
    }

    private void OnRowDoubleClickHandler(GridRowClickEventArgs args)
    {
        try
        {
            var onRowDoubleClickHandler = !string.IsNullOrEmpty(ViewDefinition?.DetailPageUri) ? "@OnRowDoubleClickHandler" : null;
            if (onRowDoubleClickHandler == null) return;
            dynamic model = args.Item;
            //Do nothing if empty guid
            if (model.Guid == Guid.Empty.ToString()) return;

            if (ViewDefinition == null) return;

            string parentGuid = model.Guid;
            // CBLD - 462: SB - Check to see if the Entity Guid in the current
            // ParentDataOnjectReference is different than where its going
            var isParentDataObjectReferenceDifferent = ParentDataObjectReference.EntityTypeGuid.ToString() != ViewDefinition.EntityTypeGuid;

            //Below is the code to get the ParentDataObjectReference and make sure it is set with the latest Modal windows saved details
            var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, parentGuid, ViewDefinition.EntityTypeGuid);

            if (ViewDefinition.IsDetailWindowed)
            {
                _ = GetScrollBarPos();

                //Get new ModalId, add it to Parameter and register it
                modalId = Guid.NewGuid().ToString();
                _detailPageParameters.Clear();
                _detailPageParameters.Add("EntityTypeGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
                _detailPageParameters.Add("Windowed", true);
                _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
                _detailPageParameters.Add("GridUpdated", EventCallback.Factory.Create(this, GridUpdated));
                _detailPageParameters.Add("RecordGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(model.Guid).ToString());
                _detailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
                _detailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                _detailPageParameters.Add("ModalId", modalId);

                modalService.RegisterModal(modalId, parentDataObjectReference);
                WindowIsVisible = true;
            }
            else
            {
                //OE: Fix for CBLD-331
                string guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(model.Guid).ToString();
                string urlEncode = System.Web.HttpUtility.UrlEncode(NavManager.Uri);
                string sPDOR = serializedParentDataObjectReference;
                string uri = System.Web.HttpUtility.UrlEncode(NavManager.Uri);
                string url = ViewDefinition.DetailPageUri + "/" + guid + "/" + serializedParentDataObjectReference + "/" + uri;

                if (ViewDefinition.DetailPageUri == "DynamicEdit")
                    NavManager.NavigateTo(ViewDefinition.DetailPageUri + "/" + PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString() + "/" + parentDataObjectReference.DataObjectGuid + "/" +
                                          serializedParentDataObjectReference + "/" + System.Web.HttpUtility.UrlEncode(NavManager.Uri));
                else
                    //NavManager.NavigateTo(ViewDefinition.DetailPageUri + "/" + PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(model.Guid).ToString() + "/" +
                    //                      serializedParentDataObjectReference + "/" + System.Web.HttpUtility.UrlEncode(NavManager.Uri));
                    //SB: Fix for CBLD-331 removef the Force Load
                    if (isParentDataObjectReferenceDifferent)
                {
                    NavManager.NavigateTo(url, false);
                }
                else
                {
                    NavManager.NavigateTo(url, true);
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while handling the row double-click event in the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/OnRowDoubleClickHandler()");
            OnError(ex);
        }
    }

    private Task<GridState<ExpandoObject>> CalcGridStateAsync()
    {
        try
        {
            if (ViewDefinition == null) return Task.FromResult(new GridState<ExpandoObject>()); // Return a default state if ViewDefinition is null
            var defaultSortColumnName = ViewDefinition.DefaultSortColumnName;

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
            ex.Data.Add("AdditionalInfo", "An error occurred while calculating the grid state in the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/CalcGridState()");
            OnError(ex);
        }
        return Task.FromResult(new GridState<ExpandoObject>());
    }

    private async Task OnGridStateChanged(GridStateEventArgs<ExpandoObject> args)
    {
        try
        {
            //Handling for saving the grid filters.
            var gridState = new FilterAndSortSetting()
            {
                code = ViewDefinition.Code,
                gridCode = GridCode,
                filterDescriptor = args.GridState.FilterDescriptors,
                sortDescriptor = args.GridState.SortDescriptors
            };

            //Serialize the created object and then save it to the session.
            var serializedGridStateToSave = JsonSerializer.Serialize(gridState, new JsonSerializerOptions() { WriteIndented = true });
            LocalStorageAccessor.SetValueAsync("gridState", serializedGridStateToSave);

            //Send over to the board.
            //SendFilterAndSortSettingsToBoard();

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

            // highlight first GridStateChangedProperty during filtering, grouping and search
            if (_operationsWithMultipleStateChanged.Contains(GridStateChangedProperty))
            {
                DoubleStateChanged = true;
                GridStateChangedPropertyClass = "first-of-two";
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while handling the grid state change in the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/OnGridStateChanged()");
            OnError(ex);
        }
    }

    #endregion Privately Inherited Functions

    #region Privately Inherited Classes

    private class FilterAndSortSetting
    {
        public string code { get; set; }
        public ICollection<IFilterDescriptor> filterDescriptor { get; set; }
        public string gridCode { get; set; }
        public ICollection<SortDescriptor> sortDescriptor { get; set; }
        public int pageNumber { get; set; }
    }

    #endregion Privately Inherited Classes

    #region Parameters

    [Parameter] public List<string> TopColumnHeaders { get; set; } = new();
    [Parameter] public string CellColoursJSON { get; set; }

    //Callback to send data from the widget to the board.
    [Parameter] public EventCallback<string> SendJSONToWidgetCallback { get; set; }

    [Parameter] public EventCallback<string> SendFilterAndSortCallback { get; set; } //Sending the filter and sort for the grid.
    [Parameter] public string CSSFromDB { get; set; }
    [Parameter] public string MyWorkFiltersFromDB { get; set; }

    #endregion Parameters

    //Controls if the color picker palette is enabled.
    private bool EditCellsEnabled = false;

    private string EditCellsButtonText = "Edit";
    private string EditCellsButtonColor = "btn btn-primary";

    //We store all the formatting applied.
    private HashSet<CellColouring> CellColourings { get; set; } = new();

    //Set to true once the CSS has been fetched from the DB.
    private bool CSSLoadedFromDatabase { get; set; } = false;

    private bool MyWorkFiltersLoadedFromDB { get; set; } = false;

    private List<ContextMenuItem> MenuItems { get; set; }
    private bool ShowPaletteForHeader { get; set; } = false;
    private Dictionary<string, bool> AllHeaders { get; set; } = new();

    //THe filter applied to the grid -> to be saved as a JSON in the database.
    private string MyWorkGridFilterAsJSON { get; set; }

    private FilterAndSortSetting MyWorkFilterSettings { get; set; }

    public class CellColouring
    {
        public string ClassName { get; set; }
        public string Colour { get; set; }
    }

    public class ContextMenuItem
    {
        public string Text { get; set; }
    }

    #region FUNCTIONS

    /*
        Init. the context menu items (right-click on top-level headers).
     */

    protected override void OnInitialized()
    {
        MenuItems = new List<ContextMenuItem>()
        {
            new ContextMenuItem
            {
                Text = "Change Colour"
            }
        };

        base.OnInitialized();
    }

    /*
        Used mainly to grey out cells - if the returned value is "#808080",
        apply class to grey out the field.

        The actual value is changed inside the GetColumnTemplate function!
     */

    private void OnCellRenderHandler(GridCellRenderEventArgs args)
    {
        try
        {
            if (args.Value.ToString() == "#808080")
            {
                args.Class = "greyed-out-cell";
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while getting the column template for the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/OnCellRenderHandler()");
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
                    { //return the
                      //value of the property which will be rendered in the grid inside the<div>

                        if (propValue.ToString() == "#808080")
                            propValue = " ";

                        builder.AddContent(0, propValue);
                    }
                }; return ColumnTemplate;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while getting the column template for the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/GetColumnTemplate()");
            OnError(ex);
        }

        return null;
    }

    /*
        Describes what should happen when the user
        clicks "Change Colour" on a top-level header.
     */

    private async void ClickHandlerForColouring(ContextMenuItem itm, string Class)
    {
        if (itm.Text == "Change Colour")
        {
            ShowPaletteForHeader = true;
            //Ensures the palette is only shown for the right-clicked header.
            AllHeaders[Class] = true;
        }
    }

    private async void SetHeaderColour(object Colour, string ClassName)
    {
        try
        {
            //Close the palette once the colour has been set.
            ShowPaletteForHeader = false;
            AllHeaders[ClassName] = false;

            //Check if we already have a colour applied to the top-level header.
            var colouring = CellColourings.Where(x => x.ClassName == ClassName).FirstOrDefault();

            //Add new colour if haven't already assigned one for the given header.
            if (colouring is null)
            {
                CellColourings.Add(new CellColouring
                {
                    ClassName = ClassName,
                    Colour = (string)Colour
                });
            }
            //Otherwise, get the colouring and change the assigned hex colour.
            else
            {
                //Default colour for the headers - remove the styling from the database.
                if ((string)Colour == "#f8f9fa")
                    CellColourings.Remove(colouring);
                else
                    colouring.Colour = (string)Colour;
            }

            await SetHeaderColourJS(Colour.ToString(), ClassName);
            SendJSONToWidgetBoard();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while getting the column template for the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/SetHeaderColour()");
            OnError(ex);
        }
    }

    /*
        The JS part of applying the CSS for a coloured header.
     */

    [JSInvokable]
    private async Task SetHeaderColourJS(string colour, string className)
    {
        try
        {
            await JS.InvokeVoidAsync("applyCSSForHeader", className, colour);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while getting the column template for the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/GetColumnTemplate()");
            OnError(ex);
        }
    }

    /*
        Unused at the moment.
     */

    [Obsolete("Function is yet to be enabled - obsolete for now.")]
    private async void ToggleEditCells()
    {
        EditCellsEnabled = !EditCellsEnabled;

        if (!EditCellsEnabled)
        {
            EditCellsButtonText = "Edit";
            EditCellsButtonColor = "btn btn-primary";
        }
        else
        {
            EditCellsButtonText = "Done";
            EditCellsButtonColor = "btn btn-danger";
        }
    }

    /*
        Ensures the CSS is applied on render.
     */

    protected override Task OnAfterRenderAsync(bool firstRender)
    {
        try
        {
            if (!firstRender)
            {
                if (CellColourings.Any())
                    _ = Task.Run(async () => { await ApplyCSSColour(); });
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while getting the column template for the DynamicGridView.");
            ex.Data.Add("PageMethod", "OnAfterRenderAsync()");
            OnError(ex);
        }

        return base.OnAfterRenderAsync(firstRender);
    }

    /*
        Loads the stored CSS in the database into the Widget board.
     */

    protected override void OnParametersSet()
    {
        try
        {
            //Check if we have the CSS styling from the db first.
            if (CSSFromDB is not null && !CSSLoadedFromDatabase)
            {
                //Deserialise the JSON into a type of "CellColouring"
                var ExistingMyWorkStyle = System.Text.Json.JsonSerializer.Deserialize<List<CellColouring>>(CSSFromDB);

                if (ExistingMyWorkStyle != null)
                {
                    foreach (var css in ExistingMyWorkStyle)
                    {
                        var className = css.ClassName;
                        var colour = css.Colour;

                        var cssStyling = CellColourings.Where(x => x.ClassName == className).FirstOrDefault();

                        if (cssStyling is not null)
                            cssStyling.Colour = colour;
                        else
                            CellColourings.Add(css);
                    }
                }

                CSSLoadedFromDatabase = true;
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while getting the column template for the DynamicGridView.");
            ex.Data.Add("PageMethod", "OnParametersSet()");
            OnError(ex);
        }
    }

    /*
        Function for setting the colour for a cell.
    */

    private async void SetCellColour(object Colour, string CSSClass, object context)
    {
        try
        {
            string CellColour = (string)Colour;

            // Check for existing CSS rule.
            var CSSRuleExists = CellColourings.Where(x => x.ClassName == CSSClass).FirstOrDefault();

            //Reset the colour if exists, otherwise, add it as a new CSS rule.
            if (CSSRuleExists is not null)
            {
                CSSRuleExists.Colour = CellColour;
            }
            else
            {
                CellColourings.Add(new CellColouring()
                {
                    ClassName = CSSClass,
                    Colour = CellColour
                });
            }

            //Apply it & send it to the widget board so that it can be saved.
            await ApplyCSSColour();
            SendJSONToWidgetBoard();

            StateHasChanged();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while getting the column template for the DynamicGridView.");
            ex.Data.Add("PageMethod", "SetCellColour()");
            OnError(ex);
        }
    }

    /*
        Applies the CSS using a JS function - this can be found in the .razor file.
        Called from SetCellColour
     */

    [JSInvokable]
    private async Task ApplyCSSColour()
    {
        try
        {
            await JS.InvokeVoidAsync("applyCSSToGrid", CellColourings);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while getting the column template for the DynamicGridView.");
            ex.Data.Add("PageMethod", "ApplyCSSColour()");
            OnError(ex);
        }
    }

    /*
        Assigns a unique ID to each cell on render - called from MultiColumnDynamicGrid.razor
        This is to help assign a colour to a selected cell.
     */

    private string EncodeClassNameAsBase64(GridViewColumnDefinition gvcd, object context)
    {
        try
        {
            if (context is ExpandoObject expandoObject)
            {
                var dictionary = expandoObject as IDictionary<string, object>;

                if (dictionary.TryGetValue("Guid", out var Guid))
                {
                    return System.Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(gvcd.Id + "_" + gvcd.Name + "_" + Guid));
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while getting the column template for the DynamicGridView.");
            ex.Data.Add("PageMethod", "ApplyCSSColour()");
            OnError(ex);
        }

        return System.Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(gvcd.Guid + "_" + gvcd.Name));
    }

    public async void SendJSONToWidgetBoard()
    {
        try
        {
            var CellJSON = JsonSerializer.Serialize(CellColourings);
            await SendJSONToWidgetCallback.InvokeAsync(CellJSON);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while getting the column template for the DynamicGridView.");
            ex.Data.Add("PageMethod", "SendJSONToWidgetBoard()");
            OnError(ex);
        }
    }

    /*
        Sends over the filter & sort settings to the widget board.
     */

    public async void SendFilterAndSortSettingsToBoard()
    {
        try
        {
            MyWorkGridFilterAsJSON = JsonSerializer.Serialize(MyWorkFilterSettings, new JsonSerializerOptions() { WriteIndented = true });
            await SendFilterAndSortCallback.InvokeAsync(MyWorkGridFilterAsJSON);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while getting the column template for the DynamicGridView.");
            ex.Data.Add("PageMethod", "SendJSONToWidgetBoard()");
            OnError(ex);
        }
    }

    #endregion FUNCTIONS
}