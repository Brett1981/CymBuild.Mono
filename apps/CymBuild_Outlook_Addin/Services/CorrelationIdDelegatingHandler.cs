// ==============================
// FILE: CymBuild_Outlook_Addin/Services/CorrelationIdDelegatingHandler.cs
// ==============================
using CymBuild_Outlook_Common.Helpers;
using System.Net.Http.Headers;

namespace CymBuild_Outlook_Addin.Services
{
    /// <summary>
    /// Adds X-Correlation-Id to every outgoing request so API/Graph logs can be matched to UI logs.
    /// </summary>
    public class CorrelationIdDelegatingHandler : DelegatingHandler
    {
        private readonly CorrelationIdProvider _correlation;
        private readonly LoggingHelper _logging;

        public CorrelationIdDelegatingHandler(CorrelationIdProvider correlation, LoggingHelper logging)
        {
            _correlation = correlation;
            _logging = logging;
        }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var corr = _correlation.GetOrCreate();

            // Add header if not present
            if (!request.Headers.TryGetValues("X-Correlation-Id", out _))
                request.Headers.Add("X-Correlation-Id", corr);

            // Helpful client hint (optional)
            if (!request.Headers.TryGetValues("X-Client", out _))
                request.Headers.Add("X-Client", "CymBuild_Outlook_Addin");

            // Only log at info level if your config allows it.
            _logging.LogInfo($"HTTP OUT -> {request.Method} {request.RequestUri} (corr={corr})", "CorrelationIdDelegatingHandler.SendAsync()");

            return base.SendAsync(request, cancellationToken);
        }
    }
}
