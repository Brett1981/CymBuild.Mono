using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.JSInterop;
using System.Collections;
using System.Dynamic;
using System.Text.Json;
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
        set => _viewDefinition = value;
    }

    public bool HasChanges { get; private set; } = false;

    // Status indicator messages.
    private string RedIndicator { get; set; } = "";
    private string GreenIndicator { get; set; } = "";
    private string OrangeIndicator { get; set; } = "";

    #region Lifecycle

    protected override async Task OnInitializedAsync()
    {
        await base.OnInitializedAsync();

        try
        {
            ApplyViewDefinitionSettings();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "FilteredDynamicGridViewV2/OnInitializedAsync()");
            await OnError(ex);
        }

        await GetQuoteThreshold();
    }

    protected override async Task OnParametersSetAsync()
    {
        await base.OnParametersSetAsync();

        try
        {
            if (ViewDefinition is null)
                return;

            ApplyViewDefinitionSettings();

            var parameterKey = $"{GridCode}|{ViewDefinition.Code}|{ParentGuid}|{FullGrid}";
            if (!string.Equals(_nativeGridParameterKey, parameterKey, StringComparison.Ordinal))
            {
                _nativeGridParameterKey = parameterKey;
                InitialiseNativeSortFromViewDefinition();
                await RestoreNativeGridStateAsync();

                if (IsClosureReviewQueueGrid)
                {
                    await EnsureAuthorisationInitialisedAsync();
                }

                await ReloadNativeGridAsync();
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "FilteredDynamicGridViewV2/OnParametersSetAsync()");
            await OnError(ex);
        }
    }

    private void ApplyViewDefinitionSettings()
    {
        if (ViewDefinition is null)
            return;

        CreatedOnColumn = ViewDefinition.FilteredListCreatedOnColumn;
        RedIndicator = ViewDefinition.FilteredListRedStatusIndicatorTxt;
        GreenIndicator = ViewDefinition.FilteredListGreenStatusIndicatorTxt;
        OrangeIndicator = ViewDefinition.FilteredListOrangeStatusIndicatorTxt;
        GroupBy = ViewDefinition.FilteredListGroupBy;

        if (GroupBy == "OrgUnit")
        {
            GroupByColumTranslation = "Organisation Unit";
        }
    }

    #endregion Lifecycle

    #region Native Grid

    private IEnumerable<GridViewColumnDefinition> VisibleGridColumns =>
        ViewDefinition?.Columns
            .Where(o => !o.IsHidden)
            .OrderBy(o => o.ColumnOrder)
        ?? Enumerable.Empty<GridViewColumnDefinition>();

    private IEnumerable<ExpandoObject> NativeGridItems => CurrentGridItems ?? Enumerable.Empty<ExpandoObject>();

    private int NativeGridColumnCount => VisibleGridColumns.Count() + (IsClosureReviewQueueGrid ? 1 : 0);

    private int NativeTotalPages => Math.Max(1, (int)Math.Ceiling((double)Math.Max(0, NativeTotalRows) / Math.Max(1, NativePageSize)));

    private bool CanGoPreviousPage => NativePage > 1 && !NativeIsLoading;

    private bool CanGoNextPage => NativePage < NativeTotalPages && !NativeIsLoading;

    private bool HasActiveNativeColumnFilters => NativeColumnFilters.Any(f => !string.IsNullOrWhiteSpace(f.Value));

    private bool HasActiveNativeSearch => !string.IsNullOrWhiteSpace(NativeSearchText);

    private int NativeActiveFilterCount => NativeColumnFilters.Count(f => !string.IsNullOrWhiteSpace(f.Value));

    private string NativeSearchPlaceholder
    {
        get
        {
            var name = ViewDefinition?.Name;
            return string.IsNullOrWhiteSpace(name)
                ? "Search records..."
                : $"Search {name} records...";
        }
    }

    private string NativeGridSummaryText
    {
        get
        {
            if (NativeTotalRows <= 0)
                return "Showing 0 records";

            var start = ((NativePage - 1) * NativePageSize) + 1;
            var end = Math.Min(NativeTotalRows, NativePage * NativePageSize);
            return $"Showing {start} to {end} of {NativeTotalRows}";
        }
    }

    public async Task ReloadNativeGridAsync(int? requestedPage = null)
    {
        NativeIsLoading = true;

        if (IsClosureReviewQueueGrid)
        {
            _authorisationIsUpdating = true;
        }

        await InvokeAsync(StateHasChanged);

        try
        {
            if (ViewDefinition is null)
                return;

            var pageNum = requestedPage ?? NativePage;
            var savedPageNum = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_currentPageNumber");

            if (ComingFromModal && !string.IsNullOrWhiteSpace(savedPageNum) && int.TryParse(savedPageNum, out var parsedPage))
            {
                pageNum = parsedPage;
            }

            NativePage = Math.Max(1, pageNum);
            NativePageSize = Math.Max(1, NativePageSize);

            var gridDataListRequest = new GridDataListRequest
            {
                GridCode = GridCode,
                GridViewCode = ViewDefinition.Code,
                Page = NativePage,
                PageSize = NativePageSize,
                ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString()
            };

            if (gridDataListRequest.ParentGuid == Guid.Empty.ToString() && !FullGrid)
            {
                CurrentGridItems = new List<ExpandoObject>();
                NativeTotalRows = 0;
                return;
            }

            await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_currentPageNumber", NativePage);

            var root = new DataCompositeFilter { LogicalOperator = "and" };

            var columnFilters = BuildNativeColumnFilterComposite();
            if (HasAnyFilterContent(columnFilters))
            {
                root.CompositeFilters.Add(columnFilters!);
            }

            var searchFilters = BuildNativeSearchFilterComposite();
            if (HasAnyFilterContent(searchFilters))
            {
                root.CompositeFilters.Add(searchFilters!);
            }

            if (HasAnyFilterContent(QuickFilters))
            {
                QuickFilters!.LogicalOperator = NormaliseLogicalOperator(QuickFilters.LogicalOperator);
                root.CompositeFilters.Add(QuickFilters);
            }

            if (HasAnyFilterContent(RangeFilters))
            {
                RangeFilters!.LogicalOperator = NormaliseLogicalOperator(RangeFilters.LogicalOperator);
                root.CompositeFilters.Add(RangeFilters);
            }

            if (IsClosureReviewQueueGrid && HasAnyFilterContent(AuthorisationFilters))
            {
                AuthorisationFilters!.LogicalOperator = NormaliseLogicalOperator(AuthorisationFilters.LogicalOperator);
                root.CompositeFilters.Add(AuthorisationFilters);
            }

            if (HasAnyFilterContent(root))
            {
                gridDataListRequest.Filters.Add(root);
                LogCompositeFilter(root);
            }

            if (!string.IsNullOrWhiteSpace(NativeSortColumn))
            {
                gridDataListRequest.Sort.Add(new DataSort
                {
                    ColumnName = NativeSortColumn,
                    Direction = NativeSortDescending ? "Descending" : "Ascending"
                });
            }

            var gridDataListReply = await coreClient.GridDataListAsync(gridDataListRequest);
            var loadedGridData = new List<ExpandoObject>();

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

                loadedGridData.Add(dataObj);
            }

            NativeTotalRows = (int)gridDataListReply.TotalRows;

            if (NativeTotalRows > 0 && NativePage > NativeTotalPages)
            {
                NativePage = NativeTotalPages;
                await ReloadNativeGridAsync(NativePage);
                return;
            }

            CurrentGridItems = GroupByField(loadedGridData);

            if (IsClosureReviewQueueGrid)
            {
                await RefreshAuthorisationKpisAsync(force: true);
            }

            ComingFromModal = false;
        }
        catch (OperationCanceledException)
        {
            return;
        }
        catch (Grpc.Core.RpcException ex) when (ex.StatusCode == Grpc.Core.StatusCode.Cancelled)
        {
            return;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "FilteredDynamicGridViewV2/ReloadNativeGridAsync()");
            await OnError(ex);
        }
        finally
        {
            NativeIsLoading = false;

            if (IsClosureReviewQueueGrid)
            {
                _authorisationIsUpdating = false;
            }

            await InvokeAsync(StateHasChanged);
        }
    }

    private DataCompositeFilter? BuildNativeColumnFilterComposite()
    {
        var composite = new DataCompositeFilter { LogicalOperator = "and" };

        foreach (var filter in NativeColumnFilters.Where(f => !string.IsNullOrWhiteSpace(f.Value)))
        {
            composite.Filters.Add(new DataFilter
            {
                ColumnName = filter.Key,
                Operator = "contains",
                Guid = Guid.NewGuid().ToString(),
                Value = Value.ForString(filter.Value.Trim())
            });
        }

        return HasAnyFilterContent(composite) ? composite : null;
    }

    private DataCompositeFilter? BuildNativeSearchFilterComposite()
    {
        if (string.IsNullOrWhiteSpace(NativeSearchText))
            return null;

        var composite = new DataCompositeFilter { LogicalOperator = "or" };
        var searchValue = NativeSearchText.Trim();

        foreach (var column in VisibleGridColumns
                     .Where(c => !string.IsNullOrWhiteSpace(c.Name))
                     .Select(c => c.Name)
                     .Distinct(StringComparer.OrdinalIgnoreCase))
        {
            composite.Filters.Add(new DataFilter
            {
                ColumnName = column,
                Operator = "contains",
                Guid = Guid.NewGuid().ToString(),
                Value = Value.ForString(searchValue)
            });
        }

        return HasAnyFilterContent(composite) ? composite : null;
    }

    private void InitialiseNativeSortFromViewDefinition()
    {
        if (ViewDefinition is null)
            return;

        if (!string.IsNullOrWhiteSpace(NativeSortColumn))
            return;

        NativeSortColumn = ViewDefinition.DefaultSortColumnName;
        NativeSortDescending = ViewDefinition.IsDefaultSortDescending;
    }

    private async Task RestoreNativeGridStateAsync()
    {
        if (ViewDefinition is null)
            return;

        var savedPageNumber = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_currentPageNumber");
        if (!string.IsNullOrWhiteSpace(savedPageNumber) && int.TryParse(savedPageNumber, out var pageNum))
        {
            NativePage = Math.Max(1, pageNum);
        }

        if (!FullGrid)
            return;

        var savedState = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_nativeGridState");
        if (string.IsNullOrWhiteSpace(savedState))
            return;

        try
        {
            var state = JsonSerializer.Deserialize<NativeFilterAndSortSetting>(savedState);
            if (state is null)
                return;

            if (!string.Equals(state.code, ViewDefinition.Code, StringComparison.OrdinalIgnoreCase) ||
                !string.Equals(state.gridCode, GridCode, StringComparison.OrdinalIgnoreCase))
                return;

            NativeColumnFilters = state.filterValues is not null
                ? new Dictionary<string, string>(state.filterValues, StringComparer.OrdinalIgnoreCase)
                : new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            NativeSearchText = state.searchText ?? string.Empty;
            NativeFilterPanelOpen = NativeColumnFilters.Any(f => !string.IsNullOrWhiteSpace(f.Value));

            if (!string.IsNullOrWhiteSpace(state.sortColumn))
            {
                NativeSortColumn = state.sortColumn;
                NativeSortDescending = state.sortDescending;
            }
        }
        catch
        {
            // Ignore invalid or legacy saved state. It will be overwritten by native state.
        }
    }

    private async Task PersistNativeGridStateAsync()
    {
        if (ViewDefinition is null || !FullGrid)
            return;

        var hasFilters = NativeColumnFilters.Any(f => !string.IsNullOrWhiteSpace(f.Value));
        var hasSearch = !string.IsNullOrWhiteSpace(NativeSearchText);
        var hasSort = !string.IsNullOrWhiteSpace(NativeSortColumn);

        if (!hasFilters && !hasSearch && !hasSort)
        {
            await LocalStorageAccessor.RemoveAsync($"{ViewDefinition.Code}_nativeGridState");
            return;
        }

        var state = new NativeFilterAndSortSetting
        {
            code = ViewDefinition.Code,
            gridCode = GridCode,
            filterValues = NativeColumnFilters
                .Where(f => !string.IsNullOrWhiteSpace(f.Value))
                .ToDictionary(f => f.Key, f => f.Value, StringComparer.OrdinalIgnoreCase),
            searchText = NativeSearchText,
            sortColumn = NativeSortColumn,
            sortDescending = NativeSortDescending
        };

        var serializedGridStateToSave = JsonSerializer.Serialize(state, new JsonSerializerOptions { WriteIndented = true });
        await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_nativeGridState", serializedGridStateToSave);
    }

    private string GetNativeFilterValue(string columnName)
    {
        return NativeColumnFilters.TryGetValue(columnName, out var value) ? value : string.Empty;
    }

    private void OnNativeSearchChanged(ChangeEventArgs args)
    {
        NativeSearchText = args.Value?.ToString() ?? string.Empty;
    }

    private async Task OnNativeSearchKeyDown(KeyboardEventArgs args)
    {
        if (string.Equals(args.Key, "Enter", StringComparison.OrdinalIgnoreCase))
        {
            await ApplyNativeSearchAsync();
        }
    }

    private async Task ApplyNativeSearchAsync()
    {
        NativePage = 1;
        await PersistNativeGridStateAsync();
        await ReloadNativeGridAsync(1);
    }

    private async Task ClearNativeSearchAsync()
    {
        if (string.IsNullOrWhiteSpace(NativeSearchText))
            return;

        NativeSearchText = string.Empty;
        NativePage = 1;
        await PersistNativeGridStateAsync();
        await ReloadNativeGridAsync(1);
    }

    private void ToggleNativeFilterPanel()
    {
        NativeFilterPanelOpen = !NativeFilterPanelOpen;
    }

    private void SetNativeFilterValue(string columnName, string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            NativeColumnFilters.Remove(columnName);
            return;
        }

        NativeColumnFilters[columnName] = value;
    }

    private async Task OnNativeFilterKeyDown(KeyboardEventArgs args)
    {
        if (string.Equals(args.Key, "Enter", StringComparison.OrdinalIgnoreCase))
        {
            await ApplyNativeColumnFiltersAsync();
        }
    }

    private async Task ApplyNativeColumnFiltersAsync()
    {
        NativePage = 1;
        await PersistNativeGridStateAsync();
        await ReloadNativeGridAsync(1);
    }

    private async Task ClearNativeColumnFilterAsync(string columnName)
    {
        NativeColumnFilters.Remove(columnName);
        NativePage = 1;
        await PersistNativeGridStateAsync();
        await ReloadNativeGridAsync(1);
    }

    private async Task ClearAllNativeColumnFiltersAsync()
    {
        NativeColumnFilters.Clear();
        NativePage = 1;
        await PersistNativeGridStateAsync();
        await ReloadNativeGridAsync(1);
    }

    private async Task SortNativeGridAsync(string columnName)
    {
        if (string.Equals(NativeSortColumn, columnName, StringComparison.OrdinalIgnoreCase))
        {
            NativeSortDescending = !NativeSortDescending;
        }
        else
        {
            NativeSortColumn = columnName;
            NativeSortDescending = false;
        }

        NativePage = 1;
        await PersistNativeGridStateAsync();
        await ReloadNativeGridAsync(1);
    }

    private string GetNativeSortIndicator(string columnName)
    {
        if (!string.Equals(NativeSortColumn, columnName, StringComparison.OrdinalIgnoreCase))
            return string.Empty;

        return NativeSortDescending ? "▼" : "▲";
    }

    private string GetNativeSortCss(string columnName)
    {
        return string.Equals(NativeSortColumn, columnName, StringComparison.OrdinalIgnoreCase)
            ? "is-active"
            : string.Empty;
    }

    private async Task GoToPreviousNativePageAsync()
    {
        if (!CanGoPreviousPage)
            return;

        await ReloadNativeGridAsync(NativePage - 1);
    }

    private async Task GoToNextNativePageAsync()
    {
        if (!CanGoNextPage)
            return;

        await ReloadNativeGridAsync(NativePage + 1);
    }

    private async Task ChangeNativePageSizeAsync(ChangeEventArgs args)
    {
        if (args.Value is not null && int.TryParse(args.Value.ToString(), out var pageSize) && pageSize > 0)
        {
            NativePageSize = pageSize;
            NativePage = 1;
            await ReloadNativeGridAsync(1);
        }
    }

    private static string GetColumnWidthStyle(string? width)
    {
        if (string.IsNullOrWhiteSpace(width))
            return string.Empty;

        var safeWidth = width.Trim();
        return $"width:{safeWidth};min-width:{safeWidth};";
    }

    private object GetNativeCellValue(ExpandoObject row, string columnName)
    {
        var dictionary = (IDictionary<string, object>)row;
        return dictionary.TryGetValue(columnName, out var value) ? value ?? string.Empty : string.Empty;
    }

    private string GetInvoicePaymentStatusDot(ExpandoObject row)
    {
        var dictionary = (IDictionary<string, object>)row;
        var paymentStatus = dictionary.TryGetValue("InvoicePaymentStatus", out var status)
            ? status?.ToString() ?? string.Empty
            : string.Empty;

        return paymentStatus switch
        {
            "Overdue" => "dot red",
            "Pending" => "dot yellow",
            "Paid" => "dot green",
            _ => string.Empty
        };
    }

    private string GetDateChaseDot(ExpandoObject row)
    {
        var dictionary = (IDictionary<string, object>)row;
        var isOverdue = dictionary.TryGetValue("IsOverdue", out var value)
            ? value?.ToString() ?? string.Empty
            : string.Empty;

        return !string.IsNullOrWhiteSpace(isOverdue) ? "dot red" : string.Empty;
    }

    private string GetNativeRowCssClass(ExpandoObject rowObject)
    {
        var row = (IDictionary<string, object>)rowObject;
        var cssClasses = new List<string>();

        if (row.TryGetValue("IsTotalHighlightRow", out var totalValue) && totalValue?.ToString() == "1")
        {
            cssClasses.Add("highlight-total-row");
        }

        var orgUnitAsString = OrganisationalUnitID switch
        {
            2 => "Building and Real Estate",
            3 => "CDM Consulting",
            8 => "Building & Real Estate Admin",
            10 => "Building Control Consultancy",
            _ => string.Empty
        };

        if (Threshold > 1 &&
            row.TryGetValue("TotalNet", out var net) &&
            row.TryGetValue("OrganisationalUnitName", out var orgUnit) &&
            string.Equals(orgUnit?.ToString(), orgUnitAsString, StringComparison.OrdinalIgnoreCase))
        {
            var valAsString = net?.ToString();
            if (decimal.TryParse(valAsString, out var n) && (double)n >= Threshold)
            {
                cssClasses.Add("OverThreshold");
            }
        }

        return string.Join(" ", cssClasses);
    }

    #endregion Native Grid

    #region Public Methods

    /// <summary>
    /// Gets the quote threshold, which is used to highlight rows where the amount is greater than the threshold.
    /// </summary>
    private async Task GetQuoteThreshold()
    {
        formHelper = new FormHelper(coreClient, Guid.Empty.ToString(), userService);

        var quoteThresholdReq = await coreClient.GetThresholdsForOrgUnitAsync(new GetQuoteThresholdReq { UserId = userService.UserId });
        Threshold = quoteThresholdReq.QuoteThreshold;

        var unitId = await formHelper.GetOrganisationalUnitForUser(userService.UserId);

        if (unitId != null)
        {
            OrganisationalUnitID = unitId;
            Console.WriteLine($"Got threshold -> {Threshold} and Organisational Unit => {OrganisationalUnitID}");
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
        if (string.IsNullOrWhiteSpace(op)) return "and";
        op = op.Trim();
        return op.Equals("or", StringComparison.OrdinalIgnoreCase) ? "or" : "and";
    }

    public RenderFragment<object> GetColumnTemplate(string propName)
    {
        try
        {
            RenderFragment<object> columnTemplate = context => builder =>
            {
                if (context is not ExpandoObject expandoObject) return;
                var dictionary = expandoObject as IDictionary<string, object>;

                if (dictionary.TryGetValue(propName, out var propValue))
                {
                    builder.AddContent(0, propValue);
                }
            };

            return columnTemplate;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while getting the column template for the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/GetColumnTemplate()");
            _ = OnError(ex);
        }

        return _ => builder => builder.AddContent(0, string.Empty);
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
                            de => de.Value?.ToString() ?? "null")
                };

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
    /// Refreshes/reloads the native grid.
    /// </summary>
    public async Task RefreshMe()
    {
        try
        {
            await ReloadNativeGridAsync(NativePage);

            if (!HasChanges) return;
            HasChanges = false;
            StateHasChanged();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/RefreshMe()");
            await OnError(ex);
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
            var key = $"{subFilter.ColumnName}|{subFilter.Operator}|{subFilter.Value}";
            if (_loggedFilters.Add(key))
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

    private object FormatGridColumnValue(string columnName, string value)
    {
        bool isPhoneNumber = CheckIfMobileNumber(columnName, value);

        if (isPhoneNumber)
        {
            return value;
        }

        if (int.TryParse(value, out var intValue)) return intValue;

        if (decimal.TryParse(value, out var decimalValue))
            return decimalValue.ToString("F2");

        if (bool.TryParse(value, out var boolValue))
            return boolValue ? "Yes" : "No";

        if (Guid.TryParse(value, out var guidValue))
            return guidValue.ToString();

        if (DateTime.TryParse(value, out var dateTimeValue))
        {
            var localDateTime = UiFormattingHelper.NormalizeToLocal(dateTimeValue);
            bool isDateOnly = columnName.ToLower().EndsWith("date") && !columnName.ToLower().Contains("time");
            return UiFormattingHelper.FormatDateForUI(localDateTime, isDateOnly);
        }

        return value;
    }

    private bool CheckIfMobileNumber(string columnName, string columnValue)
    {
        bool startsWithZero = columnValue.StartsWith("0") && !columnValue.Contains("/");
        bool startWithFourtyFour = columnValue.StartsWith("44");
        bool startsWithPlus = columnValue.StartsWith("+");

        return startsWithZero || startWithFourtyFour || startsWithPlus;
    }

    #endregion Protected Methods

    #region Private Methods

    private async Task GetScrollBarPos()
    {
        try
        {
            await JsRuntime.InvokeVoidAsync("GetScrollBarPos");
        }
        catch (Exception ex)
        {
            Console.WriteLine(ex.Message);
        }
    }

    private async Task SetScrollBarPos()
    {
        try
        {
            await JsRuntime.InvokeVoidAsync("SetScrollBarPos");
            await Task.Delay(100);
        }
        catch (Exception ex)
        {
            Console.WriteLine(ex.Message);
        }
    }

    private void OnRowDoubleClickHandler(ExpandoObject item)
    {
        try
        {
            if (DoubleClickDisabled) return;

            var onRowDoubleClickHandler = !string.IsNullOrEmpty(ViewDefinition?.DetailPageUri) ? "@OnRowDoubleClickHandler" : null;
            if (onRowDoubleClickHandler == null) return;
            if (ViewDefinition == null) return;

            var row = (IDictionary<string, object>)item;
            var parentGuid = TryGetStringFromRow(row, "Guid");

            if (PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(parentGuid) == Guid.Empty) return;

            var isParentDataObjectReferenceDifferent = ParentDataObjectReference.EntityTypeGuid.ToString() != ViewDefinition.EntityTypeGuid;

            var (parentDataObjectReference, serializedParentDataObjectReference) =
                PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, parentGuid, ViewDefinition.EntityTypeGuid);

            string guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(parentGuid).ToString();
            string sPDOR = serializedParentDataObjectReference;
            string uri = System.Web.HttpUtility.UrlEncode(NavManager.Uri);
            string url = $"{ViewDefinition.DetailPageUri}/{guid}/{sPDOR}/{uri}";

            if (ViewDefinition.DetailPageUri == "DynamicEdit")
            {
                NavManager.NavigateTo(ViewDefinition.DetailPageUri + "/" +
                                      PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString() + "/" +
                                      parentDataObjectReference.DataObjectGuid + "/" +
                                      serializedParentDataObjectReference + "/" +
                                      System.Web.HttpUtility.UrlEncode(NavManager.Uri));
            }
            else if (isParentDataObjectReferenceDifferent)
            {
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

            InteractionTracker.Log(NavManager.Uri,
                $"User Double Clicked Row in Grid - '{ViewDefinition?.Name ?? "Unknown"}' New Page Opened: '{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition?.EntityTypeGuid ?? "No Guid").ToString()}'");

            formHelper = new FormHelper(coreClient, Guid.Empty.ToString(), userService);
            _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid),
                PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while handling the row double-click event in the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/OnRowDoubleClickHandler()");
            _ = OnError(ex);
        }
    }

    private void OpenDynamicBatchGrid()
    {
        _ = GetScrollBarPos();
        BatchGridVisible = true;
    }

    private void ScrollToTop()
    {
        _ = JsRuntime.InvokeVoidAsync("window.scrollTo", 0, 0);
        InteractionTracker.Log(NavManager.Uri, "Back To Top Clicked");
    }

    #endregion Private Methods

    #region Private Classes

    private sealed class NativeFilterAndSortSetting
    {
        public string code { get; set; } = string.Empty;
        public Dictionary<string, string> filterValues { get; set; } = new(StringComparer.OrdinalIgnoreCase);
        public string gridCode { get; set; } = string.Empty;
        public string searchText { get; set; } = string.Empty;
        public string sortColumn { get; set; } = string.Empty;
        public bool sortDescending { get; set; }
    }

    #endregion Private Classes
}
