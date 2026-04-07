using CymBuild_Outlook_Common.Models;
using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class MessageService
    {
        private readonly HttpClient _httpClient;

        public MessageService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<IEnumerable<Message>> GetMessagesAsync()
        {
            return await _httpClient.GetFromJsonAsync<IEnumerable<Message>>("api/Message");
        }

        public async Task<Message> GetMessageAsync(int id)
        {
            return await _httpClient.GetFromJsonAsync<Message>($"api/Message/{id}");
        }

        public async Task<Message> CreateMessageAsync(Message message)
        {
            // delay the process by 1 second to help stop the following error: "The send or update
            // operation could not be performed because the change key passed in the request does
            // not match the current change key for the item"
            await Task.Delay(1000);
            var response = await _httpClient.PostAsJsonAsync("api/Message", message);
            if (response.IsSuccessStatusCode)
            {
                return await response.Content.ReadFromJsonAsync<Message>();
            }
            else
            {
                return null;
            }
        }

        public async Task<bool> UpdateMessageAsync(int id, Message message)
        {
            var response = await _httpClient.PutAsJsonAsync($"api/Message/{id}", message);
            return response.IsSuccessStatusCode;
        }

        public async Task<bool> DeleteMessageAsync(int id)
        {
            var response = await _httpClient.DeleteAsync($"api/Message/{id}");
            return response.IsSuccessStatusCode;
        }
    }
}