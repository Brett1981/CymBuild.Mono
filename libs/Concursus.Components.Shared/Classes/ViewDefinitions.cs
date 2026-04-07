namespace Concursus.Components.Shared.Classes
{
    /// <summary>
    /// Base class for layout items (pages, sections, fields, dashboard items). Provides a common
    /// Id, Title and CSS hook.
    /// </summary>
    public abstract class LayoutBlockDefinition
    {
        /// <summary>
        /// Internal/universal identifier for the block. For fields this will typically match the
        /// EntityProperty Guid or name. For dashboard items this will match the existing widget Id.
        /// </summary>
        public string Id { get; set; } = string.Empty;

        /// <summary>
        /// User-facing title/label for this block, where applicable.
        /// </summary>
        public string? Title { get; set; }

        /// <summary>
        /// Optional CSS class for custom styling. This is intentionally generic so V2 can align
        /// with existing Telerik/Bootstrap classes.
        /// </summary>
        public string? CssClass { get; set; }
    }

    /// <summary>
    /// Top-level definition for an edit page (e.g. JobDetail, Enquiry, etc.). This is what V2 will
    /// build from EntityType/EntityProperty/EntityPropertyGroup metadata.
    /// </summary>
    public sealed class PageViewDefinition : LayoutBlockDefinition
    {
        /// <summary>
        /// Logical sections of the page (e.g. "Job Details", "Client", "Financials"). These will
        /// typically map to your existing EntityPropertyGroups or tabs.
        /// </summary>
        public List<SectionViewDefinition> Sections { get; set; } = new();
    }

    /// <summary>
    /// A logical group/section on a page (panel, card, tab content, etc.).
    /// </summary>
    public sealed class SectionViewDefinition : LayoutBlockDefinition
    {
        /// <summary>
        /// Optional: a key that links back to the originating EntityPropertyGroup (e.g. group Guid
        /// or code) for debugging and backwards-compat.
        /// </summary>
        public string? GroupKey { get; set; }

        /// <summary>
        /// Sort order of this section within the page. This should be derived from your existing
        /// SortOrder metadata.
        /// </summary>
        public int Order { get; set; }

        /// <summary>
        /// Whether the section should render as collapsed by default (if the UI supports collapse).
        /// </summary>
        public bool IsInitiallyCollapsed { get; set; }

        /// <summary>
        /// Collection of fields to render inside this section, in display order.
        /// </summary>
        public List<FieldViewDefinition> Fields { get; set; } = new();
    }

    /// <summary>
    /// Describes how a single DataProperty should be rendered in V2. This is built from
    /// EntityProperty metadata and the existing DataProperty shape.
    /// </summary>
    public sealed class FieldViewDefinition : LayoutBlockDefinition
    {
        /// <summary>
        /// Name of the field/property on the DataObject (e.g. "JobDescription", "JobStarted"). This
        /// should match the EntityProperty.PropertyName / ColumnName convention used today.
        /// </summary>
        public string FieldName { get; set; } = string.Empty;

        /// <summary>
        /// The high-level control type the UI should use (text box, date picker, dropdown, etc.).
        /// This is derived from EntityProperty data type + flags.
        /// </summary>
        public FieldViewType ViewType { get; set; } = FieldViewType.Text;

        /// <summary>
        /// Whether the field is read-only in the current context (user/role/entity state). This
        /// should capture both static metadata and dynamic rules (e.g. completed jobs).
        /// </summary>
        public bool IsReadOnly { get; set; }

        /// <summary>
        /// Whether the field should be hidden entirely in the current context.
        /// </summary>
        public bool IsHidden { get; set; }

        /// <summary>
        /// Whether the field is required, according to metadata.
        /// Note: actual validation remains in your existing validation layer, this is UI hinting.
        /// </summary>
        public bool IsRequired { get; set; }

        /// <summary>
        /// Optional placeholder text for text-based fields.
        /// </summary>
        public string? Placeholder { get; set; }

        /// <summary>
        /// Optional tooltip/help text for this field.
        /// </summary>
        public string? HelpText { get; set; }

        /// <summary>
        /// Optional "group within group" concept for layout (e.g. columns inside a section). This
        /// gives us flexibility to replicate more complex layouts later if needed.
        /// </summary>
        public string? LayoutGroupKey { get; set; }

        /// <summary>
        /// Optional arbitrary configuration object that can be interpreted by the renderer. Typical examples:
        /// - Dropdown source IDs / URIs
        /// - Text masks, min/max, step values
        /// - Special flags (e.g. use signature control, show as multi-line)
        ///
        /// We keep this loose initially to avoid over-constraining V2; the builder will populate a
        /// shape the renderer understands.
        /// </summary>
        public object? ExtraConfig { get; set; }
    }

    /// <summary>
    /// Enumerates the core visual control types V2 will use. This is intentionally simple; we can
    /// extend it safely as we encounter more patterns.
    /// </summary>
    public enum FieldViewType
    {
        /// <summary>
        /// Single-line text input (standard TextBox equivalent).
        /// </summary>
        Text,

        /// <summary>
        /// Multi-line text area / notes field.
        /// </summary>
        MultilineText,

        /// <summary>
        /// Numeric input (integer or decimal).
        /// </summary>
        Number,

        /// <summary>
        /// Date-only picker.
        /// </summary>
        Date,

        /// <summary>
        /// Date + time picker.
        /// </summary>
        DateTime,

        /// <summary>
        /// True/false value (checkbox, switch, etc.).
        /// </summary>
        Boolean,

        /// <summary>
        /// Dropdown / select field backed by a lookup or query.
        /// </summary>
        Dropdown,

        /// <summary>
        /// Read-only label or display-only text/value.
        /// </summary>
        ReadOnly,

        /// <summary>
        /// Specialised field that uses a custom control (e.g. signature, map, document link). In V2
        /// this will be a hint to delegate to a more specific renderer.
        /// </summary>
        Custom,

        /// <summary>
        /// Hidden field, present in the DataObject but not shown in the UI.
        /// </summary>
        Hidden
    }

    /// <summary>
    /// Top-level definition for a dashboard / "My Work" style layout. This is the V2 representation
    /// that will align with your existing ItemStates JSON.
    /// </summary>
    public sealed class DashboardViewDefinition : LayoutBlockDefinition
    {
        /// <summary>
        /// Optional CSS configuration for the dashboard as a whole (mirrors "MyWorkCSS").
        /// </summary>
        public List<DashboardCellColouring> MyWorkCss { get; set; } = new();

        /// <summary>
        /// Individual widget/tile instances on the dashboard, in display order. This maps directly
        /// from/to the existing ItemStates list stored in UserPreferences.
        /// </summary>
        public List<DashboardItemState> ItemStates { get; set; } = new();
    }

    /// <summary>
    /// Represents a single widget/tile on the dashboard, including its layout and styling. This is
    /// the V2 equivalent of the existing ItemState type in Widget.razor.
    /// </summary>
    public sealed class DashboardItemState
    {
        /// <summary>
        /// Id of the widget definition. This should match the existing widget Id (e.g. the
        /// GridViewDefinitionForWidgets or metric Id used today).
        /// </summary>
        public string Id { get; set; } = string.Empty;

        /// <summary>
        /// How many rows this widget spans in the grid layout.
        /// </summary>
        public int RowSpan { get; set; } = 1;

        /// <summary>
        /// How many columns this widget spans in the grid layout.
        /// </summary>
        public int ColSpan { get; set; } = 1;

        /// <summary>
        /// Order of the widget relative to other widgets. This will mirror the existing numeric
        /// order field in your ItemStates JSON.
        /// </summary>
        public int Order { get; set; }

        /// <summary>
        /// Optional background or accent color for the widget, e.g. "#f8f9fa". This maps to the
        /// existing Color property in ItemStates.
        /// </summary>
        public string? Color { get; set; }
    }

    /// <summary>
    /// Represents a colour rule for a specific CSS class used in "My Work" cells. This is a
    /// V2-friendly equivalent of the existing CellColouring type in Widget.razor.
    /// </summary>
    public sealed class DashboardCellColouring
    {
        /// <summary>
        /// The CSS class name applied to the cell or widget.
        /// </summary>
        public string ClassName { get; set; } = string.Empty;

        /// <summary>
        /// The colour associated with this class (e.g. "#FFFFFF").
        /// </summary>
        public string Colour { get; set; } = string.Empty;
    }

    /// <summary>
    /// Represents a single option in a dropdown field: the underlying value (typically a Guid
    /// string) and the user-visible label.
    /// </summary>
    public sealed class DropdownOption
    {
        /// <summary>
        /// The value stored in the DataProperty (typically a Guid string).
        /// </summary>
        public string Value { get; set; } = string.Empty;

        /// <summary>
        /// The label shown to the user (e.g. Account Name, Job Number).
        /// </summary>
        public string Label { get; set; } = string.Empty;

        /// <summary>
        /// Optional grouping key (maps to DropDownDataListItem.Group).
        /// </summary>
        public string? Group { get; set; }

        /// <summary>
        /// Optional colour hex code (maps to DropDownDataListItem.ColourHex).
        /// </summary>
        public string? ColourHex { get; set; }
    }

    /// <summary>
    /// Extra configuration for dropdown / lookup fields. This is attached to
    /// FieldViewDefinition.ExtraConfig when ViewType == Dropdown.
    /// </summary>
    public sealed class FieldDropdownConfig
    {
        /// <summary>
        /// Identifier of the dropdown source. This should match
        /// EntityProperty.DropDownListDefinitionGuid (string Guid).
        /// </summary>
        public string DefinitionId { get; set; } = string.Empty;

        /// <summary>
        /// Optional: the foreign entity type Guid, if this dropdown represents a relationship to
        /// another EntityType (for navigation, labels, etc.).
        /// </summary>
        public string? ForeignEntityTypeGuid { get; set; }

        /// <summary>
        /// Optional: the field Id (EntityProperty Guid) this config belongs to. Mostly for
        /// diagnostics / future behaviour.
        /// </summary>
        public string? FieldId { get; set; }

        /// <summary>
        /// The loaded options for this dropdown (Value = Guid, Label = display text). Populated by V2DropdownLoader.
        /// </summary>
        public List<DropdownOption> Options { get; set; } = new();
    }
}