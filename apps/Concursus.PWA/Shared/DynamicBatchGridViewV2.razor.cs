using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using System.Collections;
using System.Dynamic;
using static Concursus.PWA.Shared.DynamicGrid;
using static Concursus.PWA.Shared.MessageDisplay;

namespace Concursus.PWA.Shared;

public partial class DynamicBatchGridViewV2 : ComponentBase
{
    #region Parameters

    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = "";
    [Parameter] public bool IsBulkProcessing { get; set; } = false;
    [Parameter] public IEnumerable<ExpandoObject> Items { get; set; } = new List<ExpandoObject>();
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    [Parameter] public EventCallback<IEnumerable<ExpandoObject>> OnSelectedItemsChanged { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public DynamicGrid.DrawerItem SelectedItem { get; set; } = new();
    [Parameter] public EventCallback<DrawerItem> SelectedItemChanged { get; set; }

    [Parameter]
    public GridViewDefinition? ViewDefinition { get; set; }

    #endregion

    #region Protected

    protected string ErrorMessage { get; set; } = "";
    protected ShowMessageType MessageType { get; set; } = ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";
    protected MessageDisplay _messageDisplay = new();

    #endregion

    #region Private state

    private List<ExpandoObject> AllRows { get; set; } = new();
    private List<ExpandoObject> FilteredRows { get; set; } = new();
    private List<ExpandoObject> Rows { get; set; } = new();
    private string ActiveStatusFilter { get; set; } = "";
    private int TotalCount => AllRows.Count;

    private int SucceededCount => CountByStatus("Succeeded");

    private int FailedRetryableCount => CountByStatus("FailedRetryable");

    private int FailedNonRetryableCount => CountByStatus("FailedNonRetryable");

    private int InProgressCount => CountByStatus("InProgress");

    private int PendingCount => CountByStatus("Pending");
    private HashSet<Guid> SelectedRowGuids { get; set; } = new();

    private bool IsLoading { get; set; }
    private bool IsRequeueingSageSubmission { get; set; }

    private int CurrentPage { get; set; } = 1;
    private int PageSize { get; set; } = 25;
    private int TotalRows { get; set; }

    private string SearchText { get; set; } = "";
    private string CurrentSortColumn { get; set; } = "";
    private bool IsSortDescending { get; set; }

    private bool IsSageSubmissionMonitorView =>
        string.Equals(ViewDefinition?.Code, "ALLSAGESUBMON", StringComparison.OrdinalIgnoreCase);

    private bool CanRequeueSelectedSageSubmissions =>
        !IsBulkProcessing
        && !IsRequeueingSageSubmission
        && IsSageSubmissionMonitorView
        && GetSelectedTransactionGuids().Count > 0;

    private int TotalPages => Math.Max(1, (int)Math.Ceiling((double)Math.Max(TotalRows, 1) / PageSize));
    private int PageStartRow => TotalRows == 0 ? 0 : ((CurrentPage - 1) * PageSize) + 1;
    private int PageEndRow => Math.Min(CurrentPage * PageSize, TotalRows);

    private List<GridViewColumnDefinition> VisibleColumns =>
        ViewDefinition?.Columns?
            .Where(c => c.IsHidden != true
                        && !string.Equals(c.Name, "Guid", StringComparison.OrdinalIgnoreCase)
                        && !string.Equals(c.Name, "RowStatus", StringComparison.OrdinalIgnoreCase))
            .OrderBy(c => c.ColumnOrder)
            .ToList()
        ?? new List<GridViewColumnDefinition>();

    private bool IsCurrentPageFullySelected =>
        Rows.Count > 0
        && Rows.Select(r => GetRowGuid((IDictionary<string, object>)r))
               .Where(g => g != Guid.Empty)
               .All(g => SelectedRowGuids.Contains(g));

    #endregion

    #region Lifecycle

    protected override async Task OnInitializedAsync()
    {
        await base.OnInitializedAsync();
        await LoadDataAsync();
    }

    protected override async Task OnParametersSetAsync()
    {
        await base.OnParametersSetAsync();

        if (ViewDefinition is not null && string.IsNullOrWhiteSpace(CurrentSortColumn))
        {
            CurrentSortColumn = ViewDefinition.DefaultSortColumnName ?? "";
            IsSortDescending = ViewDefinition.IsDefaultSortDescending;
        }
    }

    #endregion

    #region Data loading

    private async Task LoadDataAsync()
    {
        try
        {
            IsLoading = true;
            StateHasChanged();

            if (Items != null && Items.Any())
            {
                AllRows = Items.ToList();
                ApplyClientSideView();
                return;
            }

            if (ViewDefinition is null)
                return;

            var request = new GridDataListRequest
            {
                GridCode = GridCode,
                GridViewCode = ViewDefinition.Code,
                Page = 1,
                PageSize = IsSageSubmissionMonitorView ? 500 : 100,
                ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString()
            };

            var reply = await coreClient.GridDataListAsync(request);

            AllRows = new List<ExpandoObject>();

            foreach (var row in reply.DataTable)
            {
                IDictionary<string, object> expando = new ExpandoObject();

                foreach (var column in row.Columns)
                {
                    expando[column.Name] = column.Value;
                }

                AllRows.Add((ExpandoObject)expando);
            }

            ApplyClientSideView();
        }
        catch (Exception ex)
        {
            ex.Data["PageMethod"] = "DynamicBatchGridViewV2/LoadDataAsync()";
            ex.Data["MessageType"] = ShowMessageType.Error;
            await OnError(ex);
        }
        finally
        {
            IsLoading = false;
            StateHasChanged();
        }
    }

    private void ApplyClientSideView()
    {
        IEnumerable<ExpandoObject> working = AllRows;

        working = ApplyStatusFilter(working);
        working = ApplySearchFilter(working);
        working = ApplySorting(working);

        FilteredRows = working.ToList();
        TotalRows = FilteredRows.Count;

        if (CurrentPage > TotalPages)
            CurrentPage = TotalPages;

        if (CurrentPage < 1)
            CurrentPage = 1;

        Rows = FilteredRows
            .Skip((CurrentPage - 1) * PageSize)
            .Take(PageSize)
            .ToList();
    }

    private IEnumerable<ExpandoObject> ApplyStatusFilter(IEnumerable<ExpandoObject> source)
    {
        if (string.IsNullOrWhiteSpace(ActiveStatusFilter))
            return source;

        return source.Where(row =>
        {
            var dict = (IDictionary<string, object>)row;
            return string.Equals(GetStatusText(dict), ActiveStatusFilter, StringComparison.OrdinalIgnoreCase);
        });
    }

    private IEnumerable<ExpandoObject> ApplySearchFilter(IEnumerable<ExpandoObject> source)
    {
        if (string.IsNullOrWhiteSpace(SearchText))
            return source;

        var term = SearchText.Trim();

        return source.Where(row =>
        {
            var dict = (IDictionary<string, object>)row;

            foreach (var column in VisibleColumns)
            {
                if (!dict.TryGetValue(column.Name, out var value) || value is null)
                    continue;

                if (value.ToString()?.Contains(term, StringComparison.OrdinalIgnoreCase) == true)
                    return true;
            }

            return false;
        });
    }

    private IEnumerable<ExpandoObject> ApplySorting(IEnumerable<ExpandoObject> source)
    {
        if (string.IsNullOrWhiteSpace(CurrentSortColumn))
            return source;

        Func<ExpandoObject, string> keySelector = row =>
        {
            var dict = (IDictionary<string, object>)row;

            if (!dict.TryGetValue(CurrentSortColumn, out var value) || value is null)
                return string.Empty;

            return value.ToString() ?? string.Empty;
        };

        return IsSortDescending
            ? source.OrderByDescending(keySelector, StringComparer.OrdinalIgnoreCase)
            : source.OrderBy(keySelector, StringComparer.OrdinalIgnoreCase);
    }

    #endregion

    #region Selection

    private Guid GetRowGuid(IDictionary<string, object> row)
    {
        if (row.TryGetValue("Guid", out var value) &&
            value is not null &&
            Guid.TryParse(value.ToString(), out var guid))
        {
            return guid;
        }

        return Guid.Empty;
    }

    private void ToggleRowSelection(IDictionary<string, object> row, object? isChecked)
    {
        var rowGuid = GetRowGuid(row);
        if (rowGuid == Guid.Empty)
            return;

        var selected = isChecked is bool b && b;

        if (selected)
            SelectedRowGuids.Add(rowGuid);
        else
            SelectedRowGuids.Remove(rowGuid);

        _ = RaiseSelectedItemsChangedAsync();
        StateHasChanged();
    }

    private void ToggleSelectAllCurrentPage(ChangeEventArgs args)
    {
        var selectAll = args.Value is bool b && b;

        foreach (var row in Rows)
        {
            var guid = GetRowGuid((IDictionary<string, object>)row);
            if (guid == Guid.Empty)
                continue;

            if (selectAll)
                SelectedRowGuids.Add(guid);
            else
                SelectedRowGuids.Remove(guid);
        }

        _ = RaiseSelectedItemsChangedAsync();
        StateHasChanged();
    }

    private async Task RaiseSelectedItemsChangedAsync()
    {
        var selected = FilteredRows
            .Where(r =>
            {
                var guid = GetRowGuid((IDictionary<string, object>)r);
                return guid != Guid.Empty && SelectedRowGuids.Contains(guid);
            })
            .ToList();

        if (OnSelectedItemsChanged.HasDelegate)
            await OnSelectedItemsChanged.InvokeAsync(selected);
    }

    #endregion

    #region Sorting / paging / search

    private async Task ToggleSortAsync(string columnName)
    {
        if (string.Equals(CurrentSortColumn, columnName, StringComparison.OrdinalIgnoreCase))
            IsSortDescending = !IsSortDescending;
        else
        {
            CurrentSortColumn = columnName;
            IsSortDescending = false;
        }

        CurrentPage = 1;
        ApplyClientSideView();
        await InvokeAsync(StateHasChanged);
    }

    private async Task PreviousPageAsync()
    {
        if (CurrentPage <= 1)
            return;

        CurrentPage--;
        ApplyClientSideView();
        await InvokeAsync(StateHasChanged);
    }

    private async Task NextPageAsync()
    {
        if (CurrentPage >= TotalPages)
            return;

        CurrentPage++;
        ApplyClientSideView();
        await InvokeAsync(StateHasChanged);
    }

    private async Task ApplySearchAsync()
    {
        CurrentPage = 1;
        ApplyClientSideView();
        await InvokeAsync(StateHasChanged);
    }

    private async Task ClearSearchAsync()
    {
        SearchText = "";
        CurrentPage = 1;
        ApplyClientSideView();
        await InvokeAsync(StateHasChanged);
    }

    #endregion

    #region Sage requeue

    private List<Guid> GetSelectedTransactionGuids()
    {
        var result = new List<Guid>();

        foreach (var row in FilteredRows)
        {
            var dict = (IDictionary<string, object>)row;
            var guid = GetRowGuid(dict);

            if (guid == Guid.Empty || !SelectedRowGuids.Contains(guid))
                continue;

            if (dict.TryGetValue("CanRequeue", out var canRequeueObj)
                && bool.TryParse(canRequeueObj?.ToString(), out var canRequeue)
                && !canRequeue)
            {
                continue;
            }

            if (dict.TryGetValue("TransactionGuid", out var txObj)
                && Guid.TryParse(txObj?.ToString(), out var txGuid)
                && txGuid != Guid.Empty)
            {
                if (!result.Contains(txGuid))
                    result.Add(txGuid);
            }
        }

        return result;
    }

    private async Task RequeueSelectedSageSubmissionsAsync()
    {
        if (!CanRequeueSelectedSageSubmissions)
            return;

        var transactionGuids = GetSelectedTransactionGuids();
        if (transactionGuids.Count == 0)
            return;

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

            SelectedRowGuids.Clear();

            await LoadDataAsync();

            if (OnActionCompleted.HasDelegate)
                await OnActionCompleted.InvokeAsync();

            Toast.ShowSuccess(
                string.IsNullOrWhiteSpace(reply.Message)
                    ? $"{reply.RequeuedTransactionCount} Sage submission(s) requeued."
                    : reply.Message);
        }
        catch (Exception ex)
        {
            ex.Data["PageMethod"] = "DynamicBatchGridViewV2/RequeueSelectedSageSubmissionsAsync()";
            ex.Data["MessageType"] = ShowMessageType.Error;
            await OnError(ex);
        }
        finally
        {
            IsRequeueingSageSubmission = false;
            StateHasChanged();
        }
    }

