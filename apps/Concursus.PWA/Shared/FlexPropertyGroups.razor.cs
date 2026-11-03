using Concursus.API.Client;
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
    [Parameter] public FormHelper? FormHelper { get; set; }

    [Parameter] public EventCallback<DataObject> dataObjectChanged { get; set; }

    [Parameter] public List<API.Core.EntityProperty> entityProperties { get; set; } = new();

    [Parameter] public List<EntityPropertyGroup> entityPropertyGroups { get; set; } = new();

    /// <summary>
    /// The CSS grid's per-column minimum width (e.g. "60rem" for a panel with few groups that
    /// should fill its row rather than leave an empty reserved column next to it). Defaults to
    /// the original fixed value so every existing page keeps its current layout unchanged.
    /// </summary>
    [Parameter] public string MinColumnWidth { get; set; } = "30rem";

    [Parameter] public EventCallback<InputUpdatedArgs> inputUpdated { get; set; }

    [Parameter] public bool IsBulkUpdate { get; set; } = false;
    [Parameter] public string RecordGuid { get; set; } = "";
    [Parameter] public EventCallback<string> RecordGuidChanged { get; set; }

    [Parameter] public EditPage editPageRef { get; set; }

    [Parameter] public Func<Task<bool>>? ValidateAddressCallback { get; set; }
    [Parameter] public EventCallback UpdateValidateBtnCallback { get; set; }

    #endregion Public Properties

    #region Public Methods

    public void RebindFromPropertyChange(InputUpdatedArgs inputUpdatedArgs)
    {
        foreach (var flexPropertyGroup in ChildGroups) flexPropertyGroup.RebindFromPropertyChange(inputUpdatedArgs);
    }

    public void ChangeValidationBtnText(string Text, string CSSClass = "btn btn-primary")
    {
        foreach (var flexPropertyGroup in ChildGroups) flexPropertyGroup.ChangeValidationBtnText(Text, CSSClass);
    }

    #endregion Public Methods

    #region Private Methods

    private void HandleInputUpdated(InputUpdatedArgs inputUpdatedArgs)
    {
        inputUpdated.InvokeAsync(inputUpdatedArgs);
    }

    #endregion Private Methods
}