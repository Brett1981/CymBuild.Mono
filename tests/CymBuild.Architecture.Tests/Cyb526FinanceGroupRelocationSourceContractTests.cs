using Xunit;

namespace CymBuild.Architecture.Tests;

public sealed class Cyb526FinanceGroupRelocationSourceContractTests
{
    private const string FinancePropertyGroupGuid = "61dcf384-6a04-4738-91de-b462fe4172ea";

    [Fact]
    public void JobDetail_JobTabPanel_ExcludesFinanceGroupAndFeesTabPanelIncludesOnlyFinanceGroup()
    {
        var codeBehind = ReadJobDetailRazor();

        // The two computed lists are the only place the Finance/Fees split is expressed - no
        // metadata Guid or IsHidden change is involved, since EntityPropertyGroups has no tab
        // dimension of its own (see AGENTS.md: don't hard-code UI behaviour metadata already
        // controls - there's no metadata concept here to defer to).
        Assert.Contains(
            "Where(g => !string.Equals(g.Guid, FinancePropertyGroupGuid, StringComparison.OrdinalIgnoreCase))",
            codeBehind,
            StringComparison.Ordinal);

        // Anchored on "Where(g => " immediately before "string.Equals" (no "!") so this can't be
        // satisfied by matching a substring of the exclusion line above.
        Assert.Contains(
            "Where(g => string.Equals(g.Guid, FinancePropertyGroupGuid, StringComparison.OrdinalIgnoreCase))",
            codeBehind,
            StringComparison.Ordinal);
        Assert.Contains($"\"{FinancePropertyGroupGuid}\"", codeBehind, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void JobDetail_JobTabFlexPropertyGroups_BindsTheJobTabFilteredList()
    {
        var razor = ReadJobDetailRazor();

        Assert.Contains(
            "<FlexPropertyGroups @ref=\"@editPage.flexPropertyGroups\"",
            razor,
            StringComparison.Ordinal);
        Assert.Contains(
            "entityPropertyGroups=\"@JobTabPropertyGroups\"",
            razor,
            StringComparison.Ordinal);
    }

    [Fact]
    public void JobDetail_FeesTab_RendersASecondFlexPropertyGroupsBoundToTheFinanceFilteredList()
    {
        var razor = ReadJobDetailRazor();

        Assert.Contains(
            "<FlexPropertyGroups @ref=\"@_financeFlexPropertyGroups\"",
            razor,
            StringComparison.Ordinal);
        Assert.Contains(
            "entityPropertyGroups=\"@FeesTabPropertyGroups\"",
            razor,
            StringComparison.Ordinal);

        // "100%" (not a fixed rem value) so minmax(min(100%, 100%), 1fr) always resolves to
        // exactly one full-width track regardless of the page's root font-size or viewport -
        // a fixed rem value (e.g. "60rem") can still let auto-fill fit two tracks side by side
        // on a wide screen with a small root font-size, leaving an empty second column (verified
        // live: 13px root font-size meant 60rem = 780px, and a 1629px container fit two 780px
        // tracks even with only one FlexPropertyGroup card to place in them).
        Assert.Contains("MinColumnWidth=\"100%\"", razor, StringComparison.Ordinal);

        // The Finance panel must sit inside the Fees tab's panel section, not the Job tab's, and
        // specifically right after the JOBFEES grid - the second thing on the Fees tab, per the
        // reported requirement, not tacked on at the end after the PO grid.
        var jobPanelStart = razor.IndexOf("hidden=\"@(!IsNativeTabActive(JobDetailTab.Job))\"", StringComparison.Ordinal);
        var feesPanelStart = razor.IndexOf("hidden=\"@(!IsNativeTabActive(JobDetailTab.Fees))\"", StringComparison.Ordinal);
        var jobFeesGridIndex = razor.IndexOf("GridCode=\"JOBFEES\"", StringComparison.Ordinal);
        var financeMemoGridIndex = razor.IndexOf("GridCode=\"JOBFINANCEMEMO\"", StringComparison.Ordinal);
        var purchaseOrdersGridIndex = razor.IndexOf("GridCode=\"PURCHASEORDERS\"", StringComparison.Ordinal);
        var financePanelIndex = razor.IndexOf("@_financeFlexPropertyGroups", StringComparison.Ordinal);

        Assert.True(jobPanelStart >= 0 && feesPanelStart > jobPanelStart, "Fees tab panel must follow the Job tab panel.");
        Assert.True(
            financePanelIndex > feesPanelStart,
            "The Finance FlexPropertyGroups instance must be declared inside the Fees tab panel section.");
        Assert.True(
            jobFeesGridIndex >= 0 && financePanelIndex > jobFeesGridIndex && financePanelIndex < financeMemoGridIndex,
            "The Finance panel must render immediately after the JOBFEES grid (second on the Fees tab), not after it.");
        Assert.True(
            financePanelIndex < purchaseOrdersGridIndex,
            "The Finance panel must no longer be positioned after the PO grid.");
    }

    [Fact]
    public void JobDetail_OnAfterRenderAsync_RegistersTheFinancePanelIntoEditPagesExtraFlexPropertyGroups()
    {
        var razor = ReadJobDetailRazor();

        // The Fees tab (and its Finance panel) lazy-loads on first request, well after the page's
        // own firstRender, so registration can't be gated behind `if (!firstRender) return;` like
        // the rest of OnAfterRenderAsync's one-time setup.
        Assert.Contains(
            "editPage.ExtraFlexPropertyGroups.Add(_financeFlexPropertyGroups);",
            razor,
            StringComparison.Ordinal);

        var registrationIndex = razor.IndexOf("editPage.ExtraFlexPropertyGroups.Add", StringComparison.Ordinal);
        var firstRenderGuardIndex = razor.IndexOf("if (!firstRender) return;", StringComparison.Ordinal);

        Assert.True(
            registrationIndex >= 0 && firstRenderGuardIndex > registrationIndex,
            "Finance panel registration must run unconditionally, before the firstRender-only guard.");
    }

    [Fact]
    public void EditPage_BroadcastsRebindAndValidationStateToEveryRegisteredFlexPropertyGroupsInstance()
    {
        var editPage = ReadEditPageRazorCs();

        // A page with more than one FlexPropertyGroups panel (e.g. JobDetail's Job/Fees split)
        // relies on EditPage forwarding property-change rebinds and validation button state to
        // every registered instance, not just the single primary `flexPropertyGroups` ref -
        // otherwise edits in one panel silently fail to rebind derived/validation state into the
        // other.
        Assert.Contains(
            "[Parameter] public List<FlexPropertyGroups> ExtraFlexPropertyGroups { get; set; } = new();",
            editPage,
            StringComparison.Ordinal);
        Assert.Contains(
            "private IEnumerable<FlexPropertyGroups> AllFlexPropertyGroups() =>",
            editPage,
            StringComparison.Ordinal);
        Assert.Contains(
            "new[] { flexPropertyGroups }.Concat(ExtraFlexPropertyGroups).Where(fpg => fpg is not null);",
            editPage,
            StringComparison.Ordinal);

        Assert.Contains(
            "foreach (var fpg in AllFlexPropertyGroups()) fpg.ChangeValidationBtnText(\"Validated\", \"btn btn-success\");",
            editPage,
            StringComparison.Ordinal);
        Assert.Contains(
            "foreach (var fpg in AllFlexPropertyGroups()) fpg.RebindFromPropertyChange(inputUpdatedArgs);",
            editPage,
            StringComparison.Ordinal);

        // The old single-instance calls must be gone - a lingering one would mean a rebind path
        // was missed when this was split out.
        Assert.DoesNotContain("flexPropertyGroups.RebindFromPropertyChange(inputUpdatedArgs);", editPage, StringComparison.Ordinal);
        Assert.DoesNotContain("flexPropertyGroups?.ChangeValidationBtnText(\"Validated\", \"btn btn-success\");", editPage, StringComparison.Ordinal);
    }

    [Fact]
    public void FlexPropertyGroups_SupportsAnOptInWiderColumnForPanelsWithFewGroups()
    {
        var razor = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Shared", "FlexPropertyGroups.razor"));
        var codeBehind = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Shared", "FlexPropertyGroups.razor.cs"));

        // Default must stay exactly as before so every other page's layout is unchanged.
        Assert.Contains(
            "[Parameter] public string MinColumnWidth { get; set; } = \"30rem\";",
            codeBehind,
            StringComparison.Ordinal);
        Assert.Contains(
            "minmax(min(100%, @MinColumnWidth), 1fr)",
            razor,
            StringComparison.Ordinal);
    }

    [Fact]
    public void ShoreInput_ResolvesCascadingParentGuidFromItsDependencySourceBeforeFallingBackToTheRecordsOwnGuid()
    {
        // Normalise line endings once so the multi-line substring assertions below don't have to
        // guess whether the file was checked out with CRLF or LF.
        var codeBehind = ReadShoreInputRazorCs().Replace("\r\n", "\n");

        // FinanceAddressID/FinanceContactID are dependants of FinanceAccountID
        // (SCore.EntityPropertyDependants rows 27/28: ParentEntityPropertyID=1155 ->
        // DependantPropertyID=1156/1157), so on an existing record's initial load (before any
        // live edit fires RebindFromPropertyChange) ParentGuid must resolve from the parent
        // field's already-saved value, not fall straight to the current record's own guid -
        // which is wrong for a cross-entity cascade like Account -> Address/Contact.
        Assert.Contains("private string? ResolveParentGuidFromDependencySource()", codeBehind, StringComparison.Ordinal);
        Assert.Contains("p.DependantProperties.Any(d =>", codeBehind, StringComparison.Ordinal);

        Assert.Contains(
            "if (ParentGuid == Guid.Empty.ToString())\n            {\n                var resolvedParentGuid = ResolveParentGuidFromDependencySource();",
            codeBehind,
            StringComparison.Ordinal);
        Assert.Contains(
            "dropDownDataListRequest.ParentGuid = !string.IsNullOrWhiteSpace(resolvedParentGuid)\n                    ? resolvedParentGuid\n                    : stateService.OriginalRecordGuid;",
            codeBehind,
            StringComparison.Ordinal);
    }

    [Fact]
    public void FinanceAccountLookup_UpgradeScript_SetsDefaultSortColumnNameIdempotentlyByGuid()
    {
        var script = File.ReadAllText(RepositoryLayout.PathFromRoot(
            "Database", "CymBuild_DB", "Scripts", "Upgrade Scripts", "CYB-526_FinanceAccountLookup_DefaultSortOrder.sql"));

        // Guid-keyed (not the environment-specific numeric ID), guarded against soft-deleted
        // rows, and a no-op WHERE so re-running the script is safe (AGENTS.md: idempotent
        // metadata apply by stable Guid).
        Assert.Contains("0031902A-B82C-4B50-9B3D-194A5D30B931", script, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("ddld.RowStatus NOT IN (0, 254)", script, StringComparison.Ordinal);
        Assert.Contains("ISNULL(ddld.DefaultSortColumnName, N'') <> @SortColumnName", script, StringComparison.Ordinal);
        Assert.Contains("DefaultSortColumnName = @SortColumnName", script, StringComparison.Ordinal);
    }

    [Fact]
    public void ClientAgentAccountLookup_UpgradeScript_RemovesAmbiguousNameJoinsIdempotentlyByGuid()
    {
        var script = File.ReadAllText(RepositoryLayout.PathFromRoot(
            "Database", "CymBuild_DB", "Scripts", "Upgrade Scripts", "CYB-526_ClientAgentAccountLookup_AmbiguousNameFix.sql"));

        // The doc comment at the top intentionally quotes the OLD buggy query (with the joins)
        // as documentation of what's being fixed - scope the "joins are gone" assertions to the
        // executable body after that comment, not the whole file, or they'd trivially pass by
        // matching the comment's own description of the bug.
        var commentEndIndex = script.IndexOf("*/", StringComparison.Ordinal);
        Assert.True(commentEndIndex >= 0, "Expected a closing */ for the script's leading doc comment.");
        var executableBody = script[(commentEndIndex + 2)..];

        // LIVE_CRMACCOUNTS (backs ClientAccountID/AgentAccountID) had picked up two redundant
        // joins to SCrm.Accounts/SCrm.AccountStatus - neither contributes a selected column or a
        // WHERE condition, but SCrm.Accounts has its own Name column, so the generic dropdown
        // search-filter builder's unqualified `[Name]` reference (Core.CreatePropertyStatement
        // does not table-qualify columns) becomes ambiguous the moment a user types a search
        // term - confirmed live against CymBuild_DEV: "Ambiguous column name 'Name'." Fix drops
        // the two dead joins; TOP(20) is left alone since that part was never broken.
        Assert.Contains("057273BC-3784-4F65-B0BD-D860D27D0667", executableBody, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("JOIN SCrm.Accounts", executableBody, StringComparison.Ordinal);
        Assert.DoesNotContain("JOIN SCrm.AccountStatus", executableBody, StringComparison.Ordinal);
        Assert.Contains("SELECT TOP(20)", executableBody, StringComparison.Ordinal);
        Assert.Contains("ddld.RowStatus NOT IN (0, 254)", executableBody, StringComparison.Ordinal);
        Assert.Contains("ISNULL(ddld.SqlQuery, N'') <> @NewSqlQuery", executableBody, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("7A18B223-1408-4691-8E84-5A3BA2CCE266", "(SELECT ID, Guid, EntityTypeID FROM SCore.EntityQueries) eq")]
    [InlineData("BDE30F92-4CB9-4C53-A314-CB94747F0004", "(SELECT ID, Name AS StatusName FROM SCrm.AccountStatus) as acs")]
    [InlineData("C056AC1D-2A30-474F-B37F-7385D8EF3B89", "CONVERT(nvarchar(100), a.Number) + N'' - '' + a.FormattedAddressComma AS Name")]
    [InlineData("0031902A-B82C-4B50-9B3D-194A5D30B931", "(SELECT Guid, AccountStatusID FROM SCrm.Accounts) ac")]
    public void DropDownDefinitionsSweep_UpgradeScript_NarrowsEachAmbiguousJoinToOnlyItsUsedColumns(string guid, string expectedFragment)
    {
        var script = File.ReadAllText(RepositoryLayout.PathFromRoot(
            "Database", "CymBuild_DB", "Scripts", "Upgrade Scripts", "CYB-526_DropDownDefinitions_AmbiguousNameColumnSweep.sql"));

        // A full sweep (reproducing the app's own unqualified `[NameColumn]` search-filter shape
        // against every active DropDownListDefinition) found these 4 beyond the
        // already-fixed LIVE_CRMACCOUNTS: each has a JOIN'd table whose own real column shares
        // the dropdown's NameColumn name, so a search filter throws "Ambiguous column name"
        // instead of returning genuine matches. Every fix was verified directly against
        // CymBuild_DEV (search filter executes without error, returns the expected rows) before
        // being written here.
        Assert.Contains(guid, script, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(expectedFragment, script, StringComparison.Ordinal);
        Assert.Contains("ISNULL(ddld.SqlQuery, N'') <> @", script, StringComparison.Ordinal);
        Assert.Contains("ddld.RowStatus NOT IN (0, 254)", script, StringComparison.Ordinal);
    }

    private static string ReadJobDetailRazor()
    {
        return File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Pages", "JobDetail.razor"));
    }

    private static string ReadEditPageRazorCs()
    {
        return File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Shared", "EditPage.razor.cs"));
    }

    private static string ReadShoreInputRazorCs()
    {
        return File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Shared", "ShoreInput.razor.cs"));
    }
}
