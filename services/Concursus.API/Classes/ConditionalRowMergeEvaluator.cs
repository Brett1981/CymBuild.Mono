using System.Globalization;
using Concursus.EF.Types;

namespace Concursus.API.Classes
{
    /// <summary>
    /// CYB-323: pure logic behind "Conditional Row" merge document items - decides whether a
    /// bookmarked table row is kept for a quote, and builds the merge fields that row and the
    /// stage subtotals read. No SQL/SharePoint/OpenXML here so it can be unit tested directly;
    /// WordDocumentService.ProcessConditionalRowsAsync does the I/O.
    /// </summary>
    internal static class ConditionalRowMergeEvaluator
    {
        internal const string FeeFieldSuffix = "_Fee";
        internal const string DeliverablesFieldSuffix = "_Deliverables";
        internal const string StageSubtotalFieldFormat = "FeeProposal_Stage{0}Subtotal";
        internal const string TotalNetFieldName = "FeeProposal_TotalNet";
        internal const string IssueNumberFieldName = "FeeProposal_IssueNumber";
        internal const string GeneratedDateFieldName = "FeeProposal_GeneratedDate";

        /// <summary>
        /// A gating rule with this ProductId is a catch-all: it matches quote lines that no
        /// product rule in the document claims (CYB-323 Q1 option B - every quote item gets a
        /// row). With a RIBA stage it takes that stage's unclaimed lines; with RibaStageId -1 it
        /// takes whatever no product rule or stage catch-all has taken.
        /// </summary>
        internal const int CatchAllProductId = -1;

        /// <summary>
        /// A Conditional Row whose bookmark ends with this suffix is repeated once per matched
        /// quote line instead of showing them summed in one row.
        /// </summary>
        internal const string RepeatBookmarkSuffix = "_EACH";

        /// <summary>
        /// A Conditional Row whose bookmark ends with this suffix is always kept; its rules only
        /// supply the fee and deliverables, which are blank when nothing matches (CYB-323: the
        /// Table 2 D12 row is part of the invoice schedule, Jira 810439).
        /// </summary>
        internal const string AlwaysKeepBookmarkSuffix = "_KEEP";

        private static readonly CultureInfo MoneyCulture = CultureInfo.GetCultureInfo("en-GB");

        /// <summary>
        /// Quote lines matched by any of the rules. A product rule matches the same product, at
        /// the same RIBA stage unless its RibaStageId is -1 (any stage). A catch-all rule
        /// (CatchAllProductId) matches lines that no product rule in documentRules claims - at its
        /// stage, or, with RibaStageId -1, lines that no stage catch-all claims either.
        /// documentRules is every gating rule on the merge document; it defaults to rules.
        /// </summary>
        internal static List<QuoteItemMergeLine> GetMatchingLines(
            IReadOnlyCollection<MergeDocumentItemGatingRule> rules,
            IReadOnlyCollection<QuoteItemMergeLine> lines,
            IReadOnlyCollection<MergeDocumentItemGatingRule>? documentRules = null)
        {
            documentRules ??= rules;

            var productRules = documentRules.Where(rule => rule.ProductId != CatchAllProductId).ToList();
            var stageCatchAllIds = documentRules
                .Where(rule => rule.ProductId == CatchAllProductId && rule.RibaStageId != -1)
                .Select(rule => rule.RibaStageId)
                .ToHashSet();

            bool ClaimedByProduct(QuoteItemMergeLine line) =>
                productRules.Any(rule => MatchesProductRule(rule, line));

            return lines
                .Where(line => rules.Any(rule =>
                    rule.ProductId != CatchAllProductId
                        ? MatchesProductRule(rule, line)
                        : !ClaimedByProduct(line)
                          && (rule.RibaStageId == -1
                              ? !stageCatchAllIds.Contains(line.RibaStageId)
                              : rule.RibaStageId == line.RibaStageId)))
                .ToList();
        }

        /// <summary>
        /// A row with no rules is unconditional (always kept); otherwise it is kept when at
        /// least one quote line matches.
        /// </summary>
        internal static bool ShouldKeepRow(
            IReadOnlyCollection<MergeDocumentItemGatingRule> rules,
            IReadOnlyCollection<QuoteItemMergeLine> lines,
            IReadOnlyCollection<MergeDocumentItemGatingRule>? documentRules = null)
        {
            return rules.Count == 0 || GetMatchingLines(rules, lines, documentRules).Count > 0;
        }

        /// <summary>
        /// As ShouldKeepRow, except that an always-keep row (AlwaysKeepBookmarkSuffix) is kept
        /// whether or not anything matches.
        /// </summary>
        internal static bool ShouldKeepRow(
            string bookmarkName,
            IReadOnlyCollection<MergeDocumentItemGatingRule> rules,
            IReadOnlyCollection<QuoteItemMergeLine> lines,
            IReadOnlyCollection<MergeDocumentItemGatingRule>? documentRules = null)
        {
            return IsAlwaysKeepRow(bookmarkName) || ShouldKeepRow(rules, lines, documentRules);
        }

        internal static bool IsAlwaysKeepRow(string bookmarkName)
        {
            return bookmarkName.EndsWith(AlwaysKeepBookmarkSuffix, StringComparison.OrdinalIgnoreCase);
        }

