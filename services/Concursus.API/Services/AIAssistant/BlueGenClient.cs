using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Concursus.API.Services.AIAssistant;

public interface IBlueGenClient
{
    Task<BlueGenChatResult> SendChatAsync(
        string prompt,
        IReadOnlyList<BlueGenFileReference> files,
        CancellationToken cancellationToken);

    Task<BlueGenPresignedUrlResult> CreatePresignedUploadUrlAsync(
        string fileName,
        string contentType,
        CancellationToken cancellationToken);
}

public sealed class BlueGenClient : IBlueGenClient
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private readonly HttpClient _httpClient;
    private readonly BlueGenOptions _options;
    private readonly ILogger<BlueGenClient> _logger;

    private string? _accessToken;
    private DateTimeOffset _accessTokenExpiresUtc;

    public BlueGenClient(
        HttpClient httpClient,
        IOptions<BlueGenOptions> options,
        ILogger<BlueGenClient> logger)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
        _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));

        _options.Validate();

        _httpClient.Timeout = TimeSpan.FromSeconds(_options.TimeoutSeconds <= 0 ? 120 : _options.TimeoutSeconds);
    }

    public async Task<BlueGenChatResult> SendChatAsync(
        string prompt,
        IReadOnlyList<BlueGenFileReference> files,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(prompt))
        {
            throw new ArgumentException("A BlueGen prompt is required.", nameof(prompt));
        }

        var token = await GetAccessTokenAsync(cancellationToken).ConfigureAwait(false);

        using var request = new HttpRequestMessage(HttpMethod.Post, _options.Endpoint);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var payload = new BlueGenChatRequest
        {
            Message = prompt,
            Files = files?.ToArray() ?? Array.Empty<BlueGenFileReference>()
        };

        request.Content = new StringContent(
            JsonSerializer.Serialize(payload, JsonOptions),
            Encoding.UTF8,
            "application/json");

        using var response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken)
            .ConfigureAwait(false);

        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning(
                "BlueGen chat call failed with status {StatusCode}. Body: {Body}",
                (int)response.StatusCode,
                body);

            throw new BlueGenClientException($"BlueGen chat call failed with status {(int)response.StatusCode}: {body}");
        }

        return ParseChatResult(body);
    }

    public async Task<BlueGenPresignedUrlResult> CreatePresignedUploadUrlAsync(
        string fileName,
        string contentType,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(fileName))
        {
            throw new ArgumentException("A file name is required.", nameof(fileName));
        }

        if (string.IsNullOrWhiteSpace(contentType))
        {
            throw new ArgumentException("A content type is required.", nameof(contentType));
        }

        var token = await GetAccessTokenAsync(cancellationToken).ConfigureAwait(false);

        using var request = new HttpRequestMessage(HttpMethod.Post, _options.PresignUrl);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var payload = new BlueGenPresignedUrlRequest
        {
            FileName = fileName,
            ContentType = contentType
        };

        request.Content = new StringContent(
            JsonSerializer.Serialize(payload, JsonOptions),
            Encoding.UTF8,
            "application/json");

        using var response = await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);
        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning(
                "BlueGen presigned URL call failed with status {StatusCode}. Body: {Body}",
                (int)response.StatusCode,
                body);

            throw new BlueGenClientException($"BlueGen presigned URL call failed with status {(int)response.StatusCode}: {body}");
        }

        var parsed = JsonSerializer.Deserialize<BlueGenPresignedUrlResult>(body, JsonOptions);

        if (parsed is null || string.IsNullOrWhiteSpace(parsed.Url))
        {
            throw new BlueGenClientException("BlueGen presigned URL response did not contain a usable URL.");
        }

        return parsed;
    }

    private async Task<string> GetAccessTokenAsync(CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(_accessToken)
            && _accessTokenExpiresUtc > DateTimeOffset.UtcNow.AddMinutes(1))
        {
            return _accessToken;
        }

        var payload = new BlueGenTokenRequest
        {
            Email = _options.Email,
            Password = _options.Password
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, _options.AuthEndpoint)
        {
            Content = new StringContent(
                JsonSerializer.Serialize(payload, JsonOptions),
                Encoding.UTF8,
                "application/json")
        };

        using var response = await _httpClient.SendAsync(request, cancellationToken).ConfigureAwait(false);
        var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning(
                "BlueGen token call failed with status {StatusCode}. Body: {Body}",
                (int)response.StatusCode,
                body);

            throw new BlueGenClientException($"BlueGen token call failed with status {(int)response.StatusCode}: {body}");
        }

        var parsed = JsonSerializer.Deserialize<BlueGenTokenResponse>(body, JsonOptions);

        var token = parsed?.AccessToken
            ?? parsed?.AccessTokenCamel
            ?? parsed?.Token
            ?? parsed?.Jwt
            ?? ExtractStringProperty(body, "access_token")
            ?? ExtractStringProperty(body, "accessToken")
            ?? ExtractStringProperty(body, "token")
            ?? ExtractStringProperty(body, "jwt");

        if (string.IsNullOrWhiteSpace(token))
        {
            throw new BlueGenClientException("BlueGen token response did not include an access token.");
        }

        _accessToken = token;
        _accessTokenExpiresUtc = DateTimeOffset.UtcNow.AddMinutes(parsed?.ExpiresIn is > 0 ? Math.Min(parsed.ExpiresIn.Value / 60d, 50d) : 50d);

        return _accessToken;
    }

    private static BlueGenChatResult ParseChatResult(string body)
    {
        using var document = JsonDocument.Parse(body);
        var root = document.RootElement;

        var answer =
            TryGetString(root, "ai_response")
            ?? TryGetString(root, "response")
            ?? TryGetString(root, "answer")
            ?? TryGetString(root, "message")
            ?? TryGetString(root, "summary")
            ?? body;

        return new BlueGenChatResult
        {
            RawJson = body,
            AnswerMarkdown = answer,
            AnswerPlainText = answer,
            ConfidenceScore = TryGetDouble(root, "confidence") ?? TryGetDouble(root, "confidence_score"),
            ModelCode = TryGetString(root, "model") ?? "BLUEGEN"
        };
    }

    private static string? ExtractStringProperty(string json, string propertyName)
    {
        using var document = JsonDocument.Parse(json);
        return TryGetString(document.RootElement, propertyName);
    }

    private static string? TryGetString(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var property))
        {
            return null;
        }

        return property.ValueKind == JsonValueKind.String
            ? property.GetString()
            : property.ToString();
    }

    private static double? TryGetDouble(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var property))
        {
            return null;
        }

        if (property.ValueKind == JsonValueKind.Number && property.TryGetDouble(out var value))
        {
            return value;
        }

        if (property.ValueKind == JsonValueKind.String
            && double.TryParse(property.GetString(), out var parsed))
        {
            return parsed;
        }

        return null;
    }
}

