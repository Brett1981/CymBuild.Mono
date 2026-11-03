using Concursus.API.Classes;
using Concursus.API.Core;
using Google.Protobuf.Collections;
using Google.Protobuf.WellKnownTypes;
using Xunit;

namespace Concursus.API.Tests.Classes;

public sealed class FunctionsTests
{
    // CYB-466: the Transactions grid combines an AND-group of column filters with an
    // OR-group of search-bar cross-column filters as sibling composites under one root.
    // Each sibling must keep its own LogicalOperator in its own sub-composite - flattening
    // them into a single shared filter list previously left the whole set OR'd (or, once an
    // additional AND-only group such as a range filter was also present, entirely AND'd),
    // producing wrong or empty results whenever a search term was combined with a column filter.
    [Fact]
    public void ConvertToServerFilterRequest_ColumnAndSearchFilters_KeepsSeparateSubCompositesAndOperators()
    {
        var columnFilters = new DataCompositeFilter { LogicalOperator = "and" };
        columnFilters.Filters.Add(new DataFilter
        {
            ColumnName = "Reference",
            Operator = "contains",
            Guid = System.Guid.NewGuid().ToString(),
            Value = Value.ForString("CDM")
        });

        var searchFilters = new DataCompositeFilter { LogicalOperator = "or" };
        searchFilters.Filters.Add(new DataFilter
        {
            ColumnName = "Reference",
            Operator = "contains",
            Guid = System.Guid.NewGuid().ToString(),
            Value = Value.ForString("term")
        });
        searchFilters.Filters.Add(new DataFilter
        {
            ColumnName = "Description",
            Operator = "contains",
            Guid = System.Guid.NewGuid().ToString(),
            Value = Value.ForString("term")
        });

        var siblingComposites = new RepeatedField<DataCompositeFilter> { columnFilters, searchFilters };

        var result = Functions.ConvertToServerFilterRequest(siblingComposites);

        Assert.Equal("AND", result.LogicalOperator);
        Assert.Empty(result.Filters);
        Assert.Equal(2, result.CompositeFilters.Count);

        var convertedColumnGroup = result.CompositeFilters[0];
        Assert.Equal("and", convertedColumnGroup.LogicalOperator);
        Assert.Single(convertedColumnGroup.Filters);
        Assert.Equal("Reference", convertedColumnGroup.Filters[0].ColumnName);

        var convertedSearchGroup = result.CompositeFilters[1];
        Assert.Equal("or", convertedSearchGroup.LogicalOperator);
        Assert.Equal(2, convertedSearchGroup.Filters.Count);
        Assert.Equal("Reference", convertedSearchGroup.Filters[0].ColumnName);
        Assert.Equal("Description", convertedSearchGroup.Filters[1].ColumnName);
    }

    [Fact]
    public void ConvertToServerFilterRequest_SingleColumnFilterGroup_PreservesAndOperator()
    {
        var columnFilters = new DataCompositeFilter { LogicalOperator = "and" };
        columnFilters.Filters.Add(new DataFilter
        {
            ColumnName = "Reference",
            Operator = "contains",
            Guid = System.Guid.NewGuid().ToString(),
            Value = Value.ForString("CDM")
        });
        columnFilters.Filters.Add(new DataFilter
        {
            ColumnName = "Status",
            Operator = "eq",
            Guid = System.Guid.NewGuid().ToString(),
            Value = Value.ForString("Open")
        });

        var result = Functions.ConvertToServerFilterRequest(new RepeatedField<DataCompositeFilter> { columnFilters });

        var convertedGroup = Assert.Single(result.CompositeFilters);
        Assert.Equal("and", convertedGroup.LogicalOperator);
        Assert.Equal(2, convertedGroup.Filters.Count);
    }
}
