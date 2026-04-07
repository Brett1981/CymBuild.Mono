using Concursus.API.Classes;
using Microsoft.Graph;
using Microsoft.Graph.Models;

namespace Concursus.API.Components;

public class AzureADManagement
{
    #region Private Fields

    private readonly IConfiguration _config;

    //private readonly List<Microsoft.Graph.Option> graphAPIHeaderOptions;
    private readonly GraphServiceClient _graphClient;

    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly Logging _logger;

    #endregion Private Fields

    #region Public Constructors

    public AzureADManagement(
        IConfiguration config,
        IHttpContextAccessor httpContextAccessor,
        Logging logger,
        GraphServiceClient graphServiceClient
    )
    {
        _config = config;
        _httpContextAccessor = httpContextAccessor;
        _logger = logger;

        _graphClient = graphServiceClient;
    }

    #endregion Public Constructors

    #region Public Methods

    public async Task<bool> AddApplicationRolesForUser(User userRecord, string[] appRoleIds, string appDisplayName)
    {
        var servicePrincipal = await GetServicePrincipal(appDisplayName);

        if (servicePrincipal != null)
        {
            var _resourceId = Functions.ParseAndReturnEmptyGuidIfInvalid(servicePrincipal.Id).ToString();

            var _principalId = Functions.ParseAndReturnEmptyGuidIfInvalid(userRecord.Id).ToString();

            foreach (var appRoleId in appRoleIds)
            {
                var appRoleAssignment = new AppRoleAssignment
                {
                    PrincipalId = Functions.ParseAndReturnEmptyGuidIfInvalid(_principalId),
                    ResourceId = Functions.ParseAndReturnEmptyGuidIfInvalid(_resourceId),
                    AppRoleId = Functions.ParseAndReturnEmptyGuidIfInvalid(appRoleId)
                };

                await _graphClient
                    .Users[userRecord.UserPrincipalName]
                    .AppRoleAssignments
                    .PostAsync(appRoleAssignment);
            }
        }

        return true;
    }

    public async Task<List<string>> GetApplicationRolesForUser(User userRecord, string appDisplayName)
    {
        List<string> roles = new();

        // Get the possible application roles
        var servicePrincipals = await _graphClient
            .ServicePrincipals
            .GetAsync(
                requestConfig =>
                {
                    requestConfig.Headers.Add("ConsistencyLevel", "eventual");
                    requestConfig.QueryParameters.Filter = "startswith(displayName, '" + appDisplayName + "')";
                    requestConfig.QueryParameters.Top = 1;
                }
            ) ?? throw new Exception("Failed to retrieve service principle");

        if (servicePrincipals.Value != null)
        {
            var _principalId = (servicePrincipals.Value.FirstOrDefault() ?? new ServicePrincipal()).Id ?? "";
        }

        var _resourceId = userRecord.Id ?? "";

        var appRoleAssignments = await _graphClient
            .Users[userRecord.UserPrincipalName]
            .AppRoleAssignments
            .GetAsync();

        if (appRoleAssignments != null)
            if (appRoleAssignments.Value != null)
                foreach (var appRoleAssignment in appRoleAssignments.Value)
                    roles.Add((appRoleAssignment.AppRoleId ?? Guid.Empty).ToString());

        return roles;
    }

    public async Task<User> GetAzureUserRecord(string UserPrincipleName)
    {
        var userRecord = await _graphClient
            .Users[UserPrincipleName]
            .GetAsync();

        if (userRecord != null)
            return userRecord;
        else
            throw new Exception("Failed to get Azure User Record.");
    }

    public async Task<bool> RemoveApplicationRoleForUser(User userRecord, string[] appRoleIds, string appDisplayName)
    {
        var servicePrincipal = await GetServicePrincipal(appDisplayName);

        if (servicePrincipal != null)
        {
            var _resourceId = servicePrincipal.Id ?? "";

            var _principleId = userRecord.Id ?? "";

            var appRoleAssignments = await _graphClient
                .Users[userRecord.UserPrincipalName]
                .AppRoleAssignments
                .GetAsync();

            if (appRoleAssignments != null)
                foreach (var appRoleAssignment in appRoleAssignments.Value ?? new List<AppRoleAssignment>())
                    if (appRoleAssignment.ResourceId.ToString() == _resourceId)
                        foreach (var appRoleId in appRoleIds)
                            if (appRoleId == appRoleAssignment.AppRoleId.ToString())
                                await _graphClient
                                    .Users[userRecord.UserPrincipalName]
                                    .AppRoleAssignments[appRoleAssignment.Id]
                                    .DeleteAsync();
        }

        return true;
    }

    #endregion Public Methods

    #region Private Methods

    private async Task<ServicePrincipal?> GetServicePrincipal(string appDisplayName)
    {
        return ((await _graphClient.ServicePrincipals
                     .GetAsync(
                         requestConfig =>
                         {
                             requestConfig.Headers.Add("ConsistencyLevel", "eventual");
                             requestConfig.QueryParameters.Filter = "startswith(displayName, '" + appDisplayName + "')";
                             requestConfig.QueryParameters.Top = 1;
                         }
                     )
                 ?? throw new Exception("Failed to obtain service principle."))
                .Value ?? throw new Exception("Failed to obtain service principle."))
            .First();
    }

    #endregion Private Methods
}