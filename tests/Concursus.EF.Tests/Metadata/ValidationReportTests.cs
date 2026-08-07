using Concursus.EF.MetadataManifests.ValidateOnly.Reporting;
using Xunit;

namespace Concursus.EF.Tests.Metadata;

public sealed class ValidationReportTests
{
    [Fact]
    public void FinalizeReport_CalculatesDeterministicSummaryAndExitCode()
    {
        var gridGuid = Guid.Parse("10000000-0000-0000-0000-000000000001");
        var viewGuid = Guid.Parse("20000000-0000-0000-0000-000000000002");
        var report = new ValidationReport
        {
            Environment = "QA",
            Family = "grids",
            Items =
            [
                CreateIssue(DriftSeverity.Warn, DriftType.UnexpectedUnmanagedRow, "Table.B", gridGuid, viewGuid, "actions"),
                CreateIssue(DriftSeverity.Fail, DriftType.Different, "Table.A", gridGuid, viewGuid, "columns"),
                CreateIssue(DriftSeverity.Info, DriftType.UnexpectedUnmanagedRow, "Table.B", gridGuid, viewGuid, "columns")
            ]
        };

        report.FinalizeReport();

        Assert.Equal(1, report.Summary.FailCount);
        Assert.Equal(1, report.Summary.WarnCount);
        Assert.Equal(1, report.Summary.InfoCount);
        Assert.Equal(2, report.Summary.ByType[nameof(DriftType.UnexpectedUnmanagedRow)]);
        Assert.Equal(1, report.Summary.ByType[nameof(DriftType.Different)]);
        Assert.Equal(2, report.GetExitCode());

        Assert.True(report.CiSummary.HasFailures);
        Assert.True(report.CiSummary.HasWarnings);
        Assert.True(report.CiSummary.HasInfo);
        Assert.Equal(2, report.CiSummary.ExitCode);
        Assert.Equal(new[] { "Table.A", "Table.B" }, report.CiSummary.ByTable.Keys);
        Assert.Equal(2, report.CiSummary.ByInternalsKind["columns"]);
        Assert.Equal(1, report.CiSummary.ByInternalsKind["actions"]);
        Assert.NotEqual(default, report.CompletedAtUtc);
    }

    [Fact]
    public void FinalizeReport_BuildsPerViewRollupsAndSortsViews()
    {
        var firstGrid = Guid.Parse("10000000-0000-0000-0000-000000000001");
        var secondGrid = Guid.Parse("10000000-0000-0000-0000-000000000002");
        var firstView = Guid.Parse("20000000-0000-0000-0000-000000000001");
        var secondView = Guid.Parse("20000000-0000-0000-0000-000000000002");
        var report = new ValidationReport
        {
            Items =
            [
                CreateIssue(DriftSeverity.Warn, DriftType.UnexpectedUnmanagedRow, "Table", secondGrid, secondView, "widgets"),
                CreateIssue(DriftSeverity.Fail, DriftType.Missing, "Table", firstGrid, firstView, "columns"),
                CreateIssue(DriftSeverity.Info, DriftType.UnexpectedUnmanagedRow, "Table", firstGrid, firstView, "columns")
            ],
            InternalsCounts = new InternalsCountsSection
            {
                Enabled = true,
                Views =
                [
                    new ViewInternalsCount { GridGuid = secondGrid, ViewGuid = secondView },
                    new ViewInternalsCount { GridGuid = firstGrid, ViewGuid = firstView }
                ]
            },
            InternalsValidation = new InternalsValidationSection
            {
                Enabled = true,
                Views =
                [
                    new ViewInternalsValidation { GridGuid = secondGrid, ViewGuid = secondView },
                    new ViewInternalsValidation { GridGuid = firstGrid, ViewGuid = firstView }
                ]
            }
        };

        report.FinalizeReport();

        Assert.Equal(2, report.ViewSummaries.Count);
        Assert.Equal(firstGrid, report.ViewSummaries[0].GridGuid);
        Assert.Equal(secondGrid, report.ViewSummaries[1].GridGuid);
        Assert.Equal(1, report.ViewSummaries[0].FailCount);
        Assert.Equal(1, report.ViewSummaries[0].InfoCount);
        Assert.Equal(2, report.ViewSummaries[0].ByInternalsKind["columns"]);

        Assert.Equal(firstGrid, report.InternalsCounts!.Views[0].GridGuid);
        Assert.Equal(firstGrid, report.InternalsValidation!.Views[0].GridGuid);
    }

    [Fact]
    public void FinalizeReport_NoFailuresReturnsZeroExitCode()
    {
        var report = new ValidationReport
        {
            Items =
            [
                new ValidationIssue { Severity = DriftSeverity.Info, Type = DriftType.UnexpectedUnmanagedRow },
                new ValidationIssue { Severity = DriftSeverity.Warn, Type = DriftType.UnexpectedUnmanagedRow }
            ]
        };

        report.FinalizeReport();

        Assert.Equal(0, report.GetExitCode());
        Assert.Equal(0, report.CiSummary.ExitCode);
        Assert.False(report.CiSummary.HasFailures);
    }

    private static ValidationIssue CreateIssue(
        DriftSeverity severity,
        DriftType type,
        string table,
        Guid gridGuid,
        Guid viewGuid,
        string internals)
    {
        return new ValidationIssue
        {
            Severity = severity,
            Type = type,
            Table = table,
            RecordGuid = Guid.NewGuid(),
            Details = new Dictionary<string, string>
            {
                ["gridGuid"] = gridGuid.ToString("D"),
                ["gridCode"] = $"Grid-{gridGuid:N}",
                ["viewGuid"] = viewGuid.ToString("D"),
                ["viewCode"] = $"View-{viewGuid:N}",
                ["internals"] = internals
            }
        };
    }
}
