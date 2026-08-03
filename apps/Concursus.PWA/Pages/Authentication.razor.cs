using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.WebAssembly.Authentication;
using Microsoft.JSInterop;

namespace Concursus.PWA.Pages;

public partial class Authentication
{
    private const string PendingDeepLinkSessionKey = "cymbuild.pendingDeepLinkUrl";
    private const string AuthenticationRecoveryAttemptSessionKey = "cymbuild.authRecoveryAttemptedUtc";

    [Parameter] public string? Action { get; set; }

    [Inject] private NavigationManager Nav { get; set; } = default!;
    [Inject] private IJSRuntime JsRuntime { get; set; } = default!;

    private async Task OnLogInSucceeded(RemoteAuthenticationState state)
    {
        // A completed interactive sign-in resets the one-time recovery guard.
        await RemoveSessionStorageItemAsync(AuthenticationRecoveryAttemptSessionKey);

        var pendingDeepLink = await JsRuntime.InvokeAsync<string?>(
            "sessionStorage.getItem",
            PendingDeepLinkSessionKey);

        if (string.IsNullOrWhiteSpace(pendingDeepLink))
        {
            return;
        }

        await RemoveSessionStorageItemAsync(PendingDeepLinkSessionKey);

        if (!IsLocalCymBuildUrl(pendingDeepLink))
        {
            return;
        }

        Nav.NavigateTo(pendingDeepLink, replace: true);
    }

    private async Task RemoveSessionStorageItemAsync(string key)
    {
        try
        {
            await JsRuntime.InvokeVoidAsync(
                "sessionStorage.removeItem",
                key);
        }
        catch (JSException ex)
        {
            // Storage cleanup must not turn a successful sign-in into a failed one.
            Console.Error.WriteLine(
                $"Unable to remove CymBuild authentication session key '{key}': {ex.Message}");
        }
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
