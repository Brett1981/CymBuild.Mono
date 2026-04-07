using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.PWA.Classes;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Forms;
using Microsoft.AspNetCore.Components.Routing;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.JSInterop;
using System.Collections;
using System.Reflection.Metadata;
using System.Text;
using System.Text.Json;
using static Concursus.PWA.Shared.MessageDisplay;
using EntityProperty = Concursus.API.Core.EntityProperty;

namespace Concursus.PWA.Shared;

public partial class EditPage
{
    #region Private Fields

    private const string PostcodePropertyGuid = "64e674c3-e42d-4a4b-8747-16212d7db19d";
    private static EditPage _currentInstance;
    private CancellationTokenSource _cts;
    private CustomErrorBoundary? _customErrorBoundary;
    private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();
    private EditContext _editContext = new(new DataObject());
    private API.Client.FormHelper? _formHelper;
    private Geodata _geoData = new();
    private MessageDisplay _messageDisplay = new();
    private List<string> _messages = new();
    private DotNetObjectReference<EditPage> _objectReference;
    private bool _showDialog;
    private bool _showOverlay = false;
    private TaskCompletionSource<bool> _taskCompletionSource = new();
    private ConfigurationModel config;
    private bool hasConfirmedNavigation = false;
    private HubConnection hubConnection;
    private bool isHubConnected = false;
    private bool isPreparingStorageUrl = false;
    private string storageUrl = "";
    private Timer _debounceTimer;

    #endregion Private Fields

    #region Public Properties

    public ButtonMenu _buttonMenuRef { get; set; }
    [Parameter] public Dictionary<string, Any> TransientVirtualProperties { get; set; } = new();
    [Parameter] public bool EnableBrowserTabTitle { get; set; } = false;
    [Parameter] public string BrowserTabTitlePropertyName { get; set; } = "Number";
    [Parameter] public string? BrowserTabTitlePrefix { get; set; }
    [Parameter] public string BrowserTabApplicationName { get; set; } = "CymBuild";
    [Parameter] public EventCallback CloseWindow { get; set; }
    [Parameter] public DataObject dataObject { get; set; } = new() { RowStatus = 999 };
    [Parameter] public List<EntityProperty> entityProperties { get; set; } = new();
    [Parameter] public EventCallback<List<EntityProperty>> EntityPropertiesChanged { get; set; }
    [Parameter] public List<EntityPropertyGroup> entityPropertyGroups { get; set; } = new();
    [Parameter] public EventCallback<List<EntityPropertyGroup>> EntityPropertyGroupsChanged { get; set; }
    [Parameter] public string EntityTypeGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public FlexPropertyGroups flexPropertyGroups { get; set; } = new();
    [Parameter] public EventCallback<FlexPropertyGroups> FlexPropertyGroupsChanged { get; set; }
    [Parameter] public RenderFragment? FormBody { get; set; }
    [Parameter] public RenderFragment? FormButtons { get; set; }
    [Parameter] public EventCallback<(EditContext, bool, bool)> FormSubmittedPre { get; set; }
    [Parameter] public RenderFragment? FormTitle { get; set; }
    [Parameter] public EventCallback GridUpdated { get; set; }
    [Parameter] public bool IsBulkUpdate { get; set; } = false;
    [Parameter] public bool IsDetailWindowed { get; set; } = false;
    public bool IsFirstLoad { get; private set; } = true;
    [Parameter] public bool IsInformationPage { get; set; } = false;
    [Parameter] public string? ModalId { get; set; }
    public DataObjectReference? MyDataObjectReference { get; set; }
    public DataObjectReference? NewlyCreatedRecordReference { get; set; }
    public int NumberOfPhotos { get; private set; } = 0;
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string ParentGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public EntityProperty PassedEntityProperty { get; set; } = new EntityProperty();
    [Parameter] public Permissions? Permissions { get; set; } = new();
    [Parameter] public EventCallback<(API.Client.GeoData.PostcodeInfo, bool)> PostCodeChangedPre { get; set; }
    [Parameter] public string RecordGuid { get; set; } = Guid.Empty.ToString();
    [Parameter] public EventCallback<string> RecordGuidChanged { get; set; }
    public EventCallback RefreshJobProgressCallback { get; set; }
    [Parameter] public string ReturnUrl { get; set; } = "";
    [Parameter] public EventCallback<string> SelectedRecordGuidChanged { get; set; }
    [Parameter] public bool Windowed { get; set; } = false;

    [Parameter] public bool IsMainRecordContext { get; set; }

    // Optional: show invoice mode badge on Financial Overview header (DataPillRow)
    [Parameter] public string? InvoiceProcessingModeText { get; set; }
    [Parameter] public string? InvoiceProcessingModeCss { get; set; }
    [Parameter] public string? InvoiceProcessingModeTooltip { get; set; }

    [Parameter] public bool HideDefaultActions { get; set; } = false;
    [Parameter] public bool DisableDefaultActions { get; set; } = false;
    #endregion Public Properties

    #region Protected Properties

    protected string EntityTypeIcon { get; set; } = "";
    protected string EntityTypeLabel { get; set; } = "";
    protected string ErrorMessage { get; set; } = "";
    protected bool HasValidationMessages { get; set; } = true;
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string ObjectLabel { get; set; } = "";
    protected string PageMethod { get; set; } = "Not Set";

    #endregion Protected Properties

    #region Private Properties

    private string CurrentPage => NavManager.Uri.Replace(NavManager.BaseUri, "").TrimEnd('/');

    private DataObject DeltaDataObject { get; set; }
    private string DialogCss => _showDialog ? "modal show-dialog" : "modal";
    private bool firstRender { get; set; } = true;
    private bool HasChanges { get; set; } = false;
    private bool HasNavigationRanAlready { get; set; } = false;
    private bool hasUpdated { get; set; } = false;
    [Inject] private HttpClient Http { get; set; }
    private bool IsLoading { get; set; } = false;
    private bool LoaderVisibleS { get; set; }
    private bool LoaderVisibleSe { get; set; }
    private bool SaveButtonDisabled { get; set; } = false;

    [Parameter] public bool DeleteOperationPerformed { get; set; }
    [Parameter] public EventCallback<bool> DeleteOperationPerformedChanged { get; set; }
    // Tracks the most recent input update so Save can await it.
    private readonly object _inputUpdateLock = new();
    private Task _lastInputUpdateTask = Task.CompletedTask;

    // Optional: used to avoid waiting forever if something gets stuck
    private DateTime _lastInputUpdateUtc = DateTime.MinValue;


    // Monotonic counters
    private long _inputUpdateSeq = 0;        // increments on every real input update
    private long _lastProcessedUpdateSeq = 0; // last seq we considered "done" (saved or dismissed)
    #endregion Private Properties

    #region Public Methods

