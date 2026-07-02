using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.JSInterop;
using System.Dynamic;
using System.Text.Json;

namespace Concursus.PWA.Shared;

public partial class MultiColumnDynamicGridView
{
    private const string DefaultHeaderColour = "#f8f9fa";

    private readonly IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();
    private MessageDisplay _messageDisplay = default!;

    private IEnumerable<ExpandoObject>? CurrentGridItems { get; set; }
    private bool WindowIsVisible { get; set; }
    private string? WindowTitle { get; set; }
    private string modalId = Guid.Empty.ToString();

    [Parameter] public List<string> TopColumnHeaders { get; set; } = new();
    [Parameter] public string? CellColoursJSON { get; set; }
    [Parameter] public EventCallback<string> SendJSONToWidgetCallback { get; set; }
    [Parameter] public EventCallback<string> SendFilterAndSortCallback { get; set; }
    [Parameter] public string? CSSFromDB { get; set; }
    [Parameter] public string? MyWorkFiltersFromDB { get; set; }

    private bool CSSLoadedFromDatabase { get; set; }
    private HashSet<CellColouring> CellColourings { get; set; } = new();
    private string MyWorkGridFilterAsJSON { get; set; } = string.Empty;

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

    private IEnumerable<string> EffectiveTopColumnHeaders
    {
        get
        {
            if (TopColumnHeaders is not null && TopColumnHeaders.Any())
            {
                return TopColumnHeaders;
            }

            return VisibleGridColumns
                .Select(c => string.IsNullOrWhiteSpace(c.TopHeaderCategory) ? " " : c.TopHeaderCategory)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }
    }

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

    public class CellColouring
    {
        public string ClassName { get; set; } = string.Empty;
        public string Colour { get; set; } = DefaultHeaderColour;
    }

    protected override async Task OnParametersSetAsync()
    {
        await base.OnParametersSetAsync();

        LoadHeaderCssFromDatabase();

        if (ViewDefinition is null) return;

        var parameterKey = $"{GridCode}|{ViewDefinition.Code}|{ParentGuid}|{FullGrid}";
        if (!string.Equals(_nativeGridParameterKey, parameterKey, StringComparison.Ordinal))
        {
            _nativeGridParameterKey = parameterKey;
            InitialiseNativeSortFromViewDefinition();
            await RestoreNativeGridStateAsync();
            await ReloadNativeGridAsync(NativePage);
        }
    }

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        await base.OnAfterRenderAsync(firstRender);

