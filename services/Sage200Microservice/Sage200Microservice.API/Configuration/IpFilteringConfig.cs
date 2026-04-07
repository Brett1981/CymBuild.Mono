using Sage200Microservice.API.Middleware;
using Sage200Microservice.API.Security;

namespace Sage200Microservice.API.Configuration
{
    /// <summary>
    /// Configuration for IP filtering
    /// </summary>
    public static class IpFilteringConfig
    {
        /// <summary>
        /// Adds IP filtering services to the service collection
        /// </summary>
        /// <param name="services">      The service collection </param>
        /// <param name="configuration"> The configuration </param>
        /// <returns> The service collection </returns>
        public static IServiceCollection AddIpFiltering(this IServiceCollection services, IConfiguration configuration)
        {
            // Configure IP filtering options
            services.Configure<IpFilteringOptions>(configuration.GetSection("IpFiltering"));

            // Validate the configuration
            var options = configuration.GetSection("IpFiltering").Get<IpFilteringOptions>();
            if (options != null && options.Enabled)
            {
                // Validate allowed IPs
                if (!IpAddressHelper.ValidateIpRanges(options.AllowedIps))
                {
                    throw new ArgumentException("Invalid IP address or CIDR range in AllowedIps");
                }

                // Validate denied IPs
                if (!IpAddressHelper.ValidateIpRanges(options.DeniedIps))
                {
                    throw new ArgumentException("Invalid IP address or CIDR range in DeniedIps");
                }

                // Validate client restrictions
                foreach (var clientRestriction in options.ClientRestrictions.Values)
                {
                    if (!IpAddressHelper.ValidateIpRanges(clientRestriction.AllowedIps))
                    {
                        throw new ArgumentException($"Invalid IP address or CIDR range in client restriction for {clientRestriction.ClientId}");
                    }
                }
            }

            return services;
        }

        /// <summary>
        /// Adds IP filtering middleware to the application pipeline
        /// </summary>
        /// <param name="app"> The application builder </param>
        /// <returns> The application builder </returns>
        public static IApplicationBuilder UseIpFiltering(this IApplicationBuilder app)
        {
            return app.UseMiddleware<IpFilteringMiddleware>();
        }
    }
}