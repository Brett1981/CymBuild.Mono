using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-562: the DATETIME2 "Set to now" button returned the correct hour but rounded the minutes
/// down to the previous quarter-hour (08:53 became 08:45), because the native minute picker only
/// offered 00/15/30/45 and every minute path normalised onto that grid. The fix keeps the exact
/// minute end to end: "Set to now" uses the real minute, the picker displays it (adding it as an
/// option when it is off the quarter grid), and editing the date/hour no longer re-rounds it.
/// </summary>
public sealed class Cyb562SetToNowExactMinuteSourceContractTests
{
    private static string ReadShoreInputCode() =>
        File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Shared", "ShoreInput.razor.cs"))
            .Replace("\r\n", "\n");

    [Fact]
    public void SetToNow_UsesTheExactCurrentMinute()
    {
        var source = ReadShoreInputCode();

        Assert.Contains(
            "DateTimeValueBinding = now.Date.AddHours(now.Hour).AddMinutes(now.Minute);",
            source,
            StringComparison.Ordinal);
    }

    [Fact]
    public void MinutePicker_DisplaysAndOffersTheStoredMinuteWithoutRounding()
    {
        var source = ReadShoreInputCode();

        Assert.Contains(
            "private string NativeDateTimeMinuteValue => (DateTimeValueBinding?.Minute ?? 0).ToString(\"00\", CultureInfo.InvariantCulture);",
            source,
            StringComparison.Ordinal);

        // Off-grid minutes must be added to the quarter-hour options, or the <select> cannot show them.
        Assert.Contains(".Append(currentMinute)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void ShoreInput_NoLongerRoundsMinutesToTheQuarterHour()
    {
        var source = ReadShoreInputCode();

        Assert.DoesNotContain("NormaliseMinuteToQuarter", source, StringComparison.Ordinal);
        Assert.Contains("var minute = existingValue?.Minute ?? 0;", source, StringComparison.Ordinal);
    }
}
