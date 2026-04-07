using Sage200Microservice.Data.Repositories;

namespace Sage200Microservice.API.Middleware
{
    /// <summary>
    /// Middleware for API key authentication
    /// </summary>
    public class ApiKeyAuthenticationMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<ApiKeyAuthenticationMiddleware> _logger;
        private const string ApiKeyHeaderName = "X-Api-Key";

        public ApiKeyAuthenticationMiddleware(RequestDelegate next, ILogger<ApiKeyAuthenticationMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context, IApiKeyRepository apiKeyRepository)
        {
            // Skip authentication for Swagger and health check endpoints
            if (IsSwaggerRequest(context) || IsHealthCheckRequest(context))
            {
                await _next(context);
                return;
            }

            // Check if API key is provided
            if (!context.Request.Headers.TryGetValue(ApiKeyHeaderName, out var extractedApiKey))
            {
                _logger.LogWarning("API key was not provided. Request from {IpAddress}", context.Connection.RemoteIpAddress);
                context.Response.StatusCode = 401; // Unauthorized
                await context.Response.WriteAsJsonAsync(new { message = "API key is missing" });
                return;
            }

            var apiKey = extractedApiKey.ToString();

            // Validate API key
            if (!await apiKeyRepository.IsValidKeyAsync(apiKey))
            {
                _logger.LogWarning("Invalid API key provided: {ApiKey}. Request from {IpAddress}",
                    apiKey, context.Connection.RemoteIpAddress);
                context.Response.StatusCode = 401; // Unauthorized
                await context.Response.WriteAsJsonAsync(new { message = "Invalid API key" });
                return;
            }

            // Update last used timestamp
            await apiKeyRepository.UpdateLastUsedAsync(apiKey);

            // Add client name to the request context for logging
            var apiKeyEntity = await apiKeyRepository.GetByKeyAsync(apiKey);
            context.Items["ClientName"] = apiKeyEntity.ClientName;

            // Continue processing the request
            await _next(context);
        }

        private bool IsSwaggerRequest(HttpContext context)
        {
            return context.Request.Path.StartsWithSegments("/swagger") ||
                   context.Request.Path.StartsWithSegments("/index.html") ||
                   context.Request.Path.StartsWithSegments("/openapi");
        }

        private bool IsHealthCheckRequest(HttpContext context)
        {
            return context.Request.Path.StartsWithSegments("/health") ||
                   context.Request.Path.StartsWithSegments("/api/health");
        }
    }
}