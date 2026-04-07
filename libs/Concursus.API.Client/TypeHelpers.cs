using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;

namespace Concursus.API.Client;

public class TypeHelpers
{
    #region Public Methods

    public static async Task<string> GetDataSourceRequestFilterValueByName(
        IList<Telerik.DataSource.IFilterDescriptor> filterDescriptors, string name)
    {
        var filterValue = "";

        foreach (var f in filterDescriptors) filterValue = await GetFilterDescriptorValueByName(f, name);

        return filterValue;
    }

    public static DataCompositeFilter GridDataCompositeFilterFromKendoFilterDescriptor(
        IList<Telerik.DataSource.IFilterDescriptor> filterDescriptors)
    {
        var cf = new DataCompositeFilter();

        foreach (var ifd in filterDescriptors) cf.CompositeFilters.Add(ProcessKendoIFilterDescriptor(ifd));

        return cf;
    }

    public static List<DataSort> GridDataSortFromKendoSortDescriptor(
        IList<Telerik.DataSource.SortDescriptor> sortDescriptors)
    {
        List<DataSort> lgds = new();

        foreach (var sd in sortDescriptors)
        {
            var gds = new DataSort();
            gds.ColumnName = sd.Member;
            gds.Direction = sd.SortDirection.ToString();

            lgds.Add(gds);
        }

        return lgds;
    }

    #endregion Public Methods

    #region Protected Methods

    protected static DataCompositeFilter ProcessKendoIFilterDescriptor(
         Telerik.DataSource.IFilterDescriptor filterDescriptor)
    {
        var cf = new DataCompositeFilter();

        if (filterDescriptor is Telerik.DataSource.FilterDescriptor)
        {
            cf.LogicalOperator = "AND";
            var f = (Telerik.DataSource.FilterDescriptor)filterDescriptor;
            var gf = new DataFilter();
            gf.ColumnName = f.Member;
            gf.Operator = f.Operator.ToString();
            gf.Guid = new Guid().ToString();

            if (f.Value is string)
            {
                string stringValue = f.Value.ToString().ToLower();
                if (stringValue == "yes" || stringValue == "no")
                {
                    gf.Value = Value.ForString(stringValue == "yes" ? "1" : "0");
                }
                else
                {
                    gf.Value = Value.ForString(f.Value.ToString());
                }
            }
            else if (f.Value is int)
            {
                gf.Value = Value.ForNumber(int.Parse(f.Value.ToString() ?? "0"));
            }
            //Handling datetime for filters.
            else if (f.Value is DateTime dt)
            {
                var dateOnly = dt.Date.ToString();

                gf.Value = Value.ForString(dateOnly);
            }

            cf.Filters.Add(gf);
        }

        if (filterDescriptor is Telerik.DataSource.CompositeFilterDescriptor)
        {
            cf.LogicalOperator =
                ((Telerik.DataSource.CompositeFilterDescriptor)filterDescriptor).LogicalOperator.ToString();
            foreach (var ifd in ((Telerik.DataSource.CompositeFilterDescriptor)filterDescriptor).FilterDescriptors)
                cf.CompositeFilters.Add(ProcessKendoIFilterDescriptor(ifd));
        }

        return cf;
    }

    #endregion Protected Methods

    #region Private Methods

    private static async Task<string> GetFilterDescriptorValueByName(
        Telerik.DataSource.IFilterDescriptor filterDescriptor, string name)
    {
        var filterValue = "";

        if (filterDescriptor is Telerik.DataSource.FilterDescriptor)
            if (((Telerik.DataSource.FilterDescriptor)filterDescriptor).Member == name)
            {
                var _filterValue = ((Telerik.DataSource.FilterDescriptor)filterDescriptor).Value.ToString() ?? "";
                if (_filterValue != "") filterValue = _filterValue;
            }

        if (filterDescriptor is Telerik.DataSource.CompositeFilterDescriptor)
            foreach (var f in ((Telerik.DataSource.CompositeFilterDescriptor)filterDescriptor).FilterDescriptors)
            {
                var _filterValue = await GetFilterDescriptorValueByName(f, name);

                if (_filterValue != "") filterValue = _filterValue;
            }

        return filterValue;
    }

    #endregion Private Methods
}