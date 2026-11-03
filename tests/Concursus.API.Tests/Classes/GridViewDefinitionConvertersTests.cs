using Concursus.API.Classes;
using Xunit;

namespace Concursus.API.Tests.Classes;

// CYB-560: ShowSearchBar / IsSearchDefaultCollapsed must survive both directions of the
// proto <-> EF mapping, otherwise the grid silently falls back to the proto default (false),
// which hides the search bar on every grid.
public sealed class GridViewDefinitionConvertersTests
{
    [Theory]
    [InlineData(true, false)]
    [InlineData(true, true)]
    [InlineData(false, false)]
    public void ConvertEfGridViewDefinitionToCore_MapsSearchBarSettings(bool showSearchBar, bool isSearchDefaultCollapsed)
    {
        var efDefinition = new Concursus.EF.Types.GridViewDefinition
        {
            Guid = Guid.NewGuid(),
            GridViewActions = new List<Concursus.EF.Types.GridViewAction>(),
            ShowSearchBar = showSearchBar,
            IsSearchDefaultCollapsed = isSearchDefaultCollapsed
        };
        InitialiseNullStrings(efDefinition);

        var result = Converters.ConvertEfGridViewDefinitionToCoreGridViewDefinition(efDefinition);

        Assert.Equal(showSearchBar, result.ShowSearchBar);
        Assert.Equal(isSearchDefaultCollapsed, result.IsSearchDefaultCollapsed);
    }

    [Theory]
    [InlineData(true, false)]
    [InlineData(true, true)]
    [InlineData(false, false)]
    public void ConvertCoreGridViewDefinitionToEf_MapsSearchBarSettings(bool showSearchBar, bool isSearchDefaultCollapsed)
    {
        var coreDefinition = new Concursus.API.Core.GridViewDefinition
        {
            Guid = Guid.NewGuid().ToString(),
            ShowSearchBar = showSearchBar,
            IsSearchDefaultCollapsed = isSearchDefaultCollapsed
        };

        var result = Converters.ConvertCoreGridViewDefinitionToEf(coreDefinition);

        Assert.Equal(showSearchBar, result.ShowSearchBar);
        Assert.Equal(isSearchDefaultCollapsed, result.IsSearchDefaultCollapsed);
    }

    // The EF reader always populates string columns from the TVF; protobuf setters reject null.
    private static void InitialiseNullStrings(object target)
    {
        foreach (var property in target.GetType().GetProperties())
        {
            if (property.PropertyType == typeof(string) && property.CanWrite && property.GetValue(target) is null)
            {
                property.SetValue(target, string.Empty);
            }
        }
    }
}
