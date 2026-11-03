using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-577: SAi.Assistant_EnsureEntityType's source had no GO between the procedure's END and the
// rest of its setup script, so 17 seed calls, 17 CREATE TABLEs, the foreign keys and the indexes
// were all compiled into the procedure body and re-ran on every call that created an entity type.
// Tables, keys and indexes are owned by Schema/Tables|Indexes|Constraints; a routine body must not
// create or alter permanent schema objects, or define another routine.
public sealed class RoutineBodySchemaDdlSourceContractTests
{
    private static readonly Regex Batch = new(@"^\s*GO\s*$", RegexOptions.IgnoreCase | RegexOptions.Multiline | RegexOptions.CultureInvariant);

    private static readonly Regex Routine = new(
        @"CREATE\s+(?:OR\s+ALTER\s+)?(?:PROC(?:EDURE)?|FUNCTION|TRIGGER)\s+\[?(?<schema>\w+)\]?\.\[?(?<name>\w+)\]?",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    // Permanent (schema-qualified, not #temp or @table) DDL, or a nested routine definition.
    private static readonly Regex SchemaDdl = new(
        @"\b(?:CREATE\s+TABLE\s+\[?\w+\]?\s*\.|ALTER\s+TABLE\s+\[?\w+\]?\s*\.|CREATE\s+(?:UNIQUE\s+)?(?:(?:NON)?CLUSTERED\s+)?INDEX\s+\[?\w+\]?\s+ON\s+\[?\w+\]?\s*\."
        + @"|CREATE\s+(?:OR\s+ALTER\s+)?(?:PROC(?:EDURE)?|FUNCTION|VIEW|TRIGGER)\b)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    [Fact]
    public void AssistantEnsureEntityType_BodyIsOnlyTheHelper()
    {
        var offenders = FindRoutinesWithSchemaDdl();

        Assert.DoesNotContain("SAi.Assistant_EnsureEntityType", offenders);
    }

    [Fact]
    public void RoutineBodies_DoNotCreateOrAlterPermanentSchemaObjects()
    {
        var offenders = FindRoutinesWithSchemaDdl();

        // CYB-578 removed the last exception, SCore.DataObjects_ResolveEntityTypeConflicts.
        Assert.Empty(offenders);
    }

    private static List<string> FindRoutinesWithSchemaDdl()
    {
        var offenders = new List<string>();
        foreach (var folder in new[] { "Procedures", "Functions", "Triggers" })
        {
            var files = RepositoryLayout.EnumerateFilesByExtension(
                Path.Combine("Database", "CymBuild_DB", "Schema", "Programmability", folder),
                ".sql");

            foreach (var file in files)
            {
                foreach (var batch in Batch.Split(StripCommentsAndStrings(File.ReadAllText(file))))
                {
                    var routine = Routine.Match(batch);
                    if (routine.Success && SchemaDdl.IsMatch(batch[(routine.Index + routine.Length)..]))
                    {
                        offenders.Add($"{routine.Groups["schema"].Value}.{routine.Groups["name"].Value}");
                    }
                }
            }
        }

        return offenders.Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToList();
    }

    // Dynamic SQL in string literals is not routine-body DDL, so literals are blanked too.
    private static string StripCommentsAndStrings(string sql)
    {
        var withoutBlocks = Regex.Replace(sql, @"/\*.*?\*/", string.Empty, RegexOptions.Singleline | RegexOptions.CultureInvariant);
        var withoutLines = Regex.Replace(withoutBlocks, @"--[^\n]*", string.Empty, RegexOptions.CultureInvariant);
        return Regex.Replace(withoutLines, @"N?'(?:[^']|'')*'", "''", RegexOptions.CultureInvariant);
    }
}
