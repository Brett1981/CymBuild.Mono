using Concursus.API.Client;
using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.PWA.Classes;
using Microsoft.AspNetCore.Components;



using Google.Protobuf.WellKnownTypes;
namespace Concursus.PWA.Shared;

public partial class FlexPropertyGroup
{
    #region Public Properties

    public List<ShoreInput> ChildInputs { get; set; } = new();
    private bool isCollapsed;
    [Parameter] public DataObject dataObject { get; set; } = new();

    [Parameter] public EventCallback<DataObject> dataObjectChanged { get; set; }

    [Parameter]
    public bool Disabled { get; set; } = false;

    [Parameter] public List<API.Core.EntityProperty> entityProperties { get; set; } = new();

    [Parameter] public EntityPropertyGroup entityPropertyGroup { get; set; } = new();

    [Parameter] public EventCallback<InputUpdatedArgs> inputUpdated { get; set; }
    [Parameter] public bool IsMainRecordContext { get; set; } = true;
    [Parameter] public FormHelper? FormHelper { get; set; }

    [Parameter] public bool IsBulkEdit { get; set; } = false;
    [Parameter] public string RecordGuid { get; set; } = "";
    [Parameter] public EventCallback<string> RecordGuidChanged { get; set; }

    [Parameter] public EditPage editPageRef { get; set; }

    #endregion Public Properties

    // Default to false unless set from outside

    #region Private Properties

    [CascadingParameter] private FlexPropertyGroups Parent { get; set; } = new();

    #endregion Private Properties

    //CBLD-260

    #region Public Methods

    public void RebindFromPropertyChange(InputUpdatedArgs inputUpdatedArgs)
    {
        foreach (var shoreInput in ChildInputs) shoreInput.RebindFromPropertyChange(inputUpdatedArgs);
    }

    #endregion Public Methods

    #region Protected Methods

    protected override async Task OnInitializedAsync()
    {
        await base.OnInitializedAsync();

        Parent.ChildGroups.Add(this);

        // Bulk Edit Initialization
        if (IsBulkEdit)
        {
            foreach (var property in entityProperties)
            {
                property.IsSelectedForBulkChange = false;
            }
        }

        // Initialize Collapsing based on mobile/desktop
        if (entityPropertyGroup.IsCollapsable)
        {
            isCollapsed = DeviceInfoService.IsMobile
                ? entityPropertyGroup.IsDefaultCollapsedMobile
                : entityPropertyGroup.IsDefaultCollapsed;
        }
    }

    #endregion Protected Methods

    #region Private Methods

    private void ToggleCollapse()
    {
        if (entityPropertyGroup.IsCollapsable)
        {
            isCollapsed = !isCollapsed;
        }
    }

    private IEnumerable<API.Core.EntityProperty> FilteredEntityProperties => entityProperties
        .Where(p => p.EntityPropertyGroupGuid == PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(entityPropertyGroup.Guid).ToString())
        .OrderBy(p => p.GroupSortOrder)
        .ThenBy(p => p.SortOrder)
        .Where(p =>
        {
            if (entityPropertyGroup.IsCollapsable && isCollapsed)
            {
                // When collapsed, only show AlwaysVisible items
                return DeviceInfoService.IsMobile
                    ? p.IsAlwaysVisibleInGroupMobile
                    : p.IsAlwaysVisibleInGroup;
            }
            // When expanded, show everything
            return true;
        });

    private bool ShouldRenderGroup => entityProperties
        .Join(dataObject.DataProperties,
            ep => ep.Guid,
            dp => dp.EntityPropertyGuid,
            (ep, dp) => new { ep, dp })
        .Any(x => !x.ep.IsHidden && !x.dp.IsHidden && x.ep.EntityPropertyGroupGuid == PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(entityPropertyGroup.Guid).ToString());


    private string GetGroupCardCss()
    {
        var layoutCss = IsColumnPropertyGroupLayout()
            ? "is-layout-column"
            : "is-layout-row";

        return $"card shadow-sm flexpropertygroup {layoutCss}";
    }

    private string GetGroupFieldsCss()
    {
        var layoutCss = IsColumnPropertyGroupLayout()
            ? "is-column"
            : "is-row";

        return $"flexpropertygroup-fields {layoutCss}";
    }

    private string GetNormalisedPropertyGroupLayout()
    {
        return IsColumnPropertyGroupLayout()
            ? "Column"
            : "Row";
    }

    private string GetGroupCardStyle()
    {
        // The parent FlexPropertyGroups component owns group placement.
        // Keep the inline grid-column only as a metadata guard, but do not force Column
        // groups to consume a full row. Height/stretch is intentional so Column group cards
        // in the same visual row render with matching heights.
        const string common = "width: 100% !important; min-width: 0 !important; max-width: 100% !important; height: 100% !important; min-height: 100% !important; align-self: stretch !important; display: flex !important; flex-direction: column !important; box-sizing: border-box !important;";

        return IsColumnPropertyGroupLayout()
            ? $"grid-column: auto !important; {common}"
            : $"grid-column: 1 / -1 !important; {common}";
    }

