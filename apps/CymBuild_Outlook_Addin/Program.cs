// ==============================
// FILE: CymBuild_Outlook_Addin/Program.cs
// ==============================
using CymBuild_Outlook_Addin;
using CymBuild_Outlook_Addin.Auth;
using CymBuild_Outlook_Addin.Extentensions;
using CymBuild_Outlook_Addin.Services;
using CymBuild_Outlook_Common.Controls;
using CymBuild_Outlook_Common.Helpers;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Authentication;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using Microsoft.IdentityModel.Logging;
using Microsoft.JSInterop;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

// Ensure appsettings.json is loaded
builder.Configuration.AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);
builder.Services.AddSingleton<IConfiguration>(builder.Configuration);

// --------------------
// PII logging toggle
// --------------------
var identityModelConfig = builder.Configuration.GetSection("IdentityModel");
IdentityModelEventSource.ShowPII = identityModelConfig.GetValue<bool>("ShowPII", false);

// --------------------
// LOGGING
// --------------------
builder.Services.AddLogging(loggingBuilder => loggingBuilder.SetMinimumLevel(LogLevel.Debug));

// Browser console logger (you already have this)
builder.Services.AddSingleton<ILogger>(provider =>
{
    var jsRuntime = provider.GetRequiredService<IJSRuntime>();
    return new BrowserConsoleLogger(jsRuntime, "DefaultCategory");
});

// LoggingHelper (you already have this)
builder.Services.AddSingleton<LoggingHelper>(provider =>
{
    var logger = provider.GetRequiredService<ILogger<LoggingHelper>>();
    var showInformationLogs = builder.Configuration.GetValue<bool>("Logging:Settings:ShowInformationLogs");
    return new LoggingHelper(logger, showInformationLogs);
});

// --------------------
// Correlation ID (WASM)
// --------------------
builder.Services.AddScoped<CorrelationIdProvider>();

// Outgoing HTTP logging + correlation handlers
builder.Services.AddScoped<CorrelationIdDelegatingHandler>();
builder.Services.AddScoped<HttpLoggingDelegatingHandler>();

//// --------------------
//// AUTH (MSAL) – for API access_as_user
//// --------------------
//builder.Services.AddMsalAuthentication(options =>
//{
//    var azureAdConfig = builder.Configuration.GetSection("AzureAd");
//    var apiConfig = builder.Configuration.GetSection("CymBuildOutlookAPI");

//    options.ProviderOptions.Authentication.Authority =
//        $"{azureAdConfig["Authority"]}/{azureAdConfig["TenantId"]}/v2.0";

//    options.ProviderOptions.Authentication.ClientId = azureAdConfig["ClientId"];

//    // API scope(s) (MSAL token for your protected API)
//    var apiScopesRaw = apiConfig["Scopes"] ?? string.Empty;

//    // Only add valid scopes (avoid accidentally adding bare "access_as_user")
//    var apiScopes = apiScopesRaw
//        .Split(' ', StringSplitOptions.RemoveEmptyEntries)
//        .Select(s => s.Trim())
//        .Where(s =>
//            s.StartsWith("api://", StringComparison.OrdinalIgnoreCase) ||
//            s.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
//        .Distinct(StringComparer.OrdinalIgnoreCase);

//    foreach (var s in apiScopes)
//        options.ProviderOptions.DefaultAccessTokenScopes.Add(s);
//});


// --------------------
// AUTH (Office SSO ONLY)
// --------------------
// Step 2: Disable Blazor MSAL for the add-in. We standardise on:
// Office SSO token (JS) -> attach as Bearer -> call API
// (API then does OBO to Graph)
// --------------------


// HTTP CLIENTS
// --------------------
var apiBaseUrl = builder.Configuration["CymBuildOutlookAPI:ApiBaseUrl"] ?? "";
if (string.IsNullOrWhiteSpace(apiBaseUrl))
    throw new InvalidOperationException("CymBuildOutlookAPI:ApiBaseUrl is missing from appsettings.json");

//// Handler that configures once (prevents "Handler already configured")
//builder.Services.AddScoped<ApiAuthorizationMessageHandler>();

// 1) API client: MSAL token + correlation + logging
builder.Services.AddHttpClient("CymBuild_Outlook_API", client =>
{
    client.BaseAddress = new Uri(apiBaseUrl);
})
//.AddHttpMessageHandler<ApiAuthorizationMessageHandler>()          // attaches API access token automatically
.AddHttpMessageHandler<CorrelationIdDelegatingHandler>()         // adds X-Correlation-Id
.AddHttpMessageHandler<HttpLoggingDelegatingHandler>();          // logs req/res + timing

// 2) Graph client: NO MSAL handler (Office SSO token attached manually per call)
// Still add correlation + logging so we can see failures clearly.
builder.Services.AddHttpClient("Graph", client =>
{
    client.BaseAddress = new Uri("https://graph.microsoft.com/v1.0/");
})
.AddHttpMessageHandler<CorrelationIdDelegatingHandler>()
.AddHttpMessageHandler<HttpLoggingDelegatingHandler>();

// Your extension (kept as-is)
builder.Services.AddHttpClients(apiBaseUrl);

// GraphService DI
builder.Services.AddScoped<GraphService>();

// Telerik
builder.Services.AddTelerikBlazor();

await builder.Build().RunAsync();
