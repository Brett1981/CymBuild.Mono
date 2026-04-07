using Microsoft.Identity.Client;

namespace CymBuild_Outlook_API.Helpers
{
    public class Functions
    {
        public static async Task<string> GetTokenForAPI(IConfiguration config, LoggingHelper loggingHelper)
        {
            IConfigurationSection adConfig = config.GetSection("AzureAd");

            var clientId = adConfig.GetValue<string>("ClientId");
            var tenantId = adConfig.GetValue<string>("TenantId");
            var clientSecret = adConfig.GetValue<string>("ClientSecret");
            var resource = adConfig.GetValue<string>("BaseUrl"); // Ensure this is set to your API base URL

            var cca = ConfidentialClientApplicationBuilder
                .Create(clientId)
                .WithTenantId(tenantId)
                .WithClientSecret(clientSecret)
                .WithAuthority(new Uri($"https://login.microsoftonline.com/{tenantId}"))
                .Build();

            var scopes = new string[] { $"{resource}/.default" }; // Use .default suffix

            AuthenticationResult result;
            try
            {
                loggingHelper.LogInfo("Attempting to acquire token using client credentials...", "GetTokenForAPI()");
                result = await cca.AcquireTokenForClient(scopes)
                    .ExecuteAsync();
                loggingHelper.LogInfo("Token acquired successfully.", "GetTokenForAPI()");
            }
            catch (MsalServiceException ex)
            {
                loggingHelper.LogError($"MsalServiceException:", ex, "GetTokenForAPI()");
                throw;
            }
            catch (Exception ex)
            {
                loggingHelper.LogError($"General Exception:", ex, "GetTokenForAPI()");
                throw;
            }

            return result.AccessToken;
        }

        public static async Task<string> GetUserToken(IConfiguration config, UserAssertion userAssertion, LoggingHelper loggingHelper)
        {
            IConfigurationSection adConfig = config.GetSection("AzureAd");

            var clientId = adConfig.GetValue<string>("ClientId");
            var tenantId = adConfig.GetValue<string>("TenantId");
            var clientSecret = adConfig.GetValue<string>("ClientSecret");

            var cca = ConfidentialClientApplicationBuilder
                .Create(clientId)
                .WithTenantId(tenantId)
                .WithClientSecret(clientSecret)
                .WithAuthority(new Uri($"https://login.microsoftonline.com/{tenantId}"))
                .Build();

            var scopes = new string[] { "User.Read", "User.ReadWrite.All", "Mail.Read", "Sites.ReadWrite.All" };

            var assertion = userAssertion;

            AuthenticationResult result;
            try
            {
                loggingHelper.LogInfo("Attempting to acquire user token using on-behalf-of flow...", "GetUserToken()");
                result = await cca.AcquireTokenOnBehalfOf(scopes, assertion)
                    .ExecuteAsync();
                loggingHelper.LogInfo("User token acquired successfully.", "GetUserToken()");
            }
            catch (MsalServiceException ex)
            {
                loggingHelper.LogError($"MsalServiceException", ex, "GetUserToken()");
                throw;
            }
            catch (Exception ex)
            {
                loggingHelper.LogError($"General Exception", ex, "GetUserToken()");
                throw;
            }

            return result.AccessToken;
        }
    }
}