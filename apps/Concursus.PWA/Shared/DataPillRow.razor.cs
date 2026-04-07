using Concursus.API.Core;
using Microsoft.AspNetCore.Components;
using System.Globalization;
using System.Text.Json;

namespace Concursus.PWA.Shared;

public partial class DataPillRow : ComponentBase
{
    // ---------------------------
    // Inputs
    // ---------------------------
    [Parameter] public List<DataPill>? DataPills { get; set; }

    // Jobs-only toggle (you already pass this from the parent)
    [Parameter] public bool ShowFinancialOverview { get; set; } = false;

    // Needed to load the FINANCE grid
    [Parameter] public string DrawerGuid { get; set; } = Guid.Empty.ToString();

    // Grid code is configurable but defaults to what you specified
    [Parameter] public string OverdueGridCode { get; set; } = "FINANCE";

    // Optional: parent can also react, but we’ll open modal by default
    [Parameter] public EventCallback ViewOverdueInvoicesRequested { get; set; }

    [Parameter] public string? InvoiceProcessingModeText { get; set; }   // e.g. "Paused"
    [Parameter] public string? InvoiceProcessingModeCss { get; set; }    // e.g. "mode-paused"
    [Parameter] public string? InvoiceProcessingModeTooltip { get; set; } // optional

    // ---------------------------
    // State
    // ---------------------------
    private bool IsExpanded { get; set; } = true; // DEFAULT EXPANDED
    private bool ShowOverdueModal { get; set; } = false;
    private bool IsGridLoading { get; set; } = false;

    // ---------------------------
    // Derived lists
    // ---------------------------
    private List<DataPill> GeneralPills =>
        (DataPills ?? new List<DataPill>())
            .Where(p => !(p.Class?.Contains("financial-data") ?? false) &&
                        !(p.Class?.Contains("financial-json") ?? false))
            .ToList();

    private List<DataPill> FinancialPills =>
        (DataPills ?? new List<DataPill>())
            .Where(p => (p.Class?.Contains("financial-data") ?? false) ||
                        (p.Class?.Contains("financial-json") ?? false))
            .ToList();

    // Option C:
    // - Prefer ONE "financial-json" pill that contains the whole finance overview model.
    // - Fallback to legacy "Label: £X" pills for backwards compatibility.
    private List<FinanceCard> FinanceCards => BuildFinanceCards(FinancialPills);

    private bool HasAnyOverdue =>
        FinanceCards.Any(c => c.Kind == FinanceCardKind.OverdueBucket && c.Amount > 0);

    private string SummaryText
    {
        get
        {
            var outstanding = FinanceCards.FirstOrDefault(c => c.Kind == FinanceCardKind.Outstanding)?.Amount ?? 0m;
            var overdueTotal = FinanceCards
                .Where(c => c.Kind == FinanceCardKind.OverdueBucket)
                .Sum(c => c.Amount);

            if (overdueTotal > 0)
                return $"Outstanding {FormatMoney(outstanding)} • Overdue {FormatMoney(overdueTotal)}";

            return $"Outstanding {FormatMoney(outstanding)}";
        }
    }

    protected override void OnParametersSet()
    {
        // If it is shown (Jobs), default to expanded.
        if (ShowFinancialOverview)
            IsExpanded = true;

        // If it’s not Jobs, ensure we don’t leave the modal open
        if (!ShowFinancialOverview)
            ShowOverdueModal = false;
    }

    private void ToggleExpanded()
    {
        IsExpanded = !IsExpanded;
    }

    private async Task OnViewOverdueClicked()
    {
        // If the parent wants to handle it, let it.
        // Otherwise show the modal with the FINANCE grid.
        if (ViewOverdueInvoicesRequested.HasDelegate)
        {
            await ViewOverdueInvoicesRequested.InvokeAsync();
            return;
        }

        ShowOverdueModal = true;
        StateHasChanged();
    }

    private void CloseOverdueModal()
    {
        ShowOverdueModal = false;
        StateHasChanged();
    }

