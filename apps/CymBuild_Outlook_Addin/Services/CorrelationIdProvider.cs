// ==============================
// FILE: CymBuild_Outlook_Addin/Services/CorrelationIdProvider.cs
// ==============================
using System.Globalization;

namespace CymBuild_Outlook_Addin.Services
{
    /// <summary>
    /// Provides a stable correlation id for the current WASM "session".
    /// - Scoped lifetime: same id reused within a scoped DI lifetime (per tab/session).
    /// - If you want persistence across reloads, we can switch to localStorage via JS later.
    /// </summary>
    public class CorrelationIdProvider
    {
        private string? _correlationId;

        public string GetOrCreate()
        {
            if (!string.IsNullOrWhiteSpace(_correlationId))
                return _correlationId!;

            // short but unique enough for log filtering
            var utc = DateTime.UtcNow.ToString("HHmmssfff", CultureInfo.InvariantCulture);
            _correlationId = $"addin-{utc}-{Guid.NewGuid():N}".Substring(0, 28);
            return _correlationId!;
        }
    }
}
