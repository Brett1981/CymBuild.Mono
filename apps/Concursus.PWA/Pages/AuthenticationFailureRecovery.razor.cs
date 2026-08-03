using System.Globalization;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.WebAssembly.Authentication;
using Microsoft.JSInterop;

namespace Concursus.PWA.Pages;

public partial class AuthenticationFailureRecovery
{
    private const string PendingDeepLinkSessionKey = "cymbuild.pendingDeepLinkUrl";
    private const string AuthenticationRecoveryAttemptSessionKey = "cymbuild.authRecoveryAttemptedUtc";
    private static readonly TimeSpan AutomaticRecoveryGuardPeriod = TimeSpan.FromMinutes(5);

    [Parameter] public string? ErrorMessage { get; set; }

    [Inject] private NavigationManager Nav { get; set; } = default!;
    [Inject] private IJSRuntime JsRuntime { get; set; } = default!;

    private bool _recoveryEvaluated;
    private bool _navigationStarted;
    private bool _automaticRecoveryAlreadyAttempted;
    private bool _isRecoverableFailure;

    private string Heading =>
        _isRecoverableFailure
            ? "Your CymBuild session has expired"
            : "CymBuild could not complete sign-in";

    private string StatusMessage =>
        _isRecoverableFailure
            ? _automaticRecoveryAlreadyAttempted
                ? "Automatic session recovery has already been attempted. Select Sign in again to start a fresh Microsoft sign-in."
                : "CymBuild is starting a fresh Microsoft sign-in so that you can continue without restarting the application."
            : "Select Sign in again to retry. If the problem continues, contact the CymBuild support team.";

    protected override void OnParametersSet()
    {
        _isRecoverableFailure = IsRecoverableAuthenticationFailure(ErrorMessage);
    }

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (!firstRender || _recoveryEvaluated)
        {
            return;
        }

        _recoveryEvaluated = true;

        if (!_isRecoverableFailure)
        {
            return;
        }

        _automaticRecoveryAlreadyAttempted = await WasAutomaticRecoveryAttemptedRecentlyAsync();

        if (_automaticRecoveryAlreadyAttempted)
        {
            await InvokeAsync(StateHasChanged);
            return;
        }

        await StartInteractiveSignInAsync();
    }

    private Task SignInAgainAsync()
    {
        return StartInteractiveSignInAsync();
    }

    private async Task StartInteractiveSignInAsync()
    {
        if (_navigationStarted)
        {
            return;
        }

        _navigationStarted = true;
        await InvokeAsync(StateHasChanged);

        await SetRecoveryAttemptTimestampAsync();

        var pendingDeepLink = await GetSessionStorageValueAsync(PendingDeepLinkSessionKey);
        var returnUrl = BuildLocalReturnUrl(pendingDeepLink);

        var requestOptions = new InteractiveRequestOptions
        {
            Interaction = InteractionType.SignIn,
            ReturnUrl = returnUrl
        };

        // Force a genuinely interactive Entra request instead of reusing the expired grant.
        requestOptions.TryAddAdditionalParameter("prompt", "login");

        Nav.NavigateToLogin(
            "authentication/login",
            requestOptions);
    }

    private async Task<bool> WasAutomaticRecoveryAttemptedRecentlyAsync()
    {
        var value = await GetSessionStorageValueAsync(AuthenticationRecoveryAttemptSessionKey);

        if (!long.TryParse(
                value,
                NumberStyles.Integer,
                CultureInfo.InvariantCulture,
                out var attemptedUnixSeconds))
        {
            return false;
        }

        try
        {
            var attemptedUtc = DateTimeOffset.FromUnixTimeSeconds(attemptedUnixSeconds);
            var age = DateTimeOffset.UtcNow - attemptedUtc;

            return age >= TimeSpan.Zero &&
                   age < AutomaticRecoveryGuardPeriod;
        }
        catch (ArgumentOutOfRangeException)
        {
            return false;
        }
    }

    private async Task SetRecoveryAttemptTimestampAsync()
    {
        try
        {
            var value = DateTimeOffset.UtcNow
                .ToUnixTimeSeconds()
                .ToString(CultureInfo.InvariantCulture);

            await JsRuntime.InvokeVoidAsync(
                "sessionStorage.setItem",
                AuthenticationRecoveryAttemptSessionKey,
                value);
        }
        catch (JSException ex)
        {
            // A storage restriction must not prevent an interactive sign-in attempt.
            Console.Error.WriteLine(
                $"Unable to store the CymBuild authentication recovery guard: {ex.Message}");
        }
    }

    private async Task<string?> GetSessionStorageValueAsync(string key)
    {
        try
        {
            return await JsRuntime.InvokeAsync<string?>(
                "sessionStorage.getItem",
                key);
        }
        catch (JSException ex)
        {
            Console.Error.WriteLine(
                $"Unable to read CymBuild authentication session key '{key}': {ex.Message}");

            return null;
        }
    }

    private string BuildLocalReturnUrl(string? pendingDeepLink)
    {
        if (string.IsNullOrWhiteSpace(pendingDeepLink) ||
            !Uri.TryCreate(pendingDeepLink, UriKind.Absolute, out var targetUri) ||
            !Uri.TryCreate(Nav.BaseUri, UriKind.Absolute, out var baseUri) ||
            !string.Equals(
                targetUri.GetLeftPart(UriPartial.Authority),
                baseUri.GetLeftPart(UriPartial.Authority),
                StringComparison.OrdinalIgnoreCase))
        {
            return "/";
        }

        var relativeUrl = Nav.ToBaseRelativePath(targetUri.ToString());

        if (string.IsNullOrWhiteSpace(relativeUrl) ||
            relativeUrl.StartsWith("authentication/", StringComparison.OrdinalIgnoreCase))
        {
            return "/";
        }

        return "/" + relativeUrl.TrimStart('/');
    }

    private static bool IsRecoverableAuthenticationFailure(string? errorMessage)
    {
        if (string.IsNullOrWhiteSpace(errorMessage))
        {
            return false;
        }

        return RecoverableFailureMarkers.Any(
            marker => errorMessage.Contains(marker, StringComparison.OrdinalIgnoreCase));
    }

    private static readonly string[] RecoverableFailureMarkers =
    [
        "AADSTS70008",
        "AADSTS700082",
        "AADSTS700084",
        "interaction_required",
        "login_required",
        "invalid_grant",
        "authorization code or refresh token has expired",
        "refresh token has expired",
        "token has expired due to inactivity"
    ];
}
