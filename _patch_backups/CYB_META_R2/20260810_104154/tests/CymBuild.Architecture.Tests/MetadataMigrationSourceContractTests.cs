using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

public sealed class MetadataMigrationSourceContractTests
{
    private static readonly string[] ControlledApplyTables =
    [
        "SCore.LanguageLabels",
        "SCore.LanguageLabelTranslations",
        "SCore.EntityDataTypes",
        "SCore.EntityTypes",
        "SCore.EntityHobts",
        "SCore.EntityPropertyGroups",
        "SCore.EntityQueries",
        "SCore.EntityProperties",
        "SCore.EntityQueryParameters",
        "SUserInterface.Icons",
        "SUserInterface.DropDownListDefinitions",
        "SUserInterface.GridDefinitions",
        "SUserInterface.GridViewDefinitions",
        "SUserInterface.GridViewColumnDefinitions"
    ];

    [Fact]
    public void MetadataValidation_FailsClosedForTablesWithoutApplyHandlers()
    {
        var sql = ReadProcedure("SMigration.MetadataValidate_Run.sql");

        Assert.Contains("N'UnsupportedApplyHandler'", sql, StringComparison.Ordinal);
        Assert.Contains("sr.DifferenceType IN (N'Insert', N'Update')", sql, StringComparison.Ordinal);
        Assert.Contains("SMigration.Metadata_IgnoredRecords", sql, StringComparison.Ordinal);
        Assert.Contains("SMigration.Metadata_IdentityMapOverrides", sql, StringComparison.Ordinal);

        AssertControlledTableAllowList(sql);
    }

    [Fact]
    public void MetadataApply_RechecksHandlerCoverageBeforeOpeningTransaction()
    {
        var sql = ReadProcedure("SMigration.MetadataApply_Run.sql");
        var guardPosition = sql.IndexOf("THROW 52005", StringComparison.Ordinal);
        var transactionPosition = sql.IndexOf("BEGIN TRANSACTION", StringComparison.Ordinal);

        Assert.True(guardPosition >= 0, "Metadata apply does not contain the unsupported-handler execution guard.");
        Assert.True(
            transactionPosition > guardPosition,
            "The unsupported-handler guard must run before MetadataApply_Run opens its deployment transaction.");
        Assert.Contains("ISNULL(@ApplySelectedOnly, 0) = 0", sql, StringComparison.Ordinal);
        Assert.Contains("SMigration.Metadata_RunSelections", sql, StringComparison.Ordinal);

        AssertControlledTableAllowList(sql);
    }

    private static string ReadProcedure(string fileName) =>
        File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "Database",
                "CymBuild_DB",
                "Schema",
                "Programmability",
                "Procedures",
                fileName));

    private static void AssertControlledTableAllowList(string sql)
    {
        foreach (var qualifiedTableName in ControlledApplyTables)
        {
            var parts = qualifiedTableName.Split('.', 2);
            Assert.Matches(
                new Regex(
                    $@"tr\.SchemaName\s*=\s*N'{Regex.Escape(parts[0])}'.*?N'{Regex.Escape(parts[1])}'",
                    RegexOptions.CultureInvariant | RegexOptions.Singleline),
                sql);
        }
    }
}
