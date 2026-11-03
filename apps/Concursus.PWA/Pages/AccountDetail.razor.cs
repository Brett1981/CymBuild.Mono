using Concursus.API.Client.Models;
using Concursus.PWA.Shared;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Newtonsoft.Json;
using System.Web;

namespace Concursus.PWA.Pages;

public partial class AccountDetail
{
    private string? _lastAppliedSerializedDataObjectReference;

    [Parameter]
    public Dictionary<string, Any> TransientVirtualProperties { get; set; } = new();

    [Parameter]
    public bool IsDetailWindowed { get; set; } = false;

    [Parameter]
    public string? ModalId { get; set; }

    [Parameter]
    public EventCallback<Exception> OnError { get; set; }

    [Parameter]
    public EventCallback<DataObjectReference> ParentDataObjectReferenceChanged { get; set; }

    [Parameter]
    public string? SerializedDataObjectReference { get; set; }

    [Parameter]
    public bool IsMainRecordContext { get; set; } = true;

    protected override async Task OnParametersSetAsync()
    {
        try
        {
            await ApplySerializedParentDataObjectReferenceAsync();
            await base.OnParametersSetAsync();
        }
        catch (Exception ex)
        {
            ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
            ex.Data["AdditionalInfo"] = "Error occurred while setting parameters for AccountDetail.razor.";
            ex.Data["PageMethod"] = "AccountDetail/OnParametersSetAsync()";

            if (OnError.HasDelegate)
            {
                await OnError.InvokeAsync(ex);
            }
            else
            {
                throw;
            }
        }
    }

    private async Task ApplySerializedParentDataObjectReferenceAsync()
    {
        if (string.IsNullOrWhiteSpace(SerializedDataObjectReference))
        {
            return;
        }

        if (string.Equals(SerializedDataObjectReference, _lastAppliedSerializedDataObjectReference, StringComparison.Ordinal))
        {
            return;
        }

        var decodedReference = HttpUtility.UrlDecode(SerializedDataObjectReference);

        if (string.IsNullOrWhiteSpace(decodedReference)
            || string.Equals(decodedReference, "null", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        var parentReference = JsonConvert.DeserializeObject<DataObjectReference>(decodedReference);

        if (parentReference == null)
        {
            return;
        }

        ParentDataObjectReference = parentReference;
        _lastAppliedSerializedDataObjectReference = SerializedDataObjectReference;

        if (ParentDataObjectReferenceChanged.HasDelegate)
        {
            await ParentDataObjectReferenceChanged.InvokeAsync(parentReference);
        }
    }
}