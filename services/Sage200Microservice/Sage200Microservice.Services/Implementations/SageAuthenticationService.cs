// ✅ DROP-IN FIX 2: Make SageAuthenticationService implement the missing interface members.
// - Adds GetAccessTokenAsync(CancellationToken)
// - Adds ForceRefreshAsync(CancellationToken)
// - Adds BuildAuthorizeUrl(string)
// - Keeps your existing methods intact (RefreshAccessTokenAsync, RevokeAccessTokenAsync) Put this
// in Sage200Microservice.Services.Implementations (replace your existing class).

using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Sage200Microservice.Services.Interfaces;
using Sage200Microservice.Services.Models;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;

namespace Sage200Microservice.Services.Implementations
{
    /// <summary>
    /// Handles OAuth token lifecycle for Sage 200 (client credentials by default with optional refresh).
    /// </summary>
    public class SageAuthenticationService : ISageAuthenticationService
    {
        private readonly ILogger<SageAuthenticationService> _logger;
        private readonly HttpClient _httpClient;
        private readonly SageApiSettings _settings;

        private OAuthToken? _currentToken;
        private readonly object _lockObject = new();

        public SageAuthenticationService(
            ILogger<SageAuthenticationService> logger,
            IOptions<SageApiSettings> settings,
            IHttpClientFactory httpClientFactory)
        {
            _logger = logger;
            _settings = settings.Value;
            _httpClient = httpClientFactory.CreateClient("SageAuth");
        }

        /// <summary>
        /// Returns a valid access token (refreshes or re-acquires if needed).
        /// </summary>
        public async Task<string> GetAccessTokenAsync(CancellationToken ct = default)
        {
            // If we still have a valid access token, return it.
            if (_currentToken is not null && !_currentToken.IsExpired())
                return _currentToken.AccessToken;

            // If we have a token but it's expired, try a refresh.
            if (_currentToken is not null && _currentToken.IsExpired())
                return await RefreshAccessTokenAsync();

            // Otherwise, acquire a brand-new token.
            return await AcquireNewTokenAsync(ct);
        }

        /// <summary>
        /// Forces a refresh/re-acquire of the access token (used after 401 by a delegating handler).
        /// </summary>
        public async Task ForceRefreshAsync(CancellationToken ct = default)
        {
            // Try refresh; if refresh token is missing (client-credentials), re-acquire.
            try
            {
                await RefreshAccessTokenAsync();
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Refresh failed; attempting to acquire a new access token.");
                await AcquireNewTokenAsync(ct);
            }
        }

        /// <summary>
        /// Builds a user-consent authorize URL (useful if you later enable Authorization Code or
        /// Device Code flows).
        /// </summary>
        public string BuildAuthorizeUrl(string state)
        {
            // NOTE: This is not used by client-credentials, but implementing it satisfies the interface
            // and allows you to toggle user-consent flows later without changing callers.
            var enc = UrlEncoder.Default;
            var url = $"{_settings.AuthorizationEndpoint}" +
                      $"?audience={enc.Encode(_settings.Audience)}" +
                      $"&client_id={enc.Encode(_settings.ClientId)}" +
                      $"&response_type=code" +
                      $"&redirect_uri={enc.Encode(_settings.RedirectUri)}" +
                      $"&scope={enc.Encode(_settings.Scopes)}" +
                      $"&state={enc.Encode(state)}";
            return url;
        }

        /// <summary>
        /// Refreshes the access token if a refresh token exists; otherwise re-acquires a new token.
        /// </summary>
        public async Task<string> RefreshAccessTokenAsync()
        {
            if (_currentToken == null || string.IsNullOrWhiteSpace(_currentToken.RefreshToken))
            {
                // Client credentials flow doesn't return a refresh token; fallback to acquire new.
                return await AcquireNewTokenAsync(CancellationToken.None);
            }

            try
            {
                _logger.LogInformation("Refreshing OAuth token for Sage 200 API.");

                using var form = new FormUrlEncodedContent(new[]
                {
                    new KeyValuePair<string, string>("grant_type", "refresh_token"),
                    new KeyValuePair<string, string>("refresh_token", _currentToken.RefreshToken!),
                    new KeyValuePair<string, string>("client_id", _settings.ClientId),
                    new KeyValuePair<string, string>("client_secret", _settings.ClientSecret)
                });

                using var resp = await _httpClient.PostAsync(_settings.TokenEndpoint, form);
                resp.EnsureSuccessStatusCode();

                var json = await resp.Content.ReadAsStringAsync();
                var token = JsonSerializer.Deserialize<OAuthToken>(json, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                }) ?? throw new InvalidOperationException("Token refresh deserialization returned null.");

                token.AcquiredAt = DateTime.UtcNow;

                lock (_lockObject)
                    _currentToken = token;

                _logger.LogInformation("Successfully refreshed OAuth token for Sage 200 API.");
                return _currentToken.AccessToken;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error refreshing OAuth token; attempting to acquire a new token.");
                return await AcquireNewTokenAsync(CancellationToken.None);
            }
        }

