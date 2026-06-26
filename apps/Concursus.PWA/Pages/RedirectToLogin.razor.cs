using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.WebAssembly.Authentication;
using Microsoft.JSInterop;

namespace Concursus.PWA.Pages;

public partial class RedirectToLogin
{
    private const string PendingDeepLinkSessionKey = "cymbuild.pendingDeepLinkUrl";

    [Inject] private NavigationManager Nav { get; set; } = default!;
    [Inject] private IJSRuntime JsRuntime { get; set; } = default!;

    protected override async Task OnInitializedAsync()
    {
        var currentUri = Nav.Uri;

        if (!currentUri.Contains("/authentication/", StringComparison.OrdinalIgnoreCase))
        {
            await JsRuntime.InvokeVoidAsync(
                "sessionStorage.setItem",
                PendingDeepLinkSessionKey,
                currentUri);
        }

        var returnUrl = Nav.ToBaseRelativePath(currentUri);
        returnUrl = string.IsNullOrWhiteSpace(returnUrl)
            ? "/"
            : "/" + returnUrl;

        Nav.NavigateToLogin(
            "authentication/login",
            new InteractiveRequestOptions
            {
                Interaction = InteractionType.SignIn,
                ReturnUrl = returnUrl
            });
    }
}