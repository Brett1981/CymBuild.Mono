using Concursus.API.Classes;
using Concursus.EF.Types;
using Xunit;

namespace Concursus.API.Tests.Documents;

/// <summary>
/// CYB-323: gating and per-row merge-field rules for "Conditional Row" merge document items
/// (Fire Engineering Fee Proposal Table 1/2). Pure logic - no SQL, SharePoint or OpenXML.
/// </summary>
public sealed class ConditionalRowMergeEvaluatorTests
{
    private const int Gw1 = 10;
    private const int D12 = 11;
    private const int Dfs = 12;
    private const int Qdr = 13;

    private const int Stage2Id = 2;
    private const int Stage3Id = 3;
    private const int Stage4Id = 4;

    [Fact]
    public void ShouldKeepRow_NoRules_IsUnconditional()
    {
        Assert.True(ConditionalRowMergeEvaluator.ShouldKeepRow(
            new List<MergeDocumentItemGatingRule>(),
            new List<QuoteItemMergeLine>()));
    }

    [Fact]
    public void ShouldKeepRow_ProductNotOnQuote_RemovesRow()
    {
        var rules = new[] { Rule(Qdr) };
        var lines = new[] { Line(Dfs, Stage3Id, 3, 1000m) };

        Assert.False(ConditionalRowMergeEvaluator.ShouldKeepRow(rules, lines));
    }

    [Fact]
    public void ShouldKeepRow_AnyStageRule_MatchesProductAtAnyStage()
    {
        var rules = new[] { Rule(Qdr) };
        var lines = new[] { Line(Qdr, Stage4Id, 4, 500m) };

        Assert.True(ConditionalRowMergeEvaluator.ShouldKeepRow(rules, lines));
    }

    [Fact]
    public void ShouldKeepRow_StageRule_OnlyMatchesThatStage()
    {
        var stage3Row = new[] { Rule(Dfs, Stage3Id) };
        var stage4Row = new[] { Rule(Dfs, Stage4Id) };
        var lines = new[] { Line(Dfs, Stage3Id, 3, 4000m) };

        Assert.True(ConditionalRowMergeEvaluator.ShouldKeepRow(stage3Row, lines));
        Assert.False(ConditionalRowMergeEvaluator.ShouldKeepRow(stage4Row, lines));
    }

    [Fact]
    public void ShouldKeepRow_CombinedRow_KeptWhenEitherProductPresent()
    {
        var rules = new[] { Rule(Gw1, Stage2Id), Rule(D12, Stage2Id) };

        Assert.True(ConditionalRowMergeEvaluator.ShouldKeepRow(rules, new[] { Line(D12, Stage2Id, 2, 800m) }));
        Assert.True(ConditionalRowMergeEvaluator.ShouldKeepRow(rules, new[] { Line(Gw1, Stage2Id, 2, 900m) }));
        Assert.False(ConditionalRowMergeEvaluator.ShouldKeepRow(rules, new[] { Line(Dfs, Stage3Id, 3, 900m) }));
    }

    [Fact]
    public void BuildRowMergeFields_SumsOnlyMatchedLinesAndJoinsDeliverablesInQuoteOrder()
    {
        var rules = new[] { Rule(Gw1, Stage2Id), Rule(D12, Stage2Id) };
        var lines = new[]
        {
            Line(D12, Stage2Id, 2, 800m, "One D12 fire statement", sortOrder: 2),
            Line(Gw1, Stage2Id, 2, 1200.5m, "One Gateway One fire statement", sortOrder: 1),
            Line(Dfs, Stage3Id, 3, 4000m, "Fire safety strategy", sortOrder: 3)
        };

        var matched = ConditionalRowMergeEvaluator.GetMatchingLines(rules, lines);
        var fields = ToMap(ConditionalRowMergeEvaluator.BuildRowMergeFields("T1_GW1_D12", matched));

        Assert.Equal("£2,000.50", fields["T1_GW1_D12_Fee"]);
        Assert.Equal("One Gateway One fire statement; One D12 fire statement", fields["T1_GW1_D12_Deliverables"]);
    }

