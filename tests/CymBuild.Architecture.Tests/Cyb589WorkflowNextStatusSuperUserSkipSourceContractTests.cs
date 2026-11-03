using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-589: superusers must be able to skip workflow statuses when adding a new transition.
// SCore.WorkflowGetNextStatus used to apply the SU bypass only when re-opening an existing
// transition row, so new rows were always limited to the next status in the chain. SU skips on
// every entity type (and takes precedence); ENQUIRYSU / QUOTESU / JOBSU only on their own.
public sealed class Cyb589WorkflowNextStatusSuperUserSkipSourceContractTests
{
    private static string ReadSql() =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["Database", "CymBuild_DB", "Schema", "Programmability", "Functions", "SCore.WorkflowGetNextStatus.sql"]));

    [Fact]
    public void WorkflowGetNextStatus_LetsSuperUsersSkipFromTheCurrentStatus()
    {
        var sql = ReadSql();

        Assert.Matches(new Regex(
            @"wft\.FromStatusID = @CurrentStatusID[^\r\n]*\r?\n(?:[ \t]*--[^\r\n]*\r?\n)*[ \t]*OR \(@CanSkipStatuses = 1 AND toStatus\.ID <> @CurrentStatusID\)",
            RegexOptions.CultureInvariant), sql);
    }

    [Fact]
    public void WorkflowGetNextStatus_GrantsSkipToSuEverywhereAndScopedSuOnTheirOwnEntityType()
    {
        var sql = ReadSql();

        Assert.Contains("DECLARE @CanSkipStatuses BIT = @IsSuperUser;", sql, StringComparison.Ordinal);
        Assert.Contains("(@ShowInEnquiry = 1 AND g.Code = N'ENQUIRYSU')", sql, StringComparison.Ordinal);
        Assert.Contains("(@ShowInQuotes  = 1 AND g.Code = N'QUOTESU')", sql, StringComparison.Ordinal);
        Assert.Contains("(@ShowInJobs    = 1 AND g.Code = N'JOBSU')", sql, StringComparison.Ordinal);
    }
}
