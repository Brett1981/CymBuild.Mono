using Microsoft.Identity.Client;

namespace CymBuild_Outlook_Addin
{
    public class Functions
    {
        public static async Task<string> GetTokenForAPI(IConfiguration config, string token, LoggingHelper loggingHelper)
        {
            IConfigurationSection adConfig = config.GetSection("AzureAd");
            IConfigurationSection cymBuildAPIConfig = config.GetSection("CymBuildOutlookAPI");

            string apiScope = cymBuildAPIConfig.GetValue<string>("BaseUrl").ToString() + '/' + cymBuildAPIConfig.GetValue<string>("Scopes").ToString();
            string[] CymBuildInspectionsAPIScopes = new string[] { apiScope };

            var clientId = adConfig.GetValue<string>("ClientId").ToString();
            var tenantId = adConfig.GetValue<string>("TenantId").ToString();
            var clientSecret = adConfig.GetValue<string>("ClientSecret").ToString();

            var cca = ConfidentialClientApplicationBuilder
                .Create(clientId)
                .WithTenantId(tenantId)
                .WithClientSecret(clientSecret)
                .WithAuthority(new Uri($"https://login.microsoftonline.com/{tenantId}"))
                .Build();

            var assertion = new UserAssertion(token);

            AuthenticationResult result;
            try
            {
                result = await cca.AcquireTokenOnBehalfOf(CymBuildInspectionsAPIScopes, assertion)
                   .ExecuteAsync();
            }
            catch (MsalServiceException ex)
            {
                loggingHelper.LogError("Trying to acquire the Token for API", ex, "GetTokenForAPI()");
                throw;
            }
            catch (Exception ex)
            {
                loggingHelper.LogError("Trying to acquire the Token for API", ex, "GetTokenForAPI()");
                loggingHelper.LogWarning("Force freshing token", "GetTokenForAPI()");

                result = await cca.AcquireTokenOnBehalfOf(CymBuildInspectionsAPIScopes, assertion)
                    .WithForceRefresh(true)
                    .ExecuteAsync();
            }
            bool showInformationLogs = true;
            if (showInformationLogs)
            {
                loggingHelper.LogInfo($"Access Token for API: {result.AccessToken}", "GetTokenForAPI()");
            }
            return result.AccessToken;
        }
    }
}