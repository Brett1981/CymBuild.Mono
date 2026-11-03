using CymBuild_Outlook_Common.Models;
using System.Net.Http.Headers;
using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class FrequentFilingRecordsService
    {
        private readonly HttpClient _httpClient;

        public FrequentFilingRecordsService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<List<FrequentFilingRecordResult>> GetFrequentRecordsAsync(string apiToken, string? correlationId = null)
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, "api/FrequentFilingRecords");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiToken);

            if (!string.IsNullOrWhiteSpace(correlationId))
                request.Headers.TryAddWithoutValidation("X-Correlation-Id", correlationId);

            using var response = await _httpClient.SendAsync(request);
            response.EnsureSuccessStatusCode();

            return await response.Content.ReadFromJsonAsync<List<FrequentFilingRecordResult>>()
                ?? new List<FrequentFilingRecordResult>();
        }
    }
}
