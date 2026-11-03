using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-575: on the Fee Amendment form, fields jumped between half and full width as "Required"
/// messages appeared and cleared, because a field showing validation was forced onto its own full
/// row - by an inline style from FlexPropertyGroup.GetPropertyHostStyle, by "15C-R1" stylesheet
/// rules, and by the "15C-R3" :has(input.is-invalid) rule in cymbuild-v2.css. The CYB-554/575 wrap rule now drops the message below the control within the field's
/// normal width, so nothing may force a validating field to span the row. (Layout only - pinned as a
/// source contract; verified in the browser on CymBuild_Dev264 2026-10-08.)
/// </summary>
public sealed class Cyb575ValidationWidthSourceContractTests
{
    private static readonly Regex FullRowValidationRule = new(
        @"is-validation-visible[^{}]*\{[^}]*grid-column:\s*1\s*/\s*-1|:has\(\.(invalid-feedback|field-validation-error|validation-message)[^{}]*\{[^}]*grid-column:\s*1\s*/\s*-1|:has\([^{}()]*\.is-invalid\)[^{}]*\{[^}]*grid-column:\s*1\s*/\s*-1",
        RegexOptions.IgnoreCase);

    [Theory]
    [InlineData("apps", "Concursus.PWA", "Shared", "FlexPropertyGroup.razor.css")]
    [InlineData("libs", "Concursus.Components.Shared", "wwwroot", "css", "cymbuild-v2.css")]
    public void Stylesheets_DoNotForceAValidatingFieldOntoAFullRow(params string[] relativePath)
    {
        var source = Read(relativePath);

        Assert.DoesNotMatch(FullRowValidationRule, source);
    }

    [Fact]
    public void FlexPropertyGroup_KeepsTheWrapRuleThatDropsFeedbackBelowTheControl()
    {
        var source = Read("apps", "Concursus.PWA", "Shared", "FlexPropertyGroup.razor.css");

        Assert.Contains(
            ".flexpropertygroup-fields.is-row > .flexpropertygroup-field.is-validation-visible ::deep .input-group:not(.shore-input-multiline-group) {\n    flex-wrap: wrap !important;\n}",
            source,
            StringComparison.Ordinal);
    }

    [Fact]
    public void GetPropertyHostStyle_DoesNotSpanTheRowForInvalidFields()
    {
        var source = Read("apps", "Concursus.PWA", "Shared", "FlexPropertyGroup.razor.cs");
        var start = source.IndexOf("private string GetPropertyHostStyle(", StringComparison.Ordinal);
        Assert.True(start >= 0, "GetPropertyHostStyle not found.");
        var end = source.IndexOf("\n    }\n", start, StringComparison.Ordinal);
        var body = source[start..end];

        Assert.DoesNotContain("dataProperty.IsInvalid", body, StringComparison.Ordinal);
        Assert.DoesNotContain("grid-column: 1 / -1", body, StringComparison.Ordinal);
    }

    private static string Read(params string[] relativePath) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(relativePath)).Replace("\r\n", "\n");
}
