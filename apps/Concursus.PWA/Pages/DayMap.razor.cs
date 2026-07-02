using Concursus.API.Client;
using Concursus.API.Core;
using Concursus.PWA.Shared;
using Microsoft.AspNetCore.Components;
using System.Globalization;

namespace Concursus.PWA.Pages;

public partial class DayMap
{
    private Geodata geoData = new();

    private DateTime Max = new(2050, 12, 31);

    private DateTime Min = new(1950, 1, 1);

    private List<OrganisationalUnit> OrganisationalUnits = new();

    private List<string> SelectedOrganisationalUnitsIds = new();

    private List<string> SelectedUserIds = new();

    private List<User> Users = new();

    [Parameter] public string date { get; set; }

    public string MapAttribution { get; set; } =
        "&copy; <a href='https://osm.org/copyright'>OpenStreetMap contributors</a>";

    public string[] MapSubdomains { get; set; } = new[] { "a", "b", "c" };

    public string MapUrlTemplate { get; set; } =
        "https://#= subdomain #.tile.openstreetmap.org/#= zoom #/#= x #/#= y #.png";

    [Parameter] public EventCallback<Exception> OnError { get; set; }

    private int DebounceDelay { get; set; } = 100;
    private double[] MapCenter { get; set; } = new[] { 53.676375, -2.984684 };
    private List<MapMarker> MarkerData { get; set; } = new();

    private DateTime? SelectedDate { get; set; }

    private string SelectedDateValue => (SelectedDate ?? DateTime.Today).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    private string MapEmbedUrl
    {
        get
        {
            var latitude = MapCenter.Length > 0 ? MapCenter[0] : 53.676375;
            var longitude = MapCenter.Length > 1 ? MapCenter[1] : -2.984684;
            var delta = 0.08;
            var left = longitude - delta;
            var right = longitude + delta;
            var bottom = latitude - delta;
            var top = latitude + delta;

            return FormattableString.Invariant($"https://www.openstreetmap.org/export/embed.html?bbox={left}%2C{bottom}%2C{right}%2C{top}&layer=mapnik&marker={latitude}%2C{longitude}");
        }
    }

    protected override async Task OnInitializedAsync()
    {
        try
        {
            SelectedDate = DateTime.FromBinary(long.Parse(date, CultureInfo.InvariantCulture));

            var organisationalUnitsGetResponse =
                await coreClient.OrganisationalUnitsGetAsync(new OrganisationalUnitsGetRequest());
            OrganisationalUnits = organisationalUnitsGetResponse.OrganisationalUnits.ToList();

            var usersGetResponse = await coreClient.UsersGetAsync(new UsersGetRequest());
            if (!string.IsNullOrEmpty(usersGetResponse.ErrorReturned))
            { throw new Exception(usersGetResponse.ErrorReturned); }
            Users = usersGetResponse.Users.ToList();

            await LoadData();

            await base.OnInitializedAsync();
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error occurred while initializing DayMap.razor.");
            ex.Data.Add("PageMethod", "DayMap/OnInitializedAsync()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    private async Task OnSelectedDateChangedAsync(ChangeEventArgs args)
    {
        if (DateTime.TryParse(args.Value?.ToString(), CultureInfo.CurrentCulture, DateTimeStyles.AssumeLocal, out var selectedDate))
        {
            SelectedDate = selectedDate.Date;
            await LoadData();
        }
    }

    private async Task OnUsersChangedAsync(ChangeEventArgs args)
    {
        SelectedUserIds = ExtractSelectedStringValues(args.Value);
        await LoadData();
    }

    private async Task OnOrganisationalUnitsChangedAsync(ChangeEventArgs args)
    {
        SelectedOrganisationalUnitsIds = ExtractSelectedStringValues(args.Value);
        await LoadData();
    }

    private bool IsSelectedUser(string userGuid)
    {
        return SelectedUserIds.Contains(userGuid);
    }

    private bool IsSelectedOrganisationalUnit(string organisationalUnitGuid)
    {
        return SelectedOrganisationalUnitsIds.Contains(organisationalUnitGuid);
    }

    private static List<string> ExtractSelectedStringValues(object? value)
    {
        return value switch
        {
            string[] selectedValues => selectedValues.Where(v => !string.IsNullOrWhiteSpace(v)).ToList(),
            IEnumerable<string> selectedValues => selectedValues.Where(v => !string.IsNullOrWhiteSpace(v)).ToList(),
            string selectedValue when !string.IsNullOrWhiteSpace(selectedValue) => new List<string> { selectedValue },
            _ => new List<string>()
        };
    }

    private static string FormatMarkerLocation(MapMarker marker)
    {
        return marker.LatLng.Count >= 2
            ? FormattableString.Invariant($"{marker.LatLng[0]:0.000000}, {marker.LatLng[1]:0.000000}")
            : "No latitude / longitude supplied";
    }

    private async Task LoadData()
    {
        await Task.CompletedTask;
    }
}
