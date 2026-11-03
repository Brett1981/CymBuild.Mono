using CymBuild.Database.IntegrationTests.Infrastructure;

namespace CymBuild.Database.IntegrationTests.Quoting;

public sealed class QuoteJobsSummaryStageFallbackTests
{
    // CYB-553: SSop.Quote_JobsSummary's RibaStages join used to be a plain
    // rs.ID = qi.ProvideAtStageID with no fallback, so a QuoteItem with no
    // "Provide At Stage" set (ProvideAtStageID = -1) failed the join and was
    // silently excluded from Net/AgreedFee/RibaStageXFee - the value never
    // made it onto the Job's fee columns when SSop.QuoteCreateJobs created the
    // Job from this summary. Fixed to remap -1 to RibaStages ID 2, matching
    // the same sentinel convention already used by SJob.Job_FeeDrawdown and
    // SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems.
    [Fact]
    public async Task QuoteItemWithNoStageSet_IsIncludedInStage2FeeInsteadOfDropped()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var fixture = await SqlTestData.InsertQuoteJobsSummaryFixtureAsync(connection, transaction);
            await SqlTestData.InsertQuoteJobsSummaryQuoteItemAsync(
                connection,
                transaction,
                fixture.QuoteId,
                fixture.ProductId,
                provideAtStageId: -1,
                lineNet: 100.00m);

            var row = await SqlTestData.ReadQuoteJobsSummaryRowAsync(connection, transaction, fixture.QuoteGuid);

            Assert.NotNull(row);
            Assert.Equal(100.00m, row!.Net);
            Assert.Equal(100.00m, row.AgreedFee);
            Assert.Equal(100.00m, row.RibaStage2Fee);
            Assert.Equal(0.00m, row.RibaStage1Fee);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task QuoteItemWithStageOneSet_IsIncludedInStageOneFeeNotStageTwo()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var fixture = await SqlTestData.InsertQuoteJobsSummaryFixtureAsync(connection, transaction);
            await SqlTestData.InsertQuoteJobsSummaryQuoteItemAsync(
                connection,
                transaction,
                fixture.QuoteId,
                fixture.ProductId,
                provideAtStageId: 1,
                lineNet: 250.00m);

            var row = await SqlTestData.ReadQuoteJobsSummaryRowAsync(connection, transaction, fixture.QuoteGuid);

            Assert.NotNull(row);
            Assert.Equal(250.00m, row!.Net);
            Assert.Equal(0.00m, row.RibaStage2Fee);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }
}
