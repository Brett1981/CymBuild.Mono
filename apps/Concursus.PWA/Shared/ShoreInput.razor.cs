using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.JSInterop;
using Newtonsoft.Json;
using System.Globalization;
using System.Web;
using EntityProperty = Concursus.API.Core.EntityProperty;

namespace Concursus.PWA.Shared;

public partial class ShoreInput : IDisposable
{
    #region Private Fields

    private readonly Guid _componentInstanceGuid = Guid.NewGuid();

    private readonly DateTime _max = new(2050, 12, 31);

    private readonly DateTime _min = new(1950, 1, 1);

    private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();

    private DateTime? _emptyDateTime = new DateTime();

    private Guid _emptyGuid = Guid.Empty;

    private DateTime _lastRepeatableFieldUpdate = DateTime.UtcNow;

    // Byte array for the existing signature (if any)
    private byte[] existingSignature = Array.Empty<byte>();

    private bool isEnabled = true;

    // Ensure this is unique for each modal instance
    private string modalId = Guid.Empty.ToString();

    private string tempValue;
    private User user = new();

    #endregion Private Fields

    // Temporarily stores the textarea value

    #region Public Properties
    [Parameter] public Dictionary<string, Any> TransientVirtualProperties { get; set; } = new();
    [Parameter] public DataProperty DataProperty { get; set; } = new();
    [Parameter] public EventCallback<DataProperty> DataPropertyChanged { get; set; }
    [Parameter] public bool Disabled { get; set; } = false;
    [Parameter] public EntityProperty EntityProperty { get; set; } = new();
    [Parameter] public bool IsMainRecordContext { get; set; } = true;
    [Parameter] public FormHelper? FormHelper { get; set; }
    [CascadingParameter] public EditPage? ParentEditPage { get; set; }

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
    [Parameter] public string? ReturnUrl { get; set; }
    [Parameter] public EventCallback<Exception> OnError { get; set; }
    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; } = new("", "");
    [Parameter] public string? RecordGuid { get; set; }

    private Timer? _debounceTimer; //OE - 02/01/25: Pertaining to input fix where user has to click off field before save.

    private bool _isRegisteredWithParent;

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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in BigIntValueBinding GET.";
                ex.Data["PageMethod"] = "ShoreInput/BigValueBinding(GET)";
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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in BigIntValueBinding SET.";
                ex.Data["PageMethod"] = "ShoreInput/BigValueBinding(SET)";
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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in DateTimeValueBinding GET.";
                ex.Data["PageMethod"] = "ShoreInput/DateTimeValueBinding(GET)";
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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in DateTimeValueBinding SET.";
                ex.Data["PageMethod"] = "ShoreInput/DateTimeValueBinding(SET)";
                _ = OnError.InvokeAsync(ex);
            }
            var dateLogValue = value.HasValue
                ? value.Value.ToString("dd MMM yyyy HH:mm", CultureInfo.InvariantCulture)
                : string.Empty;

            InteractionTracker.Log(NavManager.Uri, $"Field Updated - '{PropertyName}' with value: '{dateLogValue}'");
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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in DoubleValueBinding GET.";
                ex.Data["PageMethod"] = "ShoreInput/DoubleValueBinding(GET)";
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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in DoubleValueBinding SET.";
                ex.Data["PageMethod"] = "ShoreInput/DoubleValueBinding(SET)";
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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in GuidValueBinding GET.";
                ex.Data["PageMethod"] = "ShoreInput/GuidValueBinding(GET)";
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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in GuidValueBinding SET.";
                ex.Data["PageMethod"] = "ShoreInput/GuidValueBinding(SET)";
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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in IntValueBinding GET.";
                ex.Data["PageMethod"] = "ShoreInput/IntValueBinding(GET)";
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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in IntValueBinding SET.";
                ex.Data["PageMethod"] = "ShoreInput/IntValueBinding(SET)";
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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in StringValueBinding GET.";
                ex.Data["PageMethod"] = "ShoreInput/StringValueBinding(GET)";
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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in StringValueBinding SET.";
                ex.Data["PageMethod"] = "ShoreInput/StringValueBinding(SET)";
                _ = OnError.InvokeAsync(ex);
            }
            InteractionTracker.Log(NavManager.Uri, $"Field Updated - '{PropertyName}' with value: '*****Value Hidden*****'");
        }
    }

    #endregion Protected Properties

    #region Private Properties

    private int _lookupRefreshKey;
