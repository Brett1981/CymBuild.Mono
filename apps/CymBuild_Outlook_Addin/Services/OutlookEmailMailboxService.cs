using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class OutlookEmailMailboxService
    {
        private readonly HttpClient _httpClient;

        public OutlookEmailMailboxService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<IEnumerable<OutlookEmailMailbox>> GetEmailMailboxesAsync()
        {
            return await _httpClient.GetFromJsonAsync<IEnumerable<OutlookEmailMailbox>>("api/OutlookEmailMailbox");
        }

        public async Task<OutlookEmailMailbox> GetEmailMailboxAsync(int id)
        {
            return await _httpClient.GetFromJsonAsync<OutlookEmailMailbox>($"api/OutlookEmailMailbox/{id}");
        }

        public async Task<bool> UpdateEmailMailboxAsync(int id, OutlookEmailMailbox emailMailbox)
        {
            var response = await _httpClient.PutAsJsonAsync($"api/OutlookEmailMailbox/{id}", emailMailbox);
            return response.IsSuccessStatusCode;
        }

        public async Task<OutlookEmailMailbox> CreateEmailMailboxAsync(OutlookEmailMailbox emailMailbox)
        {
            // delay the process by 1 second to help stop the following error: "The send or update
            // operation could not be performed because the change key passed in the request does
            // not match the current change key for the item"
            await Task.Delay(1000);
            var response = await _httpClient.PostAsJsonAsync("api/OutlookEmailMailbox", emailMailbox);
            if (response.IsSuccessStatusCode)
            {
                return await response.Content.ReadFromJsonAsync<OutlookEmailMailbox>();
            }
            else
            {
                return null;
            }
        }

        public async Task<bool> DeleteEmailMailboxAsync(int id)
        {
            var response = await _httpClient.DeleteAsync($"api/OutlookEmailMailbox/{id}");
            return response.IsSuccessStatusCode;
        }
    }
}