namespace Concursus.API.Services.AIAssistant;

public sealed class BlueGenOptions
{
    public const string SectionName = "BlueGen";

    public string BaseUrl { get; set; } = "https://bluegen-dev.socotec.com";

    public string Endpoint { get; set; } = string.Empty;

    public string AuthEndpoint { get; set; } = string.Empty;

    public string PresignUrl { get; set; } = string.Empty;

    public string AgentId { get; set; } = string.Empty;

    public string AgentName { get; set; } = string.Empty;

    public string AgentUrl { get; set; } = string.Empty;

    public string AgentRoute { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string Password { get; set; } = string.Empty;

    public int TimeoutSeconds { get; set; } = 50;

    public int AuthTimeoutSeconds { get; set; } = 30;

    public int ChatTimeoutSeconds { get; set; } = 50;

    public void ApplyConnectionDefaults()
    {
        BaseUrl = NormaliseBaseUrl(BaseUrl);

        if (string.IsNullOrWhiteSpace(Endpoint))
        {
            Endpoint = CombineEndpoint(BaseUrl, "/api/chat");
        }

        if (string.IsNullOrWhiteSpace(AuthEndpoint))
        {
            AuthEndpoint = CombineEndpoint(BaseUrl, "/api/token");
        }

        if (string.IsNullOrWhiteSpace(PresignUrl))
        {
            PresignUrl = CombineEndpoint(BaseUrl, "/api/generate-presigned-url");
        }
    }

    public void ApplyEnvironmentOverrides()
    {
        var email = Environment.GetEnvironmentVariable("BLUEGEN_EMAIL");
        if (!string.IsNullOrWhiteSpace(email))
        {
            Email = email.Trim();
        }

        var password = Environment.GetEnvironmentVariable("BLUEGEN_PASSWORD");
        if (!string.IsNullOrWhiteSpace(password))
        {
            Password = password;
        }

        var baseUrl = Environment.GetEnvironmentVariable("BLUEGEN_BASE_URL");
        if (!string.IsNullOrWhiteSpace(baseUrl))
        {
            BaseUrl = baseUrl.Trim();
            Endpoint = string.Empty;
            AuthEndpoint = string.Empty;
            PresignUrl = string.Empty;
        }

        ApplyConnectionDefaults();
    }

    public void Validate()
    {
        ApplyConnectionDefaults();

        if (string.IsNullOrWhiteSpace(BaseUrl))
        {
            throw new InvalidOperationException("BlueGen BaseUrl is not configured.");
        }

        if (string.IsNullOrWhiteSpace(Endpoint))
        {
            throw new InvalidOperationException("BlueGen Endpoint is not configured.");
        }

        if (string.IsNullOrWhiteSpace(AuthEndpoint))
        {
            throw new InvalidOperationException("BlueGen AuthEndpoint is not configured.");
        }

        if (string.IsNullOrWhiteSpace(PresignUrl))
        {
            throw new InvalidOperationException("BlueGen PresignUrl is not configured.");
        }

        if (string.IsNullOrWhiteSpace(AgentId))
        {
            throw new InvalidOperationException("BlueGen AgentId is not configured.");
        }

        if (string.IsNullOrWhiteSpace(Email))
        {
            throw new InvalidOperationException("BlueGen Email is not configured.");
        }
    }

    public void ValidateCredentials()
    {
        if (string.IsNullOrWhiteSpace(Password))
        {
            throw new InvalidOperationException("BlueGen Password is not configured.");
        }
    }

    private static string NormaliseBaseUrl(string? value)
    {
        return string.IsNullOrWhiteSpace(value)
            ? "https://bluegen-dev.socotec.com"
            : value.Trim().TrimEnd('/');
    }

    private static string CombineEndpoint(string baseUrl, string relativePath)
    {
        var normalisedBase = NormaliseBaseUrl(baseUrl);
        return $"{normalisedBase}/{relativePath.TrimStart('/')}";
    }
}
