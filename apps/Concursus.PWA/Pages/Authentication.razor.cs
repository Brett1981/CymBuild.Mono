using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.WebAssembly.Authentication;
using Microsoft.JSInterop;

namespace Concursus.PWA.Pages;

public partial class Authentication
{
    private const string PendingDeepLinkSessionKey = "cymbuild.pendingDeepLinkUrl";

    [Parameter] public string? Action { get; set; }

    [Inject] private NavigationManager Nav { get; set; } = default!;
    [Inject] private IJSRuntime JsRuntime { get; set; } = default!;

    private async Task OnLogInSucceeded(RemoteAuthenticationState state)
    {
        var pendingDeepLink = await JsRuntime.InvokeAsync<string?>(
            "sessionStorage.getItem",
            PendingDeepLinkSessionKey);

        if (string.IsNullOrWhiteSpace(pendingDeepLink))
        {
            return;
        }

        await JsRuntime.InvokeVoidAsync(
            "sessionStorage.removeItem",
            PendingDeepLinkSessionKey);

        if (!IsLocalCymBuildUrl(pendingDeepLink))
        {
            return;
        }

        Nav.NavigateTo(pendingDeepLink, replace: true);
    }

    private bool IsLocalCymBuildUrl(string url)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var targetUri))
        {
            return false;
        }

        if (!Uri.TryCreate(Nav.BaseUri, UriKind.Absolute, out var baseUri))
        {
            return false;
        }

        return string.Equals(
            targetUri.GetLeftPart(UriPartial.Authority),
            baseUri.GetLeftPart(UriPartial.Authority),
            StringComparison.OrdinalIgnoreCase);
    }
}