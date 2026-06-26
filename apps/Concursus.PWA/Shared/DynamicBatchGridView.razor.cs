using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Common.Shared.Models.Finance;
using Concursus.Components.Shared.Classes;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using Concursus.PWA.Pages;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using Newtonsoft.Json;
using System.Collections;
using System.Dynamic;
using System.Globalization;
using System.Web;
using static Concursus.PWA.Shared.DynamicGrid;
using static Concursus.PWA.Shared.MessageDisplay;

namespace Concursus.PWA.Shared;

public partial class DynamicBatchGridView : ComponentBase
{
    #region Parameters

    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = "";
    [Parameter] public EventCallback<InputUpdatedArgs> inputUpdated { get; set; }
    [Parameter] public bool IsBulkProcessing { get; set; } = false;
    [Parameter] public IEnumerable<ExpandoObject> Items { get; set; } = new List<ExpandoObject>();
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    [Parameter] public EventCallback<IEnumerable<ExpandoObject>> OnSelectedItemsChanged { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public Dictionary<string, global::Google.Protobuf.WellKnownTypes.Any> TransientVirtualProperties { get; set; } = new();
    [Parameter] public DynamicGrid.DrawerItem SelectedItem { get; set; } = new();
    [Parameter] public EventCallback<DrawerItem> SelectedItemChanged { get; set; }

    [Parameter]
    public GridViewDefinition? ViewDefinition { get; set; }

    public List<GridViewActions> GridViewActions { get; set; } = new();
    private List<GridActionMenuItem> GridActionMenuItems { get; set; } = new();
    private bool IsActionMenuOpen { get; set; }
    private bool IsPerformingGridAction { get; set; }
    private string ActionMenuButtonText => IsPerformingGridAction ? "Working..." : "Actions";

    public bool HasChanges { get; private set; }

    #endregion

    #region Protected

    protected string ErrorMessage { get; set; } = "";
    protected ShowMessageType MessageType { get; set; } = ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";
    protected MessageDisplay _messageDisplay = new();

    #endregion

    #region Private state
    private SageFinanceTab ActiveTab { get; set; } = SageFinanceTab.PostingStatus;

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
    private IList<ExpandoObject> SelectedItems { get; set; } = new List<ExpandoObject>();
    private readonly Dictionary<string, object> _detailPageParameters = new();
    private Type? _detailPageType;
    private string _detailPageComponentKey = Guid.NewGuid().ToString("N");
    private string modalId = Guid.Empty.ToString();
    private bool WindowIsClosable { get; set; } = true;
    private bool WindowIsVisible { get; set; }
    private string WindowTitle { get; set; } = "Record Details";
    private bool ShowInvoiceMergeButton { get; set; }
    private bool isMergeLoadingScreenVisible { get; set; }
    private bool _showInvoicePreviewModal;
    private bool _isInvoicePreviewBusy;
    private readonly List<Guid> _previewTransactionGuids = new();
    private readonly List<InvoicePrintTemplate.InvoicePrintModel> _invoicePreviewModels = new();
    private int _currentInvoicePreviewIndex;
    private Guid CurrentPreviewTransactionGuid =>
        _currentInvoicePreviewIndex >= 0 && _currentInvoicePreviewIndex < _previewTransactionGuids.Count
            ? _previewTransactionGuids[_currentInvoicePreviewIndex]
            : Guid.Empty;

    private InvoicePrintTemplate.InvoicePrintModel? CurrentInvoicePreviewModel =>
        _currentInvoicePreviewIndex >= 0 && _currentInvoicePreviewIndex < _invoicePreviewModels.Count
            ? _invoicePreviewModels[_currentInvoicePreviewIndex]
            : null;

    private List<Guid> InvoiceReqsToMerge { get; set; } = new();

    private bool IsLoading { get; set; }
    private bool IsRequeueingSageSubmission { get; set; }

    private int CurrentPage { get; set; } = 1;
    private int PageSize { get; set; } = 25;
    private int TotalRows { get; set; }

    private string SearchText { get; set; } = "";
    private string CurrentSortColumn { get; set; } = "";
    private bool IsSortDescending { get; set; }
    private int ReceivedCount => CountByStatus("Received");

    private sealed record StatusSummaryCard(
        string FilterCode,
        string Title,
        int Count,
        string Subtitle,
        string CssClass,
        string IconCss);

    private bool IsReceivedAlreadySubmitted(IDictionary<string, object> row)
    {
        var latestOutboxError = row.TryGetValue("LatestOutboxError", out var outboxValue)
            ? outboxValue?.ToString()
            : null;

        return !string.IsNullOrWhiteSpace(latestOutboxError)
            && latestOutboxError.Contains("already been submitted to sage", StringComparison.OrdinalIgnoreCase);
    }

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

    private enum SageFinanceTab
    {
        PostingStatus,
        InboundDiagnostics
    }

    private void SetActiveTab(SageFinanceTab tab)
    {
        if (ActiveTab == tab)
            return;

        ActiveTab = tab;
    }

    private string GetTabClass(SageFinanceTab tab)
    {
        return ActiveTab == tab ? "is-active" : string.Empty;
    }

    private bool IsResettingFailedSageSubmission { get; set; }

    private bool CanResetFailedSelectedSageSubmissions =>
        !IsBulkProcessing
        && !IsRequeueingSageSubmission
        && !IsResettingFailedSageSubmission
        && IsSageSubmissionMonitorView
        && GetSelectedFailedNonRetryableTransactionGuids().Count > 0;

    private List<Guid> GetSelectedFailedNonRetryableTransactionGuids()
    {
        var result = new List<Guid>();

        foreach (var row in FilteredRows)
        {
            var dict = (IDictionary<string, object>)row;
            var guid = GetRowGuid(dict);

            if (guid == Guid.Empty || !SelectedRowGuids.Contains(guid))
                continue;

            if (!string.Equals(GetStatusText(dict), "FailedNonRetryable", StringComparison.OrdinalIgnoreCase))
                continue;

            if (dict.TryGetValue("TransactionGuid", out var txObj)
                && Guid.TryParse(txObj?.ToString(), out var txGuid)
                && txGuid != Guid.Empty
                && !result.Contains(txGuid))
            {
                result.Add(txGuid);
            }
        }

        return result;
    }

    private async Task ResetFailedSelectedSageSubmissionsAsync()
    {
        if (!CanResetFailedSelectedSageSubmissions)
            return;

        var transactionGuids = GetSelectedFailedNonRetryableTransactionGuids();
        if (transactionGuids.Count == 0)
            return;

        var confirmed = await JsRuntime.InvokeAsync<bool>(
            "confirm",
            $"Reset {transactionGuids.Count} failed non-retryable Sage submission record(s) to Pending so they can be retried?");

        if (!confirmed)
            return;

        try
        {
            IsResettingFailedSageSubmission = true;
            StateHasChanged();

            var request = new TransactionSageSubmissionRequeueRequest
            {
                IncludeNonRetryableFailures = true
            };

            request.TransactionGuids.AddRange(transactionGuids.Select(x => x.ToString()));

            var reply = await coreClient.TransactionSageSubmissionRequeueAsync(request);

            SelectedRowGuids.Clear();

            await LoadDataAsync();

            if (OnActionCompleted.HasDelegate)
                await OnActionCompleted.InvokeAsync();

            Toast.ShowSuccess(
                string.IsNullOrWhiteSpace(reply.Message)
                    ? $"{reply.RequeuedTransactionCount} failed Sage submission(s) reset for retry."
                    : reply.Message);
        }
        catch (Exception ex)
        {
            ex.Data["PageMethod"] = "DynamicBatchGridView/ResetFailedSelectedSageSubmissionsAsync()";
            ex.Data["MessageType"] = ShowMessageType.Error;
            await OnError(ex);
        }
        finally
        {
            IsResettingFailedSageSubmission = false;
            StateHasChanged();
        }
    }
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

    protected override void OnAfterRender(bool firstRender)
    {
        if (ViewDefinition is not null)
        {
            GridViewActions = ViewDefinition.GridViewActions?.ToList() ?? new List<GridViewActions>();
            RebuildGridActionMenuItems();
        }

        base.OnAfterRender(firstRender);
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
            ex.Data["PageMethod"] = "DynamicBatchGridView/LoadDataAsync()";
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
        SelectedItems = FilteredRows
            .Where(row =>
            {
                var guid = GetRowGuid((IDictionary<string, object>)row);
                return guid != Guid.Empty && SelectedRowGuids.Contains(guid);
            })
            .ToList();

        ShowInvoiceMergeButton = CanInvoiceRequestRecordsBeMerged(SelectedItems);

        if (OnSelectedItemsChanged.HasDelegate)
            await OnSelectedItemsChanged.InvokeAsync(SelectedItems);
    }


    #region Grid action menu

    private bool HasGridActions => GridActionMenuItems.Count > 0;

    private void RebuildGridActionMenuItems()
    {
        var items = new List<GridActionMenuItem>();

        if (ViewDefinition?.GridViewActions is not null)
        {
            foreach (var item in ViewDefinition.GridViewActions
                         .Where(x => x is not null)
                         .OrderBy(x => x.Title))
            {
                var title = item.Title?.Trim();
                if (string.IsNullOrWhiteSpace(title))
                    continue;

                items.Add(new GridActionMenuItem
                {
                    Text = title,
                    Query = item.Statement ?? string.Empty,
                    Icon = GetGridActionIcon(title)
                });
            }
        }

        if (IsBatchedTransactionsGrid()
            && !items.Any(x => string.Equals(x.Text, "Preview Invoice/s", StringComparison.OrdinalIgnoreCase)))
        {
            items.Insert(0, new GridActionMenuItem
            {
                Text = "Preview Invoice/s",
                Query = string.Empty,
                Icon = "bi bi-eye"
            });
        }

        GridActionMenuItems = items
            .GroupBy(x => x.Text, StringComparer.OrdinalIgnoreCase)
            .Select(x => x.First())
            .ToList();
    }

    private static string GetGridActionIcon(string title)
    {
        return title switch
        {
            "Create Invoice" => "bi bi-currency-dollar",
            "Invoice Request → Create Invoice (Batch)" => "bi bi-receipt",
            "Batch Delete" => "bi bi-trash",
            "Approve Invoice(s)" => "bi bi-check2-circle",
            "Preview Invoice/s" => "bi bi-eye",
            _ => "bi bi-lightning-charge"
        };
    }

    private bool IsBatchedTransactionsGrid()
    {
        return string.Equals(ViewDefinition?.Code, "BATCHEDTRANSACTIONS", StringComparison.OrdinalIgnoreCase);
    }

    private bool IsInvoiceRequestGrid()
    {
        return string.Equals(ViewDefinition?.Code, "INVOICEREQUESTS", StringComparison.OrdinalIgnoreCase);
    }

    private async Task ToggleActionMenuAsync()
    {
        if (!HasGridActions || IsPerformingGridAction)
            return;

        IsActionMenuOpen = !IsActionMenuOpen;
        await InvokeAsync(StateHasChanged);
    }

    private async Task OnGridActionClickedAsync(GridActionMenuItem item)
    {
        IsActionMenuOpen = false;

        if (item is null)
            return;

        if (SelectedItems is null || !SelectedItems.Any())
        {
            await JsRuntime.InvokeVoidAsync("alert", "No records selected.");
            return;
        }

        if (string.Equals(item.Text, "Preview Invoice/s", StringComparison.OrdinalIgnoreCase))
        {
            await OpenInvoicePreviewModalAsync();
            return;
        }

        if (string.Equals(item.Text, "Approve Invoice(s)", StringComparison.OrdinalIgnoreCase))
        {
            var confirmed = await JsRuntime.InvokeAsync<bool>(
                "confirm",
                "Are you sure? This will prevent the transaction from being modified.");

            if (!confirmed)
                return;
        }

        if (string.Equals(item.Text, "Batch Delete", StringComparison.OrdinalIgnoreCase))
        {
            var confirmed = await JsRuntime.InvokeAsync<bool>(
                "confirm",
                $"Delete the selected {SelectedItems.Count()} record(s)?");

            if (!confirmed)
                return;
        }

        await PerformActionAsync(item);
    }

    private async Task PerformActionAsync(GridActionMenuItem item)
    {
        try
        {
            IsPerformingGridAction = true;
            StateHasChanged();

            var formHelper = new FormHelper(coreClient, sageIntegrationService, ViewDefinition?.EntityTypeGuid ?? Guid.Empty.ToString(), userService);
            item.FormHelper = formHelper;

            var infoMessage = PWAFunctions.GetMessageDisplayFromGridViewAction(
                item,
                new Exception(),
                ShowMessageType.Information);

            await OnError(infoMessage);

            foreach (var selectedItem in SelectedItems ?? Enumerable.Empty<ExpandoObject>())
            {
                if (selectedItem is not IDictionary<string, object> expandoDict)
                    continue;

                var recordGuid = GetRowGuidValue(
                    expandoDict,
                    "Guid",
                    "RecordGuid",
                    "DataObjectGuid",
                    "TransactionGuid",
                    "InvoiceRequestGuid");

                if (recordGuid == Guid.Empty)
                    continue;

                var response = await formHelper.GridMenuItemPostAsync(
                    item.Query ?? string.Empty,
                    recordGuid.ToString());

                if (!string.IsNullOrWhiteSpace(response.ErrorReturned))
                    throw new Exception(response.ErrorReturned);
            }

            var successMessage = PWAFunctions.GetMessageDisplayFromGridViewAction(
                item,
                new Exception(),
                ShowMessageType.Success);

            await OnError(successMessage);

            SelectedRowGuids.Clear();
            await LoadDataAsync();

            if (OnActionCompleted.HasDelegate)
                await OnActionCompleted.InvokeAsync();
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "An error occurred while trying to perform an action from the grid menu.";
            ex.Data["PageMethod"] = "DynamicBatchGridView/PerformActionAsync()";
            await OnError(ex);
        }
        finally
        {
            IsPerformingGridAction = false;
            StateHasChanged();
        }
    }

    #endregion

    #region Invoice preview

    private static string GetRowStringValue(
        IDictionary<string, object> row,
        params string[] keys)
    {
        if (row is null || keys is null || keys.Length == 0)
            return string.Empty;

        foreach (var key in keys)
        {
            if (string.IsNullOrWhiteSpace(key))
                continue;

            if (row.TryGetValue(key, out var directValue) && directValue is not null)
            {
                var directText = Convert.ToString(directValue, CultureInfo.InvariantCulture)?.Trim() ?? string.Empty;

                if (!string.IsNullOrWhiteSpace(directText))
                    return directText;
            }

            var matchedPair = row.FirstOrDefault(x =>
                string.Equals(x.Key?.Trim(), key.Trim(), StringComparison.OrdinalIgnoreCase));

            if (!string.IsNullOrWhiteSpace(matchedPair.Key) && matchedPair.Value is not null)
            {
                var matchedText = Convert.ToString(matchedPair.Value, CultureInfo.InvariantCulture)?.Trim() ?? string.Empty;

                if (!string.IsNullOrWhiteSpace(matchedText))
                    return matchedText;
            }
        }

        return string.Empty;
    }

    private static Guid GetRowGuidValue(
        IDictionary<string, object> row,
        params string[] keys)
    {
        foreach (var key in keys)
        {
            if (row.TryGetValue(key, out var value)
                && value is not null
                && Guid.TryParse(value.ToString(), out var guid))
            {
                return guid;
            }
        }

        return Guid.Empty;
    }

    private static bool IsInvoiceTransactionRow(IDictionary<string, object> row)
    {
        var transactionType = GetRowStringValue(
            row,
            "TransactionType",
            "Transaction Type",
            "TransactionTypeName",
            "Type",
            "TypeName");

        return transactionType.Equals("Invoice", StringComparison.OrdinalIgnoreCase)
            || string.IsNullOrWhiteSpace(transactionType);
    }

    private async Task OpenInvoicePreviewModalAsync()
    {
        try
        {
            if (SelectedItems is null || !SelectedItems.Any())
            {
                await JsRuntime.InvokeVoidAsync("alert", "No records selected for preview.");
                return;
            }

            _isInvoicePreviewBusy = true;
            ResetInvoicePreviewState();

            var formHelper = new FormHelper(coreClient, sageIntegrationService, ViewDefinition?.EntityTypeGuid ?? Guid.Empty.ToString(), userService);
            var selectedTransactionGuids = new List<Guid>();

            foreach (var selectedItem in SelectedItems)
            {
                if (selectedItem is not IDictionary<string, object> dict)
                    continue;

                if (!IsInvoiceTransactionRow(dict))
                {
                    await ShowGridMessageAsync(
                        "Invoice preview is only available for Invoice transactions.",
                        ShowMessageType.Information,
                        "DynamicBatchGridView/OpenInvoicePreviewModalAsync");

                    return;
                }

                var transactionGuid = GetRowGuidValue(
                    dict,
                    "Guid",
                    "TransactionGuid",
                    "RecordGuid",
                    "DataObjectGuid");

                if (transactionGuid == Guid.Empty)
                {
                    await ShowGridMessageAsync(
                        "Invoice preview could not be opened because the selected invoice transaction guid could not be resolved.",
                        ShowMessageType.Error,
                        "DynamicBatchGridView/OpenInvoicePreviewModalAsync");

                    return;
                }

                selectedTransactionGuids.Add(transactionGuid);
            }

            selectedTransactionGuids = selectedTransactionGuids
                .Distinct()
                .ToList();

            foreach (var transactionGuid in selectedTransactionGuids)
            {
                var previewModel = await formHelper.TransactionInvoicePrintModelGetAsync(
                    transactionGuid,
                    TransactionInvoiceRenderMode.Preview);

                if (previewModel is null)
                    continue;

                _previewTransactionGuids.Add(transactionGuid);
                _invoicePreviewModels.Add(MapToInvoicePrintTemplateModel(previewModel));
            }

            if (_invoicePreviewModels.Count == 0)
            {
                await ShowGridMessageAsync(
                    "Invoice preview could not be loaded for the selected invoice transaction(s).",
                    ShowMessageType.Error,
                    "DynamicBatchGridView/OpenInvoicePreviewModalAsync");

                return;
            }

            _currentInvoicePreviewIndex = 0;
            _showInvoicePreviewModal = true;
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "An error occurred while trying to open the invoice preview.";
            ex.Data["PageMethod"] = "DynamicBatchGridView/OpenInvoicePreviewModalAsync";
            await OnError(ex);
        }
        finally
        {
            _isInvoicePreviewBusy = false;
            StateHasChanged();
        }
    }

    private void ShowPreviousInvoicePreview()
    {
        if (_currentInvoicePreviewIndex <= 0)
            return;

        _currentInvoicePreviewIndex--;
        StateHasChanged();
    }

    private void ShowNextInvoicePreview()
    {
        if (_currentInvoicePreviewIndex >= _invoicePreviewModels.Count - 1)
            return;

        _currentInvoicePreviewIndex++;
        StateHasChanged();
    }

    private void CloseInvoicePreviewWindow()
    {
        ResetInvoicePreviewState();
    }

    private void ResetInvoicePreviewState()
    {
        _showInvoicePreviewModal = false;
        _isInvoicePreviewBusy = false;
        _currentInvoicePreviewIndex = 0;
        _previewTransactionGuids.Clear();
        _invoicePreviewModels.Clear();
    }

    private async Task ShowGridMessageAsync(string message, ShowMessageType messageType, string pageMethod)
    {
        var ex = new Exception(message);
        ex.Data["MessageType"] = messageType;
        ex.Data["AdditionalInfo"] = message;
        ex.Data["PageMethod"] = pageMethod;
        await OnError(ex);
    }

    private static InvoicePrintTemplate.InvoicePrintModel MapToInvoicePrintTemplateModel(
        TransactionInvoicePrintModel source)
    {
        return new InvoicePrintTemplate.InvoicePrintModel
        {
            LogoUrl = "/SOC-LOGO.png",
            CustomerReference = source.CustomerReference,
            InvoiceToBlock = source.InvoiceToBlock,
            TaxPointDate = source.TaxPointDate,
            PaymentTerms = source.PaymentTerms,
            CostCentre = source.CostCentre,
            Department = source.Department,
            InvoiceNumber = source.InvoiceNumber,
            SalesOrderNumber = source.SalesOrderNumber,
            PurchaseOrderNumber = source.PurchaseOrderNumber,
            TotalAmountExcludingVat = source.TotalAmountExcludingVat,
            TotalVat = source.TotalVat,
            TotalAmountDue = source.TotalAmountDue,
            Lines = source.Lines
                .Select(x => new InvoicePrintTemplate.InvoicePrintLineModel
                {
                    Description = x.Description,
                    Quantity = x.Quantity,
                    UnitPrice = x.UnitPrice,
                    AmountExVat = x.AmountExVat,
                    VatCode = x.VatCode,
                    VatAmount = x.VatAmount
                })
                .ToList()
        };
    }

    #endregion

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

            if (!IsRowRetryable(dict))
                continue;

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
            ex.Data["PageMethod"] = "DynamicBatchGridView/RequeueSelectedSageSubmissionsAsync()";
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

            if (ViewDefinition.IsDetailWindowed)
            {
                if (string.IsNullOrWhiteSpace(ViewDefinition.DetailPageUri))
                    throw new InvalidOperationException("DetailPageUri is not set in the ViewDefinition.");

                modalId = Guid.NewGuid().ToString();
                WindowTitle = $"New {ViewDefinition.Name}";

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
                _detailPageType = ResolveDetailPageType(ViewDefinition.DetailPageUri) ?? typeof(DynamicEdit);
                _detailPageComponentKey = $"{modalId}:{_detailPageParameters["RecordGuid"]}:{Guid.NewGuid():N}";
                modalService.RegisterModal(modalId, parentDataObjectReference);
                WindowIsVisible = true;
                StateHasChanged();
                return;
            }

            if (ViewDefinition.DetailPageUri == "DynamicEdit")
            {
                NavManager.NavigateTo(
                    $"{ViewDefinition.DetailPageUri}/" +
                    $"{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid)}/" +
                    $"{parentDataObjectReference.DataObjectGuid}/" +
                    $"{serializedParentDataObjectReference}/" +
                    $"{HttpUtility.UrlEncode(NavManager.Uri)}");
            }
            else
            {
                NavManager.NavigateTo(
                    $"{ViewDefinition.DetailPageUri}/" +
                    $"{Guid.Empty}/" +
                    $"{serializedParentDataObjectReference}/" +
                    $"{HttpUtility.UrlEncode(NavManager.Uri)}");
            }
        }
        catch (Exception ex)
        {
            ex.Data["PageMethod"] = "DynamicBatchGridView/AddNew()";
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

            if (ViewDefinition.IsDetailWindowed)
            {
                modalId = Guid.NewGuid().ToString();
                WindowTitle = $"Edit {ViewDefinition.Name}";

                _detailPageParameters.Clear();
                _detailPageParameters.Add("EntityTypeGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
                _detailPageParameters.Add("Windowed", true);
                _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
                _detailPageParameters.Add("GridUpdated", EventCallback.Factory.Create(this, GridUpdated));
                _detailPageParameters.Add("RecordGuid", recordGuid.ToString());
                _detailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
                _detailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                _detailPageParameters.Add("ModalId", modalId);
                _detailPageParameters.Add("IsDetailWindowed", true);
                _detailPageParameters.Add("IsMainRecordContext", false);
                _detailPageParameters.Add("TransientVirtualProperties", TransientVirtualProperties);
                _detailPageType = ResolveDetailPageType(ViewDefinition.DetailPageUri) ?? typeof(DynamicEdit);
                _detailPageComponentKey = $"{modalId}:{_detailPageParameters["RecordGuid"]}:{Guid.NewGuid():N}";
                modalService.RegisterModal(modalId, parentDataObjectReference);
                WindowIsVisible = true;
                StateHasChanged();
                return;
            }

            if (ViewDefinition.DetailPageUri == "DynamicEdit")
            {
                NavManager.NavigateTo(
                    $"{ViewDefinition.DetailPageUri}/" +
                    $"{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid)}/" +
                    $"{parentDataObjectReference.DataObjectGuid}/" +
                    $"{serializedParentDataObjectReference}/" +
                    $"{HttpUtility.UrlEncode(NavManager.Uri)}");
            }
            else
            {
                NavManager.NavigateTo(
                    $"{ViewDefinition.DetailPageUri}/" +
                    $"{recordGuid}/" +
                    $"{serializedParentDataObjectReference}/" +
                    $"{HttpUtility.UrlEncode(NavManager.Uri)}");
            }
        }
        catch (Exception ex)
        {
            ex.Data["PageMethod"] = "DynamicBatchGridView/OnRowDoubleClickAsync()";
            ex.Data["MessageType"] = ShowMessageType.Error;
            await OnError(ex);
        }
    }


