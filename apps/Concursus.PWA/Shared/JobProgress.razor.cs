using Concursus.API.Core;
using Microsoft.AspNetCore.Components;

namespace Concursus.PWA.Shared;

public partial class JobProgress
{
    [Parameter] public DataObject? DataObject { get; set; }

    public void RefreshProgress()
    {
        StateHasChanged(); // Add any additional logic if needed
        OnInitializedAsync();
    }
}