        /// <summary>
        /// Revokes the current access token at the configured revocation endpoint (best-effort).
        /// </summary>
        public async Task<bool> RevokeAccessTokenAsync()
        {
            if (_currentToken == null || string.IsNullOrWhiteSpace(_currentToken.AccessToken))
                return true; // nothing to revoke

            try
            {
                _logger.LogInformation("Revoking OAuth token for Sage 200 API.");

                using var form = new FormUrlEncodedContent(new[]
                {
                    new KeyValuePair<string, string>("token", _currentToken.AccessToken),
                    new KeyValuePair<string, string>("client_id", _settings.ClientId),
                    new KeyValuePair<string, string>("client_secret", _settings.ClientSecret)
                });

                using var resp = await _httpClient.PostAsync(_settings.RevocationEndpoint, form);
                resp.EnsureSuccessStatusCode();

                lock (_lockObject)
                    _currentToken = null;

                _logger.LogInformation("Successfully revoked OAuth token for Sage 200 API.");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error revoking OAuth token for Sage 200 API.");
                return false;
            }
        }

        /// <summary>
        /// Acquires a brand-new access token using Client Credentials flow (server-to-server).
        /// </summary>
        private async Task<string> AcquireNewTokenAsync(CancellationToken ct)
        {
            try
            {
                _logger.LogInformation("Acquiring new OAuth token for Sage 200 API (client credentials).");

                using var form = new FormUrlEncodedContent(new[]
                {
                    new KeyValuePair<string, string>("grant_type", "client_credentials"),
                    new KeyValuePair<string, string>("client_id", _settings.ClientId),
                    new KeyValuePair<string, string>("client_secret", _settings.ClientSecret),
                    new KeyValuePair<string, string>("scope", _settings.Scopes)
                });

                // Some providers accept Basic {base64(clientId:clientSecret)}; others ignore it.
                // Harmless to include; the form fields above are what really matter.
                var basic = Convert.ToBase64String(Encoding.ASCII.GetBytes($"{_settings.ClientId}:{_settings.ClientSecret}"));
                _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic", basic);

                using var resp = await _httpClient.PostAsync(_settings.TokenEndpoint, form, ct);
                resp.EnsureSuccessStatusCode();

                var json = await resp.Content.ReadAsStringAsync(ct);
                var token = JsonSerializer.Deserialize<OAuthToken>(json, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                }) ?? throw new InvalidOperationException("Token acquisition deserialization returned null.");

                token.AcquiredAt = DateTime.UtcNow;

                lock (_lockObject)
                    _currentToken = token;

                _logger.LogInformation("Successfully acquired new OAuth token for Sage 200 API.");
                return _currentToken.AccessToken;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error acquiring new OAuth token for Sage 200 API.");
                throw;
            }
        }
    }

    /// <summary>
    /// Minimal token model used by this service. Ensure IsExpired() reflects your expiry buffer.
    /// </summary>
    public sealed class OAuthToken
    {
        /// <summary>
        /// Access token (Bearer).
        /// </summary>
        public string AccessToken { get; set; } = default!;

        /// <summary>
        /// Refresh token (may be null/empty with client-credentials).
        /// </summary>
        public string? RefreshToken { get; set; }

        /// <summary>
        /// Lifetime (seconds) as returned by the OAuth server.
        /// </summary>
        public int ExpiresIn { get; set; }

        /// <summary>
        /// UTC time when the token was acquired.
        /// </summary>
        public DateTime AcquiredAt { get; set; }

        /// <summary>
        /// Whether the token should be considered expired (with a small safety buffer).
        /// </summary>
        public bool IsExpired(int safetySeconds = 60)
        {
            if (AcquiredAt == default) return true;
            var expiry = AcquiredAt.AddSeconds(Math.Max(0, ExpiresIn - safetySeconds));
            return DateTime.UtcNow >= expiry;
        }
    }
}