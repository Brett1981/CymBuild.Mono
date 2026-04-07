using Concursus.API.Classes;
using Concursus.API.Interfaces;
using Concursus.API.Models;
using Concursus.API.Sage.SOAP;
using Concursus.API.Sage.SOAP.Client;
using Concursus.API.Sage.SOAP.Interface;
using Concursus.API.Services;
using Concursus.API.Services.Finance;
using Concursus.API.Services.Graph;
using Concursus.API.Services.InvoiceAutomation;
using Concursus.API.Services.Monitoring;
using Concursus.API.Services.Outbox;
using Concursus.Common.Shared.Kafka.Core;
using Concursus.Common.Shared.Kafka.Core.Publisher;
using Concursus.Common.Shared.Models.Finance;
using Concursus.Common.Shared.Notifications.AuthAndBidNotification;
using Concursus.Common.Shared.Services.Finance;
using Concursus.EF.Finance;
using Concursus.EF.Monitoring;
using Concursus_EF;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Extensions.Options;
using Microsoft.Identity.Web;
using NLog;
using NLog.Web;
using System.Security.Claims;

var logger = LogManager.Setup().LoadConfigurationFromAppSettings().GetCurrentClassLogger();
logger.Debug("init main");

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Host.UseWindowsService();

    builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"))
        .EnableTokenAcquisitionToCallDownstreamApi()
        .AddMicrosoftGraph(builder.Configuration.GetSection("MicrosoftGraph"))
        .AddInMemoryTokenCaches();

    builder.Services.AddScoped<IDelegatedGraphClientFactory, DelegatedGraphClientFactory>();

    builder.Services.AddGrpc(c =>
    {
        c.MaxReceiveMessageSize = 16 * 1024 * 1024;
        c.MaxSendMessageSize = 16 * 1024 * 1024;
    });

    builder.Services.AddAuthorization();

    builder.Services.Configure<GoogleSettings>(builder.Configuration.GetSection("Google"));
    builder.Services.AddHttpClient<TranslationServiceImpl>();
    builder.Services.AddSignalR();

    // Register shared HTTP context accessor once.
    builder.Services.AddHttpContextAccessor();

    // -------------------------------------------------------------------------
    // Sage API configuration and validation
    // -------------------------------------------------------------------------
    builder.Services.AddSingleton<IValidateOptions<SageApiOptions>, SageApiOptionsValidator>();

    builder.Services
        .AddOptions<SageApiOptions>()
        .Bind(builder.Configuration.GetSection("Integrations:SageApi"))
        .ValidateDataAnnotations()
        .ValidateOnStart();

    // -------------------------------------------------------------------------
    // Core EF registration used by finance repositories and services
    // -------------------------------------------------------------------------
    builder.Services.AddScoped<Concursus.EF.Core>(sp =>
    {
        var configuration = sp.GetRequiredService<IConfiguration>();
        var httpContextAccessor = sp.GetRequiredService<IHttpContextAccessor>();

        var connectionString =
            configuration.GetConnectionString("DefaultConnection")
            ?? configuration.GetConnectionString("ShoreDB")
            ?? configuration.GetConnectionString("CymBuild")
            ?? throw new InvalidOperationException(
                "No database connection string was found for Concursus.EF.Core. Expected one of: DefaultConnection, ShoreDB, CymBuild.");

        var user = httpContextAccessor.HttpContext?.User ?? new ClaimsPrincipal(new ClaimsIdentity());

        return new Concursus.EF.Core(connectionString, user);
    });

    // -------------------------------------------------------------------------
    // Lower-level Sage API client registration
    // -------------------------------------------------------------------------
    builder.Services.AddHttpClient<SageApiClient>((sp, client) =>
    {
        var options = sp.GetRequiredService<IOptions<SageApiOptions>>().Value;

        if (!string.IsNullOrWhiteSpace(options.BaseUrl))
        {
            client.BaseAddress = new Uri(options.BaseUrl, UriKind.Absolute);
        }

        var timeout = options.TimeoutSeconds > 0 ? options.TimeoutSeconds : 60;
        client.Timeout = TimeSpan.FromSeconds(timeout);
    });

    // Wrap the lower-level client with feature-toggle behaviour
    builder.Services.AddScoped<ISageApiClient>(sp =>
    {
        var inner = sp.GetRequiredService<SageApiClient>();
        var options = sp.GetRequiredService<IOptionsMonitor<SageApiOptions>>();
        var featureToggleLogger = sp.GetRequiredService<ILogger<FeatureToggledSageApiClient>>();

        return new FeatureToggledSageApiClient(inner, options, featureToggleLogger);
    });

    // -------------------------------------------------------------------------
    // Phase 5 Sage sales-order mapping options
    // -------------------------------------------------------------------------
    builder.Services.AddOptions<SageSalesOrderMappingOptions>()
        .Bind(builder.Configuration.GetSection("Integrations:SageApi:SalesOrders"))
        .ValidateDataAnnotations()
        .ValidateOnStart();

    // -------------------------------------------------------------------------
    // Phase 5 dedicated worker options
    // -------------------------------------------------------------------------
    builder.Services.AddOptions<SageTransactionSubmissionWorkerOptions>()
        .Bind(builder.Configuration.GetSection("Integrations:SageApi:SubmissionWorker"))
        .ValidateDataAnnotations()
        .ValidateOnStart();

    // -------------------------------------------------------------------------
    // Phase 5 wrapper gateway
    // -------------------------------------------------------------------------
    builder.Services.AddHttpClient<ISageSalesOrderGateway, SageSalesOrderGateway>((sp, client) =>
    {
        var options = sp.GetRequiredService<IOptions<SageApiOptions>>().Value;

        if (!string.IsNullOrWhiteSpace(options.BaseUrl))
        {
            client.BaseAddress = new Uri(options.BaseUrl, UriKind.Absolute);
        }

        var timeout = options.TimeoutSeconds > 0 ? options.TimeoutSeconds : 60;
        client.Timeout = TimeSpan.FromSeconds(timeout);
    });

    // -------------------------------------------------------------------------
    // Phase 5 repositories, mapping, payload, submission, idempotency
    // -------------------------------------------------------------------------
    builder.Services.AddScoped<ITransactionToSageReadRepository, TransactionToSageReadRepository>();
    builder.Services.AddScoped<ITransactionApprovedOutboxRepository, TransactionApprovedOutboxRepository>();

    builder.Services.AddScoped<ISageSalesOrderRequestMapper, SageSalesOrderRequestMapper>();
    builder.Services.AddScoped<IApprovedTransactionForSagePayloadFactory, ApprovedTransactionForSagePayloadFactory>();
    builder.Services.AddScoped<ITransactionToSageSubmissionService, TransactionToSageSubmissionService>();

    builder.Services.AddScoped<ITransactionToSageEligibilityValidator, TransactionToSageEligibilityValidator>();
    builder.Services.AddScoped<ITransactionToSageIdempotencyRepository, TransactionToSageIdempotencyRepository>();
    builder.Services.AddScoped<ITransactionToSageIdempotencyService, TransactionToSageIdempotencyService>();

    builder.Services.AddScoped<ITransactionSageSubmissionAdminRepository, TransactionSageSubmissionAdminRepository>();
    builder.Services.AddScoped<ITransactionSageSubmissionAdminService, TransactionSageSubmissionAdminService>();

    builder.Logging.ClearProviders();
    builder.Host.UseNLog();

    builder.Services.AddCors(o => o.AddPolicy("AllowAll", policyBuilder =>
    {
        policyBuilder.AllowAnyOrigin()
            .AllowAnyMethod()
            .AllowAnyHeader()
            .WithExposedHeaders("Grpc-Status", "Grpc-Message", "Grpc-Encoding", "Grpc-Accept-Encoding");
    }));

    builder.Services.Configure<LookupServicesOptions>(
        builder.Configuration.GetSection("LookupServices"));

    builder.Services.AddHttpClient<ILookupService, LookupService>();

    builder.Services.AddControllers();
    builder.Services.AddScoped<ISharepointService, SharepointService>();

    builder.Services.AddScoped<JobClosureDecisionRepository>();

    builder.Services.AddSingleton<Concursus.Common.Notifications.INotificationPublisher,
                                  Concursus.Common.Notifications.NoOpNotificationPublisher>();

    builder.Services.Configure<KafkaOptions>(builder.Configuration.GetSection("Kafka"));
    KafkaServices.Add(builder.Services, builder.Configuration);

    builder.Services.AddScoped<NotificationService>();

    // -------------------------------------------------------------------------
    // Existing hosted/background services
    // -------------------------------------------------------------------------
    builder.Services.AddScoped<WorkflowOutboxRepository>();
    builder.Services.AddHostedService<WorkflowOutboxKafkaPublisherWorker>();

    builder.Services.Configure<InvoiceAutomationOptions>(builder.Configuration.GetSection("InvoiceAutomation"));
    builder.Services.AddSingleton<InvoiceAutomationRepository>();
    builder.Services.AddHostedService<InvoiceAutomationScheduledWorker>();

    // -------------------------------------------------------------------------
    // Dedicated Phase 5 Sage transaction submission worker
    // -------------------------------------------------------------------------
    builder.Services.AddHostedService<SageTransactionSubmissionWorker>();

    var app = builder.Build();

    var sageOptions = app.Services.GetRequiredService<IOptions<SageApiOptions>>().Value;
    logger.Info(
        "Sage integration configuration loaded. Enabled={Enabled}; EnvironmentName={EnvironmentName}; BaseUrl={BaseUrl}; TimeoutSeconds={TimeoutSeconds}; ApiKeyConfigured={ApiKeyConfigured}",
        sageOptions.Enabled,
        string.IsNullOrWhiteSpace(sageOptions.EnvironmentName) ? app.Environment.EnvironmentName : sageOptions.EnvironmentName,
        sageOptions.BaseUrl,
        sageOptions.TimeoutSeconds,
        !string.IsNullOrWhiteSpace(sageOptions.ApiKey));

    if (app.Environment.IsDevelopment())
    {
        app.UseDeveloperExceptionPage();
    }

    var webSocketOptions = new WebSocketOptions
    {
        KeepAliveInterval = TimeSpan.FromMinutes(2)
    };
    app.UseWebSockets(webSocketOptions);

    app.UseForwardedHeaders(new ForwardedHeadersOptions
    {
        ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
    });

    app.UseRouting();

    app.UseCors("AllowAll");

    app.UseAuthentication();
    app.UseAuthorization();

    app.UseGrpcWeb();

    app.MapGrpcService<CoreService>()
        .EnableGrpcWeb()
        .RequireCors("AllowAll");

    app.MapGrpcService<DmsService>()
        .EnableGrpcWeb()
        .RequireCors("AllowAll");

    app.MapGrpcService<TranslationServiceImpl>()
        .EnableGrpcWeb()
        .RequireCors("AllowAll");

    app.MapControllers();

    app.MapHub<FileProcessingHub>("/fileProcessingHub")
        .RequireCors("AllowAll");

    app.MapGet("/",
        () =>
            "Communication with gRPC endpoints must be made through a gRPC client. To learn how to create a client, visit: https://go.microsoft.com/fwlink/?linkid=2086909");

    app.Run();
}
catch (OperationCanceledException)
{
    // Normal during Windows Service stop / IIS recycle / shutdown.
}
catch (Exception exception)
{
    logger.Error(exception, "Stopped program because of exception");
    throw;
}
finally
{
    LogManager.Shutdown();
}