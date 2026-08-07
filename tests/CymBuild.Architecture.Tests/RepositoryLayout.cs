using System.Xml.Linq;

namespace CymBuild.Architecture.Tests;

internal static class RepositoryLayout
{
    private static readonly Lazy<string> RootValue = new(FindRepositoryRoot);

    public static string Root => RootValue.Value;

    public static string PathFromRoot(params string[] segments)
    {
        return segments.Aggregate(Root, Path.Combine);
    }

    public static IReadOnlyList<string> GetProjectReferences(string projectRelativePath)
    {
        var projectPath = PathFromRoot(projectRelativePath.Split(new[] { '\\', '/' }, StringSplitOptions.RemoveEmptyEntries));
        var document = XDocument.Load(projectPath, LoadOptions.PreserveWhitespace);
        var projectDirectory = Path.GetDirectoryName(projectPath)
            ?? throw new InvalidOperationException($"Project directory could not be resolved for '{projectPath}'.");

        return document
            .Descendants()
            .Where(element => element.Name.LocalName == "ProjectReference")
            .Select(element => element.Attribute("Include")?.Value)
            .Where(include => !string.IsNullOrWhiteSpace(include))
            .Select(include => Path.GetFullPath(Path.Combine(projectDirectory, include!)))
            .Select(path => Path.GetRelativePath(Root, path).Replace('/', '\\'))
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public static IReadOnlyList<string> GetFastTestProjectPaths()
    {
        return Directory
            .EnumerateFiles(Root, "*.csproj", SearchOption.AllDirectories)
            .Where(path => !IsExcludedPath(path))
            .Where(path =>
            {
                var name = Path.GetFileNameWithoutExtension(path);
                return name.EndsWith("Tests", StringComparison.OrdinalIgnoreCase)
                    && !name.EndsWith("IntegrationTests", StringComparison.OrdinalIgnoreCase)
                    && !name.EndsWith("EndToEnd.Tests", StringComparison.OrdinalIgnoreCase);
            })
            .Select(path => Path.GetRelativePath(Root, path).Replace('/', '\\'))
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public static IEnumerable<string> EnumerateSourceFiles(string projectRelativeDirectory)
    {
        var directory = PathFromRoot(projectRelativeDirectory.Split(new[] { '\\', '/' }, StringSplitOptions.RemoveEmptyEntries));

        return Directory
            .EnumerateFiles(directory, "*", SearchOption.AllDirectories)
            .Where(path => path.EndsWith(".cs", StringComparison.OrdinalIgnoreCase)
                || path.EndsWith(".razor", StringComparison.OrdinalIgnoreCase))
            .Where(path => !IsExcludedPath(path));
    }

    private static bool IsExcludedPath(string path)
    {
        var relative = Path.GetRelativePath(Root, path).Replace('/', '\\');
        return relative.StartsWith("_patch_backups\\", StringComparison.OrdinalIgnoreCase)
            || relative.StartsWith("TestResults\\", StringComparison.OrdinalIgnoreCase)
            || relative.Contains("\\bin\\", StringComparison.OrdinalIgnoreCase)
            || relative.Contains("\\obj\\", StringComparison.OrdinalIgnoreCase)
            || relative.StartsWith("CYB", StringComparison.OrdinalIgnoreCase);
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "CymBuild.Monorepo.sln")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException(
            $"Could not locate CymBuild.Monorepo.sln above '{AppContext.BaseDirectory}'.");
    }
}