public sealed class BlueGenClientException : Exception
{
    public BlueGenClientException(string message) : base(message)
    {
    }
}

public sealed class BlueGenTokenRequest
{
    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("password")]
    public string Password { get; set; } = string.Empty;
}

public sealed class BlueGenTokenResponse
{
    [JsonPropertyName("access_token")]
    public string? AccessToken { get; set; }

    [JsonPropertyName("accessToken")]
    public string? AccessTokenCamel { get; set; }

    [JsonPropertyName("token")]
    public string? Token { get; set; }

    [JsonPropertyName("jwt")]
    public string? Jwt { get; set; }

    [JsonPropertyName("expires_in")]
    public int? ExpiresIn { get; set; }
}

public sealed class BlueGenChatRequest
{
    [JsonPropertyName("message")]
    public string Message { get; set; } = string.Empty;

    [JsonPropertyName("files")]
    public IReadOnlyList<BlueGenFileReference> Files { get; set; } = Array.Empty<BlueGenFileReference>();
}

public sealed class BlueGenFileReference
{
    [JsonPropertyName("url")]
    public string Url { get; set; } = string.Empty;

    [JsonPropertyName("file_name")]
    public string FileName { get; set; } = string.Empty;

    [JsonPropertyName("content_type")]
    public string ContentType { get; set; } = string.Empty;
}

public sealed class BlueGenChatResult
{
    public string AnswerMarkdown { get; set; } = string.Empty;

    public string AnswerPlainText { get; set; } = string.Empty;

    public double? ConfidenceScore { get; set; }

    public string ModelCode { get; set; } = "BLUEGEN";

    public string RawJson { get; set; } = string.Empty;
}

public sealed class BlueGenPresignedUrlRequest
{
    [JsonPropertyName("file_name")]
    public string FileName { get; set; } = string.Empty;

    [JsonPropertyName("content_type")]
    public string ContentType { get; set; } = string.Empty;
}

public sealed class BlueGenPresignedUrlResult
{
    [JsonPropertyName("url")]
    public string Url { get; set; } = string.Empty;

    [JsonPropertyName("file_url")]
    public string? FileUrl { get; set; }

    [JsonPropertyName("fields")]
    public Dictionary<string, string> Fields { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}
