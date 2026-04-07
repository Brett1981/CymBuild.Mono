using Microsoft.JSInterop;

namespace Concursus.PWA.Helpers
{
    public class LocalStorageAccessor : IAsyncDisposable
    {
        private Lazy<IJSObjectReference> _accessorJsRef = new();
        private readonly IJSRuntime _jsRuntime;

        public LocalStorageAccessor(IJSRuntime jsRuntime)
        {
            _jsRuntime = jsRuntime;
        }

        private async Task WaitForReference()
        {
            if (_accessorJsRef.IsValueCreated is false)
            {
                _accessorJsRef = new(await _jsRuntime.InvokeAsync<IJSObjectReference>("import", "./localStorage.js"));
            }
        }

        public async ValueTask DisposeAsync()
        {
            if (_accessorJsRef.IsValueCreated)
            {
                await _accessorJsRef.Value.DisposeAsync();
            }
        }

        public async Task<T> GetValueAsync<T>(string key)
        {
            await WaitForReference();
            return await _accessorJsRef.Value.InvokeAsync<T>("get", key);
        }

        public async Task SetValueAsync<T>(string key, T value)
        {
            await WaitForReference();
            await _accessorJsRef.Value.InvokeVoidAsync("set", key, value);
        }

        public async Task ClearAsync()
        {
            await WaitForReference();
            await _accessorJsRef.Value.InvokeVoidAsync("clear");
        }

        public async Task RemoveAsync(string key)
        {
            await WaitForReference();
            await _accessorJsRef.Value.InvokeVoidAsync("remove", key);
        }

        //Clears the filters for all grids.
        public async Task ClearAllGridFilters()
        {
            await WaitForReference();
            await _accessorJsRef.Value.InvokeVoidAsync("clearAll");
        }
    }
}