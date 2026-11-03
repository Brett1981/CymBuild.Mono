using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-485 (LIVE 26.2 fix 79e9e001, missing from release/26.4): the Workflow Statuses and Workflow
// Authorisation grids on WorkflowDetail must be bound to the workflow record. WORKFLOWAUTH's view
// is SCore.tvf_WorkflowStatusNotificationGroups([[UserId]], [[ParentGuid]]), so without a ParentGuid
// it ran for Guid.Empty and the Authorisation tab showed nothing. The old DrawerGuid binding was an
// always-empty string.
public sealed class Cyb485WorkflowDetailGridsSourceContractTests
{
    [Theory]
    [InlineData("WORKFLOWSTATUS")]
    [InlineData("WORKFLOWAUTH")]
    public void WorkflowGrids_AreBoundToTheWorkflowRecord(string gridCode)
    {
        var markup = File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["apps", "Concursus.PWA", "Pages", "WorkflowDetail.razor"]));

        var grid = Regex.Match(markup, $@"<DynamicGrid GridCode=""{gridCode}""[^>]*>", RegexOptions.Singleline);

        Assert.True(grid.Success, $"{gridCode} grid not found in WorkflowDetail.razor.");
        Assert.Contains(@"ParentGuid=""@RecordGuid""", grid.Value, StringComparison.Ordinal);
        Assert.Contains(@"ParentDataObjectReference=""@editPage.MyDataObjectReference""", grid.Value, StringComparison.Ordinal);
        Assert.Contains(@"ParentRowStatus=""@editPage.dataObject.RowStatus""", grid.Value, StringComparison.Ordinal);
        Assert.DoesNotContain("DrawerGuid", grid.Value, StringComparison.Ordinal);
    }
}
