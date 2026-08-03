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
using static Concursus.PWA.Shared.MessageDisplay;
using JsonSerializer = System.Text.Json.JsonSerializer;

namespace Concursus.PWA.Shared;

public partial class FilteredDynamicGridView : ComponentBase
{
    private static string dataObjGuid = string.Empty;
    private readonly IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();
    private readonly List<string> _operationsWithMultipleStateChanged = new() { "FilterDescriptors", "GroupDescriptors", "SearchFilter" };
    private MessageDisplay _messageDisplay = default!;

    private GridViewDefinition? _viewDefinition;
    private bool BatchGridVisible { get; set; }
    private bool ComingFromModal { get; set; }
    private IEnumerable<ExpandoObject>? CurrentGridItems { get; set; }
    private bool DoubleStateChanged { get; set; }
    private string GridStateChangedProperty { get; set; } = string.Empty;
    private string GridStateChangedPropertyClass { get; set; } = string.Empty;
    private string GridStateString { get; set; } = string.Empty;
    private int OnStateChangedCount { get; set; }
    private string modalId = Guid.Empty.ToString();

    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = string.Empty;
    [Parameter] public EventCallback<InputUpdatedArgs> inputUpdated { get; set; }
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public bool DoubleClickDisabled { get; set; }
    [Parameter] public bool Disabled { get; set; }

    [Parameter]
    public GridViewDefinition? ViewDefinition
    {
        get => _viewDefinition;
        set => _viewDefinition = value;
    }

    public bool HasChanges { get; private set; }

    protected string ErrorMessage { get; set; } = string.Empty;
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";
    protected FormHelper? formHelper;

    private bool showCustomRange { get; set; }
    private DateTime? customStartDate { get; set; }
    private DateTime? customEndDate { get; set; }
    private int? ActiveQuickFilterDays { get; set; }
    private DataCompositeFilter? QuickFilters { get; set; }
    private string QuickFilter7DaysCSS { get; set; } = string.Empty;
    private string QuickFilter90DaysCSS { get; set; } = string.Empty;
    private DataCompositeFilter? RangeFilters { get; set; }
    public DataCompositeFilter? CompositeFilter { get; set; }

    private sealed class OrderByItem
    {
        public string Id { get; set; } = string.Empty;
        public string Text { get; set; } = string.Empty;
    }

    private string SelectedSortBy { get; set; } = string.Empty;

    private IEnumerable<OrderByItem> GroupByOptions { get; set; } = new List<OrderByItem>
    {
        new() { Id = "SentDate_desc", Text = "Date Sent (Newest First)" },
        new() { Id = "SentDate_asc", Text = "Date Sent (Oldest First)" },
        new() { Id = "Amount_desc", Text = "Value (Highest First)" },
        new() { Id = "Amount_asc", Text = "Value (Lowest First)" }
    };

    private string RedIndicator { get; set; } = string.Empty;
    private string GreenIndicator { get; set; } = string.Empty;
    private string OrangeIndicator { get; set; } = string.Empty;
    private double Threshold { get; set; } = -1;
    private int OrganisationalUnitID { get; set; } = -1;

