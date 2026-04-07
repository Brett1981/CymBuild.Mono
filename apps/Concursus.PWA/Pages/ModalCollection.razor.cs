using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Concursus.PWA.Classes;
using Concursus.PWA.Shared;
using Google.Protobuf.Collections;
using Microsoft.AspNetCore.Components;
using Telerik.Blazor.Components;
using Telerik.DataSource;
using EntityProperty = Concursus.API.Core.EntityProperty;

namespace Concursus.PWA.Pages;

public partial class ModalCollection
{
    protected FormHelper? FormHelper;

    private const int DefaultPage = 1;

    private MessageDisplay _messageDisplay = new();
    [Parameter] public List<EntityProperty> EntityProperties { get; set; } = new();

    [Parameter] public RepeatedField<MergeDocument>? ListOfMergeDocuments { get; set; }

    public IEnumerable<API.Client.MenuItem>? ListViewData { get; set; }
    public List<ModalModel> ModalList { get; set; }
    [Parameter] public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }
    [Parameter] public string? SerializedDataObjectReference { get; set; }
    protected string ErrorMessage { get; set; } = "";
    protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
    protected string PageMethod { get; set; } = "Not Set";

    private List<API.Client.MenuItem>? Data { get; set; }
    private string FilterText { get; set; } = string.Empty;
    private bool LoaderVisible { get; set; }
    private bool ModalIsVisible { get; set; }
    private TelerikWindow? ModalWindow { get; set; }
    private int Page { get; set; } = DefaultPage;
    private List<string>? SelectedItems { get; set; }
    private bool WindowIsClosable { get; set; } = true;
    private bool WindowIsVisible { get; set; }
    private string? WindowTitle { get; set; }

    public void DeleteHandler(GridCommandEventArgs args)
    {
        var modal = (ModalModel)args.Item;
        modalService.UnregisterModal(modal.ModalId.ToString());
        LoadData();
    }

    public void UpdateHandler(GridCommandEventArgs args)
    {
        var modal = (ModalModel)args.Item;
        modalService.UpdateModalDataObjectReference(modal.ModalId.ToString(), modal.DataObjectReference);
        LoadData();
    }

    protected override void OnInitialized()
    {
        if (modalService != null)
        {
            LoadData();
        }
    }

    private void LoadData()
    {
        //Get list of open modals (modalService.GetOpenModals) and show them in a TelerikGrid
        var openModals = modalService.GetOpenModals();
        List<ModalModel> modalList = new();

        foreach (var modal in openModals)
        {
            modalList.Add(new ModalModel()
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

    private void OnStateInit(GridStateEventArgs<ModalModel> args)
    {
        args.GridState.GroupDescriptors = new List<GroupDescriptor>()
        {
            new GroupDescriptor()
            {
                Member = nameof(ModalModel.ModalId),
                MemberType = typeof(int)
            }
        };
    }
}