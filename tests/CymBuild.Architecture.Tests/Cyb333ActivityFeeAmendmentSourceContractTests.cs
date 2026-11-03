using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-333: a billable activity answered "No" to "Is part of the agreed fee?" opens a new fee
/// amendment. The amendment itself is covered behaviourally by CymBuild.Database.IntegrationTests
/// ActivityFeeAmendmentEnsureTests. The field rules resolve their targets through entity metadata,
/// which the R4 SQL test database does not have, and the UI wiring has no component-test host, so
/// both are pinned here as source contracts.
/// </summary>
public sealed class Cyb333ActivityFeeAmendmentSourceContractTests
{
    [Fact]
    public void ActivitiesValidate_HidesTheAgreedFeeQuestionForNonBillableTypes_AndLocksItOnceAnAmendmentIsRaised()
    {
        var source = ReadSource("Database", "CymBuild_DB", "Schema", "Programmability", "Functions", "SJob.ActivitiesValidate.sql");

        var rules = Regex.Match(
            source,
            @"IF\s+NOT\s+EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+SJob\.ActivityTypes\s+AS\s+at\s+WHERE\s+\(at\.\[Guid\]\s*=\s*@ActivityTypeGuid\)\s+AND\s+\(at\.IsBillable\s*=\s*1\)\s*\)" +
            @"(?<hide>.*?)ELSE\s+IF\s+EXISTS\s*\((?<linked>.*?)\)\s*BEGIN(?<lock>.*?)END",
            RegexOptions.Singleline | RegexOptions.IgnoreCase);

        Assert.True(rules.Success, "CYB-333 IsPartOfAgreedFee rules not found in SJob.ActivitiesValidate.");
        AssertTargetsAgreedFeeQuestion(rules.Groups["hide"].Value, readOnly: "0", hidden: "1");
        Assert.Matches(@"fa\.ActivityID\s*=\s*a\.ID", rules.Groups["linked"].Value);
        Assert.Matches(@"fa\.RowStatus\s+NOT\s+IN\s*\(0,\s*254\)", rules.Groups["linked"].Value);
        AssertTargetsAgreedFeeQuestion(rules.Groups["lock"].Value, readOnly: "1", hidden: "0");
    }

