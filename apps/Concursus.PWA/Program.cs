using Blazored.Modal;
using Concursus.API.Client.Models;
using Concursus.API.Client.Services;
using Concursus.Components.Shared.Services;
using Concursus.PWA;
using Concursus.PWA.Classes;
using Concursus.PWA.Helpers;
using Concursus.PWA.Services;
using CymBuild.API.Client.Services;
using Grpc.Net.Client.Web;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Authentication;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.JSInterop;
using System.Net.Http.Headers;
using System.Threading.Channels;

var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

builder.Services.Configure<ClientConfiguration>(
    builder.Configuration);
builder.Services.AddScoped(sp =>
{
    return new HttpClient()
    {
        BaseAddress = new Uri(builder.HostEnvironment.BaseAddress)
    };
});

// Register the Telerik services.
builder.Services.AddTelerikBlazor();
builder.Services.AddBlazoredModal();
builder.Services.AddSingleton<UserService>();
builder.Services.AddSingleton<StateService>();
builder.Services.AddSingleton<ModalService>();
builder.Services.AddSingleton<DeviceInfoService>();
builder.Services.AddSingleton(sp => new AppConfiguration(sp.GetRequiredService<IConfiguration>()));
builder.Services.AddSingleton<SyncQueueState>();
builder.Services.AddScoped<IToastService, TelerikToastService>();
builder.Services.AddScoped<RefreshService>();
builder.Services.AddScoped<IndexedDbHelper>();
builder.Services.AddScoped<GenericEntityService>();
builder.Services.AddScoped<IndexedDbService>();
builder.Services.AddScoped<MemoryOverlayService>();
builder.Services.AddScoped<AiErrorReporter>();
builder.Services.AddScoped<UserInteractionTrackerService>();
var env = builder.Configuration.GetValue<string>("Environment:Type");
builder.Services.AddScoped(sp =>
{
    var js = sp.GetRequiredService<IJSRuntime>();
    var userService = sp.GetRequiredService<UserService>();
    var env = sp.GetRequiredService<IConfiguration>()["Environment:Type"] ?? "DEV";

    // Use your SignalR helper to create and share a single HubConnection instance
    var hubConnection = new HubConnectionBuilder()
        .WithUrl($"{sp.GetRequiredService<IConfiguration>()["ShoreAPI:Url"]}/fileProcessingHub")
        .WithAutomaticReconnect()
        .Build();

    return new OfflineSyncService(js, hubConnection, userService, env);
});

builder.Logging.SetMinimumLevel(LogLevel.Debug);

//// Register the Channel for FileModel
var fileChannel = Channel.CreateUnbounded<FileModel>();
builder.Services.AddSingleton(fileChannel);
builder.Services.AddSingleton<FileProcessingService>();



// Register the gRPC client
builder.Services
    .AddGrpcClient<Concursus.API.Core.Core.CoreClient>(o =>
    {
        o.Address = new Uri(builder.Configuration["ShoreAPI:Url"]);
    })
    .ConfigurePrimaryHttpMessageHandler(() => new GrpcWebHandler(new HttpClientHandler()))
    .AddHttpMessageHandler(sp => sp.GetRequiredService<AuthorizationMessageHandler>()
        .ConfigureHandler(
            new[] { builder.Configuration["ShoreAPI:Url"] },
            new[] { builder.Configuration["ShoreAPI:BaseUrl"] + '/' + builder.Configuration["ShoreAPI:Scopes"] }
        ));

