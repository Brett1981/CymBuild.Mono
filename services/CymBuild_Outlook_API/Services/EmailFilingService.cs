using Azure.Core;

namespace CymBuild_Outlook_API.Services
{
    public class EmailFilingService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly LoggingHelper _loggingHelper;
        private readonly TokenCredential _tokenCredential;

        public EmailFilingService(IServiceProvider serviceProvider, LoggingHelper loggingHelper, TokenCredential tokenCredential)
        {
            _serviceProvider = serviceProvider;
            _loggingHelper = loggingHelper;
            _tokenCredential = tokenCredential;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            //while (!stoppingToken.IsCancellationRequested)
            //{
            //    using (var scope = _serviceProvider.CreateScope())
            //    {
            //        var graphClient = scope.ServiceProvider.GetRequiredService<GraphServiceClient>();
            //        var logger = scope.ServiceProvider.GetRequiredService<ILogger<GraphHelper>>();
            //        var graphHelper = new GraphHelper(logger, _tokenCredential);

            // try { // Define the logic to poll the mailbox and process emails var messages = await
            // graphClient.Me.Messages.GetAsync((requestConfiguration) => {
            // requestConfiguration.QueryParameters.Filter = "singleValueExtendedProperties/any(ep:
            // ep/id eq 'String {00020329-0000-0000-c000-000000000046} Name FilingDetails')"; });

            // foreach (var message in messages.Value) { var filingDetails =
            // message.SingleValueExtendedProperties.FirstOrDefault(ep => ep.Id == "String
            // {00020329-0000-0000-c000-000000000046} Name FilingDetails")?.Value; if
            // (!string.IsNullOrEmpty(filingDetails)) { // Deserialize and process filing details
            // var request =
            // Newtonsoft.Json.JsonConvert.DeserializeObject<SaveToSharePointRequest>(filingDetails);
            // await graphHelper.SaveToSharePointAsync(request); } } } catch (ServiceException ex) {
            // _logger.LogError($"Error processing emails: {ex.Message}"); } }

            //    await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken); // Poll every 5 minutes
            //}
        }

        public class FilingDetails
        {
            public string SharePointSiteId { get; set; }
            public string SharePointFolderId { get; set; }
            public Guid TargetObjectGuid { get; set; }
            public Guid EntityTypeGuid { get; set; }
            public bool DoNotFile { get; set; }
            public string SubFolder { get; set; }
        }
    }
}