    private int NativePage { get; set; } = 1;
    private int NativePageSize { get; set; } = 50;
    private int NativeTotalRows { get; set; }
    private bool NativeIsLoading { get; set; }
    private string NativeSortColumn { get; set; } = string.Empty;
    private bool NativeSortDescending { get; set; }
    private string NativeSearchText { get; set; } = string.Empty;
    private bool NativeFilterPanelOpen { get; set; }
    private Dictionary<string, string> NativeColumnFilters { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    private string _nativeGridParameterKey = string.Empty;

    private IEnumerable<GridViewColumnDefinition> VisibleGridColumns =>
        ViewDefinition?.Columns
            .Where(o => !o.IsHidden)
            .OrderBy(o => o.ColumnOrder)
        ?? Enumerable.Empty<GridViewColumnDefinition>();

    private IEnumerable<ExpandoObject> NativeGridItems => CurrentGridItems ?? Enumerable.Empty<ExpandoObject>();
    private int NativeGridColumnCount => Math.Max(1, VisibleGridColumns.Count());
    private int NativeTotalPages => Math.Max(1, (int)Math.Ceiling((double)Math.Max(0, NativeTotalRows) / Math.Max(1, NativePageSize)));
    private bool CanGoPreviousPage => NativePage > 1 && !NativeIsLoading;
    private bool CanGoNextPage => NativePage < NativeTotalPages && !NativeIsLoading;
    private bool HasActiveNativeColumnFilters => NativeColumnFilters.Any(f => !string.IsNullOrWhiteSpace(f.Value));
    private bool HasActiveNativeSearch => !string.IsNullOrWhiteSpace(NativeSearchText);
    private int NativeActiveFilterCount => NativeColumnFilters.Count(f => !string.IsNullOrWhiteSpace(f.Value));

    private string NativeSearchPlaceholder => string.IsNullOrWhiteSpace(ViewDefinition?.Name)
        ? "Search records..."
        : $"Search {ViewDefinition.Name} records...";

    private string NativeGridSummaryText
    {
        get
        {
            if (NativeTotalRows <= 0) return "Showing 0 records";
            var start = ((NativePage - 1) * NativePageSize) + 1;
            var end = Math.Min(NativeTotalRows, NativePage * NativePageSize);
            return $"Showing {start} to {end} of {NativeTotalRows}";
        }
    }

    protected override async Task OnInitializedAsync()
    {
        await base.OnInitializedAsync();
        ApplyViewDefinitionSettings();
        await GetQuoteThreshold();
    }

    protected override async Task OnParametersSetAsync()
    {
        await base.OnParametersSetAsync();

        if (ViewDefinition is null) return;

        ApplyViewDefinitionSettings();

        var parameterKey = $"{GridCode}|{ViewDefinition.Code}|{ParentGuid}|{FullGrid}";
        if (!string.Equals(_nativeGridParameterKey, parameterKey, StringComparison.Ordinal))
        {
            _nativeGridParameterKey = parameterKey;
            InitialiseNativeSortFromViewDefinition();
            await RestoreNativeGridStateAsync();
            await ReloadNativeGridAsync(NativePage);
        }
    }

    private void ApplyViewDefinitionSettings()
    {
        if (ViewDefinition is null) return;
        RedIndicator = ViewDefinition.FilteredListRedStatusIndicatorTxt;
        GreenIndicator = ViewDefinition.FilteredListGreenStatusIndicatorTxt;
        OrangeIndicator = ViewDefinition.FilteredListOrangeStatusIndicatorTxt;
    }

    private async Task GetQuoteThreshold()
    {
        formHelper = new FormHelper(coreClient, sageIntegrationService, Guid.Empty.ToString(), userService);

        var quoteThresholdReq = await coreClient.GetThresholdsForOrgUnitAsync(new GetQuoteThresholdReq { UserId = userService.UserId });
        Threshold = quoteThresholdReq.QuoteThreshold;

        var unitId = await formHelper.GetOrganisationalUnitForUser(userService.UserId);
        if (unitId > 0)
        {
            OrganisationalUnitID = unitId;
            Console.WriteLine($"Got threshold -> {Threshold} and Organisational Unit => {OrganisationalUnitID}");
        }
    }

    private async void ShowRecordsFromXDay(int days)
    {
        try
        {
            if (showCustomRange) showCustomRange = false;
            customStartDate = null;
            customEndDate = null;
            RangeFilters = null;

            if (ActiveQuickFilterDays == days)
            {
                ActiveQuickFilterDays = null;
                QuickFilter7DaysCSS = string.Empty;
                QuickFilter90DaysCSS = string.Empty;
                QuickFilters = null;
                await ReloadNativeGridAsync(1);
                return;
            }

            ActiveQuickFilterDays = days;
            QuickFilter7DaysCSS = days == -7 ? "activeButton active" : string.Empty;
            QuickFilter90DaysCSS = days == -90 ? "activeButton active" : string.Empty;

            var startDate = DateTime.Today.AddDays(days);
            var endDate = DateTime.Today;
            var dateRangeFilter = new DataCompositeFilter { LogicalOperator = "and" };
            dateRangeFilter.Filters.Add(new DataFilter
            {
                ColumnName = "Date",
                Operator = "ge",
                Guid = Guid.NewGuid().ToString(),
                Value = Value.ForString(startDate.ToString("yyyy-MM-dd"))
            });
            dateRangeFilter.Filters.Add(new DataFilter
            {
                ColumnName = "Date",
                Operator = "le",
                Guid = Guid.NewGuid().ToString(),
                Value = Value.ForString(endDate.ToString("yyyy-MM-dd"))
            });

            QuickFilters = new DataCompositeFilter { LogicalOperator = "and" };
            QuickFilters.CompositeFilters.Add(dateRangeFilter);
            await ReloadNativeGridAsync(1);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "FilteredDynamicGridView/ShowRecordsFromXDay()");
            await OnError(ex);
        }
    }