    private string GetStringValueByPropertyName(string propertyName)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(propertyName))
            {
                return string.Empty;
            }

            var entityPropertyGuid = entityProperties?
                .FirstOrDefault(p => p.Name == propertyName)?
                .Guid;

            if (string.IsNullOrWhiteSpace(entityPropertyGuid))
            {
                return string.Empty;
            }

            var dataProperty = dataObject?.DataProperties?
                .FirstOrDefault(p => p.EntityPropertyGuid == entityPropertyGuid);

            if (dataProperty?.Value == null)
            {
                return string.Empty;
            }

            if (dataProperty.Value.Is(StringValue.Descriptor))
            {
                return dataProperty.Value.Unpack<StringValue>()?.Value ?? string.Empty;
            }

            if (dataProperty.Value.Is(Int32Value.Descriptor))
            {
                return dataProperty.Value.Unpack<Int32Value>().Value.ToString();
            }

            if (dataProperty.Value.Is(Int64Value.Descriptor))
            {
                return dataProperty.Value.Unpack<Int64Value>().Value.ToString();
            }

            if (dataProperty.Value.Is(DoubleValue.Descriptor))
            {
                return dataProperty.Value.Unpack<DoubleValue>().Value.ToString();
            }

            if (dataProperty.Value.Is(FloatValue.Descriptor))
            {
                return dataProperty.Value.Unpack<FloatValue>().Value.ToString();
            }

            if (dataProperty.Value.Is(BoolValue.Descriptor))
            {
                return dataProperty.Value.Unpack<BoolValue>().Value.ToString();
            }

            return dataProperty.Value.ToString() ?? string.Empty;
        }
        catch
        {
            return string.Empty;
        }
    }

    private string ResolveBrowserTabTitlePrefix()
    {
        if (!string.IsNullOrWhiteSpace(BrowserTabTitlePrefix))
        {
            return BrowserTabTitlePrefix.Trim();
        }

        if (!string.IsNullOrWhiteSpace(EntityTypeLabel))
        {
            return EntityTypeLabel.Trim();
        }

        return "Record";
    }

    private async Task UpdateBrowserTabTitleAsync()
    {
        try
        {
            if (!EnableBrowserTabTitle)
            {
                return;
            }

            var propertyName = string.IsNullOrWhiteSpace(BrowserTabTitlePropertyName)
                ? "Number"
                : BrowserTabTitlePropertyName.Trim();

            var recordNumber = GetStringValueByPropertyName(propertyName);
            var prefix = ResolveBrowserTabTitlePrefix();

            if (string.IsNullOrWhiteSpace(recordNumber))
            {
                await PWAFunctions.SetBrowserTabTitleAsync(JsRuntime, BrowserTabApplicationName);
                return;
            }

            await PWAFunctions.SetBrowserTabTitleAsync(
                JsRuntime,
                BrowserTabApplicationName,
                prefix,
                recordNumber);
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "An error occurred while updating the browser tab title.";
            ex.Data["PageMethod"] = "EditPage/UpdateBrowserTabTitleAsync()";
            await OnError(ex);
        }
    }
    /// <summary>
    /// Useful when for example we update the dataobject programmatically. If the user tries to
    /// save, it will say "No changes detected" - this method should solve that issue. Created for
    /// the Postcode Lookup project to tackle this very issue.
    /// </summary>
    public void SetHasChangedToTrue()
    {
        hasUpdated = true;
        DeltaDataObject = new();

        StateHasChanged();
    }

    /*
        CBLD-642:
        Having to load a type of "Contacts" record through the type "Account Contacts"
        Idea is to allow changing the label in real-time  if we are loading up a record type "through another".

     */

    public void ChangeEntityTypeLabel(string newVal, string icon = "")
    {
        if (icon != "")
            EntityTypeIcon = icon;
        EntityTypeLabel = newVal;
    }

    public bool GetValueAsBool(string propertyName)
    {
        var entityPropGuid = entityProperties?.FirstOrDefault(p => p.Name == propertyName)?.Guid;
        var value = dataObject.DataProperties.FirstOrDefault(p => p.EntityPropertyGuid == entityPropGuid)?.Value;

        bool toReturn = value.Unpack<BoolValue>().Value;

        Console.WriteLine(toReturn);

        return toReturn; // Return null if value is null or parsing fails
    }

    //CBLD-382
    public static EditPage GetInstance()
    {
        return _currentInstance;
    }

    [JSInvokable("HandleProcessedFilesStatic")]
    public static Task HandleProcessedFilesStatic(string processedFilesJson)
    {
        // Retrieve the current instance of EditPage (you can keep a static reference or pass it
        // from JavaScript)
        var instance = GetInstance(); // Assuming you have a way to get the current instance
        return instance.HandleProcessedFiles(processedFilesJson);
    }

    public void Dispose()
    {
        _objectReference?.Dispose();
        hubConnection?.DisposeAsync();
    }

    public Task HandleInputUpdated(InputUpdatedArgs? inputUpdatedArgs)
    {
        Task updateTask = HandleInputUpdatedCoreAsync(inputUpdatedArgs);

        lock (_inputUpdateLock)
        {
            _lastInputUpdateTask = updateTask;
        }

        return updateTask;
    }

    private async Task HandleInputUpdatedCoreAsync(InputUpdatedArgs? inputUpdatedArgs)
    {
        try
        {
            if (inputUpdatedArgs == null)
                return;

            // If no value, do not mark as changed.
            if (inputUpdatedArgs.NewValue is null)
                return;

            // Increment update sequence FIRST so Save can detect "something happened"
            long mySeq;
            lock (_inputUpdateLock)
            {
                mySeq = ++_inputUpdateSeq;
            }

            DeltaDataObject = new();
            DeltaDataObject.DataProperties.Add(new DataProperty
            {
                Value = inputUpdatedArgs.NewValue,
                EntityPropertyGuid = inputUpdatedArgs.EntityId.ToString()
            });

            _debounceTimer?.Dispose();
            _debounceTimer = new Timer(_ => InvokeAsync(StateHasChanged), null, 300, Timeout.Infinite);

            var isVirtualProperty = dataObject.DataProperties
                .FirstOrDefault(x => x.EntityPropertyGuid == inputUpdatedArgs.EntityId.ToString() && x.IsVirtual);

            if (isVirtualProperty != null)
                Console.WriteLine(isVirtualProperty);

            Console.WriteLine($"DeltaDataObject updated. Seq={mySeq}");

            // Type checks (as you had)
            if (inputUpdatedArgs.NewValue.Is(StringValue.Descriptor) ||
                inputUpdatedArgs.NewValue.Is(Timestamp.Descriptor) ||
                inputUpdatedArgs.NewValue.Is(BoolValue.Descriptor) ||
                inputUpdatedArgs.NewValue.Is(Int32Value.Descriptor))
            {
                HasChanges = true;
            }

            if (_formHelper != null)
            {
                await HandleFormHelper(inputUpdatedArgs, inputUpdatedArgs.NewValue.ToString());
            }

            // hasUpdated becomes derived state (still keep if other code expects it)
            hasUpdated = true;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while updating the input.");
            ex.Data.Add("PageMethod", "EditPage/HandleInputUpdated()");
            OnError(ex);
        }
    }

    private async Task WaitForPendingInputUpdatesIfNeededAsync(int maxWaitMs = 800)
    {
        // Let any queued input event dispatch first
        await Task.Yield();

        Task pending;
        long seqSnapshot;
        long processedSnapshot;

        lock (_inputUpdateLock)
        {
            pending = _lastInputUpdateTask ?? Task.CompletedTask;
            seqSnapshot = _inputUpdateSeq;
            processedSnapshot = _lastProcessedUpdateSeq;
        }

        // Nothing new since last processed -> do NOT wait
        if (seqSnapshot <= processedSnapshot)
            return;

        // There *is* a new update; wait for the update task to finish (with timeout)
        if (pending.IsCompleted)
            return;

        var timeout = Task.Delay(maxWaitMs);
        var completed = await Task.WhenAny(pending, timeout);

        if (completed == timeout)
        {
            Console.WriteLine($"WaitForPendingInputUpdatesIfNeededAsync timed out after {maxWaitMs}ms.");
            return;
        }

        await pending; // propagate exceptions
    }

    public async Task HandleProcessedFiles(string processedFilesJson)
    {
        try
        {
            Console.WriteLine($"HandleProcessedFiles method called with {processedFilesJson} as a string");
            var processedFiles = JsonSerializer.Deserialize<List<FileModel>>(processedFilesJson);
            _showOverlay = true;  // Show overlay when processing starts
            InvokeAsync(StateHasChanged);

            foreach (var file in processedFiles)
            {
                if (file.Content == null || file.Content.Length == 0)
                {
                    Console.WriteLine($"File {file.Name} has null or empty content. Skipping processing.");
                    var ex = new Exception($"Processing of Images has failed Due to the Content being empty.");
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "File content is empty or null. Skipping processing.");
                    ex.Data.Add("PageMethod", "EditPage/HandleProcessedFilesStatic(processedFilesJson)");
                    OnError(ex);
                }
                else
                {
                    Console.WriteLine($"File {file.Name} with size {file.Size} is being processed. Content length: {file.Content.Length}");
                    Console.WriteLine($"File {file.Name} will be stored at: {file.StorageUrl}");
                    await _fileChannel.Writer.WriteAsync(file);
                    Console.WriteLine($"Processed and wrote file {file.Name} to channel");

                    // Notify the Hub that the file has been processed
                    await hubConnection?.InvokeAsync("SendFileProcessed", file.Name ?? "Unknown");
                }
            }

            // Hide overlay when processing is done
            _showOverlay = false;
            InvokeAsync(StateHasChanged);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error in HandleProcessedFiles: {ex.Message}");
        }
    }

    public async Task OnError(Exception error)
    {
        Console.WriteLine("EditPage: OnError called.");

        if (string.IsNullOrEmpty(error.Message))
        {
            Console.WriteLine("EditPage: Error message is empty. Aborting.");
            return;
        }

        Console.WriteLine($"EditPage: Error Message: {error.Message}");

        ErrorMessage = error.Message;
        PageMethod = error.Data.Contains("PageMethod")
            ? error.Data["PageMethod"]?.ToString() ?? "Not Set"
            : "Not Set";
        Console.WriteLine($"EditPage: PageMethod = {PageMethod}");

        if (error.Data.Contains("MessageType"))
        {
            MessageType = (ShowMessageType)(error.Data["MessageType"] ?? ShowMessageType.Information);
            Console.WriteLine($"EditPage: MessageType = {MessageType}");
        }
        else
        {
            MessageType = ShowMessageType.Error;
            Console.WriteLine("EditPage: MessageType not found in error.Data. Defaulted to Error.");
        }

        // Extract all exception data
        var exceptionData = error.Data.Count > 0
            ? error.Data.Cast<DictionaryEntry>().ToDictionary(
                de => de.Key?.ToString() ?? "UnknownKey",
                de => de.Value!)
            : null;

        if (exceptionData != null)
        {
            Console.WriteLine("EditPage: Exception Data:");
            foreach (var kvp in exceptionData)
                Console.WriteLine($"    {kvp.Key} = {kvp.Value}");
        }

        _messageDisplay.UpdateExceptionData(exceptionData);
        _messageDisplay.UpdateStackTrace(error.StackTrace ?? "No additional details available.");
        _messageDisplay.ShowError(true);

        Console.WriteLine("EditPage: MessageDisplay updated and error shown.");

        // AI Error Reporting (only for actual errors)
        if (MessageType == ShowMessageType.Error)
        {
            try
            {
                Console.WriteLine("EditPage: Starting AI Error Reporter...");
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
                Console.WriteLine($"EditPage: UserInteractionLog = {description}");

                var result = await AiErrorReporter.ReportAsync(error, context);

                if (result != null && !string.IsNullOrEmpty(result.UiMessage))
                {
                    Console.WriteLine("EditPage: AI Error Reporter returned UI message. Updating MessageDisplay.");
                    _messageDisplay.SetMessage(result.UiMessage, result.MessageType);
                    _messageDisplay.ShowError(true);
                }
                else
                {
                    Console.WriteLine("EditPage: AI Error Reporter returned no UI message.");
                }
            }
            catch (Exception aiEx)
            {
                Console.WriteLine($"EditPage: Exception in AI Error Reporter: {aiEx.Message}\n{aiEx.StackTrace}");
            }
        }

        StateHasChanged();
        Console.WriteLine("EditPage: StateHasChanged called. OnError complete.");
    }

    public async void ReceiveItemDoubleClick(DriveListItem clickedItem)
    {
        // Handle the details received from the child component
        Console.WriteLine($"Received details from child: Item ID: {clickedItem.Id}, Name: {clickedItem.Name}");
        try
        {
            StringValue value = new() { Value = clickedItem.Id };
            var documentId = dataObject.DataProperties
                .FirstOrDefault(p => p.EntityPropertyGuid == "5b013ef3-6b8c-4486-b91d-165f5f24fb70");

            if (documentId == null) return;
            documentId.Value = Any.Pack(value);
            //_ = Task.Run(async () =>
            //{
            var (message, newDataObject) = await _formHelper?.UpsertDataObject(dataObject, null, false, IsBulkUpdate);
            if (!string.IsNullOrEmpty(message)) throw new Exception(message);
            dataObject = newDataObject;
            StateHasChanged();
            //});
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while updating the DataObject.");
            ex.Data.Add("PageMethod", "EditPage/ReceiveItemDoubleClick()");
            OnError(ex);
        }
    }

    //CBLD-498
    public async void SaveDataObject()
    {
        var (message, newDataObject) = await _formHelper.UpsertDataObject(dataObject, null, false, IsBulkUpdate, modalService);
        Console.WriteLine(message);
        Console.WriteLine(newDataObject);

        dataObject = newDataObject;

        StateHasChanged();
    }

    //CBLD-498
    public async void ReSyncDataObject()
    {
        dataObject = await _formHelper.ReadDataObjectAsync(dataObject.Guid, MyDataObjectReference);
        StateHasChanged();
    }

    // -----------------------------------------------------------------------------
    // PUBLIC: External callers (e.g., JobDetail modal) can trigger the same save
    // behaviours as the built-in buttons without duplicating logic.
    // -----------------------------------------------------------------------------
    public Task SaveAsync()
    {
        // Same behaviour as clicking "Save"
        return FormSubmitted(_editContext, save: true, exit: false, IsBulkUpdate);
    }

    public Task SaveAndExitAsync()
    {
        // Same behaviour as clicking "Save and Exit"
        return FormSubmitted(_editContext, save: true, exit: true, IsBulkUpdate);
    }

    public Task CancelAndExitAsync()
    {
        // Same behaviour as "exit without saving"
        PerformACanceledState(stateService, ReturnUrl);
        return Task.CompletedTask;
    }
    #endregion Public Methods

    #region Protected Methods

    protected async Task FormSubmitted(EditContext editContext, bool save, bool exit, bool IsBulkUpdate = false)
    {
        var UpdateSharepoint = false;

        if (save)
        {
           
            await WaitForPendingInputUpdatesIfNeededAsync(maxWaitMs: 2000);

            // Now decide "no changes" based on sequence, not sticky flags
            long seq;
            long processed;
            lock (_inputUpdateLock)
            {
                seq = _inputUpdateSeq;
                processed = _lastProcessedUpdateSeq;
            }

            // If nothing changed since last processed/save, treat as "no changes"
            if (seq <= processed)
            {
                DeltaDataObject = null;
                hasUpdated = false;
                HasChanges = false;
            }
        }

        if (DeltaDataObject == null || !hasUpdated)
        {
            if (exit && !save && !HasValidationMessages)
            {
                PerformACanceledState(stateService, ReturnUrl);
                IsLoading = false;
                Console.WriteLine("No changes detected Just Exit");
                return;
            }
            else if (!save && !exit & !IsBulkUpdate)
            {
                Console.WriteLine("Continue as normal");
            }
            else if (save && !exit && !HasValidationMessages)
            {
                // NEW: If EditContext says we're modified, give one last tiny settle before rejecting the save.
                if (editContext?.IsModified() == true)
                {
                    await StabilizePendingEditsAsync(editContext, maxWaitMs: 600, pollMs: 50);
                }

                // Re-check after settle
                if (DeltaDataObject == null || !hasUpdated)
                {
                    Console.WriteLine("No changes detected");
                    var ex = new Exception("No changes detected. No requirement to Save")
                    {
                        Data =
                    {
                        { "PageMethod", "EditPage/FormSubmitted()" },
                        { "AdditionalInfo", "User already submitted form or no changes detected." },
                        { "MessageType", MessageDisplay.ShowMessageType.Information }
                    }
                    };
                    IsLoading = false;
                    OnError(ex);
                    return;
                }
            }
            else if (save && exit && !HasValidationMessages)
            {
                Console.WriteLine("Save & Exit & No Change --> Exit page");
                PerformACanceledState(stateService, ReturnUrl);
                return;
            }
        }

        IsLoading = true;

        try
        {
            _ = SetLoaderVisibility(save, exit, true);
            _ = FormSubmittedPre.InvokeAsync((editContext, save, exit));

            // Ensure ParentDataObjectReference is initialized
            await InitializeParentDataObjectReferenceAsync();

            // Prepare state changes for the form
            PWAFunctions.PrepareStateChanges(editContext, stateService, ParentDataObjectReference.DataObjectGuid.ToString());

            if (_formHelper != null && save)
            {
                // Keep the existing small delay (but now it’s after we’ve stabilised input)
                await Task.Delay(500);
                UpdateSharepoint = true;

                var hasVirtualProperty = dataObject.DataProperties.Any(x => x.IsVirtual);

                if (hasVirtualProperty)
                {
                    Console.WriteLine(dataObject.DataProperties.First(x => x.IsVirtual));
                }

                var (message, newDataObject) = await _formHelper.UpsertDataObject(dataObject, null, false, IsBulkUpdate, modalService);
                if (!string.IsNullOrEmpty(message)) throw new Exception(message);

                Console.WriteLine($"New Data Object Guid- {newDataObject.Guid}");
                dataObject = newDataObject;

                // Update the references after data object changes
                await UpdateReferencesAfterSaveAsync();

                // Update modal reference if necessary
                UpdateModalReference();

                if (Windowed && stateService != null)
                {
                    UpdateStateServiceReference(dataObject);
                }

                // Prepare state changes for the form
                PWAFunctions.PrepareStateChanges(_editContext, stateService, ParentDataObjectReference.DataObjectGuid.ToString());

                // Handle success and validation messages
                await HandleFormSaveSuccessAsync(message, exit);

                // FIX: Prevent any hidden navigation on SAVE. Some internal state code later calls
                // PerformACanceledState when `save == true`. Setting save = false here neutralises
                // that behaviour but does not affect Save & Exit.
                save = false;

                // Update dropdown list definitions if needed
                if (PassedEntityProperty?.DropDownListDefinition != null)
                {
                    PassedEntityProperty.DropDownListDefinition.Guid = dataObject.Guid;
                }

                /* Ensure RecordGuid is updated and other record information */
                RecordGuid = dataObject.Guid.ToString();
                ObjectLabel = dataObject.Label;
                storageUrl = dataObject.SharePointUrl;
                _editContext = new EditContext(dataObject);

                await UpdateBrowserTabTitleAsync();
                // Ensure ParentDataObjectReference is initialized
                await InitializeParentDataObjectReferenceAsync();
                /* */

                HasValidationMessages = dataObject.HasValidationMessages;
                SaveButtonDisabled = dataObject.SaveButtonDisabled;

                if (_buttonMenuRef != null)
                {
                    await _buttonMenuRef.RequestRefresh();
                }

                await ReloadDataForNewRecordAsync();
            }

            if (exit && !HasValidationMessages)
            {
                await HandleExitAsync();
            }

            // Use debounce to avoid immediate UI refresh
            _debounceTimer?.Dispose();
            _debounceTimer = new Timer(_ =>
            {
                InvokeAsync(StateHasChanged);
            }, null, 500, Timeout.Infinite);

            await UpdateDependentPropertiesAsync();

            IsLoading = false;
        }
        catch (Exception ex)
        {
            HandleError(ex, "EditPage/FormSubmitted()");
            IsLoading = false;
        }
        finally
        {
            await SetLoaderVisibility(save, exit, false).ConfigureAwait(false);
        }

        await SetupSharePointUrlAsync(UpdateSharepoint);
    }

    /// <summary>
    /// Ensures Blazor has a chance to flush any last input events (especially when binding uses onchange)
    /// and waits briefly for the delta builder/rowversion refresh flags to stabilise.
    /// </summary>
    private async Task StabilizePendingEditsAsync(
        EditContext editContext,
        int maxWaitMs = 400,
        int pollMs = 40)
    {
        // 1) Let any pending UI events (blur/onchange) run before we check DeltaDataObject/hasUpdated
        // Task.Yield is usually better than a blind delay because it gives the renderer a turn.
        await Task.Yield();
        await InvokeAsync(StateHasChanged);

        // 2) If the change detection/delta builder runs async, give it a short window to complete.
        // We stop early as soon as the system recognises the update.
        var waited = 0;

        // Quick early exit if already good.
        if (DeltaDataObject != null && hasUpdated)
            return;

        while (waited < maxWaitMs)
        {
            // If the own flags say we're ready, stop.
            if (DeltaDataObject != null && hasUpdated)
                return;

            // If Blazor thinks we’re modified, that’s a strong signal something is still settling.
            // (We still rely on the DeltaDataObject/hasUpdated for correctness.)
            if (editContext?.IsModified() != true && (DeltaDataObject == null && !hasUpdated))
            {
                // Not modified and no delta – nothing to wait for
                return;
            }

            await Task.Delay(pollMs);
            waited += pollMs;
        }

        // If we get here, we deliberately *do not* throw — we just fall through
        // and the existing "No changes" logic will still apply.
    }


    protected override void OnInitialized()
    {
        try
        {
            _editContext = new EditContext(dataObject);
            Permissions ??= new Permissions
            {
                CloseWindow = CloseWindow
            };
            _currentInstance = this;
            base.OnInitialized();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while initializing the EditPage component.");
            ex.Data.Add("PageMethod", "EditPage/OnInitialized()");
            OnError(ex);
        }
    }

    private async Task EnsureCorrectParentGuid()
    {
        if (ParentGuid == Guid.Empty.ToString() && Windowed)
        {
            var numberOfModals = modalService.GetOpenModals().Count();

            //OE: CBLD-467.
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

                    StateHasChanged();
                }
            }
        }
    }

    protected override async Task OnInitializedAsync()
    {
        IsLoading = true;
        try
        {
            _editContext = new EditContext(dataObject);
            Permissions ??= new Permissions
            {
                CloseWindow = CloseWindow
            };

            // Create the DotNetObjectReference here
            _objectReference = DotNetObjectReference.Create(this);
            JsRuntime.InvokeVoidAsync("storeDotNetObjectReference", _objectReference);

            // Setup SignalR Hub connection
            if (!isHubConnected)
            {
                var apiUrl = Configuration["ShoreAPI:Url"];
                hubConnection = new HubConnectionBuilder()
                    .WithUrl($"{apiUrl}/fileProcessingHub")
                    .WithAutomaticReconnect(new[] { TimeSpan.Zero, TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(30) }) // Exponential backoff
                    .Build();

                await hubConnection.StartAsync();
                Console.WriteLine($"Hub connection started with ConnectionId: {hubConnection.ConnectionId}");

                // Register the ConnectionId with the server
                await hubConnection.InvokeAsync("RegisterConnectionId", hubConnection.ConnectionId, userService.Email);

                hubConnection.Reconnecting += error =>
                {
                    Console.WriteLine($"Reconnecting due to error: {error?.Message}");
                    // Notify user about reconnection attempts (you can update the UI here)
                    return Task.CompletedTask;
                };

                hubConnection.Reconnected += connectionId =>
                {
                    Console.WriteLine($"Reconnected with connection ID: {connectionId}");
                    // Notify user about reconnection success (you can update the UI here)
                    _debounceTimer?.Dispose();
                    _debounceTimer = new Timer(_ =>
                    {
                        InvokeAsync(StateHasChanged);
                    }, null, 500, Timeout.Infinite);

                    return Task.CompletedTask;
                };

                hubConnection.Closed += async error =>
                {
                    Console.WriteLine($"Connection closed due to error: {error?.Message}");
                    // Attempt to reconnect after a delay
                    await Task.Delay(new Random().Next(0, 5) * 1000);
                    await hubConnection.StartAsync();
                };

                hubConnection.On<string>("FileProcessed", async (fileName) =>
                {
                    Console.WriteLine($"Client ConnectionId: {hubConnection.ConnectionId}");

                    Console.WriteLine($"FileProcessed event received for file: {fileName}");

                    // Add the message and show the overlay
                    _messages.Add($"File {fileName} processed.");
                    _showOverlay = true;
                    StateHasChanged();

                    // Debounce the StateHasChanged
                    _cts?.Cancel(); // Cancel the previous debounce, if it exists
                    _cts = new CancellationTokenSource();

                    // Debounce delay (e.g., wait 300ms before updating UI)
                    await Task.Delay(300, _cts.Token).ContinueWith(task =>
                    {
                        if (!task.IsCanceled)
                        {
                            InvokeAsync(StateHasChanged);
                        }
                    });

                    // Simulate random delay before removing message
                    await Task.Delay(new Random().Next(0, 5) * 400);
                    _messages.Remove($"File {fileName} processed.");

                    if (_messages.Count == 0)
                    {
                        _showOverlay = false;
                        StateHasChanged();
                    }
                });
                isHubConnected = true;
            }
            await EnsureCorrectParentGuid();
            _formHelper = new API.Client.FormHelper(coreClient, sageIntegrationService, PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString(), userService);

            await _formHelper.LoadMetaDataAsync(IsInformationPage);

            entityPropertyGroups = _formHelper.EntityType.EntityPropertyGroups.ToList();
            entityProperties = _formHelper.EntityType.EntityProperties.ToList();
            EntityTypeLabel = _formHelper.EntityType.Label;
            EntityTypeIcon = _formHelper.EntityType.IconCss;

            if (ParentDataObjectReference == null || (ParentDataObjectReference.DataObjectGuid == Guid.Empty
                                                      && ParentDataObjectReference.EntityTypeGuid == Guid.Empty))
            {
                MyDataObjectReference =
                    await PWAFunctions.EnsureDataObjectReferenceAsync(dataObject, MyDataObjectReference);
                ParentDataObjectReference = MyDataObjectReference;
            }
            // Get the record data if its a new Record first time save
            if (!Windowed && (RecordGuid == Guid.Empty.ToString() && ParentDataObjectReference.DataObjectGuid.ToString() != Guid.Empty.ToString()))
            {
                //CBLD-365: Ensure the RecordGuid is empty.
                if (EntityTypeGuid != ParentDataObjectReference.EntityTypeGuid.ToString())
                    RecordGuid = Guid.Empty.ToString();
                else
                    RecordGuid = ParentDataObjectReference.DataObjectGuid.ToString();
            }

            //CBLD-170: Try catch added here to catch any errors that occur when the dataObject is being read, return a new record if an error occurs
            try
            {
                dataObject = await _formHelper.ReadDataObjectAsync(
                    PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(RecordGuid).ToString(),
                    ParentDataObjectReference,
                    IsInformationPage,
                    "",
                    modalService,
                    IsBulkUpdate,
                    transientVirtualProperties: TransientVirtualProperties);
                if (!string.IsNullOrEmpty(dataObject.ErrorReturned))
                {
                    throw new Exception(dataObject.ErrorReturned);
                }
            }
            catch (Exception ex)
            {
                //CBLD-407 - error message handling
                if (EntityTypeGuid == "2cfbff39-93cd-436b-b8ca-b2fcf7609707" && ex.Message.Contains("No data returned for property"))
                {
                    ex = new Exception("This asset no longer exists");
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "An error occurred while reading the DataObject.");
                    ex.Data.Add("PageMethod", "EditPage/OnInitializedAsync()");
                }

                //CBLD-627: Account Merge - display warning message
                else if (EntityTypeGuid == "40476ecc-d19a-4de9-90df-e1f45cd72fb2" && ex.Message.Contains("No data returned for property AccountStatusID"))
                {
                    ex = new Exception("The record no longer exists!");
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Warning);
                    ex.Data.Add("AdditionalInfo", "An error occurred while reading the DataObject.");
                    ex.Data.Add("PageMethod", "EditPage/OnInitializedAsync()");
                }
                else
                {
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "An error occurred while reading the DataObject.");
                    ex.Data.Add("PageMethod", "EditPage/OnInitializedAsync()");
                }

                IsLoading = false;
                OnError(ex);
            }

            HasValidationMessages = dataObject.HasValidationMessages;
            SaveButtonDisabled = dataObject.SaveButtonDisabled;
            ObjectLabel = dataObject.Label;
            storageUrl = dataObject.SharePointUrl;
            // Initialize the editContext here
            _editContext = new EditContext(dataObject);

            await UpdateBrowserTabTitleAsync();
            // Get the storage URL after initializing the form helper

            if (RecordGuid != Guid.Empty.ToString())
            {
                storageUrl = await PWAFunctions.GetStorageUrlAsync(dataObject, _formHelper, storageUrl, IsBulkUpdate);
                Console.WriteLine($"Storage URL - {storageUrl}");

                //OE: CBLD-446
                // if (EntityTypeGuid == "571a9397-7e28-4bef-8ddc-fd4c56787bde"
                // && IsFirstLoad && !string.IsNullOrEmpty(storageUrl))
                if (EntityTypeGuid == "571a9397-7e28-4bef-8ddc-fd4c56787bde" && !string.IsNullOrEmpty(storageUrl))
                {
                    await PrepareFileCount();
                }
            }
            await base.OnInitializedAsync();
            _ = Task.Run(async () => { await FormSubmitted(_editContext, false, false); });
            IsLoading = false;
            return;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while initializing the EditPage component.");
            ex.Data.Add("PageMethod", "EditPage/OnInitializedAsync()");
            IsLoading = false;
            OnError(ex);
        }

        IsLoading = false;
    }

    protected override void OnParametersSet()
    {
        try
        {
            if (Windowed)
            {
                ReturnUrl = NavManager.Uri;
            }

            SaveButtonDisabled = dataObject.SaveButtonDisabled; //CBLD-382

            // Only update if necessary to avoid triggering unnecessary re-renders
            if (MyDataObjectReference == null ||
                MyDataObjectReference.DataObjectGuid.ToString() != RecordGuid ||
                MyDataObjectReference.EntityTypeGuid.ToString() != EntityTypeGuid)
            {
                MyDataObjectReference = new DataObjectReference(RecordGuid, EntityTypeGuid);
            }

            base.OnParametersSet();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while setting the parameters.");
            ex.Data.Add("PageMethod", "EditPage/OnParametersSet()");
            OnError(ex);
        }
    }

    protected Task SetLoaderVisibility(bool save, bool exit, bool enable)
    {
        switch (save)
        {
            case true when !exit:
                LoaderVisibleS = enable;
                break;

            case true when exit:
                LoaderVisibleSe = enable;
                break;

            default:
                LoaderVisibleS = false;
                LoaderVisibleSe = false;
                break;
        }

        return Task.CompletedTask;
    }

    #endregion Protected Methods

    #region Private Methods

    private static string EnsureCorrectUri(string uri)
    {
        // IMPORTANT: This helper is used in multiple places. For encoded ReturnUrl / history URLs
        // (which already contain "https%3a%2f%2f"), this method intentionally does NOTHING to avoid
        // corrupting the encoded URL.
        if (string.IsNullOrEmpty(uri))
            return uri;

        const string encodedHttps = "https%3a";
        const string fullyEncodedHttps = "https%3a%2f%2f";

        // Find "https%3a" (encoded https)
        var idx = uri.IndexOf(encodedHttps, StringComparison.OrdinalIgnoreCase);
        if (idx == -1)
            return uri;

        // HISTORY / RETURNURL CASE: If the string already has "https%3a%2f%2f" starting at this
        // index, then the "https://" part is already FULLY encoded. That is exactly what our
        // ReturnUrl / history URLs look like. In that case, DO NOTHING – this path is "safe" and
        // must not be rewritten.
        if (uri.IndexOf(fullyEncodedHttps, StringComparison.OrdinalIgnoreCase) == idx)
        {
            // Example of such URI: ".../https%3a%2f%2flocalhost%3a44368%2fJobDetail%2f..."
            return uri;
        }

        // LEGACY / PARTIAL-ENCODE CASE: Otherwise, we assume we have a partially-encoded URL where
        // the slashes after "https%3a" are still plain "/" and we want to encode them.
        var partToReplace = uri.Substring(idx + encodedHttps.Length);

        // Replace all occurrences of "/" with "%2f"
        var replacedPart = partToReplace.Replace("/", "%2f");

        // Rebuild the string
        var prefix = uri.Substring(0, idx + encodedHttps.Length);
        var newUri = prefix + replacedPart;

        return newUri;
    }

    private Task Cancel()
        => CloseDialogAsync(false);

    private Task CloseDialogAsync(bool navigate)
    {
        _showDialog = false;
        if (Windowed && navigate)
        {
            CloseWindow.InvokeAsync();
        }
        else
        {
            // Sets the Task to completed.
            _taskCompletionSource.SetResult(navigate);
            PWAFunctions.ResetStateService(stateService);
        }

        // Queue a Render Request
        StateHasChanged();

        return _taskCompletionSource.Task;
    }

    private void HandleError(Exception ex, string pageMethod)
    {
        ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
        ex.Data.Add("AdditionalInfo", ex.Message);
        ex.Data.Add("PageMethod", pageMethod);
        OnError(ex);
    }

    private async Task HandleExitAsync()
    {
        if (Windowed)
        {
            // Original windowed behaviour (no change)
            _ = Task.Run(async () =>
            {
                var recordData = new RecordStateData(stateService);
                if (recordData.OriginalGuid != Guid.Empty &&
                    recordData.ChildGuid != Guid.Empty &&
                    recordData.OriginalGuid != recordData.ChildGuid &&
                    recordData.OriginalItem != Guid.Empty)
                {
                    // Update the bound selection in the parent grid/window
                    dataObject = await PrepareUpdateToBindedSelection();
                }
            });

            StateHasChanged();
            _ = GridUpdated.InvokeAsync();
            _ = CloseWindow.InvokeAsync();
        }
        else
        {
            // Unified exit path for all non-windowed pages: Dashboard → Job, Grid → Job, Job →
            // Job (History), etc.
            //
            // We let NavigateToCorrectPage:
            // - Decode the route segment ReturnUrl once
            // - If it contains nested https:// segments, pick the LAST one
            // - Navigate directly to that URL
            //
            // This avoids broken URLs like: /JobDetail/.../{...}/https://localhost:44368/jobs/...
            // and correctly handles: Job A → Job B (History) → Save & Exit → Job A → Save & Exit → Grid

            PWAFunctions.ResetStateService(stateService);

            // ParentDataObjectReference is initialised earlier
            // (InitializeParentDataObjectReferenceAsync). For safety, fall back to an empty
            // reference if it’s somehow null.
            var reference = ParentDataObjectReference ?? new DataObjectReference(string.Empty, string.Empty);

            PWAFunctions.NavigateToCorrectPage(
                NavManager,
                reference,
                ReturnUrl,
                IsWindowed: false);
        }
    }

    private async Task HandleFormHelper(InputUpdatedArgs inputUpdatedArgs, string newValue)
    {
        try
        {
            if (_formHelper != null)
            {
                //Take a snapshot before we update the values.

                var (message, newDataObject) = await _formHelper.UpsertDataObject(dataObject, null, true, IsBulkUpdate, null, DeltaDataObject); //OE - CBLD-436
                if (!string.IsNullOrEmpty(message))
                {
                    var ex = new Exception(message);
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "An error occurred while updating the DataObject.");
                    ex.Data.Add("PageMethod", "EditPage/HandleFormHelper()");
                    OnError(ex);
                }
                ;
                dataObject = newDataObject;

                HasValidationMessages = dataObject.HasValidationMessages;
                SaveButtonDisabled = dataObject.SaveButtonDisabled;
                UpdateBoundDataProperties(newDataObject);

                flexPropertyGroups.RebindFromPropertyChange(inputUpdatedArgs);

                if (HasValidationMessages && dataObject.ValidationResults.Any())
                {
                    HandleValidationErrors(dataObject);
                }
                else
                {
                    if (!string.IsNullOrEmpty(newValue))
                    {
                        if (IsPostcodeUpdated(inputUpdatedArgs, newValue))
                        {
                            _ = Task.Run(async () => { await HandlePostcodeUpdated(inputUpdatedArgs); });
                        }
                    }
                }
                StateHasChanged();
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while updating the DataObject.");
            ex.Data.Add("PageMethod", "EditPage/HandleFormHelper()");
            OnError(ex);
        }
    }

    private async Task HandleFormSaveSuccessAsync(string message, bool exit)
    {
        HasChanges = false;

        _ = GridUpdated.InvokeAsync();
        StateHasChanged();

        if (!string.IsNullOrEmpty(message))
        {
            exit = false;
            var ex = new Exception(message)
            {
                Data = {
                    { "PageMethod", "EditPage/FormSubmitted()" },
                    { "AdditionalInfo", "An error occurred while saving the DataObject." },
                    { "MessageType", MessageDisplay.ShowMessageType.Error } }
            };
            OnError(ex);
        }
        else
        {
            // Display success message if the record was saved successfully
            if (!exit)
            {
                var ex = new Exception("Record Saved Successfully.")
                {
                    Data = {
                        { "PageMethod", dataObject.Label ?? "New Record" },
                        { "AdditionalInfo", "Record Saved Successfully." },
                        { "MessageType", MessageDisplay.ShowMessageType.Success } }
                };
                OnError(ex);
            }
        }
    }

    private async Task HandlePostcodeUpdated(InputUpdatedArgs inputUpdatedArgs)
    {
        try
        {
            var postcode = inputUpdatedArgs.NewValue.Unpack<StringValue>().Value;

            var postcodeInfo = await _geoData.GetGeoDataAsync(postcode);
            if (postcodeInfo.Result.Count > 0)
            {
                // Assuming postcodeInfo.Result[0] is not null but its properties might be
                var result = postcodeInfo.Result.FirstOrDefault(); // Safely attempt to get the first result or null

                // Define default values for latitude and longitude as double
                double defaultLatitudeValue = 0.0;
                double defaultLongitudeValue = 0.0;

                DoubleValue lat = new() { Value = result?.Latitude ?? 0.0 };
                DoubleValue lon = new() { Value = result?.Longitude ?? 0.0 };
                StringValue county = new() { Value = result?.AdminCounty ?? "DefaultCounty" };
                StringValue town = new() { Value = result?.AdminDistrict ?? "DefaultTown" };
                StringValue addressLine3 = new() { Value = result?.AdminWard ?? "DefaultWard" };

                _ = Task.Run(async () => { await PostCodeChangedPre.InvokeAsync((postcodeInfo, true)); });
                if (dataObject?.DataProperties != null)
                {
                    var dataPropertiesList = dataObject.DataProperties.ToList();
                    var propertyGuids = new Dictionary<string, Any>
                    {
                        { "14bf36ce-da62-4dc3-b832-dd9b485ff32e", Any.Pack(lat) },
                        { "8bdb4d5c-ebbf-4db3-86e4-1dd33e5b8bba", Any.Pack(lon) },
                        { "6e1793de-70ca-4946-9ae8-487da46889a9", Any.Pack(county) },
                        { "5056c116-88b2-4287-90cb-64f0a3f1ab1d", Any.Pack(addressLine3) },
                        { "41758df6-ab2b-4010-ba0c-a06e43fb10d1", Any.Pack(town) }
                    };

                    foreach (var guid in propertyGuids.Keys)
                    {
                        var property = dataPropertiesList.Find(p => p.EntityPropertyGuid == guid);
                        if (property != null)
                        {
                            property.Value = propertyGuids[guid];
                        }
                    }
                }
            }

            //if (dataObject != null)
            //{
            //    var (message, newDataObject) = await _formHelper?.UpsertDataObject(dataObject, null, false);
            //    if (!string.IsNullOrEmpty(message)) throw new Exception(message);
            //    dataObject = newDataObject;
            //    StateHasChanged();
            //}
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while updating the Postcode.");
            ex.Data.Add("PageMethod", "EditPage/HandlePostcodeUpdated()");
            OnError(ex);
        }
    }

    private void HandleValidationErrors(DataObject newDataObject)
    {
        var ex = new Exception("Validation Error");

        try
        {
            var messageBuilder = new StringBuilder(ex.Message);

            foreach (var validationResult in newDataObject.ValidationResults)
            {
                messageBuilder.AppendLine(validationResult.ToString());
            }
            var exception = new Exception(messageBuilder.ToString());
            exception.Data.Add("MessageType", MessageDisplay.ShowMessageType.Information);
            exception.Data.Add("AdditionalInfo", ex.Message);
            exception.Data.Add("PageMethod", "EditPage/HandleValidationErrors)");
            var _messageBuilder = new StringBuilder(ex.Message);
            _messageBuilder.AppendLine("\r\n" + exception.ToString());
            ex = new Exception(_messageBuilder.ToString());
            OnError(ex);
        }
        catch (Exception e)
        {
            e.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            e.Data.Add("AdditionalInfo", "An error occurred while handling the validation errors.");
            e.Data.Add("PageMethod", "EditPage/HandleValidationErrors()");
            var messageBuilder = new StringBuilder(ex.Message);
            messageBuilder.AppendLine("\r\n" + e.ToString());
            ex = new Exception(messageBuilder.ToString());
            OnError(ex);
        }
    }

    private async Task InitializeParentDataObjectReferenceAsync()
    {
        if (ParentDataObjectReference == null || ParentDataObjectReference.DataObjectGuid == Guid.Empty || ParentDataObjectReference.EntityTypeGuid == Guid.Empty)
        {
            MyDataObjectReference = await PWAFunctions.EnsureDataObjectReferenceAsync(dataObject, MyDataObjectReference);
            ParentDataObjectReference = MyDataObjectReference;
        }
        else
        {
            MyDataObjectReference = ParentDataObjectReference;
        }
    }

    private bool IsPostcodeUpdated(InputUpdatedArgs inputUpdatedArgs, string newValue)
    {
        try
        {
            return inputUpdatedArgs.Dependents.Any() &&
                   inputUpdatedArgs.Dependents[0].ParentEntityPropertyGuid == PostcodePropertyGuid &&
                   newValue != null;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error Checking if Postcode is Updated.");
            ex.Data.Add("PageMethod", "EditPage/IsPostcodeUpdated()");
            OnError(ex);
        }

        return false;
    }

    private bool IsSearchableValue(string value, Guid entityId)
    {
        try
        {
            if (PWAFunctions.IsGuid(value) || PWAFunctions.IsNumber(value))
                return false;

            return true;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error Checking if Value is Searchable.");
            ex.Data.Add("PageMethod", "EditPage/IsSearchableValue()");
            OnError(ex);
        }
        return false;
    }

    private Task Navigate()
    {
        CloseDialogAsync(true);
        HasNavigationRanAlready = false;

        return Task.CompletedTask;
    }

    private async Task OnNavigation(LocationChangingContext context)
    {
        /* ======= OE: CBLD-140 ==============
         * [HasNavigationRanAlready:]
         * Ensures the dialog window is not opened 2x - otherwise,
         * the second dialog would open behind the modal.
         *
         */
        if (HasNavigationRanAlready) return;
        HasNavigationRanAlready = true;

        if (HasChanges)
        {
            if (ParentGuid != Guid.Empty.ToString())
            {
                if (!await this.ShowDialogAsync())
                {
                    HasNavigationRanAlready = true;
                    context.PreventNavigation();
                }
            }
            else
            {
                if (!await this.ShowDialogAsync())
                {
                    /*
                     * Sets the HasNavigationRanAlready to false.
                     * This is important when there is a change but the user clicks cancel in the dialog.
                     *
                     * If not reset, upon clicking "Cancel" in the menu button will not trigger the dialog to show.
                     */
                    context.PreventNavigation();
                    HasNavigationRanAlready = false;
                }
            }
        }
        //CBLD-140: OE - Handling the close here (when no changes are made)
        // instead of in the ButtonMenu.razor.cs file (Line 124).
        else
        {
            await CloseWindow.InvokeAsync();
        }
    }

    private async Task OpenCamera()
    {
        try
        {
            if (string.IsNullOrEmpty(dataObject?.SharePointUrl))
            {
                isPreparingStorageUrl = true; // Start loading indicator
                StateHasChanged(); // Force UI to update
                _formHelper = new API.Client.FormHelper(coreClient, sageIntegrationService, PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString(), userService);
                await _formHelper.LoadMetaDataAsync(IsInformationPage);
                storageUrl = await PWAFunctions.GetStorageUrlAsync(dataObject, _formHelper, storageUrl);
                Console.WriteLine($"Storage URL - {storageUrl}");
                Console.WriteLine("OpenCamera method called");
                isPreparingStorageUrl = false; // Stop loading indicator
                StateHasChanged(); // Force UI to update
            }
            else
            {
                storageUrl = dataObject.SharePointUrl;
            }
            var files = await JsRuntime.InvokeAsync<List<FileModel>>("openCamera", storageUrl);
            Console.WriteLine($"Files received from camera: {files.Count}");

            foreach (var file in files)
            {
                file.StorageUrl = storageUrl; // Assign the storage URL
                if (file.Content != null && file.Content.Length > 0)
                {
                    Console.WriteLine($"Writing file to channel: {file.Name} with storage URL: {storageUrl}");
                    await _fileChannel.Writer.WriteAsync(file);
                }
                else
                {
                    Console.WriteLine($"File {file.Name} has null or empty content. Skipping processing.");
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while opening the camera.");
            ex.Data.Add("PageMethod", "EditPage/OpenCamera()");
            IsLoading = false;
            OnError(ex);
        }
    }

    private async Task OpenGallery()
    {
        try
        {
            if (string.IsNullOrEmpty(dataObject?.SharePointUrl))
            {
                isPreparingStorageUrl = true; // Start loading indicator
                StateHasChanged(); // Force UI to update
                _formHelper = new API.Client.FormHelper(coreClient, sageIntegrationService, PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString(), userService);
                await _formHelper.LoadMetaDataAsync(IsInformationPage);
                storageUrl = await PWAFunctions.GetStorageUrlAsync(dataObject, _formHelper, storageUrl);
                Console.WriteLine($"Storage URL - {storageUrl}");
                Console.WriteLine("OpenGallery method called");
                isPreparingStorageUrl = false; // Stop loading indicator
                StateHasChanged(); // Force UI to update
            }
            else
            {
                storageUrl = dataObject.SharePointUrl;
            }
            var files = await JsRuntime.InvokeAsync<List<FileModel>>("openGallery", storageUrl);
            Console.WriteLine($"Files received from gallery: {files.Count}");
            foreach (var file in files)
            {
                file.StorageUrl = storageUrl; // Assign the storage URL
                Console.WriteLine($"Writing file to channel: {file.Name} with storage URL: {storageUrl}");
                await _fileChannel.Writer.WriteAsync(file);
                NumberOfPhotos = NumberOfPhotos + 1;
                StateHasChanged();
                await Task.Delay(250); // Use await to make it non-blocking
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while opening the gallery.");
            ex.Data.Add("PageMethod", "EditPage/OpenGallery()");
            IsLoading = false;
            OnError(ex);
        }
    }

    private void PerformACanceledState(StateService stateService, string returnUrl)
    {
        if (Windowed)
        {
            // Original windowed behaviour (no change)
            _ = GridUpdated.InvokeAsync();
            _ = CloseWindow.InvokeAsync();
        }
        else
        {
            // Same unified navigation strategy as HandleExitAsync.
            PWAFunctions.ResetStateService(stateService);

            var reference = ParentDataObjectReference ?? new DataObjectReference(string.Empty, string.Empty);

            PWAFunctions.NavigateToCorrectPage(
                NavManager,
                reference,
                returnUrl,
                IsWindowed: false);
        }
    }

    private async Task PrepareFileCount()
    {
        try
        {
            if (string.IsNullOrEmpty(storageUrl))
            {
                storageUrl = await PWAFunctions.GetStorageUrlAsync(dataObject, _formHelper, storageUrl);
            }
            //SB: Work in progress to check for photos in a folder and return the number of photos found
            //OE: CBLD-446
            //if (IsFirstLoad && EntityTypeGuid == "571a9397-7e28-4bef-8ddc-fd4c56787bde" && !string.IsNullOrEmpty(storageUrl))
            if (EntityTypeGuid == "571a9397-7e28-4bef-8ddc-fd4c56787bde" && !string.IsNullOrEmpty(storageUrl))
            {
                IsFirstLoad = false;
                var (message, numberOfPhotos) = await _formHelper.CheckPhotoFilesAtUrl(storageUrl);
                if (string.IsNullOrEmpty(message))
                {
                    Console.WriteLine($"Number of photos found: {numberOfPhotos}");
                    NumberOfPhotos = numberOfPhotos;
                    StateHasChanged();
                }
                else
                {
                    Console.WriteLine($"Error: {message}");
                }
            }
            //StateHasChanged();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while preparing the file count.");
            ex.Data.Add("PageMethod", "EditPage/OnParametersSet()");
            OnError(ex);
        }
    }

    private async Task PrepareStorageUrlAsync()
    {
        if (string.IsNullOrEmpty(storageUrl))
        {
            try
            {
                isPreparingStorageUrl = true; // Start loading indicator
                StateHasChanged(); // Force UI to update

                _formHelper = new API.Client.FormHelper(coreClient, sageIntegrationService, PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString(), userService);
                await _formHelper.LoadMetaDataAsync(IsInformationPage);
                storageUrl = await PWAFunctions.GetStorageUrlAsync(dataObject, _formHelper, storageUrl);
                Console.WriteLine($"Storage URL - {storageUrl}");

                if (string.IsNullOrEmpty(storageUrl))
                {
                    Console.WriteLine("Storage URL is not set. Cannot proceed with file upload.");
                    var ex = new Exception("Storage URL is not set. Cannot proceed with file upload.");
                    ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                    ex.Data.Add("AdditionalInfo", "An error occurred while preparing the storage URL.");
                    ex.Data.Add("PageMethod", "EditPage/PrepareStorageUrlAsync()");
                    OnError(ex);
                    return;
                }
            }
            finally
            {
                isPreparingStorageUrl = false; // Stop loading indicator
                StateHasChanged(); // Force UI to update
            }
        }
    }

    private async Task<DataObject> PrepareUpdateToBindedSelection()
    {
        var message = "";
        var newDataObject = dataObject;
        try
        {
            var oldDataObject = await _formHelper.ReadDataObjectAsync(stateService.OriginalRecordGuid, MyDataObjectReference, false, stateService.OriginalRecordType, modalService);
            if (!string.IsNullOrEmpty(oldDataObject.ErrorReturned))
            {
                throw new Exception(oldDataObject.ErrorReturned);
            }
            if (oldDataObject.DataProperties.Any())
            {
                var entityProperty = oldDataObject.DataProperties.FirstOrDefault(ep => ep.EntityPropertyGuid == stateService.OriginalRecordItem);

                if (entityProperty != null)
                {
                    entityProperty.Value = Any.Pack(new StringValue { Value = (string)stateService.ChildRecordGuid });

                    (message, newDataObject) = await _formHelper.UpsertDataObject(oldDataObject, null, false, IsBulkUpdate);
                }
            }

            if (string.IsNullOrEmpty(message))
            {
                // we can optionally update 'oldDataObject' with 'newDataObject' here oldDataObject= newDataObject;
                return newDataObject;
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while preparing the update to binded selection.");
            ex.Data.Add("PageMethod", "EditPage/PrepareUpdateToBindedSelection()");
            OnError(ex);
        }

        return newDataObject;
    }

    private async Task ReloadDataForNewRecordAsync()
    {
        /*
         * OE: CBLD-500.
         *
         * The function never executed on new grid creation since the only thing we were checking for is if the first GUID in the return URL is an empty GUID.
         * In this case, it was always just "/dev" without any GUID. To tackle this, I added "ReturnUrl.EndsWith("/dev")" to the if condition.
         *
         * This method is specifically for the “new record from grid/dev” scenario:
         * - We want to reload the SAME detail page, but with the new Guid.
         * - We do NOT want to go back to the grid here.
         */
        if (PWAFunctions.IsFirstGuidEmpty(ReturnUrl) || ReturnUrl.EndsWith("/dev"))
        {
            // For non-windowed pages (normal JobDetail/QuoteDetail/etc.) we want to stay on the
            // detail page but swap in the new Guid and keep the existing ReturnUrl.
            if (!Windowed && NewlyCreatedRecordReference != null)
            {
                PWAFunctions.NavigateToNewlyCreatedRecordPage(
                    NavManager,
                    NewlyCreatedRecordReference,
                    ReturnUrl);
            }

            // Handle SharePoint document structure setup if needed
            if (dataObject.HasDocuments && string.IsNullOrEmpty(dataObject.SharePointSiteIdentifier))
            {
                var ex = new Exception("Setting up SharePoint document structure and files. Please wait.")
                {
                    Data =
                {
                    { "PageMethod", dataObject.Label ?? "New Record: " },
                    { "AdditionalInfo", "Setting up SharePoint document structure and files. Please wait." },
                    { "MessageType", MessageDisplay.ShowMessageType.Information }
                }
                };
                OnError(ex);

                await OnInitializedAsync();

                ex = new Exception("SharePoint document structure and files created successfully.")
                {
                    Data =
                {
                    { "PageMethod", dataObject.Label ?? "New Record: " },
                    { "AdditionalInfo", "SharePoint document structure and files created successfully." },
                    { "MessageType", MessageDisplay.ShowMessageType.Success }
                }
                };
                OnError(ex);
            }
            else if (!Windowed)
            {
                // Non-document case: simple reload to ensure the new record state is correct
                await OnInitializedAsync();
            }
        }
    }

    private void ScrollToTop()
    {
        // Scroll to the top of the page
        JsRuntime.InvokeVoidAsync("window.scrollTo", 0, 0);
    }

    private async Task SetupSharePointUrlAsync(bool UpdateSharePoint)
    {
        try
        {
            // Check if the EntityTypeGuid is for the Permissions Record
            if (EntityTypeGuid == "5fe4e4c7-9f14-4853-90d6-ac249c3b6147" && UpdateSharePoint)
            {
                var recordGuid = PWAFunctions.GetRecordGuidFromReturnUrl(ReturnUrl);
                var entityTypeGuid = PWAFunctions.GetEntityTypeGuidFromReturnUrl(ReturnUrl);

                Console.WriteLine($"RecordGuid: {recordGuid}");
                Console.WriteLine($"EntityTypeGuid: {entityTypeGuid}");

                if (!string.IsNullOrEmpty(recordGuid) && !string.IsNullOrEmpty(entityTypeGuid))
                {
                    // Both GUIDs are valid, proceed with SharePoint URL setup
                    Console.WriteLine("Both RecordGuid and EntityTypeGuid are valid.");

                    var originalDataObjectReference = new DataObjectReference(recordGuid, entityTypeGuid);
                    var originalDataObject = await _formHelper.ReadDataObjectAsync(recordGuid, originalDataObjectReference, false, "", modalService, false, UpdateSharePoint);

                    if (!string.IsNullOrEmpty(originalDataObject?.ErrorReturned))
                    {
                        throw new Exception(originalDataObject.ErrorReturned);
                    }

                    if (originalDataObject != null && originalDataObject.HasDocuments)
                    {
                        _formHelper = new API.Client.FormHelper(coreClient, sageIntegrationService, PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString(), userService);
                        await _formHelper.LoadMetaDataAsync(IsInformationPage);

                        storageUrl = await PWAFunctions.GetStorageUrlAsync(originalDataObject, _formHelper, storageUrl, false, UpdateSharePoint);
                        originalDataObject.SharePointUrl = storageUrl;
                        Console.WriteLine($"Storage URL - {storageUrl}");
                    }
                    else
                    {
                        Console.WriteLine("Original DataObject is null or HasDocuments = False.");
                    }
                }
                else
                {
                    Console.WriteLine("One or both GUIDs are invalid.");
                }
            }
            else if (!IsBulkUpdate && dataObject != null &&
                     dataObject.HasDocuments &&
                     (string.IsNullOrEmpty(dataObject.SharePointUrl) || UpdateSharePoint))
            {
                _formHelper = new API.Client.FormHelper(coreClient, sageIntegrationService, PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString(), userService);
                await _formHelper.LoadMetaDataAsync(IsInformationPage);

                storageUrl = await PWAFunctions.GetStorageUrlAsync(dataObject, _formHelper, storageUrl, false, UpdateSharePoint);
                dataObject.SharePointUrl = storageUrl;

                if (_buttonMenuRef != null)
                    await _buttonMenuRef.InitializeButton();

                StateHasChanged();
            }
        }
        catch (Exception ex)
        {
            // Log the exception for debugging purposes
            Console.WriteLine($"Error in SetupSharePointUrlAsync: {ex.Message}");
            Console.WriteLine(ex.StackTrace);
        }
    }

    private Task<bool> ShowDialogAsync()
    {
        _showDialog = true;
        _taskCompletionSource = new();
        // Queue a Render Request
        StateHasChanged();
        // returns the Task associated with the TaskCompletionSource instance this is a running Task
        // that the caller can await
        return _taskCompletionSource.Task;
    }

    private void UpdateBoundDataProperties(DataObject newDataObject)
    {
        try
        {
            foreach (var newDataProperty in newDataObject.DataProperties)
            {
                var boundDataProperty = dataObject.DataProperties.FirstOrDefault(dp =>
                    dp.EntityPropertyGuid == newDataProperty.EntityPropertyGuid);

                if (boundDataProperty is null) continue;

                boundDataProperty.IsInvalid = newDataProperty.IsInvalid;
                boundDataProperty.IsReadOnly = newDataProperty.IsReadOnly;
                boundDataProperty.IsHidden = newDataProperty.IsHidden;
                boundDataProperty.ValidationMessage = newDataProperty.ValidationMessage;
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while updating the bound data properties.");
            ex.Data.Add("PageMethod", "EditPage/UpdateBoundDataProperties()");
            OnError(ex);
        }
    }

    private async Task UpdateDependentPropertiesAsync()
    {
        foreach (var entityProperty in entityProperties)
        {
            var dependants = entityProperty.DependantProperties.ToList();
            if (dependants.Count <= 0) continue;

            foreach (var dataProperty in dependants.Select(dependant => dataObject.DataProperties.FirstOrDefault(p =>
                             p.EntityPropertyGuid == PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(dependant.ParentEntityPropertyGuid).ToString()) ?? new DataProperty()))
            {
                if (dataProperty.Value is not null)
                {
                    await InvokeAsync(() =>
                    {
                        InputUpdatedArgs inputUpdatedArgs = new()
                        {
                            NewValue = dataProperty.Value,
                            Dependents = dependants
                        };
                        flexPropertyGroups.RebindFromPropertyChange(inputUpdatedArgs);
                        StateHasChanged();
                    });
                }
            }
        }
    }

    private void UpdateModalReference()
    {
        var latestModal = modalService.GetLatestModal();
        if (latestModal.HasValue && latestModal.Value.DataObjectReference.EntityTypeGuid == MyDataObjectReference.EntityTypeGuid)
        {
            // Update the DataObjectReference for a modal
            modalService.UpdateModalDataObjectReference(latestModal.Value.ModalId, ParentDataObjectReference);
        }
    }

    /*
        [OE: CBLD-490]
        Updates the stateService reference when creating a new record through the
        square button found next to the combo box.

        This is to ensure that the correct Guids is passed back to the combo box,
        otherwise, it might try and bind an empty Guid.
     */

    private async Task UpdateReferencesAfterSaveAsync()
    {
        MyDataObjectReference = await PWAFunctions.EnsureDataObjectReferenceAsync(dataObject, MyDataObjectReference, "", "", modalService);

        // Initialize NewlyCreatedRecordReference in one step
        NewlyCreatedRecordReference = new DataObjectReference(
            PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObject.Guid).ToString(),
            PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(dataObject.EntityTypeGuid).ToString()
        );

        ParentDataObjectReference = MyDataObjectReference;
        //await ParentDataObjectReferenceChanged.InvokeAsync(ParentDataObjectReference);
    }

    private void UpdateStateServiceReference(DataObject dataObject)
    {
        if (!stateService.IsStateReferenceStackEmpty())
            _ = stateService.UpdateExistingStateReference(dataObject.EntityTypeGuid, dataObject.Guid);
    }

    #endregion Private Methods
}