    private static Type? ResolveDetailPageType(string? detailPageUri)
    {
        if (string.IsNullOrWhiteSpace(detailPageUri)) return null;

        var candidates = new[]
        {
            $"Concursus.PWA.Pages.{detailPageUri}",
            $"Concursus.PWA.Pages.{detailPageUri}, Concursus.PWA",
            $"Concursus.PWA.Shared.{detailPageUri}",
            $"Concursus.PWA.Shared.{detailPageUri}, Concursus.PWA"
        };

        return candidates
            .Select(Type.GetType)
            .FirstOrDefault(t => t is not null);
    }
    #endregion

    #region Visual helpers



    private string GetGridSubtitle()
    {
        var viewName = ViewDefinition?.Name?.Trim();

        if (IsSageSubmissionMonitorView)
            return "Support monitor for Sage posting activity, retry management, and inbound payment allocation diagnostics.";

        if (IsInvoiceRequestGrid())
            return "Review invoice request readiness, account/batching issues, merge options, and create-batch actions.";

        if (IsBatchedTransactionsGrid())
            return "Review batched transactions before invoice preview, approval, or deletion.";

        if (!string.IsNullOrWhiteSpace(viewName))
            return $"Review and process {viewName} records.";

        return "Review and process records for the selected grid view.";
    }

