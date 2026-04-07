using CymBuild_Outlook_Common.Dto;
using CymBuild_Outlook_Common.Models;
using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class RecordSearchService
    {
        private readonly HttpClient _httpClient;

        public RecordSearchService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<List<RecordSearchResult>> SearchRecordsAsync(RecordSearchDto searchDto)
        {
            // Construct the query string from the DTO
            var query = $"?userId={searchDto.UserId}&searchString={searchDto.SearchString}&entityTypeGuid={searchDto.EntityTypeGuid}&toAddressesCSV={searchDto.ToAddressesCSV}&fromAddress={searchDto.FromAddress}&subject={searchDto.Subject}";
            var response = await _httpClient.GetFromJsonAsync<List<RecordSearchResult>>($"api/RecordSearch{query}");

            return response ?? new List<RecordSearchResult>();
        }
    }
}