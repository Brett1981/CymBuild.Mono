using Concursus.PWA.Pages;
using Xunit;

namespace Concursus.PWA.Tests
{
    public class AuthenticationTests
    {
        [Fact]
        public void GetPostLoginCorrectionTarget_ShouldReturnPendingDeepLink_WhenFrameworkNavigatedElsewhere()
        {
            // RemoteAuthenticatorViewCore falls back to the app base URI when a deep link
            // is opened in a brand new tab/window (no continuous history/state to recover
            // the original target from). We must correct back to the recovered deep link.
            const string frameworkNavigatedLocation = "https://localhost:44368/";
            const string pendingDeepLink = "https://localhost:44368/structures/00000000-0000-0000-0000-000000000000";

            var result = Authentication.GetPostLoginCorrectionTarget(frameworkNavigatedLocation, pendingDeepLink);

            Assert.Equal(pendingDeepLink, result);
        }

        [Fact]
        public void GetPostLoginCorrectionTarget_ShouldReturnNull_WhenFrameworkAlreadyNavigatedToPendingDeepLink()
        {
            // No correction needed when the framework's own return-url resolution already
            // agrees with the recovered deep link (e.g. logging back in on the home page).
            const string url = "https://localhost:44368/structures/00000000-0000-0000-0000-000000000000";

            var result = Authentication.GetPostLoginCorrectionTarget(url, url);

            Assert.Null(result);
        }

        [Fact]
        public void GetPostLoginCorrectionTarget_ShouldBeCaseInsensitive()
        {
            const string frameworkNavigatedLocation = "https://localhost:44368/Structures/00000000-0000-0000-0000-000000000000";
            const string pendingDeepLink = "https://localhost:44368/structures/00000000-0000-0000-0000-000000000000";

            var result = Authentication.GetPostLoginCorrectionTarget(frameworkNavigatedLocation, pendingDeepLink);

            Assert.Null(result);
        }
    }
}
