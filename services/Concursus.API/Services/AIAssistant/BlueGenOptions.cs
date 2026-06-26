namespace Concursus.API.Services.AIAssistant;

public sealed class BlueGenOptions
{
    public const string SectionName = "BlueGen";

    public string Endpoint { get; set; } = string.Empty;

    public string AuthEndpoint { get; set; } = string.Empty;

    public string PresignUrl { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string Password { get; set; } = string.Empty;

    public int TimeoutSeconds { get; set; } = 120;

    public void Validate()
    {
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

        if (string.IsNullOrWhiteSpace(Email))
        {
            throw new InvalidOperationException("BlueGen Email is not configured.");
        }

        if (string.IsNullOrWhiteSpace(Password))
        {
            throw new InvalidOperationException("BlueGen Password is not configured.");
        }
    }
}
