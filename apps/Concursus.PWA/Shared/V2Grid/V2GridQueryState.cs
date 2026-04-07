using System;
using System.Collections.Generic;

namespace Concursus.PWA.Shared.V2Grid
{
    public sealed class V2GridQueryState
    {
        public V2GridSort? Sort { get; private set; }

        // Simple AND-only set of column filters (Phase 1)
        public Dictionary<string, V2GridFilter> FiltersByColumn { get; } =
            new(StringComparer.OrdinalIgnoreCase);

        public void ToggleSort(string columnName)
        {
            if (string.IsNullOrWhiteSpace(columnName)) return;

            if (Sort != null && Sort.ColumnName.Equals(columnName, StringComparison.OrdinalIgnoreCase))
            {
                Sort = Sort with { Descending = !Sort.Descending };
            }
            else
            {
                Sort = new V2GridSort(columnName, false);
            }
        }

        public void ClearSort() => Sort = null;

        public void SetColumnFilter(string columnName, V2GridFilter? filter)
        {
            if (string.IsNullOrWhiteSpace(columnName)) return;

            if (filter == null || filter.IsEmpty)
            {
                FiltersByColumn.Remove(columnName);
                return;
            }

            FiltersByColumn[columnName] = filter;
        }

        public string GetColumnFilterValue(string columnName)
        {
            if (FiltersByColumn.TryGetValue(columnName, out var f))
                return f.Value ?? string.Empty;

            return string.Empty;
        }
    }

    public sealed record V2GridSort(string ColumnName, bool Descending);

    public enum V2GridFilterOperator
    {
        Contains,
        Equals
    }

    public sealed class V2GridFilter
    {
        public string ColumnName { get; set; } = "";
        public V2GridFilterOperator Operator { get; set; } = V2GridFilterOperator.Contains;

        /// <summary>
        /// Raw string input from UI. We keep it as string and let server parse based on column type
        /// (same behaviour as legacy grid where values arrive as strings in many cases).
        /// </summary>
        public string? Value { get; set; }

        public bool IsEmpty => string.IsNullOrWhiteSpace(Value);
    }
}