    [Fact]
    public void BuildRowMergeFields_DropsBlankAndDuplicateDeliverables()
    {
        var lines = new[]
        {
            Line(Dfs, Stage3Id, 3, 100m, "Fire safety strategy", sortOrder: 1),
            Line(Dfs, Stage3Id, 3, 100m, "fire safety strategy ", sortOrder: 2),
            Line(Dfs, Stage3Id, 3, 100m, "  ", sortOrder: 3)
        };

        var fields = ToMap(ConditionalRowMergeEvaluator.BuildRowMergeFields("T1_DFS3", lines));

        Assert.Equal("£300.00", fields["T1_DFS3_Fee"]);
        Assert.Equal("Fire safety strategy", fields["T1_DFS3_Deliverables"]);
    }

    [Fact]
    public void BuildStageSubtotalMergeFields_BlanksUnquotedStagesOneToSevenAndTotalsAllLines()
    {
        var lines = new[]
        {
            Line(Qdr, Stage2Id, 2, 500m),
            Line(Gw1, Stage2Id, 2, 1500m),
            Line(Dfs, Stage3Id, 3, 4000m),
            Line(Dfs, 99, 99, 250m)
        };

        var fields = ToMap(ConditionalRowMergeEvaluator.BuildStageSubtotalMergeFields(lines));

        Assert.Equal("", fields["FeeProposal_Stage1Subtotal"]);
        Assert.Equal("£2,000.00", fields["FeeProposal_Stage2Subtotal"]);
        Assert.Equal("£4,000.00", fields["FeeProposal_Stage3Subtotal"]);
        Assert.Equal("", fields["FeeProposal_Stage7Subtotal"]);
        Assert.Equal("£250.00", fields["FeeProposal_Stage99Subtotal"]);
        Assert.Equal("£6,250.00", fields["FeeProposal_TotalNet"]);
    }

    [Fact]
    public void BuildStageSubtotalMergeFields_QuotedStageWithZeroNetStillShowsZero()
    {
        var lines = new[] { Line(Dfs, Stage3Id, 3, 0m) };

        var fields = ToMap(ConditionalRowMergeEvaluator.BuildStageSubtotalMergeFields(lines));

        Assert.Equal("£0.00", fields["FeeProposal_Stage3Subtotal"]);
        Assert.Equal("", fields["FeeProposal_Stage4Subtotal"]);
    }

    [Fact]
    public void BuildStageSubtotalMergeFields_NoLinesStillEmitsEveryStageFieldAndAZeroTotal()
    {
        var fields = ToMap(ConditionalRowMergeEvaluator.BuildStageSubtotalMergeFields([]));

        Assert.All(Enumerable.Range(1, 7), stage => Assert.Equal("", fields[$"FeeProposal_Stage{stage}Subtotal"]));
        Assert.Equal("£0.00", fields["FeeProposal_TotalNet"]);
    }

    [Fact]
    public void MergeFields_UseTheNameValueShapeTheMergeEngineReads()
    {
        var fields = ConditionalRowMergeEvaluator.BuildRowMergeFields("Row", new List<QuoteItemMergeLine>());

        var map = Concursus.Common.Shared.Helpers.WordDocumentHelpers.BuildMergeFieldMap(fields);

        Assert.Equal("", map["Row_Fee"]);
        Assert.Equal("", map["Row_Deliverables"]);
    }

    [Theory]
    [InlineData("3", "3")]
    [InlineData("1", "1")]
    [InlineData("0", "1")]  // unrevised quote is issue 1
    [InlineData("-1", "1")]
    [InlineData("", "1")]
    [InlineData(null, "1")]
    public void BuildDocumentMergeFields_IssueNumberIsRevisionNumberWithAMinimumOfOne(string? revisionNumber, string expected)
    {
        var map = ToMap(ConditionalRowMergeEvaluator.BuildDocumentMergeFields(revisionNumber!, new DateTime(2026, 10, 1)));

        Assert.Equal(expected, map[ConditionalRowMergeEvaluator.IssueNumberFieldName]);
    }

    [Fact]
    public void BuildDocumentMergeFields_GeneratedDateIsUkFormat()
    {
        var map = ToMap(ConditionalRowMergeEvaluator.BuildDocumentMergeFields("0", new DateTime(2026, 3, 7, 23, 30, 0)));

        Assert.Equal("07/03/2026", map[ConditionalRowMergeEvaluator.GeneratedDateFieldName]);
    }

    // ---- CYB-323 Q1 option B: every quote item gets a row (catch-all rules, repeated rows).

