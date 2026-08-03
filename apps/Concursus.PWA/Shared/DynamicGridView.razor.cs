using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Client.Models.Finance;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using System.Collections;
using System.Dynamic;
using System.Globalization;
using System.IO;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using static Concursus.PWA.Shared.DynamicGrid;
using static Concursus.PWA.Shared.MessageDisplay;

namespace Concursus.PWA.Shared;

public partial class DynamicGridView : ComponentBase, IDisposable
{
    private static string dataObjGuid = string.Empty;

    private readonly IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();
    private readonly List<ExpandoObject> _rows = new();
    private readonly Dictionary<string, NativeColumnFilter> _filtersByColumn = new(StringComparer.OrdinalIgnoreCase);
    private readonly HashSet<string> _loggedFilters = new(StringComparer.OrdinalIgnoreCase);
    private readonly HashSet<string> _serverFilterExcludedColumns = new(StringComparer.OrdinalIgnoreCase);

    private const int FilterInputDebounceMilliseconds = 500;
    private const string BypassReadOnlyForAutomationReenableKey =
        "BypassReadOnlyForAutomationReenable";

    private System.Type? _detailPageType;
    private MessageDisplay _messageDisplay = new();
    private GridViewDefinition? _viewDefinition;
    private string modalId = Guid.Empty.ToString();

    private bool _isLoading;
    private CancellationTokenSource? _filterDebounceCancellationTokenSource;
    private bool _isInitialised;
    private bool _suppressParameterReload;
    private string? _statusText;
    private string? _lastParameterLoadKey;
    private string _searchText = string.Empty;
    private bool _isFilterPanelOpen;
    private bool _scrollDetailPanelIntoViewAfterRender;

    private int _page = 1;
    private int _pageSize = 50;
    private int _totalRows;
    private int _totalPages = 1;

    private string? _sortColumn;
    private bool _sortDescending;

    private bool IsMonthlySeriesModalVisible { get; set; }
    private bool MonthlySeriesSaving { get; set; }
    private string? MonthlySeriesError { get; set; }
    private MonthlySeriesModel MonthlySeries { get; set; } = new();

    private bool IsDrawdownInlineEditing { get; set; }
    private bool IsDrawdownInlineSaving { get; set; }
    private string? DrawdownInlineError { get; set; }
    private List<InvoiceScheduleDrawdownStageLookupModel> DrawdownStageOptions { get; set; } = new();
    private readonly Dictionary<string, Dictionary<string, object?>> _drawdownInlineOriginalRows = new(StringComparer.OrdinalIgnoreCase);

    private bool IsMonthlyDrawdownGrid => string.Equals(GridCode, "INVSCEDMONTHLY", StringComparison.OrdinalIgnoreCase);
    private bool IsPercentageDrawdownGrid => string.Equals(GridCode, "INVSCEDULEPERCENTAGE", StringComparison.OrdinalIgnoreCase);
    private bool IsInvoiceDrawdownGrid => IsMonthlyDrawdownGrid || IsPercentageDrawdownGrid;

    private bool BatchGridVisible { get; set; }
    private IEnumerable<ExpandoObject>? CurrentGridItems { get; set; }

    private bool ShouldUseActivityBulkUpdateGrid =>
        string.Equals(GridCode, "JOBACTIVITY", StringComparison.OrdinalIgnoreCase)
        || string.Equals(ViewDefinition?.Code, "JOBACTIVITY", StringComparison.OrdinalIgnoreCase)
        || string.Equals(ViewDefinition?.DetailPageUri, "ActivityBatchGridView", StringComparison.OrdinalIgnoreCase)
        || string.Equals(ViewDefinition?.DetailPageUri, "ActivityBulkUpdateGrid", StringComparison.OrdinalIgnoreCase)
        || string.Equals(ViewDefinition?.Name, "Job Activity", StringComparison.OrdinalIgnoreCase);
    private string Placeholder { get; set; } = "Search...";
    private bool WindowIsVisible { get; set; }
    private string? WindowTitle { get; set; }
    private bool ComingFromModal { get; set; }
    private bool _isDetailNewRecord;

    private string DetailWindowStateCss => _isDetailNewRecord ? "is-new" : "is-edit";
    private string DetailWindowIconCss => _isDetailNewRecord ? "bi-plus-circle-fill" : "bi-pencil-square";
    private string DetailWindowTitle => $"{(_isDetailNewRecord ? "New" : "Edit")} {WindowTitle ?? ViewDefinition?.Name ?? "record"}";
    private string DetailWindowSubtitle => _isDetailNewRecord
        ? "Complete the required fields, then save when ready."
        : "Review and update this record, then save when ready.";

    private string DetailPanelDomId => $"dynamic-grid-view-detail-{modalId}";

    private string DetailPanelInlineStyle => _isDetailNewRecord
        ? "position:relative;overflow:hidden;margin:0 0 1rem 0;border:2px solid #86efac;border-radius:18px;background:radial-gradient(circle at top left, rgba(34, 197, 94, .12), transparent 34%), linear-gradient(180deg, #ffffff 0%, #f0fdf4 100%);box-shadow:0 12px 32px rgba(15, 23, 42, .08);"
        : "position:relative;overflow:hidden;margin:0 0 1rem 0;border:2px solid #93c5fd;border-radius:18px;background:radial-gradient(circle at top left, rgba(59, 130, 246, .13), transparent 34%), linear-gradient(180deg, #ffffff 0%, #eff6ff 100%);box-shadow:0 12px 32px rgba(59, 130, 246, .10);";

    private string DetailPanelAccentInlineStyle => _isDetailNewRecord
        ? "position:absolute;inset:0 auto 0 0;width:5px;background:#22c55e;"
        : "position:absolute;inset:0 auto 0 0;width:5px;background:#3b82f6;";

    private string DetailPanelIconInlineStyle => _isDetailNewRecord
        ? "width:40px;height:40px;flex:0 0 40px;display:inline-flex;align-items:center;justify-content:center;border-radius:14px;color:#15803d;background:#dcfce7;box-shadow:inset 0 0 0 1px rgba(34, 197, 94, .18);"
        : "width:40px;height:40px;flex:0 0 40px;display:inline-flex;align-items:center;justify-content:center;border-radius:14px;color:#1d4ed8;background:#dbeafe;box-shadow:inset 0 0 0 1px rgba(59, 130, 246, .18);";

    private string MonthlySeriesPanelInlineStyle => !string.IsNullOrWhiteSpace(MonthlySeriesError)
        ? "position:relative;overflow:hidden;margin:1rem 0;border:2px solid #fca5a5;border-radius:18px;background:#ffffff;box-shadow:0 14px 36px rgba(239, 68, 68, .12);"
        : "position:relative;overflow:hidden;margin:1rem 0;border:2px solid #86efac;border-radius:18px;background:#ffffff;box-shadow:0 12px 32px rgba(34, 197, 94, .10);";

    private string MonthlySeriesAccentInlineStyle => !string.IsNullOrWhiteSpace(MonthlySeriesError)
        ? "position:absolute;inset:0 auto 0 0;width:5px;background:#ef4444;"
        : "position:absolute;inset:0 auto 0 0;width:5px;background:#22c55e;";

    private string MonthlySeriesPanelStateCss => !string.IsNullOrWhiteSpace(MonthlySeriesError)
        ? "has-validation"
        : "is-new";

