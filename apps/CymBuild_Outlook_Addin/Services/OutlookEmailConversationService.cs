using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class OutlookEmailConversationService
    {
        private readonly HttpClient _httpClient;

        public OutlookEmailConversationService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<IEnumerable<OutlookEmailConversation>> GetEmailConversationsAsync()
        {
            return await _httpClient.GetFromJsonAsync<IEnumerable<OutlookEmailConversation>>("api/OutlookEmailConversation");
        }

        public async Task<OutlookEmailConversation> GetEmailConversationAsync(long id)
        {
            return await _httpClient.GetFromJsonAsync<OutlookEmailConversation>($"api/OutlookEmailConversation/{id}");
        }

        public async Task<bool> UpdateEmailConversationAsync(long id, OutlookEmailConversation emailConversation)
        {
            var response = await _httpClient.PutAsJsonAsync($"api/OutlookEmailConversation/{id}", emailConversation);
            return response.IsSuccessStatusCode;
        }

        public async Task<OutlookEmailConversation> CreateEmailConversationAsync(OutlookEmailConversation emailConversation)
        {
            // delay the process by 1 second to help stop the following error: "The send or update
            // operation could not be performed because the change key passed in the request does
            // not match the current change key for the item"
            await Task.Delay(1000);
            var response = await _httpClient.PostAsJsonAsync("api/OutlookEmailConversation", emailConversation);
            if (response.IsSuccessStatusCode)
            {
                return await response.Content.ReadFromJsonAsync<OutlookEmailConversation>();
            }
            else
            {
                return null;
            }
        }

        public async Task<bool> DeleteEmailConversationAsync(long id)
        {
            var response = await _httpClient.DeleteAsync($"api/OutlookEmailConversation/{id}");
            return response.IsSuccessStatusCode;
        }
    }
}