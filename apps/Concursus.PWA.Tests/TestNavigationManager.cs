using Microsoft.AspNetCore.Components;

namespace Concursus.PWA.Tests;

public sealed class TestNavigationManager : NavigationManager
{
    public string NavigatedUri { get; private set; } = string.Empty;

    public TestNavigationManager(string currentUri = "http://localhost/")
    {
        Initialize("http://localhost/", currentUri);
    }

    protected override void NavigateToCore(string uri, bool forceLoad)
    {
        NavigatedUri = uri;
    }
}
