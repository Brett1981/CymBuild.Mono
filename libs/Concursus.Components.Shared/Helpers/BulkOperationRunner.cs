namespace Concursus.Components.Shared.Helpers
{
    /// <summary>
    /// Outcome of applying a bulk operation to a single item.
    /// </summary>
    public enum BulkItemOutcome
    {
        Succeeded,

        /// <summary>The item could not be processed (e.g. no record guid) and was not attempted.</summary>
        Skipped
    }

    /// <summary>
    /// Running totals reported after each item of a bulk operation.
    /// </summary>
    public sealed record BulkOperationProgress(int Total, int Processed, int Succeeded, int Skipped, int Failed);

    /// <summary>
    /// An item whose operation threw, with the error message to show the user.
    /// </summary>
    public sealed record BulkOperationFailure<TItem>(TItem Item, string Message);

    public sealed class BulkOperationResult<TItem>
    {
        public int Total { get; init; }
        public int Succeeded { get; init; }
        public int Skipped { get; init; }
        public IReadOnlyList<BulkOperationFailure<TItem>> Failures { get; init; } = Array.Empty<BulkOperationFailure<TItem>>();

        /// <summary>True when the run stopped before every item was processed (cancelled or stopped on failure).</summary>
        public bool Stopped { get; init; }

        public int Failed => Failures.Count;
        public int NotProcessed => Total - Succeeded - Skipped - Failed;
        public bool IsCompleteSuccess => !Stopped && Failed == 0;
    }

    /// <summary>
    /// Runs one operation per selected item sequentially, reporting progress after each item.
    ///
    /// CYB-579: bulk updates can now span every page of a grid, so callers need progress and,
    /// for independent updates, a per-item failure list instead of aborting on the first error.
    /// This helper does NOT know about FormHelper or gRPC; the caller supplies the per-item operation.
    /// </summary>
    public static class BulkOperationRunner
    {
        public static async Task<BulkOperationResult<TItem>> RunAsync<TItem>(
            IReadOnlyList<TItem> items,
            Func<TItem, CancellationToken, Task<BulkItemOutcome>> operation,
            Func<BulkOperationProgress, Task>? onProgress = null,
            bool stopOnFirstFailure = false,
            CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull(items);
            ArgumentNullException.ThrowIfNull(operation);

            var failures = new List<BulkOperationFailure<TItem>>();
            var succeeded = 0;
            var skipped = 0;
            var stopped = false;

            if (onProgress is not null)
                await onProgress(new BulkOperationProgress(items.Count, 0, 0, 0, 0));

            foreach (var item in items)
            {
                if (cancellationToken.IsCancellationRequested)
                {
                    stopped = true;
                    break;
                }

                try
                {
                    var outcome = await operation(item, cancellationToken);
                    if (outcome == BulkItemOutcome.Skipped)
                        skipped++;
                    else
                        succeeded++;
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
                {
                    stopped = true;
                    break;
                }
                catch (Exception ex)
                {
                    failures.Add(new BulkOperationFailure<TItem>(item, ex.Message));
                }

                if (onProgress is not null)
                {
                    await onProgress(new BulkOperationProgress(
                        items.Count,
                        succeeded + skipped + failures.Count,
                        succeeded,
                        skipped,
                        failures.Count));
                }

                if (stopOnFirstFailure && failures.Count > 0)
                {
                    stopped = succeeded + skipped + failures.Count < items.Count;
                    break;
                }
            }

            return new BulkOperationResult<TItem>
            {
                Total = items.Count,
                Succeeded = succeeded,
                Skipped = skipped,
                Failures = failures,
                Stopped = stopped
            };
        }
    }
}
