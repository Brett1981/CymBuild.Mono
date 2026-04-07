using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Identity.Web;
using PostCodeLookup.Data;
using PostCodeLookup.POCO;
using PostCodeLookup.Services;
using System.Net.Http.Headers;

var builder = WebApplication.CreateBuilder(args);
// explicitly bind to both HTTP and HTTPS
builder.WebHost
       .UseUrls("http://*:5041",    // your HTTP port
                "https://*:7102"); // your HTTPS port
// 1) Bind our two keys under one section in appsettings.json:
//
// "PostcodeLookup": { "OsPlaces": { "ApiKey": "YOUR_OS_KEY" }, "IdealPostcodes": { "ApiKey":
// "ak_test" } } this line hooks into the SCM start/stop lifecycle:
builder.Host.UseWindowsService();
builder.Services
  .Configure<PostcodeLookupOptions>(builder.Configuration.GetSection("PostcodeLookup"));

// 2) MSAL / JWT
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(opts =>
    {
        builder.Configuration.Bind("AzureAd", opts);
        opts.SaveToken = true;
        opts.TokenValidationParameters.NameClaimType = "preferred_username";
    }, opts => builder.Configuration.Bind("AzureAd", opts));

// 3) EF Core
builder.Services.AddDbContext<PostcodeLookupDbContext>(o =>
    o.UseSqlServer(
        builder.Configuration.GetConnectionString("PostcodeLookupDb"),
        sql => sql.EnableRetryOnFailure()
    ));

// 4) Named HTTP clients
builder.Services.AddHttpClient("OsPlacesClient", client =>
{
    client.BaseAddress = new Uri("https://api.os.uk/");
    client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
});

builder.Services.AddHttpClient("IdealPostcodesClient", client =>
{
    client.BaseAddress = new Uri("https://api.ideal-postcodes.co.uk/v1/");
    client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
});

// 5) Your two concrete lookup services + the composite
builder.Services.AddTransient<IdealPostcodeLookupService>();

// 6) MVC & Swagger
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddCors(o => o.AddPolicy("AllowAll", builder =>
{
    builder.AllowAnyOrigin()
        .AllowAnyMethod()
        .AllowAnyHeader();
}));

var app = builder.Build();

//Logging incoming requests for debugging.
app.Use(async (context, next) =>
{
    Console.WriteLine($"Incoming request: {context.Request.Method} {context.Request.Path}");
    await next.Invoke();
});

app.UseExceptionHandler(appError =>
{
    appError.Run(async context =>
    {
        var exceptionHandlerPathFeature = context.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerPathFeature>();
        var exception = exceptionHandlerPathFeature?.Error;
        if (exception != null)
        {
            File.AppendAllText("C:\\temp\\postcode-service-error.log",
                $"[{DateTime.Now}] Request error: {exception.ToString()}\n\n");
        }
        context.Response.StatusCode = 500;
        await context.Response.WriteAsync("An unexpected error occurred.");
    });
});
//if (app.Environment.IsDevelopment())
//{
app.UseSwagger();
app.UseSwaggerUI();
//}

//app.UseHttpsRedirection();

app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
try
{
    app.Run();
}
catch (Exception ex)
{
    File.WriteAllText("C:\\temp\\postcode-service-error.log", ex.ToString());
    throw;
}