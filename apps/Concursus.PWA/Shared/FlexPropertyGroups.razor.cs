using Concursus.API.Core;
using Concursus.Components.Shared.Classes;
using Microsoft.AspNetCore.Components;

namespace Concursus.PWA.Shared;

public partial class FlexPropertyGroups
{
    #region Public Fields

    public FlexPropertyGroups? flexPropertyGroups;

    #endregion Public Fields

    #region Public Properties

    public List<FlexPropertyGroup> ChildGroups { get; set; } = new();
    [Parameter] public DataObject? dataObject { get; set; }
    [Parameter] public bool IsMainRecordContext { get; set; } = true;

    [Parameter] public EventCallback<DataObject> dataObjectChanged { get; set; }

    [Parameter] public List<EntityProperty> entityProperties { get; set; } = new();

    [Parameter] public List<EntityPropertyGroup> entityPropertyGroups { get; set; } = new();

    [Parameter] public EventCallback<InputUpdatedArgs> inputUpdated { get; set; }

    [Parameter] public bool IsBulkUpdate { get; set; } = false;
    [Parameter] public string RecordGuid { get; set; } = "";
    [Parameter] public EventCallback<string> RecordGuidChanged { get; set; }

    [Parameter] public EditPage editPageRef { get; set; }

    #endregion Public Properties

    #region Public Methods

    public void RebindFromPropertyChange(InputUpdatedArgs inputUpdatedArgs)
    {
        foreach (var flexPropertyGroup in ChildGroups) flexPropertyGroup.RebindFromPropertyChange(inputUpdatedArgs);
    }

    #endregion Public Methods

    #region Private Methods

    private void HandleInputUpdated(InputUpdatedArgs inputUpdatedArgs)
    {
        inputUpdated.InvokeAsync(inputUpdatedArgs);
    }

    #endregion Private Methods
}