    private string GetSearchPlaceholder()
    {
        var viewName = ViewDefinition?.Name?.Trim();

        if (IsSageSubmissionMonitorView)
            return "Search transactions, statuses, responses, errors...";

        if (!string.IsNullOrWhiteSpace(viewName))
            return $"Search {viewName.ToLowerInvariant()} records, statuses, references...";

        return "Search records, statuses, references...";
    }

    private string ResolveBatchedTransactionStatus(ExpandoObject row)
    {
        if (row is null)
        {
            return "Unknown";
        }

        var netValue = GetValueAsDecimal(row, "Net");

        if (netValue == 0m)
        {
            return "Invoice request value is zero or negative and cannot be converted into a transaction.";
        }

        var consultant = GetFirstValueAsString(
            row,
            "Consultant",
            "ConsultantName",
            "ConsultantFullName",
            "CreatedByUser",
            "UserName");

        if (string.IsNullOrWhiteSpace(consultant))
        {
            return "Note: Consultant field is empty";
        }

        return "Ready for approval";
    }

    private string GetFirstValueAsString(ExpandoObject row, params string[] propertyNames)
    {
        if (row is null || propertyNames is null || propertyNames.Length == 0)
        {
            return string.Empty;
        }

        var dictionary = (IDictionary<string, object?>)row;

        foreach (var propertyName in propertyNames)
        {
            if (string.IsNullOrWhiteSpace(propertyName))
            {
                continue;
            }

            var match = dictionary.FirstOrDefault(x =>
                string.Equals(x.Key, propertyName, StringComparison.OrdinalIgnoreCase));

            if (string.IsNullOrWhiteSpace(match.Key) || match.Value is null)
            {
                continue;
            }

            var value = Convert.ToString(match.Value, CultureInfo.InvariantCulture);

            if (!string.IsNullOrWhiteSpace(value))
            {
                return value.Trim();
            }
        }

        return string.Empty;
    }

