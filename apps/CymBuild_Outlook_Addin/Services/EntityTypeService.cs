using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class EntityTypeService
    {
        private readonly HttpClient _httpClient;

        public EntityTypeService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<IEnumerable<EntityType>> GetEntityTypesAsync()
        {
            // Any HTTP/CORS failure will throw here; caller (Index.razor.cs) already wraps in try/catch.
            return await _httpClient.GetFromJsonAsync<IEnumerable<EntityType>>("api/EntityType")
                   ?? Array.Empty<EntityType>();
        }

        public async Task<EntityType?> GetEntityTypeAsync(int id)
        {
            return await _httpClient.GetFromJsonAsync<EntityType>($"api/EntityType/{id}");
        }

        public async Task<bool> UpdateEntityTypeAsync(int id, EntityType entityType)
        {
            var response = await _httpClient.PutAsJsonAsync($"api/EntityType/{id}", entityType);
            return response.IsSuccessStatusCode;
        }

        public async Task<EntityType?> CreateEntityTypeAsync(EntityType entityType)
        {
            var response = await _httpClient.PostAsJsonAsync("api/EntityType", entityType);
            if (response.IsSuccessStatusCode)
            {
                return await response.Content.ReadFromJsonAsync<EntityType>();
            }

            return null;
        }

        public async Task<bool> DeleteEntityTypeAsync(int id)
        {
            var response = await _httpClient.DeleteAsync($"api/EntityType/{id}");
            return response.IsSuccessStatusCode;
        }
    }
}