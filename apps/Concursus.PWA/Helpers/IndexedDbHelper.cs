
    using Concursus.PWA.Services;
    using Microsoft.JSInterop;
    using System.Threading.Tasks;

    namespace Concursus.PWA.Helpers
    {
        public class IndexedDbHelper
        {
            private readonly IJSRuntime _jsRuntime;
            private readonly IndexedDbService _indexedDbService;
            private IJSObjectReference _db;

            public IndexedDbHelper(IJSRuntime jsRuntime, IndexedDbService indexedDbService)
            {
                _jsRuntime = jsRuntime;
                _indexedDbService = indexedDbService;
            }

            // Initialize the IndexedDB with the given database name
            public async Task InitializeDatabaseAsync(string dbName)
            {
                _db = await _indexedDbService.OpenDatabase(dbName);
            }

            // Generic method to add an item to IndexedDB
            public async Task AddItemAsync<T>(string storeName, T item) where T : class
            {
                await _indexedDbService.AddItem(_db, storeName, item);
            }

            // Generic method to get an item from IndexedDB by its GUID
            public async Task<T> GetItemAsync<T>(string storeName, string guid) where T : class
            {
                return await _indexedDbService.GetItem<T>(_db, storeName, guid);
            }

            // Generic method to update an item in IndexedDB
            public async Task UpdateItemAsync<T>(string storeName, T item) where T : class
            {
                await _indexedDbService.UpdateItem(_db, storeName, item);
            }

            // Generic method to delete an item from IndexedDB by its GUID
            public async Task DeleteItemAsync(string storeName, string guid)
            {
                await _indexedDbService.DeleteItem(_db, storeName, guid);
            }
        }
    }