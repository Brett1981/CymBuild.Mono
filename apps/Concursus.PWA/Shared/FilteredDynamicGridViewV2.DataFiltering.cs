using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using System.Dynamic;
using Telerik.DataSource;

namespace Concursus.PWA.Shared
{
    public partial class FilteredDynamicGridViewV2 : ComponentBase
    {
        //Shows the custom range section
        private bool showCustomRange { get; set; } = false;

        //Custom start date
        private DateOnly? customStartDate { get; set; }

        //Custom end date
        private DateOnly? customEndDate { get; set; }

        //FilteredList Variables
        private string CreatedOnColumn { get; set; } = "";
        private string GroupBy { get; set; } = "";

        //==============================================
        //=             QUICK FILTERS                  =
        //==============================================
        private int? ActiveQuickFilterDays = null;

        private bool QuickFilterActive { get; set; } = false;
        private string QuickFilter7DaysCSS { get; set; } = "";
        private string QuickFilter90DaysCSS { get; set; } = "";
        private string QuickFilterGroupByCSS { get; set; } = "";

        private DataCompositeFilter QuickFilters { get; set; }

        //==============================================
        //=             RANGE FILTERS                  =
        //==============================================
        private bool RangeFiltersActive { get; set; } = false;
        private DataCompositeFilter RangeFilters { get; set; }

        //==============================================
        //=             GROUP BY FILTERS               =
        //==============================================
        private class OrderByItem
        {
            public string Id { get; set; }
            public string Text { get; set; } = string.Empty;
        }

        private string SortByOption { get; set; }

        private IEnumerable<OrderByItem> OrderByOptions { get; set; } = new List<OrderByItem>
        {
            new OrderByItem() { Id = "SentDate_desc", Text = "Date Sent (Newest First)" },
            new OrderByItem() { Id = "SentDate_asc",  Text = "Date Sent (Oldest First)" },
            new OrderByItem() { Id = "Amount_desc",    Text = "Value (Highest First)" },
            new OrderByItem() { Id = "Amount_asc",     Text = "Value (Lowest First)" }
        };

        private async Task OrderData(string SortByOption)
        {
            const string SentDesc = "SentDate_desc";
            const string SentAsc = "SentDate_asc";
            const string AmountDesc = "Amount_desc";
            const string AmountAsc = "Amount_asc";

            string member = "";
            ListSortDirection direction = ListSortDirection.Ascending;

            if (GridRef != null)
            {
                var gridState = GridRef.GetState();

                if (string.IsNullOrWhiteSpace(SortByOption))
                {
                    gridState.SortDescriptors.Clear();
                    await GridRef.SetStateAsync(gridState);
                    return;
                }

                gridState.SortDescriptors.Clear();

                switch (SortByOption)
                {
                    case SentAsc:
                        member = "Date";
                        direction = ListSortDirection.Ascending;
                        break;
                    case SentDesc:
                        member = "Date";
                        direction = ListSortDirection.Descending;
                        break;
                    case AmountDesc:
                        member = "TotalNet";
                        direction = ListSortDirection.Descending;
                        break;
                    case AmountAsc:
                        member = "TotalNet";
                        direction = ListSortDirection.Ascending;
                        break;
                }

                if (!string.IsNullOrWhiteSpace(member))
                {
                    gridState.SortDescriptors.Add(new GroupDescriptor()
                    {
                        Member = member,
                        SortDirection = direction
                    });

                    await GridRef.SetStateAsync(gridState);
                }
            }
        }

        private void ToggleCustomRange()
        {
            if (ActiveQuickFilterDays != null)
            {
                ShowRecordsFromXDay(ActiveQuickFilterDays.Value);
            }

            showCustomRange = !showCustomRange;

            if (RangeFilters != null)
                RangeFilters = null;

            GridRef?.Rebind();
        }

        private void ApplyCustomRange()
        {
            try
            {
                if (customStartDate is null || customEndDate is null)
                {
                    throw new Exception("Both the start and end date must be set. Please, try again.");
                }

                var customFilter = new DataCompositeFilter
                {
                    LogicalOperator = "AND"
                };

                DateOnly startDate = (DateOnly)customStartDate;
                DateOnly endDate = (DateOnly)customEndDate;

                // Make today inclusive by pushing end date out one day.
                if (endDate == DateOnly.FromDateTime(DateTime.Today))
                {
                    endDate = endDate.AddDays(1);
                }

                var dateRangeFilter = new DataCompositeFilter
                {
                    LogicalOperator = "AND"
                };

                dateRangeFilter.Filters.Add(new DataFilter
                {
                    ColumnName = CreatedOnColumn,
                    Operator = "ge",
                    Guid = Guid.NewGuid().ToString(),
                    Value = Value.ForString(startDate.ToString("yyyy-MM-dd"))
                });

                dateRangeFilter.Filters.Add(new DataFilter
                {
                    ColumnName = CreatedOnColumn,
                    Operator = "le",
                    Guid = Guid.NewGuid().ToString(),
                    Value = Value.ForString(endDate.ToString("yyyy-MM-dd"))
                });

                customFilter.CompositeFilters.Add(dateRangeFilter);

                RangeFilters = customFilter;

                StateHasChanged();
                GridRef?.Rebind();
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.ToString());
            }
        }

