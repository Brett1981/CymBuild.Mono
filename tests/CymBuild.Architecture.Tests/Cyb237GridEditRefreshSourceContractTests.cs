using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-237: setting an existing Fee Amendment to Agreed changes the Job's agreed fee, but the Job
/// summary cards only refreshed after a page reload. DynamicGridView.CloseWindow raised
/// OnActionCompleted when closing a new record only; closing an existing (double-clicked) record
/// took the ComingFromModal branch and skipped it, so JobDetail never re-read its summary.
/// Both branches must raise OnActionCompleted, and the JOBFEES grid must refresh the Job shell.
/// </summary>
public sealed class Cyb237GridEditRefreshSourceContractTests
{
    [Fact]
    public void CloseWindow_RaisesOnActionCompletedAfterClosingAnExistingRecord()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Shared", "DynamicGridView.razor.cs"))
            .Replace("\r\n", "\n");

        var existingRecordBranch = Regex.Match(
            source,
            @"protected async Task CloseWindow\(\).*?else\s*\{(?<body>.*?ComingFromModal = false;.*?)\n            \}",
            RegexOptions.Singleline);

        Assert.True(existingRecordBranch.Success, "CloseWindow existing-record branch not found.");
        Assert.Contains(
            "if (OnActionCompleted.HasDelegate) await OnActionCompleted.InvokeAsync();",
            existingRecordBranch.Groups["body"].Value,
            StringComparison.Ordinal);
    }

    [Fact]
    public void JobDetail_JobFeesGridRefreshesTheJobShellOnActionCompleted()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Pages", "JobDetail.razor"))
            .Replace("\r\n", "\n");

        Assert.Matches(
            @"GridCode=""JOBFEES""\s*\n\s*OnActionCompleted=""RefreshJobProgressAndInvoiceScheduleActions""",
            source);
        Assert.Matches(
            @"private async Task RefreshJobProgressAndInvoiceScheduleActions\(\)\s*\{\s*await RefreshJobShellAsync\(",
            source);
    }
}
