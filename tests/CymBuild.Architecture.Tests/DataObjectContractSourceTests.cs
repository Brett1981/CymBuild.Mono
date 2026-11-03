using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// AGENTS.md: "Every managed entity insert must atomically create the corresponding
/// SCore.DataObjects row with the correct EntityTypeId." Confirms each known managed-entity
/// upsert procedure both creates its SCore.DataObjects row (via SCore.UpsertDataObject) and
/// inserts the entity row in the same procedure body, with the DataObjects call ordered first
/// so a later failure cannot leave an orphan entity row without a DataObjects row.
/// </summary>
public sealed class DataObjectContractSourceTests
{
    public static IEnumerable<object[]> ManagedEntityUpsertProcedures =>
    [
        [@"Database\CymBuild_DB\Schema\Programmability\Procedures\SJob.JobsUpsert.sql", "SJob", "INSERT SJob.Jobs"],
        [@"Database\CymBuild_DB\Schema\Programmability\Procedures\SSop.EnquiriesUpsert.sql", "SSop", "INSERT SSop.Enquiries"],
        [@"Database\CymBuild_DB\Schema\Programmability\Procedures\SSop.QuotesUpsert.sql", "SSop", "INSERT SSop.Quotes"]
    ];

    [Theory]
    [MemberData(nameof(ManagedEntityUpsertProcedures))]
    public void ManagedEntityUpsert_CreatesDataObjectBeforeInsertingEntityRow(
        string procedureRelativePath, string expectedSchemeName, string entityInsertToken)
    {
        var path = RepositoryLayout.PathFromRoot(procedureRelativePath.Split('\\'));
        var content = File.ReadAllText(path);

        var upsertDataObjectIndex = content.IndexOf("EXEC SCore.UpsertDataObject", StringComparison.Ordinal);
        Assert.True(
            upsertDataObjectIndex >= 0,
            $"{procedureRelativePath} must call SCore.UpsertDataObject to create its SCore.DataObjects row.");

        Assert.Contains($"@SchemeName = N'{expectedSchemeName}'", content, StringComparison.Ordinal);

        var entityInsertIndex = content.IndexOf(entityInsertToken, StringComparison.Ordinal);
        Assert.True(
            entityInsertIndex >= 0,
            $"{procedureRelativePath} must contain the expected entity insert '{entityInsertToken}'.");

        Assert.True(
            upsertDataObjectIndex < entityInsertIndex,
            $"{procedureRelativePath} must create the SCore.DataObjects row (SCore.UpsertDataObject) "
            + "before inserting the entity row, so a failure cannot leave an orphan entity row.");
    }
}
