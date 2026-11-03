using CymBuild.Database.IntegrationTests.Infrastructure;

namespace CymBuild.Database.IntegrationTests.Quoting;

public sealed class JobRibaStageFeesMixedScheduleTests
{
    private const int Stage2 = 2;
    private const int Stage3 = 3;
    private const int Stage4 = 4;

    // CYB-573: two quote items with the same job type but different invoice schedules
    // merge into one Job. SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems used to let
    // any schedule's stage amount replace every item on that stage, so the item on the
    // "activity complete" schedule (no stage amounts) was dropped from the Job fee table.
    // Mirrors QA2 quote 35823 / Job 8598: £110 at stage 3 on an unstaged schedule plus
    // £150 at stage 2 on a monthly schedule of £50 on stages 2, 3 and 4.
    [Fact]
    public async Task ItemOnUnstagedSchedule_KeepsItsValueAlongsideMonthlyScheduleAmounts()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var (fixture, jobId) = await InsertQuoteAndJobAsync(connection, transaction);

            var activityScheduleId = await SqlTestData.InsertInvoiceScheduleAsync(
                connection, transaction, fixture.QuoteId, "CYB-573 activity complete");
            var monthlyScheduleId = await InsertMonthlyScheduleAsync(connection, transaction, fixture.QuoteId);

            var activityItemId = await SqlTestData.InsertCreatedQuoteItemAsync(
                connection, transaction, fixture.QuoteId, fixture.ProductId, jobId,
                provideAtStageId: Stage3, invoicingScheduleId: activityScheduleId, lineNet: 110.00m, sortOrder: 1);
            var monthlyItemId = await SqlTestData.InsertCreatedQuoteItemAsync(
                connection, transaction, fixture.QuoteId, fixture.ProductId, jobId,
                provideAtStageId: Stage2, invoicingScheduleId: monthlyScheduleId, lineNet: 150.00m, sortOrder: 2);

            await SqlTestData.ExecuteJobRibaStageFeesUpsertFromCreatedQuoteItemsAsync(connection, transaction, jobId);

            var fees = await SqlTestData.ReadActiveJobRibaStageFeesAsync(connection, transaction, jobId);

            Assert.Equal(
                new[]
                {
                    new SqlTestData.JobRibaStageFeeRow(Stage2, monthlyItemId, 50.00m),
                    new SqlTestData.JobRibaStageFeeRow(Stage3, activityItemId, 160.00m),
                    new SqlTestData.JobRibaStageFeeRow(Stage4, monthlyItemId, 50.00m)
                },
                fees);
            Assert.Equal(260.00m, fees.Sum(fee => fee.AgreedFee));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    // Guards the existing single-schedule behaviour the CYB-573 fix must preserve: the
    // monthly schedule's stage amounts replace its own item's value, and stages only the
    // schedule configures link back to that item.
    [Fact]
    public async Task SingleMonthlySchedule_StageFeesFollowTheScheduleAmounts()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var (fixture, jobId) = await InsertQuoteAndJobAsync(connection, transaction);

            var monthlyScheduleId = await InsertMonthlyScheduleAsync(connection, transaction, fixture.QuoteId);
            var monthlyItemId = await SqlTestData.InsertCreatedQuoteItemAsync(
                connection, transaction, fixture.QuoteId, fixture.ProductId, jobId,
                provideAtStageId: Stage2, invoicingScheduleId: monthlyScheduleId, lineNet: 150.00m, sortOrder: 1);

            await SqlTestData.ExecuteJobRibaStageFeesUpsertFromCreatedQuoteItemsAsync(connection, transaction, jobId);

            var fees = await SqlTestData.ReadActiveJobRibaStageFeesAsync(connection, transaction, jobId);

            Assert.Equal(
                new[]
                {
                    new SqlTestData.JobRibaStageFeeRow(Stage2, monthlyItemId, 50.00m),
                    new SqlTestData.JobRibaStageFeeRow(Stage3, monthlyItemId, 50.00m),
                    new SqlTestData.JobRibaStageFeeRow(Stage4, monthlyItemId, 50.00m)
                },
                fees);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    private static async Task<(SqlTestData.QuoteJobsSummaryFixture Fixture, int JobId)> InsertQuoteAndJobAsync(
        SqlConnection connection,
        SqlTransaction transaction)
    {
        var fixture = await SqlTestData.InsertQuoteJobsSummaryFixtureAsync(connection, transaction);
        await SqlTestData.EnsureRibaStagesAsync(connection, transaction, [Stage3, Stage4]);

        var jobId = await SqlTestData.InsertMinimalJobAsync(
            connection,
            transaction,
            Guid.NewGuid(),
            $"CYB573-{Guid.NewGuid():N}"[..20]);

        return (fixture, jobId);
    }

    private static async Task<int> InsertMonthlyScheduleAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int quoteId)
    {
        var scheduleId = await SqlTestData.InsertInvoiceScheduleAsync(connection, transaction, quoteId, "CYB-573 monthly");
        await SqlTestData.InsertInvoiceScheduleMonthConfigurationAsync(connection, transaction, scheduleId, 1, 50.00m, Stage2);
        await SqlTestData.InsertInvoiceScheduleMonthConfigurationAsync(connection, transaction, scheduleId, 2, 50.00m, Stage3);
        await SqlTestData.InsertInvoiceScheduleMonthConfigurationAsync(connection, transaction, scheduleId, 3, 50.00m, Stage4);
        return scheduleId;
    }
}
