using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using Concursus.PWA.Services;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using System.Collections;
using System.Dynamic;
using static Concursus.API.Core.Core;
using static Concursus.PWA.Shared.MessageDisplay;

namespace Concursus.PWA.Shared;

public partial class DynamicTreeListGridView
{
    protected FormHelper? formHelper;

    private readonly IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();
    private readonly Dictionary<string, string> _filters = new(StringComparer.OrdinalIgnoreCase);
    private readonly HashSet<string> _expandedRows = new(StringComparer.OrdinalIgnoreCase);

    private Type? _detailPageType;
    private MessageDisplay _messageDisplay = new();
    private GridViewDefinition? _viewDefinition;
    private List<ExpandoObject> gridData = new();
    private List<ExpandoObject> groupedData = new();
    private string modalId = Guid.Empty.ToString();
    private string currentGridCode = "";
    private bool isLoading;
    private bool WindowIsVisible;
    private string? WindowTitle;
    private string FirstOrderBy { get; set; } = "";
    private string SecondOrderBy { get; set; } = "";
    private string ThirdOrderBy { get; set; } = "";
    private string GroupBy { get; set; } = "";
    private string[] GroupByValues { get; set; } = Array.Empty<string>();
    private string OrderBy { get; set; } = "";
    private string[] OrderByValues { get; set; } = Array.Empty<string>();
    private ElementReference _scrollContainer;

    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = "";
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();

    [Parameter]
    public GridViewDefinition? ViewDefinition
    {
        get => _viewDefinition;
        set => _viewDefinition = value;
    }

    protected string ErrorMessage { get; set; } = "";
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";

    private List<GridViewColumnDefinition> VisibleColumns =>
        ViewDefinition?.Columns
            .Where(x => !x.IsHidden)
            .OrderBy(x => x.ColumnOrder)
            .ToList() ?? new List<GridViewColumnDefinition>();

    private string FirstVisibleColumnName =>
        VisibleColumns.FirstOrDefault()?.Name ?? string.Empty;

    private List<ExpandoObject> FilteredRows =>
        groupedData
            .Where(RowMatchesFilters)
            .ToList();

    private List<ExpandoObject> VisibleTreeRows =>
        FilteredRows
            .Where(IsVisibleByExpansion)
            .ToList();

    protected override async Task OnInitializedAsync()
    {
        await InitialiseAndReadAsync();
    }

    protected override async Task OnParametersSetAsync()
    {
        if (ViewDefinition is not null && currentGridCode != ViewDefinition.Code)
        {
            await InitialiseAndReadAsync();
        }
    }

    private async Task InitialiseAndReadAsync()
    {
        if (ViewDefinition is null)
        {
            return;
        }

        FirstOrderBy = ViewDefinition.TreeListFirstOrderBy ?? string.Empty;
        SecondOrderBy = ViewDefinition.TreeListSecondOrderBy ?? string.Empty;
        ThirdOrderBy = ViewDefinition.TreeListThirdOrderBy ?? string.Empty;

        GroupBy = ViewDefinition.TreeListGroupBy ?? string.Empty;
        GetGroupBy();

        OrderBy = ViewDefinition.TreeListOrderBy ?? string.Empty;
        GetOrderBy();

        await ReadItems();
    }

