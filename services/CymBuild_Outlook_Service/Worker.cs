namespace CymBuild_Outlook_Service
{
    public class Worker : BackgroundService
    {
        private readonly LoggingHelper _loggingHelper;
        private readonly ApiService _apiService;

        public Worker(LoggingHelper loggingHelper, ApiService apiService)
        {
            _loggingHelper = loggingHelper;
            _apiService = apiService;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                _loggingHelper.LogInfo($"Worker running at: {DateTimeOffset.Now}", "ExecuteAsync()");

                try
                {
                    string url = "https://localhost:7256/api/Message"; // Example URL
                    var data = await _apiService.GetApiDataAsync(url);
                    _loggingHelper.LogInfo($"API Data: {data}", "ExecuteAsync()");
                }
                catch (Exception ex)
                {
                    _loggingHelper.LogError("Error fetching data from API.", ex, "ExecuteAsync()");
                }

                await Task.Delay(10000, stoppingToken); // Wait 10 seconds before next call
            }
        }
    }
}