        if (CellColourings.Any())
        {
            await ApplyCSSColour();
        }
    }

    private IEnumerable<GridViewColumnDefinition> GetColumnsForTopHeader(string topHeader)
    {
        return VisibleGridColumns.Where(c => string.Equals(NormaliseTopHeader(c.TopHeaderCategory), NormaliseTopHeader(topHeader), StringComparison.OrdinalIgnoreCase))
                                 .OrderBy(c => c.TopHeaderCategoryOrder)
                                 .ThenBy(c => c.ColumnOrder);
    }

    private static string NormaliseTopHeader(string? value) => string.IsNullOrWhiteSpace(value) ? " " : value;

    private static string GetTopHeaderCssClass(string topHeader)
    {
        var result = topHeader == " " ? "empty_topHeader" : topHeader.Replace(" ", "_") + "_topHeader";
        return result.Replace("&", string.Empty);
    }

    private string GetHeaderColour(string className)
    {
        var colouring = CellColourings.FirstOrDefault(x => string.Equals(x.ClassName, className, StringComparison.OrdinalIgnoreCase));
        return string.IsNullOrWhiteSpace(colouring?.Colour) ? DefaultHeaderColour : colouring.Colour;
    }

    private async Task SetHeaderColour(string colour, string className)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(colour)) colour = DefaultHeaderColour;

            var colouring = CellColourings.FirstOrDefault(x => string.Equals(x.ClassName, className, StringComparison.OrdinalIgnoreCase));
            if (string.Equals(colour, DefaultHeaderColour, StringComparison.OrdinalIgnoreCase))
            {
                if (colouring is not null) CellColourings.Remove(colouring);
            }
            else if (colouring is null)
            {
                CellColourings.Add(new CellColouring { ClassName = className, Colour = colour });
            }
            else
            {
                colouring.Colour = colour;
            }

            await SetHeaderColourJS(colour, className);
            await SendJSONToWidgetBoard();
            StateHasChanged();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while setting a My Work header colour.");
            ex.Data.Add("PageMethod", "MultiColumnDynamicGridView/SetHeaderColour()");
            await OnError(ex);
        }
    }

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
            ex.Data.Add("AdditionalInfo", "An error occurred while applying My Work header CSS.");
            ex.Data.Add("PageMethod", "MultiColumnDynamicGridView/SetHeaderColourJS()");
            await OnError(ex);
        }
    }

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
            ex.Data.Add("AdditionalInfo", "An error occurred while applying My Work CSS.");
            ex.Data.Add("PageMethod", "MultiColumnDynamicGridView/ApplyCSSColour()");
            await OnError(ex);
        }
    }

    private void LoadHeaderCssFromDatabase()
    {
        try
        {
            if (CSSLoadedFromDatabase || string.IsNullOrWhiteSpace(CSSFromDB)) return;

            var existingMyWorkStyle = JsonSerializer.Deserialize<List<CellColouring>>(CSSFromDB);
            if (existingMyWorkStyle is not null)
            {
                foreach (var css in existingMyWorkStyle.Where(x => !string.IsNullOrWhiteSpace(x.ClassName)))
                {
                    var existing = CellColourings.FirstOrDefault(x => string.Equals(x.ClassName, css.ClassName, StringComparison.OrdinalIgnoreCase));
                    if (existing is null) CellColourings.Add(css);
                    else existing.Colour = css.Colour;
                }
            }

            CSSLoadedFromDatabase = true;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while loading My Work CSS settings.");
            ex.Data.Add("PageMethod", "MultiColumnDynamicGridView/LoadHeaderCssFromDatabase()");
            _ = OnError(ex);
        }
    }

    public async Task SendJSONToWidgetBoard()
    {
        var cellJson = JsonSerializer.Serialize(CellColourings);
        await SendJSONToWidgetCallback.InvokeAsync(cellJson);
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

    public async Task ReloadNativeGridAsync(int? requestedPage = null)
    {
        NativeIsLoading = true;
        await InvokeAsync(StateHasChanged);

        try
        {
            if (ViewDefinition is null) return;

            await EnsureCorrectParentGuid();

            NativePage = Math.Max(1, requestedPage ?? NativePage);
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

            await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_multiColumnCurrentPageNumber", NativePage);

            var filter = BuildCompositeFilter();
            if (filter is not null)
            {
                request.Filters.Add(filter);
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
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("PageMethod", "MultiColumnDynamicGridView/ReloadNativeGridAsync()");
            await OnError(ex);
            await SendFilterAndSortSettingsToBoard(null);
        }
        finally
        {
            NativeIsLoading = false;
            await InvokeAsync(StateHasChanged);
        }
    }

    private DataCompositeFilter? BuildCompositeFilter()
    {
        var root = new DataCompositeFilter { LogicalOperator = "and" };
        AddCompositeIfNotEmpty(root, BuildNativeColumnFilterComposite());
        AddCompositeIfNotEmpty(root, BuildNativeSearchFilterComposite());
        return HasAnyFilterContent(root) ? root : null;
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

        var savedPageNumber = await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_multiColumnCurrentPageNumber");
        if (!string.IsNullOrWhiteSpace(savedPageNumber) && int.TryParse(savedPageNumber, out var pageNum))
        {
            NativePage = Math.Max(1, pageNum);
        }

        var savedState = !string.IsNullOrWhiteSpace(MyWorkFiltersFromDB)
            ? MyWorkFiltersFromDB
            : await LocalStorageAccessor.GetValueAsync<string>($"{ViewDefinition.Code}_multiColumnNativeGridState");

        if (string.IsNullOrWhiteSpace(savedState)) return;

        try
        {
            var state = JsonSerializer.Deserialize<NativeFilterAndSortSetting>(savedState);
            if (state is null) return;
            if (!string.IsNullOrWhiteSpace(state.code) && !string.Equals(state.code, ViewDefinition.Code, StringComparison.OrdinalIgnoreCase)) return;
            if (!string.IsNullOrWhiteSpace(state.gridCode) && !string.Equals(state.gridCode, GridCode, StringComparison.OrdinalIgnoreCase)) return;

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
            // Ignore invalid legacy state from older widget records. Native state will overwrite it after the next action.
        }
    }

    private async Task PersistNativeGridStateAsync()
    {
        if (ViewDefinition is null) return;

        var state = new NativeFilterAndSortSetting
        {
            code = ViewDefinition.Code,
            gridCode = GridCode,
            filterValues = NativeColumnFilters.Where(f => !string.IsNullOrWhiteSpace(f.Value)).ToDictionary(f => f.Key, f => f.Value, StringComparer.OrdinalIgnoreCase),
            searchText = NativeSearchText,
            sortColumn = NativeSortColumn,
            sortDescending = NativeSortDescending,
            pageNumber = NativePage,
            pageSize = NativePageSize
        };

        MyWorkGridFilterAsJSON = JsonSerializer.Serialize(state, new JsonSerializerOptions { WriteIndented = true });
        await LocalStorageAccessor.SetValueAsync($"{ViewDefinition.Code}_multiColumnNativeGridState", MyWorkGridFilterAsJSON);
        await SendFilterAndSortCallback.InvokeAsync(MyWorkGridFilterAsJSON);
    }

    public async Task SendFilterAndSortSettingsToBoard(NativeFilterAndSortSetting? settings)
    {
        MyWorkGridFilterAsJSON = JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true });
        await SendFilterAndSortCallback.InvokeAsync(MyWorkGridFilterAsJSON);
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
            await PersistNativeGridStateAsync();
            await ReloadNativeGridAsync(1);
        }
    }

    private static string GetColumnWidthStyle(string? width)
    {
        var safeWidth = string.IsNullOrWhiteSpace(width) || width.StartsWith('0') ? "125px" : width.Trim();
        return $"width:{safeWidth};min-width:{safeWidth};";
    }

    private object GetNativeCellValue(ExpandoObject row, string columnName)
    {
        var dictionary = (IDictionary<string, object>)row;
        return dictionary.TryGetValue(columnName, out var value) ? value ?? string.Empty : string.Empty;
    }

    private object FormatGridColumnValue(string columnName, string value)
    {
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

    private async Task GetScrollBarPos()
    {
        try { await JSRuntime.InvokeVoidAsync("GetScrollBarPos"); }
        catch (Exception ex) { Console.WriteLine(ex.Message); }
    }

    private async Task SetScrollBarPos()
    {
        try
        {
            await JSRuntime.InvokeVoidAsync("SetScrollBarPos");
            await Task.Delay(100);
        }
        catch (Exception ex) { Console.WriteLine(ex.Message); }
    }

    private void ScrollToTop()
    {
        _ = JsRuntime.InvokeVoidAsync("window.scrollTo", 0, 0);
    }

    private void OnRowDoubleClickHandler(ExpandoObject item)
    {
        try
        {
            if (ViewDefinition is null || string.IsNullOrWhiteSpace(ViewDefinition.DetailPageUri)) return;
            var row = (IDictionary<string, object>)item;
            if (!row.TryGetValue("Guid", out var guidObj)) return;
            var parentGuid = guidObj?.ToString() ?? Guid.Empty.ToString();
            if (PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(parentGuid) == Guid.Empty) return;

            var isParentDataObjectReferenceDifferent = ParentDataObjectReference.EntityTypeGuid.ToString() != ViewDefinition.EntityTypeGuid;
            var (parentDataObjectReference, serializedParentDataObjectReference) =
                PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, parentGuid, ViewDefinition.EntityTypeGuid);

            if (ViewDefinition.IsDetailWindowed)
            {
                _ = GetScrollBarPos();
                modalId = Guid.NewGuid().ToString();
                _detailPageParameters.Clear();
                _detailPageParameters.Add("EntityTypeGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
                _detailPageParameters.Add("Windowed", true);
                _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseNativeWindow));
                _detailPageParameters.Add("GridUpdated", EventCallback.Factory.Create(this, NativeGridUpdated));
                _detailPageParameters.Add("RecordGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(parentGuid).ToString());
                _detailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
                _detailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                _detailPageParameters.Add("ModalId", modalId);

                modalService.RegisterModal(modalId, parentDataObjectReference);
                WindowTitle = ViewDefinition.Name;
                WindowIsVisible = true;
            }
            else
            {
                var guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(parentGuid).ToString();
                var uri = System.Web.HttpUtility.UrlEncode(NavManager.Uri);
                var url = ViewDefinition.DetailPageUri + "/" + guid + "/" + serializedParentDataObjectReference + "/" + uri;

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
            ex.Data.Add("PageMethod", "MultiColumnDynamicGridView/OnRowDoubleClickHandler()");
            _ = OnError(ex);
        }
    }

    private async Task CloseNativeWindow()
    {
        WindowIsVisible = false;
        if (!string.IsNullOrWhiteSpace(modalId) && modalId != Guid.Empty.ToString())
        {
            modalService.UnregisterModal(modalId);
            modalId = Guid.Empty.ToString();
        }
        _detailPageParameters.Clear();
        await SetScrollBarPos();
        StateHasChanged();
    }

    private async Task NativeGridUpdated()
    {
        await ReloadNativeGridAsync(NativePage);
        StateHasChanged();
    }

    public async Task RefreshGrid(bool resetToFirstPage = false)
    {
        await ReloadNativeGridAsync(resetToFirstPage ? 1 : NativePage);
    }

    public RenderFragment<object> GetColumnTemplate(string propName)
    {
        return context => builder =>
        {
            if (context is not ExpandoObject expandoObject) return;
            var dictionary = (IDictionary<string, object>)expandoObject;
            if (dictionary.TryGetValue(propName, out var propValue))
            {
                if (propValue?.ToString() == "#808080") propValue = " ";
                builder.AddContent(0, propValue);
            }
        };
    }

    private string EncodeClassNameAsBase64(GridViewColumnDefinition gvcd, object context)
    {
        try
        {
            if (context is ExpandoObject expandoObject)
            {
                var dictionary = (IDictionary<string, object>)expandoObject;
                if (dictionary.TryGetValue("Guid", out var guid))
                {
                    return Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(gvcd.Id + "_" + gvcd.Name + "_" + guid));
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while generating the My Work cell CSS class.");
            ex.Data.Add("PageMethod", "MultiColumnDynamicGridView/EncodeClassNameAsBase64()");
            _ = OnError(ex);
        }

        return Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(gvcd.Guid + "_" + gvcd.Name));
    }

    public sealed class NativeFilterAndSortSetting
    {
        public string code { get; set; } = string.Empty;
        public Dictionary<string, string> filterValues { get; set; } = new(StringComparer.OrdinalIgnoreCase);
        public string gridCode { get; set; } = string.Empty;
        public string searchText { get; set; } = string.Empty;
        public string sortColumn { get; set; } = string.Empty;
        public bool sortDescending { get; set; }
        public int pageNumber { get; set; }
        public int pageSize { get; set; }
    }
}
