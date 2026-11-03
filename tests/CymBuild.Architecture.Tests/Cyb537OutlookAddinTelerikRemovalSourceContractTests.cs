using System.Xml.Linq;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-537 follow-up: the main CymBuild solution had Telerik removed, but the Outlook add-in was
/// left out of scope and still pulled in Telerik.UI.for.Blazor, Telerik.Recurrence and
/// Telerik.Pivot.Core, registered AddTelerikBlazor(), wrapped its layout in TelerikRootComponent
/// and loaded the Kendo theme CSS / telerik-blazor.js from index.html. None of the add-in's pages
/// render a Telerik component, so all of it was infrastructure only. These guards stop it from
/// creeping back in, which would bring back the need for the Telerik NuGet feed and licence.
/// </summary>
public sealed class Cyb537OutlookAddinTelerikRemovalSourceContractTests
{
    private const string AddinDirectory = "apps/CymBuild_Outlook_Addin";

    [Theory]
    [InlineData("apps/CymBuild_Outlook_Addin/CymBuild_Outlook_Addin.csproj")]
    [InlineData("libs/CymBuild_Outlook_Common/CymBuild_Outlook_Common.csproj")]
    public void OutlookProjects_HaveNoTelerikPackageReferences(string projectRelativePath)
    {
        var projectPath = RepositoryLayout.PathFromRoot(projectRelativePath.Split('/'));
        var document = XDocument.Load(projectPath);

        var telerikPackages = document
            .Descendants()
            .Where(element => element.Name.LocalName == "PackageReference")
            .Select(element => element.Attribute("Include")?.Value ?? string.Empty)
            .Where(include => include.StartsWith("Telerik", StringComparison.OrdinalIgnoreCase))
            .ToArray();

        Assert.Empty(telerikPackages);
    }

    [Fact]
    public void OutlookAddin_SourceMarkupAndHostPages_DoNotReferenceTelerik()
    {
        // .cs/.razor cover the using, AddTelerikBlazor() and TelerikRootComponent; .html covers
        // the _content/Telerik.UI.for.Blazor theme stylesheet and script in both host pages.
        var offenders = RepositoryLayout
            .EnumerateFilesByExtension(AddinDirectory, ".cs", ".razor", ".html")
            .Where(path => File.ReadAllText(path).Contains("Telerik", StringComparison.OrdinalIgnoreCase))
            .Select(path => Path.GetRelativePath(RepositoryLayout.Root, path))
            .ToArray();

        Assert.Empty(offenders);
    }
}
