using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Sage200Microservice.API;
using Sage200Microservice.API.Configuration;
using Sage200Microservice.API.HealthChecks;
using Sage200Microservice.API.Logging;
using Sage200Microservice.API.Metrics;
using Sage200Microservice.API.Middleware;
using Sage200Microservice.API.Monitoring;
using Sage200Microservice.API.Services;
using Sage200Microservice.API.Tracing;
using Sage200Microservice.API.Validators;
using Sage200Microservice.Data;
using Sage200Microservice.Data.Repositories;
using Sage200Microservice.Services.Implementations;
using Sage200Microservice.Services.Interfaces;
using Sage200Microservice.Services.Models;
using Serilog;

Console.WriteLine("BOOT: starting main"); // visible even if Serilog fails

// Catch anything not flowing through the normal pipeline
AppDomain.CurrentDomain.UnhandledException += (s, e) =>
{
    Console.Error.WriteLine($"UNHANDLED EXCEPTION: {e.ExceptionObject}");
    if (e.ExceptionObject is Exception ex) Log.Fatal(ex, "UNHANDLED EXCEPTION");
};
TaskScheduler.UnobservedTaskException += (s, e) =>
{
    Console.Error.WriteLine($"UNOBSERVED TASK EXCEPTION: {e.Exception}");
    Log.Error(e.Exception, "UNOBSERVED TASK EXCEPTION");
    e.SetObserved();
};

// Enable Serilog self-diagnostics to the console (helps when nothing shows up)
//SelfLog.Enable(msg => Console.Error.WriteLine("SERILOG-SELFLOG: " + msg));

