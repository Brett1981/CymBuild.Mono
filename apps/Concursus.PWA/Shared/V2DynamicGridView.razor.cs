using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using Concursus.PWA.Shared.V2Grid;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using System.Collections;
using System.Dynamic;
using static Concursus.PWA.Shared.MessageDisplay;

namespace Concursus.PWA.Shared;

public partial class V2DynamicGridView : ComponentBase
{
    [Parameter] public bool FullGrid { get; set; }
    [Parameter] public string GridCode { get; set; } = "";
    [Parameter] public EventCallback OnActionCompleted { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public EventCallback<string> ParentGuidChanged { get; set; }
    [Parameter] public GridViewDefinition? ViewDefinition { get; set; }
    [Parameter] public bool DoubleClickDisabled { get; set; } = false;
    [Parameter] public bool Disabled { get; set; } = false;
    [Parameter] public EventCallback ResyncDataObject { get; set; }
    [Parameter] public int ParentRowStatus { get; set; } = -1;

    private MessageDisplay _messageDisplay = new();
    protected string ErrorMessage { get; set; } = "";
    protected ShowMessageType MessageType { get; set; } = ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";

    private bool _isLoading;
    private string? _statusText;

    private readonly List<ExpandoObject> _rows = new();
    private IEnumerable<ExpandoObject>? CurrentGridItems { get; set; }

    private int _page = 1;
    private int _pageSize = 50;
    private int _totalRows;
    private int _totalPages = 1;

    private string? _sortColumn;
    private bool _sortDescending;

    // V2 state (NO Telerik)
    private readonly V2GridQueryState _query = new();

    // Modal state
    private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();
    private string modalId = Guid.Empty.ToString();
    private bool WindowIsVisible { get; set; }
    private string? WindowTitle { get; set; }

    // Batch modal
    private bool BatchGridVisible { get; set; } = false;

    protected override async Task OnParametersSetAsync()
    {
        if (ViewDefinition != null)
        {
            // Apply default sort (matches legacy fields)
            if (!string.IsNullOrWhiteSpace(ViewDefinition.DefaultSortColumnName) && _query.Sort == null)
            {
                _sortColumn ??= ViewDefinition?.DefaultSortColumnName;
                _sortDescending = ViewDefinition?.IsDefaultSortDescending ?? false;

                _query.ToggleSort(ViewDefinition.DefaultSortColumnName);

                // If default is descending, toggle once
                if (ViewDefinition.IsDefaultSortDescending)
                    _query.ToggleSort(ViewDefinition.DefaultSortColumnName);
            }

            await LoadPageAsync();
        }

        await base.OnParametersSetAsync();
    }



    public async Task RefreshGrid(bool resetToFirstPage = false)
    {
        if (resetToFirstPage) _page = 1;
        await LoadPageAsync();
    }

    private async Task LoadPageAsync()
    {
        if (ViewDefinition == null) return;

        try
        {
            _isLoading = true;
            _statusText = null;

            await EnsureCorrectParentGuid();

            var parsedParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString();
            if (parsedParentGuid == Guid.Empty.ToString() && !FullGrid)
            {
                _rows.Clear();
                _totalRows = 0;
                _totalPages = 1;
                return;
            }

            var req = new GridDataListRequest();

            GridRequestReflectionSetter.SetString(req, nameof(GridDataListRequest.GridCode), GridCode);
            GridRequestReflectionSetter.SetString(req, nameof(GridDataListRequest.GridViewCode), ViewDefinition.Code);
            GridRequestReflectionSetter.SetString(req, nameof(GridDataListRequest.ParentGuid), parsedParentGuid);
            GridRequestReflectionSetter.SetInt(req, nameof(GridDataListRequest.Page), _page);
            GridRequestReflectionSetter.SetInt(req, nameof(GridDataListRequest.PageSize), _pageSize);

            // Server-side Filters + Sorts (NO Telerik)
            var filter = V2GridRequestBuilder.BuildCompositeFilter(_query);
            var sort = V2GridRequestBuilder.BuildSortList(_query);

            GridRequestReflectionSetter.TrySetSortAndFilter(req, filter, sort);

            req.Sort.Clear();

            if (!string.IsNullOrWhiteSpace(_sortColumn))
            {
                req.Sort.Add(new DataSort
                {
                    ColumnName = _sortColumn,
                    Direction = _sortDescending ? "Descending" : "Ascending"
                });
            }

            var reply = await coreClient.GridDataListAsync(req);

            _rows.Clear();

            foreach (var r in reply.DataTable)
            {
                dynamic dataObj = new ExpandoObject();
                var dict = (IDictionary<string, object>)dataObj;

                foreach (var c in r.Columns)
                {
                    dict[c.Name] = FormatGridColumnValue(c.Name, c.Value);
                }

                _rows.Add(dataObj);
            }

            _totalRows = reply.TotalRows;
            _totalPages = Math.Max(1, (int)Math.Ceiling(_totalRows / (double)_pageSize));

            CurrentGridItems = _rows;

            if (_query.Sort != null)
            {
                _statusText = $"Sort: {_query.Sort.ColumnName} {(_query.Sort.Descending ? "DESC" : "ASC")}";
            }
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = ShowMessageType.Error;
            ex.Data["PageMethod"] = "V2DynamicGridView/LoadPageAsync()";
            await OnError(ex);
        }
        finally
        {
            _isLoading = false;
            StateHasChanged();
        }
    }

    private async Task PrevPage()
    {
        if (_page <= 1) return;
        _page--;
        await LoadPageAsync();
    }

    private async Task NextPage()
    {
        if (_page >= _totalPages) return;
        _page++;
        await LoadPageAsync();
    }

    private async Task OnPageInputChanged(ChangeEventArgs _)
    {
        if (_page < 1) _page = 1;
        if (_page > _totalPages) _page = _totalPages;
        await LoadPageAsync();
    }

    private async Task OnPageSizeChanged(ChangeEventArgs e)
    {
        if (e?.Value?.ToString() is string s && int.TryParse(s, out var ps) && ps > 0)
            _pageSize = ps;

        _page = 1;
        await LoadPageAsync();
    }

    private async Task ToggleSort(string columnName)
    {
        if (string.Equals(_sortColumn, columnName, StringComparison.OrdinalIgnoreCase))
            _sortDescending = !_sortDescending;
        else
        {
            _sortColumn = columnName;
            _sortDescending = false;
        }

        _statusText = $"Sort: {_sortColumn} {(_sortDescending ? "DESC" : "ASC")}";
        await LoadPageAsync();
    }

    private string GetFilterValue(string columnName) => _query.GetColumnFilterValue(columnName);

    private async Task OnFilterChanged(string columnName, ChangeEventArgs e)
    {
        await OnFilterChanged(columnName, e?.Value?.ToString());
    }

    private async Task OnFilterChanged(string columnName, string? rawValue)
    {
        var raw = rawValue ?? string.Empty;

        if (string.IsNullOrWhiteSpace(raw))
        {
            _query.SetColumnFilter(columnName, null);
        }
        else
        {
            _query.SetColumnFilter(columnName, new V2GridFilter
            {
                ColumnName = columnName,
                Operator = V2GridFilterOperator.Contains,
                Value = raw
            });
        }

        _page = 1;
        await LoadPageAsync();
    }

    private void OnRowDoubleClick(ExpandoObject row)
    {
        // keep your existing implementation (unchanged)
        // (your uploaded file already contains it; leave as-is)
        try
        {
            if (DoubleClickDisabled) return;
            if (ViewDefinition == null) return;
            if (string.IsNullOrWhiteSpace(ViewDefinition.DetailPageUri)) return;

            var dict = (IDictionary<string, object>)row;

            if (!dict.TryGetValue("Guid", out var guidObj)) return;

            var rowGuid = guidObj?.ToString() ?? Guid.Empty.ToString();
            if (rowGuid == Guid.Empty.ToString()) return;

            var isParentDataObjectReferenceDifferent =
                ParentDataObjectReference.EntityTypeGuid.ToString() != ViewDefinition.EntityTypeGuid;

            var (parentDataObjectReference, serializedParentDataObjectReference) =
                PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, rowGuid, ViewDefinition.EntityTypeGuid);

            if (ViewDefinition.IsDetailWindowed)
            {
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

                modalService.RegisterModal(modalId, parentDataObjectReference);

                WindowTitle = ViewDefinition.Name;
                WindowIsVisible = true;

                InteractionTracker.Log(NavManager.Uri, $"User Double Clicked Row - '{ViewDefinition.Name}' Opened windowed detail.");
            }
            else
            {
                var guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(rowGuid).ToString();
                var encodedParentReference = serializedParentDataObjectReference;

                var currentUri = NavManager.Uri ?? string.Empty;
                var encodedReturnUrl = System.Web.HttpUtility.UrlEncode(currentUri);

                string url;
                if (ViewDefinition.DetailPageUri == "DynamicEdit")
                {
                    var entityTypeGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString();

                    url = $"{ViewDefinition.DetailPageUri}/" +
                          $"{entityTypeGuid}/" +
                          $"{parentDataObjectReference.DataObjectGuid}/" +
                          $"{encodedParentReference}/" +
                          $"{encodedReturnUrl}";
                }
                else
                {
                    url = $"{ViewDefinition.DetailPageUri}/" +
                          $"{guid}/" +
                          $"{encodedParentReference}/" +
                          $"{encodedReturnUrl}";
                }

                if (isParentDataObjectReferenceDifferent)
                {
                    var navigateToDetailPage = "/" + ViewDefinition.DetailPageUri + "/";
                    var current = NavManager.Uri ?? string.Empty;

                    if (current.Contains(navigateToDetailPage, StringComparison.OrdinalIgnoreCase))
                        NavManager.NavigateTo(url, forceLoad: true);
                    else
                        NavManager.NavigateTo(url, forceLoad: false);
                }
                else
                {
                    NavManager.NavigateTo(url, forceLoad: true);
                }

                InteractionTracker.Log(NavManager.Uri, $"User Double Clicked Row - '{ViewDefinition.Name}' Navigated to detail.");
            }

            var formHelper = new FormHelper(coreClient, sageIntegrationService, Guid.Empty.ToString(), userService);
            _ = formHelper.LogUsageAsync(
                PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(userService.Guid),
                PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ViewDefinition.EntityTypeGuid).ToString());
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "An error occurred while handling row double-click in V2DynamicGridView.";
            ex.Data["PageMethod"] = "V2DynamicGridView/OnRowDoubleClick()";
            _ = OnError(ex);
        }
    }

    protected async Task AddNew()
    {
        // keep your existing AddNew implementation (unchanged)
        // (your uploaded file already contains it; leave as-is)
        // ...
    }

    protected async Task CloseWindow()
    {
        try
        {
            if (_detailPageParameters.TryGetValue("ModalId", out var value) && value is string mid)
            {
                modalService.UnregisterModal(mid);
            }

            WindowIsVisible = false;

            await LoadPageAsync();

            if (ResyncDataObject.HasDelegate)
                await ResyncDataObject.InvokeAsync();

            await OnActionCompleted.InvokeAsync();
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "An error occurred while closing the modal in V2DynamicGridView.";
            ex.Data["PageMethod"] = "V2DynamicGridView/CloseWindow()";
            await OnError(ex);
        }
    }

    protected async Task GridUpdated()
    {
        try
        {
            await EnsureCorrectParentGuid();
            await LoadPageAsync();
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = ShowMessageType.Error;
            ex.Data["PageMethod"] = "V2DynamicGridView/GridUpdated()";
            await OnError(ex);
        }
    }

    private void OpenDynamicBatchGrid()
    {
        BatchGridVisible = true;
        InteractionTracker.Log(NavManager.Uri, $"Batch grid opened.");
        StateHasChanged();
    }

    private async void CloseBatchGridModal()
    {
        BatchGridVisible = false;
        await GridUpdated();
        StateHasChanged();
        InteractionTracker.Log(NavManager.Uri, $"Batch grid closed.");
    }

    private int VisibleColumnCount =>
        ViewDefinition?.Columns?.Count(c => !c.IsHidden) ?? 1;

    private static string GetCssWidth(string? width)
    {
        if (string.IsNullOrWhiteSpace(width)) return "240px";
        if (width.StartsWith("0")) return "240px";
        return width;
    }

    private static object GetValue(ExpandoObject expando, string propName)
    {
        if (expando is not ExpandoObject eo) return "";
        var dict = (IDictionary<string, object>)eo;

        return dict.TryGetValue(propName, out var val) ? val : "";
    }

    private object FormatGridColumnValue(string columnName, string value)
    {
        if (int.TryParse(value, out var intValue)) return intValue;

        if (decimal.TryParse(value, out var decimalValue))
            return decimalValue.ToString("F2");

        if (bool.TryParse(value, out var boolValue))
            return boolValue ? "Yes" : "No";

        if (Guid.TryParse(value, out var guidValue))
            return guidValue.ToString();

        if (DateTime.TryParse(value, out var dateTimeValue))
        {
            var local = UiFormattingHelper.NormalizeToLocal(dateTimeValue);
            bool isDateOnly = columnName.ToLower().EndsWith("date") && !columnName.ToLower().Contains("time");
            return UiFormattingHelper.FormatDateForUI(local, isDateOnly);
        }

        return value;
    }

    private async Task EnsureCorrectParentGuid()
    {
        if (ViewDefinition == null) return;

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

    // Error handling copied in spirit from legacy (no functionality removed)
    public async Task OnError(Exception error)
    {
        if (string.IsNullOrEmpty(error.Message)) return;

        ErrorMessage = error.Message;
        PageMethod = error.Data.Contains("PageMethod")
            ? error.Data["PageMethod"]?.ToString() ?? "Not Set"
            : "Not Set";

        MessageType = error.Data.Contains("MessageType")
            ? (ShowMessageType)(error.Data["MessageType"] ?? ShowMessageType.Information)
            : ShowMessageType.Error;

        var exceptionData = error.Data.Count > 0
            ? error.Data.Cast<DictionaryEntry>().ToDictionary(de => de.Key?.ToString() ?? "UnknownKey", de => de.Value!)
            : null;

        _messageDisplay.UpdateExceptionData(exceptionData);
        _messageDisplay.UpdateStackTrace(error.StackTrace ?? "No additional details available.");
        _messageDisplay.ShowError(true);

        // AI Error reporting preserved
        if (MessageType == ShowMessageType.Error)
        {
            try
            {
                var context = new
                {
                    ErrorMessage = error.Message,
                    PageMethod = PageMethod,
                    StackTrace = error.StackTrace ?? "No stack trace",
                    AdditionalInfo = error.Data.Contains("AdditionalInfo") ? error.Data["AdditionalInfo"]?.ToString() ?? "None" : "None"
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
                // swallow (same philosophy as legacy)
            }
        }

        StateHasChanged();
    }
}
