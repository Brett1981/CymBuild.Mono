using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.Components.Shared.Controls;
using Concursus.Components.Shared.Tracking;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.IdentityModel.Tokens;
using Newtonsoft.Json;
using System.Web;
using Telerik.Blazor.Components;
using Telerik.DataSource;
using static iText.IO.Codec.TiffWriter;
using EntityProperty = Concursus.API.Core.EntityProperty;

namespace Concursus.PWA.Shared;

public partial class ShoreInput
{
    #region Private Fields

    private readonly DateTime _max = new(2050, 12, 31);

    private readonly DateTime _min = new(1950, 1, 1);

    private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();

    private DateTime? _emptyDateTime = new DateTime();

    private Guid _emptyGuid = Guid.Empty;

    private DateTime _lastRepeatableFieldUpdate = DateTime.UtcNow;

    // Byte array for the existing signature (if any)
    private byte[] existingSignature = Array.Empty<byte>();

    private bool isEnabled = true;
    private string ComputedNVarcharMaxCssClass => $"form-control form-control-sm {(DataProperty.IsInvalid ? "is-invalid" : "is-data-valid")}";
    private string ComputedBITCssClass => $"form-check-input {(DataProperty.IsInvalid ? "is-invalid" : "is-data-valid")}";
    private string ComputedBIGINTCssClass => $"form-control form-control-sm @(DataProperty.IsInvalid ? \"is-invalid\" : \"is-data-valid\")";
    private string ComputedSMALLINTCssClass => $"((DataProperty.IsReadOnly || Disabled || EffectiveDisabled))";
    private string ComputedDOUBLECssClass = $"form-control form-control-sm @(DataProperty.IsInvalid ? \"is-invalid\" : \"is-data-valid\")";
    private string ComputedUNIQUEIDENTIFIERCssClass => $"form-control @(DataProperty.IsInvalid ? \"is-invalid\" : \"is-data-valid\")";
    private string ComputedSTRINGCssClass => $"form-control @(DataProperty.IsInvalid ? \"is-invalid\" : \"is-data-valid\")";
    // Ensure this is unique for each modal instance
    private string modalId = Guid.Empty.ToString();

    private string tempValue;
    private User user = new();

    #endregion Private Fields

    // Temporarily stores the textarea value

    #region Public Properties

    [Parameter] public DataProperty DataProperty { get; set; } = new();
    [Parameter] public EventCallback<DataProperty> DataPropertyChanged { get; set; }
    [Parameter] public bool Disabled { get; set; } = false;
    [Parameter] public EntityProperty EntityProperty { get; set; } = new();
    [Parameter] public bool IsMainRecordContext { get; set; } = true;

    private bool EffectiveDisabled =>
        Disabled || (
            EntityProperty.IsReadOnly || (
                DeviceInfoService.IsMobile &&
                IsMainRecordContext &&
                EntityProperty.ShowOnMobile
            )
        );
    public bool HasUnsavedChanges { get; set; } = false;
    public object? InputRef { get; set; }
    [Parameter] public EventCallback<InputUpdatedArgs> InputUpdated { get; set; }

    [Parameter]
    public bool IsBulkEdit { get; set; } = false;

    [Parameter] public EventCallback<Exception> OnError { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public string? RecordGuid { get; set; }

    private Timer _debounceTimer; //OE - 02/01/25: Pertaining to input fix where user has to click off field before save.

    [CascadingParameter] public string CurrentPage { get; set; }


    #endregion Public Properties

    #region Protected Properties

    protected long BigIntValueBinding
    {
        get
        {
            try
            {
                if (DataProperty.Value is null) return 0;
                if (!DataProperty.Value.Is(Int64Value.Descriptor)) return 0;
                DataProperty.Value.TryUnpack(out Int64Value int64Value);
                int64Value ??= new Int64Value { Value = 0 };
                return int64Value.Value;
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in BigIntValueBinding GET.");
                ex.Data.Add("PageMethod", "ShoreInput/BigValueBinding(GET)");
                _ = OnError.InvokeAsync(ex);
            }
            return 0;
        }
        set
        {
            try
            {
                Int64Value int64Value = new() { Value = value };
                DataProperty.Value = Any.Pack(int64Value);

                DataPropertyChanged.InvokeAsync();
                InputUpdated.InvokeAsync(new InputUpdatedArgs
                {
                    NewValue = DataProperty.Value,
                    Dependents = Dependents,
                    EntityId = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataProperty.EntityPropertyGuid)
                });
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in BigIntValueBinding SET.");
                ex.Data.Add("PageMethod", "ShoreInput/BigValueBinding(SET)");
                _ = OnError.InvokeAsync(ex);
            }
            InteractionTracker.Log(NavManager.Uri, $"Field Updated - '{PropertyName}' with value: '{PWAFunctions.UnpackInt64(DataProperty.Value).ToString()}'");
        }
    }

