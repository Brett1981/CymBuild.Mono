using CymBuild_Outlook_Common.Models;

namespace CymBuild_Outlook_API.Helpers
{
    /// <summary>
    /// Pure ranking logic over the raw rows returned by SOffice.tvf_FrequentFilingRecords.
    /// Kept free of I/O so it can be unit tested directly against plain DTOs.
    /// </summary>
    public static class FrequentFilingRecordRanker
    {
        public const int DefaultMaxResults = 5;

        public static List<FrequentFilingRecordResult> Rank(
            IEnumerable<FrequentFilingRecordResult> rows,
            int maxResults = DefaultMaxResults)
        {
            var result = new List<FrequentFilingRecordResult>();
            var seen = new HashSet<long>();

            var ordered = (rows ?? Enumerable.Empty<FrequentFilingRecordResult>())
                .Where(r => r != null && r.ID > 0 && r.Guid != Guid.Empty && r.FiledCount > 0)
                .OrderByDescending(r => r.FiledCount)
                .ThenByDescending(r => r.LastFiledDateTime ?? DateTime.MinValue);

            foreach (var row in ordered)
            {
                if (result.Count >= maxResults)
                    break;

                if (seen.Add(row.ID))
                    result.Add(row);
            }

            return result;
        }
    }
}
