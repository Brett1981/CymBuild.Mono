using Sage200Microservice.API.Models;
using System.Net;
using System.Text.Json;

namespace Sage200Microservice.API.Middleware
{
    /// <summary>
    /// Middleware for handling exceptions globally
    /// </summary>
    public class GlobalExceptionHandlerMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<GlobalExceptionHandlerMiddleware> _logger;

        /// <summary>
        /// Initializes a new instance of the GlobalExceptionHandlerMiddleware
        /// </summary>
        /// <param name="next">   The next middleware in the pipeline </param>
        /// <param name="logger"> The logger </param>
        public GlobalExceptionHandlerMiddleware(RequestDelegate next, ILogger<GlobalExceptionHandlerMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        /// <summary>
        /// Invokes the middleware
        /// </summary>
        /// <param name="context"> The HTTP context </param>
        public async Task InvokeAsync(HttpContext context)
        {
            try
            {
                // Add correlation ID to the context
                if (!context.Items.ContainsKey("CorrelationId"))
                {
                    context.Items["CorrelationId"] = Guid.NewGuid().ToString();
                }

                // Add correlation ID to the response headers
                context.Response.Headers.Append("X-Correlation-ID", context.Items["CorrelationId"].ToString());

                // Call the next middleware in the pipeline
                await _next(context);
            }
            catch (Exception ex)
            {
                await HandleExceptionAsync(context, ex);
            }
        }

        /// <summary>
        /// Handles exceptions
        /// </summary>
        /// <param name="context">   The HTTP context </param>
        /// <param name="exception"> The exception </param>
        private async Task HandleExceptionAsync(HttpContext context, Exception exception)
        {
            var correlationId = context.Items.ContainsKey("CorrelationId")
                ? context.Items["CorrelationId"].ToString()
                : Guid.NewGuid().ToString();

            // Log the exception with correlation ID
            using (_logger.BeginScope(new
            {
                CorrelationId = correlationId,
                RequestPath = context.Request.Path,
                RequestMethod = context.Request.Method
            }))
            {
                _logger.LogError(exception, "An unhandled exception occurred");
            }

            // Set the response status code and content type
            context.Response.StatusCode = GetStatusCode(exception);
            context.Response.ContentType = "application/json";

            // Create the error response
            var errorResponse = new ErrorResponse
            {
                StatusCode = context.Response.StatusCode,
                Message = GetErrorMessage(exception),
                CorrelationId = correlationId
            };

            // Serialize the error response to JSON
            var json = JsonSerializer.Serialize(errorResponse, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            });

            // Write the error response to the response body
            await context.Response.WriteAsync(json);
        }

        /// <summary>
        /// Gets the appropriate status code for an exception
        /// </summary>
        /// <param name="exception"> The exception </param>
        /// <returns> The HTTP status code </returns>
        private int GetStatusCode(Exception exception)
        {
            return exception switch
            {
                ArgumentException => (int)HttpStatusCode.BadRequest,
                UnauthorizedAccessException => (int)HttpStatusCode.Unauthorized,
                KeyNotFoundException => (int)HttpStatusCode.NotFound,
                ValidationException => (int)HttpStatusCode.BadRequest,
                ResourceNotFoundException => (int)HttpStatusCode.NotFound,
                _ => (int)HttpStatusCode.InternalServerError
            };
        }

        /// <summary>
        /// Gets the error message for an exception
        /// </summary>
        /// <param name="exception"> The exception </param>
        /// <returns> The error message </returns>
        private string GetErrorMessage(Exception exception)
        {
            return exception switch
            {
                ValidationException validationException => validationException.Message,
                ResourceNotFoundException notFoundException => notFoundException.Message,
                _ => "An unexpected error occurred. Please try again later."
            };
        }
    }
}