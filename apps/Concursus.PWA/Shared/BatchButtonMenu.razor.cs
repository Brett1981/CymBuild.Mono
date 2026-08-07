using Concursus.API.Client;
using Concursus.API.Core;
using Concursus.Common.Shared.Models.Finance;
using Concursus.PWA.Classes;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using System.Dynamic;
using System.Text;
using static Concursus.PWA.Shared.MessageDisplay;

namespace Concursus.PWA.Shared;

public partial class BatchButtonMenu
{
    protected FormHelper? formHelper;

    private IDictionary<string, object> DetailPageParameters = new Dictionary<string, object>();

    public GridActionMenuItem? ClickedItem { get; set; }
    public List<GridActionMenuItem>? MenuItems { get; set; }
[Parameter] public EventCallback<Exception> OnError { get; set; }

    private GridViewDefinition _value;

    [Parameter] public GridViewDefinition GridRef { get; set; }

    [Parameter] public object? GridReference { get; set; }
    [Parameter] public EventCallback OnRefreshRequested { get; set; }

    [Parameter] public EventCallback<GridViewDefinition> GridRefChanged { get; set; }
    [Parameter] public EventCallback<GridActionMenuItem> PerformGridAction { get; set; }
    [Parameter] public string EntityTypeGuid { get; set; } = Guid.Empty.ToString();

    [Parameter] public IEnumerable<ExpandoObject> SelectedItems { get; set; }
    [Parameter] public EventCallback<IEnumerable<ExpandoObject>> SelectedItemsChanged { get; set; }

    private string? GridCodeSelection { get; set; }
    private string HeaderCssIcon { get; set; } = "";
    private string HeaderText { get; set; } = "";
    private string? LoadPageUrl { get; set; }
    private bool ModalWindowIsVisible { get; set; } = false;
    private bool _batchModalIsMaximized;
    private bool _invoicePreviewModalIsMaximized;

    private string GeneralBatchModalCss => _batchModalIsMaximized
        ? "batch-native-modal-card is-maximized"
        : "batch-native-modal-card";

    private string InvoicePreviewModalCss => _invoicePreviewModalIsMaximized
        ? "batch-native-modal-card batch-invoice-preview-modal is-maximized"
        : "batch-native-modal-card batch-invoice-preview-modal";
    private bool windowIsClosable { get; set; } = true;
    private string? WindowTitle { get; set; }

    private bool _batchActionMenuOpen;

    private GridActionMenuItem? _batchActionMenuRootItem;

    private bool _isBusy = false;

    // Invoice preview modal state
    private bool _showInvoicePreviewModal = false;
    private readonly List<Guid> _previewTransactionGuids = new();
    private readonly List<InvoicePrintTemplate.InvoicePrintModel> _invoicePreviewModels = new();
    private int _currentInvoicePreviewIndex = 0;

    private Guid CurrentPreviewTransactionGuid =>
        _currentInvoicePreviewIndex >= 0 && _currentInvoicePreviewIndex < _previewTransactionGuids.Count
            ? _previewTransactionGuids[_currentInvoicePreviewIndex]
            : Guid.Empty;

    private InvoicePrintTemplate.InvoicePrintModel? _currentInvoicePreviewModel =>
        _currentInvoicePreviewIndex >= 0 && _currentInvoicePreviewIndex < _invoicePreviewModels.Count
            ? _invoicePreviewModels[_currentInvoicePreviewIndex]
            : null;
    private static IEnumerable<GridActionMenuItem> GetVisibleBatchMenuItems(IEnumerable<GridActionMenuItem>? items)
    {
        if (items is null)
        {
            yield break;
        }

        foreach (var item in items)
        {
            if (item is null)
            {
                continue;
            }

            if (!string.IsNullOrWhiteSpace(item.Text) || HasChildBatchMenuItems(item))
            {
                yield return item;
            }
        }
    }

    private static bool HasChildBatchMenuItems(GridActionMenuItem? item)
    {
        return item?.Items is not null && GetVisibleBatchMenuItems(item.Items).Any();
    }

