using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace Concursus.API.Sage.SOAP
{
    /// <summary>
    /// Validates SageApiOptions at startup so bad environment configuration fails fast.
    /// </summary>
    public sealed class SageApiOptionsValidator : IValidateOptions<SageApiOptions>
    {
        private readonly IHostEnvironment _hostEnvironment;

        public SageApiOptionsValidator(IHostEnvironment hostEnvironment)
        {
            _hostEnvironment = hostEnvironment;
        }

        public ValidateOptionsResult Validate(string? name, SageApiOptions options)
        {
            if (options is null)
            {
                return ValidateOptionsResult.Fail("SageApiOptions configuration is missing.");
            }

            if (!options.Enabled)
            {
                return ValidateOptionsResult.Success;
            }

            if (string.IsNullOrWhiteSpace(options.BaseUrl))
            {
                return ValidateOptionsResult.Fail("Integrations:SageApi:BaseUrl must be provided when Sage integration is enabled.");
            }

            if (!Uri.TryCreate(options.BaseUrl, UriKind.Absolute, out var uri))
            {
                return ValidateOptionsResult.Fail("Integrations:SageApi:BaseUrl must be a valid absolute URI.");
            }

            if (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps)
            {
                return ValidateOptionsResult.Fail("Integrations:SageApi:BaseUrl must use http or https.");
            }

            if (options.TimeoutSeconds < 1 || options.TimeoutSeconds > 300)
            {
                return ValidateOptionsResult.Fail("Integrations:SageApi:TimeoutSeconds must be between 1 and 300.");
            }

            if (options.RequireApiKey && string.IsNullOrWhiteSpace(options.ApiKey))
            {
                return ValidateOptionsResult.Fail("Integrations:SageApi:ApiKey is required when RequireApiKey is true.");
            }

            if (string.IsNullOrWhiteSpace(options.ApiKeyHeaderName))
            {
                return ValidateOptionsResult.Fail("Integrations:SageApi:ApiKeyHeaderName must not be empty.");
            }

            var isLocalhost =
                uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
                uri.Host.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase) ||
                uri.Host.Equals("::1", StringComparison.OrdinalIgnoreCase);

            if (uri.Scheme == Uri.UriSchemeHttp && !options.AllowInsecureHttp)
            {
                return ValidateOptionsResult.Fail(
                    "Integrations:SageApi:BaseUrl uses HTTP but AllowInsecureHttp is false. Use HTTPS for UAT/LIVE, or explicitly allow HTTP for local DEV.");
            }

            if (!_hostEnvironment.IsDevelopment() && isLocalhost)
            {
                return ValidateOptionsResult.Fail(
                    "Non-development environment cannot target a localhost Sage endpoint.");
            }

            if (!_hostEnvironment.IsDevelopment() && uri.Scheme != Uri.UriSchemeHttps)
            {
                return ValidateOptionsResult.Fail(
                    "Non-development environments must use HTTPS for Sage integration.");
            }

            return ValidateOptionsResult.Success;
        }
    }
}