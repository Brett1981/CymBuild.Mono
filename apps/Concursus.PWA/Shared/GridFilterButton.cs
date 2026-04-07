using Microsoft.AspNetCore.Components;
using System.Dynamic;
using Telerik.Blazor;
using Telerik.Blazor.Components;
using Telerik.DataSource;

namespace Concursus.PWA.Shared
{
    public partial class GridFilterButton
    {
        public List<API.Client.MenuItem>? MenuItems { get; set; }
        private string btnTxt = "Filters";
        public TelerikNotification notificationRef { get; set; }

        [Parameter] public TelerikGrid<ExpandoObject>? GridRef { get; set; }

        private const string ClearBtnTitle = "All Grids [Clear Filters]";

        protected async void OnClickHandler(API.Client.MenuItem item)
        {
            if (item.Text == ClearBtnTitle)
            {
                try
                {
                    //Clear for all grids using JS.
                    await LocalStorageAccessor.ClearAllGridFilters();

                    //Next, get the state for the current grid & force remove filters (only has to be done for currently viewed grid)
                    var gridState = GridRef!.GetState();

                    gridState.FilterDescriptors = new List<IFilterDescriptor>();
                    gridState.SearchFilter = default;
                    await GridRef.SetStateAsync(gridState);

                    StateHasChanged();

                    //Show notification that all filters are cleared.
                    notificationRef.Show(new NotificationModel()
                    {
                        Text = "Clear filters for all grids",
                        Closable = true,
                        CloseAfter = 2000,
                        ThemeColor = ThemeConstants.Notification.ThemeColor.Success
                    });
                }
                catch (Exception ex)
                {
                    Console.WriteLine(ex);
                }
            }
        }

        protected override Task OnParametersSetAsync()
        {
            InitializeButton();
            return base.OnParametersSetAsync();
        }

        //CBLD-416: Seperated function so we can call on its own.
        public async Task InitializeButton()
        {
            MenuItems = new List<API.Client.MenuItem>
            {
                new()
                {
                    Text = btnTxt, // items that don't have a URL will not render links
                    Items = new List<API.Client.MenuItem>
                    {
                        new()
                        {
                            Text = ClearBtnTitle
                        }
                    }
                }
            };

            StateHasChanged();
        }
    }
}