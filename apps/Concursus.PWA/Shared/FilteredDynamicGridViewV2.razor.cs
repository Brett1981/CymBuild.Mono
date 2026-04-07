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
using static Concursus.API.Core.Core;
using static Concursus.PWA.Shared.MessageDisplay;
using JsonSerializer = System.Text.Json.JsonSerializer;




namespace Concursus.PWA.Shared;

public partial class FilteredDynamicGridViewV2 : ComponentBase
{
    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = "";
    [Parameter] public EventCallback<InputUpdatedArgs> inputUpdated { get; set; }
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public bool DoubleClickDisabled { get; set; } = false;
    [Parameter] public bool Disabled { get; set; } = false;
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


    public bool HasChanges { get; private set; } = false;


    //Status indicator messages.
    private string RedIndicator { get; set; } = "";
    private string GreenIndicator { get; set; } = "";
    private string OrangeIndicator { get; set; } = "";



    #region Public Methods




    /// <summary>
    /// Gets the quote threshold, which is used to highlight
    /// rows where the amount is greated than the threshold threshold.
    /// </summary>
    /// <returns>Awaitable</returns>
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

    /// <summary>
    /// In this case, it is used to get the configuration for the viewdefinition
    /// to make it dynamic.
    /// </summary>
    /// <returns></returns>
    protected override async Task OnInitializedAsync()
    {
        await base.OnInitializedAsync();

        try
        {
            if (ViewDefinition is not null)
            {
                CreatedOnColumn = _viewDefinition.FilteredListCreatedOnColumn;
                RedIndicator = _viewDefinition.FilteredListRedStatusIndicatorTxt;
                GreenIndicator = _viewDefinition.FilteredListGreenStatusIndicatorTxt;
                OrangeIndicator = _viewDefinition.FilteredListOrangeStatusIndicatorTxt;
                GroupBy = _viewDefinition.FilteredListGroupBy;

                if (GroupBy == "OrgUnit")
                {
                    GroupByColumTranslation = "Organisation Unit";
                }

                // Existing KPI logic (invoicing) - keep
                await GetKPIValues();

                // NEW: Authorisation KPI logic (AUTHOREVIEW only)
                //if (IsClosureReviewQueueGrid)
                //{
                //    await RefreshAuthorisationKpisAsync(force: true);
                //    StateHasChanged();
                //}
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "FilteredDynamicGridViewV2/OnInitializedAsync()");
            OnError(ex);
        }

        await GetQuoteThreshold();
    }

