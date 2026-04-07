using Concursus.API.Client.Models;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.JSInterop;
using System.Text.Json;

namespace Concursus.Components.Shared.Services
{
    public class OfflineSyncService
    {
        private readonly IJSRuntime _js;
        private readonly string _dbName;
        private readonly HubConnection _hubConnection;
        private readonly UserService _userService;

        public OfflineSyncService(IJSRuntime js, HubConnection hubConnection, UserService userService, string environment)
        {
            _js = js;
            _hubConnection = hubConnection;
            _userService = userService;
            _dbName = $"CymBuildDB_{environment}";
        }

        // Generic Add or Update
        public async Task SetItemAsync<T>(string storeName, string key, T value)
        {
            var json = JsonSerializer.Serialize(value);
            await _js.InvokeVoidAsync("indexedDbInterop.setItem", _dbName, storeName, key, json);
        }

        // Generic Get
        public async Task<T?> GetItemAsync<T>(string storeName, string key)
        {
            var json = await _js.InvokeAsync<string?>("indexedDbInterop.getItem", _dbName, storeName, key);
            if (string.IsNullOrEmpty(json))
                return default;

            try
            {
                return JsonSerializer.Deserialize<T>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            }
            catch (JsonException ex)
            {
                Console.Error.WriteLine($"[OfflineSync] Failed to deserialize item '{key}' from '{storeName}': {ex.Message}");
                await MigrateCorruptItemToErrorQueue(key, json!, ex.Message);
                return default;
            }
        }

        // TryGet wrapper for SyncQueue
        public async Task<(bool Success, SyncQueueItem? Item)> TryGetQueueItemAsync(string id)
        {
            try
            {
                var item = await GetItemAsync<SyncQueueItem>("SyncQueue", id);
                return (item != null, item);
            }
            catch
            {
                return (false, null);
            }
        }

        // Bulk Insert
        public async Task SetItemsAsync<T>(string storeName, Dictionary<string, T> items)
        {
            var json = JsonSerializer.Serialize(items);
            await _js.InvokeVoidAsync("indexedDbInterop.setItems", _dbName, storeName, json);
        }

        // Get All with migration fallback
        public async Task<List<T>> GetAllAsync<T>(string storeName)
        {
            var json = await _js.InvokeAsync<string>("indexedDbInterop.getAll", _dbName, storeName);

            if (string.IsNullOrWhiteSpace(json))
                return new List<T>();

            try
            {
                return JsonSerializer.Deserialize<List<T>>(json)!;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[OfflineSync] Failed to deserialize store '{storeName}': {ex.Message}");

                // Migrate corrupted data to diagnostic store
                await MigrateCorruptItemToErrorQueue(storeName, json, ex.Message);
                return new List<T>();
            }
        }

        // Delete Item
        public async Task DeleteItemAsync(string storeName, string key)
        {
            await _js.InvokeVoidAsync("indexedDbInterop.deleteItem", _dbName, storeName, key);
            await NotifySyncQueueChanged();
        }

        // Enqueue to SyncQueue
        public async Task EnqueueSyncCommandAsync(string endpoint, string payload, string method)
        {
            var syncItem = new SyncQueueItem
            {
                Id = Guid.NewGuid().ToString(),
                Endpoint = endpoint,
                Payload = payload,
                Method = method,
                Timestamp = DateTime.UtcNow,
                SchemaVersion = SyncQueueItem.CurrentSchemaVersion
            };

            await SetItemAsync("SyncQueue", syncItem.Id, syncItem);
            Console.WriteLine($"[ENQUEUE] Item added to SyncQueue: {syncItem.Endpoint}");

            await NotifySyncQueueChanged();
        }

        // Check schema version compatibility
        public async Task<List<SyncQueueItem>> VersionedSchemaCheckAsync()
        {
            var items = await GetAllAsync<SyncQueueItem>("SyncQueue");
            var invalids = new List<SyncQueueItem>();

            foreach (var item in items)
            {
                if (item.SchemaVersion != SyncQueueItem.CurrentSchemaVersion)
                {
                    Console.WriteLine($"[OfflineSync] Schema mismatch: ID={item.Id}, Version={item.SchemaVersion}");
                    invalids.Add(item);
                    await MigrateCorruptItemToErrorQueue(item.Id, JsonSerializer.Serialize(item), "Schema mismatch");
                    await DeleteItemAsync("SyncQueue", item.Id);
                }
            }

            return items.Except(invalids).ToList();
        }

        public async Task<T?> TryGetItemAsync<T>(string storeName, string key)
        {
            try
            {
                return await GetItemAsync<T>(storeName, key);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"[OfflineSync] TryGet failed: {ex.Message}");
                return default;
            }
        }

        public async Task<List<SyncQueueItem>> GetSyncQueueAsync()
        {
            return await GetAllAsync<SyncQueueItem>("SyncQueue");
        }

        public async Task ClearSyncQueueAsync()
        {
            var queue = await GetSyncQueueAsync();
            foreach (var item in queue)
                await DeleteItemAsync("SyncQueue", item.Id);
        }

        private async Task NotifySyncQueueChanged()
        {
            try
            {
                if (_hubConnection.State == HubConnectionState.Connected)
                {
                    await _hubConnection.InvokeAsync("NotifySyncQueueUpdated", _userService.Email);
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"SignalR notification failed: {ex.Message}");
            }
        }

        // Save corrupt entries for debugging
        private async Task MigrateCorruptItemToErrorQueue(string storeName, string rawJson, string errorMessage)
        {
            var fallback = new SyncQueueErrorItem
            {
                Id = Guid.NewGuid().ToString(),
                StoreName = storeName,
                RawJson = rawJson,
                Error = errorMessage,
                Timestamp = DateTime.UtcNow
            };
            await SetItemAsync("ErrorQueue", fallback.Id, fallback);
        }
    }

    public class SyncQueueItem
    {
        public static readonly int CurrentSchemaVersion = 1;

        public string Id { get; set; } = default!;
        public string Endpoint { get; set; } = default!;
        public string Payload { get; set; } = default!;
        public string Method { get; set; } = default!;
        public DateTime Timestamp { get; set; }

        public int SchemaVersion { get; set; } = CurrentSchemaVersion;
    }

    public class SyncQueueErrorItem
    {
        public string Id { get; set; } = default!;
        public string StoreName { get; set; } = default!;
        public string RawJson { get; set; } = default!;
        public string Error { get; set; } = default!;
        public DateTime Timestamp { get; set; }
    }
}