    private string GetBadgeClasses(DataPill p)
    {
        // Preserve your existing badge look for non-financial pills
        var cls = p.Class ?? "";
        return $"badge rounded-pill m-2 {cls}";
    }

    private string BuildTooltip(FinanceCard c)
    {
        // If we have structured tooltip info (from JSON), show it.
        if (!string.IsNullOrWhiteSpace(c.Tooltip))
            return c.Tooltip;

        // fallback
        return $"{c.Title}: {FormatMoney(c.Amount)}";
    }

    private static string FormatMoney(decimal amount)
        => amount.ToString("C2", CultureInfo.GetCultureInfo("en-GB"));

    private static decimal ParseMoney(string s)
    {
        if (string.IsNullOrWhiteSpace(s)) return 0m;

        var cleaned = new string(s.Where(ch => char.IsDigit(ch) || ch == '.' || ch == '-').ToArray());

        if (decimal.TryParse(cleaned, NumberStyles.Any, CultureInfo.InvariantCulture, out var v))
            return v;

        return 0m;
    }

    private List<FinanceCard> BuildFinanceCards(List<DataPill> financialPills)
    {
        var pills = financialPills ?? new List<DataPill>();

        // 1) Prefer JSON model if present
        var jsonPill = pills.FirstOrDefault(p => (p.Class?.Contains("financial-json") ?? false));
        if (jsonPill?.Value is { Length: > 2 } json && json.TrimStart().StartsWith("{"))
        {
            var cardsFromJson = TryBuildFromJson(json);
            if (cardsFromJson.Count > 0)
                return cardsFromJson;
        }

        // 2) Legacy fallback: "Label: £X"
        var cards = new List<FinanceCard>();

        foreach (var p in pills.Where(p => (p.Class?.Contains("financial-data") ?? false)))
        {
            var raw = p.Value ?? "";
            if (string.IsNullOrWhiteSpace(raw)) continue;

            var parts = raw.Split(':', 2, StringSplitOptions.TrimEntries);
            var label = parts.Length > 0 ? parts[0].Trim() : raw.Trim();
            var valuePart = parts.Length > 1 ? parts[1].Trim() : "";

            var amount = ParseMoney(valuePart);

            if (label.Equals("Amount not invoiced", StringComparison.OrdinalIgnoreCase))
            {
                cards.Add(new FinanceCard(FinanceCardKind.NotInvoiced, "🧾", "Amount not invoiced", amount, "Awaiting invoice creation", "neutral"));
            }
            else if (label.Equals("Outstanding amount", StringComparison.OrdinalIgnoreCase))
            {
                cards.Add(new FinanceCard(FinanceCardKind.Outstanding, "📌", "Outstanding amount", amount, "Total unpaid balance", "neutral"));
            }
            else if (label.StartsWith("Overdue_", StringComparison.OrdinalIgnoreCase))
            {
                var nice = label switch
                {
                    "Overdue_1_30" => "Overdue (1–30 days)",
                    "Overdue_31_60" => "Overdue (31–60 days)",
                    "Overdue_61_90" => "Overdue (61–90 days)",
                    "Overdue_90+" => "Overdue (90+ days)",
                    _ => label.Replace('_', ' ')
                };

                var emphasis = amount > 0 ? "overdue" : "neutral";

                cards.Add(new FinanceCard(FinanceCardKind.OverdueBucket, "⏰", nice, amount, "Aging bucket", emphasis));
            }
        }

        return cards
            .OrderBy(c => c.Kind switch
            {
                FinanceCardKind.NotInvoiced => 1,
                FinanceCardKind.Outstanding => 2,
                FinanceCardKind.OverdueBucket => 3,
                _ => 9
            })
            .ThenBy(c => c.Title)
            .ToList();
    }

