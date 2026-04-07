using CymBuild_Outlook_Common.Dto;
using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class TargetObjectService
    {
        private readonly HttpClient _http;

        public TargetObjectService(HttpClient httpClient)
        {
            _http = httpClient;
        }

        public async Task<List<TargetObject>> GetTargetObjectsAsync()
        {
            return await _http.GetFromJsonAsync<List<TargetObject>>("api/TargetObject");
        }

        public async Task<TargetObject> GetTargetObjectAsync(Guid? id)
        {
            return await _http.GetFromJsonAsync<TargetObject>($"api/TargetObject/{id}");
        }

        public async Task<bool> UpdateTargetObjectAsync(long? id, TargetObject targetObject)
        {
            var response = await _http.PutAsJsonAsync($"api/TargetObject/{id}", targetObject);
            return response.IsSuccessStatusCode;
        }

        public async Task<TargetObject> CreateTargetObjectAsync(TargetObject targetObject)
        {
            var response = await _http.PostAsJsonAsync("api/TargetObject", targetObject);
            return await response.Content.ReadFromJsonAsync<TargetObject>();
        }

        public async Task<bool> UpsertTargetObjectAsync(TargetObjectUpsertDto upsertDto)
        {
            var response = await _http.PostAsJsonAsync("api/TargetObject/Upsert", upsertDto);
            return response.IsSuccessStatusCode;
        }

        public async Task<bool> DeleteTargetObjectAsync(long id)
        {
            var response = await _http.DeleteAsync($"api/TargetObject/{id}");
            return response.IsSuccessStatusCode;
        }
    }
}