        internal static bool IsRepeatRow(string bookmarkName)
        {
            return bookmarkName.EndsWith(RepeatBookmarkSuffix, StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>
        /// The merge field name a repeated row's copy uses: «{bookmark}_Fee» in the template
        /// becomes «{bookmark}_Fee_{copyNumber}» in copy copyNumber (1-based).
        /// </summary>
        internal static string RepeatFieldName(string fieldName, int copyNumber)
        {
            return string.Create(CultureInfo.InvariantCulture, $"{fieldName}_{copyNumber}");
        }

        /// <summary>
        /// One «{bookmark}_Fee_{n}» / «{bookmark}_Deliverables_{n}» pair per matched line, in
        /// quote order - the fields the n-th copy of a repeated row reads.
        /// </summary>
        internal static List<Dictionary<string, string>> BuildRepeatedRowMergeFields(
            string bookmarkName,
            IReadOnlyCollection<QuoteItemMergeLine> matchedLines)
        {
            return OrderForDocument(matchedLines)
                .SelectMany((line, index) => new[]
                {
                    MergeField(RepeatFieldName(bookmarkName + FeeFieldSuffix, index + 1), FormatMoney(line.LineNet)),
                    MergeField(RepeatFieldName(bookmarkName + DeliverablesFieldSuffix, index + 1), line.Deliverable?.Trim() ?? "")
                })
                .ToList();
        }

        /// <summary>Quote order: SortOrder, then the order the lines were read in.</summary>
        internal static List<QuoteItemMergeLine> OrderForDocument(IReadOnlyCollection<QuoteItemMergeLine> lines)
        {
            return lines.OrderBy(line => line.SortOrder).ToList();
        }

        private static bool MatchesProductRule(MergeDocumentItemGatingRule rule, QuoteItemMergeLine line)
        {
            return rule.ProductId == line.ProductId
                   && (rule.RibaStageId == -1 || rule.RibaStageId == line.RibaStageId);
        }

        /// <summary>
        /// «{bookmark}_Fee» = sum of the matched lines' net; «{bookmark}_Deliverables» = their
        /// distinct deliverable text in quote order, joined with "; " (combined rows such as
        /// Gateway One + D12 list both). The fee is blank when nothing matched (an always-keep row
        /// whose product isn't quoted).
        /// </summary>
        internal static List<Dictionary<string, string>> BuildRowMergeFields(
            string bookmarkName,
            IReadOnlyCollection<QuoteItemMergeLine> matchedLines)
        {
            string deliverables = string.Join("; ", matchedLines
                .OrderBy(line => line.SortOrder)
                .Select(line => line.Deliverable?.Trim() ?? "")
                .Where(text => text.Length > 0)
                .Distinct(StringComparer.OrdinalIgnoreCase));

            return new List<Dictionary<string, string>>
            {
                MergeField(bookmarkName + FeeFieldSuffix,
                    matchedLines.Count == 0 ? string.Empty : FormatMoney(matchedLines.Sum(line => line.LineNet))),
                MergeField(bookmarkName + DeliverablesFieldSuffix, deliverables)
            };
        }

        /// <summary>
        /// «FeeProposal_Stage{N}Subtotal» for RIBA stages 1-7 and any other stage number present
        /// on the quote, plus «FeeProposal_TotalNet». A stage with nothing quoted gets a blank
        /// subtotal rather than £0.00 (BA decision, CYB-323 Q2 option C); the field is still
        /// emitted so the template cell never shows an unresolved field.
        /// Pre-formatted because the merge engine does not apply MERGEFIELD \# picture switches.
        /// </summary>
        internal static List<Dictionary<string, string>> BuildStageSubtotalMergeFields(
            IReadOnlyCollection<QuoteItemMergeLine> lines)
        {
            var fields = Enumerable.Range(1, 7)
                .Union(lines.Select(line => line.RibaStageNumber))
                .OrderBy(stageNumber => stageNumber)
                .Select(stageNumber =>
                {
                    var stageLines = lines.Where(line => line.RibaStageNumber == stageNumber).ToList();
                    return MergeField(
                        string.Format(CultureInfo.InvariantCulture, StageSubtotalFieldFormat, stageNumber),
                        stageLines.Count == 0 ? string.Empty : FormatMoney(stageLines.Sum(line => line.LineNet)));
                })
                .ToList();

            fields.Add(MergeField(TotalNetFieldName, FormatMoney(lines.Sum(line => line.LineNet))));
            return fields;
        }

        /// <summary>
        /// «FeeProposal_IssueNumber»: the quote's RevisionNumber, shown as 1 when it is 0 or less
        /// (an unrevised quote is issue 1). «FeeProposal_GeneratedDate»: the date the document
        /// was generated, dd/MM/yyyy.
        /// </summary>
        internal static List<Dictionary<string, string>> BuildDocumentMergeFields(
            string revisionNumber,
            DateTime generatedOn)
        {
            int issueNumber = int.TryParse(revisionNumber, NumberStyles.Integer, CultureInfo.InvariantCulture, out int revision) && revision > 0
                ? revision
                : 1;

            return
            [
                MergeField(IssueNumberFieldName, issueNumber.ToString(CultureInfo.InvariantCulture)),
                MergeField(GeneratedDateFieldName, generatedOn.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture))
            ];
        }

        internal static string FormatMoney(decimal value)
        {
            return value.ToString("C2", MoneyCulture);
        }

        private static Dictionary<string, string> MergeField(string name, string value)
        {
            return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                { "Name", name },
                { "Value", value }
            };
        }
    }
}
