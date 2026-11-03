using Concursus.PWA.Shared.Scheduler;
using Google.Protobuf.WellKnownTypes;
using Xunit;
using Assert = Xunit.Assert;

namespace Concursus.PWA.Tests;

/// <summary>
/// Covers the CYB-538 calendar day-boundary fix: NativeTeamAvailabilityBoard buckets events into
/// calendar day columns using item.Start.Date/item.End.Date against local calendar days
/// (VisibleDays, built from DateTime.Today/the date picker). Timestamp.ToDateTime() always
/// returns Kind=Utc, so TeamAvailability must convert to local time (ToLocalCalendarInstant)
/// before that comparison - otherwise a local midnight during BST (UTC+1) is stored as the
/// previous day's 23:00 UTC and renders under the wrong day, which is what Dorothy reported when
/// setting both start and end to 17/09/2026 00:00.
/// </summary>
public sealed class TeamAvailabilityTests
{
    [Fact]
    public void ToLocalCalendarInstant_LandsOnTheOriginalLocalCalendarDay_ForALocalMidnightStoredAsUtc()
    {
        // Arrange: a local midnight is what the user actually picks (e.g. 17/09/2026 00:00),
        // which the API stores as the equivalent UTC instant.
        var intendedLocalMidnight = DateTime.SpecifyKind(new DateTime(2026, 9, 17), DateTimeKind.Local);
        var storedUtcInstant = intendedLocalMidnight.ToUniversalTime();
        var timestamp = Timestamp.FromDateTime(storedUtcInstant);

        var result = TeamAvailability.ToLocalCalendarInstant(timestamp);

        Assert.Equal(intendedLocalMidnight.Date, result.Date);
        Assert.Equal(DateTimeKind.Local, result.Kind);
    }

    [Fact]
    public void ToLocalCalendarInstant_MatchesDifferentUtcDay_WhenLocalOffsetIsNonZero()
    {
        // Regression guard against reverting the fix back to a bare `timestamp.ToDateTime()`
        // (no .ToLocalTime()): that compiles and looks harmless, but the stored UTC instant for
        // a BST local midnight falls on the *previous* UTC calendar day. This proves the UTC
        // instant genuinely differs from the intended local day, so a fix that skips the local
        // conversion would demonstrably land on the wrong day - not just "possibly."
        var intendedLocalMidnight = DateTime.SpecifyKind(new DateTime(2026, 9, 17), DateTimeKind.Local);
        var storedUtcInstant = intendedLocalMidnight.ToUniversalTime();

        if (storedUtcInstant.Date == intendedLocalMidnight.Date)
        {
            // The machine running this test has a zero UTC offset on this date, so the bug this
            // test guards against cannot be demonstrated here - nothing to assert.
            return;
        }

        var timestamp = Timestamp.FromDateTime(storedUtcInstant);

        // What the pre-fix code effectively did: use the raw UTC instant's date directly.
        var preFixDate = timestamp.ToDateTime().Date;
        // What the fix does.
        var postFixDate = TeamAvailability.ToLocalCalendarInstant(timestamp).Date;

        Assert.NotEqual(intendedLocalMidnight.Date, preFixDate);
        Assert.Equal(intendedLocalMidnight.Date, postFixDate);
    }

    [Fact]
    public void ToLocalCalendarInstant_RoundTripsExactly_ForATimeOfDayAwayFromMidnight()
    {
        // Sanity check that the conversion isn't only correct at the midnight edge case.
        var intendedLocalTime = DateTime.SpecifyKind(new DateTime(2026, 9, 17, 9, 30, 0), DateTimeKind.Local);
        var timestamp = Timestamp.FromDateTime(intendedLocalTime.ToUniversalTime());

        var result = TeamAvailability.ToLocalCalendarInstant(timestamp);

        Assert.Equal(intendedLocalTime, result);
    }
}
