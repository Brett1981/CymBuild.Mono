using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-554: Tasks-menu actions that write data behind a sibling grid on the same detail page
/// ("Create Quote(s)" on an Enquiry, "Create Job(s)" on a Quote) left that grid stale - the new
/// Quote / Job Number only appeared after a page reload. The fix has two halves that must both
/// stay in place: ButtonMenu raises GridUpdated after a successful (non-navigating) task action,
/// and each affected detail page handles GridUpdated by refreshing the grid that shows the
/// created record's number, rather than just forwarding the callback to its (often absent) parent.
/// </summary>
public sealed class Cyb554TaskMenuGridRefreshSourceContractTests
{
    [Fact]
    public void ButtonMenu_RaisesGridUpdatedAfterASuccessfulTaskAction()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Shared", "ButtonMenu.razor.cs"));

        Assert.Contains(
            "if (GridUpdated.HasDelegate)\n                            await GridUpdated.InvokeAsync();",
            source.Replace("\r\n", "\n"),
            StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("EnquiryDetail.razor", "_enquiryServicesGrid", "ENQUIRYSERVICES")]
    [InlineData("QuoteDetail.razor", "_quoteItemsGrid", "QUOTEITEMS")]
    public void DetailPage_RefreshesTheGridShowingTheCreatedRecordNumberOnGridUpdated(
        string pageFile,
        string gridField,
        string gridCode)
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Pages", pageFile));

        // The EditPage must route GridUpdated to the page's own handler, not straight through.
        Assert.Contains("GridUpdated=\"@HandleGridUpdated\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("GridUpdated=\"@GridUpdated\"", source, StringComparison.Ordinal);

        // The handler must reach the specific grid that displays the created record's number.
        Assert.Contains($"<DynamicGrid @ref=\"{gridField}\" FormHelper=\"@_formHelper\" GridCode=\"{gridCode}\"", source, StringComparison.Ordinal);
        Assert.Contains($"{gridField}?.RefreshGrid();", source, StringComparison.Ordinal);

        // And still forward the callback, so a windowed/parent host is notified as before.
        Assert.Contains("await GridUpdated.InvokeAsync();", source, StringComparison.Ordinal);
    }

    [Fact]
    public void FlexPropertyGroup_LetsRowFieldsShowingValidationWrapTheirFeedbackBelowTheControl()
    {
        // CYB-554 follow-up (Fee Amendment "Date Agreed"): the Row-group DATE / single-line text
        // rules force the input-group to nowrap, which kept ShoreInput's flex-basis 100%
        // invalid-feedback on the same line and squeezed a required, empty date input to ~0px.
        // The override must come after those nowrap rules so it wins at equal specificity.
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Shared", "FlexPropertyGroup.razor.css"))
            .Replace("\r\n", "\n");

        const string wrapOverride =
            ".flexpropertygroup-fields.is-row > .flexpropertygroup-field.is-validation-visible ::deep .input-group:not(.shore-input-multiline-group) {\n    flex-wrap: wrap !important;\n}";
        const string dateNowrap =
            ".flexpropertygroup-fields.is-row > .flexpropertygroup-field.is-date ::deep .input-group:not(.shore-input-multiline-group) {\n    display: flex !important;\n    flex-wrap: nowrap !important;";
        const string singleLineNowrap =
            ".flexpropertygroup-fields.is-row > .flexpropertygroup-field.is-singleline-text ::deep .input-group:not(.shore-input-multiline-group) {\n    display: flex !important;\n    flex-wrap: nowrap !important;";

        var overrideIndex = source.LastIndexOf(wrapOverride, StringComparison.Ordinal);
        Assert.True(overrideIndex >= 0, "Row validation wrap override is missing from FlexPropertyGroup.razor.css.");
        Assert.True(overrideIndex > source.LastIndexOf(dateNowrap, StringComparison.Ordinal), "Wrap override must follow the Row DATE nowrap rule.");
        Assert.True(overrideIndex > source.LastIndexOf(singleLineNowrap, StringComparison.Ordinal), "Wrap override must follow the Row single-line text nowrap rule.");
    }
}
