using System;
using System.Collections.Generic;
using System.Linq;
using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;

namespace Concursus.PWA.Shared.V2Grid
{
    public static class V2GridRequestBuilder
    {
        /// <summary>
        /// Build a SINGLE composite filter (AND) then attach it to GridDataListRequest.Filters (repeated).
        /// This matches the existing proto shape:
        ///   repeated DataCompositeFilter Filters = 3;
        /// </summary>
        public static DataCompositeFilter? BuildCompositeFilter(V2GridQueryState state)
        {
            if (state == null) return null;

            var active = state.FiltersByColumn.Values
                .Where(f => f != null && !f.IsEmpty)
                .ToList();

            if (active.Count == 0) return null;

            var root = new DataCompositeFilter
            {
                LogicalOperator = "AND"
            };

            foreach (var f in active)
            {
                var df = new DataFilter
                {
                    ColumnName = f.ColumnName,
                    Guid = System.Guid.NewGuid().ToString(),
                    Operator = f.Operator switch
                    {
                        V2GridFilterOperator.Equals => "IsEqualTo",
                        _ => "Contains"
                    },
                    // Keep DataType empty (server can infer) unless you want to extend later
                    DataType = ""
                };

                // Legacy behaviour: map "yes/no" to 1/0
                var raw = (f.Value ?? "").Trim();
                if (raw.Equals("yes", StringComparison.OrdinalIgnoreCase))
                {
                    df.Value = Value.ForString("1");
                }
                else if (raw.Equals("no", StringComparison.OrdinalIgnoreCase))
                {
                    df.Value = Value.ForString("0");
                }
                else
                {
                    // We send as string; server already handles its own typing rules
                    df.Value = Value.ForString(raw);
                }

                root.Filters.Add(df);
            }

            return root;
        }

        public static List<DataSort>? BuildSortList(V2GridQueryState state)
        {
            if (state?.Sort == null) return null;

            // IMPORTANT: match legacy strings (Telerik SortDirection.ToString()) => "Ascending"/"Descending"
            var sort = new DataSort
            {
                ColumnName = state.Sort.ColumnName,
                Direction = state.Sort.Descending ? "Descending" : "Ascending"
            };

            return new List<DataSort> { sort };
        }
    }
}
