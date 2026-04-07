using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using DocumentFormat.OpenXml.Drawing.Diagrams;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using System.Collections;
using System.Dynamic;
using System.Text.Json;
using Telerik.Blazor.Components;
using Telerik.Blazor.Components.Grid;
using Telerik.DataSource;
using Telerik.DataSource.Extensions;
using System.Net.Http;
using System.Net.Http.Json;
using static Concursus.PWA.Shared.DynamicGrid;
using static Concursus.PWA.Shared.MessageDisplay;
using JsonSerializer = System.Text.Json.JsonSerializer;
using System.Threading.Tasks;
using Google.Protobuf.WellKnownTypes;

namespace Concursus.PWA.Shared;

public partial class DynamicGridView : ComponentBase
{
    #region Private Fields

    //CBLD-393
    private static string dataObjGuid = "";

    private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();

    private System.Type? _detailPageType;

    private MessageDisplay _messageDisplay = new();

    private List<string> _operationsWithMultipleStateChanged = new List<string>() {
        "FilterDescriptors",
        "GroupDescriptors",
        "SearchFilter"
    };

    private GridViewDefinition? _viewDefinition;
    private List<ExpandoObject> gridData = new List<ExpandoObject>();

    // Ensure this is unique for each modal instance
    private string modalId = Guid.Empty.ToString();

    private bool IsMonthlySeriesModalVisible { get; set; }
    private bool MonthlySeriesSaving { get; set; }
    private string? MonthlySeriesError { get; set; }

    private MonthlySeriesModel MonthlySeries { get; set; } = new();

    private sealed class MonthlySeriesModel
    {
        public DateTime? StartDateFirstInvoice { get; set; }
        public DateTime? EndDateFinalInvoice { get; set; }
        public decimal? TotalValueNet { get; set; }
        public bool OverwriteExisting { get; set; }
    }

    #endregion Private Fields

    #region Public Properties
    [Parameter] public Dictionary<string, Any> TransientVirtualProperties { get; set; } = new();
    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = "";
    public bool HasChanges { get; private set; } = false;
    [Parameter] public EventCallback<InputUpdatedArgs> inputUpdated { get; set; }

    [Parameter]
    public EventCallback OnActionCompleted { get; set; }

    // [Parameter] public EventCallback<Exception> OnError { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");

    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public EventCallback<string> ParentGuidChanged { get; set; }
    [Parameter] public DynamicGrid.DrawerItem SelectedItem { get; set; } = new();

    [Parameter]
    public EventCallback<DrawerItem> SelectedItemChanged { get; set; }

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

    [Parameter] public bool DoubleClickDisabled { get; set; } = false;
    [Parameter] public bool Disabled { get; set; } = false;

    [Parameter] public EventCallback ResyncDataObject { get; set; }

    #endregion Public Properties

    #region Protected Properties

    protected string ErrorMessage { get; set; } = "";
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";

    protected FormHelper? formHelper;

    #endregion Protected Properties

    #region Private Properties

    private bool BatchGridVisible { get; set; } = false;
    // Stores the grid data

    private TelerikGrid<ExpandoObject>? correctGridRef { get; set; }
    private IEnumerable<ExpandoObject>? CurrentGridItems { get; set; } // Exposes the grid data
    private int DebounceDelay { get; set; } = 100;
    private bool DoubleStateChanged { get; set; }
    private List<GridColumn>? GridColumns { get; set; }
    private TelerikGrid<ExpandoObject>? GridRef { get; set; }
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

    private bool ComingFromModal { get; set; } = false;

    #endregion Private Properties

    #region Public Methods

    public static string ConvertBooleanStringToYesNo(string booleanString)
    {
        if (booleanString.Equals("True", StringComparison.OrdinalIgnoreCase))
            return "Yes";
        return booleanString.Equals("False", StringComparison.OrdinalIgnoreCase) ? "No" : booleanString;
    }

