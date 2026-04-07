using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class OutlookEmailsSysNotFiledService
    {
        private readonly HttpClient _httpClient;

        public OutlookEmailsSysNotFiledService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<IEnumerable<OutlookEmailSysNotFiled>> GetEmailsSysNotFiledAsync()
        {
            return await _httpClient.GetFromJsonAsync<IEnumerable<OutlookEmailSysNotFiled>>("api/OutlookEmailsSysNotFiled");
        }

        public async Task<OutlookEmailSysNotFiled> GetEmailSysNotFiledAsync(long id)
        {
            return await _httpClient.GetFromJsonAsync<OutlookEmailSysNotFiled>($"api/OutlookEmailsSysNotFiled/{id}");
        }
    }
}