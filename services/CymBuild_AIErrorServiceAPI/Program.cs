using CymBuild_AIErrorServiceAPI;
using CymBuild_AIErrorServiceAPI.Services;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;

try
{
    var builder = WebApplication.CreateBuilder(args);
    // this line hooks into the SCM start/stop lifecycle:
    builder.Host.UseWindowsService();
    // Database context
    builder.Services.AddDbContext<AiErrorDbContext>(options =>
        options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

    // Shared HttpClient factory
    builder.Services.AddHttpClient();

    // Jira OAuth + Ticketing Services
    builder.Services.AddHttpClient<JiraOAuthService>();
    builder.Services.AddSingleton<JiraOAuthService>();  // persists token across requests

    builder.Services.AddHttpClient<JiraTicketService>();
    builder.Services.AddScoped<JiraTicketService>();

    // AI Analyzer Service
    builder.Services.AddScoped<AiAnalyzerService>();

    // Azure AD JWT Authentication Disabled below for test
    //builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    //    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

    //builder.Services.AddAuthorization();
    builder.Services.AddCors(options =>
    {
        options.AddPolicy("AllowFrontend", builder =>
        {
            builder
                .WithOrigins("https://localhost:7202") // Must explicitly match PWA origin
                .AllowAnyHeader()
                .AllowAnyMethod()
                .AllowCredentials(); // Now safe
        });
    });
    builder.Services.AddControllers();

    // Swagger
    builder.Services.AddEndpointsApiExplorer();

    builder.Services.AddSwaggerGen(options =>
    {
        options.SwaggerDoc("v1", new OpenApiInfo { Title = "AiErrorServiceAPI", Version = "v1" });

        options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
        {
            Description = "JWT Authorization header using the Bearer scheme (e.g. 'Bearer ey...')",
            Name = "Authorization",
            In = ParameterLocation.Header,
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT"
        });

        // .NET 10 / Microsoft.OpenApi 2.x+ compatible requirement
        options.AddSecurityRequirement(document =>
            new OpenApiSecurityRequirement
            {
                [new OpenApiSecuritySchemeReference("Bearer", document)] = new List<string>()
            });
    });

    builder.Services.Configure<FormOptions>(options => options.MultipartBodyLengthLimit = 52428800); // 50 MB limit
    builder.Services.Configure<SwaggerGenOptions>(options =>
    {
        options.SupportNonNullableReferenceTypes();
    });
    // Background Jira Sync Retry
    builder.Services.AddHostedService<JiraSyncRetryService>();
    builder.Services.AddHostedService<JiraSyncSchedulerService>();

    var testPath = Path.Combine(AppContext.BaseDirectory, "before-startup.txt");
    File.WriteAllText(testPath, "We got this far...");

    var app = builder.Build();
    app.UseCors("AllowFrontend");
    // Swagger UI (dev only)
    //if (app.Environment.IsDevelopment())
    //{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "AIErrorServiceAPI v1");
        c.RoutePrefix = "swagger"; // Optional, ensures it loads from /swagger/
    });
    app.MapOpenApi(); // Optional if you're using NSwag or OpenAPI endpoints
    //}

    // Middleware
    app.UseHttpsRedirection();
    app.UseAuthentication();
    app.UseAuthorization();

    app.MapControllers();
    app.Run();
}
catch (Exception ex)
{
    var basePath = AppContext.BaseDirectory;
    var logPath = Path.Combine(basePath, "startup-error.txt");

    File.WriteAllText(logPath, ex.ToString());
    throw;
}