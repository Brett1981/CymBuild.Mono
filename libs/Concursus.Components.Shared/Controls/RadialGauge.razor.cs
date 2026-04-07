using Concursus.API.Client.Classes;
using Concursus.API.Core;
using Microsoft.AspNetCore.Components;

namespace Concursus.Components.Shared.Controls;

public partial class RadialGauge
{
    [Parameter] public DashboardMetric Metric { get; set; } = new();

    protected void HandleClickOnMetric(string? metricGuid, string? pageUri)
    {
        if (string.IsNullOrEmpty(metricGuid) || string.IsNullOrEmpty(pageUri)) return;
        try
        {
            Navigation.NavigateTo(pageUri + "/" + ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(metricGuid).ToString());
        }
        catch (Exception ex)
        {
            var exception = ex.Message;
            if (exception != "") throw new Exception(ex.Message);
        }
    }

    protected override Task OnParametersSetAsync()
    {
        base.OnParametersSet();
        //StateHasChanged();
        return Task.CompletedTask;
    }
}