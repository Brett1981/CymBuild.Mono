using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class RowStatusService
    {
        private readonly HttpClient _http;

        public RowStatusService(HttpClient http)
        {
            _http = http;
        }

        // Fetch all RowStatus entries
        public async Task<IEnumerable<RowStatus>> GetRowStatusesAsync()
        {
            return await _http.GetFromJsonAsync<IEnumerable<RowStatus>>("api/RowStatus");
        }

        // Fetch a single RowStatus by ID
        public async Task<RowStatus> GetRowStatusAsync(byte id)
        {
            return await _http.GetFromJsonAsync<RowStatus>($"api/RowStatus/{id}");
        }

        // Update a RowStatus
        public async Task<bool> UpdateRowStatusAsync(byte id, RowStatus rowStatus)
        {
            var response = await _http.PutAsJsonAsync($"api/RowStatus/{id}", rowStatus);
            return response.IsSuccessStatusCode;
        }

        // Create a new RowStatus
        public async Task<RowStatus> CreateRowStatusAsync(RowStatus rowStatus)
        {
            var response = await _http.PostAsJsonAsync("api/RowStatus", rowStatus);
            if (response.IsSuccessStatusCode)
            {
                return await response.Content.ReadFromJsonAsync<RowStatus>();
            }
            else
            {
                return null;
            }
        }

        // Delete a RowStatus
        public async Task<bool> DeleteRowStatusAsync(byte id)
        {
            var response = await _http.DeleteAsync($"api/RowStatus/{id}");
            return response.IsSuccessStatusCode;
        }
    }
}