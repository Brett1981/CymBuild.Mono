using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

// LIVE 26.2 fixes missing from release/26.4 (Telerik removal rewrote the files they patched):
// CYB-473 3ff9c381, CYB-457 7e6fd5cf, CYB-469 43820dc7, CYB-468 bb13f397. Each one lets a child
// record or grid resolve the wrong (or no) parent record. Pinned so they cannot silently regress.
public sealed class Cyb473ParentRecordSourceContractTests
{
    [Fact]
    public void WindowedDetailFromAChildGrid_KeepsTheGridsParentRecord()
    {
        var source = Read("Shared", "DynamicGridView.razor.cs");

        var guard = source.IndexOf("CYB-473 (LIVE 26.2 fix 3ff9c381)", StringComparison.Ordinal);
        var registerModal = source.IndexOf("modalService.RegisterModal(modalId, parentDataObjectReference);", guard, StringComparison.Ordinal);

        Assert.True(guard >= 0, "The CYB-473 parent-reference override is missing from OnRowDoubleClickHandler.");
        Assert.True(registerModal > guard, "The override must run before the modal is registered.");
        Assert.Contains("parentDataObjectReference = ParentDataObjectReference;", source[guard..registerModal], StringComparison.Ordinal);
    }

    [Fact]
    public void EnsureCorrectParentGuid_KeepsOriginalRecordGuidInStep()
    {
        var source = Read("Shared", "EditPage.razor.cs");
        var method = source[source.IndexOf("private async Task EnsureCorrectParentGuid()", StringComparison.Ordinal)..];
        method = method[..method.IndexOf("protected override async Task OnInitializedAsync()", StringComparison.Ordinal)];

        Assert.Contains("stateService.OriginalRecordGuid = ParentGuid;", method, StringComparison.Ordinal);
    }

    [Fact]
    public void TasksMenu_IsNotRenderedBeforeTheRecordReferenceExists()
    {
        var markup = Read("Shared", "EditPage.razor");

        Assert.Matches(new Regex(@"@if \(!disableActions && MyDataObjectReference != null\)\s*\{\s*<div class=""form-action-menu"" id=""taskMenubtn"">"), markup);
    }

    [Theory]
    [InlineData("ContactDetail.razor", "CONTACTDETAILS")]
    [InlineData("ContactDetail.razor", "CONTACTJOBHISTORY")]
    [InlineData("AccountDetail.razor", "ACCOUNTADDRESSES")]
    [InlineData("AccountDetail.razor", "ACCOUNTCONTACTS")]
    [InlineData("AccountDetail.razor", "ACCOUNTMEMOS")]
    [InlineData("AccountDetail.razor", "ACCOUNTTRANSACTIONS")]
    [InlineData("AccountDetail.razor", "ACCOUNTFINANCEMEMO")]
    [InlineData("AccountDetail.razor", "ACCOUNTCONTRACTS")]
    [InlineData("AccountDetail.razor", "ACCOUNTJOBHISTORY")]
    public void ChildGrids_UseTheLoadedRecordGuid(string page, string gridCode)
    {
        var markup = Read("Pages", page);
        var grid = Regex.Match(markup, $@"<DynamicGrid GridCode=""{gridCode}""[^>]*>", RegexOptions.Singleline);

        Assert.True(grid.Success, $"{gridCode} grid not found in {page}.");
        Assert.Contains(@"ParentGuid=""@editPage.dataObject.Guid""", grid.Value, StringComparison.Ordinal);
    }

    private static string Read(string folder, string file) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(["apps", "Concursus.PWA", folder, file]));
}
