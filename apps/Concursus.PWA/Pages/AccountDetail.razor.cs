using Concursus.API.Client.Models;
using Concursus.PWA.Shared;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Newtonsoft.Json;
using System.Web;

namespace Concursus.PWA.Pages;

public partial class AccountDetail
{
    [Parameter]
    public Dictionary<string, Any> TransientVirtualProperties { get; set; } = new();
    [Parameter] public bool IsDetailWindowed { get; set; } = false;
    [Parameter] public string? ModalId { get; set; }

    [Parameter]
    public EventCallback<Exception> OnError { get; set; }

    [Parameter]
    public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }

    [Parameter]
    public string? SerializedDataObjectReference { get; set; }

    [Parameter] public bool IsMainRecordContext { get; set; } = true;

    protected override async Task OnParametersSetAsync()
    {
        try
        {
            if (ParentDataObjectReference != null)
            {
                ParentDataObjectReference = JsonConvert.DeserializeObject<DataObjectReference>(HttpUtility.UrlDecode(SerializedDataObjectReference) ?? string.Empty);
                await ParentDataObjectReferenceChanged.InvokeAsync(ParentDataObjectReference);
            }
            await base.OnParametersSetAsync();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error occurred while setting parameters for AccountDetail.razor.");
            ex.Data.Add("PageMethod", "AccountDetail/OnParametersSetAsync()");
            _ = OnError.InvokeAsync(ex);
        }
    }
}