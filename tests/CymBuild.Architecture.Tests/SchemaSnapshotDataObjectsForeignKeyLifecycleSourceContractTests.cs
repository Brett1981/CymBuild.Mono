using Xunit;

namespace CymBuild.Architecture.Tests;

// SCore.PreDeploymentScript NOCHECKs every FK to SCore.DataObjects and SCore.PostDeploymentScript
// re-enables them WITH CHECK. Run Compare snapshots the target between the two, so hashing the raw
// is_disabled flag made every such FK a false "Different" row, and the runner's drift check then
// failed on 2026-09-24 (QA run 3bbe3780) once PostDeploymentScript had restored them. Both snapshot
// copies (API compare and runner re-snapshot) must normalise it identically or hashes diverge.
public sealed class SchemaSnapshotDataObjectsForeignKeyLifecycleSourceContractTests
{
    private const string NormalisedIsDisabled =
        "CONVERT(BIT, CASE WHEN fk.referenced_object_id = OBJECT_ID(N'SCore.DataObjects', N'U') THEN 0 ELSE fk.is_disabled END) AS IsDisabled,";

    [Fact]
    public void ForeignKeySnapshot_IgnoresLifecycleOwnedDisabledStateInBothCopies()
    {
        var compare = File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["libs", "Concursus.EF", "SchemaMigration", "SchemaSnapshotSql.cs"]));
        var runner = File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["tools", "SchemaDeployment", "SchemaTargetSnapshot.R7D.sql"]));

        Assert.Contains(NormalisedIsDisabled, compare, StringComparison.Ordinal);
        Assert.Contains(NormalisedIsDisabled, runner, StringComparison.Ordinal);
        Assert.DoesNotContain("CONVERT(BIT, fk.is_disabled) AS IsDisabled", compare, StringComparison.Ordinal);
        Assert.DoesNotContain("CONVERT(BIT, fk.is_disabled) AS IsDisabled", runner, StringComparison.Ordinal);
    }
}
