using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using System.Collections;
using System.Dynamic;
using System.Text.Json;
using Telerik.Blazor.Components;
using Telerik.DataSource;
using static Concursus.PWA.Shared.DynamicGrid;
using static Concursus.PWA.Shared.MessageDisplay;
using static Concursus.PWA.Shared.Widget;
using JsonSerializer = System.Text.Json.JsonSerializer;

namespace Concursus.PWA.Shared;

public partial class DynamicBatchGridView
{
    #region Protected Fields

    protected FormHelper? formHelper;

    #endregion Protected Fields

    #region Private Fields

    private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();
    private System.Type? _detailPageType;
    private MessageDisplay _messageDisplay = new();

    private List<string> _operationsWithMultipleStateChanged = new List<string>() {
        "FilterDescriptors",
        "GroupDescriptors",
        "SearchFilter"
    };

    private GridViewDefinition? _viewDefinition;
    private Guid EntityTypeGuid;
    private List<ExpandoObject> gridData = new List<ExpandoObject>();

    //CBLD-260
    private bool isBulkRecordChangeVisible = false;

    private List<ExpandoObject> ListSelectedItems = new List<ExpandoObject>();

    // Track selected items Ensure this is unique for each modal instance
    private string modalId = Guid.Empty.ToString();

    #endregion Private Fields

    #region Public Properties

    //START: CBLD-265 - Multi select.
    public BatchButtonMenu _buttonMenuRef { get; set; }

    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = "";

    public List<GridViewActions> GridViewActions { get; set; }
    public bool HasChanges { get; private set; } = false;
    [Parameter] public EventCallback<InputUpdatedArgs> inputUpdated { get; set; }
    [Parameter] public bool IsBulkProcessing { get; set; } = false;
    [Parameter] public IEnumerable<ExpandoObject> Items { get; set; } = new List<ExpandoObject>();
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    [Parameter] public EventCallback<IEnumerable<ExpandoObject>> OnSelectedItemsChanged { get; set; }

    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
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

    #endregion Public Properties

    #region Protected Properties

    protected string ErrorMessage { get; set; } = "";
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";

    #endregion Protected Properties

    #region Private Properties

    private string currentGridCode { get; set; } = "";
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
    private bool reReadData { get; set; } = false;
    private int? SearchBoxWidth { get; set; } = 200;

    // IMPORTANT: never null for Telerik selection binding
    private IList<ExpandoObject> SelectedItems { get; set; } = new List<ExpandoObject>();

    private bool WindowIsClosable { get; set; } = true;
    private bool WindowIsVisible { get; set; }
    private string? WindowTitle { get; set; }

    // Sage submission monitor specific
    private bool IsSageSubmissionMonitorView =>
        string.Equals(ViewDefinition?.Code, "ALLSAGESUBMON", StringComparison.OrdinalIgnoreCase);

    private bool IsRequeueingSageSubmission { get; set; } = false;

    private bool CanRequeueSelectedSageSubmissions =>
        !IsBulkProcessing
        && !IsRequeueingSageSubmission
        && IsSageSubmissionMonitorView
        && GetSelectedTransactionGuids().Count > 0;

    //Filtered list variables
    private string CreatedOnColumn { get; set; } = "";
    private string GroupBy { get; set; } = "";
    private string RedIndicator { get; set; } = "";
    private string GreenIndicator { get; set; } = "";

    //==============================================
    //=             QUICK FILTERS                  =
    //==============================================
    private int? ActiveQuickFilterDays = null;

    private bool QuickFilterActive { get; set; } = false;
    private string QuickFilter7DaysCSS { get; set; } = "";
    private string QuickFilter90DaysCSS { get; set; } = "";
    private string QuickFilterGroupByCSS { get; set; } = "";
    private DataCompositeFilter QuickFilters { get; set; }

    //==============================================
    //=             RANGE FILTERS                  =
    //==============================================

    private bool RangeFiltersActive { get; set; } = false;
    private DataCompositeFilter RangeFilters { get; set; }

    //==============================================
    //=             GROUP BY FILTERS               =
    //==============================================
    private class OrderByItem
    {
        public string Id { get; set; }
        public string Text { get; set; } = string.Empty;
    }

