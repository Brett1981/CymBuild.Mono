using Concursus.API.Components;
using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;
using Microsoft.Graph;
using Microsoft.Graph.Models;

namespace Concursus.API.Classes;

public class SchedulerHelper : MSGraphBase
{
    #region Private Fields

    private readonly GraphServiceClient _graphClient;

    #endregion Private Fields

    #region Public Constructors

    public SchedulerHelper(IConfiguration config) : base(config)
    {
        _graphClient = _graphServiceClient;
    }

    #endregion Public Constructors

    #region Public Methods

    public async Task<string> CreateScheduleItemAsync(DataObject dataObject, System.Security.Principal.IIdentity identity)
    {
        // Retrieve relevant data properties
        var subjectProperty = GetDataProperty(dataObject, "6a74e48e-cfad-4b6f-836f-11b205d5bce0");
        var startProperty = GetDataProperty(dataObject, "529fdf9c-df21-4562-8592-97f03df5764c");
        var endProperty = GetDataProperty(dataObject, "60d5c39a-a404-4269-949b-f8235f0391e8");

        try
        {
            // Create a new event
            var newEvent = new Event
            {
                Subject = subjectProperty?.Value.Unpack<StringValue>().Value ?? "",
                Body = new ItemBody { ContentType = BodyType.Html, Content = "" }, // Set your desired content here
                Start = Functions.DateTimeTimeZoneFromTimestamp(startProperty?.Value.Unpack<Timestamp>()),
                End = Functions.DateTimeTimeZoneFromTimestamp(endProperty?.Value.Unpack<Timestamp>())
            };

            // Add the event to the user's calendar with immutable ID preference
            if (!string.IsNullOrEmpty(identity?.Name))
            {
                var calendarEvent = await Functions.AddEventToCalendarAsync(newEvent, identity.Name, _graphClient).ConfigureAwait(false);
                return calendarEvent.Id ?? "";
            }
        }
        catch (Exception ex)
        {
            return ex.Message;
        }

        return "";
    }

    public async Task<string> DeleteScheduleItemAsync(Core.ScheduleItem scheduleItem,
        System.Security.Principal.IIdentity identity)
    {
        try
        {
            await _graphClient.Users[identity.Name].Calendar.Events[scheduleItem.Id.ToString()].DeleteAsync();
            return "Success";
        }
        catch (Exception ex)
        {
            return ex.Message;
        }
    }

    public async Task<Event?> GetScheduleItemAsync(Core.ScheduleItem scheduleItem, System.Security.Principal.IIdentity identity)
    {
        try
        {
            var selectProperties = new[]
            {
                "subject", "body", "bodyPreview", "organizer", "attendees", "start", "end", "location",
                "hideAttendees", "id"
            };

            var result = await _graphClient.Users[identity.Name].Calendar.Events[scheduleItem.Id.ToString()].GetAsync(
                requestConfiguration =>
                {
                    requestConfiguration.QueryParameters.Select = selectProperties;
                    requestConfiguration.Headers.Add("Prefer", "outlook.timezone=\"UTC\"");
                });

            return result;
        }
        catch
        {
            return null;
        }
    }

    public async Task<Event?> UpdateScheduleItemAsync(Core.ScheduleItem scheduleItem,
        System.Security.Principal.IIdentity identity)
    {
        try
        {
            var requestBody = new Event
            {
                Subject = scheduleItem.Title,
                Body = new ItemBody
                {
                    ContentType = BodyType.Html,
                    Content = scheduleItem.Description
                },
                Start = new DateTimeTimeZone
                {
                    DateTime = DateTime.SpecifyKind(scheduleItem.Start.ToDateTime(), DateTimeKind.Utc).ToString("yyyy-MM-ddTHH:mm:ss"),
                },
                End = new DateTimeTimeZone
                {
                    DateTime = DateTime.SpecifyKind(scheduleItem.End.ToDateTime(), DateTimeKind.Utc).ToString("yyyy-MM-ddTHH:mm:ss"),
                    TimeZone = "UTC"
                }
            };
            return await _graphClient.Users[identity.Name].Calendar.Events[scheduleItem.Id.ToString()]
                .PatchAsync(requestBody);
        }
        catch
        {
            return null;
        }
    }

    #endregion Public Methods

    #region Private Methods

    private static DataProperty? GetDataProperty(DataObject dataObject, string entityPropertyGuid)
    {
        return dataObject.DataProperties.FirstOrDefault(p => p.EntityPropertyGuid == Functions.ParseAndReturnEmptyGuidIfInvalid(entityPropertyGuid).ToString());
    }

    #endregion Private Methods
}