using CymBuild_Outlook_Addin.Services;

namespace CymBuild_Outlook_Addin.Extentensions
{
    public static class ServiceExtensions
    {
        public static void AddHttpClients(this IServiceCollection services, string apiBaseUrl)
        {
            // Centralize the configuration of HTTP clients
            var baseAddress = new Uri(apiBaseUrl);
            services.AddScoped(sp => new HttpClient { BaseAddress = baseAddress });

            services.AddHttpClient<TargetObjectService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<RowStatusService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<RecordSearchService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<PreferenceService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<OutlookEmailsSysReadyToFileService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<OutlookEmailsSysNotFiledService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<OutlookEmailMailboxService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<OutlookEmailFromAddressService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<OutlookEmailConversationService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<OutlookEmailService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<OutlookCalendarEventService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<MessageService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<EntityTypeService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<GraphService>(client => client.BaseAddress = baseAddress);
            services.AddHttpClient<EmailDescriptionService>(client => client.BaseAddress = baseAddress);
        }
    }
}