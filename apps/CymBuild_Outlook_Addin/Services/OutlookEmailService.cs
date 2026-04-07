using CymBuild_Outlook_Common.Dto;
using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class OutlookEmailService
    {
        private readonly HttpClient _httpClient;

        public OutlookEmailService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<IEnumerable<OutlookEmail>> GetEmailsAsync()
        {
            return await _httpClient.GetFromJsonAsync<IEnumerable<OutlookEmail>>("api/OutlookEmail");
        }

        public async Task<OutlookEmail> GetOutlookEmailAsync(long id)
        {
            return await _httpClient.GetFromJsonAsync<OutlookEmail>($"api/OutlookEmail/{id}");
        }

        public async Task<bool> UpdateOutlookEmailAsync(long id, OutlookEmail outlookEmail)
        {
            var response = await _httpClient.PutAsJsonAsync($"api/OutlookEmail/{id}", outlookEmail);
            return response.IsSuccessStatusCode;
        }

        public async Task<OutlookEmail> CreateOutlookEmailAsync(OutlookEmail outlookEmail)
        {
            // delay the process by 1 second to help stop the following error: "The send or update
            // operation could not be performed because the change key passed in the request does
            // not match the current change key for the item"
            await Task.Delay(1000);
            var response = await _httpClient.PostAsJsonAsync("api/OutlookEmail", outlookEmail);
            if (response.IsSuccessStatusCode)
            {
                return await response.Content.ReadFromJsonAsync<OutlookEmail>();
            }
            else
            {
                return null;
            }
        }

        public async Task<bool> DeleteOutlookEmailAsync(long id)
        {
            var response = await _httpClient.DeleteAsync($"api/OutlookEmail/{id}");
            return response.IsSuccessStatusCode;
        }

        public async Task<bool> SysProcessingUpdateAsync(EmailSysProcessingUpdateDto updateDto)
        {
            // delay the process by 1 second to help stop the following error: "The send or update
            // operation could not be performed because the change key passed in the request does
            // not match the current change key for the item"
            await Task.Delay(1000);
            var response = await _httpClient.PostAsJsonAsync("api/OutlookEmail/SysProcessingUpdate", updateDto);
            return response.IsSuccessStatusCode;
        }

        public async Task<bool> UpsertEmailAsync(EmailUpsertDto upsertDto)
        {
            // delay the process by 1 second to help stop the following error: "The send or update
            // operation could not be performed because the change key passed in the request does
            // not match the current change key for the item"
            await Task.Delay(1000);
            var response = await _httpClient.PostAsJsonAsync("api/OutlookEmail/Upsert", upsertDto);
            return response.IsSuccessStatusCode;
        }
    }
}