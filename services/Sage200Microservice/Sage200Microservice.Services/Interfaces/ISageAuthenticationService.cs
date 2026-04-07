namespace Sage200Microservice.Services.Interfaces
{
    /// <summary>
    /// Contract for acquiring, refreshing and revoking OAuth tokens for Sage 200.
    /// </summary>
    public interface ISageAuthenticationService
    {
        /// <summary>
        /// Returns a valid access token, refreshing if needed.
        /// </summary>
        Task<string> GetAccessTokenAsync(CancellationToken ct = default);

        /// <summary>
        /// Forces a refresh token exchange (or re-acquire) – used after 401.
        /// </summary>
        Task ForceRefreshAsync(CancellationToken ct = default);

        /// <summary>
        /// Builds the user-facing authorize URL (if you later enable user-consent flows).
        /// </summary>
        string BuildAuthorizeUrl(string state);

        /// <summary>
        /// Refreshes the access token if it's expired (falls back to re-acquire).
        /// </summary>
        Task<string> RefreshAccessTokenAsync();

        /// <summary>
        /// Revokes the current access token (best-effort).
        /// </summary>
        Task<bool> RevokeAccessTokenAsync();
    }
}