    public void AddProperty(ExpandoObject expando, string propertyName, object propertyValue)
    {
        try
        {
            // ExpandoObject supports IDictionary so we can extend it like this
            var expandoDict = expando as IDictionary<string, object>;
            if (expandoDict.ContainsKey(propertyName))
                expandoDict[propertyName] = propertyValue;
            else
                expandoDict.Add(propertyName, propertyValue);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while adding a property to the ExpandoObject.");
            ex.Data.Add("PageMethod", "DynamicGridView/AddProperty()");
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
                        builder.AddContent(0, propValue);
                    }
                    else
                    {
                        Console.WriteLine(
                            $"[DynamicGridView.GetColumnTemplate] Missing key '{propName}'. Available keys: {string.Join(", ", dictionary.Keys)}");
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

    //public void OnError(Exception error)
    //{
    //    if (string.IsNullOrEmpty(error.Message)) return;

    // ErrorMessage = error.Message; PageMethod = (error.Data.Contains("PageMethod") ?
    // error.Data["PageMethod"]?.ToString() : "Not Set") ?? string.Empty;

    // if (error.Data.Contains("MessageType")) { MessageType =
    // (MessageDisplay.ShowMessageType)(error.Data["MessageType"] ??
    // MessageDisplay.ShowMessageType.Information); } else { MessageType =
    // MessageDisplay.ShowMessageType.Error; }

    // // Extract all exception data and pass it to the MessageDisplay component if (_messageDisplay
    // != null) { // Pass Exception Data using the new method _messageDisplay?.UpdateExceptionData(
    // error.Data.Count > 0 ? error.Data.Cast<DictionaryEntry>() .ToDictionary( de =>
    // de.Key?.ToString() ?? "UnknownKey", de => de.Value!) : null );

    // // Update the stack trace dynamically _messageDisplay?.UpdateStackTrace(error.StackTrace);

    // _messageDisplay?.ShowError(true); }

    // // Recover from error (if using a custom boundary) // customErrorBoundary.Recover();

    //    StateHasChanged();
    //}

    public async Task OnError(Exception error)
    {
        if (string.IsNullOrEmpty(error.Message))
        {
            Console.WriteLine("DynamicGridView: Error message is empty. Aborting.");
            return;
        }

        ErrorMessage = error.Message;
        PageMethod = error.Data.Contains("PageMethod")
            ? error.Data["PageMethod"]?.ToString() ?? "Not Set"
            : "Not Set";
        Console.WriteLine($"DynamicGridView: PageMethod = {PageMethod}");

        if (error.Data.Contains("MessageType"))
        {
            MessageType = (ShowMessageType)(error.Data["MessageType"] ?? ShowMessageType.Information);
        }
        else
        {
            MessageType = ShowMessageType.Error;
            Console.WriteLine("DynamicGridView: MessageType not found in error.Data. Defaulted to Error.");
        }

        // Extract all exception data
        var exceptionData = error.Data.Count > 0
            ? error.Data.Cast<DictionaryEntry>().ToDictionary(
                de => de.Key?.ToString() ?? "UnknownKey",
                de => de.Value!)
            : null;

        if (exceptionData != null)
        {
            foreach (var kvp in exceptionData)
                Console.WriteLine($"    {kvp.Key} = {kvp.Value}");
        }

        _messageDisplay.UpdateExceptionData(exceptionData);
        _messageDisplay.UpdateStackTrace(error.StackTrace ?? "No additional details available.");
        _messageDisplay.ShowError(true);

        Console.WriteLine("DynamicGridView: MessageDisplay updated and error shown.");

        // AI Error Reporting (only for actual errors)
        if (MessageType == ShowMessageType.Error)
        {
            try
            {
                var context = new
                {
                    ErrorMessage = error.Message,
                    PageMethod = error.Data.Contains("PageMethod") ? error.Data["PageMethod"]?.ToString() ?? "UnknownMethod" : "UnknownMethod",
                    StackTrace = error.StackTrace ?? "No stack trace",
                    AdditionalInfo = error.Data.Contains("AdditionalInfo") ? error.Data["AdditionalInfo"]?.ToString() ?? "None" : "None",
                    Data = error.Data.Cast<DictionaryEntry>()
                        .ToDictionary(
                            de => de.Key?.ToString() ?? "UnknownKey",
                            de => de.Value?.ToString() ?? "null"
                        )
                };

                var log = InteractionTracker.GetAllLogs();
                var description = InteractionTracker.GetReplicationStepsFormatted(InteractionTracker);
                error.Data["UserInteractionLog"] = description;
                Console.WriteLine($"DynamicGridView: UserInteractionLog = {description}");

                var result = await AiErrorReporter.ReportAsync(error, context);

                if (result != null && !string.IsNullOrEmpty(result.UiMessage))
                {
                    _messageDisplay.SetMessage(result.UiMessage, result.MessageType);
                    _messageDisplay.ShowError(true);
                }
                else
                {
                    Console.WriteLine("DynamicGridView: AI Error Reporter returned no UI message.");
                }
            }
            catch (Exception aiEx)
            {
                Console.WriteLine($"DynamicGridView: Exception in AI Error Reporter: {aiEx.Message}\n{aiEx.StackTrace}");
            }
        }

        StateHasChanged();
    }

    public async Task RefreshMe()
    {
        try
        {
            var state = await CalcGridStateAsync();
            if (GridRef != null)
            {
                await GridRef.SetStateAsync(state);
                await Task.Delay(50); // Small delay for smoother UI updates
            }

            if (!HasChanges) return; // Prevent unnecessary UI refreshes
            HasChanges = false;
            StateHasChanged();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/RefreshMe()");
            OnError(ex);
        }
    }

    #endregion Public Methods

    #region Protected Methods


    protected async Task AddNew()
    {
        try
        {
            _ = GetScrollBarPos(); //Get the current scroll bar position.
            // Special behaviour for Monthly Scheduling grid
            if (string.Equals(GridCode, "INVSCEDMONTHLY", StringComparison.OrdinalIgnoreCase))
            {
                OpenMonthlySeriesModal();
                return;
            }

            //CBLD-292: Reset dataObjGuid to ensure if a new item is added, the grid will not load the previously created guid (it will load records pertaining to that).
            //dataObjGuid = "";
            if (ViewDefinition != null) // Check for null
            {
                if (ViewDefinition == null) return; // Check for null

                //CBLD-462
                await EnsureCorrectParentGuid();

                //Below is the code to get the ParentDataObjectReference and make sure it is set with the latest Modal windows saved details
                var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, ParentGuid, ViewDefinition.EntityTypeGuid);
                if (ViewDefinition.IsDetailWindowed)
                {
                    if (string.IsNullOrEmpty(ViewDefinition.DetailPageUri))
                    {
                        var ex = new Exception("DetailPageUri is not set in the ViewDefinition");
                        ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                        ex.Data.Add("AdditionalInfo", "An error occurred while adding a new record to the DynamicGridView.");
                        ex.Data.Add("PageMethod", "DynamicGridView/AddNew()");
                        OnError(ex);
                        return;
                    }

                    modalId = Guid.NewGuid().ToString();
                    _detailPageParameters.Clear();
                    _detailPageParameters.Add("EntityTypeGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
                    _detailPageParameters.Add("Windowed", true);
                    _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
                    //The RecordGuid refers to the modal content - in this case, the client details.
                    _detailPageParameters.Add("RecordGuid", Guid.Empty.ToString());
                    _detailPageParameters.Add("GridUpdated", EventCallback.Factory.Create(this, GridUpdated));
                    _detailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
                    _detailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                    _detailPageParameters.Add("ModalId", modalId);
                    _detailPageParameters.Add("IsDetailWindowed", true);
                    _detailPageParameters.Add("IsMainRecordContext", false);
                    _detailPageParameters.Add("TransientVirtualProperties", TransientVirtualProperties);
                    modalService.RegisterModal(modalId, parentDataObjectReference);

                    WindowIsVisible = true;

                    InteractionTracker.Log(NavManager.Uri ?? "Clicking New Button", $"User Clicked  \"New\" button - '{ViewDefinition.Code}'");
                }
                else
                {
                    InteractionTracker.Log(NavManager.Uri ?? "Clicking New Button", $"User Clicked  \"New\" button - '{ViewDefinition.Code}'");

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
            ex.Data.Add("AdditionalInfo", "An error occurred while adding a new record to the DynamicGridView.");
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
            //Reduntant -> Leaving in here for now for future reference, but this is now
            //replaced with using modalService.GetLatestModal() down below.
            //object? value;
            //if (_detailPageParameters.TryGetValue("ModalId", out value))
            //{
            //    if (value is string modalId)
            //    {
            //        modalService.UnregisterModal(modalId);
            //    }
            //}

            //Get the last created modal.
            var modal = modalService.GetLatestModal();

            if (modal != null)
            {
                var modalId = modal.Value.ModalId;
                modalService.UnregisterModal(modalId);
            }

             WindowIsVisible = false;

            if (!ComingFromModal)
            {
                GridRef?.Rebind();
                _ = RefreshMe();

                if (ResyncDataObject.HasDelegate)
                    await ResyncDataObject.InvokeAsync();

                StateHasChanged();
                await OnActionCompleted.InvokeAsync();  // Notify that an action has completed

                await SetScrollBarPos();
            }
            else
            {
                GridRef?.Rebind();
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while closing the window in the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/CloseWindow()");
            OnError(ex);
        }
    }

    // Optimized Grid Updated function to refresh UI efficiently
    protected async Task GridUpdated()
    {
        try
        {
            //CBLD-683
            if (!ComingFromModal)
            {
                await EnsureCorrectParentGuid();
                await RefreshMe();
                GridRef?.Rebind();
                StateHasChanged();
            }
            else
            {
                GridRef?.Rebind();
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/GridUpdated()");
            OnError(ex);
        }
    }

  

    // Optimized ReadItems to avoid unnecessary API calls
    protected async Task ReadItems(GridReadEventArgs args)
    {
        try
        {
            if (ViewDefinition == null) return;

            //if (ParentGuid != Guid.Empty.ToString())
            //    ParentGuidCopy = ParentGuid;

            //if (ParentGuid == Guid.Empty.ToString() && ParentGuidCopy != Guid.Empty.ToString())
            //    ParentGuid = ParentGuidCopy;

            await EnsureCorrectParentGuid(); // Ensure Parent GUID is properly set before API calls

            var pageNum = args.Request.Page;
            var SavedPageNum = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_currentPageNumber");

            //CBLD-686: Preventing the grid to reset the number when the modal is closed.
            if (ComingFromModal && SavedPageNum != null)
            {
                pageNum = int.Parse(SavedPageNum);
            }

            var gridDataListRequest = new GridDataListRequest
            {
                GridCode = GridCode,
                GridViewCode = ViewDefinition.Code,
                Page = pageNum,
                PageSize = args.Request.PageSize,
                ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString()
            };

            if (gridDataListRequest.ParentGuid == Guid.Empty.ToString() && !FullGrid) return;

            // Store session page number (avoid excessive API calls)
            //CBLD-686 - do not save if page num is 1
            //if(args.Request.Page != 1)
            //{
            await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_currentPageNumber", args.Request.Page);
            //}

            // Ensure we handle single `DataCompositeFilter` properly
            var compositeFilter = API.Client.TypeHelpers.GridDataCompositeFilterFromKendoFilterDescriptor(args.Request.Filters);
            if (compositeFilter != null)
            {
                gridDataListRequest.Filters.Add(compositeFilter);
                LogCompositeFilter(compositeFilter);
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

            // ===== DIAGNOSTIC CHECKS START =====
            Console.WriteLine("==================================================");
            Console.WriteLine($"[DynamicGridView.ReadItems] GridCode      = {GridCode}");
            Console.WriteLine($"[DynamicGridView.ReadItems] GridViewCode  = {ViewDefinition?.Code}");
            Console.WriteLine($"[DynamicGridView.ReadItems] ParentGuid    = {ParentGuid}");
            Console.WriteLine($"[DynamicGridView.ReadItems] Page          = {args.Request.Page}");
            Console.WriteLine($"[DynamicGridView.ReadItems] PageSize      = {args.Request.PageSize}");
            Console.WriteLine($"[DynamicGridView.ReadItems] TotalRows     = {gridDataListReply.TotalRows}");
            Console.WriteLine($"[DynamicGridView.ReadItems] DataTableRows = {gridDataListReply.DataTable.Count}");
            Console.WriteLine($"[DynamicGridView.ReadItems] ExpandoRows   = {gridData.Count}");

            if (gridData.Count > 0)
            {
                var firstRow = (IDictionary<string, object>)gridData[0];
                Console.WriteLine("[DynamicGridView.ReadItems] First row keys:");
                foreach (var key in firstRow.Keys)
                {
                    Console.WriteLine($"    KEY = '{key}'");
                }

                Console.WriteLine("[DynamicGridView.ReadItems] First row values:");
                foreach (var kvp in firstRow)
                {
                    Console.WriteLine($"    {kvp.Key} = '{kvp.Value}'");
                }
            }
            else
            {
                Console.WriteLine("[DynamicGridView.ReadItems] No rows returned to the grid.");
            }

            if (gridDataListReply.DataTable.Count > 0)
            {
                Console.WriteLine("[DynamicGridView.ReadItems] Raw first row column names from reply:");
                foreach (var col in gridDataListReply.DataTable[0].Columns)
                {
                    Console.WriteLine($"    COLUMN = '{col.Name}'   VALUE = '{col.Value}'");
                }
            }
            Console.WriteLine("==================================================");
            // ===== DIAGNOSTIC CHECKS END =====

            args.Data = gridData;
            args.Total = (int)gridDataListReply.TotalRows;
            CurrentGridItems = gridData;

            //CBLD-686: Ensure grid is rebinded, otherwise you will have to click the backwards/forwards arrow 2x on the grid (for the page number)
            if (ComingFromModal)
            {
                GridRef.Rebind();
                ComingFromModal = false;
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/ReadItems()");
            OnError(ex);
        }
    }

    private static readonly HashSet<string> _loggedFilters = new();

    public void LogCompositeFilter(DataCompositeFilter compositeFilter)
    {
        foreach (var filter in compositeFilter.CompositeFilters)
        {
            TraverseAndLogFilter(filter);
        }
    }

    private void TraverseAndLogFilter(DataCompositeFilter filter)
    {
        foreach (var subFilter in filter.Filters ?? Enumerable.Empty<DataFilter>())
        {
            var key = $"{subFilter.ColumnName}-{subFilter.Operator}-{subFilter.Value}";
            if (_loggedFilters.Add(key)) // ensures uniqueness
            {
                InteractionTracker.Log(NavManager.Uri,
                    $"Filter added to Grid - '{ViewDefinition?.Name ?? "Unknown"}' Filter: '{subFilter.ColumnName}' Operator: '{subFilter.Operator}' Value: '{subFilter.Value}'");
            }
        }

        foreach (var nestedComposite in filter.CompositeFilters ?? Enumerable.Empty<DataCompositeFilter>())
        {
            TraverseAndLogFilter(nestedComposite);
        }
    }

    // Helper function to format grid column values correctly
    private object FormatGridColumnValue(string columnName, string value)
    {
        ////CBLD-530
        bool isPhoneNumber = CheckIfMobileNumber(columnName, value);

        if (isPhoneNumber)
        {
            return value;
        }

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

    //CBLD-530 - ensuring phone number is displayed properly.
    private bool CheckIfMobileNumber(string columnName, string columnValue)
    {
        //Check for common ways a phone number might start.
        bool startsWithZero = columnValue.StartsWith("0") && !columnValue.Contains("/"); //Date can start with 0, therefore check for '/'
        bool startWithFourtyFour = columnValue.StartsWith("44");
        bool startsWithPlus = columnValue.StartsWith("+");

        if (startsWithZero || startWithFourtyFour || startsWithPlus)
        {
            return true;
        }

        return false;
    }

    protected async Task ResetDataObjectGuid()
    {
        int NumOfModals = modalService.GetOpenModals().Count;
        if (NumOfModals <= 1)
        {
            dataObjGuid = "";
        }
    }

    #endregion Protected Methods

    #region Private Methods

    private void OpenMonthlySeriesModal()
    {
        MonthlySeriesError = null;
        MonthlySeriesSaving = false;

        MonthlySeries = new MonthlySeriesModel
        {
            StartDateFirstInvoice = null,
            EndDateFinalInvoice = null,
            TotalValueNet = null,
            OverwriteExisting = false
        };

        IsMonthlySeriesModalVisible = true;
        StateHasChanged();
    }

    private void CloseMonthlySeriesModal()
    {
        IsMonthlySeriesModalVisible = false;
        MonthlySeriesError = null;
        MonthlySeriesSaving = false;
        StateHasChanged();
    }

    private async Task SaveMonthlySeriesAsync()
    {
        try
        {
            MonthlySeriesError = null;

            if (!TryResolveInvoiceScheduleGuid(out var invoiceScheduleGuid))
            {
                MonthlySeriesError = "Invoice Schedule must be saved first.";
                return;
            }

            if (MonthlySeries.StartDateFirstInvoice is null)
            {
                MonthlySeriesError = "Start Date (First Invoice) is required.";
                return;
            }

            if (MonthlySeries.EndDateFinalInvoice is null)
            {
                MonthlySeriesError = "End Date (Final Invoice) is required.";
                return;
            }

            if (MonthlySeries.TotalValueNet is null || MonthlySeries.TotalValueNet <= 0)
            {
                MonthlySeriesError = "Total Value (Net) must be greater than zero.";
                return;
            }

            var start = DateOnly.FromDateTime(MonthlySeries.StartDateFirstInvoice.Value);
            var end = DateOnly.FromDateTime(MonthlySeries.EndDateFinalInvoice.Value);

            if (start > end)
            {
                MonthlySeriesError = "Start Date must be before or equal to End Date.";
                return;
            }

            MonthlySeriesSaving = true;

            var payload = new
            {
                StartDateFirstInvoice = start,
                EndDateFinalInvoice = end,
                TotalValueNet = MonthlySeries.TotalValueNet.Value,
                OverwriteExisting = MonthlySeries.OverwriteExisting
            };

            // API call
            var apiHttp = HttpClientFactory.CreateClient("ShoreApiHttp");

            var res = await apiHttp.PostAsJsonAsync(
                $"api/invoice-schedules/{invoiceScheduleGuid}/month-configurations/generate",
                payload);

            if (!res.IsSuccessStatusCode)
            {
                var body = await res.Content.ReadAsStringAsync();
                MonthlySeriesError = $"Failed to generate monthly schedule: {res.StatusCode} {body}";
                return;
            }

            var result = await res.Content.ReadFromJsonAsync<GenerateMonthlySeriesResponse>()
                         ?? new GenerateMonthlySeriesResponse();

            Toast.ShowSuccess($"Generated {result.InsertedCount} monthly periods.");

            CloseMonthlySeriesModal();

            GridRef?.Rebind();
            _ = RefreshMe();

            if (ResyncDataObject.HasDelegate)
                await ResyncDataObject.InvokeAsync();
        }
        catch (Exception ex)
        {
            MonthlySeriesError = ex.Message;
        }
        finally
        {
            MonthlySeriesSaving = false;
            StateHasChanged();
        }
    }
    //OE: CBLD-430.
  
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

    /// <summary>
    /// Function that is used to define the columns for the csv export.
    ///
    /// It iterates through GridDataRow and extracts them.
    /// </summary>
    /// <param name="row"></param>
    /// <returns></returns>
    private List<GridCsvExportColumn> DefineCSVColumns(GridDataRow row)
    {
        var Columns = new List<GridCsvExportColumn>();

        foreach (var c in row.Columns)
        {
            //Skip ID & Guid - no need for the clients to it,
            if (c.Name == "ID" || c.Name == "Guid")
                continue;

            Columns.Add(new GridCsvExportColumn() { Field = c.Name });
        }

        return Columns;
    }

    private async Task ExportToCsvWithOptions()
    {


        var gridDataListRequest = new GridDataListRequest
        {
            GridCode = GridCode,
            GridViewCode = ViewDefinition.Code,
            Page = 1,
            PageSize = 1000,
            ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString()
        };

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

        //Define the columns inside the
        var gridColumns = gridDataListReply.DataTable[0];

        var CSVColumns = DefineCSVColumns(gridColumns);

        await GridRef.SaveAsCsvFileAsync(new GridCsvExportOptions()
        {
            FileName = $"{ViewDefinition.Name}_{DateTime.Now:yyyyMMdd_HHmmss}",
            Data = gridData.ToList(),
            Columns = CSVColumns
        });
    }

    private async void CloseBatchGridModal()
    {
        BatchGridVisible = false;
        await GridUpdated();
        StateHasChanged();
        InteractionTracker.Log(NavManager.Uri, $"Modal Closed");
        _ = SetScrollBarPos(); //CBLD-361
    }

    private IFilterDescriptor CreateSearchFilter(string searchValue, List<string> fields)
    {
        var descriptor = new CompositeFilterDescriptor();
        try
        {
            descriptor = new CompositeFilterDescriptor
            {
                LogicalOperator = FilterCompositionLogicalOperator.Or
            };

            foreach (var filter in fields.Select(field => new FilterDescriptor(field, FilterOperator.Contains, searchValue)
            {
                MemberType = typeof(string)
            }))
            {
                descriptor.FilterDescriptors.Add(filter);
                InteractionTracker.Log(NavManager.Uri, $"Filter added to Grid - '{ViewDefinition?.Name ?? "Unknown"}' Filter Added: '{filter.Member.ToString()}' Operator: '{filter.Operator.ToString()} Value: '{filter.Value}''");
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while creating a search filter in the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/CreateSearchFilter()");
            OnError(ex);
        }

        return descriptor;
    }

    //CBLD-462
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

    private async Task OnGridStateChanged(GridStateEventArgs<ExpandoObject> args)
    {
        try
        {
            //CBLD-106: Object that holds all the relevant information needed for the session storage.
            var gridStateToSave = new FilterAndSortSetting()
            {
                code = ViewDefinition.Code,
                gridCode = GridCode,
                filterDescriptor = args.GridState.FilterDescriptors,
                sortDescriptor = args.GridState.SortDescriptors
            };

            //If we only have one item in filterDescriptor, it means the filter has been reset.
            if (gridStateToSave.filterDescriptor.Count < 2)
            {
                var filterExists = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_gridState");

                if (filterExists != null)
                    await LocalStorageAccessor.RemoveAsync($"{ViewDefinition.Code}_gridState");
            }
            else
            {
                //Serialize the created object and then save it to the session.
                var serializedGridStateToSave = JsonSerializer.Serialize(gridStateToSave, new JsonSerializerOptions() { WriteIndented = true });
                await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_gridState", serializedGridStateToSave);
            }

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

    /*
        The below 2 functions are pertaining to CBLD-361.

        Their purpose is to ensure that the scrollbar does not
        jump after adding an item to the grid & clicking "save and exit".

     */

    private async Task GetScrollBarPos() //CBLD-361
    {
        try
        {
            await JsRuntime.InvokeVoidAsync("GetScrollBarPos");
        }
        catch (Exception ex)
        {
            // OE - CBLD- Added catch so that it does throw an error message.
            Console.WriteLine(ex.Message);
        }
    }

    private async Task SetScrollBarPos() //CBLD-361
    {
        try
        {
            await JsRuntime.InvokeVoidAsync("SetScrollBarPos");
            await Task.Delay(100);
        }
        catch (Exception ex)
        {
            // OE - CBLD- Added catch so that it does throw an error message.
            Console.WriteLine(ex.Message);
        }
    }

    private void OnRowDoubleClickHandler(GridRowClickEventArgs args)
    {
        try
        {
            if (DoubleClickDisabled) return;

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
                _detailPageParameters.Add("IsMainRecordContext", false);
                _detailPageParameters.Add("TransientVirtualProperties", TransientVirtualProperties);

                modalService.RegisterModal(modalId, parentDataObjectReference);
                WindowIsVisible = true;
                ComingFromModal = true; //CBLD-686: Setting to true since we are opening a modal.
                InteractionTracker.Log(NavManager.Uri, $"User Double Clicked Row in Grid - '{ViewDefinition?.Name ?? "Unknown"}' New Page Opened: '{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition?.EntityTypeGuid ?? "No Guid").ToString()}'");
            }
            else
            {
                // CBLD-771 / CBLD-331 – Safe navigation URL construction

                // Step 1: Parse safe GUID for the row we double-clicked
                var guid = PWAFunctions
                    .ParseAndReturnEmptyGuidIfInvalid(model.Guid)
                    .ToString();

                // Step 2: Parent reference stays as the original URL-encoded JSON
                var encodedParentReference = serializedParentDataObjectReference;

                var baseUri = NavManager.BaseUri.TrimEnd('/');
                var currentUri = NavManager.Uri ?? string.Empty;

                // Step 3: Detect "list/grid" context: URLs like /jobs/00000000-0000-0000-0000-000000000000
                bool isListContext = false;
                try
                {
                    var u = new Uri(currentUri);
                    var segments = u.AbsolutePath
                                      .Split('/', StringSplitOptions.RemoveEmptyEntries);
                    var lastSegment = segments.LastOrDefault();

                    if (!string.IsNullOrEmpty(lastSegment) &&
                        Guid.TryParse(lastSegment, out var lastGuid) &&
                        lastGuid == Guid.Empty)
                    {
                        // last segment is the all-zero Guid → list page
                        isListContext = true;
                    }
                }
                catch
                {
                    // Fallback: simple string check if Uri parsing fails
                    isListContext = currentUri.EndsWith(
                        "00000000-0000-0000-0000-000000000000",
                        StringComparison.OrdinalIgnoreCase);
                }

                string encodedReturnUrl;

                if (isListContext)
                {
                    // List/grid scenario (e.g. Jobs grid): ReturnUrl should be the grid URL itself.
                    encodedReturnUrl = System.Web.HttpUtility.UrlEncode(currentUri);
                }
                else
                {
                    // FIX: Avoid double-encoding when the current URL already contains an encoded ReturnUrl
                    var flattened = System.Web.HttpUtility.UrlDecode(currentUri) ?? string.Empty;

                    // Extract only the LAST https:// … (the real return page)
                    var lastIndex = flattened.LastIndexOf("https://", StringComparison.OrdinalIgnoreCase);

                    if (lastIndex >= 0)
                        flattened = flattened.Substring(lastIndex);

                    encodedReturnUrl = System.Web.HttpUtility.UrlEncode(flattened);
                }

                // Step 4: Build the final navigation URL (same route shape as before)
                string url;

                if (ViewDefinition.DetailPageUri == "DynamicEdit")
                {
                    var entityTypeGuid = PWAFunctions
                        .ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid)
                        .ToString();

                    url = $"{ViewDefinition.DetailPageUri}/" +
                          $"{entityTypeGuid}/" +
                          $"{parentDataObjectReference.DataObjectGuid}/" +
                          $"{encodedParentReference}/" +
                          $"{encodedReturnUrl}";
                }
                else
                {
                    // Standard detail page
                    url = $"{ViewDefinition.DetailPageUri}/" +
                          $"{guid}/" +
                          $"{encodedParentReference}/" +
                          $"{encodedReturnUrl}";
                }

                // CLD-611 – Force reload if we're already on a detail page of same type
                if (isParentDataObjectReferenceDifferent)
                {
                    var navigateToDetailPage = "/" + ViewDefinition.DetailPageUri + "/";
                    var current = NavManager.Uri ?? string.Empty;

                    if (current.Contains(navigateToDetailPage, StringComparison.OrdinalIgnoreCase))
                    {
                        NavManager.NavigateTo(url, forceLoad: true);
                    }
                    else
                    {
                        NavManager.NavigateTo(url, forceLoad: false);
                    }
                }
                else
                {
                    // Same parent reference – hard refresh to ensure UI reflects new record
                    NavManager.NavigateTo(url, forceLoad: true);
                }

                InteractionTracker.Log(
                    NavManager.Uri,
                    $"User Double Clicked Row in Grid - '{ViewDefinition?.Name ?? "Unknown"}' " +
                    $"New Page Opened: '{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition?.EntityTypeGuid ?? "No Guid")}'");
            }

            formHelper = new FormHelper(coreClient, sageIntegrationService, Guid.Empty.ToString(), userService);
            _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while handling the row double-click event in the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/OnRowDoubleClickHandler()");
            OnError(ex);
        }
    }

    private void OnRowRenderHandler(GridRowRenderEventArgs args)
    {
        // apply ellipsis to specific columns using OnRowRender args.Class = "custom-ellipsis";

        //CBLD-215 - Highlighting total row.
        var row = args.Item as IDictionary<string, object>;

        if (row == null) return;

        if (row.TryGetValue("IsTotalHighlightRow", out var value))
        {
            if (value?.ToString() == "1")
            {
                args.Class = "highlight-total-row";
            }
        }
        else if (row.TryGetValue("SubContractorName", out var totalValue))
        {
            if (totalValue?.ToString() == "Total")
            {
                args.Class = "highlight-total-row";
            }
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

                var savedPageNumber = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_currentPageNumber");
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

                //Check if there are gridSettings already present in the session.
                var isGradeStateSaved = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_gridState");

                //cBLD-106: ensuring the filter and sort settings are rememebered.
                if (isGradeStateSaved != null && FullGrid) //Only on full grids.
                {
                    FilterAndSortSetting gridSetting = JsonSerializer.Deserialize<FilterAndSortSetting>(isGradeStateSaved);
                    //CBLD-532: Get the page number from the session - if there is one.

                    //Only apply the settings when viewng the correct grid.
                    if (gridSetting.code == ViewDefinition.Code && gridSetting.gridCode == GridCode)
                    {
                        state.FilterDescriptors = gridSetting.filterDescriptor;
                        state.SortDescriptors = gridSetting.sortDescriptor;
                    }
                }
            }

            args.GridState = state;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while initializing the grid state in the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/OnStateInitHandler()");
            OnError(ex);
        }
    }

    // Open the batch grid view in a modal
    private void OpenDynamicBatchGrid()
    {
        _ = GetScrollBarPos(); //CBLD-361
        BatchGridVisible = true;
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
            ex.Data.Add("AdditionalInfo", "An error occurred while rebinding the grid in the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/RebindGrid()");
            OnError(ex);
        }
    }

    //Added function to programmatically refresh the grid.
    public async void RefreshGrid()
    {
        await this.RebindGrid();
    }


    private void ScrollToTop()
    {
        // Scroll to the top of the page
        JsRuntime.InvokeVoidAsync("window.scrollTo", 0, 0);
        InteractionTracker.Log(NavManager.Uri, $"Back To Top Clicked");
    }

    private async Task SetSearchBoxState(IFilterDescriptor? descriptor)
    {
        try
        {
            // Check if descriptor is not null before proceeding
            if (descriptor == null)
            {
                return;
            }

            GridState<ExpandoObject> state = new()
            {
                SearchFilter = descriptor
            };

            await GridRef!.SetStateAsync(state);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while setting the search box state in the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/SetSearchBoxState()");
            OnError(ex);
        }
    }

    private bool TryResolveInvoiceScheduleGuid(out Guid invoiceScheduleGuid)
    {
        invoiceScheduleGuid = Guid.Empty;

        // 1) ParentGuid parameter (preferred)
        if (TryParseNonEmptyGuid(ParentGuid, out invoiceScheduleGuid))
            return true;

        // 2) ParentDataObjectReference (often has Guid even when ParentGuid hasn't propagated yet)
        if (!string.IsNullOrWhiteSpace(ParentDataObjectReference?.DataObjectGuid.ToString()) &&
            Guid.TryParse(ParentDataObjectReference.DataObjectGuid.ToString(), out invoiceScheduleGuid) &&
            invoiceScheduleGuid != Guid.Empty)
            return true;

        return false;
    }

    private static bool TryParseNonEmptyGuid(string? value, out Guid guid)
    {
        guid = Guid.Empty;
        return !string.IsNullOrWhiteSpace(value) &&
               Guid.TryParse(value, out guid) &&
               guid != Guid.Empty;
    }
    private async Task WindowVisibleChangedHandler(bool currVisible)
    {
        if (WindowIsClosable)
        {
            WindowIsVisible = currVisible; // if you don't do this, the window won't close because of the user action

            //This ensures the modal is correctly closed when "X" is clicked.
            if (!currVisible)
            {
                await CloseWindow();
            }
        }

        else
            Console.WriteLine("The user tried to close the window but the code didn't let them");
    }

    #endregion Private Methods

    #region Private Classes


    private sealed class GenerateMonthlySeriesResponse
    {
        public int InsertedCount { get; set; }
        public int MonthsCount { get; set; }
    }
    //CBLD-106
    private class FilterAndSortSetting
    {
        #region Public Properties

        public string code { get; set; }
        public ICollection<IFilterDescriptor> filterDescriptor { get; set; }
        public string gridCode { get; set; }
        public ICollection<SortDescriptor> sortDescriptor { get; set; }

        #endregion Public Properties
    }

    #endregion Private Classes
}