    private List<FinanceCard> TryBuildFromJson(string json)
    {
        try
        {
            var model = JsonSerializer.Deserialize<FinanceOverviewJson>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (model is null) return new();

            var cards = new List<FinanceCard>
            {
                new(FinanceCardKind.NotInvoiced, "🧾", "Amount not invoiced", model.NotInvoicedAmount, "Awaiting invoice creation", "neutral",
                    BuildBucketTooltip("Not invoiced", model.NotInvoicedAmount, model.NotInvoicedOldestDueDate, model.NotInvoicedMaxDaysOverdue, model.NotInvoicedCount)),

                new(FinanceCardKind.Outstanding, "📌", "Outstanding amount", model.OutstandingAmount, "Total unpaid balance", "neutral",
                    BuildBucketTooltip("Outstanding", model.OutstandingAmount, model.OutstandingOldestDueDate, model.OutstandingMaxDaysOverdue, model.OutstandingCount))
            };

            foreach (var b in (model.OverdueBuckets ?? new List<OverdueBucketJson>()))
            {
                var nice = b.Key switch
                {
                    "Overdue_1_30" => "Overdue (1–30 days)",
                    "Overdue_31_60" => "Overdue (31–60 days)",
                    "Overdue_61_90" => "Overdue (61–90 days)",
                    "Overdue_90Plus" => "Overdue (90+ days)",
                    _ => b.Key?.Replace('_', ' ') ?? "Overdue"
                };

                var emphasis = b.Amount > 0 ? "overdue" : "neutral";
                var tooltip = BuildBucketTooltip(nice, b.Amount, b.OldestDueDate, b.MaxDaysOverdue, b.Count);

                cards.Add(new FinanceCard(FinanceCardKind.OverdueBucket, "⏰", nice, b.Amount, "Aging bucket", emphasis, tooltip));
            }

            return cards
                .OrderBy(c => c.Kind switch
                {
                    FinanceCardKind.NotInvoiced => 1,
                    FinanceCardKind.Outstanding => 2,
                    FinanceCardKind.OverdueBucket => 3,
                    _ => 9
                })
                .ThenBy(c => c.Title)
                .ToList();
        }
        catch
        {
            return new();
        }
    }

    private static string BuildBucketTooltip(string title, decimal amount, DateTime? oldestDueDate, int? maxDaysOverdue, int? count)
    {
        var bits = new List<string> { $"{title}: {FormatMoney(amount)}" };

        if (count.HasValue)
            bits.Add($"Count: {count.Value}");

        if (oldestDueDate.HasValue)
            bits.Add($"Oldest due: {oldestDueDate.Value:yyyy-MM-dd}");

        if (maxDaysOverdue.HasValue)
            bits.Add($"Max days overdue: {maxDaysOverdue.Value}");

        return string.Join(" | ", bits);
    }

    private enum FinanceCardKind
    {
        NotInvoiced,
        Outstanding,
        OverdueBucket
    }

    private sealed record FinanceCard(
        FinanceCardKind Kind,
        string Emoji,
        string Title,
        decimal Amount,
        string Subtitle,
        string EmphasisClass,
        string? Tooltip = null
    );

    // ---------------------------
    // JSON model (Option C)
    // ---------------------------
    private sealed class FinanceOverviewJson
    {
        public int Version { get; set; } = 1;

        public decimal NotInvoicedAmount { get; set; }
        public int? NotInvoicedCount { get; set; }
        public DateTime? NotInvoicedOldestDueDate { get; set; }
        public int? NotInvoicedMaxDaysOverdue { get; set; }

        public decimal OutstandingAmount { get; set; }
        public int? OutstandingCount { get; set; }
        public DateTime? OutstandingOldestDueDate { get; set; }
        public int? OutstandingMaxDaysOverdue { get; set; }

        public List<OverdueBucketJson>? OverdueBuckets { get; set; }
    }

    private sealed class OverdueBucketJson
    {
        public string? Key { get; set; }              // Overdue_1_30, Overdue_31_60, Overdue_61_90, Overdue_90Plus
        public decimal Amount { get; set; }
        public int? Count { get; set; }
        public DateTime? OldestDueDate { get; set; }
        public int? MaxDaysOverdue { get; set; }
    }
}
