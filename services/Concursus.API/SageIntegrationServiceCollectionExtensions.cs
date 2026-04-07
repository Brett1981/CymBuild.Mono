using Concursus.API.Sage.SOAP;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using System;

namespace Concursus.API.Services.Finance
{
    /// <summary>
    /// Service registration helper for the CymBuild Sage REST-wrapper Phase 5 pipeline.
    ///
    /// This centralises Phase 5 DI so registration does not become fragmented between
    /// Program.cs and multiple ad hoc setup blocks.
    /// </summary>
    public static class SageIntegrationServiceCollectionExtensions
    {
        /// <summary>
        /// Registers all Phase 5 sales-order submission services.
        /// </summary>
        public static IServiceCollection AddCymBuildSagePhase5(
            this IServiceCollection services,
            IConfiguration configuration)
        {
            if (services is null)
            {
                throw new ArgumentNullException(nameof(services));
            }

            if (configuration is null)
            {
                throw new ArgumentNullException(nameof(configuration));
            }

            services.AddOptions<SageSalesOrderMappingOptions>()
                .Bind(configuration.GetSection("Integrations:SageApi:SalesOrders"))
                .ValidateDataAnnotations()
                .ValidateOnStart();

            services.AddHttpClient<ISageSalesOrderGateway, SageSalesOrderGateway>((sp, client) =>
            {
                var options = sp.GetRequiredService<IOptions<SageApiOptions>>().Value;

                if (!string.IsNullOrWhiteSpace(options.BaseUrl))
                {
                    client.BaseAddress = new Uri(options.BaseUrl, UriKind.Absolute);
                }

                var timeout = options.TimeoutSeconds > 0 ? options.TimeoutSeconds : 60;
                client.Timeout = TimeSpan.FromSeconds(timeout);
            });

            services.AddScoped<ISageSalesOrderRequestMapper, SageSalesOrderRequestMapper>();
            services.AddScoped<IApprovedTransactionForSagePayloadFactory, ApprovedTransactionForSagePayloadFactory>();
            services.AddScoped<ITransactionToSageSubmissionService, TransactionToSageSubmissionService>();

            return services;
        }
    }
}