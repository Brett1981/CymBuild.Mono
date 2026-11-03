using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Routing;
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

        // RemoteAuthenticatorViewCore.ProcessLoginCallbackAsync unconditionally navigates
        // to GetReturnUrl(state) immediately after this callback returns, regardless of
        // any navigation performed here. For a deep link opened in a brand new tab/window,
        // that framework-computed return URL has no continuous history/state to recover
        // the original target from and falls back to the app base URI, clobbering a
        // NavigateTo call made here. Defer our correction to the LocationChanged event that
        // call produces so ours always applies last, instead of racing it.
        void OnFrameworkNavigated(object? sender, LocationChangedEventArgs e)
        {
            Nav.LocationChanged -= OnFrameworkNavigated;

            var correctionTarget = GetPostLoginCorrectionTarget(
                Nav.ToAbsoluteUri(e.Location).ToString(),
                pendingDeepLink);

            if (correctionTarget is not null)
            {
                Nav.NavigateTo(correctionTarget, replace: true);
            }
        }

        Nav.LocationChanged += OnFrameworkNavigated;
    }

    /// <summary>
    /// Decides whether the framework's own post-login navigation landed somewhere other
    /// than the recovered deep link, and if so, returns the URL to correct it to.
    /// Returns null when no correction is needed (the framework already landed correctly).
    /// </summary>
    internal static string? GetPostLoginCorrectionTarget(string frameworkNavigatedLocation, string pendingDeepLink)
    {
        return string.Equals(frameworkNavigatedLocation, pendingDeepLink, StringComparison.OrdinalIgnoreCase)
            ? null
            : pendingDeepLink;
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
