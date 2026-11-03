using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

// Regression coverage for the "render handle is not yet assigned" crash on
// MultiColumnDynamicGridView (widget-dashboard grids).
//
// Root cause: MultiColumnDynamicGridView (@inherits DynamicGridView) declared
// its own private `_messageDisplay` field, bound by its own template's
// <MessageDisplay @ref="_messageDisplay">. That field shadowed the base
// class's field of the same name rather than reusing it. Because @inherits
// replaces the render tree, DynamicGridView.razor's own <MessageDisplay @ref>
// markup never rendered for a MultiColumnDynamicGridView instance, so the
// base class's field stayed an unattached placeholder `new MessageDisplay()`.
// DynamicGridView.OnError() always operates on the base class's own field, so
// calling StateHasChanged() on it via OnError()/ClearGridErrorState() threw
// "The render handle is not yet assigned" and crashed the component on the
// first load failure.
//
// Fix: the base field is `protected` (not `private`), and subclasses must not
// redeclare a field with the same name - they should bind their own
// <MessageDisplay @ref="_messageDisplay"> markup to the inherited field.
public sealed class DynamicGridViewMessageDisplaySourceContractTests
{
    private static readonly Regex MessageDisplayFieldDeclaration = new(
        @"(?<modifier>private|protected|public|internal)\s+MessageDisplay\s+_messageDisplay\b",
        RegexOptions.Compiled);

    [Fact]
    public void DynamicGridView_MessageDisplayField_IsProtectedSoSubclassesCanReuseIt()
    {
        var codeBehind = ReadPwaSharedFile("DynamicGridView.razor.cs");

        var match = MessageDisplayFieldDeclaration.Match(codeBehind);

        Assert.True(match.Success, "DynamicGridView.razor.cs must declare a `_messageDisplay` field.");
        Assert.Equal("protected", match.Groups["modifier"].Value);
    }

    [Fact]
    public void MultiColumnDynamicGridView_DoesNotShadowInheritedMessageDisplayField()
    {
        var codeBehind = ReadPwaSharedFile("MultiColumnDynamicGridView.razor.cs");

        Assert.False(
            MessageDisplayFieldDeclaration.IsMatch(codeBehind),
            "MultiColumnDynamicGridView must not redeclare a `_messageDisplay` field - doing so shadows " +
            "DynamicGridView's field instead of reusing it, leaving DynamicGridView.OnError() operating on an " +
            "unattached MessageDisplay placeholder (no RenderHandle) and crashing on the first load failure.");

        var razor = ReadPwaSharedFile("MultiColumnDynamicGridView.razor");
        Assert.Contains("@ref=\"_messageDisplay\"", razor, StringComparison.Ordinal);
    }

    [Fact]
    public void NoDynamicGridViewSubclassRedeclaresTheMessageDisplayField()
    {
        var subclassComponentNames = RepositoryLayout
            .EnumerateFilesByExtension("apps/Concursus.PWA/Shared", ".razor")
            .Where(path => File.ReadAllText(path).Contains("@inherits DynamicGridView", StringComparison.Ordinal))
            .Select(Path.GetFileNameWithoutExtension)
            .Where(name => !string.IsNullOrEmpty(name))
            .ToArray();

        Assert.NotEmpty(subclassComponentNames);

        foreach (var componentName in subclassComponentNames)
        {
            var codeBehind = ReadPwaSharedFile($"{componentName}.razor.cs");

            Assert.False(
                MessageDisplayFieldDeclaration.IsMatch(codeBehind),
                $"{componentName} inherits DynamicGridView and must not redeclare `_messageDisplay` - it must " +
                "reuse the protected field DynamicGridView.OnError() operates on.");
        }
    }

    private static string ReadPwaSharedFile(string fileName)
    {
        return File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "apps",
                "Concursus.PWA",
                "Shared",
                fileName));
    }
}
