using CymBuild_Outlook_API.Helpers;
using CymBuild_Outlook_Common.Models;
using Xunit;

namespace CymBuild_Outlook_API.Tests;

public sealed class FrequentFilingRecordRankerTests
{
    private static FrequentFilingRecordResult Row(long id, int count, DateTime? lastFiled = null)
        => new()
        {
            ID = id,
            Guid = Guid.NewGuid(),
            EntityTypeName = "Job",
            Name = $"Job {id}",
            FiledCount = count,
            LastFiledDateTime = lastFiled
        };

    [Fact]
    public void Rank_OrdersByFiledCount_MostUsedFirst()
    {
        var rows = new List<FrequentFilingRecordResult>
        {
            Row(1, 2),
            Row(8804, 12),
            Row(3, 5)
        };

        var ranked = FrequentFilingRecordRanker.Rank(rows);

        Assert.Equal(new long[] { 8804, 3, 1 }, ranked.Select(r => r.ID));
    }

    [Fact]
    public void Rank_BreaksTiesByMostRecentlyFiled()
    {
        var rows = new List<FrequentFilingRecordResult>
        {
            Row(1, 4, new DateTime(2026, 8, 1)),
            Row(2, 4, new DateTime(2026, 9, 20)),
            Row(3, 4, null)
        };

        var ranked = FrequentFilingRecordRanker.Rank(rows);

        Assert.Equal(new long[] { 2, 1, 3 }, ranked.Select(r => r.ID));
    }

    [Fact]
    public void Rank_CapsAtDefaultMaxResults()
    {
        var rows = Enumerable.Range(1, 12).Select(i => Row(i, i)).ToList();

        var ranked = FrequentFilingRecordRanker.Rank(rows);

        Assert.Equal(FrequentFilingRecordRanker.DefaultMaxResults, ranked.Count);
        Assert.Equal(12, ranked[0].ID);
    }

    [Fact]
    public void Rank_DropsDuplicateAndInvalidRows()
    {
        var duplicate = Row(7, 3);
        var rows = new List<FrequentFilingRecordResult>
        {
            Row(7, 9),
            duplicate,
            Row(0, 20),
            new() { ID = 9, Guid = Guid.Empty, FiledCount = 20 },
            Row(10, 0)
        };

        var ranked = FrequentFilingRecordRanker.Rank(rows);

        var single = Assert.Single(ranked);
        Assert.Equal(7, single.ID);
        Assert.Equal(9, single.FiledCount);
    }

    [Fact]
    public void Rank_ReturnsEmpty_WhenNoRows()
    {
        Assert.Empty(FrequentFilingRecordRanker.Rank(null!));
        Assert.Empty(FrequentFilingRecordRanker.Rank(new List<FrequentFilingRecordResult>()));
    }
}
