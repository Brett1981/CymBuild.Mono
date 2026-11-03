using Concursus.Components.Shared.Helpers;

namespace Concursus.Components.Shared.Tests.Helpers;

public sealed class BulkOperationRunnerTests
{
    [Fact]
    public async Task RunAsync_RejectsNullInputs()
    {
        await Assert.ThrowsAsync<ArgumentNullException>(() =>
            BulkOperationRunner.RunAsync<int>(null!, (_, _) => Task.FromResult(BulkItemOutcome.Succeeded)));

        await Assert.ThrowsAsync<ArgumentNullException>(() =>
            BulkOperationRunner.RunAsync(new[] { 1 }, null!));
    }

    [Fact]
    public async Task RunAsync_ProcessesEveryItemInOrderAndReportsProgressAfterEach()
    {
        var processed = new List<int>();
        var progress = new List<BulkOperationProgress>();

        var result = await BulkOperationRunner.RunAsync(
            new[] { 1, 2, 3 },
            (item, _) =>
            {
                processed.Add(item);
                return Task.FromResult(BulkItemOutcome.Succeeded);
            },
            p =>
            {
                progress.Add(p);
                return Task.CompletedTask;
            });

        Assert.Equal(new[] { 1, 2, 3 }, processed);
        Assert.Equal(new[] { 0, 1, 2, 3 }, progress.Select(p => p.Processed));
        Assert.All(progress, p => Assert.Equal(3, p.Total));
        Assert.Equal(3, result.Succeeded);
        Assert.True(result.IsCompleteSuccess);
        Assert.Equal(0, result.NotProcessed);
    }

    [Fact]
    public async Task RunAsync_ContinuesPastFailuresAndRecordsEachFailedItem()
    {
        var processed = new List<int>();

        var result = await BulkOperationRunner.RunAsync(
            new[] { 1, 2, 3, 4 },
            (item, _) =>
            {
                processed.Add(item);
                if (item % 2 == 0)
                    throw new InvalidOperationException($"row {item} failed");

                return Task.FromResult(BulkItemOutcome.Succeeded);
            });

        Assert.Equal(new[] { 1, 2, 3, 4 }, processed);
        Assert.Equal(2, result.Succeeded);
        Assert.Equal(new[] { 2, 4 }, result.Failures.Select(f => f.Item));
        Assert.Equal("row 2 failed", result.Failures[0].Message);
        Assert.False(result.Stopped);
        Assert.False(result.IsCompleteSuccess);
    }

    [Fact]
    public async Task RunAsync_CountsSkippedItemsSeparately()
    {
        var result = await BulkOperationRunner.RunAsync(
            new[] { 1, 2, 3 },
            (item, _) => Task.FromResult(item == 2 ? BulkItemOutcome.Skipped : BulkItemOutcome.Succeeded));

        Assert.Equal(2, result.Succeeded);
        Assert.Equal(1, result.Skipped);
        Assert.True(result.IsCompleteSuccess);
    }

    [Fact]
    public async Task RunAsync_StopOnFirstFailure_DoesNotProcessRemainingItems()
    {
        var processed = new List<int>();

        var result = await BulkOperationRunner.RunAsync(
            new[] { 1, 2, 3 },
            (item, _) =>
            {
                processed.Add(item);
                if (item == 2)
                    throw new InvalidOperationException("boom");

                return Task.FromResult(BulkItemOutcome.Succeeded);
            },
            stopOnFirstFailure: true);

        Assert.Equal(new[] { 1, 2 }, processed);
        Assert.Equal(1, result.Succeeded);
        Assert.Single(result.Failures);
        Assert.Equal(1, result.NotProcessed);
        Assert.True(result.Stopped);
    }

    [Fact]
    public async Task RunAsync_StopsBetweenItemsWhenCancelled()
    {
        using var cancellation = new CancellationTokenSource();
        var processed = new List<int>();

        var result = await BulkOperationRunner.RunAsync(
            new[] { 1, 2, 3 },
            (item, _) =>
            {
                processed.Add(item);
                if (item == 1)
                    cancellation.Cancel();

                return Task.FromResult(BulkItemOutcome.Succeeded);
            },
            cancellationToken: cancellation.Token);

        Assert.Equal(new[] { 1 }, processed);
        Assert.Equal(1, result.Succeeded);
        Assert.Equal(2, result.NotProcessed);
        Assert.True(result.Stopped);
        Assert.False(result.IsCompleteSuccess);
    }
}
