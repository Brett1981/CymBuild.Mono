// ==============================
// FILE: CymBuild_Outlook_API/Program.cs
// ==============================
using Concursus.EF;
using CymBuild_Outlook_API.Data;
using CymBuild_Outlook_API.Services;
using CymBuild_Outlook_Common.Helpers;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.SqlServer;
using Microsoft.Extensions.Primitives;
using Microsoft.Identity.Web;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using Serilog;
using Serilog.Context;

var builder = WebApplication.CreateBuilder(args);
JwtSecurityTokenHandler.DefaultMapInboundClaims = false;

// -----------------------------------------------------------------------------
// Serilog
// -----------------------------------------------------------------------------
builder.Host.UseSerilog((ctx, services, lc) =>
{
    lc.ReadFrom.Configuration(ctx.Configuration)
      .ReadFrom.Services(services)
      .Enrich.FromLogContext()
      .Enrich.WithProperty("Application", "CymBuild_Outlook_API");
});

// -----------------------------------------------------------------------------
// IdentityModel PII (debug only; ensure false in prod)
// -----------------------------------------------------------------------------
var showPii = builder.Configuration.GetValue<bool>("IdentityModel:ShowPII");
Microsoft.IdentityModel.Logging.IdentityModelEventSource.ShowPII = showPii;

// -----------------------------------------------------------------------------
// EF
// -----------------------------------------------------------------------------
var defaultConn = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("DefaultConnection missing");

builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseSqlServer(defaultConn)
     .EnableSensitiveDataLogging(builder.Environment.IsDevelopment()));

builder.Services.AddDbContext<DataProtectionKeyContext>(o =>
    o.UseSqlServer(defaultConn));

builder.Services.AddDataProtection()
    .PersistKeysToDbContext<DataProtectionKeyContext>()
    .ProtectKeysWithDpapi(); // Windows/IIS OK. If you ever host on Linux, this must change.

// -----------------------------------------------------------------------------
// HttpContext
// -----------------------------------------------------------------------------
builder.Services.AddHttpContextAccessor();

// -----------------------------------------------------------------------------
// LoggingHelper
// -----------------------------------------------------------------------------
builder.Services.AddSingleton<LoggingHelper>(sp =>
{
    var logger = sp.GetRequiredService<ILogger<LoggingHelper>>();
    var showInfo = builder.Configuration.GetValue<bool>("Logging:Settings:ShowInformationLogs");
    return new LoggingHelper(logger, showInfo);
});

// -----------------------------------------------------------------------------
// Auth config (AzureAd)
// -----------------------------------------------------------------------------
var azureAd = builder.Configuration.GetSection("AzureAd");
var clientId = azureAd["ClientId"] ?? throw new InvalidOperationException("AzureAd:ClientId missing");
var tenantId = azureAd["TenantId"] ?? throw new InvalidOperationException("AzureAd:TenantId missing");

// Audience variants (handles api://{clientId} AND api://host:port/{clientId})
var apiAudienceSimple = $"api://{clientId}";
var apiHost = builder.Configuration["ApiSettings:Host"]
          ?? builder.Configuration["AzureAd:AppIdUriHost"]
          ?? "bre.socotec.co.uk:9603";

var apiAudienceHostPort = $"api://{apiHost}/{clientId}";
var apiAudienceFromConfig = builder.Configuration["AzureAd:Audience"]; // optional explicit override

var validAudiences = new[]
{
    apiAudienceSimple,
    clientId,
    apiAudienceHostPort,
    apiAudienceFromConfig,
    $"api://bre.socotec.co.uk:9603/{clientId}",
    $"api://bre.socotec.co.uk:9604/{clientId}",
}
.Where(x => !string.IsNullOrWhiteSpace(x))
.Distinct(StringComparer.OrdinalIgnoreCase)
.ToArray();

