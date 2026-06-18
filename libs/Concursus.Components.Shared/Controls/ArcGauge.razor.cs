using Concursus.API.Client.Classes;
using Concursus.API.Core;
using Microsoft.AspNetCore.Components;

namespace Concursus.Components.Shared.Controls;

public partial class ArcGauge
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
}