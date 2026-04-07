using CymBuild_Outlook_Service;

var builder = Host.CreateDefaultBuilder(args)
    .UseWindowsService()  // Configure the app to run as a Windows service
    .ConfigureServices((hostContext, services) =>
    {
        // Retrieve configuration for LoggingHelper
        var configuration = hostContext.Configuration;
        var showInformationLogs = configuration.GetValue<bool>("Logging:Settings:ShowInformationLogs");

        // Register LoggingHelper as a singleton
        services.AddSingleton<LoggingHelper>(provider =>
        {
            var logger = provider.GetRequiredService<ILogger<LoggingHelper>>();
            return new LoggingHelper(logger, showInformationLogs);
        });

        services.AddHostedService<Worker>(); // Register your background service
        services.AddHttpClient<ApiService>(); // Add ApiService with HttpClient
    });

var host = builder.Build();
host.Run();