// Issuers (v1 + v2)
var issuerV1 = $"https://sts.windows.net/{tenantId}/";
var issuerV2 = $"https://login.microsoftonline.com/{tenantId}/v2.0";
var issuerV2Alt = $"https://login.microsoftonline.com/{tenantId}/";

// -----------------------------------------------------------------------------
// Distributed cache (REQUIRED for stable OBO Graph token acquisition)
// -----------------------------------------------------------------------------
builder.Services.AddDistributedSqlServerCache(options =>
{
    options.ConnectionString = defaultConn;
    options.SchemaName = "SOffice";
    options.TableName = "OutlookMsalTokenCache";
});

// -----------------------------------------------------------------------------
// Authentication + MIW token acquisition (OBO)
// -----------------------------------------------------------------------------
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(azureAd)
    .EnableTokenAcquisitionToCallDownstreamApi()
    .AddDistributedTokenCaches(); // CRITICAL: replaces AddInMemoryTokenCaches()

// -----------------------------------------------------------------------------
// Configure JwtBearerOptions (events/logging/validation)
// IMPORTANT FIX:
// DO NOT overwrite o.Events (that removes MIW's internal handlers needed for OBO bootstrap token).
// Instead: chain onto existing events.
// -----------------------------------------------------------------------------
builder.Services.Configure<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme, o =>
{
    // Keep the incoming access token accessible (fine to keep)
    o.SaveToken = true;

    o.TokenValidationParameters ??= new TokenValidationParameters();
    o.TokenValidationParameters.ValidAudiences = validAudiences;
    o.TokenValidationParameters.NameClaimType = "upn";

    o.TokenValidationParameters.ValidateIssuer = true;
    o.TokenValidationParameters.ValidIssuers = new[] { issuerV1, issuerV2, issuerV2Alt };

    o.RequireHttpsMetadata = !builder.Environment.IsDevelopment();

    // Preserve existing MIW handlers and chain ours on top
    o.Events ??= new JwtBearerEvents();

    var miwOnMessageReceived = o.Events.OnMessageReceived;
    var miwOnTokenValidated = o.Events.OnTokenValidated;
    var miwOnAuthenticationFailed = o.Events.OnAuthenticationFailed;
    var miwOnChallenge = o.Events.OnChallenge;
    var miwOnForbidden = o.Events.OnForbidden;

    o.Events.OnMessageReceived = async ctx =>
    {
        if (miwOnMessageReceived != null)
            await miwOnMessageReceived(ctx);

        var corr = Correlation.GetOrCreateCorrelationId(ctx.HttpContext);
        using (LogContext.PushProperty("CorrelationId", corr))
        using (LogContext.PushProperty("TraceId", ctx.HttpContext.TraceIdentifier))
        {
            var hasAuth = ctx.Request.Headers.TryGetValue("Authorization", out var auth)
                          && !StringValues.IsNullOrEmpty(auth);

            var origin = ctx.Request.Headers.Origin.ToString();
            Log.Information("AUTH OnMessageReceived hasAuthHeader={HasAuth} method={Method} path={Path} origin={Origin}",
                hasAuth, ctx.Request.Method, ctx.Request.Path.Value, origin);
        }
    };

    o.Events.OnTokenValidated = async ctx =>
    {
        // CRITICAL: let MIW run first (bootstrap token capture for OBO)
        if (miwOnTokenValidated != null)
            await miwOnTokenValidated(ctx);

        var corr = Correlation.GetOrCreateCorrelationId(ctx.HttpContext);

        using (LogContext.PushProperty("CorrelationId", corr))
        using (LogContext.PushProperty("TraceId", ctx.HttpContext.TraceIdentifier))
        {
            var principal = ctx.Principal;
            var identity = principal?.Identity as System.Security.Claims.ClaimsIdentity;

            if (principal == null || identity == null)
            {
                Log.Warning("AUTH OnTokenValidated principal/identity null. corr={CorrelationId}", corr);
                return;
            }

            static string? FirstClaimValue(System.Security.Claims.ClaimsPrincipal p, params string[] types)
            {
                foreach (var t in types)
                {
                    var v = p.FindFirst(t)?.Value;
                    if (!string.IsNullOrWhiteSpace(v))
                        return v;
                }
                return null;
            }

            // Common claim type variants
            var oid =
                FirstClaimValue(principal,
                    "oid",
                    "http://schemas.microsoft.com/identity/claims/objectidentifier",
                    "ObjectId");

            var tid =
                FirstClaimValue(principal,
                    "tid",
                    "http://schemas.microsoft.com/identity/claims/tenantid",
                    "TenantId");

            var sub = FirstClaimValue(principal, "sub");

            // Add normalized claims only if missing AND we have a real source value
            if (string.IsNullOrWhiteSpace(principal.FindFirst("oid")?.Value) && !string.IsNullOrWhiteSpace(oid))
                identity.AddClaim(new System.Security.Claims.Claim("oid", oid));

            if (string.IsNullOrWhiteSpace(principal.FindFirst("tid")?.Value) && !string.IsNullOrWhiteSpace(tid))
                identity.AddClaim(new System.Security.Claims.Claim("tid", tid));

            var scp1 = FirstClaimValue(principal, "scp") ?? "";
            var scp2 = FirstClaimValue(principal, "http://schemas.microsoft.com/identity/claims/scope") ?? "";

            var aud = FirstClaimValue(principal, "aud") ?? "";
            var iss = FirstClaimValue(principal, "iss") ?? "";
            var ver = FirstClaimValue(principal, "ver") ?? "";

            var upn =
                FirstClaimValue(principal,
                    "preferred_username",
                    "upn",
                    "email",
                    System.Security.Claims.ClaimTypes.Upn,
                    System.Security.Claims.ClaimTypes.Email) ?? "";

            Log.Information(
                "AUTH OnTokenValidated name={Name} upn={Upn} oid={Oid} tid={Tid} sub={Sub} aud={Aud} iss={Iss} ver={Ver} scp={Scp} scopeClaim={ScopeClaim}",
                principal.Identity?.Name ?? "",
                upn,
                oid ?? "",
                tid ?? "",
                sub ?? "",
                aud,
                iss,
                ver,
                scp1,
                scp2);

            if (string.IsNullOrWhiteSpace(oid))
            {
                var claimTypes = principal.Claims
                    .Select(c => c.Type)
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .OrderBy(x => x)
                    .ToArray();

                var altObjectIdCandidates = new[]
                {
                    ("nameid", FirstClaimValue(principal, "nameid", "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier")),
                    ("puid", FirstClaimValue(principal, "puid")),
                    ("appid", FirstClaimValue(principal, "appid")),
                    ("azp", FirstClaimValue(principal, "azp")),
                    ("roles", string.Join(",", principal.FindAll("roles").Select(x => x.Value))),
                };

                Log.Warning(
                    "AUTH Claims present but oid missing. ClaimTypes={ClaimTypes}. Candidates={Candidates}",
                    string.Join(" | ", claimTypes),
                    string.Join(" | ", altObjectIdCandidates.Select(x => $"{x.Item1}={(string.IsNullOrWhiteSpace(x.Item2) ? "(empty)" : x.Item2)}")));
            }
        }
    };

    o.Events.OnAuthenticationFailed = async ctx =>
    {
        if (miwOnAuthenticationFailed != null)
            await miwOnAuthenticationFailed(ctx);

        var corr = Correlation.GetOrCreateCorrelationId(ctx.HttpContext);
        using (LogContext.PushProperty("CorrelationId", corr))
        using (LogContext.PushProperty("TraceId", ctx.HttpContext.TraceIdentifier))
        {
            Log.Error(ctx.Exception, "AUTH OnAuthenticationFailed path={Path}", ctx.HttpContext.Request.Path.Value);
        }
    };

    o.Events.OnChallenge = async ctx =>
    {
        if (miwOnChallenge != null)
            await miwOnChallenge(ctx);

        var corr = Correlation.GetOrCreateCorrelationId(ctx.HttpContext);
        using (LogContext.PushProperty("CorrelationId", corr))
        using (LogContext.PushProperty("TraceId", ctx.HttpContext.TraceIdentifier))
        {
            Log.Warning("AUTH OnChallenge path={Path} error={Error} desc={Desc}",
                ctx.HttpContext.Request.Path.Value, ctx.Error, ctx.ErrorDescription);
        }
    };

    o.Events.OnForbidden = async ctx =>
    {
        if (miwOnForbidden != null)
            await miwOnForbidden(ctx);

        var corr = Correlation.GetOrCreateCorrelationId(ctx.HttpContext);
        using (LogContext.PushProperty("CorrelationId", corr))
        using (LogContext.PushProperty("TraceId", ctx.HttpContext.TraceIdentifier))
        {
            Log.Warning("AUTH OnForbidden path={Path}", ctx.HttpContext.Request.Path.Value);
        }
    };
});

