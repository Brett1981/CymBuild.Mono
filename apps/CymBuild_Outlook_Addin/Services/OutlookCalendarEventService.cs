using CymBuild_Outlook_Common.Dto;
using System.Net.Http.Json;

namespace CymBuild_Outlook_Addin.Services
{
    public class OutlookCalendarEventService
    {
        private readonly HttpClient _httpClient;

        public OutlookCalendarEventService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<IEnumerable<OutlookCalendarEvent>> GetCalendarEventsAsync()
        {
            return await _httpClient.GetFromJsonAsync<IEnumerable<OutlookCalendarEvent>>("api/OutlookCalendarEvent");
        }

        public async Task<OutlookCalendarEvent> GetCalendarEventAsync(long id)
        {
            return await _httpClient.GetFromJsonAsync<OutlookCalendarEvent>($"api/OutlookCalendarEvent/{id}");
        }

        public async Task<bool> UpdateCalendarEventAsync(long id, OutlookCalendarEvent calendarEvent)
        {
            var response = await _httpClient.PutAsJsonAsync($"api/OutlookCalendarEvent/{id}", calendarEvent);
            return response.IsSuccessStatusCode;
        }

        public async Task<OutlookCalendarEvent> CreateCalendarEventAsync(OutlookCalendarEvent calendarEvent)
        {
            var response = await _httpClient.PostAsJsonAsync("api/OutlookCalendarEvent/Create", calendarEvent);
            if (response.IsSuccessStatusCode)
            {
                return await response.Content.ReadFromJsonAsync<OutlookCalendarEvent>();
            }
            else
            {
                return null;
            }
        }

        public async Task<bool> UpsertCalendarEventAsync(CalendarEventUpsertDto upsertDto)
        {
            var response = await _httpClient.PostAsJsonAsync("api/OutlookCalendarEvent/Upsert", upsertDto);
            return response.IsSuccessStatusCode;
        }

        public async Task<bool> DeleteCalendarEventAsync(long id)
        {
            var response = await _httpClient.DeleteAsync($"api/OutlookCalendarEvent/{id}");
            return response.IsSuccessStatusCode;
        }
    }
}