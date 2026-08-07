using Concursus.Common.Shared.Extensions;
using Concursus.Common.Shared.Helpers;
using Xunit;

namespace Concursus.Common.Shared.Tests.Extensions;

public sealed class StringHelperTests
{
    [Fact]
    public void TruncateAtWord_ReturnsInputWhenShorterThanLimit()
    {
        Assert.Equal("CymBuild", StringExtensions.TruncateAtWord("CymBuild", 20));
    }

    [Fact]
    public void TruncateAtWord_UsesLastCompleteWordBeforeLimit()
    {
        var result = StringExtensions.TruncateAtWord("CymBuild automated testing foundation", 24);

        Assert.Equal("CymBuild automated ...", result);
    }

    [Fact]
    public void TruncateAtWord_UsesExactLimitWhenNoSpaceExists()
    {
        var result = StringExtensions.TruncateAtWord("ABCDEFGHIJK", 5);

        Assert.Equal("ABCDE ...", result);
    }

    [Fact]
    public void PrepareFullTextSearchString_EscapesQuotesAndAddsPrefixWildcard()
    {
        var result = StringHelpers.PrepareFullTextSearchString("Cym\"Build");

        Assert.Equal("\"Cym\"\"Build*\"", result);
    }

    [Fact]
    public void Between_ReturnsTextBetweenMarkers()
    {
        Assert.Equal("middle", StringHelpers.Between("before[middle]after", "[", "]"));
    }
}