    [Parameter] public Dictionary<string, Any> TransientVirtualProperties { get; set; } = new();
    [Parameter] public FormHelper? FormHelper { get; set; }
    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = string.Empty;
    public bool HasChanges { get; private set; }
    [Parameter] public EventCallback<InputUpdatedArgs> inputUpdated { get; set; }
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public EventCallback<string> ParentGuidChanged { get; set; }
    [Parameter] public DrawerItem SelectedItem { get; set; } = new();
    [Parameter] public EventCallback<DrawerItem> SelectedItemChanged { get; set; }
    [Parameter]
    public GridViewDefinition? ViewDefinition
    {
        get => _viewDefinition;
        set
        {
            if (ReferenceEquals(_viewDefinition, value)) return;

            var currentIdentity = GetViewDefinitionIdentity(_viewDefinition);
            var nextIdentity = GetViewDefinitionIdentity(value);

            _viewDefinition = value;

            if (string.Equals(currentIdentity, nextIdentity, StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            _isInitialised = false;
            _lastParameterLoadKey = null;
        }
    }

    [Parameter] public bool DoubleClickDisabled { get; set; }
    [Parameter] public bool Disabled { get; set; }
    [Parameter] public EventCallback ResyncDataObject { get; set; }
    [Parameter] public int ParentRowStatus { get; set; } = -1;

    protected string ErrorMessage { get; set; } = string.Empty;
    protected ShowMessageType MessageType { get; set; } = ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";
    protected FormHelper? formHelper;
    private readonly HashSet<string> _excludedSearchColumns = new(StringComparer.OrdinalIgnoreCase);
    private IReadOnlyList<GridViewColumnDefinition> VisibleColumns =>
        ViewDefinition?.Columns?
            .Where(c => !c.IsHidden)
            .OrderBy(c => c.ColumnOrder)
            .ToList()
        ?? new List<GridViewColumnDefinition>();

    private int VisibleColumnCount => Math.Max(VisibleColumns.Count, 1);

    private bool ShouldShowCsvExportButton =>
        ViewDefinition is not null &&
        (string.Equals(ViewDefinition.Code, "OVERDUEACTIVITIES", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(ViewDefinition.Code, "ENGJOBSFINANCE", StringComparison.OrdinalIgnoreCase) ||
         string.Equals(ViewDefinition.Code, "OVERDUEMILESTONES", StringComparison.OrdinalIgnoreCase) ||
         string.Equals(GridCode, "OVERDUEACTIVITIES", StringComparison.OrdinalIgnoreCase) ||
         string.Equals(GridCode, "OVERDUEMILESTONES", StringComparison.OrdinalIgnoreCase));

    protected override async Task OnParametersSetAsync()
    {
        if (_suppressParameterReload || ViewDefinition is null) return;

        var requiresInitialLoad = !_isInitialised;
        if (requiresInitialLoad)
        {
            await RestoreNativeGridStateAsync();
            ApplyDefaultSortIfNeeded();
            _isInitialised = true;
        }

        var parameterLoadKey = BuildParameterLoadKey();
        if (!requiresInitialLoad && string.Equals(_lastParameterLoadKey, parameterLoadKey, StringComparison.Ordinal))
        {
            return;
        }

        _lastParameterLoadKey = parameterLoadKey;
        await LoadPageAsync(preservePage: true);
    }
    private static string GetViewDefinitionIdentity(GridViewDefinition? viewDefinition)
    {
        if (viewDefinition is null)
        {
            return string.Empty;
        }

        return string.Join(
            "|",
            viewDefinition.Code ?? string.Empty,
            viewDefinition.RowVersion ?? string.Empty,
            viewDefinition.GridDefinitionId.ToString(CultureInfo.InvariantCulture),
            viewDefinition.Columns?.Count.ToString(CultureInfo.InvariantCulture) ?? "0",
            viewDefinition.DefaultSortColumnName ?? string.Empty,
            viewDefinition.DetailPageUri ?? string.Empty);
    }

    private string BuildParameterLoadKey()
    {
        var viewCode = ViewDefinition?.Code ?? string.Empty;
        var entityTypeGuid = ViewDefinition?.EntityTypeGuid ?? string.Empty;
        var selectedCode = SelectedItem?.ViewDefinition?.Code
            ?? ViewDefinition?.Code
            ?? string.Empty;
        var parentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString();
        var parentReferenceGuid = ParentDataObjectReference?.DataObjectGuid.ToString() ?? string.Empty;

        return string.Join(
            "|",
            GridCode ?? string.Empty,
            viewCode,
            entityTypeGuid,
            selectedCode,
            parentGuid,
            parentReferenceGuid,
            FullGrid.ToString(CultureInfo.InvariantCulture),
            ParentRowStatus.ToString(CultureInfo.InvariantCulture));
    }

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (WindowIsVisible && ViewDefinition?.IsDetailWindowed == true)
        {
            await EnsureDetailPanelValidationObserverAsync();
        }

        if (_scrollDetailPanelIntoViewAfterRender && WindowIsVisible && ViewDefinition?.IsDetailWindowed == true)
        {
            _scrollDetailPanelIntoViewAfterRender = false;
            await ScrollDetailPanelIntoViewAsync();
        }
    }

    private async Task EnsureDetailPanelValidationObserverAsync()
    {
        try
        {
            await JsRuntime.InvokeVoidAsync(
                "cymbuildDynamicGridView.ensureValidationObserver",
                DetailPanelDomId);
        }
        catch (JSException ex)
        {
            Console.WriteLine(ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            Console.WriteLine(ex.Message);
        }
    }

    private async Task ScrollDetailPanelIntoViewAsync()
    {
        try
        {
            await JsRuntime.InvokeVoidAsync(
                "cymbuildDynamicGridView.scrollIntoViewById",
                DetailPanelDomId);
        }
        catch (JSException ex)
        {
            Console.WriteLine(ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            Console.WriteLine(ex.Message);
        }
    }

    public static string ConvertBooleanStringToYesNo(string booleanString)
    {
        if (booleanString.Equals("True", StringComparison.OrdinalIgnoreCase)) return "Yes";
        return booleanString.Equals("False", StringComparison.OrdinalIgnoreCase) ? "No" : booleanString;
    }

    public void AddProperty(ExpandoObject expando, string propertyName, object propertyValue)
    {
        try
        {
            var expandoDict = (IDictionary<string, object>)expando;
            if (expandoDict.ContainsKey(propertyName)) expandoDict[propertyName] = propertyValue;
            else expandoDict.Add(propertyName, propertyValue);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while adding a property to the ExpandoObject.");
            ex.Data.Add("PageMethod", "DynamicGridView/AddProperty()");
            _ = OnError(ex);
        }
    }

    public RenderFragment<object> GetColumnTemplate(string propName)
    {
        RenderFragment<object> fragment = context => builder =>
        {
            if (context is not ExpandoObject expandoObject) return;
            var dictionary = (IDictionary<string, object>)expandoObject;
            if (dictionary.TryGetValue(propName, out var propValue)) builder.AddContent(0, propValue);
        };

        return fragment;
    }

    public async Task RefreshMe()
    {
        await LoadPageAsync(preservePage: true);
    }

    public async void RefreshGrid()
    {
        await LoadPageAsync(preservePage: true);
    }

    protected async Task AddNew()
    {
        try
        {
            _ = GetScrollBarPos();

            if (string.Equals(GridCode, "INVSCEDMONTHLY", StringComparison.OrdinalIgnoreCase))
            {
                OpenMonthlySeriesModal();
                return;
            }

            if (ViewDefinition is null) return;

            await EnsureCorrectParentGuid();

            var (parentDataObjectReference, serializedParentDataObjectReference) =
                PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, ParentGuid, ViewDefinition.EntityTypeGuid);

            if (ViewDefinition.IsDetailWindowed)
            {
                if (string.IsNullOrWhiteSpace(ViewDefinition.DetailPageUri))
                {
                    throw new InvalidOperationException("DetailPageUri is not set in the ViewDefinition.");
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
                _detailPageParameters.Add("IsMainRecordContext", false);
                _detailPageParameters.Add("TransientVirtualProperties", TransientVirtualProperties);

                _detailPageType = ResolveDetailPageType(ViewDefinition.DetailPageUri);
                modalService.RegisterModal(modalId, parentDataObjectReference);
                WindowTitle = ViewDefinition.Name;
                _isDetailNewRecord = true;
                WindowIsVisible = true;
                _scrollDetailPanelIntoViewAfterRender = true;

                InteractionTracker.Log(NavManager.Uri ?? "Clicking New Button", $"User Clicked \"New\" button - '{ViewDefinition.Code}'");
            }
            else
            {
                InteractionTracker.Log(NavManager.Uri ?? "Clicking New Button", $"User Clicked \"New\" button - '{ViewDefinition.Code}'");

                var returnUrl = System.Web.HttpUtility.UrlEncode(NavManager.Uri);
                if (ViewDefinition.DetailPageUri == "DynamicEdit")
                {
                    NavManager.NavigateTo(
                        $"{ViewDefinition.DetailPageUri}/{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid)}/{parentDataObjectReference.DataObjectGuid}/{serializedParentDataObjectReference}/{returnUrl}");
                }
                else
                {
                    NavManager.NavigateTo(
                        $"{ViewDefinition.DetailPageUri}/{Guid.Empty}/{serializedParentDataObjectReference}/{returnUrl}");
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while adding a new record to the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/AddNew()");
            await OnError(ex);
        }
        finally
        {
            StateHasChanged();
        }
    }

    protected async Task CloseWindow()
    {
        try
        {
            var modal = modalService.GetLatestModal();
            if (modal != null) modalService.UnregisterModal(modal.Value.ModalId);

            WindowIsVisible = false;
            _isDetailNewRecord = false;
            _detailPageParameters.Clear();
            _detailPageType = null;

            if (!ComingFromModal)
            {
                await LoadPageAsync(preservePage: true);

                if (ResyncDataObject.HasDelegate) await ResyncDataObject.InvokeAsync();

                await OnActionCompleted.InvokeAsync();
                await SetScrollBarPos();
            }
            else
            {
                await LoadPageAsync(preservePage: true);
                ComingFromModal = false;
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while closing the window in the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/CloseWindow()");
            await OnError(ex);
        }
    }

    protected async Task GridUpdated()
    {
        try
        {
            if (!ComingFromModal)
            {
                await EnsureCorrectParentGuid();
                await LoadPageAsync(preservePage: true);
            }
            else
            {
                await LoadPageAsync(preservePage: true);
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/GridUpdated()");
            await OnError(ex);
        }
    }

    private async Task LoadPageAsync(bool preservePage)
    {
        if (ViewDefinition is null)
        {
            return;
        }

        try
        {
            _isLoading = true;
            _statusText = null;
            ClearGridErrorState();
            StateHasChanged();

            await EnsureCorrectParentGuid();

            var parsedParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString();
            if (parsedParentGuid == Guid.Empty.ToString() && !FullGrid)
            {
                _rows.Clear();
                CurrentGridItems = _rows;
                _totalRows = 0;
                _totalPages = 1;
                return;
            }

            if (!preservePage)
            {
                _page = 1;
            }

            if (_page < 1)
            {
                _page = 1;
            }

            await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_currentPageNumber", _page);

            var request = new GridDataListRequest
            {
                GridCode = GridCode,
                GridViewCode = ViewDefinition.Code,
                Page = _page,
                PageSize = _pageSize,
                ParentGuid = parsedParentGuid
            };

            var filter = BuildCompositeFilter();
            if (filter is not null)
            {
                request.Filters.Add(filter);
            }

            if (!string.IsNullOrWhiteSpace(_sortColumn))
            {
                request.Sort.Add(new DataSort
                {
                    ColumnName = _sortColumn,
                    Direction = _sortDescending ? "Descending" : "Ascending"
                });
            }

            var reply = await coreClient.GridDataListAsync(request);

            _rows.Clear();

            if (!IsInvoiceDrawdownGrid)
            {
                IsDrawdownInlineEditing = false;
                DrawdownInlineError = null;
                _drawdownInlineOriginalRows.Clear();
            }

            foreach (var r in reply.DataTable)
            {
                dynamic dataObj = new ExpandoObject();
                var dictionary = (IDictionary<string, object>)dataObj;

                foreach (var c in r.Columns)
                {
                    dictionary[c.Name] = FormatGridColumnValue(c.Name, c.Value);
                }

                _rows.Add(dataObj);
            }

            _totalRows = (int)reply.TotalRows;
            _totalPages = Math.Max(1, (int)Math.Ceiling(_totalRows / (double)_pageSize));

            if (_page > _totalPages)
            {
                _page = _totalPages;
                await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_currentPageNumber", _page);
            }

            CurrentGridItems = _rows;
            UpdateStatusText();
            ClearGridErrorState();
        }
        catch (Exception ex)
        {
            if (TryExcludeInvalidServerFilterColumn(ex, out var invalidColumnName))
            {
                _statusText = $"Search adjusted: column '{invalidColumnName}' is not available in the server query for this view.";

                ClearGridErrorState();

                try
                {
                    await LoadPageAsync(preservePage: true);
                    ClearGridErrorState();
                    return;
                }
                catch
                {
                    throw;
                }
            }

            ex.Data.Add("MessageType", ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/LoadPageAsync()");
            await OnError(ex);
        }
        finally
        {
            _isLoading = false;
            StateHasChanged();
        }
    }

    private bool IsServerFilterColumnExcluded(GridViewColumnDefinition column)
    {
        if (column is null)
        {
            return true;
        }

        if (!string.IsNullOrWhiteSpace(column.Name)
            && _serverFilterExcludedColumns.Contains(column.Name))
        {
            return true;
        }

        if (!string.IsNullOrWhiteSpace(column.Title)
            && _serverFilterExcludedColumns.Contains(column.Title))
        {
            return true;
        }

        return false;
    }

    private DataCompositeFilter? BuildCompositeFilter()
    {
        var root = new DataCompositeFilter { LogicalOperator = "AND" };

        foreach (var filter in _filtersByColumn.Values.Where(f => !string.IsNullOrWhiteSpace(f.Value)))
        {
            if (_serverFilterExcludedColumns.Contains(filter.ColumnName)) continue;

            var dataFilter = CreateDataFilter(filter.ColumnName, filter.Value, "contains");

            // The current UiService conversion path reads only the child CompositeFilters from
            // the first request filter.  Keep the client-side filter shape compatible with that
            // existing API behaviour so the EF SQL predicate always receives a populated
            // LogicalOperator and does not generate an empty operator between predicates.
            root.CompositeFilters.Add(CreateServerCompatibleFilterGroup("AND", new[] { dataFilter }));

            LogFilter(filter.ColumnName, "contains", filter.Value);
        }

        if (!string.IsNullOrWhiteSpace(_searchText) && ViewDefinition?.Columns is not null)
        {
            var searchableFilters = ViewDefinition.Columns
                .Where(c => !c.IsHidden)
                .Where(c => !IsServerFilterColumnExcluded(c))
                .Select(c => c.Name)
                .Where(n => !string.IsNullOrWhiteSpace(n))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Select(column => CreateDataFilter(column, _searchText, "contains"))
                .ToList();

            if (searchableFilters.Count > 0)
            {
                root.CompositeFilters.Add(CreateServerCompatibleFilterGroup("OR", searchableFilters));
            }
        }

        return root.CompositeFilters.Count == 0 ? null : root;
    }

    private bool TryExcludeInvalidServerFilterColumn(Exception exception, out string invalidColumnName)
    {
        invalidColumnName = string.Empty;

        if (string.IsNullOrWhiteSpace(_searchText)
            && !_filtersByColumn.Values.Any(f => !string.IsNullOrWhiteSpace(f.Value)))
        {
            return false;
        }

        var message = exception.ToString();
        const string marker = "Invalid column name '";

        var start = message.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
        if (start < 0)
        {
            return false;
        }

        start += marker.Length;

        var end = message.IndexOf("'", start, StringComparison.Ordinal);
        if (end <= start)
        {
            return false;
        }

        invalidColumnName = message[start..end].Trim();

        if (string.IsNullOrWhiteSpace(invalidColumnName))
        {
            return false;
        }

        // Important: copy the out parameter to a normal local variable
        // before using it in LINQ/lambda expressions.
        var excludedColumnName = invalidColumnName;

        var added = _serverFilterExcludedColumns.Add(excludedColumnName);

        var matchingColumnNames = ViewDefinition?.Columns?
            .Where(c =>
                string.Equals(c.Name, excludedColumnName, StringComparison.OrdinalIgnoreCase)
                || string.Equals(c.Title, excludedColumnName, StringComparison.OrdinalIgnoreCase))
            .Select(c => c.Name)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList()
            ?? new List<string>();

        foreach (var columnName in matchingColumnNames)
        {
            _serverFilterExcludedColumns.Add(columnName);
            _filtersByColumn.Remove(columnName);
        }

        _filtersByColumn.Remove(excludedColumnName);

        return added || matchingColumnNames.Count > 0;
    }

    private static DataCompositeFilter CreateServerCompatibleFilterGroup(string logicalOperator, IEnumerable<DataFilter> filters)
    {
        var group = new DataCompositeFilter
        {
            LogicalOperator = string.IsNullOrWhiteSpace(logicalOperator) ? "AND" : logicalOperator
        };

        foreach (var filter in filters)
        {
            var leaf = new DataCompositeFilter
            {
                LogicalOperator = "AND"
            };

            leaf.Filters.Add(filter);
            group.CompositeFilters.Add(leaf);
        }

        return group;
    }

    private static DataFilter CreateDataFilter(string columnName, string value, string op)
    {
        var normalizedOperator = string.IsNullOrWhiteSpace(op)
            ? "contains"
            : op.Trim().ToLowerInvariant();

        var trimmed = value.Trim();
        if (trimmed.Equals("yes", StringComparison.OrdinalIgnoreCase)) trimmed = "1";
        else if (trimmed.Equals("no", StringComparison.OrdinalIgnoreCase)) trimmed = "0";

        return new DataFilter
        {
            ColumnName = columnName,
            Guid = System.Guid.NewGuid().ToString(),
            Operator = normalizedOperator,
            DataType = string.Empty,
            Value = Google.Protobuf.WellKnownTypes.Value.ForString(trimmed)
        };
    }

    private void OnSearchChanged(ChangeEventArgs args)
    {
        _searchText = args.Value?.ToString() ?? string.Empty;
    }

    private async Task ApplySearchAsync()
    {
        CancelQueuedFilterReload();
        _page = 1;
        await SaveNativeGridStateAsync();
        await LoadPageAsync(preservePage: true);
    }

    private async Task ClearSearchAsync()
    {
        CancelQueuedFilterReload();
        if (string.IsNullOrWhiteSpace(_searchText)) return;

        _searchText = string.Empty;
        _page = 1;
        await SaveNativeGridStateAsync();
        await LoadPageAsync(preservePage: true);
    }

    private void OnColumnFilterChanged(string columnName, ChangeEventArgs args)
    {
        var value = args.Value?.ToString() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(value)) _filtersByColumn.Remove(columnName);
        else _filtersByColumn[columnName] = new NativeColumnFilter(columnName, value);
    }

    private void ToggleFilterPanel()
    {
        _isFilterPanelOpen = !_isFilterPanelOpen;
    }

    private async Task ApplyFiltersAsync()
    {
        CancelQueuedFilterReload();
        _page = 1;
        await SaveNativeGridStateAsync();
        await LoadPageAsync(preservePage: true);
    }

    private void QueueFilterReload()
    {
        CancelQueuedFilterReload();

        var cancellationTokenSource = new CancellationTokenSource();
        _filterDebounceCancellationTokenSource = cancellationTokenSource;

        _ = DebouncedFilterReloadAsync(cancellationTokenSource);
    }

    private async Task DebouncedFilterReloadAsync(CancellationTokenSource cancellationTokenSource)
    {
        try
        {
            await Task.Delay(FilterInputDebounceMilliseconds, cancellationTokenSource.Token);

            if (cancellationTokenSource.IsCancellationRequested) return;

            await InvokeAsync(async () =>
            {
                if (cancellationTokenSource.IsCancellationRequested) return;

                await SaveNativeGridStateAsync();
                await LoadPageAsync(preservePage: true);
            });
        }
        catch (OperationCanceledException)
        {
            // Expected when the user keeps typing or the component is disposed.
        }
        finally
        {
            if (ReferenceEquals(_filterDebounceCancellationTokenSource, cancellationTokenSource))
            {
                _filterDebounceCancellationTokenSource = null;
            }

            cancellationTokenSource.Dispose();
        }
    }

    private void CancelQueuedFilterReload()
    {
        var cancellationTokenSource = _filterDebounceCancellationTokenSource;
        if (cancellationTokenSource is null) return;

        _filterDebounceCancellationTokenSource = null;
        cancellationTokenSource.Cancel();
    }

    private async Task ClearFiltersAsync()
    {
        CancelQueuedFilterReload();
        _filtersByColumn.Clear();
        _searchText = string.Empty;
        _sortColumn = ViewDefinition?.DefaultSortColumnName;
        _sortDescending = ViewDefinition?.IsDefaultSortDescending ?? false;
        _page = 1;

        if (ViewDefinition is not null)
        {
            await LocalStorageAccessor.RemoveAsync($"{ViewDefinition.Code}_gridState");
            await LocalStorageAccessor.RemoveAsync($"{ViewDefinition.Code}_nativeGridState");
            await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_currentPageNumber", _page);
        }

        await LoadPageAsync(preservePage: true);
    }

    private string GetColumnFilterValue(string columnName) =>
        _filtersByColumn.TryGetValue(columnName, out var filter) ? filter.Value : string.Empty;

    private async Task ToggleSortAsync(string columnName)
    {
        if (string.Equals(_sortColumn, columnName, StringComparison.OrdinalIgnoreCase))
        {
            _sortDescending = !_sortDescending;
        }
        else
        {
            _sortColumn = columnName;
            _sortDescending = false;
        }

        _page = 1;
        await SaveNativeGridStateAsync();
        await LoadPageAsync(preservePage: true);
    }

    private async Task FirstPageAsync()
    {
        if (_page <= 1) return;
        _page = 1;
        await LoadPageAsync(preservePage: true);
    }

    private async Task PrevPageAsync()
    {
        if (_page <= 1) return;
        _page--;
        await LoadPageAsync(preservePage: true);
    }

    private async Task NextPageAsync()
    {
        if (_page >= _totalPages) return;
        _page++;
        await LoadPageAsync(preservePage: true);
    }

    private async Task LastPageAsync()
    {
        if (_page >= _totalPages) return;
        _page = _totalPages;
        await LoadPageAsync(preservePage: true);
    }

    private async Task OnPageInputChangedAsync(ChangeEventArgs args)
    {
        if (int.TryParse(args.Value?.ToString(), out var page)) _page = page;
        if (_page < 1) _page = 1;
        if (_page > _totalPages) _page = _totalPages;
        await LoadPageAsync(preservePage: true);
    }

    private async Task OnPageSizeChangedAsync(ChangeEventArgs args)
    {
        if (int.TryParse(args.Value?.ToString(), out var pageSize) && pageSize > 0) _pageSize = pageSize;
        _page = 1;
        await SaveNativeGridStateAsync();
        await LoadPageAsync(preservePage: true);
    }

    private void ApplyDefaultSortIfNeeded()
    {
        if (ViewDefinition is null) return;
        if (!string.IsNullOrWhiteSpace(_sortColumn)) return;

        _sortColumn = ViewDefinition.DefaultSortColumnName;
        _sortDescending = ViewDefinition.IsDefaultSortDescending;
    }

    private async Task RestoreNativeGridStateAsync()
    {
        if (ViewDefinition is null) return;

        var savedPageNumber = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_currentPageNumber");
        if (int.TryParse(savedPageNumber, out var pageNumber) && pageNumber > 0) _page = pageNumber;

        var savedNativeState = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_nativeGridState");
        if (string.IsNullOrWhiteSpace(savedNativeState) || !FullGrid) return;

        try
        {
            var state = JsonSerializer.Deserialize<NativeGridState>(savedNativeState);
            if (state is null) return;
            if (!string.Equals(state.Code, ViewDefinition.Code, StringComparison.OrdinalIgnoreCase)) return;
            if (!string.Equals(state.GridCode, GridCode, StringComparison.OrdinalIgnoreCase)) return;

            _searchText = state.SearchText ?? string.Empty;
            _sortColumn = state.SortColumn;
            _sortDescending = state.SortDescending;
            _pageSize = state.PageSize > 0 ? state.PageSize : _pageSize;
            _filtersByColumn.Clear();

            foreach (var filter in state.Filters ?? new List<NativeColumnFilter>())
            {
                if (!string.IsNullOrWhiteSpace(filter.ColumnName) && !string.IsNullOrWhiteSpace(filter.Value))
                    _filtersByColumn[filter.ColumnName] = filter;
            }
        }
        catch
        {
            await LocalStorageAccessor.RemoveAsync($"{ViewDefinition.Code}_nativeGridState");
        }
    }

    private async Task SaveNativeGridStateAsync()
    {
        if (ViewDefinition is null || !FullGrid) return;

        var hasState = !string.IsNullOrWhiteSpace(_searchText) ||
                       _filtersByColumn.Count > 0 ||
                       !string.IsNullOrWhiteSpace(_sortColumn);

        if (!hasState)
        {
            await LocalStorageAccessor.RemoveAsync($"{ViewDefinition.Code}_nativeGridState");
            return;
        }

        var state = new NativeGridState
        {
            Code = ViewDefinition.Code,
            GridCode = GridCode,
            SearchText = _searchText,
            SortColumn = _sortColumn,
            SortDescending = _sortDescending,
            PageSize = _pageSize,
            Filters = _filtersByColumn.Values.ToList()
        };

        await LocalStorageAccessor.SetValueAsync(
            $"{ViewDefinition.Code}_nativeGridState",
            JsonSerializer.Serialize(state, new JsonSerializerOptions { WriteIndented = true }));
    }

    private void UpdateStatusText()
    {
        var parts = new List<string>();
        if (!string.IsNullOrWhiteSpace(_sortColumn)) parts.Add($"Sort: {_sortColumn} {(_sortDescending ? "DESC" : "ASC")}");
        if (!string.IsNullOrWhiteSpace(_searchText)) parts.Add("Search active");
        if (_filtersByColumn.Count > 0) parts.Add($"{_filtersByColumn.Count} filter{(_filtersByColumn.Count == 1 ? string.Empty : "s")}");
        _statusText = parts.Count == 0 ? null : string.Join(" Ã‚Â· ", parts);
    }

    private void LogFilter(string columnName, string op, string value)
    {
        var key = $"{columnName}|{op}|{value}";
        if (!_loggedFilters.Add(key)) return;

        InteractionTracker.Log(
            NavManager.Uri,
            $"Filter added to Grid - '{ViewDefinition?.Name ?? "Unknown"}' Filter: '{columnName}' Operator: '{op}' Value: '{value}'");
    }

    private object FormatGridColumnValue(string columnName, string value)
    {
        if (string.IsNullOrWhiteSpace(value)) return string.Empty;

        if (CheckIfMobileNumber(columnName, value)) return value;
        if (int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var intValue)) return intValue;

        if (decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out var decimalValue) ||
            decimal.TryParse(value, NumberStyles.Number, CultureInfo.CurrentCulture, out decimalValue))
        {
            return decimalValue.ToString("F2", CultureInfo.CurrentCulture);
        }

        if (bool.TryParse(value, out var boolValue)) return boolValue ? "Yes" : "No";
        if (Guid.TryParse(value, out var guidValue)) return guidValue.ToString();

        if (DateTime.TryParse(value, CultureInfo.CurrentCulture, DateTimeStyles.AssumeLocal, out var dateTimeValue) ||
            DateTime.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out dateTimeValue))
        {
            var localDateTime = UiFormattingHelper.NormalizeToLocal(dateTimeValue);
            var isDateOnly = columnName.ToLowerInvariant().EndsWith("date") && !columnName.ToLowerInvariant().Contains("time");
            return UiFormattingHelper.FormatDateForUI(localDateTime, isDateOnly);
        }

        return value;
    }

    private static bool CheckIfMobileNumber(string columnName, string columnValue)
    {
        if (string.IsNullOrWhiteSpace(columnValue)) return false;
        if (columnName.Contains("date", StringComparison.OrdinalIgnoreCase)) return false;

        return (columnValue.StartsWith("0", StringComparison.Ordinal) && !columnValue.Contains('/')) ||
               columnValue.StartsWith("44", StringComparison.Ordinal) ||
               columnValue.StartsWith("+", StringComparison.Ordinal);
    }

    protected Task ResetDataObjectGuid()
    {
        if (modalService.GetOpenModals().Count <= 1) dataObjGuid = string.Empty;
        return Task.CompletedTask;
    }


    private async Task StartDrawdownInlineEditAsync()
    {
        if (!IsInvoiceDrawdownGrid || _rows.Count == 0)
        {
            return;
        }

        try
        {
            DrawdownInlineError = null;
            await EnsureDrawdownStageOptionsLoadedAsync();

            _drawdownInlineOriginalRows.Clear();
            foreach (var row in _rows)
            {
                var rowKey = GetDrawdownRowKey(row);
                if (string.IsNullOrWhiteSpace(rowKey))
                {
                    continue;
                }

                var source = (IDictionary<string, object>)row;
                _drawdownInlineOriginalRows[rowKey] = source.ToDictionary(kvp => kvp.Key, kvp => (object?)kvp.Value, StringComparer.OrdinalIgnoreCase);
            }

            IsDrawdownInlineEditing = true;
            await InvokeAsync(StateHasChanged);
        }
        catch (Exception ex)
        {
            DrawdownInlineError = ex.Message;
            await InvokeAsync(StateHasChanged);
        }
    }

    private void CancelDrawdownInlineEdit()
    {
        foreach (var row in _rows)
        {
            var rowKey = GetDrawdownRowKey(row);
            if (string.IsNullOrWhiteSpace(rowKey) || !_drawdownInlineOriginalRows.TryGetValue(rowKey, out var original))
            {
                continue;
            }

            var target = (IDictionary<string, object>)row;
            target.Clear();
            foreach (var kvp in original)
            {
                target[kvp.Key] = kvp.Value ?? string.Empty;
            }
        }

        IsDrawdownInlineEditing = false;
        IsDrawdownInlineSaving = false;
        DrawdownInlineError = null;
        _drawdownInlineOriginalRows.Clear();
        StateHasChanged();
    }

    private async Task SaveDrawdownInlineEditAsync()
    {
        if (!IsInvoiceDrawdownGrid)
        {
            return;
        }

        try
        {
            DrawdownInlineError = null;

            if (!TryResolveInvoiceScheduleGuid(out var invoiceScheduleGuid))
            {
                DrawdownInlineError = "Invoice Schedule must be saved before drawdowns can be edited.";
                return;
            }

            var rows = BuildDrawdownInlineSaveRows();
            if (rows.Count == 0)
            {
                DrawdownInlineError = "There are no drawdown rows to save.";
                return;
            }

            IsDrawdownInlineSaving = true;
            await InvokeAsync(StateHasChanged);

            var helper = FormHelper ?? formHelper
                ?? throw new InvalidOperationException(
                    "FormHelper is required for invoice schedule drawdown amendments.");

            var updatedCount = await helper.InvoiceScheduleDrawdownsBulkUpdateAsync(
                invoiceScheduleGuid,
                GridCode,
                rows,
                bypassReadOnlyForAutomationReenable:
                    GetTransientBool(BypassReadOnlyForAutomationReenableKey));

            IsDrawdownInlineEditing = false;
            _drawdownInlineOriginalRows.Clear();
            Toast.ShowSuccess($"Saved {updatedCount} drawdown row(s).");

            await LoadPageAsync(preservePage: true);

            if (OnActionCompleted.HasDelegate)
            {
                await OnActionCompleted.InvokeAsync();
            }

            if (ResyncDataObject.HasDelegate)
            {
                await ResyncDataObject.InvokeAsync();
            }
        }
        catch (Exception ex)
        {
            DrawdownInlineError = ex.Message;
        }
        finally
        {
            IsDrawdownInlineSaving = false;
            await InvokeAsync(StateHasChanged);
        }
    }

    private async Task EnsureDrawdownStageOptionsLoadedAsync()
    {
        if (DrawdownStageOptions.Count > 0)
        {
            return;
        }

        if (!TryResolveInvoiceScheduleGuid(out var invoiceScheduleGuid))
        {
            return;
        }

        var helper = FormHelper ?? formHelper
            ?? throw new InvalidOperationException(
                "FormHelper is required for invoice schedule drawdown stage lookup.");

        DrawdownStageOptions =
            await helper.InvoiceScheduleDrawdownStageLookupGetAsync(invoiceScheduleGuid);
    }

    private List<InvoiceScheduleDrawdownBulkEditRowModel> BuildDrawdownInlineSaveRows()
    {
        var result = new List<InvoiceScheduleDrawdownBulkEditRowModel>();
        var index = 0;

        foreach (var row in _rows)
        {
            index++;
            var rowGuid = GetDrawdownGuid(row);
            if (rowGuid == Guid.Empty)
            {
                continue;
            }

            var onDayOfMonth = GetDrawdownDate(row);
            if (onDayOfMonth is null)
            {
                throw new InvalidOperationException($"Drawdown row {index} must have a valid date.");
            }

            var numericValue = GetDrawdownNumericValue(row);
            if (numericValue < 0)
            {
                throw new InvalidOperationException($"Drawdown row {index} must not have a negative value.");
            }

            result.Add(new InvoiceScheduleDrawdownBulkEditRowModel
            {
                Guid = rowGuid,
                PeriodNumber = GetDrawdownPeriodNumber(row, index),
                Amount = IsMonthlyDrawdownGrid ? numericValue : 0m,
                Percentage = IsPercentageDrawdownGrid ? numericValue : 0m,
                OnDayOfMonth = onDayOfMonth.Value,
                Description = GetDrawdownDescription(row),
                RibaStageGuid = GetDrawdownStageGuidValue(row)
            });
        }

        return result;
    }

    private bool IsDrawdownEditableColumn(GridViewColumnDefinition column)
    {
        return IsInvoiceDrawdownGrid
            && (IsDrawdownStageColumn(column)
                || IsDrawdownNumericColumn(column)
                || IsDrawdownDateColumn(column)
                || IsDrawdownDescriptionColumn(column));
    }

    private bool IsDrawdownStageColumn(GridViewColumnDefinition column)
    {
        return string.Equals(column.Name, "RibaStage", StringComparison.OrdinalIgnoreCase)
            || string.Equals(column.Name, "RibaStageID", StringComparison.OrdinalIgnoreCase)
            || string.Equals(column.Title, "Stage", StringComparison.OrdinalIgnoreCase);
    }

    private bool IsDrawdownNumericColumn(GridViewColumnDefinition column)
    {
        return (IsMonthlyDrawdownGrid && string.Equals(column.Name, "Amount", StringComparison.OrdinalIgnoreCase))
            || (IsPercentageDrawdownGrid && string.Equals(column.Name, "Percentage", StringComparison.OrdinalIgnoreCase))
            || (IsMonthlyDrawdownGrid && string.Equals(column.Title, "Amount", StringComparison.OrdinalIgnoreCase))
            || (IsPercentageDrawdownGrid && column.Title.Contains("percentage", StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsDrawdownDateColumn(GridViewColumnDefinition column)
    {
        return string.Equals(column.Name, "OnDayOfMonth", StringComparison.OrdinalIgnoreCase)
            || column.Title.Contains("day of month", StringComparison.OrdinalIgnoreCase)
            || column.Title.Contains("date", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsDrawdownDescriptionColumn(GridViewColumnDefinition column)
    {
        return string.Equals(column.Name, "Description", StringComparison.OrdinalIgnoreCase)
            || string.Equals(column.Title, "Description", StringComparison.OrdinalIgnoreCase);
    }

    private void UpdateDrawdownCell(ExpandoObject row, string columnName, string? value)
    {
        var dictionary = (IDictionary<string, object>)row;
        dictionary[columnName] = value ?? string.Empty;
    }

    private void UpdateDrawdownStage(ExpandoObject row, string? stageGuid)
    {
        var dictionary = (IDictionary<string, object>)row;
        var normalisedGuid = string.IsNullOrWhiteSpace(stageGuid) ? string.Empty : stageGuid.Trim();
        dictionary["RibaStageID"] = normalisedGuid;

        var stage = DrawdownStageOptions.FirstOrDefault(x =>
            string.Equals(x.Guid.ToString(), normalisedGuid, StringComparison.OrdinalIgnoreCase));

        dictionary["RibaStage"] = stage?.Name ?? string.Empty;
    }

    private string GetDrawdownStageGuid(ExpandoObject row)
    {
        var explicitGuid = GetRowValue(row, "RibaStageID");
        if (Guid.TryParse(explicitGuid, out var parsed) && parsed != Guid.Empty)
        {
            return parsed.ToString();
        }

        var stageName = GetRowValue(row, "RibaStage");
        var stage = DrawdownStageOptions.FirstOrDefault(x =>
            string.Equals(x.Name, stageName, StringComparison.OrdinalIgnoreCase));

        return stage?.Guid.ToString() ?? string.Empty;
    }

    private Guid? GetDrawdownStageGuidValue(ExpandoObject row)
    {
        var value = GetDrawdownStageGuid(row);
        return Guid.TryParse(value, out var parsed) && parsed != Guid.Empty ? parsed : null;
    }

    private string GetDrawdownDateInputValue(ExpandoObject row, string columnName)
    {
        return FormatDateInput(ParseGridDateCell(GetRowValue(row, columnName)));
    }

    private DateTime? GetDrawdownDate(ExpandoObject row)
    {
        var value = GetRowValue(row, "OnDayOfMonth");
        if (string.IsNullOrWhiteSpace(value))
        {
            value = GetRowValueByTitle("day of month", row);
        }

        return ParseGridDateCell(value);
    }

    private decimal GetDrawdownNumericValue(ExpandoObject row)
    {
        var value = IsMonthlyDrawdownGrid
            ? GetRowValue(row, "Amount")
            : GetRowValue(row, "Percentage");

        if (string.IsNullOrWhiteSpace(value))
        {
            value = IsMonthlyDrawdownGrid
                ? GetRowValueByTitle("amount", row)
                : GetRowValueByTitle("percentage", row);
        }

        return ParseDecimalInput(value) ?? 0m;
    }

    private string GetDrawdownDescription(ExpandoObject row)
    {
        return GetRowValue(row, "Description");
    }

    private int GetDrawdownPeriodNumber(ExpandoObject row, int fallback)
    {
        var value = GetRowValue(row, "PeriodNumber");
        return int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed) && parsed > 0
            ? parsed
            : fallback;
    }

    private Guid GetDrawdownGuid(ExpandoObject row)
    {
        var value = GetRowValue(row, "Guid");
        return Guid.TryParse(value, out var parsed) ? parsed : Guid.Empty;
    }

    private string GetDrawdownRowKey(ExpandoObject row)
    {
        var guid = GetDrawdownGuid(row);
        return guid != Guid.Empty ? guid.ToString() : string.Empty;
    }

    private string GetRowValue(ExpandoObject row, string columnName)
    {
        var dictionary = (IDictionary<string, object>)row;
        return dictionary.TryGetValue(columnName, out var value) ? value?.ToString() ?? string.Empty : string.Empty;
    }

    private string GetRowValueByTitle(string titleToken, ExpandoObject row)
    {
        var column = VisibleColumns.FirstOrDefault(x =>
            x.Title.Contains(titleToken, StringComparison.OrdinalIgnoreCase));

        return column is null ? string.Empty : GetRowValue(row, column.Name);
    }

    private static DateTime? ParseGridDateCell(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (DateTime.TryParse(value, CultureInfo.CurrentCulture, DateTimeStyles.AssumeLocal, out var current))
        {
            return current.Date;
        }

        if (DateTime.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out var invariant))
        {
            return invariant.Date;
        }

        return null;
    }

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
    }

    private void CloseMonthlySeriesModal()
    {
        IsMonthlySeriesModalVisible = false;
        MonthlySeriesError = null;
        MonthlySeriesSaving = false;
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

            var result = await res.Content.ReadFromJsonAsync<GenerateMonthlySeriesResponse>() ?? new GenerateMonthlySeriesResponse();
            Toast.ShowSuccess($"Generated {result.InsertedCount} monthly periods.");
            CloseMonthlySeriesModal();
            await LoadPageAsync(preservePage: true);

            if (ResyncDataObject.HasDelegate) await ResyncDataObject.InvokeAsync();
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

    private async Task ExportToCsvWithOptions()
    {
        if (ViewDefinition is null) return;

        try
        {
            var request = new GridDataListRequest
            {
                GridCode = GridCode,
                GridViewCode = ViewDefinition.Code,
                Page = 1,
                PageSize = 1000,
                ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString()
            };

            var filter = BuildCompositeFilter();
            if (filter is not null) request.Filters.Add(filter);

            if (!string.IsNullOrWhiteSpace(_sortColumn))
            {
                request.Sort.Add(new DataSort
                {
                    ColumnName = _sortColumn,
                    Direction = _sortDescending ? "Descending" : "Ascending"
                });
            }

            var reply = await coreClient.GridDataListAsync(request);
            var columns = ViewDefinition.Columns
                .Where(c => !c.IsHidden && !string.Equals(c.Name, "ID", StringComparison.OrdinalIgnoreCase) && !string.Equals(c.Name, "Guid", StringComparison.OrdinalIgnoreCase))
                .OrderBy(c => c.ColumnOrder)
                .ToList();

            var csv = new StringBuilder();
            csv.AppendLine(string.Join(",", columns.Select(c => EscapeCsv(c.Title))));

            foreach (var row in reply.DataTable)
            {
                var dict = row.Columns.ToDictionary(c => c.Name, c => FormatGridColumnValue(c.Name, c.Value)?.ToString() ?? string.Empty, StringComparer.OrdinalIgnoreCase);
                csv.AppendLine(string.Join(",", columns.Select(c => EscapeCsv(dict.TryGetValue(c.Name, out var value) ? value : string.Empty))));
            }

            var bytes = Encoding.UTF8.GetBytes(csv.ToString());
            var base64 = Convert.ToBase64String(bytes);
            var fileName = $"{SanitiseFileName(ViewDefinition.Name)}_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
            await JsRuntime.InvokeVoidAsync("BlazorDownloadFile", fileName, "text/csv;charset=utf-8", base64);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", ShowMessageType.Error);
            ex.Data.Add("PageMethod", "DynamicGridView/ExportToCsvWithOptions()");
            await OnError(ex);
        }
    }

    private async void CloseBatchGridModal()
    {
        BatchGridVisible = false;
        await GridUpdated();
        InteractionTracker.Log(NavManager.Uri, "Modal Closed");
        await SetScrollBarPos();
        StateHasChanged();
    }

    private async Task EnsureCorrectParentGuid()
    {
        if (ViewDefinition is null) return;

        if (ParentGuid == Guid.Empty.ToString() && ViewDefinition.IsDetailWindowed)
        {
            var numberOfModals = modalService.GetOpenModals().Count();
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
        catch (Exception ex)
        {
            Console.WriteLine(ex.Message);
        }
    }

    private async Task OnRowDoubleClickHandler(ExpandoObject row)
    {
        try
        {
            if (IsDrawdownInlineEditing || DoubleClickDisabled || ViewDefinition is null) return;
            if (string.IsNullOrWhiteSpace(ViewDefinition.DetailPageUri)) return;

            var dictionary = (IDictionary<string, object>)row;
            if (!dictionary.TryGetValue("Guid", out var guidObj)) return;

            var rowGuid = guidObj?.ToString() ?? Guid.Empty.ToString();
            if (rowGuid == Guid.Empty.ToString()) return;

            var isParentDataObjectReferenceDifferent =
                ParentDataObjectReference.EntityTypeGuid.ToString() != ViewDefinition.EntityTypeGuid;

            var (parentDataObjectReference, serializedParentDataObjectReference) =
                PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, rowGuid, ViewDefinition.EntityTypeGuid);

            if (ViewDefinition.IsDetailWindowed)
            {
                await GetScrollBarPos();
                modalId = Guid.NewGuid().ToString();
                _detailPageParameters.Clear();
                _detailPageParameters.Add("EntityTypeGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
                _detailPageParameters.Add("Windowed", true);
                _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
                _detailPageParameters.Add("GridUpdated", EventCallback.Factory.Create(this, GridUpdated));
                _detailPageParameters.Add("RecordGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(rowGuid).ToString());
                _detailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
                _detailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                _detailPageParameters.Add("ModalId", modalId);
                _detailPageParameters.Add("IsMainRecordContext", false);
                _detailPageParameters.Add("TransientVirtualProperties", TransientVirtualProperties);

                _detailPageType = ResolveDetailPageType(ViewDefinition.DetailPageUri);
                modalService.RegisterModal(modalId, parentDataObjectReference);
                WindowTitle = ViewDefinition.Name;
                _isDetailNewRecord = false;
                WindowIsVisible = true;
                ComingFromModal = true;
                _scrollDetailPanelIntoViewAfterRender = true;

                InteractionTracker.Log(
                    NavManager.Uri,
                    $"User Double Clicked Row in Grid - '{ViewDefinition.Name}' New Page Opened: '{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid)}'");
            }
            else
            {
                var guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(rowGuid).ToString();
                var encodedParentReference = serializedParentDataObjectReference;
                var currentUri = NavManager.Uri ?? string.Empty;
                var encodedReturnUrl = BuildSafeEncodedReturnUrl(currentUri);

                string url;
                if (ViewDefinition.DetailPageUri == "DynamicEdit")
                {
                    var entityTypeGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString();
                    url = $"{ViewDefinition.DetailPageUri}/{entityTypeGuid}/{parentDataObjectReference.DataObjectGuid}/{encodedParentReference}/{encodedReturnUrl}";
                }
                else
                {
                    url = $"{ViewDefinition.DetailPageUri}/{guid}/{encodedParentReference}/{encodedReturnUrl}";
                }

                if (isParentDataObjectReferenceDifferent)
                {
                    var navigateToDetailPage = "/" + ViewDefinition.DetailPageUri + "/";
                    var current = NavManager.Uri ?? string.Empty;
                    NavManager.NavigateTo(url, forceLoad: current.Contains(navigateToDetailPage, StringComparison.OrdinalIgnoreCase));
                }
                else
                {
                    NavManager.NavigateTo(url, forceLoad: true);
                }

                InteractionTracker.Log(
                    NavManager.Uri,
                    $"User Double Clicked Row in Grid - '{ViewDefinition.Name}' New Page Opened: '{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid)}'");
            }

            formHelper = new FormHelper(coreClient, sageIntegrationService, Guid.Empty.ToString(), userService);
            _ = formHelper.LogUsageAsync(
                PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid),
                PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while handling the row double-click event in the DynamicGridView.");
            ex.Data.Add("PageMethod", "DynamicGridView/OnRowDoubleClickHandler()");
            await OnError(ex);
        }
    }

    private void ClearGridErrorState()
    {
        ErrorMessage = string.Empty;
        PageMethod = string.Empty;
        MessageType = ShowMessageType.Information;

        _messageDisplay.ShowError(false);
        _messageDisplay.UpdateExceptionData(null);
        _messageDisplay.UpdateStackTrace(string.Empty);
    }

    private string GetRowCssClass(ExpandoObject row)
    {
        var dictionary = (IDictionary<string, object>)row;

        if (dictionary.TryGetValue("IsTotalHighlightRow", out var highlightValue) && highlightValue?.ToString() == "1")
            return "highlight-total-row";

        if (dictionary.TryGetValue("SubContractorName", out var totalValue) && string.Equals(totalValue?.ToString(), "Total", StringComparison.OrdinalIgnoreCase))
            return "highlight-total-row";

        return string.Empty;
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

    private bool GetTransientBool(string key, bool defaultValue = false)
    {
        if (TransientVirtualProperties is not null
            && TransientVirtualProperties.TryGetValue(key, out var anyValue)
            && anyValue is not null
            && anyValue.Is(BoolValue.Descriptor))
        {
            return anyValue.Unpack<BoolValue>().Value;
        }

        return defaultValue;
    }

    private bool TryResolveInvoiceScheduleGuid(out Guid invoiceScheduleGuid)
    {
        invoiceScheduleGuid = Guid.Empty;
        if (TryParseNonEmptyGuid(ParentGuid, out invoiceScheduleGuid)) return true;

        if (!string.IsNullOrWhiteSpace(ParentDataObjectReference?.DataObjectGuid.ToString()) &&
            Guid.TryParse(ParentDataObjectReference.DataObjectGuid.ToString(), out invoiceScheduleGuid) &&
            invoiceScheduleGuid != Guid.Empty)
        {
            return true;
        }

        return false;
    }

    private static bool TryParseNonEmptyGuid(string? value, out Guid guid)
    {
        guid = Guid.Empty;
        return !string.IsNullOrWhiteSpace(value) && Guid.TryParse(value, out guid) && guid != Guid.Empty;
    }

    private static System.Type? ResolveDetailPageType(string? detailPageUri)
    {
        if (string.IsNullOrWhiteSpace(detailPageUri)) return null;

        var candidates = new[]
        {
            $"Concursus.PWA.Pages.{detailPageUri}",
            $"Concursus.PWA.Pages.{detailPageUri}, Concursus.PWA",
            $"Concursus.PWA.Shared.{detailPageUri}",
            $"Concursus.PWA.Shared.{detailPageUri}, Concursus.PWA"
        };

        return candidates.Select(System.Type.GetType).FirstOrDefault(t => t is not null);
    }

    private static string BuildSafeEncodedReturnUrl(string currentUri)
    {
        var isListContext = false;
        try
        {
            var uri = new Uri(currentUri);
            var lastSegment = uri.AbsolutePath.Split('/', StringSplitOptions.RemoveEmptyEntries).LastOrDefault();
            isListContext = !string.IsNullOrWhiteSpace(lastSegment) &&
                            Guid.TryParse(lastSegment, out var lastGuid) &&
                            lastGuid == Guid.Empty;
        }
        catch
        {
            isListContext = currentUri.EndsWith(Guid.Empty.ToString(), StringComparison.OrdinalIgnoreCase);
        }

        if (isListContext) return System.Web.HttpUtility.UrlEncode(currentUri);

        var flattened = System.Web.HttpUtility.UrlDecode(currentUri) ?? string.Empty;
        var lastIndex = flattened.LastIndexOf("https://", StringComparison.OrdinalIgnoreCase);
        if (lastIndex >= 0) flattened = flattened[lastIndex..];

        return System.Web.HttpUtility.UrlEncode(flattened);
    }

    private static string GetCssWidth(string? width)
    {
        if (string.IsNullOrWhiteSpace(width)) return "220px";
        if (width.StartsWith("0", StringComparison.Ordinal)) return "220px";
        return width;
    }

    private static string GetCellText(ExpandoObject row, string columnName)
    {
        var dictionary = (IDictionary<string, object>)row;
        return dictionary.TryGetValue(columnName, out var value) ? value?.ToString() ?? string.Empty : string.Empty;
    }

    private static string FormatDateInput(DateTime? value) => value?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) ?? string.Empty;

    private static DateTime? ParseDateInput(string? value)
    {
        return DateTime.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out var parsed)
            ? parsed.Date
            : null;
    }

    private static decimal? ParseDecimalInput(string? value)
    {
        if (decimal.TryParse(value, NumberStyles.Number, CultureInfo.CurrentCulture, out var current)) return current;
        if (decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out var invariant)) return invariant;
        return null;
    }

    private static string EscapeCsv(string value)
    {
        value ??= string.Empty;
        return value.Contains(',') || value.Contains('"') || value.Contains('\r') || value.Contains('\n')
            ? $"\"{value.Replace("\"", "\"\"")}\""
            : value;
    }

    private static string? TryExtractInvalidSqlColumnName(Exception exception)
    {
        var message = exception.ToString();

        const string marker = "Invalid column name '";
        var start = message.IndexOf(marker, StringComparison.OrdinalIgnoreCase);

        if (start < 0)
            return null;

        start += marker.Length;

        var end = message.IndexOf("'", start, StringComparison.OrdinalIgnoreCase);

        if (end <= start)
            return null;

        return message[start..end].Trim();
    }

    private static string SanitiseFileName(string fileName)
    {
        var invalid = Path.GetInvalidFileNameChars();
        var builder = new StringBuilder(fileName.Length);
        foreach (var ch in fileName) builder.Append(invalid.Contains(ch) ? '_' : ch);
        return builder.ToString();
    }

    public async Task OnError(Exception error)
    {
        if (string.IsNullOrEmpty(error.Message)) return;

        ErrorMessage = error.Message;
        PageMethod = error.Data.Contains("PageMethod") ? error.Data["PageMethod"]?.ToString() ?? "Not Set" : "Not Set";
        MessageType = error.Data.Contains("MessageType")
            ? (ShowMessageType)(error.Data["MessageType"] ?? ShowMessageType.Information)
            : ShowMessageType.Error;

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
                if (result != null && !string.IsNullOrEmpty(result.UiMessage))
                {
                    _messageDisplay.SetMessage(result.UiMessage, result.MessageType);
                    _messageDisplay.ShowError(true);
                }
            }
            catch
            {
                // Error reporting must never break the grid.
            }
        }

        StateHasChanged();
    }

    public void Dispose()
    {
        CancelQueuedFilterReload();
        GC.SuppressFinalize(this);
    }


    private sealed class MonthlySeriesModel
    {
        public DateTime? StartDateFirstInvoice { get; set; }
        public DateTime? EndDateFinalInvoice { get; set; }
        public decimal? TotalValueNet { get; set; }
        public bool OverwriteExisting { get; set; }
    }

    private sealed class GenerateMonthlySeriesResponse
    {
        public int InsertedCount { get; set; }
        public int MonthsCount { get; set; }
    }

    private sealed class NativeGridState
    {
        public string? Code { get; set; }
        public string? GridCode { get; set; }
        public string? SearchText { get; set; }
        public string? SortColumn { get; set; }
        public bool SortDescending { get; set; }
        public int PageSize { get; set; }
        public List<NativeColumnFilter>? Filters { get; set; }
    }

    private sealed record NativeColumnFilter(string ColumnName, string Value);
}


