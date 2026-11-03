using CymBuild_Outlook_API.Helpers;
using CymBuild_Outlook_Common.Models;
using Xunit;

namespace CymBuild_Outlook_API.Tests;

public sealed class FolderSuggestionRankerTests
{
    private static SuggestedFilingLocationResult Row(string url, string scope, int count)
        => new() { FilingLocationUrl = url, Scope = scope, FiledCount = count };

    [Fact]
    public void Rank_UsesRecordScopeOnly_WhenRecordHasEnoughHistory()
    {
        var rows = new List<SuggestedFilingLocationResult>
        {
            Row("https://sp/Job1/Drawings", "Record", 5),
            Row("https://sp/Job1/Reports", "Record", 2),
            Row("https://sp/Job2/Drawings", "EntityType", 40)
        };

        var ranked = FolderSuggestionRanker.Rank(rows);

        Assert.Equal(2, ranked.Count);
        Assert.Equal("https://sp/Job1/Drawings", ranked[0].FilingLocationUrl);
        Assert.Equal("https://sp/Job1/Reports", ranked[1].FilingLocationUrl);
    }

    [Fact]
    public void Rank_BlendsInEntityTypeScope_WhenRecordHistoryIsBelowThreshold()
    {
        var rows = new List<SuggestedFilingLocationResult>
        {
            Row("https://sp/Job1/Drawings", "Record", 1),
            Row("https://sp/Job2/Drawings", "EntityType", 40),
            Row("https://sp/Job3/Reports", "EntityType", 10)
        };

        var ranked = FolderSuggestionRanker.Rank(rows, recordHistoryThreshold: 3);

        Assert.Equal(3, ranked.Count);
        Assert.Equal("https://sp/Job1/Drawings", ranked[0].FilingLocationUrl);
        Assert.Equal("https://sp/Job2/Drawings", ranked[1].FilingLocationUrl);
        Assert.Equal("https://sp/Job3/Reports", ranked[2].FilingLocationUrl);
    }

    [Fact]
    public void Rank_ReturnsOnlyEntityTypeScope_WhenRecordHasNoHistory()
    {
        var rows = new List<SuggestedFilingLocationResult>
        {
            Row("https://sp/Job2/Drawings", "EntityType", 40),
            Row("https://sp/Job3/Reports", "EntityType", 10)
        };

        var ranked = FolderSuggestionRanker.Rank(rows);

        Assert.Equal(2, ranked.Count);
        Assert.Equal("https://sp/Job2/Drawings", ranked[0].FilingLocationUrl);
    }

    [Fact]
    public void Rank_DedupesWhenSameFolderAppearsInBothScopes()
    {
        var rows = new List<SuggestedFilingLocationResult>
        {
            Row("https://sp/Job1/Drawings", "Record", 1),
            Row("https://sp/Job1/Drawings", "EntityType", 40)
        };

        var ranked = FolderSuggestionRanker.Rank(rows, recordHistoryThreshold: 3);

        Assert.Single(ranked);
        Assert.Equal("https://sp/Job1/Drawings", ranked[0].FilingLocationUrl);
    }

    [Fact]
    public void Rank_CapsAtMaxResults()
    {
        var rows = Enumerable.Range(1, 10)
            .Select(i => Row($"https://sp/Job1/Folder{i}", "Record", 10 - i))
            .ToList();

        var ranked = FolderSuggestionRanker.Rank(rows, maxResults: 5);

        Assert.Equal(5, ranked.Count);
        Assert.Equal("https://sp/Job1/Folder1", ranked[0].FilingLocationUrl);
    }

    [Fact]
    public void Rank_ReturnsEmptyForNoRows()
    {
        var ranked = FolderSuggestionRanker.Rank(new List<SuggestedFilingLocationResult>());

        Assert.Empty(ranked);
    }
}