    protected async Task ReadItems(GridReadEventArgs args)
    {
        _authorisationIsUpdating = true;
        await InvokeAsync(StateHasChanged);

        try
        {
            if (ViewDefinition == null)
                return;

            var pageNum = args.Request.Page;
            var savedPageNum = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_currentPageNumber");

            if (ComingFromModal && !string.IsNullOrWhiteSpace(savedPageNum) && int.TryParse(savedPageNum, out var parsedPage))
                pageNum = parsedPage;

            var gridDataListRequest = new GridDataListRequest
            {
                GridCode = GridCode,
                GridViewCode = ViewDefinition.Code,
                Page = pageNum,
                PageSize = args.Request.PageSize,
                ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString()
            };

            if (gridDataListRequest.ParentGuid == Guid.Empty.ToString() && !FullGrid)
                return;

            await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_currentPageNumber", args.Request.Page);

            // ---------------------------------------------------------------------
            // FILTERS: always create a fresh root filter with lowercase operators
            // ---------------------------------------------------------------------
            var root = new DataCompositeFilter { LogicalOperator = "and" };

            // 1) Kendo column filters
            var kendo = API.Client.TypeHelpers.GridDataCompositeFilterFromKendoFilterDescriptor(args.Request.Filters);
            if (HasAnyFilterContent(kendo))
            {
                // Ensure lowercase (defensive). If your helper already emits "and"/"or", this does nothing.
                kendo.LogicalOperator = NormaliseLogicalOperator(kendo.LogicalOperator);
                root.CompositeFilters.Add(kendo);
            }

            // 2) Quick filters
            if (HasAnyFilterContent(QuickFilters))
            {
                QuickFilters.LogicalOperator = NormaliseLogicalOperator(QuickFilters.LogicalOperator);
                root.CompositeFilters.Add(QuickFilters);
            }

            // 3) Range filters
            if (HasAnyFilterContent(RangeFilters))
            {
                RangeFilters.LogicalOperator = NormaliseLogicalOperator(RangeFilters.LogicalOperator);
                root.CompositeFilters.Add(RangeFilters);
            }

            // 4) AUTHOREVIEW filters (type + my items)
            if (IsClosureReviewQueueGrid && HasAnyFilterContent(AuthorisationFilters))
            {
                AuthorisationFilters.LogicalOperator = NormaliseLogicalOperator(AuthorisationFilters.LogicalOperator);
                root.CompositeFilters.Add(AuthorisationFilters);
            }

            if (HasAnyFilterContent(root))
            {
                gridDataListRequest.Filters.Add(root);
                LogCompositeFilter(root);
            }

            // ---------------------------------------------------------------------
            // SORTS
            // ---------------------------------------------------------------------
            gridDataListRequest.Sort.AddRange(
                API.Client.TypeHelpers.GridDataSortFromKendoSortDescriptor(args.Request.Sorts));

            // ---------------------------------------------------------------------
            // DATA
            // ---------------------------------------------------------------------
            var gridDataListReply = await coreClient.GridDataListAsync(gridDataListRequest);

            var gridData = new List<ExpandoObject>();

            foreach (var r in gridDataListReply.DataTable)
            {
                dynamic dataObj = new ExpandoObject();
                var dictionary = (IDictionary<string, object>)dataObj;

                foreach (var c in r.Columns)
                {
                    var name = c.Name;
                    var value = FormatGridColumnValue(name, c.Value);
                    dictionary[name] = value;
                }

                gridData.Add(dataObj);
            }

            //Update the KPI from here.
            if (IsClosureReviewQueueGrid)
            {
                await RefreshAuthorisationKpisAsync(force: true);
                StateHasChanged();
            }

            gridData = GroupByField(gridData);

            args.Data = gridData;
            args.Total = (int)gridDataListReply.TotalRows;
            CurrentGridItems = gridData;

            if (ComingFromModal)
            {
                ComingFromModal = false;
                _ = InvokeAsync(() => GridRef?.Rebind());
            }
        }
        catch (OperationCanceledException)
        {
            // Expected when user clicks quickly / cancels
            return;
        }
        catch (Grpc.Core.RpcException ex) when (ex.StatusCode == Grpc.Core.StatusCode.Cancelled)
        {
            // Expected when client cancels in-flight gRPC calls
            return;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "FilteredDynamicGridViewV2/ReadItems()");
            OnError(ex);
        }
        finally
        {
            _authorisationIsUpdating = false;
            await InvokeAsync(StateHasChanged);
        }
    }

    private static bool HasAnyFilterContent(DataCompositeFilter? f)
    {
        if (f is null) return false;

        var hasFilters = f.Filters != null && f.Filters.Count > 0;
        var hasComposites = f.CompositeFilters != null && f.CompositeFilters.Count > 0;

        return hasFilters || hasComposites;
    }

    private static string NormaliseLogicalOperator(string op)
    {
        // Defensive: your SQL builder likely expects lowercase
        if (string.IsNullOrWhiteSpace(op)) return "and";
        op = op.Trim();
        return op.Equals("or", StringComparison.OrdinalIgnoreCase) ? "or" : "and";
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

    /// <summary>
    /// Refreshes/rebinds the grid.
    /// </summary>
    /// <returns></returns>
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

    /// <summary>
    /// Helper function to format grid column values correctly
    /// </summary>
    /// <param name="columnName"></param>
    /// <param name="value"></param>
    /// <returns></returns>
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

    /// <summary>
    /// Helper function ensuring phone number is displayed properly.
    /// </summary>
    /// <param name="columnName"></param>
    /// <param name="columnValue"></param>
    /// <returns></returns>
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
    /// Function in which we highlight rows based on two things: Threshold (set for the org unit) and the user's org unit.
    /// This means, if the user is part of "CDM", only CDM jobs should be highlighted.
    /// </summary>
    /// <param name="args"></param>
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


    /// <summary>
    /// Mainly used to apply saved filtering & page number (accessed by LocalStorageAccessor)
    /// which then gets applied to the grid.
    /// </summary>
    /// <param name="args"></param>
    /// <returns></returns>
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