using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Outbox;

public sealed class QuoteItemJobCreatedOutboxTests
{
    [Fact]
    public async Task SettingCreatedJobId_EnqueuesJobCreatedFromProposalOutboxEvent()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var jobGuid = Guid.NewGuid();
            var jobId = await SqlTestData.InsertMinimalJobAsync(connection, transaction, jobGuid, "R4-JOB-OUTBOX-0001");
            var quote = await SqlTestData.InsertMinimalQuoteAsync(connection, transaction, "R4-QUOTE-OUTBOX-0001");
            var quoteItemId = await SqlTestData.InsertQuoteItemAsync(connection, transaction, quote.QuoteId);

            await SqlTestData.SetQuoteItemCreatedJobIdAsync(connection, transaction, quoteItemId, jobId);

            var outboxRow = await SqlTestData.ReadJobCreatedFromProposalOutboxRowAsync(connection, transaction, jobGuid);

            Assert.NotNull(outboxRow);
            Assert.Equal("JobCreatedFromProposal", outboxRow!.EventType);
            Assert.Equal(jobGuid, outboxRow.JobGuid);
            Assert.Equal(quote.QuoteGuid, outboxRow.QuoteGuid);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task ConsolidatingTwoQuoteItemsIntoSameJob_EnqueuesOutboxEventOnce()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var jobGuid = Guid.NewGuid();
            var jobId = await SqlTestData.InsertMinimalJobAsync(connection, transaction, jobGuid, "R4-JOB-OUTBOX-0002");
            var firstQuote = await SqlTestData.InsertMinimalQuoteAsync(connection, transaction, "R4-QUOTE-OUTBOX-0002A");
            var secondQuote = await SqlTestData.InsertMinimalQuoteAsync(connection, transaction, "R4-QUOTE-OUTBOX-0002B");
            var firstQuoteItemId = await SqlTestData.InsertQuoteItemAsync(connection, transaction, firstQuote.QuoteId);
            var secondQuoteItemId = await SqlTestData.InsertQuoteItemAsync(connection, transaction, secondQuote.QuoteId);

            await SqlTestData.SetQuoteItemCreatedJobIdAsync(connection, transaction, firstQuoteItemId, jobId);
            await SqlTestData.SetQuoteItemCreatedJobIdAsync(connection, transaction, secondQuoteItemId, jobId);

            var outboxCount = await SqlTestData.CountJobCreatedFromProposalOutboxRowsAsync(connection, transaction, jobGuid);
            Assert.Equal(1L, outboxCount);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }
}
