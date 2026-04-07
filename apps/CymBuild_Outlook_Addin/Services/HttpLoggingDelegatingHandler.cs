// ==============================
// FILE: CymBuild_Outlook_Addin/Services/HttpLoggingDelegatingHandler.cs
// ==============================
using CymBuild_Outlook_Common.Helpers;
using System.Diagnostics;

namespace CymBuild_Outlook_Addin.Services
{
    /// <summary>
    /// Logs outgoing HTTP requests with timings and useful failure details.
    /// - Logs method, URL, status, elapsed ms
    /// - On non-success, logs a small response body snippet (helps with Graph/502/401/etc)
    /// </summary>
    public class HttpLoggingDelegatingHandler : DelegatingHandler
    {
        private readonly LoggingHelper _logging;

        public HttpLoggingDelegatingHandler(LoggingHelper logging)
        {
            _logging = logging;
        }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var sw = Stopwatch.StartNew();

            string url = request.RequestUri?.ToString() ?? "(null-uri)";
            string method = request.Method.Method;

            try
            {
                // Basic request log (avoid headers/body to prevent token leakage)
                _logging.LogInfo($"HTTP START -> {method} {url}", "HttpLoggingDelegatingHandler.SendAsync()");

                var response = await base.SendAsync(request, cancellationToken);

                sw.Stop();
                var statusCode = (int)response.StatusCode;

                if (response.IsSuccessStatusCode)
                {
                    _logging.LogInfo($"HTTP END   -> {method} {url} [{statusCode}] {sw.ElapsedMilliseconds}ms",
                        "HttpLoggingDelegatingHandler.SendAsync()");
                    return response;
                }

                // Non-success: capture small response body snippet (safe + super useful)
                string bodySnippet = string.Empty;
                try
                {
                    if (response.Content != null)
                    {
                        var body = await response.Content.ReadAsStringAsync(cancellationToken);
                        if (!string.IsNullOrWhiteSpace(body))
                        {
                            bodySnippet = body.Length <= 2000 ? body : body.Substring(0, 2000) + "…(truncated)";
                        }
                    }
                }
                catch (Exception exRead)
                {
                    bodySnippet = $"(failed reading error body: {exRead.Message})";
                }

                _logging.LogError(
                    $"HTTP FAIL -> {method} {url} [{statusCode}] {sw.ElapsedMilliseconds}ms Body={bodySnippet}",
                    new Exception($"HTTP {(int)response.StatusCode} {response.ReasonPhrase}"),
                    "HttpLoggingDelegatingHandler.SendAsync()");

                return response;
            }
            catch (TaskCanceledException ex) when (!cancellationToken.IsCancellationRequested)
            {
                sw.Stop();
                _logging.LogError(
                    $"HTTP TIMEOUT -> {method} {url} after {sw.ElapsedMilliseconds}ms",
                    ex,
                    "HttpLoggingDelegatingHandler.SendAsync()");
                throw;
            }
            catch (Exception ex)
            {
                sw.Stop();
                _logging.LogError(
                    $"HTTP EXCEPTION -> {method} {url} after {sw.ElapsedMilliseconds}ms",
                    ex,
                    "HttpLoggingDelegatingHandler.SendAsync()");
                throw;
            }
        }
    }
}