    private async void ApplyCustomRange()
    {
        try
        {
            if (customStartDate is null || customEndDate is null)
            {
                await OnError(new Exception("Both the start and end date must be set. Please, try again."));
                return;
            }

            var dateRangeFilter = new DataCompositeFilter { LogicalOperator = "and" };
            dateRangeFilter.Filters.Add(new DataFilter
            {
                ColumnName = "Date",
                Operator = "ge",
                Guid = Guid.NewGuid().ToString(),
                Value = Value.ForString(customStartDate.Value.ToString("yyyy-MM-dd"))
            });
            dateRangeFilter.Filters.Add(new DataFilter
            {
                ColumnName = "Date",
                Operator = "le",
                Guid = Guid.NewGuid().ToString(),
                Value = Value.ForString(customEndDate.Value.ToString("yyyy-MM-dd"))
            });

            RangeFilters = new DataCompositeFilter { LogicalOperator = "and" };
            RangeFilters.CompositeFilters.Add(dateRangeFilter);
            await ReloadNativeGridAsync(1);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "FilteredDynamicGridView/ApplyCustomRange()");
            await OnError(ex);
        }
    }

    private async void ToggleCustomRange()
    {
        if (ActiveQuickFilterDays.HasValue)
        {
            ActiveQuickFilterDays = null;
            QuickFilter7DaysCSS = string.Empty;
            QuickFilter90DaysCSS = string.Empty;
            QuickFilters = null;
        }

        showCustomRange = !showCustomRange;
        if (!showCustomRange) RangeFilters = null;
        await ReloadNativeGridAsync(1);
    }

    private async Task OnGroupDataChangedAsync(ChangeEventArgs args)
    {
        await GroupData(args.Value?.ToString() ?? string.Empty);
    }

    private async Task GroupData(string val)
    {
        SelectedSortBy = val;
        NativeSortColumn = ViewDefinition?.DefaultSortColumnName ?? string.Empty;
        NativeSortDescending = ViewDefinition?.IsDefaultSortDescending ?? false;

        switch (val)
        {
            case "SentDate_asc":
                NativeSortColumn = "Date";
                NativeSortDescending = false;
                break;
            case "SentDate_desc":
                NativeSortColumn = "Date";
                NativeSortDescending = true;
                break;
            case "Amount_desc":
                NativeSortColumn = "TotalNet";
                NativeSortDescending = true;
                break;
            case "Amount_asc":
                NativeSortColumn = "TotalNet";
                NativeSortDescending = false;
                break;
        }

        await PersistNativeGridStateAsync();
        await ReloadNativeGridAsync(1);
    }

    public async Task ReloadNativeGridAsync(int? requestedPage = null)
    {
        NativeIsLoading = true;
        await InvokeAsync(StateHasChanged);

        try
        {
            if (ViewDefinition is null) return;

            var pageNum = requestedPage ?? NativePage;
            var savedPageNum = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_currentPageNumber");
            if (ComingFromModal && !string.IsNullOrWhiteSpace(savedPageNum) && int.TryParse(savedPageNum, out var parsedPage))
            {
                pageNum = parsedPage;
            }

            NativePage = Math.Max(1, pageNum);
            NativePageSize = Math.Max(1, NativePageSize);

            var request = new GridDataListRequest
            {
                GridCode = GridCode,
                GridViewCode = ViewDefinition.Code,
                Page = NativePage,
                PageSize = NativePageSize,
                ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString()
            };

            if (request.ParentGuid == Guid.Empty.ToString() && !FullGrid)
            {
                CurrentGridItems = new List<ExpandoObject>();
                NativeTotalRows = 0;
                return;
            }

            await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_currentPageNumber", NativePage);

            var root = new DataCompositeFilter { LogicalOperator = "and" };
            AddCompositeIfNotEmpty(root, BuildNativeColumnFilterComposite());
            AddCompositeIfNotEmpty(root, BuildNativeSearchFilterComposite());
            AddCompositeIfNotEmpty(root, QuickFilters);
            AddCompositeIfNotEmpty(root, RangeFilters);

            CompositeFilter = HasAnyFilterContent(root) ? root : null;
            ShowCSVButton = CompositeFilter is not null;

            if (CompositeFilter is not null)
            {
                request.Filters.Add(CompositeFilter);
                LogCompositeFilter(CompositeFilter);
            }

            if (!string.IsNullOrWhiteSpace(NativeSortColumn))
            {
                request.Sort.Add(new DataSort
                {
                    ColumnName = NativeSortColumn,
                    Direction = NativeSortDescending ? "Descending" : "Ascending"
                });
            }

            var reply = await coreClient.GridDataListAsync(request);
            var loadedRows = new List<ExpandoObject>();
            foreach (var r in reply.DataTable)
            {
                dynamic dataObj = new ExpandoObject();
                var dictionary = (IDictionary<string, object>)dataObj;
                foreach (var c in r.Columns)
                {
                    dictionary[c.Name] = FormatGridColumnValue(c.Name, c.Value);
                }
                loadedRows.Add(dataObj);
            }

            NativeTotalRows = (int)reply.TotalRows;
            if (NativeTotalRows > 0 && NativePage > NativeTotalPages)
            {
                NativePage = NativeTotalPages;
                await ReloadNativeGridAsync(NativePage);
                return;
            }

            CurrentGridItems = loadedRows;
            ComingFromModal = false;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "FilteredDynamicGridView/ReloadNativeGridAsync()");
            await OnError(ex);
        }
        finally
        {
            NativeIsLoading = false;
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
        if (string.IsNullOrWhiteSpace(NativeSearchText)) return null;
        var composite = new DataCompositeFilter { LogicalOperator = "or" };
        var searchValue = NativeSearchText.Trim();
        foreach (var column in VisibleGridColumns.Select(c => c.Name).Where(n => !string.IsNullOrWhiteSpace(n)).Distinct(StringComparer.OrdinalIgnoreCase))
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

    private static void AddCompositeIfNotEmpty(DataCompositeFilter root, DataCompositeFilter? filter)
    {
        if (!HasAnyFilterContent(filter)) return;
        filter!.LogicalOperator = NormaliseLogicalOperator(filter.LogicalOperator);
        root.CompositeFilters.Add(filter);
    }

    private static bool HasAnyFilterContent(DataCompositeFilter? filter)
    {
        return filter is not null && ((filter.Filters?.Count ?? 0) > 0 || (filter.CompositeFilters?.Count ?? 0) > 0);
    }

    private static string NormaliseLogicalOperator(string op)
    {
        if (string.IsNullOrWhiteSpace(op)) return "and";
        return op.Trim().Equals("or", StringComparison.OrdinalIgnoreCase) ? "or" : "and";
    }

    private void InitialiseNativeSortFromViewDefinition()
    {
        if (ViewDefinition is null || !string.IsNullOrWhiteSpace(NativeSortColumn)) return;
        NativeSortColumn = ViewDefinition.DefaultSortColumnName;
        NativeSortDescending = ViewDefinition.IsDefaultSortDescending;
    }

    private async Task RestoreNativeGridStateAsync()
    {
        if (ViewDefinition is null) return;

        var savedPageNumber = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_currentPageNumber");
        if (!string.IsNullOrWhiteSpace(savedPageNumber) && int.TryParse(savedPageNumber, out var pageNum))
        {
            NativePage = Math.Max(1, pageNum);
        }

        if (!FullGrid) return;

        var savedState = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_legacyNativeGridState");
        if (string.IsNullOrWhiteSpace(savedState)) return;

        try
        {
            var state = JsonSerializer.Deserialize<NativeFilterAndSortSetting>(savedState);
            if (state is null) return;
            if (!string.Equals(state.code, ViewDefinition.Code, StringComparison.OrdinalIgnoreCase) ||
                !string.Equals(state.gridCode, GridCode, StringComparison.OrdinalIgnoreCase)) return;

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
            // Ignore invalid legacy state.
        }
    }

    private async Task PersistNativeGridStateAsync()
    {
        if (ViewDefinition is null || !FullGrid) return;

        var hasFilters = NativeColumnFilters.Any(f => !string.IsNullOrWhiteSpace(f.Value));
        var hasSearch = !string.IsNullOrWhiteSpace(NativeSearchText);
        var hasSort = !string.IsNullOrWhiteSpace(NativeSortColumn);

        if (!hasFilters && !hasSearch && !hasSort)
        {
            await LocalStorageAccessor.RemoveAsync($"{ViewDefinition.Code}_legacyNativeGridState");
            return;
        }

        var state = new NativeFilterAndSortSetting
        {
            code = ViewDefinition.Code,
            gridCode = GridCode,
            filterValues = NativeColumnFilters.Where(f => !string.IsNullOrWhiteSpace(f.Value)).ToDictionary(f => f.Key, f => f.Value, StringComparer.OrdinalIgnoreCase),
            searchText = NativeSearchText,
            sortColumn = NativeSortColumn,
            sortDescending = NativeSortDescending
        };

        await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_legacyNativeGridState", JsonSerializer.Serialize(state, new JsonSerializerOptions { WriteIndented = true }));
    }

    private string GetNativeFilterValue(string columnName) => NativeColumnFilters.TryGetValue(columnName, out var value) ? value : string.Empty;
    private void OnNativeSearchChanged(ChangeEventArgs args) => NativeSearchText = args.Value?.ToString() ?? string.Empty;

    private async Task OnNativeSearchKeyDown(KeyboardEventArgs args)
    {
        if (string.Equals(args.Key, "Enter", StringComparison.OrdinalIgnoreCase)) await ApplyNativeSearchAsync();
    }

    private async Task ApplyNativeSearchAsync()
    {
        NativePage = 1;
        await PersistNativeGridStateAsync();
        await ReloadNativeGridAsync(1);
    }

    private async Task ClearNativeSearchAsync()
    {
        NativeSearchText = string.Empty;
        NativePage = 1;
        await PersistNativeGridStateAsync();
        await ReloadNativeGridAsync(1);
    }

    private void ToggleNativeFilterPanel() => NativeFilterPanelOpen = !NativeFilterPanelOpen;

    private void SetNativeFilterValue(string columnName, string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) NativeColumnFilters.Remove(columnName);
        else NativeColumnFilters[columnName] = value;
    }

    private async Task OnNativeFilterKeyDown(KeyboardEventArgs args)
    {
        if (string.Equals(args.Key, "Enter", StringComparison.OrdinalIgnoreCase)) await ApplyNativeColumnFiltersAsync();
    }

    private async Task ApplyNativeColumnFiltersAsync()
    {
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
        if (string.Equals(NativeSortColumn, columnName, StringComparison.OrdinalIgnoreCase)) NativeSortDescending = !NativeSortDescending;
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
        if (!string.Equals(NativeSortColumn, columnName, StringComparison.OrdinalIgnoreCase)) return string.Empty;
        return NativeSortDescending ? "▼" : "▲";
    }

    private string GetNativeSortCss(string columnName) => string.Equals(NativeSortColumn, columnName, StringComparison.OrdinalIgnoreCase) ? "is-active" : string.Empty;

    private async Task GoToPreviousNativePageAsync()
    {
        if (CanGoPreviousPage) await ReloadNativeGridAsync(NativePage - 1);
    }

    private async Task GoToNextNativePageAsync()
    {
        if (CanGoNextPage) await ReloadNativeGridAsync(NativePage + 1);
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
        if (string.IsNullOrWhiteSpace(width)) return string.Empty;
        var safeWidth = width.Trim();
        return $"width:{safeWidth};min-width:{safeWidth};";
    }

    private object GetNativeCellValue(ExpandoObject row, string columnName)
    {
        var dictionary = (IDictionary<string, object>)row;
        return dictionary.TryGetValue(columnName, out var value) ? value ?? string.Empty : string.Empty;
    }

    private sealed class SageStatusPresentation
    {
        public string DisplayText { get; init; } = "Unknown";
        public string CssClass { get; init; } =
            "cb-sage-status-badge badge rounded-pill m-0 bg-secondary";
    }

    private bool IsAllTransactionsView =>
        string.Equals(
            ViewDefinition?.Code,
            "ALLTRANSACTIONS",
            StringComparison.OrdinalIgnoreCase);

    private bool HasVisibleSageStatusColumn =>
        VisibleGridColumns.Any(
            column => IsSageStatusColumn(column.Name));

    private static bool IsSageStatusColumn(string columnName)
    {
        return string.Equals(
            columnName,
            "SageStatusCode",
            StringComparison.OrdinalIgnoreCase);
    }

    private bool ShouldRenderSageStatusWithDate(
        string columnName,
        ExpandoObject row)
    {
        if (!IsAllTransactionsView ||
            HasVisibleSageStatusColumn ||
            !string.Equals(
                columnName,
                "Date",
                StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var dictionary = (IDictionary<string, object>)row;
        return dictionary.ContainsKey("SageStatusCode") ||
               dictionary.ContainsKey("SageTransactionReference");
    }

    private static SageStatusPresentation GetSageStatusPresentation(
        ExpandoObject row)
    {
        var dictionary = (IDictionary<string, object>)row;
        var statusCode = GetDictionaryString(
            dictionary,
            "SageStatusCode");
        var sageReference = GetDictionaryString(
            dictionary,
            "SageTransactionReference");
        var hasSageReference =
            !string.IsNullOrWhiteSpace(sageReference);

        switch (statusCode.ToUpperInvariant())
        {
            case "SUCCEEDED":
                return new SageStatusPresentation
                {
                    DisplayText = "Succeeded",
                    CssClass =
                        "cb-sage-status-badge badge rounded-pill m-0 bg-success"
                };

            case "PENDING":
                return new SageStatusPresentation
                {
                    DisplayText = "Pending",
                    CssClass =
                        "cb-sage-status-badge badge rounded-pill m-0 bg-primary"
                };

            case "INPROGRESS":
                return new SageStatusPresentation
                {
                    DisplayText = "In Progress",
                    CssClass =
                        "cb-sage-status-badge badge rounded-pill m-0 bg-secondary"
                };

            case "FAILEDRETRYABLE":
                // Preserve the existing user-facing wording.
                return new SageStatusPresentation
                {
                    DisplayText = "In Progress",
                    CssClass =
                        "cb-sage-status-badge badge rounded-pill m-0 bg-warning"
                };

            case "LEGACY":
            case "SENT (LEGACY)":
                return CreateLegacySageStatus();

            case "NOT SENT":
                return hasSageReference
                    ? CreateLegacySageStatus()
                    : new SageStatusPresentation
                    {
                        DisplayText = "Not Sent",
                        CssClass =
                            "cb-sage-status-badge badge rounded-pill m-0 bg-info"
                    };

            case "":
                // A Sage reference is authoritative legacy evidence even when
                // an older query does not return SageStatusCode.
                return hasSageReference
                    ? CreateLegacySageStatus()
                    : new SageStatusPresentation();

            default:
                // Preserve future server values rather than falsely
                // presenting them as Not Sent.
                return new SageStatusPresentation
                {
                    DisplayText = statusCode,
                    CssClass =
                        "cb-sage-status-badge badge rounded-pill m-0 bg-secondary"
                };
        }
    }

    private static SageStatusPresentation CreateLegacySageStatus()
    {
        return new SageStatusPresentation
        {
            DisplayText = "Sent (Legacy)",
            CssClass =
                "cb-sage-status-badge badge rounded-pill m-0 bg-sageLegacyCustom"
        };
    }

    private static string GetDictionaryString(
        IDictionary<string, object> dictionary,
        string key)
    {
        return dictionary.TryGetValue(key, out var value)
            ? value?.ToString()?.Trim() ?? string.Empty
            : string.Empty;
    }

    private string GetNativeRowCssClass(ExpandoObject rowObject)
    {
        var row = (IDictionary<string, object>)rowObject;
        var cssClasses = new List<string>();
        if (row.TryGetValue("IsTotalHighlightRow", out var totalValue) && totalValue?.ToString() == "1") cssClasses.Add("highlight-total-row");

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
            string.Equals(orgUnit?.ToString(), orgUnitAsString, StringComparison.OrdinalIgnoreCase) &&
            decimal.TryParse(net?.ToString(), out var n) &&
            (double)n >= Threshold)
        {
            cssClasses.Add("OverThreshold");
        }

        return string.Join(" ", cssClasses);
    }

    private object FormatGridColumnValue(string columnName, string value)
    {
        if (CheckIfMobileNumber(columnName, value)) return value;
        if (int.TryParse(value, out var intValue)) return intValue;
        if (decimal.TryParse(value, out var decimalValue)) return decimalValue.ToString("F2");
        if (bool.TryParse(value, out var boolValue)) return boolValue ? "Yes" : "No";
        if (Guid.TryParse(value, out var guidValue)) return guidValue.ToString();
        if (DateTime.TryParse(value, out var dateTimeValue))
        {
            var localDateTime = UiFormattingHelper.NormalizeToLocal(dateTimeValue);
            var isDateOnly = columnName.ToLower().EndsWith("date") && !columnName.ToLower().Contains("time");
            return UiFormattingHelper.FormatDateForUI(localDateTime, isDateOnly);
        }
        return value;
    }

    private bool CheckIfMobileNumber(string columnName, string columnValue)
    {
        var startsWithZero = columnValue.StartsWith("0") && !columnValue.Contains("/");
        var startWithFourtyFour = columnValue.StartsWith("44");
        var startsWithPlus = columnValue.StartsWith("+");
        return startsWithZero || startWithFourtyFour || startsWithPlus;
    }

    public RenderFragment<object> GetColumnTemplate(string propName)
    {
        return context => builder =>
        {
            if (context is not ExpandoObject expandoObject) return;
            var dictionary = (IDictionary<string, object>)expandoObject;
            if (dictionary.TryGetValue(propName, out var propValue)) builder.AddContent(0, propValue);
        };
    }

    public async Task OnError(Exception error)
    {
        if (string.IsNullOrEmpty(error.Message)) return;

        ErrorMessage = error.Message;
        PageMethod = error.Data.Contains("PageMethod") ? error.Data["PageMethod"]?.ToString() ?? "Not Set" : "Not Set";
        MessageType = error.Data.Contains("MessageType") ? (ShowMessageType)(error.Data["MessageType"] ?? ShowMessageType.Information) : ShowMessageType.Error;

        var exceptionData = error.Data.Count > 0
            ? error.Data.Cast<DictionaryEntry>().ToDictionary(de => de.Key?.ToString() ?? "UnknownKey", de => de.Value!)
            : null;

        _messageDisplay.UpdateExceptionData(exceptionData);
        _messageDisplay.UpdateStackTrace(error.StackTrace ?? "No additional details available.");
        _messageDisplay.ShowError(true);

        if (MessageType == ShowMessageType.Error)
        {
            try
            {
                var context = new
                {
                    ErrorMessage = error.Message,
                    PageMethod,
                    StackTrace = error.StackTrace ?? "No stack trace",
                    AdditionalInfo = error.Data.Contains("AdditionalInfo") ? error.Data["AdditionalInfo"]?.ToString() ?? "None" : "None",
                    Data = error.Data.Cast<DictionaryEntry>().ToDictionary(de => de.Key?.ToString() ?? "UnknownKey", de => de.Value?.ToString() ?? "null")
                };

                var description = InteractionTracker.GetReplicationStepsFormatted(InteractionTracker);
                error.Data["UserInteractionLog"] = description;
                var result = await AiErrorReporter.ReportAsync(error, context);
                if (result is not null && !string.IsNullOrEmpty(result.UiMessage))
                {
                    _messageDisplay.SetMessage(result.UiMessage, result.MessageType);
                    _messageDisplay.ShowError(true);
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
        await ReloadNativeGridAsync(NativePage);
        if (!HasChanges) return;
        HasChanges = false;
        StateHasChanged();
    }

    public async Task RefreshGrid(bool resetToFirstPage = false)
    {
        await ReloadNativeGridAsync(resetToFirstPage ? 1 : NativePage);
    }

    protected async Task GridUpdated()
    {
        try
        {
            ComingFromModal = true;
            await ReloadNativeGridAsync(NativePage);
            await OnActionCompleted.InvokeAsync();
            StateHasChanged();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "FilteredDynamicGridView/GridUpdated()");
            await OnError(ex);
        }
    }

    private async Task HandleBatchActionCompletedAsync()
    {
        await GridUpdated();
    }

    private void OpenDynamicBatchGrid()
    {
        _ = GetScrollBarPos();
        BatchGridVisible = true;
    }

    private async Task CloseBatchGridModal()
    {
        BatchGridVisible = false;
        await GridUpdated();
        await SetScrollBarPos();
    }

    private async Task GetScrollBarPos()
    {
        try { await JsRuntime.InvokeVoidAsync("GetScrollBarPos"); }
        catch (Exception ex) { Console.WriteLine(ex.Message); }
    }

    private async Task SetScrollBarPos()
    {
        try
        {
            await JsRuntime.InvokeVoidAsync("SetScrollBarPos");
            await Task.Delay(100);
        }
        catch (Exception ex) { Console.WriteLine(ex.Message); }
    }

    private void OnRowDoubleClickHandler(ExpandoObject item)
    {
        try
        {
            if (DoubleClickDisabled || ViewDefinition is null || string.IsNullOrWhiteSpace(ViewDefinition.DetailPageUri)) return;
            var row = (IDictionary<string, object>)item;
            if (!row.TryGetValue("Guid", out var guidObj)) return;
            var parentGuid = guidObj?.ToString() ?? Guid.Empty.ToString();
            if (PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(parentGuid) == Guid.Empty) return;

            var isParentDataObjectReferenceDifferent = ParentDataObjectReference.EntityTypeGuid.ToString() != ViewDefinition.EntityTypeGuid;
            var (parentDataObjectReference, serializedParentDataObjectReference) =
                PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, parentGuid, ViewDefinition.EntityTypeGuid);

            var guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(parentGuid).ToString();
            var encodedReturnUrl = System.Web.HttpUtility.UrlEncode(NavManager.Uri);
            var url = $"{ViewDefinition.DetailPageUri}/{guid}/{serializedParentDataObjectReference}/{encodedReturnUrl}";

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
                NavManager.NavigateTo(url, currentUri.Contains(navigateToDetailPage, StringComparison.OrdinalIgnoreCase));
            }
            else
            {
                NavManager.NavigateTo(url, true);
            }

            InteractionTracker.Log(NavManager.Uri, $"User Double Clicked Row in Grid - '{ViewDefinition?.Name ?? "Unknown"}' New Page Opened: '{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition?.EntityTypeGuid ?? "No Guid")}'");
            formHelper = new FormHelper(coreClient, sageIntegrationService, Guid.Empty.ToString(), userService);
            _ = formHelper.LogUsageAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid), PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while handling the row double-click event in the DynamicGridView.");
            ex.Data.Add("PageMethod", "FilteredDynamicGridView/OnRowDoubleClickHandler()");
            _ = OnError(ex);
        }
    }

    private void ScrollToTop()
    {
        _ = JsRuntime.InvokeVoidAsync("window.scrollTo", 0, 0);
        InteractionTracker.Log(NavManager.Uri, "Back To Top Clicked");
    }

    public void LogCompositeFilter(DataCompositeFilter compositeFilter)
    {
        TraverseAndLogFilter(compositeFilter);
    }

    private static readonly HashSet<string> _loggedFilters = new();

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

    private sealed class NativeFilterAndSortSetting
    {
        public string code { get; set; } = string.Empty;
        public Dictionary<string, string> filterValues { get; set; } = new(StringComparer.OrdinalIgnoreCase);
        public string gridCode { get; set; } = string.Empty;
        public string searchText { get; set; } = string.Empty;
        public string sortColumn { get; set; } = string.Empty;
        public bool sortDescending { get; set; }
    }
}
