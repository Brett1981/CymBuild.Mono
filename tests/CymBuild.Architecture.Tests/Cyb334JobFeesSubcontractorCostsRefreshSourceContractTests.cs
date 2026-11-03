using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-334: the Fee table (JOBFEES) Subcontractor Costs column is derived from the job's
/// Subcontractor Invoices and their Activity's RIBA stage. Saving an invoice or changing an
/// activity's stage refreshed only the Job shell, so the column stayed stale until a page reload.
/// The SUBCONTRACTOR and JOBACTIVITY grids must reload the JOBFEES grid when an action completes.
/// </summary>
public sealed class Cyb334JobFeesSubcontractorCostsRefreshSourceContractTests
{
    [Fact]
    public void JobDetail_HoldsAReferenceToTheJobFeesGrid()
    {
        var source = ReadJobDetail();

        Assert.Contains(
            "<DynamicGrid @ref=\"_jobFeesGrid\" FormHelper=\"@ActiveFormHelper\" GridCode=\"JOBFEES\"",
            source,
            StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("SUBCONTRACTOR", "OnSubcontractorActionCompletedAsync")]
    [InlineData("JOBACTIVITY", "OnActivityActionCompletedAsync")]
    public void JobDetail_GridActionRefreshesTheJobFeesGrid(string gridCode, string handler)
    {
        var source = ReadJobDetail();

        Assert.Matches(
            $@"GridCode=""{gridCode}""\s*\n\s*OnActionCompleted=""{handler}""",
            source);

        var handlerBody = Regex.Match(
            source,
            $@"private async Task {handler}\(\)\s*\{{(?<body>.*?)\n    \}}",
            RegexOptions.Singleline);

        Assert.True(handlerBody.Success, $"{handler} not found in JobDetail.razor.");
        Assert.Contains("_jobFeesGrid?.RefreshGrid();", handlerBody.Groups["body"].Value, StringComparison.Ordinal);
        Assert.Contains("await RefreshJobShellAsync(", handlerBody.Groups["body"].Value, StringComparison.Ordinal);
    }

    private static string ReadJobDetail() =>
        File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Pages", "JobDetail.razor"))
            .Replace("\r\n", "\n");
}