    [Fact]
    public void ActivitiesValidate_RequiresTheJobStage_AndTheFeeWhereShown_WhenNotPartOfTheAgreedFee()
    {
        var source = ReadSource("Database", "CymBuild_DB", "Schema", "Programmability", "Functions", "SJob.ActivitiesValidate.sql");

        Assert.Matches(@"@ActivityTypeGuid\s+UNIQUEIDENTIFIER,\s*@RibaStageGuid\s+UNIQUEIDENTIFIER,[^\n]*\n\s*@IsPartOfAgreedFee\s+BIT", source);

        var rules = Regex.Match(
            source,
            @"IF\s+\(@IsPartOfAgreedFee\s*=\s*0\)\s+AND\s+\(EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+SJob\.ActivityTypes\s+AS\s+at\s+WHERE\s+\(at\.\[Guid\]\s*=\s*@ActivityTypeGuid\)\s+AND\s+\(at\.IsBillable\s*=\s*1\)\s*\)\s*\)\s*BEGIN" +
            @"(?<stage>.*?N'RibaStageId'\);\s*END)(?<fee>.*?)RETURN;",
            RegexOptions.Singleline);

        Assert.True(rules.Success, "CYB-333 required job stage / fee rules not found in SJob.ActivitiesValidate.");
        Assert.Matches(@"rs\.\[Guid\]\s*=\s*@RibaStageGuid\)\s+AND\s+\(rs\.ID\s*>\s*0\)", rules.Groups["stage"].Value);
        Assert.Matches(@"N'P',\s*0,\s*0,\s*1,\s*N'Select the job stage for the fee amendment\.'", rules.Groups["stage"].Value);

        var fee = rules.Groups["fee"].Value;
        Assert.Matches(@"(?s)SELECT\s+jt\.UseTimeSheets.*?\),\s*1\)\s*=\s*1\)", fee);
        Assert.Matches(@"(?s)ISNULL\(@InvoicingValue,\s*0\)\s*<=\s*0\).*?ISNULL\(@InvoicingQuantity,\s*0\)\s*<=\s*0\)", fee);
        Assert.Matches(@"N'P',\s*0,\s*0,\s*1,\s*N'Enter the Invoicing Value or Quantity for the fee amendment\.'", fee);
        Assert.Contains("epfvv.Name IN (N'InvoicingValue')", fee, StringComparison.Ordinal);
        Assert.DoesNotContain("N'InvoicingQuantity')", fee, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("ActivityDetail.razor")]
    [InlineData("JobActivityDetail.razor")]
    public void ActivityPages_OpenTheRaisedFeeAmendmentInAModalAfterSaving(string page)
    {
        var source = ReadSource("apps", "Concursus.PWA", "Pages", page);

        Assert.Contains("FormSavedPost=\"OpenRaisedFeeAmendmentAsync\"", source, StringComparison.Ordinal);
        Assert.Contains("@inject Concursus.Components.Shared.Modals.CymBuildModalService feeAmendmentModalService", source, StringComparison.Ordinal);
        Assert.Matches(
            @"Task\s+OpenRaisedFeeAmendmentAsync\(DataObject\s+savedActivity\)\s*=>\s*ActivityFeeAmendmentNavigation\.OpenRaisedFeeAmendmentAsync\(" +
            @"\s*new\s+API\.Client\.FormHelper\([^)]*\),\s*feeAmendmentModalService,\s*refreshService,\s*this,\s*savedActivity\);",
            source);
    }

    [Fact]
    public void FeeAmendmentModal_AsksTheServerAndOnlyOpensANewlyRaisedAmendment()
    {
        var source = ReadSource("apps", "Concursus.PWA", "Classes", "ActivityFeeAmendmentNavigation.cs");

        Assert.Contains("formHelper.ActivityFeeAmendmentEnsureAsync(activityGuid)", source, StringComparison.Ordinal);
        Assert.Matches(@"if\s*\(\s*!response\.WasCreated\s*\|\|", source);
        Assert.Contains("modalService.ShowWindowedEntityAsync<FeeAmendmentDetail>(", source, StringComparison.Ordinal);
        Assert.DoesNotContain("NavigateTo(", source, StringComparison.Ordinal);

        // The entity type must stay in step with the page the modal hosts.
        var page = ReadSource("apps", "Concursus.PWA", "Pages", "FeeAmendmentDetail.razor");
        var entityTypeGuid = Regex.Match(source, @"FeeAmendmentEntityTypeGuid\s*=\s*""(?<guid>[0-9a-fA-F-]{36})""").Groups["guid"].Value;
        Assert.Contains($"EntityTypeGuid=\"{entityTypeGuid}\"", page, StringComparison.Ordinal);
    }

    [Fact]
    public void FeeAmendmentModal_StacksAboveTheGridDetailPanel()
    {
        var source = ReadSource("apps", "Concursus.PWA", "wwwroot", "css", "app.css");

        Assert.Matches(
            @"\.cb-v2-modal-backdrop:has\(>\s*\.cb-v2-modal-activity-fee-amendment\)\s*\{\s*z-index:\s*2700;",
            source);
    }

    [Fact]
    public void EditPage_RunsFormSavedPostBeforeItsOwnPostSaveNavigation()
    {
        var source = ReadSource("apps", "Concursus.PWA", "Shared", "EditPage.razor.cs");

        Assert.Matches(
            @"if\s*\(\s*FormSavedPost\s*!=\s*null\s*&&\s*!HasValidationMessages\s*\)\s*\{\s*await\s+FormSavedPost\(dataObject\);\s*\}\s*" +
            @"await\s+ReloadDataForNewRecordAsync\(\);",
            source);
    }

    private static void AssertTargetsAgreedFeeQuestion(string block, string readOnly, string hidden)
    {
        var row = Regex.Match(
            block,
            @"SELECT\s+epfvv\.Guid,\s*N'P',\s*(?<readOnly>[01]),\s*(?<hidden>[01]),\s*(?<invalid>[01]),\s*N''\s+FROM\s+SCore\.EntityPropertiesForValidationV\s+AS\s+epfvv\s+" +
            @"WHERE\s+\(epfvv\.\[Schema\]\s*=\s*N'SJob'\)\s+AND\s+\(epfvv\.Hobt\s*=\s*N'Activities'\)\s+AND\s+\(epfvv\.Name\s*=\s*N'IsPartOfAgreedFee'\)",
            RegexOptions.IgnoreCase);

        Assert.True(row.Success, "IsPartOfAgreedFee validation row not found.");
        Assert.Equal(readOnly, row.Groups["readOnly"].Value);
        Assert.Equal(hidden, row.Groups["hidden"].Value);
        Assert.Equal("0", row.Groups["invalid"].Value);
    }

    private static string ReadSource(params string[] segments) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(segments)).Replace("\r\n", "\n");
}
