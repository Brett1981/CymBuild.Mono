using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;
using System.Net.Http.Headers;

namespace CymBuild_Outlook_API.Helpers
{
    public sealed class GraphOboAuthHandler : DelegatingHandler
    {
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly ITokenAcquisition _tokenAcquisition;
        private readonly LoggingHelper _loggingHelper;
        private readonly string[] _scopes;
        private readonly string _corr;

        public GraphOboAuthHandler(
            IHttpContextAccessor httpContextAccessor,
            ITokenAcquisition tokenAcquisition,
            LoggingHelper loggingHelper,
            string[] scopes,
            string correlationId)
        {
            _httpContextAccessor = httpContextAccessor;
            _tokenAcquisition = tokenAcquisition;
            _loggingHelper = loggingHelper;
            _scopes = scopes;
            _corr = correlationId;

            InnerHandler = new HttpClientHandler();
        }

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            var user = _httpContextAccessor.HttpContext?.User;

            if (user?.Identity?.IsAuthenticated != true)
            {
                _loggingHelper.LogError(
                    $"[{_corr}] HttpContext.User is null or unauthenticated — cannot acquire OBO token.",
                    new Exception("OBO user missing"),
                    nameof(GraphOboAuthHandler));

                throw new MicrosoftIdentityWebChallengeUserException(
                    new Microsoft.Identity.Client.MsalUiRequiredException("user_null", "User is not authenticated for OBO token acquisition."),
                    _scopes);
            }

            var accessToken = await _tokenAcquisition.GetAccessTokenForUserAsync(
                _scopes,
                user: user,
                authenticationScheme: JwtBearerDefaults.AuthenticationScheme);

            request.Headers.Authorization =
                new AuthenticationHeaderValue("Bearer", accessToken);

            request.Headers.TryAddWithoutValidation("Prefer", "IdType=\"ImmutableId\"");

            return await base.SendAsync(request, cancellationToken);
        }
    }
}