private int DebounceDelay { get; set; } = 100;
    private List<EntityPropertyDependant> Dependents { get; set; } = new();
    private bool HideCurrentUserOnFirstRender { get; set; } = true;

    // Phase 4B performance: Telerik ComboBox invokes OnRead during initial rendering even when
    // the lookup has no selected value and the user has not opened/searched it yet. In that case
    // the page only needs to render an empty field, not hydrate the top 10 options for every lookup.
    // Once the user focuses/clicks the lookup, the component allows the normal OnRead flow and
    // explicitly rebinds the combo so behaviour is preserved when the dropdown is actually used.
    private bool _lookupHasUserRequestedData;
    private bool _lookupInitialEmptyReadDeferred;

    private string InputType { get; set; } = "Text";

    private bool ModalIsVisible { get; set; } = false;

    private bool NativeModalIsMaximized { get; set; }

    private string NativeModalCardCss => NativeModalIsMaximized
        ? "shore-input-modal-card is-maximized"
        : "shore-input-modal-card";

    private System.Type? DetailPageComponentType => ResolvePageComponentType(EntityProperty?.DetailPageUri);

    private System.Type? InformationPageComponentType => ResolvePageComponentType(EntityProperty?.InformationPageUri);

    [CascadingParameter] private FlexPropertyGroup Parent { get; set; } = new();

    private string? ParentGuid { get; set; } = Guid.Empty.ToString();

    private string Placeholder { get; set; } = "";

    private string PropertyId { get; set; } = "";

    private string DatePickerId => $"{PropertyId}-date";

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
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "Error in StepValue GET.";
                ex.Data["PageMethod"] = "ShoreInput/StepValue(GET)";
                _ = OnError.InvokeAsync(ex);
            }

            return "1";
        }
    }

    private bool WindowIsClosable { get; set; } = true;

    private bool WindowIsVisible { get; set; } = false;

    private string? WindowTitle { get; set; }

    #endregion Private Properties

    // BEGIN 14S-R18 metadata tooltip helpers
    private string LabelTooltip => BuildLabelTooltip();

    private string ValueTooltip => BuildValueTooltip();

    private string BuildLabelTooltip()
    {
        var helpText = GetEntityPropertyTextValue(
            EntityProperty,
            "HelpText",
            "LanguageLabelHelpText",
            "LanguageLabelTranslationHelpText",
            "LanguageLabelTranslation.HelpText",
            "LanguageLabel.HelpText");

        if (!string.IsNullOrWhiteSpace(helpText))
        {
            return CleanTooltipText(helpText);
        }

        var label = GetEntityPropertyTextValue(
            EntityProperty,
            "Label",
            "LanguageLabel",
            "LanguageLabelTranslation.Value",
            "LanguageLabelTranslation.Label",
            "LanguageLabel.Name");

        if (!string.IsNullOrWhiteSpace(label))
        {
            return CleanTooltipText(label);
        }

        if (!string.IsNullOrWhiteSpace(PropertyName))
        {
            return CleanTooltipText(PropertyName);
        }

        return CleanTooltipText(EntityProperty?.Name);
    }

    private string BuildValueTooltip()
    {
        try
        {
            if (EntityProperty == null)
            {
                return string.Empty;
            }

            // Lookup selected display text is owned by ShoreLookupInput and rendered there as the tooltip.
            // Returning empty here avoids showing the stored Guid when hovering between lookup pieces.
            if (IsLookupEntityProperty())
            {
                return string.Empty;
            }

            var dataTypeName = EntityProperty.EntityDataTypeName?.Trim() ?? string.Empty;

            return dataTypeName.ToUpperInvariant() switch
            {
                "BIT" => BoolValueBinding ? "True" : "False",
                "DATE" or "DATETIME2" => DateTimeValueBinding.HasValue
                    ? DateTimeValueBinding.Value.ToString("dd MMM yyyy HH:mm", CultureInfo.InvariantCulture)
                    : string.Empty,
                "INT" or "SMALLINT" or "TINYINT" => IntValueBinding.ToString(CultureInfo.InvariantCulture),
                "BIGINT" => BigIntValueBinding.ToString(CultureInfo.InvariantCulture),
                "DOUBLE" or "DECIMAL" or "MONEY" => DoubleValueBinding.ToString(CultureInfo.InvariantCulture),
                "UNIQUEIDENTIFIER" => GuidValueBinding == Guid.Empty ? string.Empty : GuidValueBinding.ToString(),
                _ => CleanTooltipText(StringValueBinding)
            };
        }
        catch
        {
            return string.Empty;
        }
    }

    private bool IsLookupEntityProperty()
    {
        return !string.IsNullOrWhiteSpace(EntityProperty?.DropDownListDefinitionGuid)
            && EntityProperty.DropDownListDefinitionGuid != Guid.Empty.ToString();
    }

    private static string CleanTooltipText(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        return string.Join(
            " ",
            value.Split(new[] { ' ', '\r', '\n', '\t' }, StringSplitOptions.RemoveEmptyEntries));
    }

    private static string GetEntityPropertyTextValue(object? source, params string[] propertyPaths)
    {
        foreach (var propertyPath in propertyPaths)
        {
            var value = GetObjectTextValueByPath(source, propertyPath);

            if (!string.IsNullOrWhiteSpace(value))
            {
                return value;
            }
        }

        return string.Empty;
    }

    private static string GetObjectTextValueByPath(object? source, string propertyPath)
    {
        if (source == null || string.IsNullOrWhiteSpace(propertyPath))
        {
            return string.Empty;
        }

        object? current = source;

        foreach (var part in propertyPath.Split('.', StringSplitOptions.RemoveEmptyEntries))
        {
            if (current == null)
            {
                return string.Empty;
            }

            var property = current.GetType()
                .GetProperties(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance)
                .FirstOrDefault(p => string.Equals(p.Name, part, StringComparison.OrdinalIgnoreCase));

            if (property == null)
            {
                return string.Empty;
            }

            current = property.GetValue(current);
        }

        return current?.ToString() ?? string.Empty;
    }
    // END 14S-R18 metadata tooltip helpers

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
            _lookupRefreshKey++;
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in RebindFromPropertyChange.";
            ex.Data["PageMethod"] = "ShoreInput/RebindFromPropertyChange()";
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
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in CloseWindow().";
            ex.Data["PageMethod"] = "ShoreInput/CloseWindow()";
            _ = OnError.InvokeAsync(ex);
        }

        WindowIsVisible = false;
        ModalIsVisible = false;
        NativeModalIsMaximized = false;
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
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in HandleModelOnClick().";
            ex.Data["PageMethod"] = "ShoreInput/HandleModelOnClick()";
            _ = OnError.InvokeAsync(ex);
        }
    }

    private void OnLeaveHandler(string fieldName, object? newValue)
    {
        InteractionTracker.Log(NavManager.Uri, $"Left field '{fieldName}' with value: '{newValue}'");
    }

    protected void NavigateToDetailPage()
    {
        try
        {
            var recordGuid = GuidValueBinding;
            var entityTypeGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityProperty.ForeignEntityTypeGuid);

            if (recordGuid == Guid.Empty)
            {
                throw new Exception("Cannot navigate to detail page because RecordGuid is empty.");
            }

            if (entityTypeGuid == Guid.Empty)
            {
                throw new Exception("Cannot navigate to detail page because EntityTypeGuid is empty.");
            }

            var detailPageUri = PWAFunctions.BuildEntityNavigationUrl(
                baseUri: NavManager.BaseUri,
                detailPageUri: EntityProperty.DetailPageUri,
                recordGuid: recordGuid,
                entityTypeGuid: entityTypeGuid,
                currentUrl: NavManager.Uri,
                inheritedReturnUrl: ReturnUrl);

            InteractionTracker.Log(
                NavManager.BaseUri,
                $"Button Clicked - '{PropertyName}' New Page Opened: '{detailPageUri}'");

            NavManager.NavigateTo(detailPageUri);
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in NavigateToDetailPage().";
            ex.Data["PageMethod"] = "ShoreInput/NavigateToDetailPage()";
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
            if (!_isRegisteredWithParent && !Parent.ChildInputs.Contains(this))
            {
                Parent.ChildInputs.Add(this);
                _isRegisteredWithParent = true;
            }
            // Get User of Selected Record When in Settings --> Users --> User Record
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

    protected override void OnParametersSet()
    {
        try
        {
            RefreshResolvedPropertyMetadata();
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in OnParametersSet().";
            ex.Data["PageMethod"] = "ShoreInput/OnParametersSet()";
            _ = OnError.InvokeAsync(ex);
        }
    }

    protected override async Task OnInitializedAsync()
    {
        try
        {
            RefreshResolvedPropertyMetadata();

            await base.OnInitializedAsync();
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in OnInitializedAsync().";
            ex.Data["PageMethod"] = "ShoreInput/OnInitializedAsync()";
            _ = OnError.InvokeAsync(ex);
        }
    }

    protected async Task PausedStringUpdateNotificationAsync(DateTime updateTime)
    {
        try
        {
            //if (updateTime > _lastRepeatableFieldUpdate.AddSeconds(0.5))
            //{
            _ = InputUpdated.InvokeAsync(new InputUpdatedArgs
            { NewValue = DataProperty.Value, Dependents = Dependents, EntityId = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataProperty.EntityPropertyGuid) });
            _lastRepeatableFieldUpdate = updateTime;
            //}
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in PausedStringUpdateNotificationAsync().";
            ex.Data["PageMethod"] = "ShoreInput/PausedStringUpdateNotificationAsync()";
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
            _detailPageParameters.Add("TransientVirtualProperties", TransientVirtualProperties);

            modalService.RegisterModal(modalId, parentDataObjectReference);
            WindowIsVisible = true;
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in SetDefaultWindowParameters().";
            ex.Data["PageMethod"] = "ShoreInput/SetDefaultWindowParameters()";
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
            _detailPageParameters.Add("TransientVirtualProperties", TransientVirtualProperties);

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
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in SetDetailWindowParameters().";
            ex.Data["PageMethod"] = "ShoreInput/SetDetailWindowParameters()";
            Console.WriteLine($"Exception: {ex.Message}");
            _ = OnError.InvokeAsync(ex);
        }
    }

    #endregion Protected Methods

    #region Private Methods

    private void RefreshResolvedPropertyMetadata()
    {
        var entityPropertyGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityProperty?.Guid);

        if (entityPropertyGuid == Guid.Empty)
        {
            entityPropertyGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataProperty?.EntityPropertyGuid);
        }

        PropertyId = entityPropertyGuid == Guid.Empty
            ? $"shore-input-{_componentInstanceGuid:N}"
            : $"shore-input-{entityPropertyGuid:N}-{_componentInstanceGuid:N}";

        var resolvedLabel = string.IsNullOrWhiteSpace(EntityProperty?.Label)
            ? EntityProperty?.Name ?? string.Empty
            : EntityProperty.Label;

        PropertyName = resolvedLabel;
        Placeholder = resolvedLabel;
        Dependents = EntityProperty?.DependantProperties?.ToList() ?? new List<EntityPropertyDependant>();
    }

    public void Dispose()
    {
        _debounceTimer?.Dispose();

        if (_isRegisteredWithParent)
        {
            Parent.ChildInputs.Remove(this);
            _isRegisteredWithParent = false;
        }
    }

    private async Task HandleOnBlur(FocusEventArgs e)
    {
        try
        {
            StringValueBinding = tempValue;
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in HandleOnBlur().";
            ex.Data["PageMethod"] = "ShoreInput/HandleOnChange()";
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
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in HandleOnChange().";
            ex.Data["PageMethod"] = "ShoreInput/HandleOnChange()";
            _ = OnError.InvokeAsync(ex);
        }
    }

    /// <summary>
    /// Opens a link in a new tab that is tied to the "ExternalSearchPageUrl" property
    /// </summary>
    private async Task OpenLinkInNewTab(string url)
    {
        try
        {
            //Calls upon the function found in wwwroot/OpenLinkInNewTab.js
            await JS.InvokeVoidAsync("openInNewTab", url);
        }
        catch (Exception ex)
        {
            Console.WriteLine(ex.Message);
        }
    }

    private void HandleOnClick()
    {
        try
        {
            WindowTitle = string.Empty;

            // Existing behaviour preserved:
            // - If no dropdown definition, open default window parameters
            // - If detail is windowed or property row is inactive, open detail window
            // - Otherwise navigate to the detail page

            if (EntityProperty.DropDownListDefinitionGuid == Guid.Empty.ToString())
            {
                SetDefaultWindowParameters();
            }
            else if (EntityProperty.IsDetailWindowed || EntityProperty.RowStatus == 0)
            {
                SetDetailWindowParameters();
            }
            else
            {
                NavigateToDetailPage();
            }
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in HandleOnClick().";
            ex.Data["PageMethod"] = "ShoreInput/HandleOnClick()";
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

    private string NativeDateMin => _min.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    private string NativeDateMax => _max.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    private string NativeDateTimeMin => _min.ToString("yyyy-MM-ddTHH:mm", CultureInfo.InvariantCulture);

    private string NativeDateTimeMax => _max.ToString("yyyy-MM-ddTHH:mm", CultureInfo.InvariantCulture);

    private string NativeDateValue => DateTimeValueBinding?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) ?? string.Empty;

    private string NativeDateTimeValue => DateTimeValueBinding?.ToString("yyyy-MM-ddTHH:mm", CultureInfo.InvariantCulture) ?? string.Empty;

    private bool IsNativeDateInputDisabled => DataProperty.IsReadOnly || EffectiveDisabled;

    private Task OnNativeDateInputChangeAsync(ChangeEventArgs args)
    {
        try
        {
            var value = args.Value?.ToString();

            if (string.IsNullOrWhiteSpace(value))
            {
                DateTimeValueBinding = null;
                return Task.CompletedTask;
            }

            if (DateTime.TryParseExact(
                    value,
                    "yyyy-MM-dd",
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.None,
                    out var parsedDate))
            {
                DateTimeValueBinding = UiFormattingHelper.EnsureNoUtcRollback(parsedDate.Date);
            }
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in OnNativeDateInputChangeAsync().";
            ex.Data["PageMethod"] = "ShoreInput/OnNativeDateInputChangeAsync()";
            _ = OnError.InvokeAsync(ex);
        }

        return Task.CompletedTask;
    }

    private static readonly string[] NativeDateTimeHourOptions = Enumerable
        .Range(0, 24)
        .Select(x => x.ToString("00", CultureInfo.InvariantCulture))
        .ToArray();

    private static readonly string[] NativeDateTimeMinuteOptions =
    {
        "00",
        "15",
        "30",
        "45"
    };

    private string NativeDateTimeDateValue => DateTimeValueBinding?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) ?? string.Empty;

    private string NativeDateTimeHourValue => (DateTimeValueBinding?.Hour ?? 0).ToString("00", CultureInfo.InvariantCulture);

    private string NativeDateTimeMinuteValue => NormaliseMinuteToQuarter(DateTimeValueBinding?.Minute ?? 0).ToString("00", CultureInfo.InvariantCulture);

    private static int NormaliseMinuteToQuarter(int minute)
    {
        if (minute <= 0)
        {
            return 0;
        }

        if (minute >= 45)
        {
            return 45;
        }

        return (minute / 15) * 15;
    }

    private Task OnNativeDateTimeDatePartChangeAsync(ChangeEventArgs args)
    {
        return UpdateNativeDateTimeFromPartsAsync(dateText: args.Value?.ToString());
    }

    private Task OnNativeDateTimeHourPartChangeAsync(ChangeEventArgs args)
    {
        return UpdateNativeDateTimeFromPartsAsync(hourText: args.Value?.ToString());
    }

    private Task OnNativeDateTimeMinutePartChangeAsync(ChangeEventArgs args)
    {
        return UpdateNativeDateTimeFromPartsAsync(minuteText: args.Value?.ToString());
    }

    private Task UpdateNativeDateTimeFromPartsAsync(
        string? dateText = null,
        string? hourText = null,
        string? minuteText = null)
    {
        try
        {
            var existingValue = DateTimeValueBinding;
            var effectiveDateText = dateText ?? existingValue?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) ?? string.Empty;

            if (string.IsNullOrWhiteSpace(effectiveDateText))
            {
                DateTimeValueBinding = null;
                return Task.CompletedTask;
            }

            if (!DateTime.TryParseExact(
                    effectiveDateText,
                    "yyyy-MM-dd",
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.None,
                    out var parsedDate))
            {
                return Task.CompletedTask;
            }

            var hour = existingValue?.Hour ?? 0;
            if (!string.IsNullOrWhiteSpace(hourText) &&
                int.TryParse(hourText, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsedHour))
            {
                hour = Math.Clamp(parsedHour, 0, 23);
            }

            var minute = NormaliseMinuteToQuarter(existingValue?.Minute ?? 0);
            if (!string.IsNullOrWhiteSpace(minuteText) &&
                int.TryParse(minuteText, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsedMinute))
            {
                minute = NormaliseMinuteToQuarter(Math.Clamp(parsedMinute, 0, 59));
            }

            DateTimeValueBinding = parsedDate.Date.AddHours(hour).AddMinutes(minute);
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in UpdateNativeDateTimeFromPartsAsync().";
            ex.Data["PageMethod"] = "ShoreInput/UpdateNativeDateTimeFromPartsAsync()";
            _ = OnError.InvokeAsync(ex);
        }

        return Task.CompletedTask;
    }
    private Task OnNativeDateTimeInputChangeAsync(ChangeEventArgs args)
    {
        try
        {
            var value = args.Value?.ToString();

            if (string.IsNullOrWhiteSpace(value))
            {
                DateTimeValueBinding = null;
                return Task.CompletedTask;
            }

            var formats = new[]
            {
                "yyyy-MM-ddTHH:mm",
                "yyyy-MM-ddTHH:mm:ss"
            };

            if (DateTime.TryParseExact(
                    value,
                    formats,
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.None,
                    out var parsedDateTime))
            {
                DateTimeValueBinding = parsedDateTime;
            }
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in OnNativeDateTimeInputChangeAsync().";
            ex.Data["PageMethod"] = "ShoreInput/OnNativeDateTimeInputChangeAsync()";
            _ = OnError.InvokeAsync(ex);
        }

        return Task.CompletedTask;
    }
    private async Task OnPickerChangeAsync(object newValue)
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
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in OnPickerChangeAsync().";
            ex.Data["PageMethod"] = "ShoreInput/OnPickerChangeAsync()";
            _ = OnError.InvokeAsync(ex);
        }
    }

    private async Task HandleLookupUserInteractionAsync()
    {
        try
        {
            if (_lookupHasUserRequestedData)
            {
                return;
            }

            _lookupHasUserRequestedData = true;

            // If the first render was deliberately deferred, force a rebind now that the user has
            // actually interacted with the lookup. This keeps the initial page load light while
            // preserving the existing user-facing dropdown behaviour.
            if (_lookupInitialEmptyReadDeferred)
            {
                _lookupRefreshKey++;
                await InvokeAsync(StateHasChanged);
            }
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error while preparing lookup options after user interaction.";
            ex.Data["PageMethod"] = "ShoreInput/HandleLookupUserInteractionAsync()";
            _ = OnError.InvokeAsync(ex);
        }
    }
    private bool ShouldDeferInitialEmptyLookupRead(string? searchText)
    {
        try
        {
            if (_lookupHasUserRequestedData)
            {
                return false;
            }

            if (!string.IsNullOrWhiteSpace(searchText))
            {
                return false;
            }

            // If a value is already selected, allow the existing lookup path so the display text
            // can be resolved and reported back to EditPage for headers/browser title updates.
            if (GuidValueBinding != Guid.Empty)
            {
                return false;
            }

            // Workflow/status lookups can have side-effect-sensitive parent context and should keep
            // their existing hydration behaviour.
            if (string.Equals(
                    EntityProperty?.DropDownListDefinitionGuid,
                    "192f12f6-c7b0-4626-8e8d-8c5091456b93",
                    StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            return true;
        }
        catch
        {
            // Prefer existing behaviour if the guard cannot be evaluated.
            return false;
        }
    }

    private Task OnNativeLookupValueChangedAsync(Guid value)
    {
        GuidValueBinding = value;
        return Task.CompletedTask;
    }

    private async Task<IReadOnlyList<ComboDataItem>> LoadNativeLookupItemsAsync(string? searchText)
    {
        try
        {
            /*
             * Pertaining to CBLD-616:
             * Preserve the workflow status lookup parent-guid fix from the Telerik OnRead path.
             */
            if (EntityProperty.DropDownListDefinition.Guid.ToString() == "192f12f6-c7b0-4626-8e8d-8c5091456b93")
            {
                if (ParentGuid != Guid.Empty.ToString() || ParentGuid == null)
                    stateService.OriginalRecordGuid = ParentGuid;

                if (RecordGuid == Guid.Empty.ToString())
                    RecordGuid = stateService.ChildRecordGuid.ToString();

                if (ParentGuid == Guid.Empty.ToString() || ParentGuid == null)
                    ParentGuid = stateService.OriginalRecordGuid;
            }

            if (ShouldDeferInitialEmptyLookupRead(searchText))
            {
                _lookupInitialEmptyReadDeferred = true;

                try
                {
                    Console.WriteLine($"[CymBuildPerf] Layer=UI Method=ShoreInput Step=DropDownDataListDeferred Guid={EntityProperty.DropDownListDefinitionGuid} Reason=InitialEmptyLookup");
                }
                catch
                {
                    // Logging must never affect user workflows.
                }

                return Array.Empty<ComboDataItem>();
            }

            var dropDownDataListRequest = new DropDownDataListRequest
            {
                Guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityProperty.DropDownListDefinitionGuid)
                    .ToString(),
                ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString(),
                RecordGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(RecordGuid).ToString(),
                CurrentSelectedValueGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(GuidValueBinding.ToString())
                    .ToString()
            };

            if (!string.IsNullOrWhiteSpace(searchText))
            {
                var compositeFilter = new DataObjectCompositeFilter
                {
                    LogicalOperator = "Contains"
                };

                compositeFilter.Filters.Add(new DataObjectFilter
                {
                    Guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityProperty.DropDownListDefinitionGuid)
                        .ToString(),
                    Value = new Value { StringValue = searchText.Trim() },
                    Operator = "Contains",
                    ColumnName = EntityProperty.DropDownListDefinition.NameColumn,
                    DataType = "string"
                });

                dropDownDataListRequest.Filters.Add(compositeFilter);
            }

            // If the parentguid is Guid.Empty -> Try to get it from the stateService
            if (ParentGuid == Guid.Empty.ToString())
            {
                dropDownDataListRequest.ParentGuid = stateService.OriginalRecordGuid;
            }

            DropDownDataListReply dropDownDataListReply;

            if (FormHelper is not null)
            {
                dropDownDataListReply = await FormHelper.DropDownDataListGetAsync(dropDownDataListRequest);
            }
            else
            {
                // Compatibility fallback for existing pages that have not yet passed FormHelper through.
                // New main-record work should pass FormHelper so the UI does not own lookup retrieval.
                var stopwatch = System.Diagnostics.Stopwatch.StartNew();
                dropDownDataListReply = await CoreClient.DropDownDataListAsync(dropDownDataListRequest);

                try
                {
                    Console.WriteLine($"[CymBuildPerf] Layer=UI Method=ShoreInput Step=DropDownDataList Guid={dropDownDataListRequest.Guid} DurationMs={stopwatch.ElapsedMilliseconds} CacheHit=False Boundary=DirectFallback");
                }
                catch
                {
                    // Logging must never affect user workflows.
                }
            }

            var comboItems = dropDownDataListReply.Items
                .Select(item => new ComboDataItem(item))
                .ToList();

            await NotifyParentOfSelectedLookupDisplayValueAsync(comboItems);

            return comboItems;
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in LoadNativeLookupItemsAsync().";
            ex.Data["PageMethod"] = "ShoreInput/LoadNativeLookupItemsAsync()";
            await OnError.InvokeAsync(ex);
            return Array.Empty<ComboDataItem>();
        }
    }
    private async Task NotifyParentOfSelectedLookupDisplayValueAsync(IReadOnlyCollection<ComboDataItem> comboItems)
    {
        try
        {
            if (ParentEditPage == null)
            {
                return;
            }

            if (EntityProperty == null || string.IsNullOrWhiteSpace(EntityProperty.Guid))
            {
                return;
            }

            var entityPropertyGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityProperty.Guid);

            if (entityPropertyGuid == Guid.Empty)
            {
                return;
            }

            var selectedValue = GuidValueBinding;

            if (selectedValue == Guid.Empty)
            {
                return;
            }

            var selectedItem = comboItems.FirstOrDefault(item => item.Value == selectedValue);

            if (selectedItem == null || string.IsNullOrWhiteSpace(selectedItem.Name))
            {
                return;
            }

            await ParentEditPage.RegisterHeaderLookupDisplayValueAsync(
                entityPropertyGuid,
                selectedItem.Name);
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error notifying EditPage of selected lookup display value.";
            ex.Data["PageMethod"] = "ShoreInput/NotifyParentOfSelectedLookupDisplayValueAsync()";
            await OnError.InvokeAsync(ex);
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
                GuidValueBinding = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(currentContextVal["OriginalRecordGuid"]);
            }

            _lookupHasUserRequestedData = true;
            _lookupRefreshKey++;

            PWAFunctions.ResetStateService(stateService);
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error in RebindComboBox().";
            ex.Data["PageMethod"] = "ShoreInput/RebindComboBox()";
            _ = OnError.InvokeAsync(ex);
        }
    }

    private void ToggleNativeModalMaximized()
    {
        NativeModalIsMaximized = !NativeModalIsMaximized;
        StateHasChanged();
    }

    private static System.Type? ResolvePageComponentType(string? pageUri)
    {
        var trimmedPageUri = pageUri?.Trim();

        if (string.IsNullOrWhiteSpace(trimmedPageUri))
        {
            return null;
        }

        var candidates = new[]
        {
            trimmedPageUri,
            $"{trimmedPageUri}, Concursus.PWA",
            $"Concursus.PWA.Pages.{trimmedPageUri}",
            $"Concursus.PWA.Pages.{trimmedPageUri}, Concursus.PWA",
            $"Concursus.PWA.Shared.{trimmedPageUri}",
            $"Concursus.PWA.Shared.{trimmedPageUri}, Concursus.PWA"
        };

        foreach (var candidate in candidates)
        {
            var type = System.Type.GetType(candidate, throwOnError: false, ignoreCase: false);

            if (type is not null)
            {
                return type;
            }
        }

        return AppDomain.CurrentDomain
            .GetAssemblies()
            .Select(assembly => assembly.GetType($"Concursus.PWA.Pages.{trimmedPageUri}", throwOnError: false, ignoreCase: false)
                             ?? assembly.GetType($"Concursus.PWA.Shared.{trimmedPageUri}", throwOnError: false, ignoreCase: false)
                             ?? assembly.GetType(trimmedPageUri, throwOnError: false, ignoreCase: false))
            .FirstOrDefault(type => type is not null);
    }
    private void WindowVisibleChangedHandler(bool currVisible)
    {
        if (WindowIsClosable)
        {
            WindowIsVisible = currVisible; // if you don't do this, the window won't close because of the user action
            ModalIsVisible = currVisible; // if you don't do this, the window won't close because of the user action
            if (!currVisible)
            {
                NativeModalIsMaximized = false;
            }
        }
        else
        {
            Console.WriteLine("The user tried to close the window but the code didn't let them");
        }
    }

    #endregion Private Methods
}