    public void AddProperty(ExpandoObject expando, string propertyName, object? propertyValue)
    {
        try
        {
            var expandoDict = (IDictionary<string, object?>)expando;

            if (expandoDict.ContainsKey(propertyName))
            {
                expandoDict[propertyName] = propertyValue ?? string.Empty;
            }
            else
            {
                expandoDict.Add(propertyName, propertyValue ?? string.Empty);
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to add a property to the ExpandoObject.");
            ex.Data.Add("PageMethod", "DynamicTreeListGridView/AddProperty()");
            _ = OnError(ex);
        }
    }

    public async Task OnError(Exception error)
    {
        if (string.IsNullOrEmpty(error.Message))
        {
            return;
        }

        ErrorMessage = error.Message;
        PageMethod = error.Data.Contains("PageMethod")
            ? error.Data["PageMethod"]?.ToString() ?? "Not Set"
            : "Not Set";

        MessageType = error.Data.Contains("MessageType")
            ? (ShowMessageType)(error.Data["MessageType"] ?? ShowMessageType.Information)
            : ShowMessageType.Error;

        var exceptionData = error.Data.Count > 0
            ? error.Data.Cast<DictionaryEntry>().ToDictionary(
                de => de.Key?.ToString() ?? "UnknownKey",
                de => de.Value!)
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
                    Data = error.Data.Cast<DictionaryEntry>()
                        .ToDictionary(
                            de => de.Key?.ToString() ?? "UnknownKey",
                            de => de.Value?.ToString() ?? "null")
                };

                var description = InteractionTracker.GetReplicationStepsFormatted(InteractionTracker);
                error.Data["UserInteractionLog"] = description;

                //var result = await AiErrorReporter.ReportAsync(error, context);

                //if (result != null && !string.IsNullOrEmpty(result.UiMessage))
                //{
                //    _messageDisplay.SetMessage(result.UiMessage, result.MessageType);
                //    _messageDisplay.ShowError(true);
                //}
            }
            catch
            {
                // Never break rendering because optional AI error reporting failed.
            }
        }

        StateHasChanged();
    }

    public async Task RefreshMe()
    {
        try
        {
            await ReadItems();
            await OnActionCompleted.InvokeAsync();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to refresh the tree grid.");
            ex.Data.Add("PageMethod", "DynamicTreeListGridView/RefreshMe()");
            await OnError(ex);
        }
    }

    public void GetOrderBy()
    {
        OrderByValues = string.IsNullOrWhiteSpace(OrderBy)
            ? Array.Empty<string>()
            : OrderBy.Split(",", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    }

    public void GetGroupBy()
    {
        GroupByValues = string.IsNullOrWhiteSpace(GroupBy)
            ? Array.Empty<string>()
            : GroupBy.Split(",", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    }

    protected async Task CloseWindow()
    {
        try
        {
            if (_detailPageParameters.TryGetValue("ModalId", out var value) && value is string detailModalId)
            {
                modalService.UnregisterModal(detailModalId);
            }

            WindowIsVisible = false;
            await RefreshMe();

            StateHasChanged();
            await OnActionCompleted.InvokeAsync();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to close the window.");
            ex.Data.Add("PageMethod", "DynamicTreeListGridView/CloseWindow()");
            await OnError(ex);
        }
    }

    protected async Task ReadItems()
    {
        try
        {
            if (ViewDefinition is null)
            {
                return;
            }

            isLoading = true;
            StateHasChanged();

            if (currentGridCode != ViewDefinition.Code)
            {
                _filters.Clear();
                _expandedRows.Clear();
            }

            var request = new GridDataListRequest
            {
                GridCode = GridCode,
                GridViewCode = ViewDefinition.Code,
                Page = 1,
                PageSize = 10000,
                ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString()
            };

            currentGridCode = ViewDefinition.Code;

            if (request.ParentGuid == Guid.Empty.ToString() && !FullGrid)
            {
                gridData.Clear();
                groupedData.Clear();
                return;
            }

            var reply = await coreClient.GridDataListAsync(request);

            gridData = new List<ExpandoObject>();

            foreach (var sourceRow in reply.DataTable)
            {
                dynamic dataObj = new ExpandoObject();

                foreach (var column in sourceRow.Columns)
                {
                    var value = column.Value;
                    var name = column.Name;

                    if (DateTime.TryParse(value, out var dateTimeValue))
                    {
                        value = UiFormattingHelper.FormatDynamicDate(name, dateTimeValue);
                    }

                    AddProperty(dataObj, name, value);
                }

                gridData.Add(dataObj);
            }

            BuildGroupedData(reply);
            //ApplyConfiguredOrder();
            ExpandTopLevelRows();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to read items for the tree grid.");
            ex.Data.Add("PageMethod", "DynamicTreeListGridView/ReadItems()");
            await OnError(ex);
        }
        finally
        {
            isLoading = false;
            StateHasChanged();
        }
    }
    private string GetGroupDisplayText(ExpandoObject row)
    {
        if (GetBool(row, "ApplyCSS"))
        {
            return GetValue(row, FirstOrderBy, "Group");
        }

        if (GetBool(row, "SecondLevelCSS"))
        {
            return GetValue(row, SecondOrderBy, "Group");
        }

        if (GetBool(row, "ThirdLevelCSS"))
        {
            return GetValue(row, ThirdOrderBy, "Group");
        }

        return "Group";
    }
    private void BuildGroupedData(GridDataListReply reply)
    {
        groupedData = new List<ExpandoObject>();

        if (!gridData.Any())
        {
            return;
        }

        if (string.IsNullOrWhiteSpace(FirstOrderBy))
        {
            foreach (var row in gridData)
            {
                EnsureTreeIdentity(row, null);
                groupedData.Add(row);
            }

            return;
        }

        var firstGroups = gridData.GroupBy(row => GetValue(row, FirstOrderBy, "Unknown"));

        foreach (var firstGroup in firstGroups)
        {
            var firstParent = CreateGroupRow(FirstOrderBy, firstGroup.Key, null, "ApplyCSS", reply);
            var firstParentId = GetObjectValue(firstParent, "TreeListID");
            groupedData.Add(firstParent);

            if (!string.IsNullOrWhiteSpace(SecondOrderBy))
            {
                var secondGroups = firstGroup.GroupBy(row => GetValue(row, SecondOrderBy, "Unknown"));

                foreach (var secondGroup in secondGroups)
                {
                    var secondParent = CreateGroupRow(SecondOrderBy, secondGroup.Key, firstParentId, "SecondLevelCSS", reply);
                    var secondParentId = GetObjectValue(secondParent, "TreeListID");
                    groupedData.Add(secondParent);

                    if (!string.IsNullOrWhiteSpace(ThirdOrderBy))
                    {
                        var thirdGroups = secondGroup.GroupBy(row => GetValue(row, ThirdOrderBy, "Unknown"));

                        foreach (var thirdGroup in thirdGroups)
                        {
                            var thirdParent = CreateGroupRow(ThirdOrderBy, thirdGroup.Key, secondParentId, "ThirdLevelCSS", reply);
                            var thirdParentId = GetObjectValue(thirdParent, "TreeListID");
                            groupedData.Add(thirdParent);

                            foreach (var leaf in thirdGroup)
                            {
                                PrepareLeafRow(leaf, thirdParentId, ThirdOrderBy);
                                groupedData.Add(leaf);
                            }
                        }
                    }
                    else
                    {
                        foreach (var leaf in secondGroup)
                        {
                            PrepareLeafRow(leaf, secondParentId, SecondOrderBy);
                            groupedData.Add(leaf);
                        }
                    }
                }
            }
            else
            {
                foreach (var leaf in firstGroup)
                {
                    PrepareLeafRow(leaf, firstParentId, string.Empty);
                    groupedData.Add(leaf);
                }
            }
        }
    }

    private ExpandoObject CreateGroupRow(
        string groupColumnName,
        object? groupValue,
        object? parentId,
        string cssFlag,
        GridDataListReply reply)
    {
        dynamic groupRow = new ExpandoObject();
        var dict = (IDictionary<string, object?>)groupRow;

        dict["TreeListID"] = Guid.NewGuid();
        dict["ParentID"] = parentId;
        dict["ApplyCSS"] = cssFlag == "ApplyCSS";
        dict["SecondLevelCSS"] = cssFlag == "SecondLevelCSS";
        dict["ThirdLevelCSS"] = cssFlag == "ThirdLevelCSS";
        dict[groupColumnName] = groupValue ?? "Unknown";

        foreach (var column in reply.DataTable.FirstOrDefault()?.Columns ?? Enumerable.Empty<GridDataColumn>())
        {
            if (column.Name == "TreeListID" || column.Name == groupColumnName)
            {
                continue;
            }

            if (!dict.ContainsKey(column.Name))
            {
                dict[column.Name] = string.Empty;
            }
        }

        return groupRow;
    }

    private void PrepareLeafRow(ExpandoObject row, object? parentId, string clearedGroupColumn)
    {
        var dict = (IDictionary<string, object?>)row;

        dict["ParentID"] = parentId;

        if (!string.IsNullOrWhiteSpace(clearedGroupColumn))
        {
            dict[clearedGroupColumn] = string.Empty;
        }

        if (!dict.ContainsKey("TreeListID"))
        {
            dict["TreeListID"] = Guid.NewGuid();
        }
    }

    private void EnsureTreeIdentity(ExpandoObject row, object? parentId)
    {
        var dict = (IDictionary<string, object?>)row;

        if (!dict.ContainsKey("TreeListID"))
        {
            dict["TreeListID"] = Guid.NewGuid();
        }

        dict["ParentID"] = parentId;
    }

    private void ApplyConfiguredOrder()
    {
        if (!OrderByValues.Any() || !groupedData.Any())
        {
            return;
        }

        object SafeGetValue(ExpandoObject obj, string key)
        {
            var dict = (IDictionary<string, object?>)obj;
            return dict.TryGetValue(key, out var value) ? value ?? string.Empty : string.Empty;
        }

        IOrderedEnumerable<ExpandoObject>? ordered = null;

        for (var i = 0; i < OrderByValues.Length; i++)
        {
            var key = OrderByValues[i];

            ordered = i == 0
                ? groupedData.OrderBy(x => SafeGetValue(x, key))
                : ordered!.ThenBy(x => SafeGetValue(x, key));
        }

        groupedData = ordered?.ToList() ?? groupedData;
    }

    private void ExpandTopLevelRows()
    {
        foreach (var row in groupedData.Where(IsGroupRow))
        {
            var parent = GetObjectValue(row, "ParentID");

            if (parent is null || string.IsNullOrWhiteSpace(parent.ToString()))
            {
                _expandedRows.Add(GetRowId(row));
            }
        }
    }

    private async Task ExportToExcelAsync()
    {
        try
        {
            if (ViewDefinition is null)
            {
                return;
            }

            var columns = VisibleColumns
                .Select(column => new
                {
                    key = column.Name,
                    title = string.IsNullOrWhiteSpace(column.Title) ? column.Name : column.Title
                })
                .ToList();

            var rows = FilteredRows
                .Select(row =>
                {
                    var isGroup = IsGroupRow(row);
                    var level = GetLevel(row);

                    var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

                    foreach (var column in VisibleColumns)
                    {
                        values[column.Name] = GetValue(row, column.Name);
                    }

                    return new
                    {
                        isGroup,
                        level,
                        groupText = isGroup ? GetGroupDisplayText(row) : string.Empty,
                        values
                    };
                })
                .ToList();

            var fileName = $"{SanitiseExcelFileName(ViewDefinition.Name)}_{DateTime.Now:yyyyMMdd_HHmmss}.xls";

            await JsRuntime.InvokeVoidAsync(
                "cymBuildV2.exportTreeGridToExcel",
                fileName,
                ViewDefinition.Name ?? "CymBuild Export",
                columns,
                rows);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while exporting the tree grid to Excel.");
            ex.Data.Add("PageMethod", "DynamicTreeListGridView/ExportToExcelAsync()");
            await OnError(ex);
        }
    }

    private static string SanitiseExcelFileName(string? value)
    {
        var name = string.IsNullOrWhiteSpace(value) ? "CymBuild_Export" : value;

        foreach (var invalidChar in Path.GetInvalidFileNameChars())
        {
            name = name.Replace(invalidChar, '_');
        }

        return name.Replace(' ', '_');
    }
    private async Task ScrollToTopAsync()
    {
        try
        {
            await JsRuntime.InvokeVoidAsync(
                "cymBuildV2.scrollElementToTop",
                _scrollContainer);
        }
        catch (JSException)
        {
            await JsRuntime.InvokeVoidAsync("window.scrollTo", 0, 0);
        }
    }

    private void OnRowDoubleClickHandler(ExpandoObject row)
    {
        try
        {
            if (ViewDefinition is null || string.IsNullOrWhiteSpace(ViewDefinition.DetailPageUri))
            {
                return;
            }

            if (IsGroupRow(row))
            {
                ToggleExpanded(GetRowId(row));
                return;
            }

            var recordGuid = GetValue(row, "Guid");

            if (string.IsNullOrWhiteSpace(recordGuid) || recordGuid == Guid.Empty.ToString())
            {
                return;
            }

            var parentGuid = recordGuid;
            var isParentDataObjectReferenceDifferent =
                ParentDataObjectReference.EntityTypeGuid.ToString() != ViewDefinition.EntityTypeGuid;

            var referenceResult = PWAFunctions.ProcessDataObjectReference(
                modalService,
                ParentDataObjectReference,
                parentGuid,
                ViewDefinition.EntityTypeGuid);

            var parentDataObjectReference = referenceResult.Item1;
            var serializedParentDataObjectReference = referenceResult.Item2;

            if (ViewDefinition.IsDetailWindowed)
            {
                modalId = Guid.NewGuid().ToString();

                _detailPageParameters.Clear();
                _detailPageParameters.Add("EntityTypeGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
                _detailPageParameters.Add("Windowed", true);
                _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
                _detailPageParameters.Add("GridUpdated", EventCallback.Factory.Create(this, RefreshMe));
                _detailPageParameters.Add("RecordGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(recordGuid).ToString());
                _detailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
                _detailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                _detailPageParameters.Add("ModalId", modalId);
                _detailPageParameters.Add("IsMainRecordContext", false);

                modalService.RegisterModal(modalId, parentDataObjectReference);

                _detailPageType = Type.GetType($"Concursus.PWA.Pages.{ViewDefinition.DetailPageUri}");
                WindowTitle = ViewDefinition.Name;
                WindowIsVisible = true;

                InteractionTracker.Log(
                    NavManager.Uri,
                    $"User opened row in tree grid - '{ViewDefinition.Name}' windowed page '{ViewDefinition.DetailPageUri}'.");

                StateHasChanged();
                return;
            }

            var guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(recordGuid).ToString();

            if (guid == Guid.Empty.ToString())
            {
                return;
            }

            var baseUri = System.Web.HttpUtility.UrlEncode(NavManager.BaseUri);
            var url = $"{ViewDefinition.DetailPageUri}/{guid}/{serializedParentDataObjectReference}/{baseUri}";

            if (ViewDefinition.DetailPageUri == "DynamicEdit")
            {
                NavManager.NavigateTo(
                    ViewDefinition.DetailPageUri +
                    "/" +
                    PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid) +
                    "/" +
                    parentDataObjectReference.DataObjectGuid +
                    "/" +
                    serializedParentDataObjectReference +
                    "/" +
                    System.Web.HttpUtility.UrlEncode(NavManager.Uri));
            }
            else if (isParentDataObjectReferenceDifferent)
            {
                var navigateToDetailPage = "/" + ViewDefinition.DetailPageUri + "/";
                var currentUri = NavManager.Uri;

                NavManager.NavigateTo(url, currentUri.Contains(navigateToDetailPage));
            }
            else
            {
                NavManager.NavigateTo(url, true);
            }

            InteractionTracker.Log(
                NavManager.Uri,
                $"User opened row in tree grid - '{ViewDefinition.Name}' page '{ViewDefinition.DetailPageUri}'.");
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to open the selected tree grid row.");
            ex.Data.Add("PageMethod", "DynamicTreeListGridView/OnRowDoubleClickHandler()");
            _ = OnError(ex);
        }
    }

    private string GetFilterValue(string columnName)
    {
        return _filters.TryGetValue(columnName, out var value) ? value : string.Empty;
    }

    private void SetFilterValue(string columnName, string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            _filters.Remove(columnName);
        }
        else
        {
            _filters[columnName] = value.Trim();
        }
    }

    private bool RowMatchesFilters(ExpandoObject row)
    {
        if (!_filters.Any())
        {
            return true;
        }

        foreach (var filter in _filters)
        {
            var value = GetValue(row, filter.Key);

            if (!value.Contains(filter.Value, StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }
        }

        return true;
    }

    private bool IsVisibleByExpansion(ExpandoObject row)
    {
        var parentId = GetObjectValue(row, "ParentID");

        if (parentId is null || string.IsNullOrWhiteSpace(parentId.ToString()))
        {
            return true;
        }

        return IsAncestorChainExpanded(row);
    }

    private bool IsAncestorChainExpanded(ExpandoObject row)
    {
        var parentId = GetObjectValue(row, "ParentID");

        while (parentId is not null && !string.IsNullOrWhiteSpace(parentId.ToString()))
        {
            var parent = groupedData.FirstOrDefault(x => GetRowId(x) == parentId.ToString());

            if (parent is null)
            {
                return false;
            }

            if (!IsExpanded(GetRowId(parent)))
            {
                return false;
            }

            parentId = GetObjectValue(parent, "ParentID");
        }

        return true;
    }

    private int GetLevel(ExpandoObject row)
    {
        var level = 0;
        var parentId = GetObjectValue(row, "ParentID");

        while (parentId is not null && !string.IsNullOrWhiteSpace(parentId.ToString()))
        {
            var parent = groupedData.FirstOrDefault(x => GetRowId(x) == parentId.ToString());

            if (parent is null)
            {
                break;
            }

            level++;
            parentId = GetObjectValue(parent, "ParentID");
        }

        return level;
    }

    private bool HasChildren(string rowId)
    {
        return groupedData.Any(x =>
        {
            var parentId = GetObjectValue(x, "ParentID");
            return string.Equals(parentId?.ToString(), rowId, StringComparison.OrdinalIgnoreCase);
        });
    }

    private bool IsExpanded(string rowId)
    {
        return _expandedRows.Contains(rowId);
    }

    private void ToggleExpanded(string rowId)
    {
        if (!_expandedRows.Add(rowId))
        {
            _expandedRows.Remove(rowId);
        }
    }

    private string GetRowCss(ExpandoObject row)
    {
        if (GetBool(row, "ApplyCSS"))
        {
            return "cb-tree-grid-group cb-tree-grid-group-primary";
        }

        if (GetBool(row, "SecondLevelCSS"))
        {
            return "cb-tree-grid-group cb-tree-grid-group-secondary";
        }

        if (GetBool(row, "ThirdLevelCSS"))
        {
            return "cb-tree-grid-group cb-tree-grid-group-tertiary";
        }

        return "cb-tree-grid-leaf cb-v2-clickable-row";
    }

    private bool IsGroupRow(ExpandoObject row)
    {
        return GetBool(row, "ApplyCSS") || GetBool(row, "SecondLevelCSS") || GetBool(row, "ThirdLevelCSS");
    }

    private string GetRowId(ExpandoObject row)
    {
        return GetObjectValue(row, "TreeListID")?.ToString() ?? string.Empty;
    }

    private bool GetBool(ExpandoObject row, string key)
    {
        var value = GetObjectValue(row, key);

        return value switch
        {
            bool b => b,
            string s when bool.TryParse(s, out var parsed) => parsed,
            _ => false
        };
    }

    private string GetValue(ExpandoObject row, string key, string fallback = "")
    {
        var value = GetObjectValue(row, key);
        return value?.ToString() ?? fallback;
    }

    private object? GetObjectValue(ExpandoObject row, string key)
    {
        var dict = (IDictionary<string, object?>)row;
        return dict.TryGetValue(key, out var value) ? value : null;
    }
}