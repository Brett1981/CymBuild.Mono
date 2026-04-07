using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class OutlookEmailFromAddressService
    {
        private readonly HttpClient _httpClient;

        public OutlookEmailFromAddressService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<IEnumerable<OutlookEmailFromAddress>> GetEmailFromAddressesAsync()
        {
            return await _httpClient.GetFromJsonAsync<IEnumerable<OutlookEmailFromAddress>>("api/OutlookEmailFromAddress");
        }

        public async Task<OutlookEmailFromAddress> GetEmailFromAddressAsync(int id)
        {
            return await _httpClient.GetFromJsonAsync<OutlookEmailFromAddress>($"api/OutlookEmailFromAddress/{id}");
        }

        public async Task<bool> UpdateEmailFromAddressAsync(int id, OutlookEmailFromAddress emailFromAddress)
        {
            var response = await _httpClient.PutAsJsonAsync($"api/OutlookEmailFromAddress/{id}", emailFromAddress);
            return response.IsSuccessStatusCode;
        }

        public async Task<OutlookEmailFromAddress> CreateEmailFromAddressAsync(OutlookEmailFromAddress emailFromAddress)
        {
            // delay the process by 1 second to help stop the following error: "The send or update
            // operation could not be performed because the change key passed in the request does
            // not match the current change key for the item"
            await Task.Delay(1000);
            var response = await _httpClient.PostAsJsonAsync("api/OutlookEmailFromAddress", emailFromAddress);
            if (response.IsSuccessStatusCode)
            {
                return await response.Content.ReadFromJsonAsync<OutlookEmailFromAddress>();
            }
            else
            {
                return null;
            }
        }

        public async Task<bool> DeleteEmailFromAddressAsync(int id)
        {
            var response = await _httpClient.DeleteAsync($"api/OutlookEmailFromAddress/{id}");
            return response.IsSuccessStatusCode;
        }
    }
}