    #endregion

    #region Navigation

    private async Task AddNew()
    {
        try
        {
            if (ViewDefinition is null)
                return;

            var (parentDataObjectReference, serializedParentDataObjectReference) =
                PWAFunctions.ProcessDataObjectReference(
                    modalService,
                    ParentDataObjectReference,
                    ParentGuid,
                    ViewDefinition.EntityTypeGuid);

            if (ViewDefinition.DetailPageUri == "DynamicEdit")
            {
                NavManager.NavigateTo(
                    $"{ViewDefinition.DetailPageUri}/" +
                    $"{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid)}/" +
                    $"{parentDataObjectReference.DataObjectGuid}/" +
                    $"{serializedParentDataObjectReference}/" +
                    $"{System.Web.HttpUtility.UrlEncode(NavManager.Uri)}");
            }
            else
            {
                NavManager.NavigateTo(
                    $"{ViewDefinition.DetailPageUri}/" +
                    $"{Guid.Empty}/" +
                    $"{serializedParentDataObjectReference}/" +
                    $"{System.Web.HttpUtility.UrlEncode(NavManager.Uri)}");
            }
        }
        catch (Exception ex)
        {
            ex.Data["PageMethod"] = "DynamicBatchGridViewV2/AddNew()";
            ex.Data["MessageType"] = ShowMessageType.Error;
            await OnError(ex);
        }
    }