    private bool IsColumnPropertyGroupLayout()
    {
        var layout = entityPropertyGroup?.Layout?.Trim() ?? string.Empty;

        return layout.Equals("Column", StringComparison.OrdinalIgnoreCase)
            || layout.Equals("Columns", StringComparison.OrdinalIgnoreCase)
            || layout.Contains("Column", StringComparison.OrdinalIgnoreCase);
    }

    private string GetPropertyHostStyle(API.Core.EntityProperty entityProperty, DataProperty dataProperty)
    {
        // Only Row property groups use content-aware single-line text sizing.
        // Column property groups intentionally keep the stable full-width stacked behaviour.
        if (IsColumnPropertyGroupLayoutName(entityPropertyGroup?.Layout)
            || IsMultilineEntityProperty(entityProperty)
            || !IsSingleLineTextEntityProperty(entityProperty))
        {
            return string.Empty;
        }

        var preferredCharacters = GetSingleLineTextPreferredCharacters(entityProperty, dataProperty);
        var minCharacters = Math.Max(10, SingleLineTextMinCharacters);
        var maxCharacters = Math.Max(minCharacters, SingleLineTextMaxCharacters);
        var clampedCharacters = Math.Clamp(preferredCharacters, minCharacters, maxCharacters);

        return $"--cb-row-text-field-basis: clamp({minCharacters}ch, {clampedCharacters}ch, {maxCharacters}ch); --cb-row-text-field-min: min(100%, {minCharacters}ch); --cb-row-text-field-max: min(100%, {maxCharacters}ch);";
    }

    private static int SingleLineTextMinCharacters => 22;

    private static int SingleLineTextMaxCharacters => 72;

    private static string GetPropertyHostCss(API.Core.EntityProperty entityProperty, bool isBulkEdit = false)
    {
        var css = "flexpropertygroup-field";

        if (isBulkEdit)
        {
            css += " is-bulk-edit";
        }

        if (IsMultilineEntityProperty(entityProperty))
        {
            return css + " is-multiline";
        }

        if (IsLookupEntityProperty(entityProperty))
        {
            return css + " is-lookup";
        }

        if (IsBooleanEntityProperty(entityProperty))
        {
            return css + " is-boolean";
        }

        if (IsDateEntityProperty(entityProperty))
        {
            return css + " is-date";
        }

        if (IsDateTimeEntityProperty(entityProperty))
        {
            return css + " is-datetime";
        }

        if (IsNumericEntityProperty(entityProperty))
        {
            return css + " is-numeric";
        }

        if (IsSingleLineTextEntityProperty(entityProperty))
        {
            return css + " is-singleline-text";
        }

        return css;
    }

    private static bool IsLookupEntityProperty(API.Core.EntityProperty entityProperty)
    {
        return !string.IsNullOrWhiteSpace(entityProperty.DropDownListDefinitionGuid)
            && entityProperty.DropDownListDefinitionGuid != Guid.Empty.ToString();
    }

