using CymBuild_Outlook_Common.Models;
using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class SuggestedFilingLocationsService
    {
        private readonly HttpClient _httpClient;

        public SuggestedFilingLocationsService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<List<SuggestedFilingLocationResult>> GetSuggestionsAsync(long targetObjectId, int entityTypeId)
        {
            return await _httpClient.GetFromJsonAsync<List<SuggestedFilingLocationResult>>(
                $"api/SuggestedFilingLocations?targetObjectId={targetObjectId}&entityTypeId={entityTypeId}")
                ?? new List<SuggestedFilingLocationResult>();
        }
    }
}
