using Azure.Core;
using Microsoft.Kiota.Abstractions;
using Microsoft.Kiota.Abstractions.Authentication;

namespace CymBuild_Outlook_API.Helpers
{
    public class TokenCredentialAuthProvider : IAuthenticationProvider
    {
        private readonly TokenCredential _tokenCredential;

        public TokenCredentialAuthProvider(TokenCredential tokenCredential)
        {
            _tokenCredential = tokenCredential;
        }

        public async Task AuthenticateRequestAsync(RequestInformation request, Dictionary<string, object> additionalAuthenticationContext = null, CancellationToken cancellationToken = default)
        {
            var tokenRequestContext = new TokenRequestContext(new[] { "https://graph.microsoft.com/.default" });
            var token = await _tokenCredential.GetTokenAsync(tokenRequestContext, cancellationToken);
            request.Headers.Add("Authorization", $"Bearer {token.Token}");
            request.Headers.Add("Prefer", "IdType=\"ImmutableId\"");
        }
    }
}