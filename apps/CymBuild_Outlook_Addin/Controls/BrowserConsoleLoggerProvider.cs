using Microsoft.JSInterop;

namespace CymBuild_Outlook_Addin.Controls
{
    public class BrowserConsoleLoggerProvider : ILoggerProvider
    {
        private readonly IJSRuntime _jsRuntime;

        public BrowserConsoleLoggerProvider(IJSRuntime jsRuntime)
        {
            _jsRuntime = jsRuntime;
        }

        public ILogger CreateLogger(string categoryName)
        {
            return new BrowserConsoleLogger(_jsRuntime, categoryName);
        }

        public void Dispose() { }
    }
}
