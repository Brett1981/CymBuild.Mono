using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-484: SCore.WorkflowGetNextStatus must not offer the record's current status as a next
// status. On 2026-09-23 a DEV -> repo schema source sync (-SyncSource) reverted this by copying an
// older DEV definition over the committed file, with the guard commented out. Pinned here so a
// stale sync fails the fast suite instead of reaching a release.
public sealed class Cyb484WorkflowNextStatusSourceContractTests
{
    [Fact]
    public void WorkflowGetNextStatus_ExcludesTheCurrentStatusInEveryBranch()
    {
        var sql = File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["Database", "CymBuild_DB", "Schema", "Programmability", "Functions", "SCore.WorkflowGetNextStatus.sql"]));

        var activeGuards = Regex.Matches(
            sql,
            @"^[ \t]*AND @OpenedStatusId <> @CurrentStatusID",
            RegexOptions.Multiline | RegexOptions.CultureInvariant);
        var commentedGuards = Regex.Matches(
            sql,
            @"--[ \t]*AND @OpenedStatusId <> @CurrentStatusID",
            RegexOptions.CultureInvariant);

        Assert.Equal(2, activeGuards.Count);
        Assert.Empty(commentedGuards);
    }

    [Fact]
    public void WorkflowGetNextStatus_LeavesSchemaBindingToTheDeploymentLifecycle()
    {
        var sql = File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["Database", "CymBuild_DB", "Schema", "Programmability", "Functions", "SCore.WorkflowGetNextStatus.sql"]));

        // Source keeps schema binding commented out; SCore.PreDeploymentScript/PostDeploymentScript
        // toggle it on the target. A sync captured while binding was applied must not commit it.
        Assert.Contains("--WITH SCHEMABINDING", sql, StringComparison.Ordinal);
        Assert.DoesNotMatch(new Regex(@"^[ \t]*WITH SCHEMABINDING", RegexOptions.Multiline | RegexOptions.CultureInvariant), sql);
    }
}
