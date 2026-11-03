using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-526 follow-up (reported while smoke-testing the Finance panel relocation, but not scoped
/// to it - this is the shared DropDownDataList query builder used by every combo-box lookup in
/// the app): a dropdown's own stored query commonly starts "SELECT TOP(N) ...". Evaluated as-is,
/// that TOP(N) truncates to an ARBITRARY N rows before the ORDER BY appended afterwards ever
/// runs - T-SQL's TOP has no defined row order without an ORDER BY in the SAME SELECT. Confirmed
/// live against CymBuild_DEV: searching "Client" for "Electronic" (194 real matches) never
/// surfaced "Electronic Geek" or "Zenith Electronics" no matter how the list was scrolled,
/// because the arbitrary top-20 the database happened to pick was entirely "A+"/"Arrow" variants.
/// Fix: move TOP(N) to an outer wrapper applied AFTER filtering and sorting, only when the stored
/// query actually has one (SourceContractTests can't spin up a live DB - see
/// CYB323MergeDocumentQueryGuardTests.cs for this repo's established precedent for that
/// limitation; the SQL correctness itself was hand-verified against CymBuild_DEV for both the
/// broad "Electronic" search and the narrower "Geek" search).
/// </summary>
public sealed class Cyb526DropDownSearchTruncationSourceContractTests
{
    [Fact]
    public void DropDownDataList_MovesEmbeddedTopToAnOuterWrapperAppliedAfterFilteringAndSorting()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("libs", "Concursus.EF", "UserInterface.cs"));

        Assert.Contains(
            "var topMatch = Regex.Match(dataSqlQuery, @\"^(\\s*SELECT\\s+)TOP\\s*\\(\\s*(\\d+)\\s*\\)\\s*\", RegexOptions.IgnoreCase);",
            source,
            StringComparison.Ordinal);

        // The wrapped shape: TOP(N) only at the outermost SELECT, ORDER BY only after the
        // wrapped subquery - never inside the per-branch SELECTs that do the actual filtering.
        Assert.Contains(
            "finalSql = $\"SELECT TOP({topN}) * FROM ({innerSql}) AS combined {outerSort}\";",
            source,
            StringComparison.Ordinal);

        // The union-with-currently-selected-value branch must also use the un-TOP'd query, or
        // it would reintroduce a second, independent arbitrary-truncation point inside the
        // wrapper.
        Assert.Contains(
            "innerSql += $\" UNION {unTopSql} WHERE (root_hobt.Guid = @CurrentSelectedValueGuid)\";",
            source,
            StringComparison.Ordinal);

        // Queries with no embedded TOP(N) at all must be completely unaffected - same
        // concatenation as before, no wrapping overhead or behaviour change for the 99 of 120
        // active DropDownListDefinitions in CymBuild_DEV that don't use this pattern.
        Assert.Contains(
            "finalSql = dataSqlQuery + \" \" + sqlWhere;",
            source,
            StringComparison.Ordinal);
    }

    [Fact]
    public void DropDownDataList_GivesTheSelectedValueSortPriorityBeforeTheOuterTopReapplies()
    {
        // Follow-up to the above: unioning the selected value into the candidate set is not
        // enough on its own, because the outer "SELECT TOP({topN}) ... {sqlSort}" wrapper still
        // re-truncates the WHOLE combined set by the ordinary sort column alone. A selected
        // value that doesn't naturally rank inside the first {topN} rows (e.g. the Client/Agent
        // "LIVE_CRMACCOUNTS" lookup's TOP(20) sorted by Name, or the Finance
        // "LIVE_CRMSAGECOLOURAC" lookup's TOP(10) sorted by ConcatenatedNameCode - both reported
        // live: an already-set account not appearing/populating unless it happened to be in that
        // top page) is dropped by this second truncation exactly as if the UNION never ran.
        // Fix: give the selected row sort-priority 0 so TOP(N) can never cut it, whatever its
        // natural rank would otherwise be. Reasoned from the two dropdowns' actual deployed
        // queries quoted in CYB-526_FinanceAccountLookup_DefaultSortOrder.sql and
        // CYB-526_ClientAgentAccountLookup_AmbiguousNameFix.sql - not independently re-verified
        // against a live DB (SourceContractTests can't spin one up; unlike the sibling test
        // above, no live confirmation was performed for this follow-up).
        // Normalise line endings so the multi-line assertion below doesn't have to guess
        // whether the file was checked out with CRLF or LF (same approach as
        // Cyb526FinanceGroupRelocationSourceContractTests.ShoreInput_ResolvesCascadingParentGuidFromItsDependencySourceBeforeFallingBackToTheRecordsOwnGuid).
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot("libs", "Concursus.EF", "UserInterface.cs"))
            .Replace("\r\n", "\n");

        Assert.Contains(
            "var selectedPriority = \"CASE WHEN Guid = @CurrentSelectedValueGuid THEN 0 ELSE 1 END\";",
            source,
            StringComparison.Ordinal);

        // Falls back to ordering by priority alone when the dropdown has no
        // DefaultSortColumnName configured (sqlSort empty) - must not produce "ORDER BY ," or
        // otherwise malformed SQL.
        Assert.Contains(
            "outerSort = string.IsNullOrEmpty(sqlSort)\n                                    ? $\" ORDER BY {selectedPriority} \"\n                                    : sqlSort.Replace(\"ORDER BY \", $\"ORDER BY {selectedPriority}, \", StringComparison.OrdinalIgnoreCase);",
            source,
            StringComparison.Ordinal);

        // The priority boost only applies when there's a genuine selected value to protect -
        // an empty CurrentSelectedValueGuid must leave outerSort as the plain sqlSort, matching
        // pre-fix behaviour for the common case of a fresh, unset lookup.
        Assert.Contains("var outerSort = sqlSort;", source, StringComparison.Ordinal);
    }
}
