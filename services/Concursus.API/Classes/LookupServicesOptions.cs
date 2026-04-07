namespace Concursus.API.Classes;

public sealed class LookupServicesOptions
{
    public bool Enabled { get; set; } = true;

    /// <summary>
    /// Base address for the internal PostCode API, for example:
    /// https://postcodelookup-dev.socotec.co.uk/api/
    /// </summary>
    public string BaseUrl { get; set; } = string.Empty;

    /// <summary>
    /// Optional application name/header value if required by the downstream service.
    /// </summary>
    public string ApplicationName { get; set; } = string.Empty;

    /// <summary>
    /// Optional API key/header value if required by the downstream service.
    /// </summary>
    public string ApiKey { get; set; } = string.Empty;
}