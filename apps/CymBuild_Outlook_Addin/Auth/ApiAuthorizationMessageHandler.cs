// ==============================
// FILE: CymBuild_Outlook_Addin/Auth/ApiAuthorizationMessageHandler.cs
// ==============================
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.WebAssembly.Authentication;

namespace CymBuild_Outlook_Addin.Auth
{
    public sealed class ApiAuthorizationMessageHandler : AuthorizationMessageHandler
    {
        public ApiAuthorizationMessageHandler(
            IAccessTokenProvider provider,
            NavigationManager navigation,
            IConfiguration config)
            : base(provider, navigation)
        {
            var apiBaseUrl = (config["CymBuildOutlookAPI:ApiBaseUrl"] ?? string.Empty).TrimEnd('/');
            if (string.IsNullOrWhiteSpace(apiBaseUrl))
                throw new InvalidOperationException("CymBuildOutlookAPI:ApiBaseUrl is missing from appsettings.json");

            var scopesRaw = config["CymBuildOutlookAPI:Scopes"] ?? string.Empty;

            // Only keep real scopes (fixes accidental "access_as_user" token)
            var scopes = scopesRaw
                .Split(' ', StringSplitOptions.RemoveEmptyEntries)
                .Select(s => s.Trim())
                .Where(s =>
                    s.StartsWith("api://", StringComparison.OrdinalIgnoreCase) ||
                    s.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();

            ConfigureHandler(
                authorizedUrls: new[] { apiBaseUrl },
                scopes: scopes.Length > 0 ? scopes : null
            );
        }
    }
}
