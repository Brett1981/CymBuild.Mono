public class AppConfiguration
{
    public string? Version { get; private set; }
    public string? EFVersion { get; private set; }
    public string? EnvironmentType { get; private set; }
    public string? DevSharepointIdentifier { get; private set; }
    public string? DevSharepointURL { get; private set; }
    public bool IsLiveMessageActive { get; private set; } = false;
    public string LiveMessageText { get; private set; } = "";
    public bool ShowBanner { get; private set; } = false;

    public AppConfiguration(IConfiguration configuration)
    {
        LoadConfiguration(configuration);
    }

    private void LoadConfiguration(IConfiguration configuration)
    {
        Version = configuration["Versioning:PWAVersion"];
        EFVersion = configuration["Versioning:EFVersion"];
        EnvironmentType = configuration["Environment:Type"];
        DevSharepointIdentifier = configuration["Environment:DevSharepointIdentifier"];
        DevSharepointURL = configuration["Environment:DevSharepointURL"];
        LiveMessageText = configuration["Environment:LiveMessageText"];
        IsLiveMessageActive = bool.Parse(configuration["Environment:IsLiveMessageActive"]);
        ShowBanner = bool.Parse(configuration["Environment:ShowBanner"]);
    }
}