    private async Task OnRowDoubleClickAsync(ExpandoObject row)
    {
        try
        {
            if (ViewDefinition is null || string.IsNullOrWhiteSpace(ViewDefinition.DetailPageUri))
                return;

            var model = (IDictionary<string, object>)row;

            if (!model.TryGetValue("Guid", out var guidObj))
                return;

            var recordGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(guidObj?.ToString() ?? Guid.Empty.ToString());
            if (recordGuid == Guid.Empty)
                return;

            var (parentDataObjectReference, serializedParentDataObjectReference) =
                PWAFunctions.ProcessDataObjectReference(
                    modalService,
                    ParentDataObjectReference,
                    recordGuid.ToString(),
                    ViewDefinition.EntityTypeGuid);

            if (ViewDefinition.DetailPageUri == "DynamicEdit")
            {
                NavManager.NavigateTo(
                    $"{ViewDefinition.DetailPageUri}/" +
                    $"{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid)}/" +
                    $"{parentDataObjectReference.DataObjectGuid}/" +
                    $"{serializedParentDataObjectReference}/" +
                    $"{System.Web.HttpUtility.UrlEncode(NavManager.Uri)}");
            }
            else
            {
                NavManager.NavigateTo(
                    $"{ViewDefinition.DetailPageUri}/" +
                    $"{recordGuid}/" +
                    $"{serializedParentDataObjectReference}/" +
                    $"{System.Web.HttpUtility.UrlEncode(NavManager.Uri)}");
            }
        }
        catch (Exception ex)
        {
            ex.Data["PageMethod"] = "DynamicBatchGridViewV2/OnRowDoubleClickAsync()";
            ex.Data["MessageType"] = ShowMessageType.Error;
            await OnError(ex);
        }
    }

