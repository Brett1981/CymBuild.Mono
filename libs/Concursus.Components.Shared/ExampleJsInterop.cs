using Microsoft.JSInterop;

namespace Concursus.Components.Shared;
// This class provides an example of how JavaScript functionality can be wrapped in a .NET class for
// easy consumption. The associated JavaScript module is loaded on demand when first needed.
//
// This class can be registered as scoped DI service and then injected into Blazor components for use.

public class ExampleJsInterop : IAsyncDisposable
{
    #region Private Fields

    private readonly Lazy<Task<IJSObjectReference>> moduleTask;

    #endregion Private Fields

    #region Public Constructors

    public ExampleJsInterop(IJSRuntime jsRuntime)
    {
        moduleTask = new Lazy<Task<IJSObjectReference>>(() => jsRuntime.InvokeAsync<IJSObjectReference>(
            "import", "./_content/Concursus.Components.Shared/exampleJsInterop.js").AsTask());
    }

    #endregion Public Constructors

    #region Public Methods

    public async ValueTask DisposeAsync()
    {
        if (moduleTask.IsValueCreated)
        {
            var module = await moduleTask.Value;
            await module.DisposeAsync();
        }
    }

    public async ValueTask<string> Prompt(string message)
    {
        var module = await moduleTask.Value;
        return await module.InvokeAsync<string>("showPrompt", message);
    }

    #endregion Public Methods
}