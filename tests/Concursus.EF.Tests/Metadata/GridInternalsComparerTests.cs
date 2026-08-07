using Concursus.EF.MetadataManifests.ValidateOnly.ManifestModels;
using Concursus.EF.MetadataManifests.ValidateOnly.Reporting;
using Concursus.EF.MetadataManifests.ValidateOnly.Sql;
using Concursus.EF.MetadataManifests.ValidateOnly.Validation;
using Xunit;

namespace Concursus.EF.Tests.Metadata;

public sealed class GridInternalsComparerTests
{
    private static readonly Guid GridGuid = Guid.Parse("10000000-0000-0000-0000-000000000001");
    private static readonly Guid ViewGuid = Guid.Parse("20000000-0000-0000-0000-000000000002");

    [Theory]
    [InlineData("QA", DriftSeverity.Warn)]
    [InlineData("qa", DriftSeverity.Warn)]
    [InlineData("UAT", DriftSeverity.Warn)]
    [InlineData("LIVE", DriftSeverity.Info)]
    [InlineData("PROD", DriftSeverity.Info)]
    [InlineData("DEV", DriftSeverity.Warn)]
    public void DefaultSeverityKnobs_ResolveEnvironmentDeterministically(
        string environment,
        DriftSeverity expected)
    {
        Assert.Equal(
            expected,
            GridInternalsComparer.GetUnmanagedSeverity(
                environment,
                GridInternalsComparer.GridInternalsSeverityKnobs.Default));
    }

    [Fact]
    public void NullColumnsManifest_TreatsRowsAsNotManagedYetWithoutMissingFailures()
    {
        var firstGuid = Guid.Parse("30000000-0000-0000-0000-000000000001");
        var secondGuid = Guid.Parse("30000000-0000-0000-0000-000000000002");
        var rows = new[]
        {
            CreateColumnRow(secondGuid),
            CreateColumnRow(firstGuid)
        };

        var issues = CompareColumns(manifestColumns: null, dbColumns: rows);

        Assert.Equal(2, issues.Count);
        Assert.All(issues, issue =>
        {
            Assert.Equal(DriftSeverity.Info, issue.Severity);
            Assert.Equal(DriftType.UnexpectedUnmanagedRow, issue.Type);
            Assert.Equal("columns", issue.Details!["internals"]);
        });
        Assert.Equal(firstGuid, issues[0].RecordGuid);
        Assert.Equal(secondGuid, issues[1].RecordGuid);
    }

    [Theory]
    [InlineData("QA", DriftSeverity.Warn)]
    [InlineData("UAT", DriftSeverity.Warn)]
    [InlineData("LIVE", DriftSeverity.Info)]
    public void EmptyManagedColumnsManifest_UsesEnvironmentSeverityForDatabaseOnlyRows(
        string environment,
        DriftSeverity expectedSeverity)
    {
        var issues = CompareColumns(
            environment,
            manifestColumns: Array.Empty<GridViewColumnDefinitionV1>(),
            dbColumns: [CreateColumnRow(Guid.NewGuid())]);

        var issue = Assert.Single(issues);
        Assert.Equal(expectedSeverity, issue.Severity);
        Assert.Equal(DriftType.UnexpectedUnmanagedRow, issue.Type);
    }

    [Fact]
    public void ManagedColumnMissingFromDatabase_IsFailingMissingDrift()
    {
        var columnGuid = Guid.NewGuid();
        var manifest = new[]
        {
            new GridViewColumnDefinitionV1 { Guid = columnGuid, Name = "JobNumber" }
        };

        var issue = Assert.Single(CompareColumns(manifestColumns: manifest, dbColumns: []));

        Assert.Equal(DriftSeverity.Fail, issue.Severity);
        Assert.Equal(DriftType.Missing, issue.Type);
        Assert.Equal(columnGuid, issue.RecordGuid);
    }

    [Fact]
    public void SuppliedDifferentProperty_IsFailingWhileOmittedPropertiesAreIgnored()
    {
        var columnGuid = Guid.NewGuid();
        var manifest = new[]
        {
            new GridViewColumnDefinitionV1
            {
                Guid = columnGuid,
                Name = "ExpectedName",
                RowStatus = null,
                ColumnOrder = null,
                IsHidden = null
            }
        };
        var database = new[]
        {
            CreateColumnRow(columnGuid, name: "DatabaseName", rowStatus: 254, columnOrder: 999, isHidden: true)
        };

        var issue = Assert.Single(CompareColumns(manifestColumns: manifest, dbColumns: database));

        Assert.Equal(DriftSeverity.Fail, issue.Severity);
        Assert.Equal(DriftType.Different, issue.Type);
        Assert.Contains("Name", issue.Message);
    }