    private decimal GetValueAsDecimal(ExpandoObject row, params string[] propertyNames)
    {
        if (row is null || propertyNames is null || propertyNames.Length == 0)
        {
            return 0m;
        }

        var dictionary = (IDictionary<string, object?>)row;

        foreach (var propertyName in propertyNames)
        {
            if (string.IsNullOrWhiteSpace(propertyName))
            {
                continue;
            }

            var match = dictionary.FirstOrDefault(x =>
                string.Equals(x.Key, propertyName, StringComparison.OrdinalIgnoreCase));

            if (string.IsNullOrWhiteSpace(match.Key) || match.Value is null)
            {
                continue;
            }

            if (match.Value is decimal decimalValue)
            {
                return decimalValue;
            }

            if (match.Value is double doubleValue)
            {
                return Convert.ToDecimal(doubleValue, CultureInfo.InvariantCulture);
            }

            if (match.Value is float floatValue)
            {
                return Convert.ToDecimal(floatValue, CultureInfo.InvariantCulture);
            }

            if (match.Value is int intValue)
            {
                return intValue;
            }

            if (match.Value is long longValue)
            {
                return longValue;
            }

            if (decimal.TryParse(
                    Convert.ToString(match.Value, CultureInfo.InvariantCulture),
                    NumberStyles.Any,
                    CultureInfo.InvariantCulture,
                    out var parsed))
            {
                return parsed;
            }
        }

        return 0m;
    }
    private List<StatusSummaryCard> StatusCards
    {
        get
        {
            if (IsSageSubmissionMonitorView)
            {
                return new List<StatusSummaryCard>
                {
                    new("Succeeded", "Succeeded", SucceededCount, "Completed successfully", "dynamic-batch-grid-v2-summary-green", "bi bi-check-circle"),
                    new("FailedRetryable", "Failed Retryable", FailedRetryableCount, "Can be requeued", "dynamic-batch-grid-v2-summary-amber", "bi bi-arrow-repeat"),
                    new("FailedNonRetryable", "Failed Non-Retryable", FailedNonRetryableCount, "Needs data/config fix", "dynamic-batch-grid-v2-summary-red", "bi bi-exclamation-triangle"),
                    new("InProgress", "In Progress", InProgressCount, "Currently processing", "dynamic-batch-grid-v2-summary-blue", "bi bi-hourglass-split"),
                    new("Pending", "Pending", PendingCount, "Awaiting processing", "dynamic-batch-grid-v2-summary-slate", "bi bi-clock"),
                    new("Received", "Received", ReceivedCount, "Already received by Sage", "dynamic-batch-grid-v2-summary-purple", "bi bi-inbox")
                };
            }

            return AllRows
                .Select(row => GetStatusText((IDictionary<string, object>)row))
                .Where(x => !string.IsNullOrWhiteSpace(x) && !string.Equals(x, "Unknown", StringComparison.OrdinalIgnoreCase))
                .GroupBy(x => x, StringComparer.OrdinalIgnoreCase)
                .OrderByDescending(x => x.Count())
                .ThenBy(x => x.Key)
                .Select(group =>
                {
                    var status = group.Key;
                    return new StatusSummaryCard(
                        status,
                        FormatStatusTitle(status),
                        group.Count(),
                        GetStatusCardSubtitle(status),
                        GetStatusSummaryClass(status),
                        GetStatusIconClass(status));
                })
                .ToList();
        }
    }