    // Default to enabled, checkbox toggles this
    protected bool BoolValueBinding
    {
        get
        {
            if (DataProperty.Value is not null)
                if (DataProperty.Value.Is(BoolValue.Descriptor))
                {
                    DataProperty.Value.TryUnpack(out BoolValue boolValue);
                    return boolValue.Value;
                }

            return false;
        }
        set
        {
            BoolValue boolValue = new() { Value = value };
            DataProperty.Value = Any.Pack(boolValue);

            DataPropertyChanged.InvokeAsync();
            InputUpdated.InvokeAsync(new InputUpdatedArgs { NewValue = DataProperty.Value, Dependents = Dependents, EntityId = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataProperty.EntityPropertyGuid) });
            InteractionTracker.Log(NavManager.Uri, $"Field Updated - '{PropertyName}' with value: '{PWAFunctions.UnpackBool(DataProperty.Value).ToString()}'");
        }
    }

    protected DateTime? DateTimeValueBinding
    {
        get
        {
            try
            {
                if (DataProperty.Value is not null)
                    if (DataProperty.Value.Is(Timestamp.Descriptor))
                    {
                        DataProperty.Value.TryUnpack(out Timestamp timestampValue);
                        return timestampValue.ToDateTime().ToLocalTime();
                        //return timestampValue.ToDateTime().ToUniversalTime(); //OE: Fix for CBLD-347

                    }
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in DateTimeValueBinding GET.");
                ex.Data.Add("PageMethod", "ShoreInput/DateTimeValueBinding(GET)");
                _ = OnError.InvokeAsync(ex);
            }

            return null; // Return null instead of new DateTime(0) when no valid timestamp is available
        }
        set
        {
            try
            {
                if (value.HasValue)
                {
                    // Correct: treat the user-selected time as local
                    var localTime = DateTime.SpecifyKind(value.Value, DateTimeKind.Local);
                    var utcDateTime = localTime.ToUniversalTime();
                    var timestampValue = Timestamp.FromDateTime(utcDateTime);

                    DataProperty.Value = Any.Pack(timestampValue);

                    DataPropertyChanged.InvokeAsync();
                    InputUpdated.InvokeAsync(new InputUpdatedArgs
                    {
                        NewValue = DataProperty.Value,
                        Dependents = Dependents,
                        EntityId = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataProperty.EntityPropertyGuid)
                    });
                }
                else
                {
                    DataProperty.Value = Any.Pack(new Empty());
                    DataPropertyChanged.InvokeAsync();
                    InputUpdated.InvokeAsync(new InputUpdatedArgs
                    {
                        NewValue = DataProperty.Value,
                        Dependents = Dependents,
                        EntityId = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataProperty.EntityPropertyGuid)
                    });
                }
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in DateTimeValueBinding SET.");
                ex.Data.Add("PageMethod", "ShoreInput/DateTimeValueBinding(SET)");
                _ = OnError.InvokeAsync(ex);
            }
            InteractionTracker.Log(NavManager.Uri, $"Field Updated - '{PropertyName}' with value: '{PWAFunctions.UnpackTimestamp(DataProperty.Value).ToString()}'");
        }
    }

    protected double DoubleValueBinding
    {
        get
        {
            try
            {
                if (DataProperty.Value is null) return 0;
                if (!DataProperty.Value.Is(DoubleValue.Descriptor)) return 0;
                DataProperty.Value.TryUnpack(out DoubleValue doubleValue);

                doubleValue ??= new DoubleValue { Value = 0 };
                return doubleValue.Value;
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in DoubleValueBinding GET.");
                ex.Data.Add("PageMethod", "ShoreInput/DoubleValueBinding(GET)");
                _ = OnError.InvokeAsync(ex);
            }

            return 0;
        }
        set
        {
            try
            {
                DoubleValue doubleValue = new() { Value = value };
                DataProperty.Value = Any.Pack(doubleValue);

                DataPropertyChanged.InvokeAsync();
                InputUpdated.InvokeAsync(new InputUpdatedArgs { NewValue = DataProperty.Value, Dependents = Dependents, EntityId = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataProperty.EntityPropertyGuid) });
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in DoubleValueBinding SET.");
                ex.Data.Add("PageMethod", "ShoreInput/DoubleValueBinding(SET)");
                _ = OnError.InvokeAsync(ex);
            }
            InteractionTracker.Log(NavManager.Uri, $"Field Updated - '{PropertyName}' with value: '{PWAFunctions.UnpackDouble(DataProperty.Value).ToString()}'");
        }
    }

    protected Guid GuidValueBinding
    {
        get
        {
            try
            {
                /*
                     [OE:CBLD-260]
                     This section ensures that when the batch window is loaded, the SurveyorID/Assignee
                     field does not automatically source the current user - instead, it remains empty.
                 */
                if (IsBulkEdit && HideCurrentUserOnFirstRender)
                {
                    if (DataProperty.EntityPropertyGuid == "5db26018-e002-4412-b04f-d3737a749836") //SurveyorID
                    {
                        return Guid.Empty;
                    }
                }

                if (DataProperty.Value is null) return Guid.Empty;
                if (!DataProperty.Value.Is(StringValue.Descriptor)) return Guid.Empty;
                DataProperty.Value.TryUnpack(out StringValue stringValue);
                return PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(stringValue.Value);
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in GuidValueBinding GET.");
                ex.Data.Add("PageMethod", "ShoreInput/GuidValueBinding(GET)");
                _ = OnError.InvokeAsync(ex);
            }

            return Guid.Empty;
        }
        set
        {
            try
            {
                /*
                    [OE:CBLD-260]
                    Here, we reset the flag that ensures the Assignee field is set to empty.
                    For this to happen, the user just needs to select a value & it will be shown in the window.
                */
                if (IsBulkEdit)
                {
                    if (DataProperty.EntityPropertyGuid == "5db26018-e002-4412-b04f-d3737a749836") //SurveyorID
                    {
                        HideCurrentUserOnFirstRender = false;
                    }
                }
                StringValue stringValue = new() { Value = value.ToString() };
                DataProperty.Value = Any.Pack(stringValue);

                DataPropertyChanged.InvokeAsync();
                InputUpdated.InvokeAsync(new InputUpdatedArgs { NewValue = DataProperty.Value, Dependents = Dependents, EntityId = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataProperty.EntityPropertyGuid) });
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in GuidValueBinding SET.");
                ex.Data.Add("PageMethod", "ShoreInput/GuidValueBinding(SET)");
                _ = OnError.InvokeAsync(ex);
            }
            InteractionTracker.Log(NavManager.Uri, $"Field Updated - '{PropertyName}' with value: '{PWAFunctions.UnpackString(DataProperty.Value).ToString()}'");
        }
    }

    protected int IntValueBinding
    {
        get
        {
            try
            {
                if (DataProperty.Value is null) return 0;
                if (!DataProperty.Value.Is(Int32Value.Descriptor)) return 0;
                DataProperty.Value.TryUnpack(out Int32Value int32Value);
                int32Value ??= new Int32Value { Value = 0 };
                return int32Value.Value;
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in IntValueBinding GET.");
                ex.Data.Add("PageMethod", "ShoreInput/IntValueBinding(GET)");
                _ = OnError.InvokeAsync(ex);
            }
            return 0;
        }
        set
        {
            try
            {
                Int32Value int32Value = new() { Value = value };
                DataProperty.Value = Any.Pack(int32Value);

                DataPropertyChanged.InvokeAsync();
                InputUpdated.InvokeAsync(new InputUpdatedArgs { NewValue = DataProperty.Value, Dependents = Dependents, EntityId = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataProperty.EntityPropertyGuid) });
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in IntValueBinding SET.");
                ex.Data.Add("PageMethod", "ShoreInput/IntValueBinding(SET)");
                _ = OnError.InvokeAsync(ex);
            }
            InteractionTracker.Log(NavManager.Uri, $"Field Updated - '{PropertyName}' with value: '{PWAFunctions.UnpackInt32(DataProperty.Value).ToString()}'");
        }
    }

    protected string? StringValueBinding
    {
        get
        {
            try
            {
                if (DataProperty.Value is null) return "";
                if (!DataProperty.Value.Is(StringValue.Descriptor)) return "";
                DataProperty.Value.TryUnpack(out StringValue stringValue);

                return EntityProperty.IsUpperCase ? stringValue.Value.ToUpper() : stringValue.Value;
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in StringValueBinding GET.");
                ex.Data.Add("PageMethod", "ShoreInput/StringValueBinding(GET)");
                _ = OnError.InvokeAsync(ex);
            }
            return "";
        }
        set
        {
            try
            {
                value = EntityProperty.IsUpperCase ? value?.ToUpper() : value;

                StringValue stringValue = new() { Value = value };

                DataProperty.Value = Any.Pack(stringValue);
                DataProperty.EntityPropertyGuid = EntityProperty.Guid;

                DataPropertyChanged.InvokeAsync(DataProperty);

                var thisUpdate = DateTime.UtcNow;
                _ = PausedStringUpdateNotificationAsync(thisUpdate).ConfigureAwait(true);

            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in StringValueBinding SET.");
                ex.Data.Add("PageMethod", "ShoreInput/StringValueBinding(SET)");
                _ = OnError.InvokeAsync(ex);
            }
            InteractionTracker.Log(NavManager.Uri, $"Field Updated - '{PropertyName}' with value: '*****Value Hidden*****'");
        }
    }

    #endregion Protected Properties

    #region Private Properties

    private TrackableTelerikComboBox<ComboDataItem, Guid>? Combo = new ();

    private int DebounceDelay { get; set; } = 100;
    private List<EntityPropertyDependant> Dependents { get; set; } = new();
    private bool HideCurrentUserOnFirstRender { get; set; } = true;
    private string InputType { get; set; } = "Text";

    private bool ModalIsVisible { get; set; } = false;

    private TelerikWindow? ModalWindow { get; set; }

    [CascadingParameter] private FlexPropertyGroup Parent { get; set; } = new();

    private string? ParentGuid { get; set; } = Guid.Empty.ToString();

    private string Placeholder { get; set; } = "";

    private string PropertyId { get; set; } = "";

    private string PropertyName { get; set; } = "";

    private string StepValue
    {
        get
        {
            try
            {
                // Calculate the step value based on entityProperty.Scale
                if (EntityProperty.Scale == 0)
                    return "1"; // Default step value if scale is 0
                return $"0.{new string('0', EntityProperty.Scale - 1)}1";
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "Error in StepValue GET.");
                ex.Data.Add("PageMethod", "ShoreInput/StepValue(GET)");
                _ = OnError.InvokeAsync(ex);
            }

            return "1";
        }
    }

    private bool WindowIsClosable { get; set; } = true;

    private bool WindowIsVisible { get; set; } = false;

    private string? WindowTitle { get; set; }

    #endregion Private Properties

    #region Public Methods

    public void RebindFromPropertyChange(InputUpdatedArgs inputUpdatedArgs)
    {
        try
        {
            // Step 1: Ensure this input has a dependent relationship
            var isDependent = inputUpdatedArgs.Dependents.Any(d =>
                PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(d.DependantEntityPropertyGuid) ==
                PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityProperty.Guid));

            if (!isDependent)
                return;

            // Step 2: Safely unpack the new value and parse as Guid
            if (inputUpdatedArgs.NewValue != null &&
                inputUpdatedArgs.NewValue.Is(StringValue.Descriptor) &&
                inputUpdatedArgs.NewValue.TryUnpack(out StringValue stringValue) &&
                Guid.TryParse(stringValue.Value, out Guid parsedGuid) &&
                parsedGuid != Guid.Empty)
            {
                ParentGuid = parsedGuid.ToString();
            }
            else
            {
                ParentGuid = Guid.Empty.ToString();
            }

            // Step 3: Rebind combo only when ParentGuid has changed meaningfully
            Combo.Rebind();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in RebindFromPropertyChange.");
            ex.Data.Add("PageMethod", "ShoreInput/RebindFromPropertyChange()");
            _ = OnError.InvokeAsync(ex);
        }
    }
    #endregion Public Methods

    #region Protected Methods

    protected void CloseWindow()
    {
        object? value;
        try
        {
            if (_detailPageParameters.TryGetValue("ModalId", out value))
            {
                if (value is string modalId)
                {
                    modalService.UnregisterModal(modalId);
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in CloseWindow().");
            ex.Data.Add("PageMethod", "ShoreInput/CloseWindow()");
            _ = OnError.InvokeAsync(ex);
        }

        WindowIsVisible = false;
        ModalIsVisible = false;
        RebindComboBox();
    }

    protected void HandleModelOnClick()
    {
        if (ModalIsVisible) return; // Prevent modal from being re-registered
        try
        {
            string serializeParentDataObjectReferenced = HttpUtility.UrlEncode(JsonConvert.SerializeObject(ParentDataObjectReference ?? new DataObjectReference("", ""))); ;
            if (ParentDataObjectReference == null || (ParentDataObjectReference.EntityTypeGuid == Guid.Empty)
                && ParentDataObjectReference.DataObjectGuid == Guid.Empty)
            {
                try
                {
                    ParentDataObjectReference = new DataObjectReference(ParentGuid, EntityProperty.ForeignEntityTypeGuid);
                    serializeParentDataObjectReferenced = HttpUtility.UrlEncode(JsonConvert.SerializeObject(ParentDataObjectReference));
                }
                catch (Exception ex)
                {
                    Console.WriteLine(ex);
                }
            }
            //Get new ModalId, add it to Parameter and register it
            modalId = Guid.NewGuid().ToString();
            _detailPageParameters.Clear();
            _detailPageParameters.Add("EntityTypeGuid", EntityProperty.ForeignEntityTypeGuid);
            _detailPageParameters.Add("Windowed", true);
            _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
            _detailPageParameters.Add("RecordGuid",
                PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(GuidValueBinding.ToString()).ToString());
            _detailPageParameters.Add("SerializedDataObjectReference", serializeParentDataObjectReferenced);
            _detailPageParameters.Add("ParentDataObjectReference", ParentDataObjectReference);
            _detailPageParameters.Add("PassedEntityProperty",
                EntityProperty); //this will be the Object that needs populating
            _detailPageParameters.Add("ReturnUrl", NavManager.Uri);
            _detailPageParameters.Add("IsInformationPage", true);
            _detailPageParameters.Add("ModalId", modalId);

            modalService.RegisterModal(modalId, ParentDataObjectReference);
            //Set Window Title to Information
            WindowTitle = "Information";
            ModalIsVisible = true;
            InteractionTracker.Log(NavManager.BaseUri, $"Info Button Clicked - '{PropertyName}' New Modal Opened For EntityTypeGuid: '{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityProperty.ForeignEntityTypeGuid.ToString()).ToString()}' RecordGuid: {PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(GuidValueBinding.ToString()).ToString()}");

        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in HandleModelOnClick().");
            ex.Data.Add("PageMethod", "ShoreInput/HandleModelOnClick()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    protected void NavigateToDetailPage()
    {
        try
        {
            //Below is the code to get the ParentDataObjectReference and make sure it is set with the latest Modal windows saved details
            var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, ParentGuid, EntityProperty.ForeignEntityTypeGuid);
            var detailPageUri = EntityProperty.DetailPageUri == "DynamicEdit"
                ? $"{EntityProperty.DetailPageUri}/{PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityProperty.ForeignEntityTypeGuid).ToString()}/{GuidValueBinding}/{serializedParentDataObjectReference}/{HttpUtility.UrlEncode(NavManager.Uri)}"
                : $"{EntityProperty.DetailPageUri}/{GuidValueBinding}/{serializedParentDataObjectReference}/{HttpUtility.UrlEncode(NavManager.Uri)}";
            InteractionTracker.Log(NavManager.BaseUri, $"Button Clicked - '{PropertyName}' New Page Opened: '{detailPageUri}'");
            NavManager.NavigateTo(detailPageUri);

        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in NavigateToDetailPage().");
            ex.Data.Add("PageMethod", "ShoreInput/NavigateToDetailPage()");
            _ = OnError.InvokeAsync(ex);
        }

    }

    protected override void OnAfterRender(bool firstRender)
    {
        base.OnAfterRender(firstRender);
    }

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            Parent.ChildInputs.Add(this);
            // Get User of Selected Record When in Settings --> Users --> User
            // Record
            if (EntityProperty.EntityTypeGuid == "b123cd82-291e-4dd2-8bb4-c9e51302786d" && RecordGuid != "00000000-0000-0000-0000-000000000000")
            {
                //2BB6F3F2-5BC3-48BD-8752-518EF7AEA3DB = AHall
                var userRequest = new UserGetByGuidRequest { Guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(RecordGuid).ToString() };
                var resp = await CoreClient.UserGetByGuidAsync(userRequest);
                if (resp != null)
                {
                    user = resp.User;
                    existingSignature = user.Signature.ToByteArray();
                }
            }
        }
        await base.OnAfterRenderAsync(firstRender);
    }

    protected override async Task OnInitializedAsync()
    {
        try
        {
            PropertyId = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityProperty.Guid).ToString();
            PropertyName = EntityProperty.Label;
            Placeholder = EntityProperty.Label;
            Dependents = EntityProperty.DependantProperties.ToList();

            await base.OnInitializedAsync();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in OnInitializedAsync().");
            ex.Data.Add("PageMethod", "ShoreInput/OnInitializedAsync()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    protected async Task PausedStringUpdateNotificationAsync(DateTime updateTime)
    {
        try
        {
            //if (updateTime > _lastRepeatableFieldUpdate.AddSeconds(0.5))
            //{
                _= InputUpdated.InvokeAsync(new InputUpdatedArgs
                { NewValue = DataProperty.Value, Dependents = Dependents, EntityId = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataProperty.EntityPropertyGuid) });
                _lastRepeatableFieldUpdate = updateTime;
            //}
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in PausedStringUpdateNotificationAsync().");
            ex.Data.Add("PageMethod", "ShoreInput/PausedStringUpdateNotificationAsync()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    protected void SetDefaultWindowParameters()
    {
        try
        {
            //Below is the code to get the ParentDataObjectReference and make sure it is set with the latest Modal windows saved details
            var (parentDataObjectReference, serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, ParentGuid, EntityProperty.ForeignEntityTypeGuid);

            //Get new ModalId, add it to Parameter and register it
            modalId = Guid.NewGuid().ToString();
            _detailPageParameters.Clear();
            _detailPageParameters.Add("EntityTypeGuid",
                PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityProperty.ForeignEntityTypeGuid).ToString());
            _detailPageParameters.Add("Windowed", true);
            _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
            _detailPageParameters.Add("RecordGuid", Guid.Empty.ToString());
            _detailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
            _detailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
            _detailPageParameters.Add("ReturnUrl", NavManager.Uri);
            _detailPageParameters.Add("ModalId", modalId);

            modalService.RegisterModal(modalId, parentDataObjectReference);
            WindowIsVisible = true;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in SetDefaultWindowParameters().");
            ex.Data.Add("PageMethod", "ShoreInput/SetDefaultWindowParameters()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    protected void SetDetailWindowParameters()
    {
        try
        {
            if (WindowIsVisible) return;  // Prevent unnecessary StateHasChanged calls

            // Validate ParentDataObjectReference and ParentGuid
            if (string.IsNullOrEmpty(ParentDataObjectReference?.DataObjectGuid.ToString()) || string.IsNullOrEmpty(ParentGuid))
            {
                Console.WriteLine("ParentDataObjectReference or ParentGuid is null or empty.");
                throw new Exception("Parent record information is missing.");
            }

            // Validate EntityProperty
            if (EntityProperty == null || string.IsNullOrEmpty(EntityProperty.DetailPageUri))
            {
                Console.WriteLine("EntityProperty or DetailPageUri is null.");
                throw new Exception("Entity property details are missing.");
            }

            // Verify Dynamic Component Type
            var componentType = System.Type.GetType($"Concursus.PWA.Pages.{EntityProperty.DetailPageUri}");
            if (componentType == null)
            {
                Console.WriteLine($"Component not found for URI: {EntityProperty.DetailPageUri}");
                throw new Exception($"Component not found for {EntityProperty.DetailPageUri}");
            }

            // Get ParentDataObjectReference and ensure it's up-to-date
            var (parentDataObjectReference, serializedParentDataObjectReference) =
                PWAFunctions.ProcessDataObjectReference(modalService, ParentDataObjectReference, ParentGuid, EntityProperty.ForeignEntityTypeGuid);

            // Generate new ModalId
            modalId = Guid.NewGuid().ToString();
            _detailPageParameters.Clear();
            _detailPageParameters.Add("EntityTypeGuid", EntityProperty.ForeignEntityTypeGuid);
            _detailPageParameters.Add("Windowed", true);
            _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
            _detailPageParameters.Add("RecordGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(GuidValueBinding.ToString()).ToString());
            _detailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
            _detailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
            _detailPageParameters.Add("PassedEntityProperty", EntityProperty);
            _detailPageParameters.Add("ReturnUrl", NavManager.Uri);
            _detailPageParameters.Add("ModalId", modalId);

            // Register Modal
            modalService.RegisterModal(modalId, parentDataObjectReference);
            if (string.IsNullOrEmpty(modalId))
            {
                Console.WriteLine("Modal ID is null or empty.");
                throw new Exception("Modal registration failed.");
            }

            // Set State and Make Window Visible
            stateService.AddNewStateReference(EntityProperty.ForeignEntityTypeGuid, GuidValueBinding.ToString());
            stateService.OriginalRecordItem = EntityProperty.Guid;

            if (!WindowIsVisible)
            {
                Console.WriteLine("Making modal window visible.");
                WindowIsVisible = true;

                if (!WindowIsVisible)
                {
                    InvokeAsync(StateHasChanged);
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in SetDetailWindowParameters().");
            ex.Data.Add("PageMethod", "ShoreInput/SetDetailWindowParameters()");
            Console.WriteLine($"Exception: {ex.Message}");
            _ = OnError.InvokeAsync(ex);
        }
    }



    #endregion Protected Methods

    #region Private Methods
    private double ParseStepValue(string? value)
    {
        return double.TryParse(value, out var result) ? result : 1.0;
    }

    private Guid ParseGuid(string? input)
    {
        return Guid.TryParse(input, out var result) ? result : Guid.Empty;
    }
    private void OnLeaveHandler(string fieldName, object? newValue)
    {
        InteractionTracker.Log(CurrentPage, $"Left field '{fieldName}' with value: '{newValue}'");
    }
    private async Task HandleOnBlur(FocusEventArgs e)
    {
        try
        {
            StringValueBinding = tempValue;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in HandleOnBlur().");
            ex.Data.Add("PageMethod", "ShoreInput/HandleOnChange()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    private void HandleOnChange(ChangeEventArgs args)
    {
        try
        {
            if (args.Value is not null)
            {
                tempValue = args.Value.ToString();

                /*
                 * OE - CBLD-501: 02/01/2025
                 * Debouncer is used to prevent the StringValueBinding executing every time the user presses a key
                 * as this would cause noticable delay between the characters showing up the screen.
                 *
                 * Instead, we wate 500ms before we do the updates.
                 */
                if (_debounceTimer != null)
                {
                    _debounceTimer.Dispose();
                }

                _debounceTimer = new Timer(async _ =>
                {
                    StringValueBinding = tempValue;
                }, null, 500, Timeout.Infinite); // Debounce by 300ms

            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in HandleOnChange().");
            ex.Data.Add("PageMethod", "ShoreInput/HandleOnChange()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    private void HandleOnClick()
    {
        try
        {
            // Set Window Title to ""
            WindowTitle = "";
            dynamic result = PWAFunctions.UnPackGoogleProtoBufTypes(DataProperty.Value);
            if (result is not null || result is not Empty || result != "00000000-0000-0000-0000-000000000000")
            {
                result = "00000000-0000-0000-0000-000000000000";
            }
            if (EntityProperty.DropDownListDefinitionGuid == Guid.Empty.ToString())
                // No DropDownListDefinitionGuid, open window with default
                // parameters
                SetDefaultWindowParameters();
            else if (EntityProperty.IsDetailWindowed || EntityProperty.RowStatus == 0)
                // Open window with custom parameters
                SetDetailWindowParameters();
            else
                // Navigate to the appropriate page
                NavigateToDetailPage();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in HandleOnClick().");
            ex.Data.Add("PageMethod", "ShoreInput/HandleOnClick()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    private void HandleSignatureCleared()
    {
        existingSignature = Array.Empty<byte>();  // Clear the existing signature
        Console.WriteLine("Signature has been cleared.");
    }

    private void HandleSignatureSaved(byte[] signatureBytes)
    {
        // Handle the saved signature, e.g., save to the database
        existingSignature = signatureBytes;  // Capture the newly saved signature
        Console.WriteLine($"Signature saved. Size: {signatureBytes.Length} bytes");
    }

    private async Task OnPickerChangeAsync(DateTime? newValue)
    {
        try
        {
            var newDate = (DateTime?)newValue;

            if (newDate.HasValue)
            {
                if (newDate.Value.Ticks == 0)
                {
                    await Task.Yield();
                    DateTimeValueBinding = null;
                }
                else
                {
                    // Normalize if midnight
                    var safeDate = UiFormattingHelper.EnsureNoUtcRollback(newDate.Value);
                    DateTimeValueBinding = safeDate;
                }
            }
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in OnPickerChangeAsync().");
            ex.Data.Add("PageMethod", "ShoreInput/OnPickerChangeAsync()");
            _ = OnError.InvokeAsync(ex);
        }
    }


    private async Task ReadItemsAsync(ComboBoxReadEventArgs args)
    {
        try
        {
            var dropDownDataListRequest = new DropDownDataListRequest
            {
                Guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityProperty.DropDownListDefinitionGuid)
                    .ToString(),
                ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString(),
                RecordGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(RecordGuid).ToString(),
                CurrentSelectedValueGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(GuidValueBinding.ToString())
                    .ToString()
            };

            if (args.Request.Filters.Count > 0)
            {
                var compositeFilter = new DataObjectCompositeFilter
                {
                    LogicalOperator = FilterOperator.Contains.ToString()
                };

                foreach (var filterDescriptor in args.Request.Filters)
                {
                    var filter = filterDescriptor as FilterDescriptor;
                    var userInput = filter?.Value.ToString();
                    var method = filter?.Operator.ToString();

                    var filterItem = new DataObjectFilter
                    {
                        Guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityProperty.DropDownListDefinitionGuid)
                            .ToString(),
                        Value = new Value { StringValue = userInput },
                        Operator = method,
                        ColumnName = EntityProperty.DropDownListDefinition.NameColumn,
                        DataType = "string"
                    };

                    compositeFilter.Filters.Add(filterItem);
                }

                dropDownDataListRequest.Filters.Add(compositeFilter);
            }
            var dropDownDataListReply = await CoreClient.DropDownDataListAsync(dropDownDataListRequest);

            args.Data = dropDownDataListReply.Items
                .Select(item => new ComboDataItem(item))
                .ToList();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in ReadItemsAsync().");
            ex.Data.Add("PageMethod", "ShoreInput/ReadItemsAsync()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    /* OE - CBLD-336 & CBLD-362 fix
     * Problem: The combo box gets reset when 2 modals (nested) get opened,
     * but they are both closed when the 'x' button gets clicked.
     *
     * Why?: RebindComboBox() calls Combo.ValueChanged.InvokeAsync which works
     * perfectly when there is an actual change in value for the combo box.
     *
     * **/

    private void RebindComboBox()
    {
        try
        {
            //OE: CBLD-483: Get the LATEST reference.
            var currentContextVal = stateService.GetContextReference();
            if (ParentGuid == Guid.Empty.ToString())
                ParentGuid = (string)stateService.OriginalRecordGuid;

            // [DEPRECATED] -->    //OE: Fix for CBLD-362
            //if (stateService.ChildRecordGuid != Guid.Empty.ToString()) //Only execute if the Guid != Guid.Empty.
            //    //Combo.ValueChanged.InvokeAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(GuidValueBinding.ToString()));

            if (currentContextVal != null && currentContextVal["OriginalRecordGuid"] != Guid.Empty.ToString())
            {
                Combo.ValueChanged.InvokeAsync(PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(currentContextVal["OriginalRecordGuid"]));
            }

            Combo.Rebind();

            PWAFunctions.ResetStateService(stateService);
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error in RebindComboBox().");
            ex.Data.Add("PageMethod", "ShoreInput/RebindComboBox()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    private void WindowVisibleChangedHandler(bool currVisible)
    {
        if (WindowIsClosable)
        {
            WindowIsVisible = currVisible; // if you don't do this, the window won't close because of the user action
            ModalIsVisible = currVisible; // if you don't do this, the window won't close because of the user action
        }
        else
        {
            Console.WriteLine("The user tried to close the window but the code didn't let them");
        }
    }

    #endregion Private Methods
}