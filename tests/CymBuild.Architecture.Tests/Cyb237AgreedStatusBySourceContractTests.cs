using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-237: "Agreed Status By" is system-set by SJob.FeeAmendmentsUpsert (covered behaviourally by
/// CymBuild.Database.IntegrationTests FeeAmendmentAgreedStatusByTests). The validation function
/// resolves its targets through SCore.GetEntityPropertyGuid, which the R4 SQL test database has no
/// metadata for, so the read-only lock is pinned here as a source contract: the field is always
/// read-only and never reported as "Required" (the user has no way to enter it).
/// </summary>
public sealed class Cyb237AgreedStatusBySourceContractTests
{
    [Fact]
    public void FeeAmendmentsValidate_LocksAgreedStatusByAndNeverRequiresIt()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["Database", "CymBuild_DB", "Schema", "Programmability", "Functions", "SJob.FeeAmendmentsValidate.sql"]))
            .Replace("\r\n", "\n");

        var agreedStatusByRows = Regex.Matches(
            source,
            @"GetEntityPropertyGuid\(N'SJob', N'FeeAmendment', N'AgreedStatusByUserId'\)\s*INSERT\s+@ValidationResult\s*\([^)]*\)\s*VALUES\s*\(\s*@EntityPropertyGuid,\s*N'P',\s*(?<readOnly>[01]),\s*(?<hidden>[01]),\s*(?<invalid>[01]),\s*N'(?<message>[^']*)'",
            RegexOptions.IgnoreCase);

        var row = Assert.Single(agreedStatusByRows);
        Assert.Equal("1", row.Groups["readOnly"].Value);
        Assert.Equal("0", row.Groups["invalid"].Value);
        Assert.Equal(string.Empty, row.Groups["message"].Value);
    }

    [Fact]
    public void FeeAmendmentsValidate_RequiresARejectionReasonOnlyWhileItIsEmpty()
    {
        // Found on CymBuild_Dev264 2026-10-08: the Rejected branch flagged RejectionReason as invalid
        // unconditionally, so a Rejected amendment could never be saved even with a reason entered.
        var source = ReadValidate();

        var rejectedBranch = Regex.Match(
            source,
            @"IF\s*\(\s*@FeeAmendmentStatusGuid\s*=\s*@RejectedFeeAmendmentStatusGuid\s*\)(?<body>.*?)N'Rejection reason required\.'",
            RegexOptions.Singleline | RegexOptions.IgnoreCase);

        Assert.True(rejectedBranch.Success, "Rejected-status rejection reason rule not found.");
        Assert.Matches(
            @"IF\s*\(\s*NULLIF\(LTRIM\(RTRIM\(ISNULL\(@RejectionReason, N''\)\)\), N''\) IS NULL\s*\)",
            rejectedBranch.Groups["body"].Value);
    }

    private static string ReadValidate() =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["Database", "CymBuild_DB", "Schema", "Programmability", "Functions", "SJob.FeeAmendmentsValidate.sql"]))
            .Replace("\r\n", "\n");
}
