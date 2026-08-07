using Concursus.Common.Shared.Extensions;
using Concursus.Common.Shared.Functions;
using Xunit;

namespace Concursus.Common.Shared.Tests.Extensions;

public sealed class CollectionAndValueExtensionTests
{
    [Fact]
    public void Batch_SplitsSequenceWithoutLosingOrderOrRemainder()
    {
        var batches = EnumerableExtensions.Batch(Enumerable.Range(1, 7), 3).ToArray();

        Assert.Equal(3, batches.Length);
        Assert.Equal(new[] { 1, 2, 3 }, batches[0]);
        Assert.Equal(new[] { 4, 5, 6 }, batches[1]);
        Assert.Equal(new[] { 7 }, batches[2]);
    }

    [Fact]
    public void Batch_EmptySequenceProducesNoBatches()
    {
        Assert.Empty(EnumerableExtensions.Batch(Array.Empty<int>(), 5));
    }

    [Fact]
    public void DistinctBy_PreservesFirstOccurrenceForEachKey()
    {
        var source = new[]
        {
            new Sample(1, "first"),
            new Sample(2, "second"),
            new Sample(1, "duplicate")
        };

        var result = ListExtensions.DistinctBy(source, item => item.Id).ToArray();

        Assert.Equal(2, result.Length);
        Assert.Equal("first", result[0].Name);
        Assert.Equal("second", result[1].Name);
    }

    [Theory]
    [InlineData(-5, 0, 10, 0)]
    [InlineData(5, 0, 10, 5)]
    [InlineData(15, 0, 10, 10)]
    public void Clamp_IntReturnsValueWithinBounds(int value, int min, int max, int expected)
    {
        Assert.Equal(expected, NumericExtensions.Clamp(value, min, max));
    }

    [Theory]
    [InlineData(-1.5, 0.0, 1.0, 0.0)]
    [InlineData(0.5, 0.0, 1.0, 0.5)]
    [InlineData(1.5, 0.0, 1.0, 1.0)]
    public void Clamp_DoubleReturnsValueWithinBounds(double value, double min, double max, double expected)
    {
        Assert.Equal(expected, NumericExtensions.Clamp(value, min, max));
    }

    [Fact]
    public void Compare_HasChangedIsFalseForEqualValues()
    {
        var comparison = new Compare<string>("CymBuild", "CymBuild");

        Assert.False(comparison.HasChanged);
    }

    [Fact]
    public void Compare_HasChangedIsTrueForDifferentOrNullValues()
    {
        Assert.True(new Compare<string>("CymBuild", "Concursus").HasChanged);
        Assert.True(new Compare<string?>("CymBuild", null).HasChanged);
        Assert.True(new Compare<string?>(null, "CymBuild").HasChanged);
        Assert.False(new Compare<string?>(null, null).HasChanged);
    }

    private sealed record Sample(int Id, string Name);
}
