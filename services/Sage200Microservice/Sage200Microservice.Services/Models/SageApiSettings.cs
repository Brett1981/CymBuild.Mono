namespace Sage200Microservice.Services.Models
{
    /// <summary>
    /// Strongly-typed settings for Sage 200 (UKI) Professional via Sage ID.
    /// </summary>
    public sealed class SageApiSettings
    {
        /// <summary>
        /// API base, include trailing slash. e.g. https://api.columbus.sage.com/uk/sage200extra/accounts/
        /// </summary>
        public string BaseUrl { get; set; } = "https://api.columbus.sage.com/uk/sage200extra/accounts/";

        /// <summary>
        /// Client ID issued by Sage (not an email address).
        /// </summary>
        public string ClientId { get; set; } = default!;

        /// <summary>
        /// Client Secret issued by Sage (confidential client).
        /// </summary>
        public string ClientSecret { get; set; } = default!;

        /// <summary>
        /// OAuth authorize endpoint.
        /// </summary>
        public string AuthorizationEndpoint { get; set; } = "https://id.sage.com/authorize";

        /// <summary>
        /// OAuth token/refresh endpoint.
        /// </summary>
        public string TokenEndpoint { get; set; } = "https://id.sage.com/oauth/token";

        /// <summary>
        /// Redirect URI registered in your Sage credentials (server-side page).
        /// </summary>
        public string RedirectUri { get; set; } = default!;

        /// <summary>
        /// OAuth revocation endpoint (optional; used by RevokeAccessTokenAsync).
        /// </summary>
        public string RevocationEndpoint { get; set; } = "https://id.sage.com/oauth/revoke";

        /// <summary>
        /// Space-separated scopes required by Sage 200.
        /// </summary>
        public string Scopes { get; set; } = "openid profile email offline_access";

        /// <summary>
        /// Audience parameter for authorize request.
        /// </summary>
        public string Audience { get; set; } = "s200ukipd/sage200";

        /// <summary>
        /// Chosen Site ID to target (X-Site).
        /// </summary>
        public string SiteId { get; set; } = default!;

        /// <summary>
        /// Chosen Company ID to target (X-Company).
        /// </summary>
        public string CompanyId { get; set; } = default!;
    }
}