    private const int Sit = 14;
    private const int Cdm = 15;
    private const int Stage1Id = 1;
    private const int Stage5Id = 5;
    private const int ConstructionId = 11;
    private const int CatchAll = ConditionalRowMergeEvaluator.CatchAllProductId;

    // Product rows for DFS at stages 3 and 4 and QDR at any stage, catch-all rows for stages
    // 1, 3 and 5, and an "other" catch-all for everything else.
    private static readonly MergeDocumentItemGatingRule[] DocumentRules =
    [
        Rule(Dfs, Stage3Id), Rule(Dfs, Stage4Id), Rule(Qdr),
        Rule(CatchAll, Stage1Id), Rule(CatchAll, Stage3Id), Rule(CatchAll, Stage5Id),
        Rule(CatchAll)
    ];

    [Fact]
    public void CatchAll_StageRule_TakesOnlyUnclaimedLinesAtThatStage()
    {
        var lines = new[]
        {
            Line(Dfs, Stage3Id, 3, 4000m),   // claimed by the DFS product rule
            Line(Sit, Stage3Id, 3, 1800m),   // unclaimed at stage 3
            Line(Sit, Stage1Id, 1, 900m)     // unclaimed, but stage 1
        };

        var matched = ConditionalRowMergeEvaluator.GetMatchingLines([Rule(CatchAll, Stage3Id)], lines, DocumentRules);

        Assert.Equal(1800m, Assert.Single(matched).LineNet);
    }

    [Fact]
    public void CatchAll_AnyStageProductRule_ClaimsLinesAtEveryStage()
    {
        var lines = new[] { Line(Qdr, Stage3Id, 3, 1500m) };

        Assert.False(ConditionalRowMergeEvaluator.ShouldKeepRow([Rule(CatchAll, Stage3Id)], lines, DocumentRules));
        Assert.False(ConditionalRowMergeEvaluator.ShouldKeepRow([Rule(CatchAll)], lines, DocumentRules));
    }

    [Fact]
    public void CatchAll_OtherRule_TakesLinesNoStageCatchAllCovers()
    {
        var lines = new[]
        {
            Line(Cdm, Stage5Id, 5, 700m),               // stage 5 catch-all
            Line(Cdm, ConstructionId, 999, 2000m),      // no stage catch-all: "other"
            Line(Dfs, Stage4Id, 4, 3000m)               // claimed by product rule
        };

        var matched = ConditionalRowMergeEvaluator.GetMatchingLines([Rule(CatchAll)], lines, DocumentRules);

        Assert.Equal(2000m, Assert.Single(matched).LineNet);
    }

    [Fact]
    public void CatchAll_EveryLineIsShownExactlyOnce()
    {
        var lines = new[]
        {
            Line(Qdr, Stage2Id, 2, 1500m), Line(Dfs, Stage3Id, 3, 4000m), Line(Sit, Stage3Id, 3, 1800m),
            Line(Sit, Stage1Id, 1, 900m), Line(Cdm, Stage5Id, 5, 700m), Line(Cdm, ConstructionId, 999, 2000m),
            Line(Dfs, Stage4Id, 4, 3000m), Line(Sit, Stage2Id, 2, 600m)
        };

        var shown = DocumentRules
            .Select(rule => new[] { rule })
            .SelectMany(rules => ConditionalRowMergeEvaluator.GetMatchingLines(rules, lines, DocumentRules))
            .ToList();

        // Stage 2's SIT line has no product rule and no stage 2 catch-all here, so it falls to
        // "other"; every line still appears exactly once and the shown rows add up to the total.
        Assert.Equal(lines.Length, shown.Count);
        Assert.Equal(lines.Sum(line => line.LineNet), shown.Sum(line => line.LineNet));
    }

    [Fact]
    public void CatchAll_WithoutDocumentRules_OnlySeesItsOwnRules()
    {
        var lines = new[] { Line(Sit, Stage3Id, 3, 1800m) };

        Assert.True(ConditionalRowMergeEvaluator.ShouldKeepRow([Rule(CatchAll, Stage3Id)], lines));
    }

    [Theory]
    [InlineData("FP_T1_S1_EACH", true)]
    [InlineData("fp_t1_s1_each", true)]
    [InlineData("FP_T1_S1_SUB", false)]
    [InlineData("FP_T1_S3_DFS", false)]
    public void IsRepeatRow_UsesTheEachSuffix(string bookmark, bool expected)
    {
        Assert.Equal(expected, ConditionalRowMergeEvaluator.IsRepeatRow(bookmark));
    }