    [Fact]
    public void MatchingSuppliedProperties_ProduceNoDrift()
    {
        var columnGuid = Guid.NewGuid();
        var manifest = new[]
        {
            new GridViewColumnDefinitionV1
            {
                Guid = columnGuid,
                Name = "JobNumber",
                RowStatus = 1,
                ColumnOrder = 3,
                IsHidden = false
            }
        };
        var database = new[]
        {
            CreateColumnRow(columnGuid, name: "JobNumber", rowStatus: 1, columnOrder: 3, isHidden: false)
        };

        Assert.Empty(CompareColumns(manifestColumns: manifest, dbColumns: database));
    }

    [Fact]
    public void InvalidLanguageLabelReference_IsFailingUnresolvableReference()
    {
        var columnGuid = Guid.NewGuid();
        var manifest = new[]
        {
            new GridViewColumnDefinitionV1
            {
                Guid = columnGuid,
                LanguageLabel = new RefV1
                {
                    RefTable = "SCore.LanguageLabels",
                    Key = "name",
                    Value = "Job number"
                }
            }
        };

        var issue = Assert.Single(CompareColumns(
            manifestColumns: manifest,
            dbColumns: [CreateColumnRow(columnGuid)]));

        Assert.Equal(DriftSeverity.Fail, issue.Severity);
        Assert.Equal(DriftType.UnresolvableReference, issue.Type);
    }

    [Fact]
    public void ResolvedLanguageLabelIdMismatch_IsFailingDifferentDrift()
    {
        var columnGuid = Guid.NewGuid();
        var labelGuid = Guid.NewGuid();
        var manifest = new[]
        {
            new GridViewColumnDefinitionV1
            {
                Guid = columnGuid,
                LanguageLabel = new RefV1
                {
                    RefTable = "SCore.LanguageLabels",
                    Key = "guid",
                    Value = labelGuid.ToString("D")
                }
            }
        };

        var issue = Assert.Single(CompareColumns(
            manifestColumns: manifest,
            dbColumns: [CreateColumnRow(columnGuid, languageLabelId: 99)],
            languageLabels: new Dictionary<Guid, int> { [labelGuid] = 12 }));

        Assert.Equal(DriftSeverity.Fail, issue.Severity);
        Assert.Equal(DriftType.Different, issue.Type);
        Assert.Contains("LanguageLabelId", issue.Message);
    }

    [Fact]
    public void ActionsAndWidgets_NullManifestUseNotManagedYetSeverity()
    {
        var actionIssues = GridInternalsComparer.CompareActions(
            "QA",
            GridInternalsComparer.GridInternalsSeverityKnobs.Default,
            GridGuid,
            "Jobs",
            ViewGuid,
            "Jobs.Default",
            null,
            [new GridViewActionRow { Guid = Guid.NewGuid() }],
            new Dictionary<Guid, int>(),
            new Dictionary<Guid, int>());

        var widgetIssues = GridInternalsComparer.CompareWidgets(
            "QA",
            GridInternalsComparer.GridInternalsSeverityKnobs.Default,
            GridGuid,
            "Jobs",
            ViewGuid,
            "Jobs.Default",
            null,
            [new GridViewWidgetRow { Guid = Guid.NewGuid() }],
            new Dictionary<Guid, int>(),
            new Dictionary<Guid, int>(),
            new Dictionary<Guid, short>());

        Assert.Equal(DriftSeverity.Info, Assert.Single(actionIssues).Severity);
        Assert.Equal(DriftSeverity.Info, Assert.Single(widgetIssues).Severity);
    }

    private static List<ValidationIssue> CompareColumns(
        IReadOnlyList<GridViewColumnDefinitionV1>? manifestColumns,
        IReadOnlyList<GridViewColumnRow> dbColumns,
        IReadOnlyDictionary<Guid, int>? languageLabels = null)
    {
        return CompareColumns("QA", manifestColumns, dbColumns, languageLabels);
    }

    private static List<ValidationIssue> CompareColumns(
        string environment,
        IReadOnlyList<GridViewColumnDefinitionV1>? manifestColumns,
        IReadOnlyList<GridViewColumnRow> dbColumns,
        IReadOnlyDictionary<Guid, int>? languageLabels = null)
    {
        return GridInternalsComparer.CompareColumns(
            environment,
            GridInternalsComparer.GridInternalsSeverityKnobs.Default,
            GridGuid,
            "Jobs",
            ViewGuid,
            "Jobs.Default",
            manifestColumns,
            dbColumns,
            languageLabels ?? new Dictionary<Guid, int>());
    }

    private static GridViewColumnRow CreateColumnRow(
        Guid guid,
        string name = "JobNumber",
        byte rowStatus = 1,
        int columnOrder = 1,
        bool isHidden = false,
        int languageLabelId = 1)
    {
        return new GridViewColumnRow
        {
            Guid = guid,
            Name = name,
            RowStatus = rowStatus,
            ColumnOrder = columnOrder,
            IsHidden = isHidden,
            LanguageLabelId = languageLabelId
        };
    }
}
