using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// AGENTS.md: "Never update workflow status directly. Use SCore.DataObjectTransitionUpsert;
/// the latest transition is current state." libs/Concursus.EF/Core.cs was previously fixed
/// to stop doing a direct INSERT and call the stored procedure instead (see the
/// "IMPORTANT FIX" comment above ExecuteDataObjectTransitionUpsertAsync) - this gate exists
/// to stop that regression from being reintroduced anywhere in application code.
/// </summary>
public sealed class WorkflowStatusWriteBoundaryTests
{
    private static readonly Regex DirectTransitionWriteRegex = new(
        @"(INSERT(?:\s+INTO)?|UPDATE)\s+\[?SCore\]?\.\[?DataObjectTransition\]?",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    [Fact]
    public void ApplicationSource_DoesNotWriteDataObjectTransitionDirectly()
    {
        var violations = new List<string>();

        foreach (var projectDirectory in new[] { "apps", "libs", "services" })
        {
            foreach (var file in RepositoryLayout.EnumerateSourceFiles(projectDirectory))
            {
                var content = File.ReadAllText(file);
                if (DirectTransitionWriteRegex.IsMatch(content))
                {
                    violations.Add(Path.GetRelativePath(RepositoryLayout.Root, file));
                }
            }
        }

        Assert.True(
            violations.Count == 0,
            "Application code must transition workflow status only through SCore.DataObjectTransitionUpsert. "
            + "Direct INSERT/UPDATE against SCore.DataObjectTransition was found in:"
            + Environment.NewLine
            + string.Join(Environment.NewLine, violations));
    }
}
