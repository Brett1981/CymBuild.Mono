using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// CYB-333: a billable activity answered "No" to "Is part of the agreed fee?" raises a Pending fee
/// amendment linked to the activity (SJob.ActivityFeeAmendmentEnsure), with the activity's
/// invoiced fee as the change for its RIBA stage. The stage, and the fee where the form shows it, are
/// required. The Job Fees table only takes the change once
/// the amendment is Agreed, so the invoiced activity no longer draws down from the original fee.
/// </summary>
public sealed class ActivityFeeAmendmentEnsureTests
{
    private static readonly Guid TestIdentityGuid = Guid.Parse("D4D00004-0000-4000-8000-000000000001");
    private static readonly Guid PendingStatusGuid = new("68C95270-1BB9-4E8B-BE4C-38746C4661BB");
    private static readonly Guid AgreedStatusGuid = new("215F258A-CF79-468F-9EB8-A84481F7F8AF");
    private static readonly Guid JobsEntityTypeGuid = new("63542427-46AB-4078-ABD1-1D583C24315C");
    private static readonly Guid FeeAmendmentEntityTypeGuid = new("D4D00237-0000-4000-8000-000000000001");

    // Standard stage (RIBA 3, the fixed RibaStage3Change column) and a custom stage.
    private const int StandardStageId = 3331;
    private const int StandardStageNumber = 3;
    private const int CustomStageId = 3332;

    private const decimal InvoicingValue = 250.00m;

    [Fact]
    public async Task Ensure_ForABillableActivityNotPartOfTheAgreedFee_RaisesOnePendingAmendmentLinkedToIt()
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            var activity = await InsertActivityAsync(connection, transaction, fixture, isBillable: true, isPartOfAgreedFee: false, StandardStageId);

            var first = await EnsureAsync(connection, transaction, activity.Guid);

            Assert.True(first.WasCreated);
            Assert.NotEqual(Guid.Empty, first.FeeAmendmentGuid);
            Assert.Equal(fixture.JobGuid, first.JobGuid);
            Assert.Equal(JobsEntityTypeGuid, first.JobEntityTypeGuid);

