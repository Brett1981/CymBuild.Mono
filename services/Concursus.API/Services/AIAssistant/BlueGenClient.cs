using System.Net;
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

        _options.ApplyEnvironmentOverrides();
        _options.Validate();

        _httpClient.Timeout = TimeSpan.FromSeconds(_options.TimeoutSeconds <= 0 ? 50 : _options.TimeoutSeconds);
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

        var safeFiles = files?
            .Where(file => !string.IsNullOrWhiteSpace(file.Url) || !string.IsNullOrWhiteSpace(file.Folder))
            .ToArray() ?? Array.Empty<BlueGenFileReference>();

        var token = await GetAccessTokenAsync(cancellationToken).ConfigureAwait(false);
        var firstAttempt = await SendChatRequestAsync(token, prompt, safeFiles, cancellationToken).ConfigureAwait(false);

        if (firstAttempt.StatusCode == HttpStatusCode.Unauthorized)
        {
            _logger.LogInformation("BlueGen chat call returned Unauthorized. Clearing cached token and retrying once.");
            ClearCachedToken();

            token = await GetAccessTokenAsync(cancellationToken).ConfigureAwait(false);
            firstAttempt = await SendChatRequestAsync(token, prompt, safeFiles, cancellationToken).ConfigureAwait(false);
        }

        if (!firstAttempt.IsSuccessStatusCode)
        {
            _logger.LogWarning(
                "BlueGen chat call failed with status {StatusCode}. Body: {Body}",
                (int)firstAttempt.StatusCode,
                firstAttempt.Body);

            throw new BlueGenClientException($"BlueGen chat call failed with status {(int)firstAttempt.StatusCode}: {firstAttempt.Body}");
        }

        return ParseChatResult(firstAttempt.Body);
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

        using var timeoutCts = CreateOperationTimeout(cancellationToken, _options.ChatTimeoutSeconds <= 0 ? 50 : _options.ChatTimeoutSeconds);
        using var request = new HttpRequestMessage(HttpMethod.Post, _options.PresignUrl);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var payload = new BlueGenPresignedUrlRequest
        {
            Files = new[] { fileName }
        };

        request.Content = new StringContent(
            JsonSerializer.Serialize(payload, JsonOptions),
            Encoding.UTF8,
            "application/json");

        using var response = await _httpClient.SendAsync(request, timeoutCts.Token).ConfigureAwait(false);
        var body = await response.Content.ReadAsStringAsync(timeoutCts.Token).ConfigureAwait(false);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning(
                "BlueGen presigned URL call failed with status {StatusCode}. Body: {Body}",
                (int)response.StatusCode,
                body);

            throw new BlueGenClientException($"BlueGen presigned URL call failed with status {(int)response.StatusCode}: {body}");
        }

        return ParsePresignedUrlResult(body);
    }

    private async Task<BlueGenHttpResult> SendChatRequestAsync(
        string token,
        string prompt,
        IReadOnlyList<BlueGenFileReference> files,
        CancellationToken cancellationToken)
    {
        using var timeoutCts = CreateOperationTimeout(cancellationToken, _options.ChatTimeoutSeconds <= 0 ? 50 : _options.ChatTimeoutSeconds);
        using var request = new HttpRequestMessage(HttpMethod.Post, _options.Endpoint);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var payload = BuildChatPayload(prompt, files);

        request.Content = new StringContent(
            JsonSerializer.Serialize(payload, JsonOptions),
            Encoding.UTF8,
            "application/json");

        using var response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, timeoutCts.Token)
            .ConfigureAwait(false);

        var body = await response.Content.ReadAsStringAsync(timeoutCts.Token).ConfigureAwait(false);

        return new BlueGenHttpResult(response.StatusCode, response.IsSuccessStatusCode, body);
    }

    private async Task<string> GetAccessTokenAsync(CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(_accessToken)
            && _accessTokenExpiresUtc > DateTimeOffset.UtcNow.AddMinutes(1))
        {
            return _accessToken;
        }

        _options.ValidateCredentials();

        var tokenUri = BuildUriWithQueryParameters(
            _options.AuthEndpoint,
            new Dictionary<string, string>
            {
                ["email"] = _options.Email,
                ["password"] = _options.Password
            });

        using var timeoutCts = CreateOperationTimeout(cancellationToken, _options.AuthTimeoutSeconds <= 0 ? 30 : _options.AuthTimeoutSeconds);
        using var request = new HttpRequestMessage(HttpMethod.Post, tokenUri);

        // BlueGen current method requires email/password in the query string and no request body.
        using var response = await _httpClient.SendAsync(request, timeoutCts.Token).ConfigureAwait(false);
        var body = await response.Content.ReadAsStringAsync(timeoutCts.Token).ConfigureAwait(false);

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

    private object BuildChatPayload(string prompt, IReadOnlyList<BlueGenFileReference> files)
    {
        if (files.Count == 0)
        {
            return new BlueGenChatRequest
            {
                Message = prompt
            };
        }

        var folder = files
            .Select(file => file.Folder)
            .FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));

        if (string.IsNullOrWhiteSpace(folder))
        {
            throw new BlueGenClientException("BlueGen attachment analysis requires the folder returned by /api/generate-presigned-url. The assistant upload record did not contain a BlueGen folder reference.");
        }

        return new BlueGenChatRequest
        {
            Message = prompt,
            Folder = folder
        };
    }

    private static BlueGenPresignedUrlResult ParsePresignedUrlResult(string body)
    {
        if (string.IsNullOrWhiteSpace(body))
        {
            throw new BlueGenClientException("BlueGen presigned URL response was empty.");
        }

        BlueGenPresignedUrlResult? parsed = null;
        try
        {
            parsed = JsonSerializer.Deserialize<BlueGenPresignedUrlResult>(body, JsonOptions);
        }
        catch (JsonException)
        {
            // Fall through to tolerant parsing below.
        }

        var uploadUrl = parsed?.Url;

        if (string.IsNullOrWhiteSpace(uploadUrl))
        {
            uploadUrl = parsed?.PresignedUrls?.FirstOrDefault(value => !string.IsNullOrWhiteSpace(value))
                ?? ExtractStringProperty(body, "presigned_url")
                ?? ExtractStringProperty(body, "presignedUrl")
                ?? ExtractStringProperty(body, "upload_url")
                ?? ExtractStringProperty(body, "uploadUrl")
                ?? ExtractStringProperty(body, "url");
        }

        if (string.IsNullOrWhiteSpace(uploadUrl))
        {
            throw new BlueGenClientException("BlueGen presigned URL response did not contain a usable upload URL.");
        }

        var fileUrl = parsed?.FileUrl
            ?? ExtractStringProperty(body, "file_url")
            ?? ExtractStringProperty(body, "fileUrl")
            ?? ExtractStringProperty(body, "storage_url")
            ?? ExtractStringProperty(body, "storageUrl");

        var folder = parsed?.Folder
            ?? ExtractStringProperty(body, "folder")
            ?? ExtractStringProperty(body, "folderName")
            ?? ExtractStringProperty(body, "folder_name");

        return new BlueGenPresignedUrlResult
        {
            Url = uploadUrl,
            FileUrl = fileUrl,
            Folder = folder,
            Fields = parsed?.Fields ?? new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        };
    }

    private static Uri BuildUriWithQueryParameters(string uri, IReadOnlyDictionary<string, string> parameters)
    {
        if (string.IsNullOrWhiteSpace(uri))
        {
            throw new BlueGenClientException("BlueGen URI was not configured.");
        }

        var builder = new UriBuilder(uri);
        var queryParts = new List<string>();

        if (!string.IsNullOrWhiteSpace(builder.Query))
        {
            queryParts.Add(builder.Query.TrimStart('?'));
        }

        foreach (var parameter in parameters)
        {
            queryParts.Add(
                $"{Uri.EscapeDataString(parameter.Key)}={Uri.EscapeDataString(parameter.Value ?? string.Empty)}");
        }

        builder.Query = string.Join("&", queryParts.Where(part => !string.IsNullOrWhiteSpace(part)));
        return builder.Uri;
    }

    private static BlueGenChatResult ParseChatResult(string body)
    {
        if (string.IsNullOrWhiteSpace(body))
        {
            throw new BlueGenClientException("BlueGen chat response was empty.");
        }

        try
        {
            using var document = JsonDocument.Parse(body);
            var root = document.RootElement;

            var answer =
                TryGetString(root, "ai_response")
                ?? TryGetString(root, "response")
                ?? TryGetString(root, "answer")
                ?? TryGetString(root, "message")
                ?? TryGetString(root, "summary")
                ?? TryFindAnswerText(root)
                ?? body;

            return new BlueGenChatResult
            {
                RawJson = body,
                AnswerMarkdown = answer,
                AnswerPlainText = answer,
                ConfidenceScore = TryGetDouble(root, "confidence")
                    ?? TryGetDouble(root, "confidence_score")
                    ?? TryFindDoubleProperty(root, "confidence", "confidence_score", "score"),
                ModelCode = TryGetString(root, "model")
                    ?? TryFindStringProperty(root, "model", "modelCode", "model_code", "provider")
                    ?? "BLUEGEN"
            };
        }
        catch (JsonException)
        {
            return new BlueGenChatResult
            {
                RawJson = body,
                AnswerMarkdown = body,
                AnswerPlainText = body,
                ConfidenceScore = null,
                ModelCode = "BLUEGEN:RAW_TEXT"
            };
        }
    }

    private static string? TryFindAnswerText(JsonElement root)
    {
        var direct = TryFindStringProperty(
            root,
            "content",
            "text",
            "output",
            "result",
            "completion",
            "generated_text",
            "generatedText");

        if (!string.IsNullOrWhiteSpace(direct))
        {
            return direct;
        }

        if (root.ValueKind == JsonValueKind.Object
            && root.TryGetProperty("choices", out var choices)
            && choices.ValueKind == JsonValueKind.Array)
        {
            foreach (var choice in choices.EnumerateArray())
            {
                var choiceText = TryFindStringProperty(choice, "content", "text", "message");
                if (!string.IsNullOrWhiteSpace(choiceText))
                {
                    return choiceText;
                }
            }
        }

        return null;
    }

    private static string? TryFindStringProperty(JsonElement element, params string[] propertyNames)
    {
        if (propertyNames.Length == 0)
        {
            return null;
        }

        var names = propertyNames.ToHashSet(StringComparer.OrdinalIgnoreCase);
        return TryFindStringProperty(element, names, depthRemaining: 8);
    }

    private static string? TryFindStringProperty(JsonElement element, ISet<string> propertyNames, int depthRemaining)
    {
        if (depthRemaining <= 0)
        {
            return null;
        }

        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                foreach (var property in element.EnumerateObject())
                {
                    if (propertyNames.Contains(property.Name))
                    {
                        var value = TryReadJsonTextValue(property.Value);
                        if (!string.IsNullOrWhiteSpace(value))
                        {
                            return value;
                        }
                    }
                }

                foreach (var property in element.EnumerateObject())
                {
                    var nested = TryFindStringProperty(property.Value, propertyNames, depthRemaining - 1);
                    if (!string.IsNullOrWhiteSpace(nested))
                    {
                        return nested;
                    }
                }

                return null;

            case JsonValueKind.Array:
                foreach (var item in element.EnumerateArray())
                {
                    var nested = TryFindStringProperty(item, propertyNames, depthRemaining - 1);
                    if (!string.IsNullOrWhiteSpace(nested))
                    {
                        return nested;
                    }
                }

                return null;

            default:
                return null;
        }
    }

    private static string? TryReadJsonTextValue(JsonElement value)
    {
        return value.ValueKind switch
        {
            JsonValueKind.String => value.GetString(),
            JsonValueKind.Number => value.ToString(),
            JsonValueKind.True => "true",
            JsonValueKind.False => "false",
            JsonValueKind.Object => TryFindStringProperty(value, "content", "text", "message", "answer", "response"),
            JsonValueKind.Array => TryReadFirstJsonArrayTextValue(value),
            _ => null
        };
    }

    private static string? TryReadFirstJsonArrayTextValue(JsonElement value)
    {
        foreach (var item in value.EnumerateArray())
        {
            var text = TryReadJsonTextValue(item);
            if (!string.IsNullOrWhiteSpace(text))
            {
                return text;
            }
        }

        return null;
    }

    private static double? TryFindDoubleProperty(JsonElement element, params string[] propertyNames)
    {
        if (propertyNames.Length == 0)
        {
            return null;
        }

        var names = propertyNames.ToHashSet(StringComparer.OrdinalIgnoreCase);
        return TryFindDoubleProperty(element, names, depthRemaining: 8);
    }

    private static double? TryFindDoubleProperty(JsonElement element, ISet<string> propertyNames, int depthRemaining)
    {
        if (depthRemaining <= 0)
        {
            return null;
        }

        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                foreach (var property in element.EnumerateObject())
                {
                    if (propertyNames.Contains(property.Name))
                    {
                        var value = TryReadJsonDoubleValue(property.Value);
                        if (value.HasValue)
                        {
                            return value.Value;
                        }
                    }
                }

                foreach (var property in element.EnumerateObject())
                {
                    var nested = TryFindDoubleProperty(property.Value, propertyNames, depthRemaining - 1);
                    if (nested.HasValue)
                    {
                        return nested.Value;
                    }
                }

                return null;

            case JsonValueKind.Array:
                foreach (var item in element.EnumerateArray())
                {
                    var nested = TryFindDoubleProperty(item, propertyNames, depthRemaining - 1);
                    if (nested.HasValue)
                    {
                        return nested.Value;
                    }
                }

                return null;

            default:
                return null;
        }
    }

    private static double? TryReadJsonDoubleValue(JsonElement value)
    {
        if (value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out var number))
        {
            return number;
        }

        if (value.ValueKind == JsonValueKind.String
            && double.TryParse(value.GetString(), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var parsed))
        {
            return parsed;
        }

        return null;
    }

    private static string? ExtractStringProperty(string json, string propertyName)
    {
        try
        {
            using var document = JsonDocument.Parse(json);
            return TryFindStringProperty(document.RootElement, propertyName);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static string? TryGetString(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var property))
        {
            return null;
        }

        return TryReadJsonTextValue(property);
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
            && double.TryParse(property.GetString(), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var parsed))
        {
            return parsed;
        }

        return null;
    }

    private void ClearCachedToken()
    {
        _accessToken = null;
        _accessTokenExpiresUtc = DateTimeOffset.MinValue;
    }

    private static CancellationTokenSource CreateOperationTimeout(CancellationToken cancellationToken, int timeoutSeconds)
    {
        var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        cts.CancelAfter(TimeSpan.FromSeconds(timeoutSeconds <= 0 ? 50 : timeoutSeconds));
        return cts;
    }

    private sealed record BlueGenHttpResult(HttpStatusCode StatusCode, bool IsSuccessStatusCode, string Body);
}

public sealed class BlueGenClientException : Exception
{
    public BlueGenClientException(string message) : base(message)
    {
    }
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

    [JsonPropertyName("folder")]
    public string? Folder { get; set; }
}

public sealed class BlueGenFileReference
{
    [JsonPropertyName("url")]
    public string Url { get; set; } = string.Empty;

    [JsonPropertyName("file_name")]
    public string FileName { get; set; } = string.Empty;

    [JsonPropertyName("content_type")]
    public string ContentType { get; set; } = string.Empty;

    [JsonPropertyName("folder")]
    public string? Folder { get; set; }
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
    [JsonPropertyName("files")]
    public IReadOnlyList<string> Files { get; set; } = Array.Empty<string>();
}

public sealed class BlueGenPresignedUrlResult
{
    [JsonPropertyName("url")]
    public string Url { get; set; } = string.Empty;

    [JsonPropertyName("presigned_url")]
    public IReadOnlyList<string>? PresignedUrls { get; set; }

    [JsonPropertyName("file_url")]
    public string? FileUrl { get; set; }

    [JsonPropertyName("folder")]
    public string? Folder { get; set; }

    [JsonPropertyName("fields")]
    public Dictionary<string, string> Fields { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}
