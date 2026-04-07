using Microsoft.Graph;
using Microsoft.Identity.Web;
using Microsoft.Kiota.Abstractions;
using Microsoft.Kiota.Abstractions.Authentication;
using System.Security.Claims;

namespace Concursus.API.Services.Graph;

public interface IDelegatedGraphClientFactory
{
    Task<GraphServiceClient> CreateAsync(ClaimsPrincipal user, CancellationToken ct);
}

public sealed class DelegatedGraphClientFactory : IDelegatedGraphClientFactory
{
    private readonly ITokenAcquisition _tokenAcquisition;

    private static readonly string[] Scopes =
    {
        "Sites.Read.All",
        "Files.Read.All",
        "Mail.ReadWrite"
    };

    public DelegatedGraphClientFactory(ITokenAcquisition tokenAcquisition)
    {
        _tokenAcquisition = tokenAcquisition ?? throw new ArgumentNullException(nameof(tokenAcquisition));
    }

    public async Task<GraphServiceClient> CreateAsync(ClaimsPrincipal user, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(user);
        ct.ThrowIfCancellationRequested();

        var token = await _tokenAcquisition.GetAccessTokenForUserAsync(
            Scopes,
            user: user,
            tokenAcquisitionOptions: null);

        ct.ThrowIfCancellationRequested();

        var accessTokenProvider = new StaticAccessTokenProvider(token);
        var authProvider = new BaseBearerTokenAuthenticationProvider(accessTokenProvider);

        return new GraphServiceClient(authProvider);
    }

    private sealed class StaticAccessTokenProvider : IAccessTokenProvider
    {
        private readonly string _token;

        public StaticAccessTokenProvider(string token)
        {
            _token = token ?? throw new ArgumentNullException(nameof(token));
        }

        public AllowedHostsValidator AllowedHostsValidator { get; } = new();

        public Task<string> GetAuthorizationTokenAsync(
            Uri uri,
            Dictionary<string, object>? additionalAuthenticationContext = null,
            CancellationToken cancellationToken = default)
        {
            return Task.FromResult(_token);
        }
    }
}