builder.Services.AddAuthorization(o =>
{
    o.AddPolicy("AccessAsUserPolicy", p =>
        p.RequireAuthenticatedUser()
         .RequireAssertion(ctx =>
             ctx.User.HasClaim("scp", "access_as_user") ||
             ctx.User.HasClaim("http://schemas.microsoft.com/identity/claims/scope", "access_as_user")
         ));
});

// -----------------------------------------------------------------------------
// Concursus Core
// -----------------------------------------------------------------------------
builder.Services.AddScoped<Core>(sp =>
{
    var cfg = sp.GetRequiredService<IConfiguration>();
    var http = sp.GetRequiredService<IHttpContextAccessor>();

    var cs = cfg.GetConnectionString("DefaultConnection")
        ?? throw new InvalidOperationException("DefaultConnection missing");

    return new Core(cs, http.HttpContext?.User);
});

// -----------------------------------------------------------------------------
// Graph / App Services
// -----------------------------------------------------------------------------
builder.Services.AddScoped<IMSGraphBase, MSGraphBase>();

builder.Services.AddScoped<CoreServices_API>(sp =>
{
    return new CoreServices_API(
        sp.GetRequiredService<AppDbContext>(),
        sp.GetRequiredService<IConfiguration>(),
        sp.GetRequiredService<Core>(),
        sp.GetRequiredService<IMSGraphBase>(),
        sp.GetRequiredService<LoggingHelper>());
});

