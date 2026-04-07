using System.Collections.Generic;
using Concursus.API.Core;

namespace Concursus.PWA.Shared.V2Grid
{
    /// <summary>
    /// Not actually "reflection" anymore - we keep the name because your V2DynamicGridView already calls it.
    /// This safely attaches sort + filter lists to the proto request.
    /// </summary>
    public static class GridRequestReflectionSetter
    {
        public static void TrySetSortAndFilter(GridDataListRequest req, DataCompositeFilter? filter, List<DataSort>? sort)
        {
            if (req == null) return;

            req.Filters.Clear();
            req.Sort.Clear();

            if (filter != null && (filter.Filters.Count > 0 || filter.CompositeFilters.Count > 0))
                req.Filters.Add(filter);

            if (sort != null && sort.Count > 0)
                req.Sort.AddRange(sort);
        }

        public static void SetString(GridDataListRequest req, string propertyName, string value)
        {
            // Keeping this API because your file calls SetString(...) already.
            // We only support the known fields.
            if (req == null) return;

            switch (propertyName)
            {
                case nameof(GridDataListRequest.GridCode):
                    req.GridCode = value ?? "";
                    break;
                case nameof(GridDataListRequest.GridViewCode):
                    req.GridViewCode = value ?? "";
                    break;
                case nameof(GridDataListRequest.ParentGuid):
                    req.ParentGuid = value ?? "";
                    break;
            }
        }

        public static void SetInt(GridDataListRequest req, string propertyName, int value)
        {
            if (req == null) return;

            switch (propertyName)
            {
                case nameof(GridDataListRequest.Page):
                    req.Page = value;
                    break;
                case nameof(GridDataListRequest.PageSize):
                    req.PageSize = value;
                    break;
            }
        }
    }
}