            const string sql = """
SELECT fa.ActivityID, fas.Guid, fa.RibaStage3Change, fa.Reason, fa.RequestedByUserID, et.Guid
FROM SJob.FeeAmendment AS fa
JOIN SJob.FeeAmendmentStatus AS fas ON fas.ID = fa.FeeAmendmentStatusID
JOIN SCore.DataObjects AS dob ON dob.Guid = fa.Guid
JOIN SCore.EntityTypes AS et ON et.ID = dob.EntityTypeId
WHERE fa.Guid = @Guid;
""";
            await using (var command = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                sql,
                new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = first.FeeAmendmentGuid } }))
            await using (var reader = await command.ExecuteReaderAsync())
            {
                Assert.True(await reader.ReadAsync());
                Assert.Equal(activity.Id, reader.GetInt64(0));
                Assert.Equal(PendingStatusGuid, reader.GetGuid(1));
                Assert.Equal(InvoicingValue, reader.GetDecimal(2));
                Assert.Contains("CYB-333 fixture activity", reader.GetString(3), StringComparison.Ordinal);
                Assert.Equal(fixture.UserId, reader.GetInt32(4));
                Assert.Equal(FeeAmendmentEntityTypeGuid, reader.GetGuid(5));
            }

            var second = await EnsureAsync(connection, transaction, activity.Guid);

            Assert.False(second.WasCreated);
            Assert.Equal(first.FeeAmendmentGuid, second.FeeAmendmentGuid);
            Assert.Equal(1, await CountAmendmentsForActivityAsync(connection, transaction, activity.Id));
        });
    }

    [Fact]
    public async Task RaisedAmendment_OnlyChangesTheJobFees_OnceItIsAgreed()
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            await InsertStageFeeAsync(connection, transaction, fixture.JobId, StandardStageId, 1000.00m);
            var activity = await InsertActivityAsync(connection, transaction, fixture, isBillable: true, isPartOfAgreedFee: false, StandardStageId);

            var raised = await EnsureAsync(connection, transaction, activity.Guid);
            Assert.Equal(1000.00m, await ReadStageAgreedAsync(connection, transaction, fixture.JobId, StandardStageId));

            // The user completes the amendment in the Fee Amendment form and sets it to Agreed.
            await SaveAmendmentFromFormAsync(connection, transaction, fixture, raised.FeeAmendmentGuid, AgreedStatusGuid, ribaStage3Change: InvoicingValue);

            Assert.Equal(1250.00m, await ReadStageAgreedAsync(connection, transaction, fixture.JobId, StandardStageId));
            Assert.Equal(1, await CountAmendmentsForActivityAsync(connection, transaction, activity.Id));
        });
    }

    [Fact]
    public async Task Ensure_ForACustomStage_RaisesTheChangeOnACustomFeeAmendmentRow()
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            var activity = await InsertActivityAsync(connection, transaction, fixture, isBillable: true, isPartOfAgreedFee: false, CustomStageId);

            var raised = await EnsureAsync(connection, transaction, activity.Guid);

            const string sql = """
SELECT cfa.StageChange,
       fa.NewTotalAgreedFee - fa.OriginalAgreedFee,
       fa.RibaStage0Change + fa.RibaStage1Change + fa.RibaStage2Change + fa.RibaStage3Change
     + fa.RibaStage4Change + fa.RibaStage5Change + fa.RibaStage6Change + fa.RibaStage7Change
     + fa.PreConstructionStageChange + fa.ConstructionStageChange
FROM SJob.FeeAmendment AS fa
JOIN SJob.CustomFeeAmendment AS cfa ON cfa.FeeAmendmentId = fa.ID AND cfa.RowStatus NOT IN (0, 254)
WHERE fa.Guid = @Guid
  AND cfa.StageId = @StageId;
""";
            await using var command = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                sql,
                new[]
                {
                    new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = raised.FeeAmendmentGuid },
                    new SqlParameter("@StageId", SqlDbType.Int) { Value = CustomStageId }
                });
            await using var reader = await command.ExecuteReaderAsync();

            Assert.True(await reader.ReadAsync(), "No custom-stage fee amendment row was raised for the activity.");
            Assert.Equal(InvoicingValue, reader.GetDecimal(0));
            Assert.Equal(InvoicingValue, reader.GetDecimal(1));
            Assert.Equal(0m, reader.GetDecimal(2));
        });
    }

    [Theory]
    [InlineData(true, true)]
    [InlineData(false, false)]
    public async Task Ensure_RaisesNothing_WhenTheActivityIsPartOfTheAgreedFeeOrNotBillable(bool isBillable, bool isPartOfAgreedFee)
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            var activity = await InsertActivityAsync(connection, transaction, fixture, isBillable, isPartOfAgreedFee, StandardStageId);

            var result = await EnsureAsync(connection, transaction, activity.Guid);

            Assert.False(result.WasCreated);
            Assert.Equal(Guid.Empty, result.FeeAmendmentGuid);
            Assert.Equal(0, await CountAmendmentsForActivityAsync(connection, transaction, activity.Id));
        });
    }

    [Fact]
    public async Task ActivitiesUpsert_KeepsTheStoredAnswer_WhenTheFormDoesNotPassIt()
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            var activity = await InsertActivityAsync(connection, transaction, fixture, isBillable: true, isPartOfAgreedFee: false, StandardStageId);

            await ExecuteActivitiesUpsertAsync(connection, transaction, fixture, activity, isPartOfAgreedFee: null);

            Assert.False(await ReadIsPartOfAgreedFeeAsync(connection, transaction, activity.Id));
        });
    }

    [Fact]
    public async Task ActivitiesUpsert_KeepsTheActivityOutOfTheAgreedFee_OnceItsAmendmentIsRaised()
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            var activity = await InsertActivityAsync(connection, transaction, fixture, isBillable: true, isPartOfAgreedFee: false, StandardStageId);
            await EnsureAsync(connection, transaction, activity.Guid);

            await ExecuteActivitiesUpsertAsync(connection, transaction, fixture, activity, isPartOfAgreedFee: true);

            Assert.False(await ReadIsPartOfAgreedFeeAsync(connection, transaction, activity.Id));
        });
    }

    [Fact]
    public async Task Ensure_PrefillsAQuantityBasedFee_AtTheSurveyorsBillableRate()
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            await SetSurveyorBillableRateAsync(connection, transaction, fixture.UserId, 80.00m);
            var activity = await InsertActivityAsync(
                connection, transaction, fixture, isBillable: true, isPartOfAgreedFee: false, StandardStageId,
                invoicingValue: 0m, invoicingQuantity: 2.5m);

            var raised = await EnsureAsync(connection, transaction, activity.Guid);

            Assert.Equal(200.00m, await ReadRibaStage3ChangeAsync(connection, transaction, raised.FeeAmendmentGuid));
        });
    }

    [Fact]
    public async Task ActivitiesUpsert_RequiresTheJobStage_WhenNotPartOfTheAgreedFee()
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            var activity = await InsertActivityAsync(connection, transaction, fixture, isBillable: true, isPartOfAgreedFee: true, StandardStageId);

            var error = await Assert.ThrowsAsync<SqlException>(() =>
                ExecuteActivitiesUpsertAsync(connection, transaction, fixture, activity, isPartOfAgreedFee: false, ribaStageId: -1));

            Assert.Contains("Select the job stage for the fee amendment.", error.Message, StringComparison.Ordinal);
        });
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task ActivitiesUpsert_RequiresAFee_OnlyWhereTheJobTypeShowsIt(bool useTimeSheets)
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            await SetJobUsesTimeSheetsAsync(connection, transaction, fixture.JobId, useTimeSheets);
            var activity = await InsertActivityAsync(connection, transaction, fixture, isBillable: true, isPartOfAgreedFee: true, StandardStageId);

            Task Save() => ExecuteActivitiesUpsertAsync(connection, transaction, fixture, activity, isPartOfAgreedFee: false, invoicingValue: 0m);

            if (useTimeSheets)
            {
                var error = await Assert.ThrowsAsync<SqlException>(Save);
                Assert.Contains("Enter the Invoicing Value or Quantity for the fee amendment.", error.Message, StringComparison.Ordinal);
                return;
            }

            // No fee on the activity: the amendment is raised on its stage and the user enters the amount.
            await Save();
            var raised = await EnsureAsync(connection, transaction, activity.Guid);

            Assert.True(raised.WasCreated);
            Assert.Equal(0m, await ReadRibaStage3ChangeAsync(connection, transaction, raised.FeeAmendmentGuid));
        });
    }

    [Fact]
    public async Task ActivitiesUpsert_DoesNotRequireAStageOrFee_WhenPartOfTheAgreedFee()
    {
        await RunAsync(async (connection, transaction, fixture) =>
        {
            var activity = await InsertActivityAsync(connection, transaction, fixture, isBillable: true, isPartOfAgreedFee: true, StandardStageId);

            await ExecuteActivitiesUpsertAsync(connection, transaction, fixture, activity, isPartOfAgreedFee: true, ribaStageId: -1, invoicingValue: 0m);

            Assert.True(await ReadIsPartOfAgreedFeeAsync(connection, transaction, activity.Id));
        });
    }

    private sealed record Fixture(int JobId, Guid JobGuid, int UserId, int ActivityStatusId);

    private sealed record ActivityFixture(long Id, Guid Guid, Guid ActivityTypeGuid);

    private sealed record EnsureResult(Guid FeeAmendmentGuid, Guid JobGuid, Guid JobEntityTypeGuid, bool WasCreated);

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

        const string sql = """
-- Production's -1 sentinel row, which the amendment's empty Send To contact resolves to.
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

SET IDENTITY_INSERT SJob.RibaStages ON;
IF NOT EXISTS (SELECT 1 FROM SJob.RibaStages WHERE ID = @StandardStageId)
    INSERT INTO SJob.RibaStages (ID, RowStatus, Number, Description, IsRealStage, IsCustomStage)
    VALUES (@StandardStageId, 1, @StandardStageNumber, N'CYB-333 standard stage', 1, 0);
IF NOT EXISTS (SELECT 1 FROM SJob.RibaStages WHERE ID = @CustomStageId)
    INSERT INTO SJob.RibaStages (ID, RowStatus, Number, Description, IsRealStage, IsCustomStage)
    VALUES (@CustomStageId, 1, @CustomStageId, N'CYB-333 custom stage', 1, 1);
SET IDENTITY_INSERT SJob.RibaStages OFF;

DECLARE @UserId int = (SELECT ID FROM SCore.Identities WHERE Guid = @UserGuid);
DECLARE @JobId int, @ActivityStatusId int;

EXEC sys.sp_set_session_context @key = N'user_id', @value = @UserId, @read_only = 0;

INSERT INTO SJob.Jobs (RowStatus, Guid, Number, SurveyorID, JobDescription)
VALUES (1, @JobGuid, N'CYB333-JOB', @UserId, N'CYB-333 activity fee amendment fixture');
SET @JobId = SCOPE_IDENTITY();

INSERT INTO SJob.ActivityStatus (RowStatus, Guid, Name, IsActive, IsCompleteStatus)
VALUES (1, NEWID(), N'CYB-333 fixture status', 1, 0);
SET @ActivityStatusId = SCOPE_IDENTITY();

SELECT @JobId, @UserId, @ActivityStatusId;
""";
        int jobId, userId, activityStatusId;
        await using (var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@PendingStatusGuid", SqlDbType.UniqueIdentifier) { Value = PendingStatusGuid },
                new SqlParameter("@AgreedStatusGuid", SqlDbType.UniqueIdentifier) { Value = AgreedStatusGuid },
                new SqlParameter("@StandardStageId", SqlDbType.Int) { Value = StandardStageId },
                new SqlParameter("@StandardStageNumber", SqlDbType.Int) { Value = StandardStageNumber },
                new SqlParameter("@CustomStageId", SqlDbType.Int) { Value = CustomStageId },
                new SqlParameter("@UserGuid", SqlDbType.UniqueIdentifier) { Value = TestIdentityGuid },
                new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid }
            }))
        await using (var reader = await command.ExecuteReaderAsync())
        {
            Assert.True(await reader.ReadAsync());
            jobId = reader.GetInt32(0);
            userId = reader.GetInt32(1);
            activityStatusId = reader.GetInt32(2);
        }

        await SqlTestData.ExecuteUpsertDataObjectAsync(connection, transaction, jobGuid, "SJob", "Jobs");

        return new Fixture(jobId, jobGuid, userId, activityStatusId);
    }

    private static async Task<ActivityFixture> InsertActivityAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Fixture fixture,
        bool isBillable,
        bool isPartOfAgreedFee,
        int ribaStageId,
        decimal invoicingValue = InvoicingValue,
        decimal invoicingQuantity = 0m)
    {
        var activityGuid = Guid.NewGuid();
        var activityTypeGuid = Guid.NewGuid();

        const string sql = """
DECLARE @ActivityTypeId int;

INSERT INTO SJob.ActivityTypes (RowStatus, Guid, Name, IsActive, IsBillable)
VALUES (1, @ActivityTypeGuid, N'CYB-333 fixture type', 1, @IsBillable);
SET @ActivityTypeId = SCOPE_IDENTITY();

INSERT INTO SJob.Activities
    (RowStatus, Guid, JobID, SurveyorID, ActivityTypeID, ActivityStatusID, Title, RibaStageId, InvoicingValue, InvoicingQuantity, IsPartOfAgreedFee)
VALUES
    (1, @ActivityGuid, @JobId, @UserId, @ActivityTypeId, @ActivityStatusId, N'CYB-333 fixture activity', @RibaStageId, @InvoicingValue, @InvoicingQuantity, @IsPartOfAgreedFee);

SELECT CONVERT(bigint, SCOPE_IDENTITY());
""";
        long activityId;
        await using (var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@ActivityTypeGuid", SqlDbType.UniqueIdentifier) { Value = activityTypeGuid },
                new SqlParameter("@IsBillable", SqlDbType.Bit) { Value = isBillable },
                new SqlParameter("@ActivityGuid", SqlDbType.UniqueIdentifier) { Value = activityGuid },
                new SqlParameter("@JobId", SqlDbType.Int) { Value = fixture.JobId },
                new SqlParameter("@UserId", SqlDbType.Int) { Value = fixture.UserId },
                new SqlParameter("@ActivityStatusId", SqlDbType.Int) { Value = fixture.ActivityStatusId },
                new SqlParameter("@RibaStageId", SqlDbType.Int) { Value = ribaStageId },
                new SqlParameter("@InvoicingValue", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = invoicingValue },
                new SqlParameter("@InvoicingQuantity", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = invoicingQuantity },
                new SqlParameter("@IsPartOfAgreedFee", SqlDbType.Bit) { Value = isPartOfAgreedFee }
            }))
        {
            activityId = Convert.ToInt64(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
        }

        await SqlTestData.ExecuteUpsertDataObjectAsync(connection, transaction, activityGuid, "SJob", "Activities");

        return new ActivityFixture(activityId, activityGuid, activityTypeGuid);
    }

    private static async Task InsertStageFeeAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int jobId,
        int ribaStageId,
        decimal agreedFee)
    {
        const string sql = """
INSERT INTO SJob.JobRibaStageFees (RowStatus, Guid, JobID, RibaStageID, CreatedFromQuoteItemID, AgreedFee)
VALUES (1, NEWID(), @JobId, @RibaStageId, -1, @AgreedFee);
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@JobId", SqlDbType.Int) { Value = jobId },
                new SqlParameter("@RibaStageId", SqlDbType.Int) { Value = ribaStageId },
                new SqlParameter("@AgreedFee", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = agreedFee }
            });
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<EnsureResult> EnsureAsync(SqlConnection connection, SqlTransaction transaction, Guid activityGuid)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SJob.ActivityFeeAmendmentEnsure",
            new[] { new SqlParameter("@ActivityGuid", SqlDbType.UniqueIdentifier) { Value = activityGuid } },
            CommandType.StoredProcedure);
        await using var reader = await command.ExecuteReaderAsync();

        Assert.True(await reader.ReadAsync());
        var result = new EnsureResult(
            reader.GetGuid(reader.GetOrdinal("FeeAmendmentGuid")),
            reader.GetGuid(reader.GetOrdinal("JobGuid")),
            reader.GetGuid(reader.GetOrdinal("JobEntityTypeGuid")),
            reader.GetBoolean(reader.GetOrdinal("WasCreated")));
        Assert.False(await reader.ReadAsync());
        return result;
    }

    /// <summary>The save the Fee Amendment form makes (SJob.FeeAmendmentsUpsert).</summary>
    private static async Task SaveAmendmentFromFormAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Fixture fixture,
        Guid amendmentGuid,
        Guid statusGuid,
        decimal ribaStage3Change)
    {
        const string sql = """
EXEC SJob.FeeAmendmentsUpsert
    @JobGuid = @JobGuid,
    @RibaStage0Change = 0, @RibaStage1Change = 0, @RibaStage2Change = 0, @RibaStage3Change = @RibaStage3Change,
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
    @Reason = N'CYB-333 fixture',
    @DateReceivedRequest = '2026-10-12',
    @DateAgreed = '2026-10-12',
    @OriginalAgreedFee = 0,
    @NewTotalAgreedFee = 0,
    @Comments = N'',
    @RejectionReason = N'',
    @FeeAmendmentStatusGuid = @StatusGuid,
    @SendToContactGuid = '00000000-0000-0000-0000-000000000000',
    @RequestedByUserGuid = @UserGuid,
    @AgreedStatusByUserGuid = '00000000-0000-0000-0000-000000000000';
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = fixture.JobGuid },
                new SqlParameter("@RibaStage3Change", SqlDbType.Decimal) { Precision = 9, Scale = 2, Value = ribaStage3Change },
                new SqlParameter("@AmendmentGuid", SqlDbType.UniqueIdentifier) { Value = amendmentGuid },
                new SqlParameter("@StatusGuid", SqlDbType.UniqueIdentifier) { Value = statusGuid },
                new SqlParameter("@UserGuid", SqlDbType.UniqueIdentifier) { Value = TestIdentityGuid }
            });
        await command.ExecuteNonQueryAsync();
    }

    /// <summary>The save the Activity form makes (SJob.ActivitiesUpsert), optionally without the new answer.</summary>
    private static async Task ExecuteActivitiesUpsertAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Fixture fixture,
        ActivityFixture activity,
        bool? isPartOfAgreedFee,
        int ribaStageId = StandardStageId,
        decimal invoicingValue = InvoicingValue)
    {
        const string sql = """
DECLARE @ActivityStatusGuid uniqueidentifier = (SELECT Guid FROM SJob.ActivityStatus WHERE ID = @ActivityStatusId);
DECLARE @RibaStageGuid uniqueidentifier = (SELECT Guid FROM SJob.RibaStages WHERE ID = @RibaStageId);

IF (@PassAnswer = 1)
    EXEC SJob.ActivitiesUpsert
        @JobGuid = @JobGuid, @SurveyorGuid = @UserGuid, @Date = '2026-10-12', @EndDate = '2026-10-12',
        @ActivityTypeGuid = @ActivityTypeGuid, @ActivityStatusGuid = @ActivityStatusGuid,
        @Title = N'CYB-333 fixture activity', @Notes = N'', @EditedByUserGuid = @UserGuid,
        @IsAdditionalWork = 0, @RibaStageGuid = @RibaStageGuid,
        @MilestoneGuid = '00000000-0000-0000-0000-000000000000',
        @InvoicingQuantity = 0, @InvoicingValue = @InvoicingValue,
        @Guid = @ActivityGuid, @NewExpiryDate = NULL,
        @IsPartOfAgreedFee = @IsPartOfAgreedFee;
ELSE
    EXEC SJob.ActivitiesUpsert
        @JobGuid = @JobGuid, @SurveyorGuid = @UserGuid, @Date = '2026-10-12', @EndDate = '2026-10-12',
        @ActivityTypeGuid = @ActivityTypeGuid, @ActivityStatusGuid = @ActivityStatusGuid,
        @Title = N'CYB-333 fixture activity', @Notes = N'', @EditedByUserGuid = @UserGuid,
        @IsAdditionalWork = 0, @RibaStageGuid = @RibaStageGuid,
        @MilestoneGuid = '00000000-0000-0000-0000-000000000000',
        @InvoicingQuantity = 0, @InvoicingValue = @InvoicingValue,
        @Guid = @ActivityGuid, @NewExpiryDate = NULL;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@ActivityStatusId", SqlDbType.Int) { Value = fixture.ActivityStatusId },
                new SqlParameter("@RibaStageId", SqlDbType.Int) { Value = ribaStageId },
                new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = fixture.JobGuid },
                new SqlParameter("@UserGuid", SqlDbType.UniqueIdentifier) { Value = TestIdentityGuid },
                new SqlParameter("@ActivityTypeGuid", SqlDbType.UniqueIdentifier) { Value = activity.ActivityTypeGuid },
                new SqlParameter("@InvoicingValue", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = invoicingValue },
                new SqlParameter("@ActivityGuid", SqlDbType.UniqueIdentifier) { Value = activity.Guid },
                new SqlParameter("@PassAnswer", SqlDbType.Bit) { Value = isPartOfAgreedFee.HasValue },
                new SqlParameter("@IsPartOfAgreedFee", SqlDbType.Bit) { Value = (object?)isPartOfAgreedFee ?? DBNull.Value }
            });
        await command.ExecuteNonQueryAsync();
    }

    private static async Task SetJobUsesTimeSheetsAsync(SqlConnection connection, SqlTransaction transaction, int jobId, bool useTimeSheets)
    {
        const string sql = """
DECLARE @JobTypeId int;

INSERT INTO SJob.JobTypes (RowStatus, Guid, Name, IsActive, UseTimeSheets)
VALUES (1, NEWID(), N'CYB-333 fixture job type', 1, @UseTimeSheets);
SET @JobTypeId = SCOPE_IDENTITY();

UPDATE SJob.Jobs SET JobTypeID = @JobTypeId WHERE ID = @JobId;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@UseTimeSheets", SqlDbType.Bit) { Value = useTimeSheets },
                new SqlParameter("@JobId", SqlDbType.Int) { Value = jobId }
            });
        await command.ExecuteNonQueryAsync();
    }

    private static async Task SetSurveyorBillableRateAsync(SqlConnection connection, SqlTransaction transaction, int userId, decimal billableRate)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "UPDATE SCore.Identities SET BillableRate = @BillableRate WHERE ID = @UserId;",
            new[]
            {
                new SqlParameter("@BillableRate", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = billableRate },
                new SqlParameter("@UserId", SqlDbType.Int) { Value = userId }
            });
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<decimal> ReadRibaStage3ChangeAsync(SqlConnection connection, SqlTransaction transaction, Guid feeAmendmentGuid)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SELECT fa.RibaStage3Change FROM SJob.FeeAmendment AS fa WHERE fa.Guid = @Guid;",
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = feeAmendmentGuid } });
        return Convert.ToDecimal(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }

    private static async Task<decimal> ReadStageAgreedAsync(SqlConnection connection, SqlTransaction transaction, int jobId, int stageId)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SELECT fd.Agreed FROM SJob.Job_FeeDrawdown AS fd WHERE fd.JobId = @JobId AND fd.StageId = @StageId;",
            new[]
            {
                new SqlParameter("@JobId", SqlDbType.Int) { Value = jobId },
                new SqlParameter("@StageId", SqlDbType.Int) { Value = stageId }
            });
        return Convert.ToDecimal(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }

    private static async Task<int> CountAmendmentsForActivityAsync(SqlConnection connection, SqlTransaction transaction, long activityId)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SELECT COUNT(*) FROM SJob.FeeAmendment AS fa WHERE fa.ActivityID = @ActivityId AND fa.RowStatus NOT IN (0, 254);",
            new[] { new SqlParameter("@ActivityId", SqlDbType.BigInt) { Value = activityId } });
        return Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }

    private static async Task<bool> ReadIsPartOfAgreedFeeAsync(SqlConnection connection, SqlTransaction transaction, long activityId)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SELECT a.IsPartOfAgreedFee FROM SJob.Activities AS a WHERE a.ID = @ActivityId;",
            new[] { new SqlParameter("@ActivityId", SqlDbType.BigInt) { Value = activityId } });
        return Convert.ToBoolean(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }
}
