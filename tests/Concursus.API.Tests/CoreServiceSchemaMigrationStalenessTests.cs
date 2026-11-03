using Concursus.EF.SchemaMigration;
using Xunit;

namespace Concursus.API.Tests;

/// <summary>
/// CoreService.SchemaMigration.cs is not unit-testable the way CoreService.Sage.cs is (it delegates
/// to SchemaMigrationEngine, which uses raw ADO.NET SqlConnection/SqlCommand throughout). The
/// staleness guard's decision is the pure SchemaMigrationRules.IsSourceSyncStale function with no
/// DB dependency, so it is tested directly here with no CoreServiceTestFactory or Moq involved.
/// </summary>
public sealed class CoreServiceSchemaMigrationStalenessTests
{
    [Fact]
    public void IsSourceSyncStale_NeverSynced_ReturnsTrue()
    {
        Assert.True(SchemaMigrationRules.IsSourceSyncStale(string.Empty, DateTime.UtcNow));
        Assert.True(SchemaMigrationRules.IsSourceSyncStale(null, DateTime.UtcNow));
    }

    [Fact]
    public void IsSourceSyncStale_SyncedWithinThreshold_ReturnsFalse()
    {
        var now = new DateTime(2026, 9, 8, 12, 0, 0, DateTimeKind.Utc);
        var syncedOnUtc = now.AddMinutes(-10).ToString("yyyy-MM-dd HH:mm:ss");

        Assert.False(SchemaMigrationRules.IsSourceSyncStale(syncedOnUtc, now));
    }

    [Fact]
    public void IsSourceSyncStale_SyncedBeyondThreshold_ReturnsTrue()
    {
        var now = new DateTime(2026, 9, 8, 12, 0, 0, DateTimeKind.Utc);
        var syncedOnUtc = now.AddMinutes(-31).ToString("yyyy-MM-dd HH:mm:ss");

        Assert.True(SchemaMigrationRules.IsSourceSyncStale(syncedOnUtc, now));
    }

    [Fact]
    public void IsSourceSyncStale_UnparsableValue_ReturnsTrue()
    {
        Assert.True(SchemaMigrationRules.IsSourceSyncStale("not-a-date", DateTime.UtcNow));
    }
}
