using System.ComponentModel.DataAnnotations;

namespace Concursus.API.Sage.SOAP
{
    /// <summary>
    /// Configuration for the outbound Sage API integration.
    /// This is bound from configuration at Integrations:SageApi.
    /// Existing behaviour is preserved:
    /// - BaseUrl still controls the endpoint
    /// - Enabled still turns the integration on/off
    /// - ApiKey / ApiKeyHeaderName / ApiKeyPrefix still work as before
    /// Added behaviour:
    /// - TimeoutSeconds is configurable
    /// - RequireApiKey can be enforced in UAT/Live
    /// - AllowInsecureHttp can be used for localhost mock dev only
    /// - EnvironmentName improves diagnostics/logging
    /// </summary>
    public sealed class SageApiOptions
    {
        /// <summary>
        /// Enables or disables the Sage integration.
        /// When false, the service remains registered but outbound calls should be blocked safely.
        /// </summary>
        public bool Enabled { get; set; }

        /// <summary>
        /// Friendly label for diagnostics only, e.g. DEV / UAT / LIVE.
        /// </summary>
        [MaxLength(50)]
        public string EnvironmentName { get; set; } = string.Empty;

        /// <summary>
        /// Absolute base URL of the Sage API, e.g. http://localhost:8080 or https://sage-uat.socotec.co.uk.
        /// </summary>
        [Required]
        [MaxLength(2048)]
        public string BaseUrl { get; set; } = string.Empty;

        /// <summary>
        /// Request timeout in seconds for outbound Sage API calls.
        /// </summary>
        [Range(1, 300)]
        public int TimeoutSeconds { get; set; } = 60;

        /// <summary>
        /// When true, the integration requires an API key to be present if Enabled = true.
        /// Recommended true for UAT and LIVE.
        /// </summary>
        public bool RequireApiKey { get; set; }

        /// <summary>
        /// API key value to send to the Sage API when configured.
        /// </summary>
        public string? ApiKey { get; set; }

        /// <summary>
        /// Header name used for API key authentication.
        /// Defaults to Authorization.
        /// </summary>
        [MaxLength(200)]
        public string ApiKeyHeaderName { get; set; } = "Authorization";

        /// <summary>
        /// Prefix used when ApiKeyHeaderName is Authorization, e.g. Bearer.
        /// </summary>
        [MaxLength(50)]
        public string ApiKeyPrefix { get; set; } = "Bearer";

        /// <summary>
        /// Allows HTTP endpoints instead of HTTPS.
        /// Intended only for local development/mock usage.
        /// </summary>
        public bool AllowInsecureHttp { get; set; }

        /// <summary>
        /// Optional health endpoint path. Defaults to /health to preserve current behaviour.
        /// </summary>
        [MaxLength(200)]
        public string HealthPath { get; set; } = "/health";
    }
}