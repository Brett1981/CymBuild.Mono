using Microsoft.Extensions.Logging;

public class LoggingHelper
{
    private readonly ILogger _logger;
    private readonly bool _showInformationLogs;

    public LoggingHelper(ILogger logger, bool showInformationLogs)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _showInformationLogs = showInformationLogs;
    }
    public static Dictionary<string, object?> DecodeJwtPayload(string jwt)
    {
        var parts = jwt.Split('.');
        if (parts.Length < 2) return new();

        string payload = parts[1]
            .Replace('-', '+')
            .Replace('_', '/');

        switch (payload.Length % 4)
        {
            case 2: payload += "=="; break;
            case 3: payload += "="; break;
        }

        var json = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(payload));
        return System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, object?>>(json)
               ?? new Dictionary<string, object?>();
    }

    public void LogInfo(string message, string? context = null)
    {
        if (_showInformationLogs)
        {
            var timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
            var formattedMessage = FormatMessage(message, context, timestamp);
            _logger.LogInformation(formattedMessage);
        }
    }

    public void LogWarning(string message, string? context = null)
    {
        if (_showInformationLogs)
        {
            var timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
            var formattedMessage = FormatMessage(message, context, timestamp);
            _logger.LogWarning(formattedMessage);
        }
    }

    public void LogError(string message, Exception? ex = null, string? context = null)
    {
        var timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
        var formattedMessage = FormatMessage(message, context, timestamp);

        if (ex != null)
        {
            _logger.LogError(ex, formattedMessage);
        }
        else
        {
            _logger.LogError(formattedMessage);
        }
    }

    private static string FormatMessage(string message, string? context, string timestamp)
    {
        return string.IsNullOrEmpty(context)
            ? $"[{timestamp}] {message}"
            : $"[{timestamp}] [{context}] {message}";
    }
}