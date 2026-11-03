using System.Reflection;
using System.Text.Json;
using Concursus.API.Classes;
using Xunit;

namespace Concursus.API.Tests;

/// <summary>
/// CYB-537: binary-level proof that Telerik is gone from the gRPC API and everything it references, complementing the source scans
/// in CymBuild.Architecture.Tests. Source can look clean while a transitive package still ships a
/// Telerik assembly (and so still needs the Telerik feed and licence), so these check what was
/// actually compiled, resolved and copied: the assembly reference graph, the test host's
/// .deps.json, and the output directory.
/// </summary>
public sealed class Cyb537TelerikFreeBinariesTests
{
    [Fact]
    public void AssemblyReferenceGraph_ContainsNoTelerikAssembly()
    {
        Assert.Empty(FindTelerikReferences(typeof(WordDocumentService).Assembly));
    }

    [Fact]
    public void ResolvedDependencyManifest_ContainsNoTelerikPackage()
    {
        var depsFiles = (AppContext.GetData("APP_CONTEXT_DEPS_FILES") as string ?? string.Empty)
            .Split(';', StringSplitOptions.RemoveEmptyEntries)
            .Where(File.Exists)
            .ToArray();

        Assert.NotEmpty(depsFiles);

        var telerikLibraries = depsFiles
            .SelectMany(path =>
            {
                using var document = JsonDocument.Parse(File.ReadAllText(path));
                return document.RootElement.TryGetProperty("libraries", out var libraries)
                    ? libraries.EnumerateObject().Select(library => library.Name).ToArray()
                    : [];
            })
            .Where(IsTelerik)
            .ToArray();

        Assert.Empty(telerikLibraries);
    }

    [Fact]
    public void OutputDirectory_ContainsNoTelerikBinaries()
    {
        var telerikFiles = Directory
            .EnumerateFiles(AppContext.BaseDirectory, "*", SearchOption.AllDirectories)
            .Where(path => IsTelerik(Path.GetFileName(path)))
            .Select(path => Path.GetRelativePath(AppContext.BaseDirectory, path))
            .ToArray();

        Assert.Empty(telerikFiles);
    }

    private static IReadOnlyList<string> FindTelerikReferences(params Assembly[] roots)
    {
        var visited = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var pending = new Queue<Assembly>(roots);
        var offenders = new List<string>();

        while (pending.Count > 0)
        {
            var assembly = pending.Dequeue();
            if (!visited.Add(assembly.GetName().Name ?? string.Empty))
            {
                continue;
            }

            foreach (var reference in assembly.GetReferencedAssemblies())
            {
                if (IsTelerik(reference.Name))
                {
                    offenders.Add($"{assembly.GetName().Name} -> {reference.Name}");
                    continue;
                }

                if (visited.Contains(reference.Name ?? string.Empty))
                {
                    continue;
                }

                try
                {
                    pending.Enqueue(Assembly.Load(reference));
                }
                catch (Exception exception) when (exception is FileNotFoundException or FileLoadException or BadImageFormatException)
                {
                    // Platform-specific references (e.g. browser-only WASM shims) that are not
                    // deployed to the test host; their own names were already checked above.
                }
            }
        }

        return offenders;
    }

    private static bool IsTelerik(string? name)
    {
        return name is not null && name.StartsWith("Telerik", StringComparison.OrdinalIgnoreCase);
    }
}
