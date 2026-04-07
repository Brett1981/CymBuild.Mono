using Microsoft.JSInterop;

namespace Concursus.PWA.Services
{
    public class IndexedDbService
    {
        private readonly IJSRuntime _jsRuntime;

        public IndexedDbService(IJSRuntime jsRuntime)
        {
            _jsRuntime = jsRuntime;
        }

        public async Task<IJSObjectReference> OpenDatabase(string dbName)
        {
            return await _jsRuntime.InvokeAsync<IJSObjectReference>("indexedDbInterop.openDatabase", dbName);
        }

        public async Task AddItem<T>(IJSObjectReference db, string storeName, T item)
        {
            await _jsRuntime.InvokeVoidAsync("indexedDbInterop.addItem", db, storeName, item);
        }

        public async Task<T> GetItem<T>(IJSObjectReference db, string storeName, string guid)
        {
            return await _jsRuntime.InvokeAsync<T>("indexedDbInterop.getItem", db, storeName, guid);
        }

        public async Task UpdateItem<T>(IJSObjectReference db, string storeName, T item)
        {
            await _jsRuntime.InvokeVoidAsync("indexedDbInterop.updateItem", db, storeName, item);
        }

        public async Task DeleteItem(IJSObjectReference db, string storeName, string guid)
        {
            await _jsRuntime.InvokeVoidAsync("indexedDbInterop.deleteItem", db, storeName, guid);
        }
    }
}