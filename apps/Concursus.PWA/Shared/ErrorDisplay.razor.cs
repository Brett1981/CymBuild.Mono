using Microsoft.AspNetCore.Components;

namespace Concursus.PWA.Shared;

public partial class ErrorDisplay
{
    [Parameter] public string? ErrorMessage { get; set; }
}