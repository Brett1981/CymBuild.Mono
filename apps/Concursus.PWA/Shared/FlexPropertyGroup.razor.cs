using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Concursus.PWA.Classes;
using Microsoft.AspNetCore.Components;



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

    [Parameter] public List<EntityProperty> entityProperties { get; set; } = new();

    [Parameter] public EntityPropertyGroup entityPropertyGroup { get; set; } = new();

    [Parameter] public EventCallback<InputUpdatedArgs> inputUpdated { get; set; }
    [Parameter] public bool IsMainRecordContext { get; set; } = true;

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

    private IEnumerable<EntityProperty> FilteredEntityProperties => entityProperties
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

    private void HandleInputUpdated(InputUpdatedArgs inputUpdatedArgs)
    {
        inputUpdated.InvokeAsync(inputUpdatedArgs);
    }

    #endregion Private Methods
}