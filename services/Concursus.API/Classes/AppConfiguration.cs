namespace Concursus.API.Classes;

public class AppConfiguration
{
    public string? EnvironmentType { get; private set; }
    public string? DevSharepointIdentifier { get; private set; }
    public string? DevSharepointURL { get; private set; }

    public string? MessageText =
        "THIS IS A DEVELOPMENT VERSION OF THE SOFTWARE!";

    public AppConfiguration(IConfiguration configuration)
    {
        LoadConfiguration(configuration);
    }

    private void LoadConfiguration(IConfiguration configuration)
    {
        EnvironmentType = configuration["Environment:Type"];
        DevSharepointIdentifier = configuration["Environment:DevSharepointIdentifier"];
        DevSharepointURL = configuration["Environment:DevSharepointURL"];
    }
}