builder.Services.AddScoped<SharePointHelper>();

builder.Services.AddHttpClient<BlueGenService>();
builder.Services.AddScoped<BlueGenService>();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// -----------------------------------------------------------------------------
// CORS
// -----------------------------------------------------------------------------
var corsRaw = builder.Configuration["CorsOrigins"]
           ?? builder.Configuration["CorsOrigin"]
           ?? "";

var allowedOrigins = corsRaw
    .Split(new[] { ' ', ',', ';' }, StringSplitOptions.RemoveEmptyEntries)
    .Select(o => o.Trim().TrimEnd('/'))
    .Where(o => !string.IsNullOrWhiteSpace(o))
    .Distinct(StringComparer.OrdinalIgnoreCase)
    .ToArray();

if (allowedOrigins.Length == 0)
{
    throw new InvalidOperationException("CORS misconfigured: CorsOrigins/CorsOrigin is empty.");
}

builder.Services.AddCors(o =>
{
    o.AddPolicy("AddinCors", p =>
    {
        p.WithOrigins(allowedOrigins)
         .AllowAnyHeader()
         .AllowAnyMethod()
         .AllowCredentials();
    });
});

// -----------------------------------------------------------------------------
// BUILD
// -----------------------------------------------------------------------------
var app = builder.Build();

