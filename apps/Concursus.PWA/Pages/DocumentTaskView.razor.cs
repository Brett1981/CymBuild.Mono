using Concursus.API.Client;
using Concursus.API.Client.Classes;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.PWA.Services;
using Concursus.PWA.Shared;
using Google.Protobuf.Collections;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using Newtonsoft.Json;
using System.Collections;
using System.Web;
using Telerik.Blazor.Components;
using Telerik.DataSource;
using Telerik.DataSource.Extensions;
using Telerik.Windows.Documents.Extensibility;
using Telerik.Windows.Documents.Flow.FormatProviders.Docx;
using Telerik.Windows.Documents.Flow.FormatProviders.Pdf;
using static Concursus.PWA.Shared.MessageDisplay;
using EntityProperty = Concursus.API.Core.EntityProperty;

namespace Concursus.PWA.Pages;

public partial class DocumentTaskView
{
    #region Protected Fields

    protected FormHelper? FormHelper;

    #endregion Protected Fields

    #region Private Fields

    private const int DefaultPage = 1;
    private MessageDisplay _messageDisplay = new();
    private bool IsListVisible = false;

    #endregion Private Fields

    #region Public Properties

    [Parameter] public List<EntityProperty> EntityProperties { get; set; } = new();

    [Parameter] public RepeatedField<MergeDocument>? ListOfMergeDocuments { get; set; }
    public IEnumerable<API.Client.MenuItem>? ListViewData { get; set; }
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public EventCallback ReSyncDataObject { get; set; } //[OE: CBLD-498]
    [Parameter] public string? SerializedDataObjectReference { get; set; }

    #endregion Public Properties

    #region Protected Properties

    protected string ErrorMessage { get; set; } = "";
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";

    #endregion Protected Properties

    #region Private Properties

    private List<API.Client.MenuItem>? Data { get; set; }
    private string FilterText { get; set; } = string.Empty;
    private bool LoaderVisible { get; set; }
    private bool ModalIsVisible { get; set; }
    private TelerikWindow? ModalWindow { get; set; }
    private string OutputType { get; set; } = "docx";
    private int Page { get; set; } = DefaultPage;
    private List<string>? SelectedItems { get; set; }
    private bool ShowOutPutType { get; set; } = false;
    private bool WindowIsClosable { get; set; } = true;
    private bool WindowIsVisible { get; set; }
    private string? WindowTitle { get; set; }

    #endregion Private Properties

    #region Public Methods

    public static void ConverDocxToPdf(string path, out string tempResultPath)
    {
        var docxProvider = new DocxFormatProvider();
        var pdfProvider = new PdfFormatProvider();

        var docBytes = File.ReadAllBytes(path);

        var document = docxProvider.Import(docBytes);
        var resultBytes = pdfProvider.Export(document);

        // Generate a temporary file name and path
        tempResultPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString() + ".pdf");

