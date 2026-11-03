using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// CYB-237: "Agreed Status By" is system-set - the user who saves the fee amendment as Agreed. The
/// field is read-only in the UI, so SJob.FeeAmendmentsUpsert ignores the value passed in: it records
/// the saving user when the amendment becomes Agreed, keeps that user on later saves while it stays
/// Agreed, and clears it (-1) when the status moves away from Agreed.
/// </summary>
public sealed class FeeAmendmentAgreedStatusByTests
{
    private static readonly Guid PendingStatusGuid = new("68C95270-1BB9-4E8B-BE4C-38746C4661BB");
    private static readonly Guid AgreedStatusGuid = new("215F258A-CF79-468F-9EB8-A84481F7F8AF");

    [Fact]
    public async Task SavingAsAgreed_RecordsTheSavingUser_NotThePassedValue()
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            var amendmentGuid = Guid.NewGuid();

            await UpsertAsync(connection, transaction, fixture, amendmentGuid, AgreedStatusGuid, savingUserId: fixture.FirstUserId, passedAgreedByGuid: fixture.SecondUserGuid);

            Assert.Equal(fixture.FirstUserId, await ReadAgreedStatusByAsync(connection, transaction, amendmentGuid));
        });
    }

    [Fact]
    public async Task ResavingAnAgreedAmendment_KeepsTheUserWhoAgreedIt()
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            var amendmentGuid = Guid.NewGuid();

            await UpsertAsync(connection, transaction, fixture, amendmentGuid, AgreedStatusGuid, savingUserId: fixture.FirstUserId, passedAgreedByGuid: Guid.Empty);
            await UpsertAsync(connection, transaction, fixture, amendmentGuid, AgreedStatusGuid, savingUserId: fixture.SecondUserId, passedAgreedByGuid: fixture.SecondUserGuid);

            Assert.Equal(fixture.FirstUserId, await ReadAgreedStatusByAsync(connection, transaction, amendmentGuid));
        });
    }

    [Fact]
    public async Task MovingFromPendingToAgreed_RecordsTheUserWhoAgreedIt()
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            var amendmentGuid = Guid.NewGuid();

            await UpsertAsync(connection, transaction, fixture, amendmentGuid, PendingStatusGuid, savingUserId: fixture.FirstUserId, passedAgreedByGuid: Guid.Empty);
            Assert.Equal(-1, await ReadAgreedStatusByAsync(connection, transaction, amendmentGuid));

            await UpsertAsync(connection, transaction, fixture, amendmentGuid, AgreedStatusGuid, savingUserId: fixture.SecondUserId, passedAgreedByGuid: Guid.Empty);
            Assert.Equal(fixture.SecondUserId, await ReadAgreedStatusByAsync(connection, transaction, amendmentGuid));
        });
    }

    [Fact]
    public async Task MovingAwayFromAgreed_ClearsAgreedStatusBy()
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            var amendmentGuid = Guid.NewGuid();

            await UpsertAsync(connection, transaction, fixture, amendmentGuid, AgreedStatusGuid, savingUserId: fixture.FirstUserId, passedAgreedByGuid: Guid.Empty);
            await UpsertAsync(connection, transaction, fixture, amendmentGuid, PendingStatusGuid, savingUserId: fixture.FirstUserId, passedAgreedByGuid: fixture.FirstUserGuid);

            Assert.Equal(-1, await ReadAgreedStatusByAsync(connection, transaction, amendmentGuid));
        });
    }

    private sealed record Fixture(Guid JobGuid, int FirstUserId, Guid FirstUserGuid, int SecondUserId, Guid SecondUserGuid);

    private static async Task RunAsync(Func<SqlConnection, SqlTransaction, Fixture, Task> test)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var fixture = await InsertFixtureAsync(connection, transaction);
            await test(connection, transaction, fixture);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    private static async Task<Fixture> InsertFixtureAsync(SqlConnection connection, SqlTransaction transaction)
    {
        var jobGuid = Guid.NewGuid();
        var firstUserGuid = Guid.NewGuid();
        var secondUserGuid = Guid.NewGuid();

        const string sql = """
-- Production's -1 sentinel row, which an empty Send To contact Guid resolves to (the R4
-- fixtures already carry the zero-Guid identity used for an empty Requested By).
IF NOT EXISTS (SELECT 1 FROM SCrm.AccountContacts WHERE Guid = '00000000-0000-0000-0000-000000000000')
BEGIN
    SET IDENTITY_INSERT SCrm.AccountContacts ON;
    INSERT INTO SCrm.AccountContacts (ID, RowStatus, Guid) VALUES (-1, 1, '00000000-0000-0000-0000-000000000000');
    SET IDENTITY_INSERT SCrm.AccountContacts OFF;
END;

IF NOT EXISTS (SELECT 1 FROM SJob.FeeAmendmentStatus WHERE Guid = @PendingStatusGuid)
    INSERT INTO SJob.FeeAmendmentStatus (RowStatus, Guid, Name) VALUES (1, @PendingStatusGuid, N'Pending');
IF NOT EXISTS (SELECT 1 FROM SJob.FeeAmendmentStatus WHERE Guid = @AgreedStatusGuid)
    INSERT INTO SJob.FeeAmendmentStatus (RowStatus, Guid, Name) VALUES (1, @AgreedStatusGuid, N'Agreed');

DECLARE @FirstUserId int, @SecondUserId int;

INSERT INTO SCore.Identities (RowStatus, Guid, FullName, EmailAddress, UserGuid)
VALUES (1, @FirstUserGuid, N'CYB-237 first user', @FirstEmail, NEWID());
SET @FirstUserId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO SCore.Identities (RowStatus, Guid, FullName, EmailAddress, UserGuid)
VALUES (1, @SecondUserGuid, N'CYB-237 second user', @SecondEmail, NEWID());
SET @SecondUserId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO SJob.Jobs (RowStatus, Guid, Number, SurveyorID, JobDescription)
VALUES (1, @JobGuid, N'CYB237-FA', @FirstUserId, N'CYB-237 fee amendment fixture job');

SELECT @FirstUserId, @SecondUserId;
""";

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@PendingStatusGuid", SqlDbType.UniqueIdentifier) { Value = PendingStatusGuid },
                new SqlParameter("@AgreedStatusGuid", SqlDbType.UniqueIdentifier) { Value = AgreedStatusGuid },
                new SqlParameter("@FirstUserGuid", SqlDbType.UniqueIdentifier) { Value = firstUserGuid },
                new SqlParameter("@SecondUserGuid", SqlDbType.UniqueIdentifier) { Value = secondUserGuid },
                new SqlParameter("@FirstEmail", SqlDbType.NVarChar, 250) { Value = $"cyb237-a-{Guid.NewGuid():N}@invalid.local" },
                new SqlParameter("@SecondEmail", SqlDbType.NVarChar, 250) { Value = $"cyb237-b-{Guid.NewGuid():N}@invalid.local" },
                new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid }
            });
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        return new Fixture(jobGuid, reader.GetInt32(0), firstUserGuid, reader.GetInt32(1), secondUserGuid);
    }

    private static async Task UpsertAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Fixture fixture,
        Guid amendmentGuid,
        Guid statusGuid,
        int savingUserId,
        Guid passedAgreedByGuid)
    {
        const string sql = """
EXEC sys.sp_set_session_context @key = N'user_id', @value = @SavingUserId, @read_only = 0;

EXEC SJob.FeeAmendmentsUpsert
    @JobGuid = @JobGuid,
    @RibaStage0Change = 0, @RibaStage1Change = 0, @RibaStage2Change = 0, @RibaStage3Change = 0,
    @RibaStage4Change = 0, @RibaStage5Change = 0, @RibaStage6Change = 0, @RibaStage7Change = 0,
    @RibaStage0VisitChange = 0, @RibaStage1VisitChange = 0, @RibaStage2VisitChange = 0, @RibaStage3VisitChange = 0,
    @RibaStage4VisitChange = 0, @RibaStage5VisitChange = 0, @RibaStage6VisitChange = 0, @RibaStage7VisitChange = 0,
    @RibaStage0MeetingChange = 0, @RibaStage1MeetingChange = 0, @RibaStage2MeetingChange = 0, @RibaStage3MeetingChange = 0,
    @RibaStage4MeetingChange = 0, @RibaStage5MeetingChange = 0, @RibaStage6MeetingChange = 0, @RibaStage7MeetingChange = 0,
    @PreConstructionStageChange = 0, @ConstructionStageChange = 0,
    @PreConstructionStageMeetingChange = 0, @PreConstructionStageVisitChange = 0,
    @ConstructionStageMeetingChange = 0, @ConstructionStageVisitChange = 0,
    @FeeCapChange = 0,
    @Guid = @AmendmentGuid,
    @Reason = N'CYB-237 fixture',
    @DateReceivedRequest = '2026-10-08',
    @DateAgreed = '2026-10-08',
    @OriginalAgreedFee = 0,
    @NewTotalAgreedFee = 0,
    @Comments = N'CYB-237 fixture',
    @RejectionReason = N'',
    @FeeAmendmentStatusGuid = @StatusGuid,
    @SendToContactGuid = '00000000-0000-0000-0000-000000000000',
    @RequestedByUserGuid = '00000000-0000-0000-0000-000000000000',
    @AgreedStatusByUserGuid = @PassedAgreedByGuid;
""";

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@SavingUserId", SqlDbType.Int) { Value = savingUserId },
                new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = fixture.JobGuid },
                new SqlParameter("@AmendmentGuid", SqlDbType.UniqueIdentifier) { Value = amendmentGuid },
                new SqlParameter("@StatusGuid", SqlDbType.UniqueIdentifier) { Value = statusGuid },
                new SqlParameter("@PassedAgreedByGuid", SqlDbType.UniqueIdentifier) { Value = passedAgreedByGuid }
            });
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<int> ReadAgreedStatusByAsync(SqlConnection connection, SqlTransaction transaction, Guid amendmentGuid)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SELECT AgreedStatusByUserID FROM SJob.FeeAmendment WHERE Guid = @Guid;",
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = amendmentGuid } });
        return Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }
}
