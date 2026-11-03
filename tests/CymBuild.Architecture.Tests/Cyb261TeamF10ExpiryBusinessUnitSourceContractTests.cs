using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-261 (LIVE 26.2 checkpoint dce858c4, missing from release/26.4): the JOBS/TEAMF10EXPIRYLIST
// grid view has Department and BusinessUnit columns (and BU/Department filters), but
// SJob.tvf_Jobs_TeamF10ExpiryList stopped returning them, so the columns were empty on every
// environment. Pinned so a stale DEV schema sync cannot drop them again.
public sealed class Cyb261TeamF10ExpiryBusinessUnitSourceContractTests
{
    [Fact]
    public void TeamF10ExpiryList_ReturnsDepartmentAndBusinessUnit()
    {
        var sql = File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["Database", "CymBuild_DB", "Schema", "Programmability", "Functions", "SJob.tvf_Jobs_TeamF10ExpiryList.sql"]));

        Assert.Matches(new Regex(@"org\.Name AS Department"), sql);
        Assert.Matches(new Regex(@"org2\.Name AS BusinessUnit"), sql);
        Assert.Matches(new Regex(@"JOIN SCore\.OrganisationalUnits AS org ON \(j\.OrganisationalUnitID = org\.ID\)"), sql);
        Assert.Matches(new Regex(@"JOIN SCore\.OrganisationalUnits AS org2 ON \(org\.ParentID = org2\.ID\)"), sql);
    }
}