// Startup diagnostics
Log.Information("STARTUP Env={Env} ShowPII={ShowPII}", app.Environment.EnvironmentName, showPii);
Log.Information("STARTUP ValidAudiencesCount={Count} ValidAudiences={Audiences}",
    validAudiences.Length, string.Join(" | ", validAudiences));
Log.Information("STARTUP ValidIssuers={Issuers}", string.Join(" | ", new[] { issuerV1, issuerV2, issuerV2Alt }));
Log.Information("STARTUP CORS AllowedOrigins={Origins}", string.Join(" | ", allowedOrigins));

// -----------------------------------------------------------------------------
// Correlation ID (EARLY)
// -----------------------------------------------------------------------------
app.Use(async (ctx, next) =>
{
    var corr = Correlation.GetOrCreateCorrelationId(ctx);

    ctx.Response.OnStarting(() =>
    {
        ctx.Response.Headers["X-Correlation-Id"] = corr;
        return Task.CompletedTask;
    });

    using (LogContext.PushProperty("CorrelationId", corr))
    using (LogContext.PushProperty("TraceId", ctx.TraceIdentifier))
    {
        await next();
    }
});

// -----------------------------------------------------------------------------
// Exception handler (ensures CORS headers on 500s too)
// -----------------------------------------------------------------------------
app.UseExceptionHandler(e =>
{
    e.Run(async ctx =>
    {
        var corr = Correlation.GetOrCreateCorrelationId(ctx);
        var ex = ctx.Features.Get<IExceptionHandlerFeature>()?.Error;

        Log.Error(ex, "UNHANDLED method={Method} path={Path}", ctx.Request.Method, ctx.Request.Path);

        var pd = new ProblemDetails
        {
            Title = "Unhandled server error",
            Status = 500,
            Instance = ctx.Request.Path
        };
        pd.Extensions["correlationId"] = corr;

        var origin = ctx.Request.Headers.Origin.ToString();
        if (!string.IsNullOrWhiteSpace(origin) &&
            allowedOrigins.Contains(origin.TrimEnd('/'), StringComparer.OrdinalIgnoreCase))
        {
            ctx.Response.Headers["Access-Control-Allow-Origin"] = origin;
            ctx.Response.Headers["Access-Control-Allow-Credentials"] = "true";
            ctx.Response.Headers["Vary"] = "Origin";
        }

        ctx.Response.StatusCode = 500;
        ctx.Response.ContentType = "application/problem+json";
        await ctx.Response.WriteAsJsonAsync(pd);
    });
});

// -----------------------------------------------------------------------------
// Request logging
// -----------------------------------------------------------------------------
app.UseSerilogRequestLogging();

// -----------------------------------------------------------------------------
// PIPELINE ORDER (IMPORTANT)
// -----------------------------------------------------------------------------
app.UseRouting();

app.UseCors("AddinCors");

// Preflight safety: always respond to OPTIONS with CORS headers
app.MapMethods("{*path}", new[] { "OPTIONS" }, () => Results.NoContent())
   .RequireCors("AddinCors");

app.UseSwagger();
app.UseSwaggerUI();

app.UseHttpsRedirection();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers().RequireCors("AddinCors");

app.Run();

// -----------------------------------------------------------------------------
// Correlation helper
// -----------------------------------------------------------------------------
static class Correlation
{
    private const string Header = "X-Correlation-Id";
    private const string ItemKey = "__corrId";

    public static string GetOrCreateCorrelationId(HttpContext ctx)
    {
        if (ctx.Items.TryGetValue(ItemKey, out var v) && v is string s && !string.IsNullOrWhiteSpace(s))
            return s;

        if (ctx.Request.Headers.TryGetValue(Header, out var h) && !StringValues.IsNullOrEmpty(h))
        {
            var hv = h.ToString();
            ctx.Items[ItemKey] = hv;
            return hv;
        }

        var corr = $"api-{Guid.NewGuid():N}".Substring(0, 28);
        ctx.Items[ItemKey] = corr;
        return corr;
    }
}
