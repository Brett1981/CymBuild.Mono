using Microsoft.Extensions.Logging;
using Microsoft.JSInterop;

namespace CymBuild_Outlook_Common.Controls
{
    public class BrowserConsoleLogger : ILogger
    {
        private readonly IJSRuntime _jsRuntime;
        private readonly string _categoryName;

        public BrowserConsoleLogger(IJSRuntime jsRuntime, string categoryName)
        {
            _jsRuntime = jsRuntime;
            _categoryName = categoryName;
        }

        public IDisposable BeginScope<TState>(TState state) => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception exception, Func<TState, Exception, string> formatter)
        {
            var message = $"{logLevel.ToString().ToUpper()}: {_categoryName}[{eventId.Id}] {formatter(state, exception)}";
            _jsRuntime.InvokeVoidAsync("logging.logToConsole", message);
        }
    }
}