    private void ToggleBatchActionMenu(GridActionMenuItem item)
    {
        if (item is null)
        {
            return;
        }

        if (!HasChildBatchMenuItems(item))
        {
            _ = OnNativeBatchActionMenuItemClicked(item);
            return;
        }

        if (_batchActionMenuOpen && ReferenceEquals(_batchActionMenuRootItem, item))
        {
            CloseBatchActionMenu();
            return;
        }

        _batchActionMenuRootItem = item;
        _batchActionMenuOpen = true;
        StateHasChanged();
    }

    private void CloseBatchActionMenu()
    {
        _batchActionMenuOpen = false;
        _batchActionMenuRootItem = null;
        StateHasChanged();
    }

    private async Task OnNativeBatchActionMenuItemClicked(GridActionMenuItem item)
    {
        if (item is null || string.IsNullOrWhiteSpace(item.Text))
        {
            return;
        }

        CloseBatchActionMenu();

        var continuation = await OnClickHandler(item);
        if (continuation is not null)
        {
            await continuation;
        }
    }
    private Task ShowMessageAsync(string message, ShowMessageType messageType, string pageMethod = "BatchButtonMenu")
    {
        var ex = new Exception(message);
        ex.Data.Add("MessageType", messageType);
        ex.Data.Add("AdditionalInfo", message);
        ex.Data.Add("PageMethod", pageMethod);

        return OnError.InvokeAsync(ex);
    }

    private void ToggleBatchNativeModalMaximized()
    {
        _batchModalIsMaximized = !_batchModalIsMaximized;
        StateHasChanged();
    }

    private void ToggleInvoicePreviewNativeModalMaximized()
    {
        _invoicePreviewModalIsMaximized = !_invoicePreviewModalIsMaximized;
        StateHasChanged();
    }
    protected void CloseWindowCross()
    {
        ModalWindowIsVisible = false;
        _batchModalIsMaximized = false;
        ResetInvoicePreviewState();
    }

    protected async Task<Task> OnClickHandler(GridActionMenuItem item)
    {
        try
        {
            formHelper = new FormHelper(coreClient, EntityTypeGuid, userService);

            if (item.Text == "Create Invoice")
            {
                try
                {
                    var infoMessage = PWAFunctions.GetMessageDisplayFromGridViewAction(item, new Exception(), ShowMessageType.Information);
                    await OnError.InvokeAsync(infoMessage);

                    item.FormHelper = formHelper;
                    await PerformGridAction.InvokeAsync(item);
                }
                catch (Exception ex)
                {
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "An error occurred while trying to create an invoice.");
                    ex.Data.Add("PageMethod", "BatchButtonMenu/OnClickHandler(Create Invoice)");
                    _ = OnError.InvokeAsync(ex);
                }
            }
            else if (item.Text == "Invoice Request ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Create Invoice (Batch)")
            {
                var infoMessage = PWAFunctions.GetMessageDisplayFromGridViewAction(item, new Exception(), ShowMessageType.Information);
                await OnError.InvokeAsync(infoMessage);

                item.FormHelper = formHelper;
                await PerformGridAction.InvokeAsync(item);
            }
            else if (item.Text == "Batch Delete")
            {
                var infoMessage = PWAFunctions.GetMessageDisplayFromGridViewAction(item, new Exception(), ShowMessageType.Information);
                await OnError.InvokeAsync(infoMessage);

                item.FormHelper = formHelper;
                await PerformGridAction.InvokeAsync(item);
            }
            else if (item.Text == "Approve Invoice(s)")
            {
                bool isConfirmed = await JSRuntime.InvokeAsync<bool>("confirm", "Are you sure? This will prevent the transaction from being modified.");
                if (isConfirmed)
                {
                    var infoMessage = PWAFunctions.GetMessageDisplayFromGridViewAction(item, new Exception(), ShowMessageType.Information);
                    await OnError.InvokeAsync(infoMessage);

                    item.FormHelper = formHelper;
                    await PerformGridAction.InvokeAsync(item);
                }
            }
            else if (item.Text == "Quote Assignment")
            {
                if (SelectedItems == null || !SelectedItems.Any())
                {
                    await JSRuntime.InvokeVoidAsync("alert", "No records selected for update!");
                }
                else
                {
                    DetailPageParameters.Add("OnRefreshRequested", OnRefreshRequested);
                    DetailPageParameters.Add("SelectedItems", SelectedItems);
                    ModalWindowIsVisible = true;
                }
            }
            else if (item.Text == "Preview Invoice/s")
            {
                await OpenInvoicePreviewModalAsync();
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to create an invoice.");
            ex.Data.Add("PageMethod", "BatchButtonMenu/OnClickHandler()");
            _ = OnError.InvokeAsync(ex);
            throw;
        }

        return Task.CompletedTask;
    }
    private static bool IsInvoiceTransactionRow(IDictionary<string, object> row)
    {
        static string GetValue(IDictionary<string, object> values, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (values.TryGetValue(key, out var value) && value is not null)
                {
                    return value.ToString()?.Trim() ?? string.Empty;
                }
            }

            return string.Empty;
        }