    private bool HasStatusCards => StatusCards.Count > 0;

    private static string GetStatusCardTooltip(StatusSummaryCard card)
    {
        var title = string.IsNullOrWhiteSpace(card.Title) ? "Status" : card.Title.Trim();
        var subtitle = string.IsNullOrWhiteSpace(card.Subtitle) ? "Matching records" : card.Subtitle.Trim();

        return $"{title}: {card.Count} record{(card.Count == 1 ? string.Empty : "s")}. {subtitle}";
    }

    private string GetStatusTooltip(IDictionary<string, object> row)
    {
        var detail = GetStatusDetail(row);
        var status = GetStatusText(row);

        if (string.IsNullOrWhiteSpace(detail))
            return status;

        if (string.Equals(detail, status, StringComparison.OrdinalIgnoreCase))
            return status;

        return $"{status}: {detail}";
    }

    private static string FormatStatusTitle(string status)
    {
        if (string.IsNullOrWhiteSpace(status))
            return "Unknown";

        return status
            .Replace("_", " ")
            .Replace("-", " ")
            .Trim();
    }

    private static string GetStatusCardSubtitle(string status)
    {
        return GetStatusTone(status) switch
        {
            "red" => "Needs attention",
            "green" => "Ready/complete records",
            "amber" => "Awaiting attention",
            "blue" => "Batch/processing records",
            "purple" => "Received records",
            _ => "Matching records"
        };
    }