        // Write the PDF bytes to the temporary file
        File.WriteAllBytes(tempResultPath, resultBytes);
    }

    public async Task<MergeDocument> GenerateDocumentAsync(API.Client.MenuItem menuItem)
    {
        try
        {
            var mergeDocument = new MergeDocument
            {
                Name = menuItem.Text ?? "",
                FilenameTemplate = menuItem.FilenameTemplate ?? "",
                DriveId = menuItem.DriveId ?? "",
                DocumentId = menuItem.DocumentId ?? "",
                EntityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(menuItem.EntityTypeGuid).ToString(),
                LinkedEntityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(menuItem.LinkedEntityTypeGuid).ToString(),
                Guid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(menuItem.DocumentGuid).ToString(),
                RecordGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(RecordGuid).ToString(),
                AllowPDFOnly = menuItem.AllowPDFOnly,
                AllowExcelOutputOnly = menuItem.AllowExcelOutputOnly,
                ParentRecordGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(menuItem._Guid).ToString()
            };

            // Populate Items using AddRange
            var items = menuItem.MergeDocumentItems;
            mergeDocument.Items.AddRange(items);

            return mergeDocument;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while generating the document.");
            ex.Data.Add("PageMethod", "DocumentTaskView/GenerateDocumentAsync()");
            OnError(ex);
            return new MergeDocument();
        }
    }

    public async Task OnError(Exception error)
    {
        if (string.IsNullOrEmpty(error.Message))
        {
            Console.WriteLine("DocumentTaskView: Error message is empty. Aborting.");
            return;
        }

        ErrorMessage = error.Message;
        PageMethod = error.Data.Contains("PageMethod")
            ? error.Data["PageMethod"]?.ToString() ?? "Not Set"
            : "Not Set";
        Console.WriteLine($"DocumentTaskView: PageMethod = {PageMethod}");

        if (error.Data.Contains("MessageType"))
        {
            MessageType = (ShowMessageType)(error.Data["MessageType"] ?? ShowMessageType.Information);
        }
        else
        {
            MessageType = ShowMessageType.Error;
            Console.WriteLine("DocumentTaskView: MessageType not found in error.Data. Defaulted to Error.");
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

        Console.WriteLine("DocumentTaskView: MessageDisplay updated and error shown.");

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
                Console.WriteLine($"DocumentTaskView: UserInteractionLog = {description}");

                var result = await AiErrorReporter.ReportAsync(error, context);

                if (result != null && !string.IsNullOrEmpty(result.UiMessage))
                {
                    _messageDisplay.SetMessage(result.UiMessage, result.MessageType);
                    _messageDisplay.ShowError(true);
                }
                else
                {
                    Console.WriteLine("DocumentTaskView: AI Error Reporter returned no UI message.");
                }
            }
            catch (Exception aiEx)
            {
                Console.WriteLine($"DocumentTaskView: Exception in AI Error Reporter: {aiEx.Message}\n{aiEx.StackTrace}");
            }
        }

        StateHasChanged();
    }

    //public void OnError(Exception error)
    //{
    //    if (string.IsNullOrEmpty(error.Message)) return;

    // ErrorMessage = error.Message; PageMethod = (error.Data.Contains("PageMethod") ?
    // error.Data["PageMethod"]?.ToString() : "Not Set") ?? string.Empty;

    // if (error.Data.Contains("MessageType")) { MessageType =
    // (MessageDisplay.ShowMessageType)(error.Data["MessageType"] ??
    // MessageDisplay.ShowMessageType.Information); } else { MessageType =
    // MessageDisplay.ShowMessageType.Error; }

    // // Extract all exception data and pass it to the MessageDisplay component if (_messageDisplay
    // != null) { // Pass Exception Data using the new method _messageDisplay?.UpdateExceptionData(
    // error.Data.Count > 0 ? error.Data.Cast<DictionaryEntry>() .ToDictionary( de =>
    // de.Key?.ToString() ?? "UnknownKey", de => de.Value!) : null );

    // // Update the stack trace dynamically _messageDisplay?.UpdateStackTrace(error.StackTrace);

    // _messageDisplay?.ShowError(true); }

    // // Recover from error (if using a custom boundary) // customErrorBoundary.Recover();

    //    StateHasChanged();
    //}

    #endregion Public Methods

    #region Protected Methods

    protected async Task BtnGenerateDocuments(List<string>? menuItems)
    {
        // Set them in FixedExtensibilityManager
        JpegImageConverterBase customJpegImageConverter = new Helpers.JpegImageConverter();
        FixedExtensibilityManager.JpegImageConverter = customJpegImageConverter;
        var fileName = string.Empty;
        var fileUrl = string.Empty;
        SetLoaderVisibility(true);
        if (menuItems != null)
            foreach (var item in menuItems)
            {
                try
                {
                    var menuItem = ListViewData?.FirstOrDefault(x => x.DocumentId == item);
                    if (menuItem == null) continue;

                    var ex = new Exception($"Document {menuItem.Text} is attempting to be processed. Please Wait.... This may take some time");
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Information);
                    ex.Data.Add("AdditionalInfo", "Document is being processed. Please wait....");
                    ex.Data.Add("PageMethod", "DocumentTaskView/BtnGenerateDocuments()");
                    OnError(ex);

                    var response = await GenerateDocumentAsync(menuItem);
                    if (!string.IsNullOrEmpty(response.DocumentId))
                    {
                        if (FormHelper != null)
                        {
                            var results = await FormHelper.GetSharePointDocumentsAsync(response, OutputType);
                            if (!string.IsNullOrEmpty(results.ErrorReturned))
                            {
                                throw new Exception(results.ErrorReturned);
                            }

                            await ReSyncDataObject.InvokeAsync();  // OE: CBLD-498
                            fileName = results.DriveItem.Name;
                            fileUrl = Path.Combine((string)results.DownloadUrl, "files", fileName);
                            var destinationPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "GeneratedDocuments");

                            if (OutputType == "PDF")
                            {
                                await JS.InvokeVoidAsync("triggerFileDownload", fileName, fileUrl);
                                Console.WriteLine($"PDF generated and saved: {fileName}");
                            }
                            else if (OutputType == "Word")
                            {
                                await JS.InvokeVoidAsync("triggerFileDownload", fileName, fileUrl);
                                Console.WriteLine($"Word document generated and saved: {fileName}");
                            }
                            else if (OutputType == "Excel")
                            {
                                await JS.InvokeVoidAsync("triggerFileDownload", fileName, fileUrl);
                                Console.WriteLine($"Excel document generated and saved: {fileName}");
                            }
                        }

                        // Pass fileUrl and fileName to the AdditionalInfo field
                        var successMessage = $"Document {response.Name} has been generated successfully.";
                        var filePathInfo = $"File: {fileName} - Location: {fileUrl}";

                        ex = new Exception(successMessage);
                        ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Success);
                        ex.Data.Add("AdditionalInfo", filePathInfo);
                        ex.Data.Add("PageMethod", "DocumentTaskView/BtnGenerateDocuments()");
                        OnError(ex);

                        WindowIsVisible = true;
                        WindowTitle = "Generating Documents";
                        StateHasChanged();
                    }
                    else
                    {
                        WindowIsVisible = false;
                        WindowTitle = string.Empty;
                        var filePathInfo = $"File: {fileName} - Location: {fileUrl}";
                        ex = new Exception($"Document {response.Name} has been generated successfully.");
                        ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Success);
                        ex.Data.Add("AdditionalInfo", filePathInfo);
                        ex.Data.Add("PageMethod", "DocumentTaskView/BtnGenerateDocuments()");
                        OnError(ex);
                        StateHasChanged();
                    }
                }
                catch (Exception ex)
                {
                    var filePathInfo = $"File: {fileName} - Location: {fileUrl}";
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", filePathInfo);
                    ex.Data.Add("PageMethod", "DocumentTaskView/BtnGenerateDocuments()");
                    OnError(ex);
                }
            }
        // if (windowIsVisible) { // Callback to notify the parent about the window status await
        // CloseWindow.InvokeAsync(windowIsVisible); }
        SetLoaderVisibility(false);
    }

    private static async Task SavePdfToDestination(byte[] pdfBytes, string pdfFileName, string destinationPath)
    {
        try
        {
            if (!Directory.Exists(destinationPath))
            {
                Directory.CreateDirectory(destinationPath);
            }

            var filePath = Path.Combine(destinationPath, pdfFileName);
            await File.WriteAllBytesAsync(filePath, pdfBytes);
            Console.WriteLine($"PDF saved at: {filePath}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error saving PDF: {ex.Message}");
            throw;
        }
    }

    protected override void OnInitialized()
    {
        try
        {
            if (ListOfMergeDocuments != null)
            {
                List<API.Client.MenuItem> menuItems = new();
                foreach (var item in ListOfMergeDocuments)
                    menuItems.Add(new API.Client.MenuItem
                    {
                        Text = item.Name,
                        Icon = "bi bi-file-earmark-word",
                        FilenameTemplate = item.FilenameTemplate,
                        DriveId = item.DriveId,
                        DocumentId = item.DocumentId,
                        AllowPDFOnly = item.AllowPDFOnly,
                        AllowExcelOutputOnly = item.AllowExcelOutputOnly,
                        EntityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(item.EntityTypeGuid).ToString(),
                        LinkedEntityTypeGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(item.LinkedEntityTypeGuid).ToString(),
                        RecordGuid = ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(item.RecordGuid).ToString(),
                        MergeDocumentItems = item.Items.Select(x =>
                        {
                            var mergeDocumentItem = new MergeDocumentItem
                            {
                                Guid = x.Guid,
                                BookmarkName = x.BookmarkName,
                                EntityType = x.EntityType,
                                EntityTypeGuid = x.EntityTypeGuid,
                                LinkedEntityTypeGuid = x.LinkedEntityTypeGuid,
                                ImageColumns = x.ImageColumns,
                                MergeDocumentItemType = x.MergeDocumentItemType,
                                SubFolderPath = x.SubFolderPath,
                            };

                            // Populate Includes using AddRange
                            mergeDocumentItem.Includes.AddRange(x.Includes.Select(y => new MergeDocumentItemInclude
                            {
                                Guid = y.Guid,
                                SourceDocumentEntityProperty = y.SourceDocumentEntityProperty,
                                SourceSharepointItemEntityProperty = y.SourceSharepointItemEntityProperty,
                                IncludedMergeDocument = y.IncludedMergeDocument
                            }));

                            return mergeDocumentItem;
                        }).ToList()
                    });

                ListViewData = menuItems;
                Filter();
                FormHelper = new FormHelper(coreClient, sageIntegrationService, ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString(), userService);

                WindowIsVisible = true;
                base.OnInitialized();
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while initializing the component.");
            ex.Data.Add("PageMethod", "DocumentTaskView/OnInitialized()");
            OnError(ex);
        }
    }

    protected override async Task OnParametersSetAsync()
    {
        try
        {
            if (ParentDataObjectReference != null)
            {
                ParentDataObjectReference = JsonConvert.DeserializeObject<DataObjectReference>(HttpUtility.UrlDecode(SerializedDataObjectReference) ?? string.Empty);
                await ParentDataObjectReferenceChanged.InvokeAsync(ParentDataObjectReference);
            }
            await base.OnParametersSetAsync();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while setting the parameters.");
            ex.Data.Add("PageMethod", "JobDetail/OnParametersSetAsync()");
            OnError(ex);
        }
    }

    protected void SetLoaderVisibility(bool enable)
    {
        LoaderVisible = enable;
    }

    #endregion Protected Methods

    #region Private Methods

    private void ClearFilter()
    {
        FilterText = string.Empty;
        Filter();
    }

    private void CloseOutputTypeModal()
    {
        ShowOutPutType = false;
        StateHasChanged();
    }

    private void Filter()
    {
        try
        {
            var request = new DataSourceRequest
            {
                Filters = new List<IFilterDescriptor>()
            };
            request.Filters.Add(new FilterDescriptor("Text", FilterOperator.Contains, FilterText));

            if (ListViewData == null) return;
            Data = ListViewData.ToDataSourceResult(request).Data as List<API.Client.MenuItem>;
            Page = DefaultPage;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while filtering the data.");
            ex.Data.Add("PageMethod", "DocumentTaskView/Filter()");
            OnError(ex);
        }
    }

    private async void SetOutputType(string Type)
    {
        OutputType = Type;
        ShowOutPutType = false;
        StateHasChanged();

        await BtnGenerateDocuments(SelectedItems);
    }

    private void ShowOutPutTypeModal()
    {
        ShowOutPutType = true;
        StateHasChanged();
    }

    private void ToggleListVisibility()
    {
        IsListVisible = !IsListVisible;
    }

    #endregion Private Methods
}