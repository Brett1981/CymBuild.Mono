using System.Text.RegularExpressions;
using System.Xml.Linq;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-537: Telerik has been removed from the whole solution (main app first, Outlook add-in as
/// the follow-up). These guards scan every project, source, markup, host page, script, style and
/// config file under apps/services/libs/tests and fail on any Telerik or Kendo reference that is
/// not inside a comment. Comments are stripped first on purpose: the removal left "CYB-537: X
/// removed" notes behind, and those are history, not dependencies.
/// <para>
/// A handful of non-comment leftovers are known and harmless; they are pinned below by exact
/// line so a NEW occurrence still fails. Delete an entry once its line is cleaned up.
/// </para>
/// </summary>
public sealed class Cyb537SolutionWideTelerikRemovalSourceContractTests
{
    private static readonly string[] ScannedRoots = ["apps", "services", "libs", "tests"];

    private static readonly string[] ProjectExtensions = [".csproj", ".props", ".targets"];

    private static readonly string[] TextExtensions =
        [".cs", ".razor", ".cshtml", ".html", ".js", ".css", ".json", ".config"];

    private static readonly (string File, string Line)[] KnownResidue =
    [
        // User-facing hint text on the structure map panel - wording only, no dependency.
        ("apps\\Concursus.PWA\\Pages\\StructureDetail.razor",
            "The Telerik map has been replaced with a native OpenStreetMap preview."),

        // Diagnostics counter that can only return 0 now that no .telerik-blazor elements exist.
        ("apps\\Concursus.PWA\\wwwroot\\memoryDiagnostics.js",
            "return document.querySelectorAll(\".telerik-blazor\").length;"),

        // Legacy jQuery Kendo grid lookups in the Outlook add-in. No #filingDestinationsGrid
        // element exists any more, so every one of these returns early (search runs natively in
        // Index.razor.cs LoadGridDataAsync). They never needed the Telerik package or licence.
        ("apps\\CymBuild_Outlook_Addin\\wwwroot\\js\\CymBuildFunctions.js",
            "var grid = $(\"#filingDestinationsGrid\").data(\"kendoGrid\");"),
        ("apps\\CymBuild_Outlook_Addin\\wwwroot\\js\\MessageFiler.js",
            "var grid = gridElement.data(\"kendoGrid\");"),
        ("apps\\CymBuild_Outlook_Addin\\wwwroot\\js\\MessageFiler.js",
            "var grid = $(\"#filingDestinationsGrid\").data(\"kendoGrid\");"),
    ];

    private static readonly Regex TelerikOrKendo = new("telerik|kendo", RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static readonly Regex[] CommentPatterns =
    [
        new(@"@\*.*?\*@", RegexOptions.Singleline | RegexOptions.Compiled),   // Razor
        new(@"<!--.*?-->", RegexOptions.Singleline | RegexOptions.Compiled),  // HTML/XML
        new(@"/\*.*?\*/", RegexOptions.Singleline | RegexOptions.Compiled),   // C#/JS/CSS block
        new(@"(?<![:""'])//[^\n]*", RegexOptions.Compiled),                   // C#/JS line (not URLs)
    ];

    [Fact]
    public void NoProjectOrBuildFile_ReferencesTelerikOutsideComments()
    {
        // Parsed as XML so comments are ignored structurally; element names, attribute values and
        // text all count, which covers PackageReference/PackageVersion/Reference/licence items.
        var offenders = new List<string>();

        foreach (var path in EnumerateScannedFiles(ProjectExtensions).Append(RepositoryLayout.PathFromRoot("Directory.Build.props")))
        {
            if (!File.Exists(path))
            {
                continue;
            }

            var document = XDocument.Load(path);
            var values = document.Descendants().SelectMany(element =>
                new[] { element.Name.LocalName }
                    .Concat(element.Attributes().Select(attribute => attribute.Value))
                    .Concat(element.Nodes().OfType<XText>().Select(text => text.Value)));

            offenders.AddRange(values
                .Where(value => TelerikOrKendo.IsMatch(value))
                .Select(value => $"{Relative(path)}: {value.Trim()}"));
        }

        Assert.Empty(offenders);
    }

    [Fact]
    public void NoSourceMarkupScriptOrStyleFile_ReferencesTelerikOrKendoOutsideComments()
    {
        var offenders = FindNonCommentOccurrences()
            .Where(hit => !KnownResidue.Contains(hit))
            .Select(hit => $"{hit.File}: {hit.Line}")
            .ToArray();

        Assert.Empty(offenders);
    }

    [Fact]
    public void KnownResidueAllowList_OnlyContainsLinesThatStillExist()
    {
        // Keeps the allow-list honest: once a leftover is cleaned up its entry must go too, so it
        // can't silently re-admit the same line later.
        var hits = FindNonCommentOccurrences().ToHashSet();

        var stale = KnownResidue
            .Where(entry => !hits.Contains(entry))
            .Select(entry => $"{entry.File}: {entry.Line}")
            .ToArray();

        Assert.Empty(stale);
    }

    private static IEnumerable<(string File, string Line)> FindNonCommentOccurrences()
    {
        foreach (var path in EnumerateScannedFiles(TextExtensions))
        {
            var content = CommentPatterns.Aggregate(File.ReadAllText(path), (text, pattern) => pattern.Replace(text, string.Empty));

            foreach (var line in content.Split('\n'))
            {
                if (TelerikOrKendo.IsMatch(line))
                {
                    yield return (Relative(path), line.Trim());
                }
            }
        }
    }

    private static IEnumerable<string> EnumerateScannedFiles(string[] extensions)
    {
        return ScannedRoots
            .SelectMany(root => RepositoryLayout.EnumerateFilesByExtension(root, extensions))
            .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}node_modules{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase)
                && !path.Contains($"{Path.DirectorySeparatorChar}TestResults{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
            .Where(path => !path.EndsWith(".min.js", StringComparison.OrdinalIgnoreCase)
                && !path.EndsWith(".min.css", StringComparison.OrdinalIgnoreCase))
            // These guards necessarily spell out the words they look for.
            .Where(path => !Path.GetFileName(path).StartsWith("Cyb537", StringComparison.OrdinalIgnoreCase));
    }

    private static string Relative(string path)
    {
        return Path.GetRelativePath(RepositoryLayout.Root, path).Replace('/', '\\');
    }
}