builder.Services.AddGrpcClient<Sage200Microservice.API.Protos.Invoice.InvoiceService.InvoiceServiceClient>(options =>
{
    options.Address = new Uri(builder.Configuration["Grpc:SageApi"]);
});
builder.Services.AddHttpClient("SageIntegrationAPI", client =>
{
    client.BaseAddress = new Uri(builder.Configuration["Grpc:SageApi"]);
});
// Register the gRPC client for TranslationService
builder.Services
    .AddGrpcClient<Concursus.API.TranslationService.TranslationServiceClient>(o =>
    {
        o.Address = new Uri(builder.Configuration["ShoreAPI:Url"]);
    })
    .ConfigurePrimaryHttpMessageHandler(() => new GrpcWebHandler(new HttpClientHandler()))
    .ConfigureChannel(options =>
    {
        options.MaxReceiveMessageSize = 16 * 1024 * 1024;
        options.MaxSendMessageSize = 16 * 1024 * 1024;
    })
    .AddHttpMessageHandler(sp => sp.GetRequiredService<AuthorizationMessageHandler>()
        .ConfigureHandler(
            new[] { builder.Configuration["ShoreAPI:Url"] },
            new[] { builder.Configuration["ShoreAPI:BaseUrl"] + "/" + builder.Configuration["ShoreAPI:Scopes"] }
        ));

builder.Services.AddScoped<TranslationServiceWrapper>();

builder.Services.AddMsalAuthentication(options =>
{
    builder.Configuration.Bind("AzureAd", options.ProviderOptions.Authentication);
    options.ProviderOptions.DefaultAccessTokenScopes.Add(builder.Configuration["ShoreAPI:BaseUrl"] + '/' + builder.Configuration["ShoreAPI:Scopes"]);
    options.ProviderOptions.LoginMode = "popup"; // or "redirect"
});

//// JSInterop for sending tokens to iframe
//builder.Services.AddScoped(async serviceProvider =>
//{
//    var authProvider = serviceProvider.GetRequiredService<IAccessTokenProvider>();
//    var result = await authProvider.RequestAccessToken();

//    string token = null;
//    if (result.TryGetToken(out var accessToken))
//    {
//        token = accessToken.Value;
//    }

//    var jsRuntime = serviceProvider.GetRequiredService<IJSRuntime>();
//    await jsRuntime.InvokeVoidAsync("sendTokenToIframe", token);
//});

//OE: CBLD-12 + CBLD-106: Using SessionStorage to keep track of last visited
builder.Services.AddScoped<SessionStorageAccessor>();
builder.Services.AddScoped<LocalStorageAccessor>();

builder.Services.AddHttpClient("ShoreApiHttp", client =>
{
    var apiUrl = builder.Configuration["ShoreAPI:Url"]
        ?? throw new InvalidOperationException("Missing ShoreAPI:Url");

    client.BaseAddress = new Uri(apiUrl);
    client.DefaultRequestHeaders.Accept.Add(
        new MediaTypeWithQualityHeaderValue("application/json"));
})
.AddHttpMessageHandler(sp =>
{
    // Reuse the same MSAL token flow you already use for gRPC
    var handler = sp.GetRequiredService<AuthorizationMessageHandler>();

    return handler.ConfigureHandler(
        authorizedUrls: new[] { builder.Configuration["ShoreAPI:Url"]! },
        scopes: new[] { builder.Configuration["ShoreAPI:BaseUrl"] + "/" + builder.Configuration["ShoreAPI:Scopes"] }
    );
});

var gridSettingsSection = builder.Configuration.GetSection("GridSettings");
builder.Services.Configure<GridSettings>(options => gridSettingsSection.Bind(options));

var host = builder.Build();

//// Set the Hub connection URL
var hubConnectionUrl = builder.Configuration["ShoreAPI:Url"];
var fileProcessingService = host.Services.GetRequiredService<FileProcessingService>();
fileProcessingService.SetHubConnectionUrl(hubConnectionUrl);

// Start the File Processing Service
try
{
    await fileProcessingService.StartProcessingAsync();
}
catch (Exception ex)
{
    Console.Error.WriteLine($"FileProcessingService startup failed: {ex}");
}
var js = host.Services.GetRequiredService<IJSRuntime>();
var config = host.Services.GetRequiredService<IConfiguration>();

string environment = config["Environment:Type"] ?? "DEV";

// Send environment type to Service Worker via JS interop
await js.InvokeVoidAsync("serviceWorkerInterop.sendEnvironmentType", environment);

await host.RunAsync();