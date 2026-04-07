using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class OutlookEmailsSysReadyToFileService
    {
        private readonly HttpClient _httpClient;

        public OutlookEmailsSysReadyToFileService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<IEnumerable<OutlookEmailSysReadyToFile>> GetEmailsSysReadyToFileAsync()
        {
            return await _httpClient.GetFromJsonAsync<IEnumerable<OutlookEmailSysReadyToFile>>("api/OutlookEmailsSysReadyToFile");
        }

        public async Task<OutlookEmailSysReadyToFile> GetEmailSysReadyToFileAsync(long id)
        {
            return await _httpClient.GetFromJsonAsync<OutlookEmailSysReadyToFile>($"api/OutlookEmailsSysReadyToFile/{id}");
        }
    }
}