// ==============================
// FILE: CymBuild_Outlook_API/Services/MSGraphBase.cs
// ==============================
using CymBuild_Outlook_Common.Helpers;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Graph;
using Microsoft.Identity.Web;
using Microsoft.Kiota.Abstractions.Authentication;
using System.Net.Http.Headers;
using System.Security.Claims;

namespace CymBuild_Outlook_API.Services
{

    /// <summary>
    /// Creates a GraphServiceClient that always authenticates using OBO (On-Behalf-Of)
    /// based on the *current request's* authenticated ClaimsPrincipal.
    /// </summary>
    public class MSGraphBase : IMSGraphBase
    {
        private readonly ITokenAcquisition _tokenAcquisition;
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly IConfiguration _configuration;
        private readonly LoggingHelper _loggingHelper;

        public MSGraphBase(
            ITokenAcquisition tokenAcquisition,
            IHttpContextAccessor httpContextAccessor,
            IConfiguration configuration,
            LoggingHelper loggingHelper)
        {
            _tokenAcquisition = tokenAcquisition;
            _httpContextAccessor = httpContextAccessor;
            _configuration = configuration;
            _loggingHelper = loggingHelper;
        }

        public GraphServiceClient GetGraphClient(string? correlationId = null)
        {
            var corr = string.IsNullOrWhiteSpace(correlationId)
                ? $"GraphBase-{DateTime.UtcNow:HHmmssfff}-{Guid.NewGuid():N}".Substring(0, 28)
                : correlationId;

            // Graph SDK v5 (Kiota): use IAccessTokenProvider + BaseBearerTokenAuthenticationProvider
            var tokenProvider = new OboAccessTokenProvider(
                httpContextAccessor: _httpContextAccessor,
                tokenAcquisition: _tokenAcquisition,
                getScopes: GetGraphScopes,
                logUserIdentitySummary: LogUserIdentitySummary,
                loggingHelper: _loggingHelper,
                correlationId: corr);

            var authProvider = new BaseBearerTokenAuthenticationProvider(tokenProvider);

            // v5 supports constructing with auth provider (preferred for custom flows)
            return new GraphServiceClient(authProvider);
        }


        private string[] GetGraphScopes()
        {
            // Prefer config; fallback to sensible delegated scopes
            var scopes = _configuration.GetSection("Graph:Scopes").Get<string[]>();
            if (scopes != null && scopes.Length > 0)
                return scopes;

            // Note: MIW supports both "User.Read" and "https://graph.microsoft.com/User.Read".
            // If you keep full URLs in config, that's fine — consistency is key.
            return new[]
            {
                "User.Read",
                "Mail.ReadWrite",
                "Mail.ReadWrite.Shared",
                "Sites.ReadWrite.All"
            };
        }

        private void LogUserIdentitySummary(string corr, ClaimsPrincipal user)
        {
            try
            {
                string Get(string type) => user.Claims.FirstOrDefault(c => c.Type == type)?.Value ?? "";

                var oid = Get("oid");
                var tid = Get("tid");
                var upn = Get("preferred_username");
                if (string.IsNullOrWhiteSpace(upn)) upn = Get("upn");
                if (string.IsNullOrWhiteSpace(upn)) upn = Get("email");

                _loggingHelper.LogInfo(
                    $"[{corr}] OBO user identity: oid={(string.IsNullOrWhiteSpace(oid) ? "(missing)" : oid)} " +
                    $"tid={(string.IsNullOrWhiteSpace(tid) ? "(missing)" : tid)} " +
                    $"upn={(string.IsNullOrWhiteSpace(upn) ? "(missing)" : upn)}",
                    "MSGraphBase.LogUserIdentitySummary()");
            }
            catch
            {
                // no-op
            }
        }
    }

    public sealed class OboAccessTokenProvider : IAccessTokenProvider
    {
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly ITokenAcquisition _tokenAcquisition;
        private readonly Func<string[]> _getScopes;
        private readonly Action<string, ClaimsPrincipal> _logUserIdentitySummary;
        private readonly LoggingHelper _loggingHelper;
        private readonly string _corr;

        public OboAccessTokenProvider(
            IHttpContextAccessor httpContextAccessor,
            ITokenAcquisition tokenAcquisition,
            Func<string[]> getScopes,
            Action<string, ClaimsPrincipal> logUserIdentitySummary,
            LoggingHelper loggingHelper,
            string correlationId)
        {
            _httpContextAccessor = httpContextAccessor;
            _tokenAcquisition = tokenAcquisition;
            _getScopes = getScopes;
            _logUserIdentitySummary = logUserIdentitySummary;
            _loggingHelper = loggingHelper;
            _corr = correlationId;

            // Allow all hosts by default; you can lock this down later if desired
            AllowedHostsValidator = new AllowedHostsValidator();
        }

        public AllowedHostsValidator AllowedHostsValidator { get; }

        public async Task<string> GetAuthorizationTokenAsync(
            Uri uri,
            Dictionary<string, object>? additionalAuthenticationContext = null,
            CancellationToken cancellationToken = default)
        {
            var httpContext = _httpContextAccessor.HttpContext;
            var user = httpContext?.User;

            if (user?.Identity?.IsAuthenticated != true)
            {
                _loggingHelper.LogError(
                    $"[{_corr}] HttpContext.User is not authenticated (null or unauthenticated). Cannot do OBO.",
                    new Exception("OBO user is null/unauthenticated"),
                    "MSGraphBase.GetGraphClient()");

                // This is the same “shape” that Identity.Web expects when OBO cannot proceed
                throw new MicrosoftIdentityWebChallengeUserException(
                    new Microsoft.Identity.Client.MsalUiRequiredException("user_null", "User is not authenticated for OBO token acquisition."),
                    _getScopes());
            }

            // Helpful diagnostics if your token is missing identity claims
            _logUserIdentitySummary(_corr, user);

            var scopes = _getScopes();

            // KEY: pass user + scheme explicitly (prevents user_null AcquireTokenSilent)
            var accessToken = await _tokenAcquisition.GetAccessTokenForUserAsync(
                scopes,
                user: user,
                authenticationScheme: JwtBearerDefaults.AuthenticationScheme);

            return accessToken;
        }
    }
}
