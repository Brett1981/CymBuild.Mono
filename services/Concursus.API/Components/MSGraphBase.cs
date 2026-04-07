using Azure.Identity;
using Microsoft.Graph;

namespace Concursus.API.Components;

public class MSGraphBase
{
    #region Protected Fields

    protected GraphServiceClient _graphServiceClient;

    #endregion Protected Fields

    #region Private Fields

    public readonly IConfiguration _config;

    #endregion Private Fields

    #region Public Constructors

    public MSGraphBase(IConfiguration config)
    {
        _config = config;
        _graphServiceClient = GetGraphClient();
    }

    #endregion Public Constructors

    #region Public Methods

    public GraphServiceClient GetGraphClient()
    {
        if (_graphServiceClient == null)
        {
            var azureAppConfig = _config.GetSection("AzureAd");
            var clientId = azureAppConfig.GetValue<string>("ClientId");
            var tenantId = azureAppConfig.GetValue<string>("TenantId");
            var clientSecret = azureAppConfig.GetValue<string>("ClientSecret");

            var clientSecretCredential = new ClientSecretCredential(tenantId, clientId, clientSecret);
            _graphServiceClient = new GraphServiceClient(clientSecretCredential);
        }

        return _graphServiceClient;
    }

    #endregion Public Methods
}