try
{
    var builder = WebApplication.CreateBuilder(args);

    // Be explicit about server URLs so we know where it *tries* to bind. (launchSettings.json still
    // works; this just guarantees defaults.)
    builder.WebHost.UseKestrel()
           .UseUrls("https://localhost:7003", "http://localhost:5266");

    Console.WriteLine("BOOT: configuring Serilog");
    builder.Host.UseSerilogLogging(); // reads Serilog from appsettings*

    Console.WriteLine("BOOT: configuring OpenTelemetry logging & tracing");
    builder.Logging.AddOpenTelemetryLogging(builder.Configuration);
    builder.Services.AddDistributedTracing(builder.Configuration);

    Console.WriteLine("BOOT: adding controllers & validation");
    builder.Services
        .AddControllers(o => o.Filters.Add<Sage200Microservice.API.Filters.ValidationFilter>())
        .AddJsonOptions(o => o.JsonSerializerOptions.PropertyNamingPolicy = null);
    builder.Services.AddValidatorsFromAssemblyContaining<CreateCustomerRequestValidator>();

    Console.WriteLine("BOOT: configuring DbContext");
    builder.Services.AddDbContext<ApplicationContext>((sp, options) =>
    {
        var config = sp.GetRequiredService<IConfiguration>();
        var cs = config.GetConnectionString("DefaultConnection");

        options.UseSqlServer(cs, sql =>
        {
            sql.EnableRetryOnFailure(5, TimeSpan.FromSeconds(30), errorNumbersToAdd: null);
            sql.CommandTimeout(60);
            sql.UseQuerySplittingBehavior(QuerySplittingBehavior.SplitQuery);
            sql.MaxBatchSize(100);
        });
        //options.UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking);
    });

    Console.WriteLine("BOOT: registering repositories/services");
    // Repositories
    builder.Services.AddScoped<ICustomerRepository, CustomerRepository>();
    builder.Services.AddScoped<IInvoiceRepository, InvoiceRepository>();
    builder.Services.AddScoped<IInvoiceStatusHistoryRepository, InvoiceStatusHistoryRepository>();
    builder.Services.AddScoped<IApiLogRepository, ApiLogRepository>();
    builder.Services.AddScoped<IApiKeyRepository, ApiKeyRepository>();
    builder.Services.AddScoped<IAuditLogRepository, AuditLogRepository>();
    // Services
    builder.Services.AddScoped<ISageAuthenticationService, SageAuthenticationService>();
    builder.Services.AddScoped<ICustomerService, CustomerService>();
    builder.Services.AddScoped<IInvoiceService, InvoiceService>();
    builder.Services.AddScoped<IBatchProcessingService, BatchProcessingService>();
    builder.Services.AddScoped<IApiKeyService, ApiKeyService>();
    builder.Services.AddScoped<IAuditLogService, AuditLogService>();

    Console.WriteLine("BOOT: binding options");
    builder.Services.Configure<SageApiSettings>(builder.Configuration.GetSection("SageApi"));
    builder.Services.Configure<AuditLogSettings>(builder.Configuration.GetSection("AuditLogging"));
    builder.Services.Configure<BackgroundServiceSettings>(builder.Configuration.GetSection("BackgroundServices"));
    builder.Services.Configure<InvoiceStatusServiceSettings>(builder.Configuration.GetSection("BackgroundServices:InvoiceStatus"));
    builder.Services.Configure<ApiKeyRotationOptions>(builder.Configuration.GetSection("ApiKeyRotation"));

    // Delegating handler
    builder.Services.AddTransient<SageAuthDelegatingHandler>();

    Console.WriteLine("BOOT: configuring HTTP clients");
    builder.Services.AddHttpClient("SageAuth", c =>
    {
        c.DefaultRequestHeaders.Add("Accept", "application/json");
    })
    .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
    {
        PooledConnectionLifetime = TimeSpan.FromMinutes(15),
        MaxConnectionsPerServer = 100,
        KeepAlivePingPolicy = HttpKeepAlivePingPolicy.WithActiveRequests,
        KeepAlivePingDelay = TimeSpan.FromSeconds(60),
        KeepAlivePingTimeout = TimeSpan.FromSeconds(30)
    });

    builder.Services.AddHttpClient<ISageApiClient, Sage200Microservice.Services.Implementations.SageApiClient>((sp, c) =>
    {
        var cfg = sp.GetRequiredService<IOptions<SageApiSettings>>().Value;
        c.BaseAddress = new Uri(cfg.BaseUrl); // centralizes base URL
        c.Timeout = TimeSpan.FromSeconds(100);
    })
    .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
    {
        PooledConnectionLifetime = TimeSpan.FromMinutes(15),
        MaxConnectionsPerServer = 100,
        KeepAlivePingPolicy = HttpKeepAlivePingPolicy.WithActiveRequests,
        KeepAlivePingDelay = TimeSpan.FromSeconds(60),
        KeepAlivePingTimeout = TimeSpan.FromSeconds(30)
    })
    // This is the key line—bearer + X-Site + X-Company + 401 refresh:
    .AddHttpMessageHandler<SageAuthDelegatingHandler>();

    Console.WriteLine("BOOT: caching & hosted services");
    builder.Services.AddMemoryCache();
    builder.Services.AddSingleton<ICachingService, CachingService>();
    builder.Services.AddSingleton<ICacheInvalidationService, CacheInvalidationService>();

    builder.Services.AddHostedService<InvoiceStatusBackgroundService>();
    builder.Services.AddHostedService<ApiKeyRotationService>();
    builder.Services.AddHostedService<AuditLogCleanupService>();

    Console.WriteLine("BOOT: health checks / monitoring / swagger / security");
    builder.Services.AddHealthChecksConfig();
    builder.Services.AddHealthCheckDashboard(builder.Configuration);
    builder.Services.AddErrorMonitoring(builder.Configuration);
    builder.Services.AddBusinessMetrics(builder.Configuration);
    builder.Services.AddSingleton<Sage200Microservice.API.Metrics.BackgroundServiceMetrics>();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerDocumentation();
    builder.Services.AddSerilogServices();
    builder.Services.AddSingleton<Sage200Microservice.API.Configuration.ApiKeyClientResolveContributor>();
    builder.Services.AddSingleton<AspNetCoreRateLimit.IClientResolveContributor>(sp =>
        sp.GetRequiredService<Sage200Microservice.API.Configuration.ApiKeyClientResolveContributor>());
    // Uncommented below to use as AddSingleton instead of AddScoped
    //builder.Services.AddScoped<Sage200Microservice.API.Configuration.ApiKeyClientResolveContributor>();
    //builder.Services.AddScoped<AspNetCoreRateLimit.IClientResolveContributor>(sp =>
    //    sp.GetRequiredService<Sage200Microservice.API.Configuration.ApiKeyClientResolveContributor>());

    builder.Services.AddRateLimiting(builder.Configuration);
    builder.Services.AddScoped<Sage200Microservice.API.Middleware.IpFilteringMiddleware>();
    builder.Services.AddCorsPolicy(builder.Configuration);
    builder.Services.AddSecurityHeaders(builder.Configuration);
    builder.Services.AddResponseCompression(o => o.EnableForHttps = true);
    // gRPC JSON-transcoding (optional, but handy for CymBuild HTTP clients)
    builder.Services.AddGrpc().AddJsonTranscoding();
    builder.Services.AddGrpcReflection();
    builder.Services.AddGrpcSwagger();    // Microsoft.AspNetCore.Grpc.Swagger
    builder.Services.AddSwaggerGen();     // Swashbuckle

    Console.WriteLine("BOOT: building app");
    var app = builder.Build();

    // Log basic environment info early
    var env = app.Environment.EnvironmentName;
    var contentRoot = app.Environment.ContentRootPath;
    var urlsConfigured = Environment.GetEnvironmentVariable("ASPNETCORE_URLS");
    Log.Information("Environment: {Env} | ContentRoot: {ContentRoot} | ASPNETCORE_URLS={Urls}", env, contentRoot, urlsConfigured);

    // Show the (sanitized) DB connection settings
    var cs = app.Services.GetRequiredService<IConfiguration>().GetConnectionString("DefaultConnection") ?? "(null)";
    Log.Information("DB connection string in use (sanitized): {CS}", SanitizeConnectionString(cs));

    Log.Information("DB: applying migrations & seeding...");
    await DatabaseSeeder.SeedDatabaseAsync(app.Services);
    Log.Information("DB: seed complete");

    if (app.Environment.IsDevelopment())
    {
        app.UseDeveloperExceptionPage();
        app.UseSwagger();
        app.UseSwaggerUI(c =>
        {
            c.SwaggerEndpoint("/swagger/v1/swagger.json", "Sage200Microservice API v1");
            c.RoutePrefix = "swagger";
        });
        app.MapGrpcReflectionService();
    }

    // Pipeline
    app.UseGlobalExceptionHandler();
    app.UseTracing();
    app.UseDistributedTracing();
    app.UseResponseCompression();
    app.UseHttpsRedirection();
    app.UseStaticFiles();
    app.UseSecurityHeaders();
    app.UseMiddleware<Sage200Microservice.API.Middleware.IpFilteringMiddleware>();
    app.UseCorsPolicy(app.Configuration);
    app.UseRateLimiting();

    // Require API key only outside dev to avoid blocking Swagger during diagnosis
    if (!app.Environment.IsDevelopment())
        app.UseApiKeyAuthentication();

    app.UseSerilogRequestLogging();
    app.UseAuditLogging();

    app.MapControllers();
    app.MapGrpcService<InvoiceGrpcService>();
    app.UseHealthChecksConfig();
    app.UseHealthCheckDashboard(app.Configuration);

    app.MapGet("/business-dashboard", ctx =>
    {
        ctx.Response.Redirect("/business-dashboard.html");
        return Task.CompletedTask;
    });

    // Start explicitly so we can print the bound URLs before blocking
    Log.Information("Starting web host...");
    await app.StartAsync();
    Log.Information("Now listening on: {Urls}", string.Join(", ", app.Urls));
    Console.WriteLine("BOOT: app started; press Ctrl+C to exit");

    await app.WaitForShutdownAsync();
    Log.Information("Host shutdown complete");
}
catch (Exception ex)
{
    Console.Error.WriteLine("FATAL: " + ex);
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}

// --- helpers ---
static string SanitizeConnectionString(string cs)
{
    if (string.IsNullOrWhiteSpace(cs)) return cs;
    // Hide secrets
    var parts = cs.Split(';', StringSplitOptions.RemoveEmptyEntries)
                  .Select(p =>
                  {
                      var kv = p.Split('=', 2);
                      if (kv.Length != 2) return p;
                      var key = kv[0].Trim().ToLowerInvariant();
                      if (key is "password" or "pwd" or "user id" or "uid")
                          return $"{kv[0]}=***";
                      return p;
                  });
    return string.Join(';', parts);
}