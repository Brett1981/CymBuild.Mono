using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-572: SFin.InvoiceRequestUpsert gained required @IsWIP/@WIPReason parameters, but
// SJob.ActivityCreateInvoiceRequest still called it without them, so "Request Invoice" failed
// in every environment with "expects parameter '@IsWIP', which was not supplied". The metadata
// query was migrated correctly; the break was in the schema source itself. Every named-parameter
// EXEC between source-controlled procedures must supply each parameter the target procedure
// declares without a default, and must not pass a parameter the target no longer declares.
public sealed class ProcedureCallRequiredParameterSourceContractTests
{
    private static readonly Regex ProcedureDefinition = new(
        @"CREATE\s+(?:OR\s+ALTER\s+)?PROC(?:EDURE)?\s+\[?(?<schema>\w+)\]?\.\[?(?<name>\w+)\]?(?<parameters>.*?)\bAS\b\s",
        RegexOptions.IgnoreCase | RegexOptions.Singleline | RegexOptions.CultureInvariant);

    // One "@Name = value [OUTPUT]" argument. The value is a single token (string literal, number,
    // variable, keyword or function call), so a call ends where no comma follows - it cannot run on
    // into the next statement when the last argument has no terminating semicolon.
    private const string Argument =
        @"@\w+\s*=\s*(?:N?'(?:[^']|'')*'|[-+]?\d+(?:\.\d+)?|@\w+|\w+(?:\.\w+)*(?:\s*\([^()]*\))?)(?:\s+OUT(?:PUT)?\b)?";

    private static readonly Regex NamedCall = new(
        @"\bEXEC(?:UTE)?\s+(?:@\w+\s*=\s*)?\[?(?<schema>\w+)\]?\.\[?(?<name>\w+)\]?\s+(?<arguments>" + Argument + @"(?:\s*,\s*" + Argument + @")*)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    private static readonly Regex ArgumentName = new(@"(@\w+)\s*=\s*(?:N?'(?:[^']|'')*'|[^,]*)", RegexOptions.CultureInvariant);

    [Fact]
    public void ActivityCreateInvoiceRequest_SuppliesTheWipParameters()
    {
        var (breaks, _) = FindParameterBreaks();

        Assert.DoesNotContain(breaks, entry => entry.StartsWith("SJob.ActivityCreateInvoiceRequest ->", StringComparison.Ordinal));
    }

    [Fact]
    public void ProcedureCalls_SupplyEveryRequiredParameterAndNoUnknownOnes()
    {
        var (breaks, callsChecked) = FindParameterBreaks();

        // Guards the scan itself: a grammar that stopped matching would otherwise pass vacuously.
        Assert.True(callsChecked > 400, $"Only {callsChecked} procedure-to-procedure calls were recognised.");
        Assert.Empty(breaks);
    }

    private static (List<string> Breaks, int CallsChecked) FindParameterBreaks()
    {
        var sources = RepositoryLayout
            .EnumerateFilesByExtension(Path.Combine("Database", "CymBuild_DB", "Schema", "Programmability", "Procedures"), ".sql")
            .Select(path => StripComments(File.ReadAllText(path)))
            .ToArray();

        var procedures = new Dictionary<string, (string DisplayName, Dictionary<string, (string DisplayName, bool Required)> Parameters)>(StringComparer.OrdinalIgnoreCase);
        foreach (var source in sources)
        {
            var definition = ProcedureDefinition.Match(source);
            if (!definition.Success)
            {
                continue;
            }

            var parameters = new Dictionary<string, (string, bool)>(StringComparer.OrdinalIgnoreCase);
            foreach (var declaration in SplitParameterDeclarations(definition.Groups["parameters"].Value))
            {
                var parameter = Regex.Match(declaration, @"^\s*\(?\s*(@\w+)", RegexOptions.CultureInvariant);
                if (parameter.Success)
                {
                    // A table-valued (READONLY) parameter defaults to an empty table.
                    var required = !declaration.Contains('=', StringComparison.Ordinal)
                        && !Regex.IsMatch(declaration, @"\bREADONLY\b", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
                    parameters[parameter.Groups[1].Value] = (parameter.Groups[1].Value, required);
                }
            }

            var name = $"{definition.Groups["schema"].Value}.{definition.Groups["name"].Value}";
            procedures[name] = (name, parameters);
        }

        var breaks = new List<string>();
        var callsChecked = 0;
        foreach (var source in sources)
        {
            var caller = ProcedureDefinition.Match(source);
            if (!caller.Success)
            {
                continue;
            }

            var callerName = procedures[$"{caller.Groups["schema"].Value}.{caller.Groups["name"].Value}"].DisplayName;
            foreach (Match call in NamedCall.Matches(source))
            {
                if (!procedures.TryGetValue($"{call.Groups["schema"].Value}.{call.Groups["name"].Value}", out var target))
                {
                    continue;
                }

                callsChecked++;
                var supplied = ArgumentName
                    .Matches(call.Groups["arguments"].Value)
                    .Select(match => match.Groups[1].Value)
                    .ToHashSet(StringComparer.OrdinalIgnoreCase);
                var missing = target.Parameters.Values
                    .Where(parameter => parameter.Required && !supplied.Contains(parameter.DisplayName))
                    .Select(parameter => parameter.DisplayName)
                    .Order(StringComparer.OrdinalIgnoreCase)
                    .ToArray();
                var unknown = supplied
                    .Where(name => !target.Parameters.ContainsKey(name))
                    .Order(StringComparer.OrdinalIgnoreCase)
                    .ToArray();

                if (missing.Length > 0)
                {
                    breaks.Add($"{callerName} -> {target.DisplayName}: missing {string.Join(", ", missing)}");
                }

                if (unknown.Length > 0)
                {
                    breaks.Add($"{callerName} -> {target.DisplayName}: unknown {string.Join(", ", unknown)}");
                }
            }
        }

        return (breaks.Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToList(), callsChecked);
    }

    // Splits on commas outside type parentheses such as DECIMAL(19, 2). The list may itself be
    // wrapped in parentheses, so depth is counted relative to where the first parameter starts.
    private static IEnumerable<string> SplitParameterDeclarations(string parameterList)
    {
        var start = parameterList.IndexOf('@', StringComparison.Ordinal);
        if (start < 0)
        {
            yield break;
        }

        var depth = 0;
        var current = start;
        for (var index = start; index < parameterList.Length; index++)
        {
            switch (parameterList[index])
            {
                case '(':
                    depth++;
                    break;
                case ')' when depth > 0:
                    depth--;
                    break;
                case ')':
                    yield return parameterList[current..index];
                    yield break;
                case ',' when depth == 0:
                    yield return parameterList[current..index];
                    current = index + 1;
                    break;
            }
        }

        yield return parameterList[current..];
    }

    private static string StripComments(string sql)
    {
        var withoutBlocks = Regex.Replace(sql, @"/\*.*?\*/", string.Empty, RegexOptions.Singleline | RegexOptions.CultureInvariant);
        return Regex.Replace(withoutBlocks, @"--[^\n]*", string.Empty, RegexOptions.CultureInvariant);
    }
}