    private static string GetStatusSummaryClass(string status)
    {
        return GetStatusTone(status) switch
        {
            "red" => "dynamic-batch-grid-v2-summary-red",
            "green" => "dynamic-batch-grid-v2-summary-green",
            "amber" => "dynamic-batch-grid-v2-summary-amber",
            "blue" => "dynamic-batch-grid-v2-summary-blue",
            "purple" => "dynamic-batch-grid-v2-summary-purple",
            _ => "dynamic-batch-grid-v2-summary-slate"
        };
    }

    private static string GetStatusIconClass(string status)
    {
        return GetStatusTone(status) switch
        {
            "red" => "bi bi-exclamation-triangle",
            "green" => "bi bi-check-circle",
            "amber" => "bi bi-clock",
            "blue" => "bi bi-hourglass-split",
            "purple" => "bi bi-inbox",
            _ => "bi bi-circle"
        };
    }

    private static string GetStatusTone(string status)
    {
        var normalized = NormalizeStatus(status);

        if (ContainsStatusToken(
                normalized,
                "missing",
                "issue",
                "failed",
                "failure",
                "error",
                "rejected",
                "declined",
                "deleted",
                "passed",
                "invalid",
                "zero or negative",
                "cannot be converted",
                "no finance account",
                "finance account does not have",
                "does not have a valid sage code",
                "valid sage code"))
        {
            return "red";
        }

        if (ContainsStatusToken(
                normalized,
                "consultant field is empty",
                "note:",
                "pending",
                "waiting",
                "sent",
                "submitted",
                "terms"))
        {
            return "amber";
        }

        if (ContainsStatusToken(
                normalized,
                "ready",
                "ready for approval",
                "ready for batching",
                "success",
                "succeeded",
                "approved",
                "accepted",
                "complete",
                "completed",
                "ok",
                "expected date ok"))
        {
            return "green";
        }

        if (ContainsStatusToken(
                normalized,
                "inprogress",
                "in progress",
                "processing",
                "batched",
                "batch"))
        {
            return "blue";
        }

        if (ContainsStatusToken(normalized, "received"))
        {
            return "purple";
        }

        if (ContainsStatusToken(normalized, "draft", "new", "created", "open"))
        {
            return "slate";
        }

        return "slate";
    }

    private static bool ContainsStatusToken(string normalizedStatus, params string[] tokens)
    {
        if (string.IsNullOrWhiteSpace(normalizedStatus) || tokens is null || tokens.Length == 0)
        {
            return false;
        }

        return tokens.Any(token =>
            !string.IsNullOrWhiteSpace(token)
            && normalizedStatus.Contains(token.Trim().ToLowerInvariant(), StringComparison.OrdinalIgnoreCase));
    }

    private static string NormalizeStatus(string status)
    {
        return (status ?? string.Empty)
            .Trim()
            .Replace("_", " ")
            .Replace("-", " ")
            .ToLowerInvariant();
    }

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
        if (IsReceivedAlreadySubmitted(row))
            return "Received";

        if (IsInvoiceRequestGrid())
        {
            var issueMessages = GetInvoiceRequestIssueMessages(row);

            if (issueMessages.Count > 0)
                return string.Join(" / ", issueMessages);

            return "Ready for batching";
        }

        if (IsBatchedTransactionsGrid())
        {
            var netValue = GetRowDecimalValue(row, "Net", "LineNet", "NetValue");

            if (netValue == 0m)
                return "Invoice request value is zero or negative and cannot be converted into a transaction.";

            var consultant = GetRowStringValue(
                row,
                "Surveyor",
                "Consultant",
                "Consultant Name",
                "ConsultantName",
                "ConsultantFullName",
                "AssignedConsultant",
                "AssignedConsultantName",
                "UserFullName",
                "CreatedByUser",
                "CreatedByUserName",
                "CreatedBy",
                "Owner",
                "OwnerName");

            if (string.IsNullOrWhiteSpace(consultant))
                return "Note: Consultant field is empty";

            return "Ready for approval";
        }

        var explicitStatus = GetRowStringValue(
            row,
            "StatusCode",
            "Status",
            "StatusName",
            "StatusNameText",
            "WorkflowStatus",
            "WorkflowStatusName",
            "LatestResponseStatus",
            "InvoiceRequestStatus",
            "TransactionStatus",
            "BatchStatus",
            "BatchStatusName",
            "TransactionBatchStatus",
            "InvoiceStatus",
            "InvoiceStatusName",
            "LatestResponse",
            "LatestResponseDetail",
            "LatestOutboxError");

        if (!string.IsNullOrWhiteSpace(explicitStatus))
            return CollapseLongStatus(explicitStatus);

        if (TryGetExpectedDateStatus(row, out var expectedDateStatus))
            return expectedDateStatus;

