using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using System.Dynamic;

namespace Concursus.PWA.Shared
{
    public partial class FilteredDynamicGridViewV2 : ComponentBase
    {
        // Shows the custom range section
        private bool showCustomRange { get; set; } = false;

        // Custom start date
        private DateOnly? customStartDate { get; set; }

        // Custom end date
        private DateOnly? customEndDate { get; set; }

        // FilteredList Variables
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

        private DataCompositeFilter? QuickFilters { get; set; }

        //==============================================
        //=             RANGE FILTERS                  =
        //==============================================
        private bool RangeFiltersActive { get; set; } = false;
        private DataCompositeFilter? RangeFilters { get; set; }

        //==============================================
        //=             GROUP BY FILTERS               =
        //==============================================
        private class OrderByItem
        {
            public string Id { get; set; } = string.Empty;
            public string Text { get; set; } = string.Empty;
        }

        private string SortByOption { get; set; } = string.Empty;

        private IEnumerable<OrderByItem> OrderByOptions { get; set; } = new List<OrderByItem>
        {
            new OrderByItem() { Id = "SentDate_desc", Text = "Date Sent (Newest First)" },
            new OrderByItem() { Id = "SentDate_asc",  Text = "Date Sent (Oldest First)" },
            new OrderByItem() { Id = "Amount_desc",    Text = "Value (Highest First)" },
            new OrderByItem() { Id = "Amount_asc",     Text = "Value (Lowest First)" }
        };

        private async Task OrderData(string sortByOption)
        {
            const string SentDesc = "SentDate_desc";
            const string SentAsc = "SentDate_asc";
            const string AmountDesc = "Amount_desc";
            const string AmountAsc = "Amount_asc";

            var member = string.Empty;
            var descending = false;

            switch (sortByOption)
            {
                case SentAsc:
                    member = "Date";
                    descending = false;
                    break;
                case SentDesc:
                    member = "Date";
                    descending = true;
                    break;
                case AmountDesc:
                    member = "TotalNet";
                    descending = true;
                    break;
                case AmountAsc:
                    member = "TotalNet";
                    descending = false;
                    break;
            }

            NativeSortColumn = member;
            NativeSortDescending = descending;
            NativePage = 1;
            await PersistNativeGridStateAsync();
            await ReloadNativeGridAsync(1);
        }

        private async Task ToggleCustomRange()
        {
            if (ActiveQuickFilterDays != null)
            {
                ShowRecordsFromXDay(ActiveQuickFilterDays.Value);
            }

            showCustomRange = !showCustomRange;

            if (RangeFilters != null)
                RangeFilters = null;

            await ReloadNativeGridAsync(1);
        }

        private async Task ApplyCustomRange()
        {
            try
            {
                if (customStartDate is null || customEndDate is null)
                {
                    throw new Exception("Both the start and end date must be set. Please, try again.");
                }

                var customFilter = new DataCompositeFilter
                {
                    LogicalOperator = "and"
                };

                DateOnly startDate = customStartDate.Value;
                DateOnly endDate = customEndDate.Value;

                // Make today inclusive by pushing end date out one day.
                if (endDate == DateOnly.FromDateTime(DateTime.Today))
                {
                    endDate = endDate.AddDays(1);
                }

                var dateRangeFilter = new DataCompositeFilter
                {
                    LogicalOperator = "and"
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
                NativePage = 1;

                await ReloadNativeGridAsync(1);
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.ToString());
            }
        }

        private async Task GroupByButton()
        {
            if (GroupByColumn)
                QuickFilterGroupByCSS = "";
            else
                QuickFilterGroupByCSS = "activeButton";

            GroupByColumn = !GroupByColumn;
            await ReloadNativeGridAsync(NativePage);
        }

        /// <summary>
        /// Returns records from the last X days where X is the input.
        /// Example usage: ShowRecordsFromXDay(-7) for last 7 days.
        /// </summary>
        private void ShowRecordsFromXDay(int days)
        {
            _ = InvokeAsync(async () =>
            {
                customStartDate = null;
                customEndDate = null;
                RangeFilters = null;

                if (showCustomRange)
                    showCustomRange = false;

                // Toggle behaviour: pressing the same button again disables it
                if (ActiveQuickFilterDays == days)
                {
                    ActiveQuickFilterDays = null;
                    QuickFilter7DaysCSS = "";
                    QuickFilter90DaysCSS = "";
                    QuickFilters = null;

                    await ReloadNativeGridAsync(1);
                    return;
                }

                if (RangeFilters != null)
                {
                    RangeFiltersActive = false;
                    RangeFilters = null;
                }

                ActiveQuickFilterDays = days;

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

                var customFilter = new DataCompositeFilter
                {
                    LogicalOperator = "and"
                };

                DateTime startDate = DateTime.Today.AddDays(days);
                DateTime endDate = DateTime.Today.AddDays(1);

                var dateRangeFilter = new DataCompositeFilter
                {
                    LogicalOperator = "and"
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
                QuickFilters = customFilter;

                await ReloadNativeGridAsync(1);
            });
        }

        private string DateOnlyToInputValue(DateOnly? value)
        {
            return value?.ToString("yyyy-MM-dd") ?? string.Empty;
        }

        private void OnCustomStartDateChanged(ChangeEventArgs args)
        {
            customStartDate = TryParseDateOnly(args.Value?.ToString());
        }

        private void OnCustomEndDateChanged(ChangeEventArgs args)
        {
            customEndDate = TryParseDateOnly(args.Value?.ToString());
        }

        private static DateOnly? TryParseDateOnly(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return null;

            return DateOnly.TryParse(value, out var parsed) ? parsed : null;
        }

        /// <summary>
        /// Applies grouping to the grid data if GroupByColumn is enabled.
        /// This method still flattens grouped data to preserve the existing rendering behaviour.
        /// </summary>
        private List<ExpandoObject> GroupByField(List<ExpandoObject> gridData)
        {
            if (GroupByColumn)
            {
                string groupColumn = GroupBy;

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
                    .ToList()!;

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
