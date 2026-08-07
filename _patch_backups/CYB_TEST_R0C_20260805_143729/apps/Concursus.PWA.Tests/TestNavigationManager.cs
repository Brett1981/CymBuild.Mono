using Microsoft.AspNetCore.Components;

namespace Concursus.PWA.Tests
{
    public class TestNavigationManager : NavigationManager
    {
        public string NavigatedUri { get; private set; } = string.Empty;

        public TestNavigationManager()
        {
            Initialize("http://localhost/", "http://localhost/");
        }

        protected override void NavigateToCore(string uri, bool forceLoad)
        {
            NavigatedUri = uri; // Capture the URI for verification
        }
    }
}