        var transactionType = GetValue(
            row,
            "TransactionType",
            "Transaction Type",
            "TransactionTypeName",
            "Type",
            "TypeName");

        return transactionType.Equals("Invoice", StringComparison.OrdinalIgnoreCase);
    }
    private async Task OpenInvoicePreviewModalAsync()
    {
        try
        {
            if (SelectedItems == null || !SelectedItems.Any())
            {
                await JSRuntime.InvokeVoidAsync("alert", "No records selected for preview!");
                return;
            }

            formHelper ??= new FormHelper(coreClient, EntityTypeGuid, userService);

            _isBusy = true;
            ResetInvoicePreviewState();

            var selectedTransactionGuids = new List<Guid>();

            foreach (var selectedItem in SelectedItems)
            {
                if (selectedItem is not IDictionary<string, object> dict)
                {
                    continue;
                }

                var transactionType = GetRowStringValue(
                    dict,
                    "TransactionType",
                    "Transaction Type",
                    "Type",
                    "TypeName",
                    "TransactionTypeName");

                if (!transactionType.Equals("Invoice", StringComparison.OrdinalIgnoreCase))
                {
                    await ShowMessageAsync(
                        "Invoice preview is only available for Invoice transactions.",
                        MessageDisplay.ShowMessageType.Information,
                        "BatchButtonMenu/OpenInvoicePreviewModalAsync");

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
                    await ShowMessageAsync(
                        "Invoice preview could not be opened because the selected invoice transaction guid could not be resolved.",
                        MessageDisplay.ShowMessageType.Error,
                        "BatchButtonMenu/OpenInvoicePreviewModalAsync");

                    return;
                }

                selectedTransactionGuids.Add(transactionGuid);
            }

            selectedTransactionGuids = selectedTransactionGuids
                .Distinct()
                .ToList();

            if (selectedTransactionGuids.Count == 0)
            {
                await ShowMessageAsync(
                    "Invoice preview could not be opened because no valid invoice transactions were found in the selected rows.",
                    MessageDisplay.ShowMessageType.Error,
                    "BatchButtonMenu/OpenInvoicePreviewModalAsync");

                return;
            }

            foreach (var transactionGuid in selectedTransactionGuids)
            {
                var previewModel = await formHelper.TransactionInvoicePrintModelGetAsync(
                    transactionGuid,
                    TransactionInvoiceRenderMode.Preview);

                if (previewModel is null)
                {
                    continue;
                }

                _previewTransactionGuids.Add(transactionGuid);
                _invoicePreviewModels.Add(MapToInvoicePrintTemplateModel(previewModel));
            }

            if (_invoicePreviewModels.Count == 0)
            {
                await ShowMessageAsync(
                    "Invoice preview could not be loaded for the selected invoice transaction(s).",
                    MessageDisplay.ShowMessageType.Error,
                    "BatchButtonMenu/OpenInvoicePreviewModalAsync");

                return;
            }

            _currentInvoicePreviewIndex = 0;

            WindowTitle = "Invoice Preview";
            windowIsClosable = true;
            _showInvoicePreviewModal = true;
            ModalWindowIsVisible = false;
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "An error occurred while trying to open the invoice preview.";
            ex.Data["PageMethod"] = "BatchButtonMenu/OpenInvoicePreviewModalAsync";
            await OnError.InvokeAsync(ex);
        }
        finally
        {
            _isBusy = false;
            StateHasChanged();
        }
    }

    private static string GetRowStringValue(
    IDictionary<string, object> row,
    params string[] keys)
    {
        foreach (var key in keys)
        {
            if (row.TryGetValue(key, out var value) && value is not null)
            {
                return value.ToString()?.Trim() ?? string.Empty;
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
            if (row.TryGetValue(key, out var value) &&
                value is not null &&
                Guid.TryParse(value.ToString(), out var guid))
            {
                return guid;
            }
        }

        return Guid.Empty;
    }

    private void ShowPreviousInvoicePreview()
    {
        if (_currentInvoicePreviewIndex <= 0)
        {
            return;
        }

        _currentInvoicePreviewIndex--;
        StateHasChanged();
    }

    private void ShowNextInvoicePreview()
    {
        if (_currentInvoicePreviewIndex >= _invoicePreviewModels.Count - 1)
        {
            return;
        }

        _currentInvoicePreviewIndex++;
        StateHasChanged();
    }
    private static InvoicePrintTemplate.InvoicePrintModel MapToInvoicePrintTemplateModel(
    Concursus.Common.Shared.Models.Finance.TransactionInvoicePrintModel source)
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


    private Task OnInvoicePreviewVisibleChanged(bool visible)
    {
        _showInvoicePreviewModal = visible;

        if (!visible)
        {
            ResetInvoicePreviewState();
        }

        StateHasChanged();
        return Task.CompletedTask;
    }

    private void CloseInvoicePreviewWindow()
    {
        ResetInvoicePreviewState();
    }

    private void ResetInvoicePreviewState()
    {
        _showInvoicePreviewModal = false;
        _invoicePreviewModalIsMaximized = false;
        _currentInvoicePreviewIndex = 0;
        _previewTransactionGuids.Clear();
        _invoicePreviewModels.Clear();
    }
    protected override void OnParametersSet()
    {
        reloadButton();
        base.OnParametersSet();
    }

    private async Task ExportCurrentInvoiceToPdfAsync()
    {
        try
        {
            if (_currentInvoicePreviewModel is null)
            {
                await ShowMessageAsync(
                    "No invoice preview is currently available to export.",
                    MessageDisplay.ShowMessageType.Error,
                    "BatchButtonMenu/ExportCurrentInvoiceToPdfAsync");

                return;
            }

            _isBusy = true;

            var fileName = _currentInvoicePreviewModel.InvoiceNumber;
            if (string.IsNullOrWhiteSpace(fileName))
            {
                fileName = $"invoice_{DateTime.Now:yyyyMMdd_HHmmss}";
            }
            else
            {
                fileName = $"invoice_{SanitizeFileName(fileName)}";
            }

            await JSRuntime.InvokeVoidAsync(
                "exportToPdf",
                "invoice-preview-current-export",
                $"{fileName}.pdf");
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "An error occurred while exporting the current invoice to PDF.";
            ex.Data["PageMethod"] = "BatchButtonMenu/ExportCurrentInvoiceToPdfAsync";
            await OnError.InvokeAsync(ex);
        }
        finally
        {
            _isBusy = false;
            StateHasChanged();
        }
    }

    private async Task ExportAllInvoicesToPdfAsync()
    {
        try
        {
            if (_invoicePreviewModels.Count == 0)
            {
                await ShowMessageAsync(
                    "No invoice previews are currently available to export.",
                    MessageDisplay.ShowMessageType.Error,
                    "BatchButtonMenu/ExportAllInvoicesToPdfAsync");

                return;
            }

            if (_invoicePreviewModels.Count == 1)
            {
                await ExportCurrentInvoiceToPdfAsync();
                return;
            }

            _isBusy = true;
            StateHasChanged();

            // Let Blazor render the hidden export containers before export begins.
            await Task.Delay(150);

            for (var i = 0; i < _invoicePreviewModels.Count; i++)
            {
                var previewModel = _invoicePreviewModels[i];
                var elementId = GetInvoiceExportElementId(i);

                var invoiceNumber = previewModel.InvoiceNumber;
                var safeInvoiceNumber = string.IsNullOrWhiteSpace(invoiceNumber)
                    ? $"invoice_{i + 1}_{DateTime.Now:yyyyMMdd_HHmmss}"
                    : $"invoice_{SanitizeFileName(invoiceNumber)}";

                await JSRuntime.InvokeVoidAsync(
                    "exportToPdf",
                    elementId,
                    $"{safeInvoiceNumber}.pdf");

                // Small delay helps the browser complete each download cleanly.
                await Task.Delay(250);
            }
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "An error occurred while exporting all invoice previews to PDF.";
            ex.Data["PageMethod"] = "BatchButtonMenu/ExportAllInvoicesToPdfAsync";
            await OnError.InvokeAsync(ex);
        }
        finally
        {
            _isBusy = false;
            StateHasChanged();
        }
    }

    private static string GetInvoiceExportElementId(int index)
    {
        return $"invoice-preview-export-{index}";
    }

    private static string SanitizeFileName(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return "invoice";
        }

        var invalidChars = Path.GetInvalidFileNameChars();
        var builder = new StringBuilder(value.Length);

        foreach (var ch in value)
        {
            builder.Append(invalidChars.Contains(ch) ? '_' : ch);
        }

        return builder.ToString().Trim();
    }

    public async void reloadButton()
    {
        try
        {
            MenuItems = new List<GridActionMenuItem>
            {
                new()
                {
                    Text = "Actions",
                    Items = new List<GridActionMenuItem>()
                }
            };

            if (MenuItems != null && MenuItems[0].Items == null)
                MenuItems[0].Items = new List<GridActionMenuItem>();

            {
                if (GridRef != null && GridRef?.GridViewActions?.Count != 0)
                    foreach (var item in GridRef?.GridViewActions?.OrderBy(o => o.Title))
                    {
                        string icon = "";
                        if (item.Title == "Create Invoice")
                            icon = "bi bi-currency-dollar";
                        else if (item.Title == "Invoice Request ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Create Invoice (Batch)")
                            icon = "bi bi-receipt";
                        else if (item.Title == "Batch Delete")
                            icon = "bi bi-trash";
                        else if (item.Title == "Approve Invoice(s)")
                            icon = "bi bi-link-45deg";

                        MenuItems?[0].Items.Add(new GridActionMenuItem()
                        {
                            Text = item.Title,
                            Query = item.Statement,
                            Icon = icon
                        });
                    }

                if (GridRef?.Code == "AUTHASSIGN")
                    MenuItems?[0].Items.Add(new GridActionMenuItem()
                    {
                        Text = "Quote Assignment",
                        Icon = "bi bi-person-check",
                        Query = ""
                    });

                if (GridRef?.Code == "BATCHEDTRANSACTIONS")
                    MenuItems?[0].Items.Add(new GridActionMenuItem()
                    {
                        Text = "Preview Invoice/s",
                        Icon = "bi bi-eye",
                        Query = ""
                    });

                StateHasChanged();
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to reload the button.");
            ex.Data.Add("PageMethod", "BatchButtonMenu/OnInitialized()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    private string GetParentGuid()
    {
        try
        {
            if (DetailPageParameters.TryGetValue("RecordGuid", out var parentGuid))
                return parentGuid?.ToString();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while trying to get the parent guid.");
            ex.Data.Add("PageMethod", "ButtonMenu/GetParentGuid()");
            _ = OnError.InvokeAsync(ex);
        }

        return Guid.Empty.ToString();
    }
}