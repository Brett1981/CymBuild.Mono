using System.Data;
using CymBuild.Database.IntegrationTests.Infrastructure;

namespace CymBuild.Database.IntegrationTests.Quoting;

public sealed class QuoteEnquiryExpiryTests
{
    // CYB-461: SSop.Quote_CalculatedFields only returned "Expired" for quotes with
    // no status history, so Sent/Chase/Quoting quotes never expired, and nothing
    // saved an "Expired" status. Expected (BA, 2026-09-29):
    // - Quoting, Ready to Send, Sent, 1st Chase and 2nd Chase quotes expire once
    //   their ExpiryDate has passed; Accepted, Rejected, Dead, Declined and
    //   Reopened quotes never expire.
    // - SSop.ExpireOverdueQuotesAndEnquiries saves "Expired" through
    //   SCore.DataObjectTransitionUpsert, idempotently.
    // - An Enquiry only expires once all its quotes have expired, or when it has
    //   no quotes and its quoting deadline passed more than 2 days ago.
    //
    // History before the expiry is seeded directly: only the views read it. The
    // R4 database has no DataObjectTransition triggers, so notification
    // suppression is asserted through the procedure's silent count and the
    // restored session context, not through the notification queue.

    private static readonly Guid QuotingStatus = Guid.Parse("9A60F983-24BA-4733-907E-C5CCE0B691CB");
    private static readonly Guid ReadyToSendStatus = Guid.Parse("02A2237F-2AE7-4E05-926F-38E8B7D050A0");
    private static readonly Guid SentStatus = Guid.Parse("25D5491C-42A8-4B04-B3AC-D648AF0F8032");
    private static readonly Guid FirstChaseStatus = Guid.Parse("9FF22CEA-A2A6-4907-9B2D-E62DF8150913");
    private static readonly Guid SecondChaseStatus = Guid.Parse("1F01C16B-1A73-4844-A938-FE357405FD93");
    private static readonly Guid AcceptedStatus = Guid.Parse("21A29AEE-2D99-4DA3-8182-F31813B0C498");
    private static readonly Guid RejectedStatus = Guid.Parse("0A6A71F7-B39F-4213-997E-2B3A13B6144C");
    private static readonly Guid DeadStatus = Guid.Parse("8C7F7526-559F-4CCF-8FC2-DB0DA67E793D");
    private static readonly Guid DeclinedStatus = Guid.Parse("708C00E6-F45F-4CB2-8E91-A80B8B8E802E");
    private static readonly Guid ReopenedStatus = Guid.Parse("34EF363A-C8F7-4BA8-A2C6-067EBAEF12FD");
    private static readonly Guid ExpiredStatus = Guid.Parse("E6FAC201-F98B-4B3A-AB55-83DC9F802D00");

    private static readonly Guid QuotesEntityTypeGuid = Guid.Parse("D4D00461-0000-4000-8000-000000000001");
    private static readonly Guid EnquiriesEntityTypeGuid = Guid.Parse("D4D00007-0000-4000-8000-000000000006");
    private static readonly Guid ServiceUserGuid = Guid.Parse("D4D00004-0000-4000-8000-000000000001");

    private static DateTime TodayUtc => DateTime.UtcNow.Date;

    public static TheoryData<string> ExpirableStatuses => new() { "Quoting", "Ready to Send", "Sent", "1st Chase", "2nd Chase" };

    public static TheoryData<string, string> NonExpirableStatuses => new()
    {
        { "Accepted", "Accepted" },
        { "Rejected", "Rejected" },
        { "Dead", "Dead" },
        { "Declined", "Declined" },
        { "Reopened", "Reopened" }
    };

    [Theory]
    [MemberData(nameof(ExpirableStatuses))]
    public async Task InProgressQuotePastExpiryDate_IsCalculatedAsExpired(string statusName)
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var quote = await InsertQuoteAsync(connection, transaction, enquiryServiceId: -1, TodayUtc.AddDays(-1));
            await InsertTransitionAsync(connection, transaction, quote.Guid, StatusGuid(statusName));