        return "Unknown";
    }

    private decimal GetRowDecimalValue(IDictionary<string, object> row, params string[] propertyNames)
    {
        foreach (var propertyName in propertyNames)
        {
            if (string.IsNullOrWhiteSpace(propertyName))
                continue;

            if (!row.TryGetValue(propertyName, out var value) || value is null)
            {
                var match = row.FirstOrDefault(x =>
                    string.Equals(x.Key, propertyName, StringComparison.OrdinalIgnoreCase));

                value = string.IsNullOrWhiteSpace(match.Key) ? null : match.Value;
            }

            if (value is null)
                continue;

            if (value is decimal decimalValue)
                return decimalValue;

            if (value is double doubleValue)
                return Convert.ToDecimal(doubleValue, CultureInfo.InvariantCulture);

            if (value is float floatValue)
                return Convert.ToDecimal(floatValue, CultureInfo.InvariantCulture);

            if (value is int intValue)
                return intValue;

            if (value is long longValue)
                return longValue;

            if (decimal.TryParse(
                    Convert.ToString(value, CultureInfo.InvariantCulture),
                    NumberStyles.Any,
                    CultureInfo.InvariantCulture,
                    out var parsed))
            {
                return parsed;
            }
        }

        return 0m;
    }
    private string GetStatusDetail(IDictionary<string, object> row)
    {
        if (IsInvoiceRequestGrid())
        {
            var issueMessages = GetInvoiceRequestIssueMessages(row);
            return issueMessages.Count > 0
                ? string.Join(" ", issueMessages)
                : "Ready for batching.";
        }

        var detail = GetRowStringValue(
            row,
            "FinanceAccountIssueMessage",
            "BatchingIssueMessage",
            "LatestResponseDetail",
            "LatestOutboxError",
            "LastError",
            "ErrorMessage",
            "StatusMessage",
            "StatusDetail");

        return string.IsNullOrWhiteSpace(detail)
            ? GetStatusText(row)
            : detail;
    }

    private List<string> GetInvoiceRequestIssueMessages(IDictionary<string, object> row)
    {
        var messages = new List<string>();

        var hasFinanceIssue = TryGetRowBoolean(row, "HasFinanceAccountIssue");
        var hasBatchingIssue = TryGetRowBoolean(row, "HasBatchingIssue");

        if (hasFinanceIssue)
        {
            var financeMessage = GetRowStringValue(row, "FinanceAccountIssueMessage");

            messages.Add(!string.IsNullOrWhiteSpace(financeMessage)
                ? financeMessage
                : "Missing account code");
        }

        if (hasBatchingIssue)
        {
            var batchingMessage = GetRowStringValue(row, "BatchingIssueMessage");

            messages.Add(!string.IsNullOrWhiteSpace(batchingMessage)
                ? batchingMessage
                : "Batching issue");
        }

        if (messages.Count == 0)
        {
            var fallbackIssue = GetRowStringValue(
                row,
                "IssueMessage",
                "WarningMessage",
                "BlockingReason",
                "BlockingDiagnostics",
                "ValidationMessage");

            if (!string.IsNullOrWhiteSpace(fallbackIssue))
                messages.Add(fallbackIssue);
        }

        return messages
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static bool TryGetRowBoolean(IDictionary<string, object> row, string key)
    {
        if (!row.TryGetValue(key, out var value) || value is null)
            return false;

        if (value is bool boolValue)
            return boolValue;

        if (bool.TryParse(value.ToString(), out var parsedBool))
            return parsedBool;

        if (int.TryParse(value.ToString(), out var parsedInt))
            return parsedInt != 0;

        return false;
    }

    private static string CollapseLongStatus(string status)
    {
        var value = status.Trim();

        if (value.Length <= 80)
            return value;

        var lowered = value.ToLowerInvariant();

        if (lowered.Contains("account") && lowered.Contains("missing"))
            return "Missing account code";

        if (lowered.Contains("terms"))
            return "Terms";

        if (lowered.Contains("expected date") || lowered.Contains("expecteddate"))
            return "Expected date";

        if (lowered.Contains("already") && lowered.Contains("received"))
            return "Received";

        if (lowered.Contains("success"))
            return "Succeeded";

        if (lowered.Contains("error") || lowered.Contains("failed"))
            return "Error";

        return value[..77] + "...";
    }

    private static bool TryGetExpectedDateStatus(IDictionary<string, object> row, out string status)
    {
        status = string.Empty;

        if (!row.TryGetValue("ExpectedDate", out var expectedDateValue)
            || expectedDateValue is null
            || !DateTime.TryParse(expectedDateValue.ToString(), out var expectedDate))
        {
            return false;
        }

        status = expectedDate.Date < DateTime.Today
            ? "Expected date passed"
            : "Expected date ok";

        return true;
    }

    private bool IsStatusRed(IDictionary<string, object> row)
    {
        if (IsInvoiceRequestGrid())
            return GetInvoiceRequestIssueMessages(row).Count > 0;

        if (TryGetExpectedDateStatus(row, out var expectedDateStatus)
            && expectedDateStatus.Contains("passed", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var normalized = NormalizeStatus(GetStatusText(row));

        return normalized.Contains("missing", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("issue", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("failed", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("error", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("rejected", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("declined", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("deleted", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("passed", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("invalid", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("zero or negative", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("cannot be converted", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("no finance account", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("does not have a valid sage code", StringComparison.OrdinalIgnoreCase);
    }

    private bool IsStatusGreen(IDictionary<string, object> row)
    {
        if (IsInvoiceRequestGrid())
            return GetInvoiceRequestIssueMessages(row).Count == 0;

        var normalized = NormalizeStatus(GetStatusText(row));

        return normalized.Contains("ready", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("success", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("succeeded", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("approved", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("accepted", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("complete", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("ok", StringComparison.OrdinalIgnoreCase);
    }

    private bool IsStatusAmber(IDictionary<string, object> row)
    {
        var normalized = NormalizeStatus(GetStatusText(row));

        return normalized.Contains("pending", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("waiting", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("sent", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("submitted", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("consultant field is empty", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("note:", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("terms", StringComparison.OrdinalIgnoreCase);
    }

    private bool IsStatusBlue(IDictionary<string, object> row)
    {
        var normalized = NormalizeStatus(GetStatusText(row));

        return normalized.Contains("progress", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("processing", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("batched", StringComparison.OrdinalIgnoreCase)
            || normalized.Contains("batch", StringComparison.OrdinalIgnoreCase);
    }

    private bool IsStatusPurple(IDictionary<string, object> row)
    {
        return NormalizeStatus(GetStatusText(row)).Contains("received", StringComparison.OrdinalIgnoreCase);
    }

    private bool IsRowRetryable(IDictionary<string, object> row)
    {
        if (IsReceivedAlreadySubmitted(row))
            return false;

        return row.TryGetValue("CanRequeue", out var canRequeueObj)
            && bool.TryParse(canRequeueObj?.ToString(), out var canRequeue)
            && canRequeue;
    }
    private string GetStatusBadgeClass(IDictionary<string, object> row)
    {
        if (IsStatusRed(row))
            return "status-badge status-red";

        if (IsStatusGreen(row))
            return "status-badge status-green";

        if (IsStatusAmber(row))
            return "status-badge status-amber";

        if (IsStatusBlue(row))
            return "status-badge status-blue";

        if (IsStatusPurple(row))
            return "status-badge status-purple";

        return GetStatusBadgeClass(GetStatusText(row));
    }

    private static string GetStatusBadgeClass(string? status)
    {
        var normalized = NormalizeStatus(status ?? string.Empty);

        return normalized switch
        {
            "succeeded" or "success" or "approved" or "accepted" or "complete" or "completed" or "ready" or "ready for batching" or "expected date ok" => "status-badge status-green",
            "failedretryable" or "failed retryable" or "pending" or "waiting" or "sent" or "submitted" => "status-badge status-amber",
            "failednonretryable" or "failed non retryable" or "failed" or "error" or "rejected" or "declined" or "deleted" or "missing account code" or "batching issue" or "expected date passed" => "status-badge status-red",
            "inprogress" or "in progress" or "processing" or "batched" or "batch" => "status-badge status-blue",
            "received" => "status-badge status-purple",
            "draft" or "new" or "created" or "open" => "status-badge status-slate",
            _ => "status-badge status-slate"
        };
    }

    private string GetRowAccentClass(IDictionary<string, object> row)
    {
        if (IsStatusRed(row))
            return "row-accent-red";

        if (IsStatusGreen(row))
            return "row-accent-green";

        if (IsStatusAmber(row))
            return "row-accent-amber";

        if (IsStatusBlue(row))
            return "row-accent-blue";

        if (IsStatusPurple(row))
            return "row-accent-purple";

        return string.Empty;
    }

    private object? RenderCellValue(IDictionary<string, object> row, string columnName)
    {
        if (string.Equals(columnName, "CanRequeue", StringComparison.OrdinalIgnoreCase))
            return IsRowRetryable(row);

        if (IsReceivedAlreadySubmitted(row)
            && string.Equals(columnName, "LatestResponseStatus", StringComparison.OrdinalIgnoreCase))
        {
            return "Received";
        }

        return row.TryGetValue(columnName, out var value)
            ? value
            : null;
    }

    private static bool IsStatusColumn(string columnName)
    {
        return string.Equals(columnName, "Status", StringComparison.OrdinalIgnoreCase)
            || string.Equals(columnName, "StatusName", StringComparison.OrdinalIgnoreCase)
            || string.Equals(columnName, "StatusCode", StringComparison.OrdinalIgnoreCase)
            || string.Equals(columnName, "LatestResponseStatus", StringComparison.OrdinalIgnoreCase)
            || string.Equals(columnName, "InvoiceRequestStatus", StringComparison.OrdinalIgnoreCase)
            || string.Equals(columnName, "TransactionStatus", StringComparison.OrdinalIgnoreCase);
    }


    private string GetColumnTitle(GridViewColumnDefinition column)
    {
        if (string.Equals(column.Name, "LatestOutboxError", StringComparison.OrdinalIgnoreCase))
            return "Latest Response";

        return column.Title;
    }


    #endregion

    #region Legacy compatibility helpers

    public IEnumerable<ExpandoObject> GetSelectionForBatch()
    {
        return SelectedItems ?? new List<ExpandoObject>();
    }

    public void HideUnselected(List<string> guidsToHide)
    {
        if (guidsToHide is null || guidsToHide.Count == 0)
            return;

        var hidden = new HashSet<string>(guidsToHide, StringComparer.OrdinalIgnoreCase);

        AllRows = AllRows
            .Where(row =>
            {
                var dict = (IDictionary<string, object>)row;
                return !dict.TryGetValue("Guid", out var guidObj)
                    || guidObj is null
                    || !hidden.Contains(guidObj.ToString() ?? string.Empty);
            })
            .ToList();

        ApplyClientSideView();
        StateHasChanged();
    }

    protected async Task RefreshMe()
    {
        await LoadDataAsync();
    }

    protected async Task reloadGridData()
    {
        await RefreshMe();
    }

    protected async Task CloseWindow()
    {
        try
        {
            if (_detailPageParameters.TryGetValue("ModalId", out var value) && value is string modalIdValue)
                modalService.UnregisterModal(modalIdValue);

            WindowIsVisible = false;
            _detailPageParameters.Clear();
            _detailPageType = null;
            _detailPageComponentKey = Guid.NewGuid().ToString("N");

            await GridUpdated();
            await RefreshMe();

            if (OnActionCompleted.HasDelegate)
                await OnActionCompleted.InvokeAsync();

            StateHasChanged();
        }
        catch (Exception ex)
        {
            ex.Data["PageMethod"] = "DynamicBatchGridView/CloseWindow()";
            ex.Data["MessageType"] = ShowMessageType.Error;
            await OnError(ex);
        }
    }

    protected async Task GridUpdated()
    {
        try
        {
            var modal = modalService.RetrieveModalByEntityTypeGuid(ParentDataObjectReference.EntityTypeGuid);
            if (modal.HasValue && ParentDataObjectReferenceChanged.HasDelegate)
                await ParentDataObjectReferenceChanged.InvokeAsync(modal.Value.DataObjectReference);

            await RefreshMe();
            StateHasChanged();
        }
        catch (Exception ex)
        {
            ex.Data["PageMethod"] = "DynamicBatchGridView/GridUpdated()";
            ex.Data["MessageType"] = ShowMessageType.Error;
            await OnError(ex);
        }
    }

    private void WindowVisibleChangedHandler(bool currVisible)
    {
        if (WindowIsClosable)
            WindowIsVisible = currVisible;
    }

    //private bool CanInvoiceRequestRecordsBeMerged(IEnumerable<ExpandoObject> selectedItemsInList)
    //{
    //    InvoiceReqsToMerge.Clear();

    //    if (ViewDefinition?.Code != "INVOICEREQUESTS")
    //        return false;

    //    var selectedList = selectedItemsInList?.ToList() ?? new List<ExpandoObject>();
    //    if (selectedList.Count <= 1)
    //        return false;

    //    var jobNumbers = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    //    var financeAccounts = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

    //    foreach (var selected in selectedList)
    //    {
    //        var dict = selected as IDictionary<string, object>;
    //        if (dict is null)
    //            continue;

    //        if (dict.TryGetValue("Number", out var number) && !string.IsNullOrWhiteSpace(number?.ToString()))
    //            jobNumbers.Add(number.ToString()!);

    //        if (dict.TryGetValue("FinanceAccountID", out var account) && !string.IsNullOrWhiteSpace(account?.ToString()))
    //            financeAccounts.Add(account.ToString()!);

    //        if (dict.TryGetValue("Guid", out var guidValue)
    //            && Guid.TryParse(guidValue?.ToString(), out var guid)
    //            && guid != Guid.Empty
    //            && !InvoiceReqsToMerge.Contains(guid))
    //        {
    //            InvoiceReqsToMerge.Add(guid);
    //        }
    //    }

    //    return jobNumbers.Count == 1 && financeAccounts.Count == 1 && InvoiceReqsToMerge.Count > 1;
    //}

    private static class EntityPropertiesToCopy
    {
        public const string JobID = "dddabd42-c753-48fa-800f-a73c88fcadcd";
        public const string Notes = "f22eb049-a999-4485-9838-751b3f577293";
        public const string Consultant = "8c1f4236-36a8-44ed-af70-c43f56840943";
    }

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
#endregion