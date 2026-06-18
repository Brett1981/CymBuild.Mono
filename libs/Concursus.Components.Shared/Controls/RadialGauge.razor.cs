using Concursus.API.Client.Classes;
using Concursus.API.Core;
using Microsoft.AspNetCore.Components;

namespace Concursus.Components.Shared.Controls;

public partial class RadialGauge
{

    private bool CanOpenMetric =>
        !string.IsNullOrWhiteSpace(Metric?.Guid)
        && !string.IsNullOrWhiteSpace(Metric?.PageUri);

    private void HandleClickOnMetric()
    {
        if (!CanOpenMetric)
        {
            return;
        }

        Navigation.NavigateTo(
            $"{Metric!.PageUri}/{ClientFunctions.ParseAndReturnEmptyGuidIfInvalid(Metric.Guid)}");
    }

    protected override Task OnParametersSetAsync()
    {
        base.OnParametersSet();
        //StateHasChanged();
        return Task.CompletedTask;
    }
}