    [Theory]
    [InlineData("FP_T2_S2_D12_KEEP", true)]
    [InlineData("fp_t2_s2_d12_keep", true)]
    [InlineData("FP_T2_S2_D12", false)]
    [InlineData("FP_T1_S1_EACH", false)]
    public void IsAlwaysKeepRow_UsesTheKeepSuffix(string bookmark, bool expected)
    {
        Assert.Equal(expected, ConditionalRowMergeEvaluator.IsAlwaysKeepRow(bookmark));
    }

    [Fact]
    public void AlwaysKeepRow_ProductNotOnQuote_KeptWithBlankFee()
    {
        // Jira 810439: the Table 2 D12 row is part of the invoice schedule, so it stays when
        // D12 isn't quoted (quote 3757), with no fee.
        var rules = new[] { Rule(D12, Stage2Id) };
        var lines = new[] { Line(Dfs, Stage3Id, 3, 5500m, "Fire safety strategy") };

        Assert.True(ConditionalRowMergeEvaluator.ShouldKeepRow("FP_T2_S2_D12_KEEP", rules, lines));
        Assert.False(ConditionalRowMergeEvaluator.ShouldKeepRow("FP_T2_S2_D12", rules, lines));

        var matched = ConditionalRowMergeEvaluator.GetMatchingLines(rules, lines);
        var fields = ToMap(ConditionalRowMergeEvaluator.BuildRowMergeFields("FP_T2_S2_D12_KEEP", matched));
        Assert.Equal("", fields["FP_T2_S2_D12_KEEP_Fee"]);
    }

    [Fact]
    public void AlwaysKeepRow_ProductQuoted_ShowsItsFee()
    {
        var rules = new[] { Rule(D12, Stage2Id) };
        var lines = new[]
        {
            Line(D12, Stage2Id, 2, 800m, "One D12 fire statement"),
            Line(Dfs, Stage3Id, 3, 5500m, "Fire safety strategy")
        };

        Assert.True(ConditionalRowMergeEvaluator.ShouldKeepRow("FP_T2_S2_D12_KEEP", rules, lines));

        var matched = ConditionalRowMergeEvaluator.GetMatchingLines(rules, lines);
        var fields = ToMap(ConditionalRowMergeEvaluator.BuildRowMergeFields("FP_T2_S2_D12_KEEP", matched));
        Assert.Equal("£800.00", fields["FP_T2_S2_D12_KEEP_Fee"]);
    }

    [Fact]
    public void BuildRepeatedRowMergeFields_OneNumberedPairPerLineInQuoteOrder()
    {
        var lines = new[]
        {
            Line(Sit, Stage1Id, 1, 900m, "Second item", sortOrder: 2),
            Line(Cdm, Stage1Id, 1, 1250.5m, "  First item  ", sortOrder: 1)
        };

        var fields = ConditionalRowMergeEvaluator.BuildRepeatedRowMergeFields("FP_T1_S1_EACH", lines)
            .ToDictionary(field => field["Name"], field => field["Value"]);

        Assert.Equal(4, fields.Count);
        Assert.Equal("First item", fields["FP_T1_S1_EACH_Deliverables_1"]);
        Assert.Equal("£1,250.50", fields["FP_T1_S1_EACH_Fee_1"]);
        Assert.Equal("Second item", fields["FP_T1_S1_EACH_Deliverables_2"]);
        Assert.Equal("£900.00", fields["FP_T1_S1_EACH_Fee_2"]);
    }

    private static MergeDocumentItemGatingRule Rule(int productId, int ribaStageId = -1) =>
        new() { ProductId = productId, RibaStageId = ribaStageId };

    private static QuoteItemMergeLine Line(
        int productId, int ribaStageId, int ribaStageNumber, decimal lineNet,
        string deliverable = "", int sortOrder = 0) =>
        new()
        {
            ProductId = productId,
            RibaStageId = ribaStageId,
            RibaStageNumber = ribaStageNumber,
            LineNet = lineNet,
            Deliverable = deliverable,
            SortOrder = sortOrder
        };

    private static Dictionary<string, string> ToMap(List<Dictionary<string, string>> fields) =>
        fields.ToDictionary(f => f["Name"], f => f["Value"]);
}