            Assert.Equal("Expired", await ReadQuoteStatusAsync(connection, transaction, quote.Id));
        });
    }

    [Theory]
    [MemberData(nameof(NonExpirableStatuses))]
    public async Task FinishedOrReopenedQuotePastExpiryDate_KeepsItsStatus(string statusName, string expected)
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var quote = await InsertQuoteAsync(connection, transaction, enquiryServiceId: -1, TodayUtc.AddDays(-30));
            await InsertTransitionAsync(connection, transaction, quote.Guid, StatusGuid(statusName));

            Assert.Equal(expected, await ReadQuoteStatusAsync(connection, transaction, quote.Id));
        });
    }

    [Fact]
    public async Task ReopenedQuoteReturnedToQuoting_DoesNotExpire()
    {
        // SSop.QuoteReopen writes Reopened then Quoting; the view shows Reopened.
        await InTransactionAsync(async (connection, transaction) =>
        {
            var quote = await InsertQuoteAsync(connection, transaction, enquiryServiceId: -1, TodayUtc.AddDays(-30));
            await InsertTransitionAsync(connection, transaction, quote.Guid, SentStatus);
            await InsertTransitionAsync(connection, transaction, quote.Guid, ReopenedStatus, oldStatusGuid: SentStatus);
            await InsertTransitionAsync(connection, transaction, quote.Guid, QuotingStatus, oldStatusGuid: ReopenedStatus);

            Assert.Equal("Reopened", await ReadQuoteStatusAsync(connection, transaction, quote.Id));
        });
    }

    [Fact]
    public async Task SentQuoteOnItsExpiryDate_HasNotExpiredYet()
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var quote = await InsertQuoteAsync(connection, transaction, enquiryServiceId: -1, TodayUtc);
            await InsertTransitionAsync(connection, transaction, quote.Guid, SentStatus);

            Assert.Equal("Sent", await ReadQuoteStatusAsync(connection, transaction, quote.Id));
        });
    }

    [Fact]
    public async Task LegacySentQuoteWithNoHistoryPastExpiryDate_IsCalculatedAsExpired()
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var quote = await InsertQuoteAsync(connection, transaction, enquiryServiceId: -1, TodayUtc.AddDays(-1), dateSent: TodayUtc.AddDays(-60));

            Assert.Equal("Expired", await ReadQuoteStatusAsync(connection, transaction, quote.Id));
        });
    }

    [Fact]
    public async Task LegacyAcceptedQuoteWithNoHistoryPastExpiryDate_StaysAccepted()
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var quote = await InsertQuoteAsync(connection, transaction, enquiryServiceId: -1, TodayUtc.AddDays(-1), dateAccepted: TodayUtc.AddDays(-60));

            Assert.Equal("Accepted", await ReadQuoteStatusAsync(connection, transaction, quote.Id));
        });
    }

    [Fact]
    public async Task Run_SavesExpiredForTheOnlyQuote_AndSyncsTheEnquiry()
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var enquiry = await InsertEnquiryAsync(connection, transaction, quotingDeadline: null);
            var quote = await InsertQuoteAsync(connection, transaction, enquiry.EnquiryServiceId, TodayUtc.AddDays(-1));
            await InsertTransitionAsync(connection, transaction, quote.Guid, SentStatus);

            var summary = await RunAsync(connection, transaction);

            Assert.Equal(1, summary.QuotesExpired);
            Assert.Equal(0, summary.Failed);
            Assert.Equal(ExpiredStatus, await ReadLatestStatusAsync(connection, transaction, quote.Guid, enquiriesOnly: false));
            Assert.Equal(ExpiredStatus, await ReadLatestStatusAsync(connection, transaction, enquiry.Guid, enquiriesOnly: true));
            Assert.Equal(1, await CountExpiredTransitionsAsync(connection, transaction, enquiry.Guid));
        });
    }

    [Fact]
    public async Task Run_DoesNotExpireTheEnquiry_WhileAnotherQuoteIsStillLive()
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var enquiry = await InsertEnquiryAsync(connection, transaction, quotingDeadline: null);
            var expiredQuote = await InsertQuoteAsync(connection, transaction, enquiry.EnquiryServiceId, TodayUtc.AddDays(-1));
            await InsertTransitionAsync(connection, transaction, expiredQuote.Guid, SentStatus);
            var liveQuote = await InsertQuoteAsync(connection, transaction, enquiry.EnquiryServiceId, TodayUtc.AddDays(30));
            await InsertTransitionAsync(connection, transaction, liveQuote.Guid, SentStatus);

            var summary = await RunAsync(connection, transaction);

            Assert.Equal(1, summary.QuotesExpired);
            Assert.Equal(0, summary.EnquiriesExpired);
            Assert.Equal(ExpiredStatus, await ReadLatestStatusAsync(connection, transaction, expiredQuote.Guid, enquiriesOnly: false));
            Assert.Equal(SentStatus, await ReadLatestStatusAsync(connection, transaction, liveQuote.Guid, enquiriesOnly: false));
            Assert.Equal(0, await CountExpiredTransitionsAsync(connection, transaction, enquiry.Guid));
        });
    }

    [Fact]
    public async Task Run_ExpiresTheEnquiry_OnceTheLastQuoteExpires()
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var enquiry = await InsertEnquiryAsync(connection, transaction, quotingDeadline: null);
            var firstQuote = await InsertQuoteAsync(connection, transaction, enquiry.EnquiryServiceId, TodayUtc.AddDays(-5));
            await InsertTransitionAsync(connection, transaction, firstQuote.Guid, SentStatus);
            var secondQuote = await InsertQuoteAsync(connection, transaction, enquiry.EnquiryServiceId, TodayUtc.AddDays(-1));
            await InsertTransitionAsync(connection, transaction, secondQuote.Guid, FirstChaseStatus);

            var summary = await RunAsync(connection, transaction);

            Assert.Equal(2, summary.QuotesExpired);
            Assert.Equal(ExpiredStatus, await ReadLatestStatusAsync(connection, transaction, enquiry.Guid, enquiriesOnly: true));
            Assert.Equal(1, await CountExpiredTransitionsAsync(connection, transaction, enquiry.Guid));
        });
    }

    [Fact]
    public async Task Run_LeavesAcceptedAndNotYetDueQuotesAlone()
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var accepted = await InsertQuoteAsync(connection, transaction, enquiryServiceId: -1, TodayUtc.AddDays(-30));
            await InsertTransitionAsync(connection, transaction, accepted.Guid, AcceptedStatus);
            var notDue = await InsertQuoteAsync(connection, transaction, enquiryServiceId: -1, TodayUtc);
            await InsertTransitionAsync(connection, transaction, notDue.Guid, SentStatus);

            var summary = await RunAsync(connection, transaction);

            Assert.Equal(0, summary.QuotesExpired);
            Assert.Equal(AcceptedStatus, await ReadLatestStatusAsync(connection, transaction, accepted.Guid, enquiriesOnly: false));
            Assert.Equal(SentStatus, await ReadLatestStatusAsync(connection, transaction, notDue.Guid, enquiriesOnly: false));
        });
    }

    [Fact]
    public async Task Run_IsIdempotent()
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var enquiry = await InsertEnquiryAsync(connection, transaction, quotingDeadline: null);
            var quote = await InsertQuoteAsync(connection, transaction, enquiry.EnquiryServiceId, TodayUtc.AddDays(-1));
            await InsertTransitionAsync(connection, transaction, quote.Guid, SentStatus);
            var noQuoteEnquiry = await InsertEnquiryAsync(connection, transaction, quotingDeadline: TodayUtc.AddDays(-3));

            await RunAsync(connection, transaction);
            var second = await RunAsync(connection, transaction);

            Assert.Equal(0, second.QuotesExpired);
            Assert.Equal(0, second.EnquiriesExpired);
            Assert.Equal(1, await CountExpiredTransitionsAsync(connection, transaction, quote.Guid));
            Assert.Equal(1, await CountExpiredTransitionsAsync(connection, transaction, enquiry.Guid));
            Assert.Equal(1, await CountExpiredTransitionsAsync(connection, transaction, noQuoteEnquiry.Guid));
        });
    }

    [Fact]
    public async Task Run_ExpiresAnEnquiryWithNoQuotes_MoreThanTwoDaysAfterItsQuotingDeadline()
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var overdue = await InsertEnquiryAsync(connection, transaction, quotingDeadline: TodayUtc.AddDays(-3), withService: false);
            var justMissed = await InsertEnquiryAsync(connection, transaction, quotingDeadline: TodayUtc.AddDays(-1), withService: false);

            var summary = await RunAsync(connection, transaction);

            Assert.Equal(1, summary.EnquiriesExpired);
            Assert.Equal(ExpiredStatus, await ReadLatestStatusAsync(connection, transaction, overdue.Guid, enquiriesOnly: true));
            Assert.Equal(0, await CountExpiredTransitionsAsync(connection, transaction, justMissed.Guid));
        });
    }

    [Fact]
    public async Task Run_ExpiresTheOldBacklogSilently_AndRestoresSessionContext()
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var oldQuote = await InsertQuoteAsync(connection, transaction, enquiryServiceId: -1, TodayUtc.AddDays(-30));
            await InsertTransitionAsync(connection, transaction, oldQuote.Guid, SentStatus);
            var recentQuote = await InsertQuoteAsync(connection, transaction, enquiryServiceId: -1, TodayUtc.AddDays(-2));
            await InsertTransitionAsync(connection, transaction, recentQuote.Guid, SentStatus);

            // Notifications on, as in the API worker's session, so the procedure
            // has to switch them off for the old quote and back on afterwards.
            await using (var enable = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                "EXEC sys.sp_set_session_context @key = N'S_disable_notification_triggers', @value = NULL, @read_only = 0;"))
            {
                await enable.ExecuteNonQueryAsync();
            }

            var summary = await RunAsync(connection, transaction, notifyWithinDays: 7);
            var (disableTriggers, disableNotifications) = await ReadNotificationSessionContextAsync(connection, transaction);

            Assert.Equal(2, summary.QuotesExpired);
            Assert.Equal(1, summary.ExpiredSilently);
            Assert.Equal("1", disableTriggers);
            Assert.Null(disableNotifications);
        });
    }

    [Fact]
    public async Task Run_RejectsAnUnknownServiceUser()
    {
        await InTransactionAsync(async (connection, transaction) =>
        {
            var exception = await Assert.ThrowsAsync<SqlException>(() => RunAsync(connection, transaction, serviceUserGuid: Guid.NewGuid()));

            Assert.Equal(62002, exception.Number);
        });
    }

    private sealed record SeededQuote(int Id, Guid Guid);

    private sealed record SeededEnquiry(Guid Guid, int EnquiryServiceId);

    private sealed record RunSummary(bool LockAcquired, int QuotesExpired, int EnquiriesExpired, int ExpiredSilently, int Failed);

    private static Guid StatusGuid(string statusName) => statusName switch
    {
        "Quoting" => QuotingStatus,
        "Ready to Send" => ReadyToSendStatus,
        "Sent" => SentStatus,
        "1st Chase" => FirstChaseStatus,
        "2nd Chase" => SecondChaseStatus,
        "Accepted" => AcceptedStatus,
        "Rejected" => RejectedStatus,
        "Dead" => DeadStatus,
        "Declined" => DeclinedStatus,
        "Reopened" => ReopenedStatus,
        _ => throw new ArgumentOutOfRangeException(nameof(statusName), statusName, null)
    };

    private static async Task InTransactionAsync(Func<SqlConnection, SqlTransaction, Task> test)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            await SeedStatusesAndEntityTypesAsync(connection, transaction);
            await test(connection, transaction);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    private static async Task SeedStatusesAndEntityTypesAsync(SqlConnection connection, SqlTransaction transaction)
    {
        const string sql = """
INSERT INTO SCore.WorkflowStatus (RowStatus, Guid, Name, ShowInQuotes, ShowInEnquiries)
SELECT 1, seed.Guid, seed.Name, 1, seed.ShowInEnquiries
FROM (VALUES
    (CONVERT(uniqueidentifier, '9A60F983-24BA-4733-907E-C5CCE0B691CB'), N'Quoting', 0),
    (CONVERT(uniqueidentifier, '02A2237F-2AE7-4E05-926F-38E8B7D050A0'), N'Ready to Send', 0),
    (CONVERT(uniqueidentifier, '25D5491C-42A8-4B04-B3AC-D648AF0F8032'), N'Sent', 0),
    (CONVERT(uniqueidentifier, '9FF22CEA-A2A6-4907-9B2D-E62DF8150913'), N'1st Chase', 0),
    (CONVERT(uniqueidentifier, '1F01C16B-1A73-4844-A938-FE357405FD93'), N'2nd Chase', 0),
    (CONVERT(uniqueidentifier, '21A29AEE-2D99-4DA3-8182-F31813B0C498'), N'Accepted', 0),
    (CONVERT(uniqueidentifier, '0A6A71F7-B39F-4213-997E-2B3A13B6144C'), N'Rejected', 0),
    (CONVERT(uniqueidentifier, '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D'), N'Dead', 0),
    (CONVERT(uniqueidentifier, '708C00E6-F45F-4CB2-8E91-A80B8B8E802E'), N'Declined', 0),
    (CONVERT(uniqueidentifier, '34EF363A-C8F7-4BA8-A2C6-067EBAEF12FD'), N'Reopened', 0),
    (CONVERT(uniqueidentifier, 'E6FAC201-F98B-4B3A-AB55-83DC9F802D00'), N'Expired', 1)
) AS seed(Guid, Name, ShowInEnquiries)
WHERE NOT EXISTS (SELECT 1 FROM SCore.WorkflowStatus AS ws WHERE ws.Guid = seed.Guid);

IF NOT EXISTS (SELECT 1 FROM SCore.EntityTypes AS et WHERE et.Name = N'Quotes' AND et.RowStatus NOT IN (0, 254))
BEGIN
    INSERT INTO SCore.EntityTypes (RowStatus, Guid, Name)
    VALUES (1, @QuotesEntityTypeGuid, N'Quotes');
END;
""";
        var parameters = new[] { new SqlParameter("@QuotesEntityTypeGuid", SqlDbType.UniqueIdentifier) { Value = QuotesEntityTypeGuid } };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<SeededEnquiry> InsertEnquiryAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        DateTime? quotingDeadline,
        bool withService = true)
    {
        var enquiryGuid = Guid.NewGuid();
        const string sql = """
INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
SELECT @Guid, 1, et.ID
FROM SCore.EntityTypes AS et
WHERE et.Guid = @EnquiriesEntityTypeGuid;

INSERT INTO SSop.Enquiries (RowStatus, Guid, Number, QuotingDeadlineDate)
VALUES (1, @Guid, @Number, @QuotingDeadlineDate);

DECLARE @EnquiryId int = SCOPE_IDENTITY();
DECLARE @EnquiryServiceId int = -1;

IF (@WithService = 1)
BEGIN
    INSERT INTO SSop.EnquiryServices (RowStatus, Guid, EnquiryId)
    VALUES (1, NEWID(), @EnquiryId);

    SET @EnquiryServiceId = SCOPE_IDENTITY();
END;

SELECT @EnquiryServiceId;
""";
        var parameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = enquiryGuid },
            new SqlParameter("@EnquiriesEntityTypeGuid", SqlDbType.UniqueIdentifier) { Value = EnquiriesEntityTypeGuid },
            new SqlParameter("@Number", SqlDbType.NVarChar, 50) { Value = $"CYB-461-{enquiryGuid:N}" },
            new SqlParameter("@QuotingDeadlineDate", SqlDbType.Date) { Value = (object?)quotingDeadline ?? DBNull.Value },
            new SqlParameter("@WithService", SqlDbType.Bit) { Value = withService }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        var enquiryServiceId = Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);

        return new SeededEnquiry(enquiryGuid, enquiryServiceId);
    }

    private static async Task<SeededQuote> InsertQuoteAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int enquiryServiceId,
        DateTime expiryDate,
        DateTime? dateSent = null,
        DateTime? dateAccepted = null)
    {
        var quoteGuid = Guid.NewGuid();
        const string sql = """
INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
SELECT @Guid, 1, et.ID
FROM SCore.EntityTypes AS et
WHERE et.Name = N'Quotes'
  AND et.RowStatus NOT IN (0, 254);

INSERT INTO SSop.Quotes (RowStatus, Guid, EnquiryServiceID, Number, RevisionNumber, ExpiryDate, DateSent, DateAccepted)
OUTPUT INSERTED.ID
VALUES (1, @Guid, @EnquiryServiceId, @Number, 1, @ExpiryDate, @DateSent, @DateAccepted);
""";
        var parameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = quoteGuid },
            new SqlParameter("@EnquiryServiceId", SqlDbType.Int) { Value = enquiryServiceId },
            new SqlParameter("@Number", SqlDbType.NVarChar, 50) { Value = $"CYB-461-{quoteGuid:N}" },
            new SqlParameter("@ExpiryDate", SqlDbType.Date) { Value = expiryDate },
            new SqlParameter("@DateSent", SqlDbType.DateTime2) { Value = (object?)dateSent ?? DBNull.Value },
            new SqlParameter("@DateAccepted", SqlDbType.DateTime2) { Value = (object?)dateAccepted ?? DBNull.Value }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        var quoteId = Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);

        return new SeededQuote(quoteId, quoteGuid);
    }

    private static async Task InsertTransitionAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid recordGuid,
        Guid statusGuid,
        Guid? oldStatusGuid = null)
    {
        const string sql = """
INSERT INTO SCore.DataObjectTransition
    (RowStatus, Guid, StatusID, OldStatusID, Comment, DateTimeUTC, CreatedByUserId, SurveyorUserId, DataObjectGuid, IsImported)
SELECT
    1,
    NEWID(),
    (SELECT ws.ID FROM SCore.WorkflowStatus AS ws WHERE ws.Guid = @StatusGuid),
    (SELECT ws.ID FROM SCore.WorkflowStatus AS ws WHERE ws.Guid = @OldStatusGuid),
    N'CYB-461 seeded history',
    DATEADD(DAY, -90, SYSUTCDATETIME()),
    i.ID,
    NULL,
    @RecordGuid,
    0
FROM SCore.Identities AS i
WHERE i.Guid = @ServiceUserGuid;
""";
        var parameters = new[]
        {
            new SqlParameter("@StatusGuid", SqlDbType.UniqueIdentifier) { Value = statusGuid },
            new SqlParameter("@OldStatusGuid", SqlDbType.UniqueIdentifier) { Value = (object?)oldStatusGuid ?? DBNull.Value },
            new SqlParameter("@RecordGuid", SqlDbType.UniqueIdentifier) { Value = recordGuid },
            new SqlParameter("@ServiceUserGuid", SqlDbType.UniqueIdentifier) { Value = ServiceUserGuid }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        Assert.Equal(1, await command.ExecuteNonQueryAsync());
    }

    private static async Task<string> ReadQuoteStatusAsync(SqlConnection connection, SqlTransaction transaction, int quoteId)
    {
        const string sql = "SELECT qcf.QuoteStatus FROM SSop.Quote_CalculatedFields AS qcf WHERE qcf.ID = @QuoteId;";
        var parameters = new[] { new SqlParameter("@QuoteId", SqlDbType.Int) { Value = quoteId } };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        return (string)(await command.ExecuteScalarAsync())!;
    }

    private static async Task<RunSummary> RunAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int notifyWithinDays = 7,
        Guid? serviceUserGuid = null)
    {
        var parameters = new[]
        {
            new SqlParameter("@ServiceUserGuid", SqlDbType.UniqueIdentifier) { Value = serviceUserGuid ?? ServiceUserGuid },
            new SqlParameter("@MaxRecords", SqlDbType.Int) { Value = 500 },
            new SqlParameter("@NotifyWithinDays", SqlDbType.Int) { Value = notifyWithinDays }
        };

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SSop.ExpireOverdueQuotesAndEnquiries",
            parameters,
            CommandType.StoredProcedure);
        await using var reader = await command.ExecuteReaderAsync();

        Assert.True(await reader.ReadAsync(), "The procedure must return a summary row.");
        var summary = new RunSummary(
            reader.GetBoolean(reader.GetOrdinal("LockAcquired")),
            reader.GetInt32(reader.GetOrdinal("QuotesExpired")),
            reader.GetInt32(reader.GetOrdinal("EnquiriesExpired")),
            reader.GetInt32(reader.GetOrdinal("ExpiredSilently")),
            reader.GetInt32(reader.GetOrdinal("Failed")));

        var failures = new List<string>();
        if (await reader.NextResultAsync())
        {
            while (await reader.ReadAsync())
            {
                failures.Add($"{reader.GetString(0)} {reader.GetGuid(1)}: {reader.GetString(2)}");
            }
        }

        Assert.True(summary.LockAcquired);
        Assert.True(failures.Count == 0, string.Join(Environment.NewLine, failures));
        return summary;
    }

    private static async Task<Guid?> ReadLatestStatusAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid recordGuid,
        bool enquiriesOnly)
    {
        const string sql = """
SELECT TOP (1) ws.Guid
FROM SCore.DataObjectTransition AS dot
JOIN SCore.WorkflowStatus AS ws ON ws.ID = dot.StatusID
WHERE dot.DataObjectGuid = @RecordGuid
  AND dot.RowStatus NOT IN (0, 254)
  AND (@EnquiriesOnly = 0 OR ws.ShowInEnquiries = 1)
ORDER BY dot.DateTimeUTC DESC, dot.ID DESC;
""";
        var parameters = new[]
        {
            new SqlParameter("@RecordGuid", SqlDbType.UniqueIdentifier) { Value = recordGuid },
            new SqlParameter("@EnquiriesOnly", SqlDbType.Bit) { Value = enquiriesOnly }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        return await command.ExecuteScalarAsync() as Guid?;
    }

    private static async Task<int> CountExpiredTransitionsAsync(SqlConnection connection, SqlTransaction transaction, Guid recordGuid)
    {
        const string sql = """
SELECT COUNT(1)
FROM SCore.DataObjectTransition AS dot
JOIN SCore.WorkflowStatus AS ws ON ws.ID = dot.StatusID
WHERE dot.DataObjectGuid = @RecordGuid
  AND dot.RowStatus NOT IN (0, 254)
  AND ws.Guid = @ExpiredStatus;
""";
        var parameters = new[]
        {
            new SqlParameter("@RecordGuid", SqlDbType.UniqueIdentifier) { Value = recordGuid },
            new SqlParameter("@ExpiredStatus", SqlDbType.UniqueIdentifier) { Value = ExpiredStatus }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        return Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }

    private static async Task<(string?, string?)> ReadNotificationSessionContextAsync(SqlConnection connection, SqlTransaction transaction)
    {
        const string sql = """
SELECT
    CONVERT(nvarchar(20), SESSION_CONTEXT(N'S_disable_triggers')),
    CONVERT(nvarchar(20), SESSION_CONTEXT(N'S_disable_notification_triggers'));
""";
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql);
        await using var reader = await command.ExecuteReaderAsync();
        await reader.ReadAsync();

        return (reader.IsDBNull(0) ? null : reader.GetString(0), reader.IsDBNull(1) ? null : reader.GetString(1));
    }
}
