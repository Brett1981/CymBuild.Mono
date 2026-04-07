using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class PreferenceService
    {
        private readonly HttpClient _httpClient;

        public PreferenceService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<IEnumerable<Preference>> GetPreferencesAsync()
        {
            return await _httpClient.GetFromJsonAsync<IEnumerable<Preference>>("api/Preference");
        }

        public async Task<Preference> GetPreferenceAsync(int id)
        {
            return await _httpClient.GetFromJsonAsync<Preference>($"api/Preference/{id}");
        }

        public async Task<bool> UpdatePreferenceAsync(int id, Preference preference)
        {
            var response = await _httpClient.PutAsJsonAsync($"api/Preference/{id}", preference);
            return response.IsSuccessStatusCode;
        }

        public async Task<Preference> CreatePreferenceAsync(Preference preference)
        {
            var response = await _httpClient.PostAsJsonAsync("api/Preference", preference);
            if (response.IsSuccessStatusCode)
            {
                return await response.Content.ReadFromJsonAsync<Preference>();
            }
            else
            {
                return null;
            }
        }

        public async Task<bool> DeletePreferenceAsync(int id)
        {
            var response = await _httpClient.DeleteAsync($"api/Preference/{id}");
            return response.IsSuccessStatusCode;
        }
    }
}