    private static bool IsBooleanEntityProperty(API.Core.EntityProperty entityProperty)
    {
        return string.Equals(entityProperty.EntityDataTypeName?.Trim(), "BIT", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsDateEntityProperty(API.Core.EntityProperty entityProperty)
    {
        return string.Equals(entityProperty.EntityDataTypeName?.Trim(), "DATE", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsDateTimeEntityProperty(API.Core.EntityProperty entityProperty)
    {
        return string.Equals(entityProperty.EntityDataTypeName?.Trim(), "DATETIME2", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsNumericEntityProperty(API.Core.EntityProperty entityProperty)
    {
        var dataTypeName = entityProperty.EntityDataTypeName?.Trim() ?? string.Empty;

        return dataTypeName.Equals("INT", StringComparison.OrdinalIgnoreCase)
            || dataTypeName.Equals("BIGINT", StringComparison.OrdinalIgnoreCase)
            || dataTypeName.Equals("SMALLINT", StringComparison.OrdinalIgnoreCase)
            || dataTypeName.Equals("TINYINT", StringComparison.OrdinalIgnoreCase)
            || dataTypeName.Equals("DOUBLE", StringComparison.OrdinalIgnoreCase)
            || dataTypeName.Equals("DECIMAL", StringComparison.OrdinalIgnoreCase)
            || dataTypeName.Equals("MONEY", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsSingleLineTextEntityProperty(API.Core.EntityProperty entityProperty)
    {
        if (IsLookupEntityProperty(entityProperty)
            || IsBooleanEntityProperty(entityProperty)
            || IsDateEntityProperty(entityProperty)
            || IsDateTimeEntityProperty(entityProperty)
            || IsNumericEntityProperty(entityProperty)
            || IsMultilineEntityProperty(entityProperty))
        {
            return false;
        }

        var dataTypeName = entityProperty.EntityDataTypeName?.Trim() ?? string.Empty;

        return dataTypeName.StartsWith("NVARCHAR", StringComparison.OrdinalIgnoreCase)
            || dataTypeName.StartsWith("VARCHAR", StringComparison.OrdinalIgnoreCase)
            || dataTypeName.StartsWith("NCHAR", StringComparison.OrdinalIgnoreCase)
            || dataTypeName.StartsWith("CHAR", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsColumnPropertyGroupLayoutName(string? layout)
    {
        var normalisedLayout = layout?.Trim() ?? string.Empty;

        return normalisedLayout.Equals("Column", StringComparison.OrdinalIgnoreCase)
            || normalisedLayout.Equals("Columns", StringComparison.OrdinalIgnoreCase)
            || normalisedLayout.Contains("Column", StringComparison.OrdinalIgnoreCase);
    }

    private static int GetSingleLineTextPreferredCharacters(API.Core.EntityProperty entityProperty, DataProperty dataProperty)
    {
        var labelLength = GetUsableTextLength(entityProperty.Label, entityProperty.Name);
        var valueLength = GetUsableTextLength(GetDataPropertyStringValue(dataProperty), entityProperty.Label, entityProperty.Name);

        // Add allowance for input-group padding/borders while keeping short text fields compact.
        return Math.Max(labelLength + 10, labelLength + valueLength + 8);
    }

    private static int GetUsableTextLength(params string?[] values)
    {
        foreach (var value in values)
        {
            if (!string.IsNullOrWhiteSpace(value))
            {
                return Math.Min(value.Trim().Length, 120);
            }
        }

        return 0;
    }

    private static string GetDataPropertyStringValue(DataProperty dataProperty)
    {
        try
        {
            if (dataProperty?.Value == null)
            {
                return string.Empty;
            }

            if (dataProperty.Value.Is(StringValue.Descriptor))
            {
                dataProperty.Value.TryUnpack(out StringValue stringValue);
                return stringValue?.Value ?? string.Empty;
            }

            if (dataProperty.Value.Is(Int32Value.Descriptor))
            {
                dataProperty.Value.TryUnpack(out Int32Value int32Value);
                return int32Value?.Value.ToString() ?? string.Empty;
            }

            if (dataProperty.Value.Is(Int64Value.Descriptor))
            {
                dataProperty.Value.TryUnpack(out Int64Value int64Value);
                return int64Value?.Value.ToString() ?? string.Empty;
            }

            if (dataProperty.Value.Is(DoubleValue.Descriptor))
            {
                dataProperty.Value.TryUnpack(out DoubleValue doubleValue);
                return doubleValue?.Value.ToString() ?? string.Empty;
            }
        }
        catch
        {
            return string.Empty;
        }

        return string.Empty;
    }

    private static bool IsMultilineEntityProperty(API.Core.EntityProperty entityProperty)
    {
        if (!string.IsNullOrWhiteSpace(entityProperty.DropDownListDefinitionGuid)
            && entityProperty.DropDownListDefinitionGuid != Guid.Empty.ToString())
        {
            return false;
        }

        var dataTypeName = entityProperty.EntityDataTypeName?.Trim() ?? string.Empty;

        if (string.Equals(dataTypeName, "NVARCHAR(MAX)", StringComparison.OrdinalIgnoreCase)
            || string.Equals(dataTypeName, "VARCHAR(MAX)", StringComparison.OrdinalIgnoreCase)
            || string.Equals(dataTypeName, "NTEXT", StringComparison.OrdinalIgnoreCase)
            || string.Equals(dataTypeName, "TEXT", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        if ((string.Equals(dataTypeName, "NVARCHAR", StringComparison.OrdinalIgnoreCase)
                || string.Equals(dataTypeName, "VARCHAR", StringComparison.OrdinalIgnoreCase))
            && entityProperty.MaxLength <= 0)
        {
            return true;
        }

        return false;
    }

    private static string GetInspectorComponentName(API.Core.EntityProperty entityProperty)
    {
        if (!string.IsNullOrWhiteSpace(entityProperty.DropDownListDefinitionGuid)
            && entityProperty.DropDownListDefinitionGuid != Guid.Empty.ToString())
        {
            return "ShoreLookupInput";
        }

        return entityProperty.EntityDataTypeName switch
        {
            "BIT" => "NativeCheckbox",
            "DATE" => "NativeDateInput",
            "DATETIME2" => "NativeDateTimeInput",
            "INT" or "BIGINT" or "SMALLINT" or "TINYINT" => "NativeIntegerInput",
            "DOUBLE" or "DECIMAL" or "MONEY" => "NativeDecimalInput",
            "UNIQUEIDENTIFIER" => "GuidInput",
            "VARBINARY(MAX)" => "BinaryInput",
            "NVARCHAR(MAX)" => "NativeTextArea",
            _ => "NativeTextInput"
        };
    }

    private void HandleInputUpdated(InputUpdatedArgs inputUpdatedArgs)
    {
        inputUpdated.InvokeAsync(inputUpdatedArgs);
    }

    #endregion Private Methods
}




