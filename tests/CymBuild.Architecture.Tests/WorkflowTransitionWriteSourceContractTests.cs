using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// AGENTS.md: "Never update workflow status directly. Use SCore.DataObjectTransitionUpsert;
/// the latest transition is current state." This scans the canonical (current) schema/procedure
/// source for anything other than SCore.DataObjectTransitionUpsert itself writing rows into
/// SCore.DataObjectTransition, so a new procedure can't silently bypass the validated write path
/// (e.g. the CYB-101 quote-item guard and "Ready to Send" net-value guard live only in
/// DataObjectTransitionUpsert).
/// </summary>
public sealed class WorkflowTransitionWriteSourceContractTests
{
    private static readonly Regex DirectTransitionWriteRegex = new(
        @"^\s*(INSERT(?:\s+INTO)?|UPDATE)\s+\[?SCore\]?\.\[?DataObjectTransition\]?",
        RegexOptions.IgnoreCase | RegexOptions.Multiline | RegexOptions.Compiled);

    /// <summary>
    /// Known, reviewed import/backfill exceptions. Both write SCore.DataObjectTransition
    /// directly with IsImported = 1 as historical/backfill import tooling, not as part of the
    /// live user-facing transition flow, so they do not go through the live-transition
    /// validation rules in SCore.DataObjectTransitionUpsert:
    /// - DataObjectTransitionAddCalculatedStatus: SQL-Agent-only backfill job (see
    ///   SCore.PostDeploymentScript.sql); has no C# caller anywhere in the repo.
    /// - DataObjectTransitionImportLegacyStatus: reachable via Concursus.EF.Core.ImportLegacyStatuses()
    ///   / CoreService.ImportLegacyStatuses (CBLD-616), a one-time legacy-status backfill endpoint.
    /// Adding a name here is a reviewed architectural decision, not a rubber stamp - if a new
    /// procedure needs to appear, confirm with the team that it is genuinely import/backfill-only.
    /// </summary>
    private static readonly string[] AllowedImportWriters =
    [
        "SCore.DataObjectTransitionAddCalculatedStatus.sql",
        "SCore.DataObjectTransitionImportLegacyStatus.sql"
    ];

    /// <summary>
    /// Known, reviewed administrative exception. DataObjectTransitionDelete only ever sets
    /// RowStatus = 254 (soft-deletes/deactivates an erroneous transition row); it never sets
    /// StatusID, so it cannot be used to change which workflow status a record is in, and it is
    /// gated behind Super User group membership. This is a different exception category to the
    /// import writers above - it doesn't touch status logic at all, so it isn't marked IsImported.
    /// </summary>
    private const string AllowedDeleteWriter = "SCore.DataObjectTransitionDelete.sql";

    private static readonly string[] AllowedDirectWriters =
    [
        "SCore.DataObjectTransitionUpsert.sql",
        .. AllowedImportWriters,
        AllowedDeleteWriter
    ];

    [Fact]
    public void OnlyAllowlistedProceduresWriteDataObjectTransitionDirectly()
    {
        var violations = new List<string>();

        foreach (var file in RepositoryLayout.EnumerateFilesByExtension(
            @"Database\CymBuild_DB\Schema\Programmability", ".sql"))
        {
            var fileName = Path.GetFileName(file);
            if (AllowedDirectWriters.Contains(fileName, StringComparer.OrdinalIgnoreCase))
            {
                continue;
            }

            var content = File.ReadAllText(file);
            if (DirectTransitionWriteRegex.IsMatch(content))
            {
                violations.Add(Path.GetRelativePath(RepositoryLayout.Root, file));
            }
        }

        Assert.True(
            violations.Count == 0,
            "Only SCore.DataObjectTransitionUpsert (and the reviewed import/backfill exceptions) may write "
            + "SCore.DataObjectTransition directly. Unreviewed direct writes were found in:"
            + Environment.NewLine
            + string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void AllowlistedImportExceptions_StillExistAndAreExplicitlyMarkedAsImports()
    {
        foreach (var fileName in AllowedImportWriters)
        {
            var content = ReadSingleAllowlistedFile(fileName);

            Assert.True(
                content.Contains("IsImported", StringComparison.Ordinal),
                $"{fileName} is allowlisted as an import/backfill exception but no longer marks its rows IsImported.");
        }
    }

    [Fact]
    public void AllowlistedDeleteException_OnlyChangesRowStatusAndRequiresSuperUser()
    {
        var content = ReadSingleAllowlistedFile(AllowedDeleteWriter);

        Assert.True(
            content.Contains("Code = N'SU'", StringComparison.Ordinal),
            $"{AllowedDeleteWriter} is allowlisted only because it is gated behind Super User group membership.");
        Assert.False(
            content.Contains("StatusID =", StringComparison.Ordinal),
            $"{AllowedDeleteWriter} is allowlisted only because it never assigns StatusID; it must remain a RowStatus-only deactivation.");
    }

    private static string ReadSingleAllowlistedFile(string fileName)
    {
        var matches = RepositoryLayout
            .EnumerateFilesByExtension(@"Database\CymBuild_DB\Schema\Programmability", ".sql")
            .Where(path => string.Equals(Path.GetFileName(path), fileName, StringComparison.OrdinalIgnoreCase))
            .ToArray();

        var file = Assert.Single(matches);
        return File.ReadAllText(file);
    }
}
