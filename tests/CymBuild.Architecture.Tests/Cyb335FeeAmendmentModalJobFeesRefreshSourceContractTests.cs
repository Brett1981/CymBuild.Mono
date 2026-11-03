using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-335: agreeing the fee amendment raised from an activity (CYB-333) changes the Job Fees table's
/// Agreed and Variation columns, but the amendment is completed in an app-level modal after the
/// activity panel has closed, so no grid callback reached the Job page and the table stayed stale
/// until a reload. The modal's close now requests a JOBFEES refresh through RefreshService, which
/// JobDetail handles by reloading the Fees grid and its shell.
/// </summary>
public sealed class Cyb335FeeAmendmentModalJobFeesRefreshSourceContractTests
{
    [Fact]
    public void RefreshService_SetsTheRequestedGridCodeBeforeRaisingTheEvent()
    {
        var source = ReadSource("libs", "Concursus.API.Client", "Models", "RefreshService.cs");

        Assert.Matches(
            @"public void RequestGridRefresh\(string GridCode\)\s*\{[^}]*GridCodeSelected = GridCode;[^}]*GridRefreshRequested\?\.Invoke\(\);\s*\}",
            source);
    }

    [Fact]
    public void FeeAmendmentModal_RequestsAJobFeesRefreshWhenItCloses()
    {
        var source = ReadSource("apps", "Concursus.PWA", "Classes", "ActivityFeeAmendmentNavigation.cs");

        Assert.Contains("public const string JobFeesGridCode = \"JOBFEES\";", source, StringComparison.Ordinal);
        Assert.Contains("_ = RequestJobFeesRefreshWhenClosedAsync(modalClosed, refreshService);", source, StringComparison.Ordinal);
        Assert.Matches(
            @"await modalClosed;\s*refreshService\.RequestGridRefresh\(JobFeesGridCode\);",
            source);
    }

    [Fact]
    public void JobDetail_RefreshesTheFeesGridWhenAJobFeesRefreshIsRequested()
    {
        var source = ReadSource("apps", "Concursus.PWA", "Pages", "JobDetail.razor");

        Assert.Contains("@implements IDisposable", source, StringComparison.Ordinal);
        Assert.Contains("refreshService.GridRefreshRequested += OnGridRefreshRequested;", source, StringComparison.Ordinal);
        Assert.Contains("refreshService.GridRefreshRequested -= OnGridRefreshRequested;", source, StringComparison.Ordinal);

        var handler = Regex.Match(
            source,
            @"private void OnGridRefreshRequested\(\)\s*\{(?<body>.*?)\n    \}",
            RegexOptions.Singleline);

        Assert.True(handler.Success, "OnGridRefreshRequested not found in JobDetail.razor.");
        var body = handler.Groups["body"].Value;
        Assert.Contains("ActivityFeeAmendmentNavigation.JobFeesGridCode", body, StringComparison.Ordinal);
        Assert.Contains("_jobFeesGrid?.RefreshGrid();", body, StringComparison.Ordinal);
        Assert.Contains("await RefreshJobShellAsync(", body, StringComparison.Ordinal);
    }

    private static string ReadSource(params string[] segments) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(segments)).Replace("\r\n", "\n");
}
