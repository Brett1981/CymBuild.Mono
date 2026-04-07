using Microsoft.Extensions.Options;
using Sage200Microservice.Services.Interfaces;
using Sage200Microservice.Services.Models;
using System.Net.Http.Headers;

namespace Sage200Microservice.API.Validators
{
    // NOTE: register this in Program.cs (see below).
    /// <summary>
    /// Applies Bearer token + Sage 200 required headers (X-Site, X-Company) to every request, and
    /// retries once on 401 after forcing a token refresh.
    /// </summary>
    public sealed class SageAuthDelegatingHandler : DelegatingHandler
    {
        private readonly ISageAuthenticationService _auth;
        private readonly IOptions<SageApiSettings> _settings;

        /// <summary>
        /// Creates a new handler.
        /// </summary>
        public SageAuthDelegatingHandler(
            ISageAuthenticationService auth,
            IOptions<SageApiSettings> settings)
        {
            _auth = auth;
            _settings = settings;
        }

        /// <inheritdoc/>
        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            await StampAsync(request, cancellationToken);

            var response = await base.SendAsync(request, cancellationToken);
            if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized)
            {
                // Dispose the 401 so we can safely retry
                response.Dispose();

                // Try a refresh (your implementation already supports refresh/client-cred)
                await _auth.RefreshAccessTokenAsync(); // re-acquires if none exists
                await StampAsync(request, cancellationToken);

                response = await base.SendAsync(request, cancellationToken);
            }

            return response;
        }

        /// <summary>
        /// Stamps Authorization, X-Site and X-Company.
        /// </summary>
        private async Task StampAsync(HttpRequestMessage request, CancellationToken ct)
        {
            var token = await _auth.GetAccessTokenAsync();
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

            var cfg = _settings.Value;
            request.Headers.Remove("X-Site");
            request.Headers.Remove("X-Company");
            if (!string.IsNullOrWhiteSpace(cfg.SiteId))
                request.Headers.Add("X-Site", cfg.SiteId);
            if (!string.IsNullOrWhiteSpace(cfg.CompanyId))
                request.Headers.Add("X-Company", cfg.CompanyId);

            request.Headers.Accept.Clear();
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        }
    }
}