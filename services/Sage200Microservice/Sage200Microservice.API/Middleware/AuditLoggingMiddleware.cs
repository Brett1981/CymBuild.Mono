using Microsoft.Extensions.Options;
using Sage200Microservice.Services.Interfaces;
using Sage200Microservice.Services.Models;
using System.Diagnostics;
using System.Text;

namespace Sage200Microservice.API.Middleware
{
    /// <summary>
    /// Middleware for audit logging of HTTP requests
    /// </summary>
    public class AuditLoggingMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<AuditLoggingMiddleware> _logger;
        private readonly AuditLogSettings _settings;

        /// <summary>
        /// Initializes a new instance of the AuditLoggingMiddleware class
        /// </summary>
        /// <param name="next">    The next middleware in the pipeline </param>
        /// <param name="logger">  The logger </param>
        /// <param name="options"> The audit log settings </param>
        public AuditLoggingMiddleware(
            RequestDelegate next,
            ILogger<AuditLoggingMiddleware> logger,
            IOptions<AuditLogSettings> options)
        {
            _next = next;
            _logger = logger;
            _settings = options.Value;
        }

        /// <summary>
        /// Invokes the middleware
        /// </summary>
        /// <param name="context">         The HTTP context </param>
        /// <param name="auditLogService"> The audit log service </param>
        /// <returns> A task representing the asynchronous operation </returns>
        public async Task InvokeAsync(HttpContext context, IAuditLogService auditLogService)
        {
            // Skip if audit logging is disabled or HTTP request logging is disabled
            if (!_settings.Enabled || !_settings.LogHttpRequests)
            {
                await _next(context);
                return;
            }

            // Skip for excluded endpoints
            var endpoint = context.Request.Path.Value;
            foreach (var excludedEndpoint in _settings.ExcludedEndpoints)
            {
                if (endpoint.StartsWith(excludedEndpoint, StringComparison.OrdinalIgnoreCase))
                {
                    await _next(context);
                    return;
                }
            }

            // Skip for non-sensitive endpoints if configured to log only sensitive endpoints
            if (_settings.LogOnlySensitiveEndpoints)
            {
                bool isSensitive = false;
                foreach (var sensitiveEndpoint in _settings.SensitiveEndpoints)
                {
                    if (endpoint.StartsWith(sensitiveEndpoint, StringComparison.OrdinalIgnoreCase))
                    {
                        isSensitive = true;
                        break;
                    }
                }

                if (!isSensitive)
                {
                    await _next(context);
                    return;
                }
            }

            // Start the stopwatch to measure request duration
            var stopwatch = Stopwatch.StartNew();

            // Get request details
            var httpMethod = context.Request.Method;
            var urlPath = context.Request.Path.Value;
            var userAgent = context.Request.Headers["User-Agent"].ToString();
            var ipAddress = context.Connection.RemoteIpAddress?.ToString();
            var correlationId = context.Request.Headers["X-Correlation-ID"].ToString();
            if (string.IsNullOrEmpty(correlationId))
            {
                correlationId = Guid.NewGuid().ToString();
                context.Request.Headers["X-Correlation-ID"] = correlationId;
            }

            // Get user ID and client ID from claims or headers
            string userId = null;
            string clientId = null;

            if (context.User?.Identity?.IsAuthenticated == true)
            {
                userId = context.User.Identity.Name;
            }

            if (context.Request.Headers.TryGetValue("X-Api-Key", out var apiKey))
            {
                clientId = apiKey.ToString();
            }

            // Enable request body buffering for reading
            context.Request.EnableBuffering();

            // Read the request body
            string requestBody = null;
            if (context.Request.ContentLength > 0 && context.Request.ContentLength <= _settings.MaxDetailsSize)
            {
                try
                {
                    // Save the current position
                    var position = context.Request.Body.Position;

                    // Read the request body
                    using (var reader = new StreamReader(
                        context.Request.Body,
                        encoding: Encoding.UTF8,
                        detectEncodingFromByteOrderMarks: false,
                        leaveOpen: true))
                    {
                        requestBody = await reader.ReadToEndAsync();
                    }

                    // Reset the position
                    context.Request.Body.Position = position;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error reading request body for audit logging");
                }
            }

            // Replace the response body with a memory stream to capture the response
            var originalResponseBody = context.Response.Body;
            using var responseBodyStream = new MemoryStream();
            context.Response.Body = responseBodyStream;

            try
            {
                // Call the next middleware in the pipeline
                await _next(context);

                // Stop the stopwatch
                stopwatch.Stop();

                // Get response details
                var statusCode = context.Response.StatusCode;
                var durationMs = stopwatch.ElapsedMilliseconds;

                // Read the response body
                string responseBody = null;
                if (responseBodyStream.Length > 0 && responseBodyStream.Length <= _settings.MaxDetailsSize)
                {
                    try
                    {
                        responseBodyStream.Position = 0;
                        using (var reader = new StreamReader(
                            responseBodyStream,
                            encoding: Encoding.UTF8,
                            detectEncodingFromByteOrderMarks: false,
                            leaveOpen: true))
                        {
                            responseBody = await reader.ReadToEndAsync();
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Error reading response body for audit logging");
                    }
                }

                // Copy the response body to the original stream
                responseBodyStream.Position = 0;
                await responseBodyStream.CopyToAsync(originalResponseBody);

                // Create a description for the audit log
                var description = $"{httpMethod} {urlPath} - {statusCode}";

                // Create details for the audit log
                var details = new
                {
                    Request = new
                    {
                        Headers = MaskSensitiveHeaders(context.Request.Headers),
                        Body = MaskSensitiveData(requestBody)
                    },
                    Response = new
                    {
                        Headers = context.Response.Headers,
                        Body = MaskSensitiveData(responseBody)
                    }
                };

                // Log the HTTP request
                await auditLogService.LogHttpRequestAsync(
                    userId,
                    clientId,
                    ipAddress,
                    httpMethod,
                    urlPath,
                    statusCode,
                    durationMs,
                    userAgent,
                    description,
                    details,
                    correlationId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in audit logging middleware");

                // Ensure the response body is copied to the original stream
                responseBodyStream.Position = 0;
                await responseBodyStream.CopyToAsync(originalResponseBody);

                // Re-throw the exception to be handled by the global exception handler
                throw;
            }
            finally
            {
                // Restore the original response body
                context.Response.Body = originalResponseBody;
            }
        }

        /// <summary>
        /// Masks sensitive data in headers
        /// </summary>
        /// <param name="headers"> The headers </param>
        /// <returns> The masked headers </returns>
        private object MaskSensitiveHeaders(IHeaderDictionary headers)
        {
            if (!_settings.MaskSensitiveData)
            {
                return headers;
            }

            var maskedHeaders = new System.Collections.Generic.Dictionary<string, string>();

            foreach (var header in headers)
            {
                var key = header.Key;
                var value = header.Value.ToString();

                // Check if the header contains sensitive information
                bool isSensitive = false;
                foreach (var sensitiveField in _settings.SensitiveFields)
                {
                    if (key.Contains(sensitiveField, StringComparison.OrdinalIgnoreCase))
                    {
                        isSensitive = true;
                        break;
                    }
                }

                // Mask sensitive headers
                if (isSensitive)
                {
                    maskedHeaders[key] = "********";
                }
                else
                {
                    maskedHeaders[key] = value;
                }
            }

            return maskedHeaders;
        }

        /// <summary>
        /// Masks sensitive data in a string
        /// </summary>
        /// <param name="data"> The data </param>
        /// <returns> The masked data </returns>
        private string MaskSensitiveData(string data)
        {
            if (string.IsNullOrEmpty(data) || !_settings.MaskSensitiveData)
            {
                return data;
            }

            var maskedData = data;

            // Simple approach: replace sensitive fields with asterisks
            foreach (var sensitiveField in _settings.SensitiveFields)
            {
                // Look for JSON patterns like "password": "secret"
                var pattern = $"&quot;{sensitiveField}&quot;\\s*:\\s*&quot;([^&quot;]*)&quot;";
                maskedData = System.Text.RegularExpressions.Regex.Replace(
                    maskedData,
                    pattern,
                    $"&quot;{sensitiveField}&quot;: &quot;********&quot;",
                    System.Text.RegularExpressions.RegexOptions.IgnoreCase);

                // Look for form data patterns like password=secret
                pattern = $"{sensitiveField}=([^&]*)";
                maskedData = System.Text.RegularExpressions.Regex.Replace(
                    maskedData,
                    pattern,
                    $"{sensitiveField}=********",
                    System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            }

            return maskedData;
        }
    }

    /// <summary>
    /// Extension methods for the AuditLoggingMiddleware
    /// </summary>
    public static class AuditLoggingMiddlewareExtensions
    {
        /// <summary>
        /// Adds the audit logging middleware to the application pipeline
        /// </summary>
        /// <param name="app"> The application builder </param>
        /// <returns> The application builder </returns>
        public static IApplicationBuilder UseAuditLogging(this IApplicationBuilder app)
        {
            return app.UseMiddleware<AuditLoggingMiddleware>();
        }
    }
}