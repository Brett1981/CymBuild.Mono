using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.PWA.Classes;
using Concursus.PWA.Shared;
using Google.Protobuf.Collections;
using Microsoft.AspNetCore.Components;
using EntityProperty = Concursus.API.Core.EntityProperty;

namespace Concursus.PWA.Pages;

public partial class ModalCollection
{
    protected FormHelper? FormHelper;

    private MessageDisplay _messageDisplay = new();

    [Parameter] public List<EntityProperty> EntityProperties { get; set; } = new();

    [Parameter] public RepeatedField<MergeDocument>? ListOfMergeDocuments { get; set; }

    public IEnumerable<API.Client.MenuItem>? ListViewData { get; set; }
    public List<ModalModel> ModalList { get; set; } = new();

    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string? SerializedDataObjectReference { get; set; }

    protected string ErrorMessage { get; set; } = string.Empty;
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";

    private string? editingModalId;
    private string editDataObjectGuid = Guid.Empty.ToString();
    private string editEntityTypeGuid = Guid.Empty.ToString();

    protected override void OnInitialized()
    {
        LoadData();
    }

    private void LoadData()
    {
        try
        {
            ErrorMessage = string.Empty;
            var openModals = modalService.GetOpenModals();
            var modalList = new List<ModalModel>();

            foreach (var modal in openModals)
            {
                modalList.Add(new ModalModel
                {
                    ModalId = modal.Key,
                    DataObjectReference = modal.Value.DataObjectReference,
                    DataObjectGuid = modal.Value.DataObjectReference.DataObjectGuid.ToString(),
                    EntityTypeGuid = modal.Value.DataObjectReference.EntityTypeGuid.ToString(),
                    Timestamp = modal.Value.Timestamp
                });
            }

            ModalList = modalList;
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Unable to load modal collection: {ex.Message}";
            ModalList = new List<ModalModel>();
        }
    }

    private bool IsEditing(ModalModel modal) =>
        string.Equals(editingModalId, modal.ModalId, StringComparison.OrdinalIgnoreCase);

    private void BeginEdit(ModalModel modal)
    {
        editingModalId = modal.ModalId;
        editDataObjectGuid = modal.DataObjectGuid;
        editEntityTypeGuid = modal.EntityTypeGuid;
    }

    private void CancelEdit()
    {
        editingModalId = null;
        editDataObjectGuid = Guid.Empty.ToString();
        editEntityTypeGuid = Guid.Empty.ToString();
    }

    private void SaveEdit(ModalModel modal)
    {
        try
        {
            ErrorMessage = string.Empty;
            var updatedReference = new DataObjectReference(editDataObjectGuid, editEntityTypeGuid);
            modal.DataObjectReference = updatedReference;
            modal.DataObjectGuid = editDataObjectGuid;
            modal.EntityTypeGuid = editEntityTypeGuid;

            modalService.UpdateModalDataObjectReference(modal.ModalId, updatedReference);
            CancelEdit();
            LoadData();
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Unable to update modal reference: {ex.Message}";
        }
    }

    private void DeleteModal(ModalModel modal)
    {
        try
        {
            ErrorMessage = string.Empty;
            modalService.UnregisterModal(modal.ModalId);
            CancelEdit();
            LoadData();
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Unable to delete modal: {ex.Message}";
        }
    }
}
