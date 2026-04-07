using Concursus.API.Client;
using Concursus.API.Core;
using Concursus.PWA.Shared;
using Microsoft.AspNetCore.Components;
using Telerik.Blazor.Components;

namespace Concursus.PWA.Pages;

public partial class DayMap
{
    private Geodata geoData = new();

    private DateTime Max = new(2050, 12, 31);

    private DateTime Min = new(1950, 1, 1);

    private List<OrganisationalUnit> OrganisationalUnits = new();

    private List<int> SelectedOrganisationalUnitsIds = new();

    private List<int> SelectedUserIds = new();

    private List<User> Users = new();

    [Parameter] public string date { get; set; }

    public string MapAttribution { get; set; } =
        "&copy; <a href='https://osm.org/copyright'>OpenStreetMap contributors</a>";

    public string[] MapSubdomains { get; set; } = new string[] { "a", "b", "c" };

    public string MapUrlTemplate { get; set; } =
        "https://#= subdomain #.tile.openstreetmap.org/#= zoom #/#= x #/#= y #.png";

    [Parameter] public EventCallback<Exception> OnError { get; set; }

    private int DebounceDelay { get; set; } = 100;
    private double[] MapCenter { get; set; } = new double[] { 53.676375, -2.984684 };
    private TelerikMap MapRef { get; set; }
    private List<MapMarker> MarkerData { get; set; } = new();

    private DateTime? SelectedDate { get; set; }

    protected override async Task OnInitializedAsync()
    {
        try
        {
            SelectedDate = DateTime.FromBinary(long.Parse(date));

            var organisationalUnitsGetResponse =
                await coreClient.OrganisationalUnitsGetAsync(new OrganisationalUnitsGetRequest());
            OrganisationalUnits = organisationalUnitsGetResponse.OrganisationalUnits.ToList();

            var usersGetResponse = await coreClient.UsersGetAsync(new UsersGetRequest());
            if (!string.IsNullOrEmpty(usersGetResponse.ErrorReturned))
            { throw new Exception(usersGetResponse.ErrorReturned); }
            Users = usersGetResponse.Users.ToList();

            await LoadData();

            await base.OnInitializedAsync();

            return;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "Error occurred while initializing DayMap.razor.");
            ex.Data.Add("PageMethod", "DayMap/OnInitializedAsync()");
            _ = OnError.InvokeAsync(ex);
        }
    }

    private async Task LoadData()
    {
    }
}