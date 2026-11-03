using CymBuild_Outlook_Common.Models;

namespace CymBuild_Outlook_API.Helpers
{
    /// <summary>
    /// Pure ranking logic over the raw rows returned by SOffice.tvf_SuggestedFilingLocations.
    /// Kept free of I/O so it can be unit tested directly against plain DTOs.
    /// </summary>
    public static class FolderSuggestionRanker
    {
        public const int DefaultMaxResults = 5;
        public const int DefaultRecordHistoryThreshold = 3;

        public static List<SuggestedFilingLocationResult> Rank(
            IEnumerable<SuggestedFilingLocationResult> rows,
            int maxResults = DefaultMaxResults,
            int recordHistoryThreshold = DefaultRecordHistoryThreshold)
        {
            var all = (rows ?? Enumerable.Empty<SuggestedFilingLocationResult>())
                .Where(r => !string.IsNullOrWhiteSpace(r.FilingLocationUrl))
                .ToList();

            var recordRows = all
                .Where(r => string.Equals(r.Scope, "Record", StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(r => r.FiledCount)
                .ToList();

            var result = new List<SuggestedFilingLocationResult>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var row in recordRows)
            {
                if (result.Count >= maxResults)
                    break;

                if (seen.Add(row.FilingLocationUrl))
                    result.Add(row);
            }

            var recordTotal = recordRows.Sum(r => r.FiledCount);

            if (recordTotal < recordHistoryThreshold && result.Count < maxResults)
            {
                var entityTypeRows = all
                    .Where(r => string.Equals(r.Scope, "EntityType", StringComparison.OrdinalIgnoreCase))
                    .OrderByDescending(r => r.FiledCount);

                foreach (var row in entityTypeRows)
                {
                    if (result.Count >= maxResults)
                        break;

                    if (seen.Add(row.FilingLocationUrl))
                        result.Add(row);
                }
            }

            return result;
        }
    }
}
