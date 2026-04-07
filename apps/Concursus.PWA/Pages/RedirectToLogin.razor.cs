using Microsoft.AspNetCore.Components.WebAssembly.Authentication;

namespace Concursus.PWA.Pages;

public partial class RedirectToLogin
{
    protected override void OnInitialized()
    {
        Navigation.NavigateToLogin("authentication/login");
    }
}