    #endregion

    #region Visual helpers

    private int CountByStatus(string statusCode)
    {
        return AllRows.Count(row =>
        {
            var dict = (IDictionary<string, object>)row;
            return string.Equals(GetStatusText(dict), statusCode, StringComparison.OrdinalIgnoreCase);
        });
    }

    private bool IsStatusCardActive(string statusCode)
    {
        return string.Equals(ActiveStatusFilter, statusCode, StringComparison.OrdinalIgnoreCase);
    }

    private async Task ApplyStatusFilterAsync(string statusCode)
    {
        ActiveStatusFilter = statusCode;
        CurrentPage = 1;
        ApplyClientSideView();
        await InvokeAsync(StateHasChanged);
    }

    private async Task ClearStatusFilterAsync()
    {
        ActiveStatusFilter = "";
        CurrentPage = 1;
        ApplyClientSideView();
        await InvokeAsync(StateHasChanged);
    }
    private string GetStatusText(IDictionary<string, object> row)
    {
        if (!row.TryGetValue("StatusCode", out var value) || value is null)
            return "Unknown";

        return value.ToString() ?? "Unknown";
    }

    private string GetStatusBadgeClass(IDictionary<string, object> row)
    {
        var status = GetStatusText(row);

        return status switch
        {
            "Succeeded" => "status-badge status-green",
            "FailedRetryable" => "status-badge status-amber",
            "FailedNonRetryable" => "status-badge status-red",
            "InProgress" => "status-badge status-blue",
            "Pending" => "status-badge status-slate",
            _ => "status-badge status-slate"
        };
    }

    private string GetRowAccentClass(IDictionary<string, object> row)
    {
        var status = GetStatusText(row);

        return status switch
        {
            "Succeeded" => "row-accent-green",
            "FailedRetryable" => "row-accent-amber",
            "FailedNonRetryable" => "row-accent-red",
            "InProgress" => "row-accent-blue",
            _ => string.Empty
        };
    }

    private object? RenderCellValue(IDictionary<string, object> row, string columnName)
    {
        return row.TryGetValue(columnName, out var value) ? value : null;
    }

    #endregion

    #region Error handling

    public async Task OnError(Exception error)
    {
        if (string.IsNullOrWhiteSpace(error.Message))
            return;

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

        StateHasChanged();
        await Task.CompletedTask;
    }

    #endregion
}