    private string SelectedSortBy { get; set; }
    private IEnumerable<OrderByItem> OrderByOptions { get; set; } = new List<OrderByItem>
    {
        new OrderByItem()
        {
            Id = "SentDate_desc",
            Text = "Date Sent (Newest First)"
        },

        new OrderByItem()
        {
            Id = "SentDate_asc",
            Text = "Date Sent (Oldest First)"
        },

        new OrderByItem()
        {
            Id ="Amount_desc",
            Text = "Value (Highest First)"
        },
        new OrderByItem()
        {
            Id = "Amount_asc",
            Text = "Value (Lowest First)"
        }
    };

    private IEnumerable<string> GroupByOptions { get; set; } = new List<string>();
    private bool GroupByColumn { get; set; } = false;
    private string GroupByColumTranslation { get; set; } = "";

    private bool showCustomRange { get; set; } = false;
    private DateOnly? customStartDate { get; set; }
    private DateOnly? customEndDate { get; set; }

    private double Threshold { get; set; } = -1;
    private int OrganisationalUnitID { get; set; } = -1;

    #endregion Private Properties

    #region Public Methods

    public void AddProperty(ExpandoObject expando, string propertyName, object propertyValue)
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
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to add a property to the ExpandoObject.");
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
                };
            return ColumnTemplate;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to get the column template.");
            ex.Data.Add("PageMethod", "DynamicGridView/GetColumnTemplate()");
            OnError(ex);
        }

        return null;
    }

    public IEnumerable<ExpandoObject> GetSelectionForBatch()
    {
        return SelectedItems ?? new List<ExpandoObject>();
    }

    public void HideUnselected(List<string> GuidsToHide)
    {
    }

    public async Task OnError(Exception error)
    {
        if (string.IsNullOrEmpty(error.Message))
        {
            Console.WriteLine("DynamicBatchGridView: Error message is empty. Aborting.");
            return;
        }

        ErrorMessage = error.Message;
        PageMethod = error.Data.Contains("PageMethod")
            ? error.Data["PageMethod"]?.ToString() ?? "Not Set"
            : "Not Set";
        Console.WriteLine($"DynamicBatchGridView: PageMethod = {PageMethod}");

        if (error.Data.Contains("MessageType"))
        {
            MessageType = (ShowMessageType)(error.Data["MessageType"] ?? ShowMessageType.Information);
        }
        else
        {
            MessageType = ShowMessageType.Error;
            Console.WriteLine("DynamicBatchGridView: MessageType not found in error.Data. Defaulted to Error.");
        }

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

        Console.WriteLine("DynamicBatchGridView: MessageDisplay updated and error shown.");

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
                Console.WriteLine($"DynamicBatchGridView: UserInteractionLog = {description}");

                var result = await AiErrorReporter.ReportAsync(error, context);

                if (result != null && !string.IsNullOrEmpty(result.UiMessage))
                {
                    _messageDisplay.SetMessage(result.UiMessage, result.MessageType);
                    _messageDisplay.ShowError(true);
                }
                else
                {
                    Console.WriteLine("DynamicBatchGridView: AI Error Reporter returned no UI message.");
                }
            }
            catch (Exception aiEx)
            {
                Console.WriteLine($"DynamicBatchGridView: Exception in AI Error Reporter: {aiEx.Message}\n{aiEx.StackTrace}");
            }
        }

        StateHasChanged();
    }

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
                var expandoDict = item as IDictionary<string, object>;

                if (expandoDict != null)
                {
                    foreach (var kvp in expandoDict)
                    {
                        if (kvp.Key == "Guid" && kvp.Value != "")
                        {
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
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to perform an Action from the menu");
            ex.Data.Add("PageMethod", "DynamicBatchGridView/PerformAction()");
            OnError(ex);
        }
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
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to refresh the grid.");
            ex.Data.Add("PageMethod", "DynamicGridView/RefreshMe()");
            OnError(ex);
        }
    }

    #endregion Public Methods

    #region Protected Methods

    protected override async Task OnInitializedAsync()
    {
        await base.OnInitializedAsync();

        if (ViewDefinition is not null)
        {
            CreatedOnColumn = _viewDefinition.FilteredListCreatedOnColumn;
            RedIndicator = _viewDefinition.FilteredListRedStatusIndicatorTxt;
            GreenIndicator = _viewDefinition.FilteredListGreenStatusIndicatorTxt;
            GroupBy = _viewDefinition.FilteredListGroupBy;

            if (GroupBy == "OrgUnit")
            {
                GroupByColumTranslation = "Organisation Unit";
            }
        }
    }

    protected async Task AddNew()
    {
        try
        {
            if (ViewDefinition != null)
            {
                if (ViewDefinition == null) return;
                var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, ParentGuid, ViewDefinition.EntityTypeGuid);
                if (ViewDefinition.IsDetailWindowed)
                {
                    if (string.IsNullOrEmpty(ViewDefinition.DetailPageUri))
                    {
                        var ex = new Exception("DetailPageUri is not set in the ViewDefinition");
                        ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                        ex.Data.Add("AdditionalInfo", "DetailPageUri is not set in the ViewDefinition");
                        ex.Data.Add("PageMethod", "DynamicGridView/AddNew()");
                        OnError(ex);
                        return;
                    }

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
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to add a new record.");
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

            await GridUpdated();
            await RefreshMe();

            StateHasChanged();
            await OnActionCompleted.InvokeAsync();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to close the window.");
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
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to update the grid.");
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

    protected async Task ReadItems(GridReadEventArgs args)
    {
        try
        {
            if (Items != null && Items.Any())
            {
                args.Data = Items;
                args.Total = Items.Count();
            }
            else
            {
                if (ViewDefinition != null)
                {
                    if (currentGridCode != ViewDefinition.Code)
                    {
                        SelectedItems = new List<ExpandoObject>();
                    }

                    GridDataListRequest gridDataListRequest = new()
                    {
                        GridCode = GridCode,
                        GridViewCode = ViewDefinition.Code,
                        Page = args.Request.Page,
                        PageSize = args.Request.PageSize,
                        ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString()
                    };

                    currentGridCode = ViewDefinition.Code;

                    var compositeFilter = API.Client.TypeHelpers.GridDataCompositeFilterFromKendoFilterDescriptor(args.Request.Filters);

                    if (gridDataListRequest.ParentGuid != Guid.Empty.ToString() || FullGrid)
                    {
                        if (QuickFilters != null)
                        {
                            compositeFilter.CompositeFilters.Add(QuickFilters);
                        }

                        if (RangeFilters != null)
                        {
                            compositeFilter.CompositeFilters.Add(RangeFilters);
                        }

                        if (compositeFilter != null)
                        {
                            gridDataListRequest.Filters.Add(compositeFilter);
                        }

                        gridDataListRequest.Filters.Add(API.Client.TypeHelpers.GridDataCompositeFilterFromKendoFilterDescriptor(args.Request.Filters));
                        gridDataListRequest.Sort.Add(API.Client.TypeHelpers.GridDataSortFromKendoSortDescriptor(args.Request.Sorts));

                        var gridDataListReply = await coreClient.GridDataListAsync(gridDataListRequest);

                        if (SelectedItems != null && SelectedItems.Count > 0)
                        {
                            currentGridCode = ViewDefinition.Code;
                            args.Data = gridData;
                            args.Total = (int)gridDataListReply.TotalRows;
                            return;
                        }

                        gridData = new();
                        reReadData = false;

                        foreach (var r in gridDataListReply.DataTable)
                        {
                            dynamic dataObj = new ExpandoObject();

                            foreach (var c in r.Columns)
                            {
                                var value = c.Value;
                                var name = c.Name;

                                if (DateTime.TryParse(value, out var dateTimeValue))
                                {
                                    value = UiFormattingHelper.FormatDynamicDate(name, dateTimeValue);
                                }

                                AddProperty(dataObj, name, value);
                            }

                            gridData.Add(dataObj);
                        }

                        if (GroupByColumn)
                        {
                            string groupColumn = GroupBy;

                            GroupByOptions = gridData
                                .Select(row =>
                                {
                                    var dict = (IDictionary<string, object>)row;
                                    return dict.TryGetValue(groupColumn, out var value)
                                        ? value?.ToString()
                                        : null;
                                })
                                .Where(v => !string.IsNullOrWhiteSpace(v))
                                .Distinct()
                                .ToList();

                            var grouped = gridData
                                .GroupBy(row =>
                                {
                                    var dict = (IDictionary<string, object>)row;
                                    return dict.TryGetValue(groupColumn, out var value)
                                        ? value
                                        : null;
                                })
                                .ToList();

                            var flattened = grouped
                                .SelectMany(g => g)
                                .ToList();

                            gridData = flattened;
                        }

                        var pagedData = gridData.Skip((args.Request.Page - 1) * args.Request.PageSize).Take(args.Request.PageSize).ToList();

                        args.Data = pagedData;
                        args.Total = (int)gridDataListReply.TotalRows;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to read items for the grid.");
            ex.Data.Add("PageMethod", "DynamicGridView/ReadItems()");
            OnError(ex);
        }
    }

    #endregion Protected Methods

    #region Private Methods

    private List<Guid> GetSelectedTransactionGuids()
    {
        var result = new List<Guid>();

        if (SelectedItems == null || SelectedItems.Count == 0)
            return result;

        foreach (var item in SelectedItems)
        {
            if (item is not IDictionary<string, object> row)
                continue;

            if (row.TryGetValue("CanRequeue", out var canRequeueValue))
            {
                if (!TryConvertToBoolean(canRequeueValue, out var canRequeue) || !canRequeue)
                    continue;
            }

            if (!row.TryGetValue("TransactionGuid", out var transactionGuidValue))
                continue;

            var rawValue = transactionGuidValue?.ToString();

            if (string.IsNullOrWhiteSpace(rawValue))
                continue;

            if (!Guid.TryParse(rawValue, out var transactionGuid))
                continue;

            if (transactionGuid == Guid.Empty)
                continue;

            if (!result.Contains(transactionGuid))
                result.Add(transactionGuid);
        }

        return result;
    }

    private static bool TryConvertToBoolean(object? value, out bool result)
    {
        result = false;

        if (value is null)
            return false;

        if (value is bool boolValue)
        {
            result = boolValue;
            return true;
        }

        var text = value.ToString();

        if (string.IsNullOrWhiteSpace(text))
            return false;

        if (bool.TryParse(text, out var parsedBool))
        {
            result = parsedBool;
            return true;
        }

        if (int.TryParse(text, out var parsedInt))
        {
            result = parsedInt != 0;
            return true;
        }

        return false;
    }

    private async Task RequeueSelectedSageSubmissionsAsync()
    {
        if (!IsSageSubmissionMonitorView || IsBulkProcessing || IsRequeueingSageSubmission)
            return;

        var transactionGuids = GetSelectedTransactionGuids();

        if (transactionGuids.Count == 0)
        {
            await JsRuntime.InvokeVoidAsync(
                "alert",
                "Please select at least one retryable Sage submission row.");
            return;
        }

        var confirmed = await JsRuntime.InvokeAsync<bool>(
            "confirm",
            $"Requeue {transactionGuids.Count} Sage submission record(s)? Previous attempt history will be retained.");

        if (!confirmed)
            return;

        try
        {
            IsRequeueingSageSubmission = true;
            StateHasChanged();

            var request = new TransactionSageSubmissionRequeueRequest();
            request.TransactionGuids.AddRange(transactionGuids.Select(x => x.ToString()));

            var reply = await coreClient.TransactionSageSubmissionRequeueAsync(request);

            SelectedItems = new List<ExpandoObject>();
            ListSelectedItems = new List<ExpandoObject>();

            await reloadGridData();

            if (OnSelectedItemsChanged.HasDelegate)
                await OnSelectedItemsChanged.InvokeAsync(SelectedItems);

            if (OnActionCompleted.HasDelegate)
                await OnActionCompleted.InvokeAsync();

            Toast.ShowSuccess(
                string.IsNullOrWhiteSpace(reply.Message)
                    ? $"{reply.RequeuedTransactionCount} Sage submission(s) requeued."
                    : reply.Message);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while requeueing Sage submissions from the batch grid.");
            ex.Data.Add("PageMethod", "DynamicBatchGridView/RequeueSelectedSageSubmissionsAsync()");
            await OnError(ex);
        }
        finally
        {
            IsRequeueingSageSubmission = false;
            StateHasChanged();
        }
    }

    private void GroupByButton()
    {
        if (GroupByColumn)
            QuickFilterGroupByCSS = "";
        else
            QuickFilterGroupByCSS = "activeButton";

        GroupByColumn = !GroupByColumn;

        StateHasChanged();
        GridRef.Rebind();
    }

    private void ShowRecordsFromXDay(int days)
    {
        if (showCustomRange) showCustomRange = false;

        customStartDate = null;
        customEndDate = null;
        RangeFilters = null;

        if (ActiveQuickFilterDays == days)
        {
            ActiveQuickFilterDays = null;
            QuickFilter7DaysCSS = "";
            QuickFilter90DaysCSS = "";
            QuickFilters = null;

            StateHasChanged();
            GridRef.Rebind();

            return;
        }
        else if (RangeFilters != null)
        {
            RangeFiltersActive = false;
            RangeFilters = null;

            GridRef.Rebind();
        }

        Thread.Sleep(1000);

        ActiveQuickFilterDays = days;

        QuickFilter7DaysCSS = "";
        QuickFilter90DaysCSS = "";

        if (days == -7)
            QuickFilter7DaysCSS = "activeButton";
        else if (days == -90)
            QuickFilter90DaysCSS = "activeButton";

        var customFilter = new DataCompositeFilter
        {
            LogicalOperator = "AND"
        };

        DateTime startDate = DateTime.Today.AddDays(days);
        DateTime endDate = DateTime.Today;

        var dateRangeFilter = new DataCompositeFilter
        {
            LogicalOperator = "AND"
        };

        dateRangeFilter.Filters.Add(new DataFilter
        {
            ColumnName = CreatedOnColumn,
            Operator = "ge",
            Guid = Guid.NewGuid().ToString(),
            Value = Value.ForString(startDate.ToString("yyyy-MM-dd"))
        });

        dateRangeFilter.Filters.Add(new DataFilter
        {
            ColumnName = CreatedOnColumn,
            Operator = "le",
            Guid = Guid.NewGuid().ToString(),
            Value = Value.ForString(endDate.ToString("yyyy-MM-dd"))
        });

        customFilter.CompositeFilters.Add(dateRangeFilter);

        QuickFilters = customFilter;

        StateHasChanged();
        GridRef.Rebind();
    }

    private void ApplyCustomRange()
    {
        try
        {
            if (customStartDate is null || customStartDate is null)
            {
                throw (new Exception("Both the start and end date must be set. Please, try again."));
            }
            else
            {
                var customFilter = new DataCompositeFilter
                {
                    LogicalOperator = "AND"
                };

                DateOnly startDate = (DateOnly)customStartDate;
                DateOnly endDate = (DateOnly)customEndDate;

                var dateRangeFilter = new DataCompositeFilter
                {
                    LogicalOperator = "AND"
                };

                dateRangeFilter.Filters.Add(new DataFilter
                {
                    ColumnName = CreatedOnColumn,
                    Operator = "ge",
                    Guid = Guid.NewGuid().ToString(),
                    Value = Value.ForString(startDate.ToString("yyyy-MM-dd"))
                });

                dateRangeFilter.Filters.Add(new DataFilter
                {
                    ColumnName = CreatedOnColumn,
                    Operator = "le",
                    Guid = Guid.NewGuid().ToString(),
                    Value = Value.ForString(endDate.ToString("yyyy-MM-dd"))
                });

                customFilter.CompositeFilters.Add(dateRangeFilter);

                RangeFilters = customFilter;

                StateHasChanged();
                GridRef.Rebind();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine(ex.ToString());
        }
    }

    private void ToggleCustomRange()
    {
        if (ActiveQuickFilterDays != null)
        {
            ShowRecordsFromXDay(ActiveQuickFilterDays.Value);
        }

        showCustomRange = !showCustomRange;

        if (RangeFilters != null)
            RangeFilters = null;

        GridRef.Rebind();
    }

    private async Task OrderData(string val)
    {
        const string SentDesc = "SentDate_desc";
        const string SentAsc = "SentDate_asc";
        const string AmountDesc = "Amount_desc";
        const string AmountAsc = "Amount_asc";

        SelectedSortBy = val;

        string member = "";
        ListSortDirection direction = ListSortDirection.Ascending;

        if (GridRef != null)
        {
            var gridState = GridRef.GetState();

            if (val == "" | val == null)
            {
                gridState.SortDescriptors.Clear();
                await GridRef.SetStateAsync(gridState);
                return;
            }

            gridState.SortDescriptors.Clear();

            switch (SelectedSortBy)
            {
                case SentAsc:
                    member = "Date";
                    direction = ListSortDirection.Ascending;
                    break;

                case SentDesc:
                    member = "Date";
                    direction = ListSortDirection.Descending;
                    break;

                case AmountDesc:
                    member = "TotalNet";
                    direction = ListSortDirection.Descending;
                    break;

                case AmountAsc:
                    member = "TotalNet";
                    direction = ListSortDirection.Ascending;
                    break;
            }

            if (member != "")
            {
                gridState.SortDescriptors.Add(new GroupDescriptor()
                {
                    Member = member,
                    SortDirection = direction
                });

                await GridRef.SetStateAsync(gridState);
            }
        }
    }

    private Task<GridState<ExpandoObject>> CalcGridStateAsync()
    {
        try
        {
            if (ViewDefinition == null) return Task.FromResult(new GridState<ExpandoObject>());
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
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to calculate the grid state.");
            ex.Data.Add("PageMethod", "DynamicGridView/CalcGridState()");
            OnError(ex);
        }
        return Task.FromResult(new GridState<ExpandoObject>());
    }

    private async void CancelBulkEdit()
    {
        IsBulkProcessing = false;
        SelectedItems = new List<ExpandoObject>();

        isBulkRecordChangeVisible = false;
        WindowIsVisible = false;
        await CloseWindow();
    }

    private void OnRowRenderHandler(GridRowRenderEventArgs args)
    {
        try
        {
            if (args.Item is IDictionary<string, object> dict &&
                dict.TryGetValue("Guid", out var guidValue))
            {
                if (guidValue == null ||
                    !Guid.TryParse(guidValue.ToString(), out var parsedGuid) ||
                    parsedGuid == Guid.Empty)
                {
                    args.Class = "invalid-row";
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to render a row in the grid.");
            ex.Data.Add("PageMethod", "DynamicGridView/OnRowRenderHandler()");
            OnError(ex);
        }
    }

    private void OnRowClickHandler(GridRowClickEventArgs args)
    {
        var item = args.Item as IDictionary<string, object>;
        if (item != null && item.TryGetValue("Guid", out var guidValue))
        {
            if (guidValue == null || !Guid.TryParse(guidValue?.ToString(), out var parsedGuid) || parsedGuid == Guid.Empty)
            {
                OnError(new Exception("This row is invalid and cannot be selected."));
            }
        }
    }

    private void OnRowDoubleClickHandler(GridRowClickEventArgs args)
    {
        try
        {
            var onRowDoubleClickHandler = !string.IsNullOrEmpty(ViewDefinition?.DetailPageUri) ? "@OnRowDoubleClickHandler" : null;
            if (onRowDoubleClickHandler == null) return;
            dynamic model = args.Item;
            if (ViewDefinition == null) return;

            string parentGuid = model.Guid;
            if (model.Guid == Guid.Empty.ToString()) return;

            var isParentDataObjectReferenceDifferent = ParentDataObjectReference.EntityTypeGuid.ToString() != ViewDefinition.EntityTypeGuid;

            var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, parentGuid, ViewDefinition.EntityTypeGuid);

            if (ViewDefinition.IsDetailWindowed)
            {
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
                string guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(model.Guid).ToString();
                string uri = System.Web.HttpUtility.UrlEncode(NavManager.Uri);
                string url = ViewDefinition.DetailPageUri + "/" + guid + "/" + serializedParentDataObjectReference + "/" + uri;

                if (ViewDefinition.DetailPageUri == "DynamicEdit")
                    NavManager.NavigateTo(ViewDefinition.DetailPageUri + "/" + PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString() + "/" + parentDataObjectReference.DataObjectGuid + "/" +
                                          serializedParentDataObjectReference + "/" + System.Web.HttpUtility.UrlEncode(NavManager.Uri));
                else if (isParentDataObjectReferenceDifferent)
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
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to handle a double click event in the grid.");
            ex.Data.Add("PageMethod", "DynamicGridView/OnRowDoubleClickHandler()");
            OnError(ex);
        }
    }

    private async Task MoveNext()
    {
        if (!SelectedItems.Any())
        {
            OnError(new Exception("No items selected for bulk update.")
            {
                Data = { ["MessageType"] = MessageDisplay.ShowMessageType.Warning }
            });
            return;
        }

        ListSelectedItems = SelectedItems.ToList();
        EntityTypeGuid = ParentDataObjectReference.EntityTypeGuid != Guid.Empty ? ParentDataObjectReference.EntityTypeGuid : Guid.Empty;

        if (ViewDefinition?.IsDetailWindowed == true)
        {
            var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(
                modalService, ParentDataObjectReference, ParentGuid, ViewDefinition.EntityTypeGuid);

            modalId = Guid.NewGuid().ToString();
            _detailPageParameters = new Dictionary<string, object>
            {
                { "EntityTypeGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString() },
                { "Windowed", true },
                { "CloseWindow", EventCallback.Factory.Create(this, CloseWindow) },
                { "RecordGuid", Guid.Empty.ToString() },
                { "GridUpdated", EventCallback.Factory.Create(this, GridUpdated) },
                { "SerializedDataObjectReference", serializedParentDataObjectReference },
                { "ParentDataObjectReference", parentDataObjectReference },
                { "ModalId", modalId },
                { "SelectedItems", ListSelectedItems },
                { "IsDetailWindowed", true },
                { "IsBulkUpdate", true }
            };

            modalService.RegisterModal(modalId, parentDataObjectReference);

            isBulkRecordChangeVisible = true;
            WindowIsVisible = false;

            StateHasChanged();
        }
    }

    private async Task OnGridStateChanged(GridStateEventArgs<ExpandoObject> args)
    {
        try
        {
            var gridStateToSave = new FilterAndSortSetting()
            {
                code = ViewDefinition.Code,
                gridCode = GridCode,
                filterDescriptor = args.GridState.FilterDescriptors,
                sortDescriptor = args.GridState.SortDescriptors
            };

            if (gridStateToSave.filterDescriptor.Count < 2)
            {
                var filterExists = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_gridState");

                if (filterExists != null)
                    await LocalStorageAccessor.RemoveAsync($"{ViewDefinition.Code}_gridState");
            }
            else
            {
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

            GridStateString = JsonSerializer.Serialize(args.GridState, new JsonSerializerOptions() { WriteIndented = true })
                .Replace($"\"{GridStateChangedProperty}\"", $"\"<strong class='latest-changed-property'>{GridStateChangedProperty}</strong>\"");

            if (_operationsWithMultipleStateChanged.Contains(GridStateChangedProperty))
            {
                DoubleStateChanged = true;
                GridStateChangedPropertyClass = "first-of-two";
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to handle a grid state change.");
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

                var savedPageNumber = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_currentPageNumber");
                int pageNum;
                if (savedPageNumber != null)
                {
                    if (Int32.TryParse(savedPageNumber, out pageNum))
                    {
                        state.Page = pageNum;
                    }
                }

                var isGradeStateSaved = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_gridState");

                if (isGradeStateSaved != null && FullGrid)
                {
                    FilterAndSortSetting gridSetting = JsonSerializer.Deserialize<FilterAndSortSetting>(isGradeStateSaved);

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

    private async Task RebindGrid()
    {
        try
        {
            GridRef?.Rebind();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to rebind the grid.");
            ex.Data.Add("PageMethod", "DynamicGridView/RebindGrid()");
            OnError(ex);
        }
    }

    private async Task reloadGridData()
    {
        SelectedItems = new List<ExpandoObject>();
        await RefreshMe();
    }

    private void ScrollToTop()
    {
        JsRuntime.InvokeVoidAsync("window.scrollTo", 0, 0);
    }

    private async void SelectedItemsChanged(IEnumerable<ExpandoObject> items)
    {
        SelectedItems = items?.ToList() ?? new List<ExpandoObject>();
        SortGridAfterSelection();

        ShowInvoiceMergeButton = CanInvoiceRequestRecordsBeMerged(SelectedItems);

        Console.WriteLine("# of selected items for merge => " + SelectedItems.Count);

        if (OnSelectedItemsChanged.HasDelegate)
            await OnSelectedItemsChanged.InvokeAsync(SelectedItems);

        StateHasChanged();
    }

    private async void SortGridAfterSelection()
    {
        gridData = gridData.OrderByDescending(item => SelectedItems.Contains(item)).ToList();
        GridRef?.Rebind();
    }

    private void WindowVisibleChangedHandler(bool currVisible)
    {
        if (WindowIsClosable)
            WindowIsVisible = currVisible;
        else
            Console.WriteLine("The user tried to close the window but the code didn't let them");
    }

    #endregion Private Methods

    #region Private Classes

    private class FilterAndSortSetting
    {
        public string code { get; set; }
        public ICollection<IFilterDescriptor> filterDescriptor { get; set; }
        public string gridCode { get; set; }
        public ICollection<SortDescriptor> sortDescriptor { get; set; }
    }

    #endregion Private Classes
}