        private void GroupByButton()
        {
            if (GroupByColumn)
                QuickFilterGroupByCSS = "";
            else
                QuickFilterGroupByCSS = "activeButton";

            GroupByColumn = !GroupByColumn;

            GridRef?.Rebind();
        }

        /// <summary>
        /// Returns records from the last X days (where X is the input).
        /// Example usage: ShowRecordsFromXDay(-7) for last 7 days.
        /// </summary>
        /// <param name="days">Number of days to back (negative integer)</param>
        private void ShowRecordsFromXDay(int days)
        {
            // Reset custom range state
            customStartDate = null;
            customEndDate = null;
            RangeFilters = null;

            // Hide range section if currently shown
            if (showCustomRange)
                showCustomRange = false;

            // Toggle behaviour: pressing the same button again disables it
            if (ActiveQuickFilterDays == days)
            {
                ActiveQuickFilterDays = null;
                QuickFilter7DaysCSS = "";
                QuickFilter90DaysCSS = "";
                QuickFilters = null;

                StateHasChanged();
                GridRef?.Rebind();
                return;
            }

            // Clear any active range filter
            if (RangeFilters != null)
            {
                RangeFiltersActive = false;
                RangeFilters = null;
            }

            // Activate the quick filter
            ActiveQuickFilterDays = days;

            // Apply CSS class based on which button was clicked
            if (days == -7)
            {
                QuickFilter7DaysCSS = "activeButton";
                QuickFilter90DaysCSS = "";
            }
            else if (days == -90)
            {
                QuickFilter90DaysCSS = "activeButton";
                QuickFilter7DaysCSS = "";
            }

            // Build the filter
            var customFilter = new DataCompositeFilter
            {
                LogicalOperator = "AND"
            };

            DateTime startDate = DateTime.Today.AddDays(days);
            DateTime endDate = DateTime.Today.AddDays(1); // include today

            var dateRangeFilter = new DataCompositeFilter
            {
                LogicalOperator = "AND"
            };

            // >= startDate
            dateRangeFilter.Filters.Add(new DataFilter
            {
                ColumnName = CreatedOnColumn,
                Operator = "ge",
                Guid = Guid.NewGuid().ToString(),
                Value = Value.ForString(startDate.ToString("yyyy-MM-dd"))
            });

            // <= endDate
            dateRangeFilter.Filters.Add(new DataFilter
            {
                ColumnName = CreatedOnColumn,
                Operator = "le",
                Guid = Guid.NewGuid().ToString(),
                Value = Value.ForString(endDate.ToString("yyyy-MM-dd"))
            });

            customFilter.CompositeFilters.Add(dateRangeFilter);

            QuickFilters = customFilter;

            StateHasChanged();
            GridRef?.Rebind();
        }

        /// <summary>
        /// Applies grouping to the grid data if GroupByColumn is enabled.
        /// Note: This method currently flattens the grouped data back to a single list
        /// to preserve compatibility with the existing grid binding.
        /// </summary>
        private List<ExpandoObject> GroupByField(List<ExpandoObject> gridData)
        {
            if (GroupByColumn)
            {
                string groupColumn = GroupBy;

                // Extract unique values for UI options (if used elsewhere)
                GroupByOptions = gridData
                    .Select(row =>
                    {
                        var dict = (IDictionary<string, object>)row;
                        return dict.TryGetValue(groupColumn, out var value)
                            ? value?.ToString()
                            : null;
                    })
                    .Where(v => !string.IsNullOrWhiteSpace(v))
                    .Distinct()
                    .ToList();

                // Group and then flatten (preserves original rendering behaviour)
                var grouped = gridData
                    .GroupBy(row =>
                    {
                        var dict = (IDictionary<string, object>)row;
                        return dict.TryGetValue(groupColumn, out var value)
                            ? value
                            : null;
                    })
                    .ToList();

                gridData = grouped.SelectMany(g => g).ToList();
            }

            return gridData;
        }
    }
}
