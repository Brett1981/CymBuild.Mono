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
using static Concursus.PWA.Shared.MessageDisplay;
using JsonSerializer = System.Text.Json.JsonSerializer;

namespace Concursus.PWA.Shared;

public partial class FilteredDynamicGridView : ComponentBase
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

    #endregion Private Fields

    #region Public Properties

    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = "";
    public bool HasChanges { get; private set; } = false;
    [Parameter] public EventCallback<InputUpdatedArgs> inputUpdated { get; set; }

    [Parameter]
    public EventCallback OnActionCompleted { get; set; }

    // [Parameter] public EventCallback<Exception> OnError { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");

    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();

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

    #endregion Public Properties

    #region Protected Properties

    protected string ErrorMessage { get; set; } = "";
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";
    protected FormHelper? formHelper;

    #endregion Protected Properties

    #region Private Properties

    private bool BatchGridVisible { get; set; } = false;
    private IEnumerable<ExpandoObject>? CurrentGridItems { get; set; } // Exposes the grid data
    private bool DoubleStateChanged { get; set; }
    private TelerikGrid<ExpandoObject>? GridRef { get; set; }
    private string GridStateChangedProperty { get; set; } = string.Empty;
    private string GridStateChangedPropertyClass { get; set; } = string.Empty;
    private string GridStateString { get; set; } = string.Empty;
    private int OnStateChangedCount { get; set; }
    private bool ComingFromModal { get; set; } = false;

    //Shows the custom range section
    private bool showCustomRange { get; set; } = false;

    //Custom start date
    private DateOnly? customStartDate { get; set; }

    //Custom end date
    private DateOnly? customEndDate { get; set; }

    //==============================================
    //=             QUICK FILTERS                  =
    //==============================================
    private int? ActiveQuickFilterDays = null;

    private DataCompositeFilter QuickFilters { get; set; }
    private bool QuickFilterActive { get; set; } = false;
    private string QuickFilter7DaysCSS { get; set; } = "";
    private string QuickFilter90DaysCSS { get; set; } = "";

    //==============================================
    //=             RANGE FILTERS                  =
    //==============================================
    private DataCompositeFilter RangeFilters { get; set; }

    private bool RangeFiltersActive { get; set; } = false;

    //==============================================
    //=             GROUP BY FILTERS               =
    //==============================================
    private class OrderByItem
    {
        public string Id { get; set; }
        public string Text { get; set; } = string.Empty;
    }

    private string SelectedSortBy { get; set; }

    private IEnumerable<OrderByItem> GroupByOptions { get; set; } = new List<OrderByItem>
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

    private string RedIndicator { get; set; } = "";
    private string GreenIndicator { get; set; } = "";
    private string OrangeIndicator { get; set; } = "";

    private double Threshold { get; set; } = -1; //Set it to -1 for now.
    private int OrganisationalUnitID { get; set; } = -1;

    #endregion Private Properties

    #region Public Methods

  

    /// <summary>
    /// Gets the quote threshold, which is used to highlight rows where the amount &gt;= threshold.
    /// </summary>
    /// <returns> Awaitable </returns>
    private async Task GetQuoteThreshold()
    {
        formHelper = new FormHelper(coreClient, sageIntegrationService, Guid.Empty.ToString(), userService);

        //Get the threshold first.
        var QuoteThresholdReq = await coreClient.GetThresholdsForOrgUnitAsync(new GetQuoteThresholdReq() { UserId = userService.UserId });
        Threshold = QuoteThresholdReq.QuoteThreshold;

        //Next, get the organisation unit ID.
        var UnitId = await formHelper.GetOrganisationalUnitForUser(userService.UserId);

        if (UnitId != null)
        {
            OrganisationalUnitID = UnitId;
            Console.WriteLine($"Got threshold -> {Threshold} and Organisational Unit => {OrganisationalUnitID}");
        }
    }

    protected override async Task OnInitializedAsync()
    {

        if (ViewDefinition is not null)
        {
            RedIndicator = _viewDefinition.FilteredListRedStatusIndicatorTxt;
            GreenIndicator = _viewDefinition.FilteredListGreenStatusIndicatorTxt;
            OrangeIndicator = _viewDefinition.FilteredListOrangeStatusIndicatorTxt;
        }
      

        await base.OnInitializedAsync();
        await GetQuoteThreshold();
    }

    /// <summary>
    /// Returns records from the last X days (where X is the input)
    /// </summary>
    /// <param name="days"> Number of days to back (minus int) </param>
    private void ShowRecordsFromXDay(int days)
    {
        //Hide the range section if already show.
        if (showCustomRange) showCustomRange = false;

        //Ensure Range filters are reset.
        customStartDate = null;
        customEndDate = null;
        RangeFilters = null;

        // If the same button is pressed again → deactivate
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

        //Allows the grid to rebind.
        Thread.Sleep(1000);

        // Otherwise, activate this filter
        ActiveQuickFilterDays = days;

        // Reset both buttons
        QuickFilter7DaysCSS = "";
        QuickFilter90DaysCSS = "";

        // Apply CSS class based on which button was clicked
        if (days == -7)
            QuickFilter7DaysCSS = "activeButton";
        else if (days == -90)
            QuickFilter90DaysCSS = "activeButton";

        // Build the filter
        var customFilter = new DataCompositeFilter
        {
            LogicalOperator = "AND"
        };

        //Set the ranges as DateTime
        DateTime startDate = DateTime.Today.AddDays(days);
        DateTime endDate = DateTime.Today;

        var dateRangeFilter = new DataCompositeFilter
        {
            LogicalOperator = "AND"
        };

        // >= startDate
        dateRangeFilter.Filters.Add(new DataFilter
        {
            ColumnName = "Date",
            Operator = "ge",
            Guid = Guid.NewGuid().ToString(),
            Value = Value.ForString(startDate.ToString("yyyy-MM-dd"))
        });

        // <= endDate
        dateRangeFilter.Filters.Add(new DataFilter
        {
            ColumnName = "Date",
            Operator = "le",
            Guid = Guid.NewGuid().ToString(),
            Value = Value.ForString(endDate.ToString("yyyy-MM-dd"))
        });

        customFilter.CompositeFilters.Add(dateRangeFilter);

        QuickFilters = customFilter;

        StateHasChanged();
        GridRef.Rebind();
    }

    /// <summary>
    /// Applies a custom range from which records should be returned.
    /// </summary>
    private void ApplyCustomRange()
    {
        //Throw an error message if either the start or end date is not set.
        if (customStartDate is null || customStartDate is null)
        {
            Exception ex = new Exception("Both the start and end date must be set. Please, try again.");
            OnError(ex);
        }
        else
        {
            // Build the filter
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

            // FROM
            dateRangeFilter.Filters.Add(new DataFilter
            {
                ColumnName = "Date",
                Operator = "ge",
                Guid = Guid.NewGuid().ToString(),
                Value = Value.ForString(startDate.ToString("yyyy-MM-dd"))
            });

            // TO
            dateRangeFilter.Filters.Add(new DataFilter
            {
                ColumnName = "Date",
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

    /// <summary>
    /// Hides/shows the custom range section where a date range can be set.
    /// </summary>
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

    /// <summary>
    /// Used by the dropdown to order the search result.
    /// </summary>
    /// <param name="val"> The value to filter by </param>
    /// <returns> </returns>
    private async Task GroupData(string val)
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

    protected async Task ReadItems(GridReadEventArgs args)
    {
        try
        {
            if (ViewDefinition == null) return;

            //await EnsureCorrectParentGuid(); // Ensure Parent GUID is properly set before API calls

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
            await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_currentPageNumber", args.Request.Page);

            // Ensure we handle single `DataCompositeFilter` properly
            var compositeFilter = API.Client.TypeHelpers.GridDataCompositeFilterFromKendoFilterDescriptor(args.Request.Filters);

            //Check for quick filters
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

    // Optimized Grid Updated function to refresh UI efficiently
    protected async Task GridUpdated()
    {
        try
        {
            //CBLD-683
            if (!ComingFromModal)
            {
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

    #endregion Protected Methods

    #region Private Methods



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

            //OE: Fix for CBLD-331
            //string guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(model.Guid).ToString();
            //string urlEncode = System.Web.HttpUtility.UrlEncode(NavManager.Uri);
            //string sPDOR = serializedParentDataObjectReference;
            //string uri = System.Web.HttpUtility.UrlEncode(NavManager.Uri);
            //string url = ViewDefinition.DetailPageUri + "/" + guid + "/" + serializedParentDataObjectReference + "/" + uri;

            //CBLD-771
            // Step 1: Parse safe GUID
            string guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(model.Guid).ToString();

            // Step 2: Serialized reference should already be encoded (confirm this!)
            string sPDOR = serializedParentDataObjectReference;

            // Step 3: ENCODE the full URL you are appending
            string uri = System.Web.HttpUtility.UrlEncode(NavManager.Uri);

            // Step 4: Combine
            string url = $"{ViewDefinition.DetailPageUri}/{guid}/{sPDOR}/{uri}";

            if (ViewDefinition.DetailPageUri == "DynamicEdit")
                NavManager.NavigateTo(ViewDefinition.DetailPageUri + "/" + PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString() + "/" + parentDataObjectReference.DataObjectGuid + "/" +
                                      serializedParentDataObjectReference + "/" + System.Web.HttpUtility.UrlEncode(NavManager.Uri));
            else

            if (isParentDataObjectReferenceDifferent)
            {
                //CLD-611
                //Page not refreshing (url does change though) when we try to go to the same record type through the history tab in a modal
                var navigateToDetailPage = "/" + ViewDefinition.DetailPageUri + "/";
                var currentUri = NavManager.Uri;

                if (currentUri.Contains(navigateToDetailPage))
                {
                    NavManager.NavigateTo(url, true);
                }
                else
                {
                    NavManager.NavigateTo(url, false);
                }
            }
            else
            {
                NavManager.NavigateTo(url, true);
            }
            InteractionTracker.Log(NavManager.Uri, $"User Double Clicked Row in Grid - '{ViewDefinition?.Name ?? "Unknown"}' New Page Opened: '{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition?.EntityTypeGuid ?? "No Guid").ToString()}'");

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

    /// <summary>
    /// Function in which we highlight rows based on two things: Threshold (set for the org unit)
    /// and the user's org unit. This means, if the user is part of "CDM", only CDM jobs should be highlighted.
    /// </summary>
    /// <param name="args"> </param>
    private void OnRowRenderHandler(GridRowRenderEventArgs args)
    {
        //Match the organisational unit / row.
        var OrgUnitAsString = "";

        switch (OrganisationalUnitID)
        {
            case 2:
                OrgUnitAsString = "Building and Real Estate";
                break;

            case 3:
                OrgUnitAsString = "CDM Consulting";
                break;

            case 8:
                OrgUnitAsString = "Building & Real Estate Admin";
                break;

            case 10:
                OrgUnitAsString = "Building Control Consultancy";
                break;
        }

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

        //Check the threshold is above 1 at minimum.
        if (Threshold > 1)
        {
            //Now, get the net amount for the row.
            if (row.TryGetValue("TotalNet", out var net))
            {
                //Get the organisational unit ID.
                if (row.TryGetValue("OrganisationalUnitName", out var OrgUnit))
                {
                    if (OrgUnit.ToString() == OrgUnitAsString)
                    {
                        var valAsString = net?.ToString();
                        if (decimal.TryParse(valAsString, out var n))
                        {
                            if ((double)n >= Threshold)
                                args.Class = "OverThreshold";
                        }
                    }
                }
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


    private void ScrollToTop()
    {
        // Scroll to the top of the page
        JsRuntime.InvokeVoidAsync("window.scrollTo", 0, 0);
        InteractionTracker.Log(NavManager.Uri, $"Back To Top Clicked");
    }

    #endregion Private Methods

    #region Private Classes

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