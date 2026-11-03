using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// CYB-580: an Invoice Request Item linked to an Activity was saved without the Activity's
/// RIBA stage, and could then be re-allocated to a stage with no agreed fee because only the
/// Activity's stage was fee-checked. SFin.InvoiceRequestItemsUpsert now allocates the item to
/// the Activity's stage, refuses a different stage, and fee-checks the selected stage when the
/// Activity has none.
/// QA follow-up: a stage with no agreed fee cannot be invoiced at all (whatever the item's
/// value), and the remaining fee is reduced by batched invoices and by Invoice Request Items
/// not yet invoiced, not only by posted invoices. SFin.tvf_InvoiceRequestItemsValidate keeps
/// the RIBA stage on the Activity's stage in the form.
/// </summary>
public sealed class InvoiceRequestItemRibaStageTests
{
    private static readonly Guid TestIdentityGuid = Guid.Parse("D4D00004-0000-4000-8000-000000000001");

    private const int StageWithFee = 5801;
    private const int StageWithoutFee = 5802;
    private const decimal AgreedFee = 1000.00m;
    private const decimal ActivityValue = 100.00m;

    [Fact]
    public async Task ActivityCreateInvoiceRequest_AllocatesTheItemToTheActivitysRibaStage()
    {
        await RunAsync(activityStageId: StageWithFee, async (connection, transaction, fixture) =>
        {
            await ExecuteCreateInvoiceRequestAsync(connection, transaction, fixture.ActivityGuid);

            var item = await ReadItemAsync(connection, transaction, fixture.ActivityId);
            Assert.Equal(StageWithFee, item.RibaStageId);
        });
    }

    [Fact]
    public async Task ReallocatingAnActivityItemToADifferentStage_IsRefused()
    {
        await RunAsync(activityStageId: StageWithFee, async (connection, transaction, fixture) =>
        {
            await ExecuteCreateInvoiceRequestAsync(connection, transaction, fixture.ActivityGuid);
            var item = await ReadItemAsync(connection, transaction, fixture.ActivityId);

            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteActivityItemUpsertAsync(connection, transaction, item, fixture, fixture.StageWithoutFeeGuid));
            Assert.Equal(51004, error.Number);
        });
    }

    [Fact]
    public async Task ResavingAnActivityItemWithTheActivitysStage_IsAllowed()
    {
        await RunAsync(activityStageId: StageWithFee, async (connection, transaction, fixture) =>
        {
            await ExecuteCreateInvoiceRequestAsync(connection, transaction, fixture.ActivityGuid);
            var item = await ReadItemAsync(connection, transaction, fixture.ActivityId);

            await ExecuteActivityItemUpsertAsync(connection, transaction, item, fixture, fixture.StageWithFeeGuid);

            Assert.Equal(StageWithFee, (await ReadItemAsync(connection, transaction, fixture.ActivityId)).RibaStageId);
        });
    }

    [Fact]
    public async Task AllocatingAnUnstagedActivityItemToAStageWithNoAgreedFee_IsRefused()
    {
        await RunAsync(activityStageId: -1, async (connection, transaction, fixture) =>
        {
            await ExecuteCreateInvoiceRequestAsync(connection, transaction, fixture.ActivityGuid);
            var item = await ReadItemAsync(connection, transaction, fixture.ActivityId);

            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteActivityItemUpsertAsync(connection, transaction, item, fixture, fixture.StageWithoutFeeGuid));
            AssertNoAgreedFee(error);
        });
    }

    [Fact]
    public async Task ActivityOnAStageWithNoAgreedFee_CannotBeInvoiced()
    {
        await RunAsync(activityStageId: StageWithoutFee, async (connection, transaction, fixture) =>
        {
            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteCreateInvoiceRequestAsync(connection, transaction, fixture.ActivityGuid));
            AssertNoAgreedFee(error);
        });
    }

    [Fact]
    public async Task ZeroValueItemOnAStageWithNoAgreedFee_IsRefused()
    {
        await RunAsync(activityStageId: StageWithFee, async (connection, transaction, fixture) =>
        {
            await ExecuteCreateInvoiceRequestAsync(connection, transaction, fixture.ActivityGuid);
            var item = await ReadItemAsync(connection, transaction, fixture.ActivityId);

            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteStageItemUpsertAsync(connection, transaction, item.InvoiceRequestGuid, Guid.NewGuid(), 0.00m, fixture.StageWithoutFeeGuid));
            AssertNoAgreedFee(error);
        });
    }

    [Fact]
    public async Task InvoiceRequestItemsNotYetInvoiced_AreTakenOffTheRemainingStageFee()
    {
        await RunAsync(activityStageId: StageWithFee, async (connection, transaction, fixture) =>
        {
            // The Activity's request takes 100 of the 1000 agreed, leaving 900.
            await ExecuteCreateInvoiceRequestAsync(connection, transaction, fixture.ActivityGuid);
            var item = await ReadItemAsync(connection, transaction, fixture.ActivityId);

            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteStageItemUpsertAsync(connection, transaction, item.InvoiceRequestGuid, Guid.NewGuid(), AgreedFee - ActivityValue + 0.01m, fixture.StageWithFeeGuid));
            Assert.Equal(51003, error.Number);
            Assert.Contains("only £900.00", error.Message, StringComparison.Ordinal);

            await ExecuteStageItemUpsertAsync(connection, transaction, item.InvoiceRequestGuid, Guid.NewGuid(), AgreedFee - ActivityValue, fixture.StageWithFeeGuid);
        });
    }

    [Fact]
    public async Task BatchedInvoices_AreTakenOffTheRemainingStageFee()
    {
        await RunAsync(activityStageId: StageWithFee, async (connection, transaction, fixture) =>
        {
            // A batched (not yet approved) invoice for 950 leaves 50, less than the Activity's 100.
            await InsertBatchedInvoiceAsync(connection, transaction, fixture.JobId, StageWithFee, AgreedFee - 50.00m);

            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteCreateInvoiceRequestAsync(connection, transaction, fixture.ActivityGuid));
            Assert.Equal(51003, error.Number);
            Assert.Contains("only £50.00", error.Message, StringComparison.Ordinal);
        });
    }

    [Fact]
    public async Task ItemsValidate_KeepsTheRibaStageOnTheActivitysStage()
    {
        await RunAsync(activityStageId: StageWithFee, async (connection, transaction, fixture) =>
        {
            var ribaStageProperty = await SeedInvoiceRequestItemPropertiesAsync(connection, transaction);

            var blank = await ReadRibaStageValidationAsync(connection, transaction, ribaStageProperty, fixture.ActivityGuid, Guid.Empty);
            Assert.Equal((true, false), (blank.IsReadOnly, blank.IsInvalid));

            var matching = await ReadRibaStageValidationAsync(connection, transaction, ribaStageProperty, fixture.ActivityGuid, fixture.StageWithFeeGuid);
            Assert.Equal((true, false), (matching.IsReadOnly, matching.IsInvalid));

            var different = await ReadRibaStageValidationAsync(connection, transaction, ribaStageProperty, fixture.ActivityGuid, fixture.StageWithoutFeeGuid);
            Assert.Equal((false, true), (different.IsReadOnly, different.IsInvalid));
            Assert.Contains("CYB-580 stage with fee", different.Message, StringComparison.Ordinal);
        });
    }

    [Fact]
    public async Task ItemsValidate_LeavesTheRibaStageEditableForAnUnstagedActivity()
    {
        await RunAsync(activityStageId: -1, async (connection, transaction, fixture) =>
        {
            var ribaStageProperty = await SeedInvoiceRequestItemPropertiesAsync(connection, transaction);

            var result = await ReadRibaStageValidationAsync(connection, transaction, ribaStageProperty, fixture.ActivityGuid, fixture.StageWithFeeGuid);
            Assert.Equal((false, false), (result.IsReadOnly, result.IsInvalid));
        });
    }

    private static void AssertNoAgreedFee(SqlException error)
    {
        Assert.Equal(51003, error.Number);
        Assert.Contains("has no agreed fee", error.Message, StringComparison.Ordinal);
    }

    private sealed record ActivityFixture(
        int JobId,
        long ActivityId,
        Guid ActivityGuid,
        Guid MilestoneGuid,
        Guid StageWithFeeGuid,
        Guid StageWithoutFeeGuid);

    private sealed record ItemRow(Guid ItemGuid, Guid InvoiceRequestGuid, int? RibaStageId);

    private sealed record PropertyValidation(bool IsReadOnly, bool IsInvalid, string Message);

    private static async Task RunAsync(int activityStageId, Func<SqlConnection, SqlTransaction, ActivityFixture, Task> test)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var fixture = await InsertFixtureAsync(connection, transaction, activityStageId);
            await test(connection, transaction, fixture);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    /// <summary>
    /// Inserts two RIBA stages with distinct labels, a Job with an agreed fee on only the first
    /// stage, and a completed Activity with an invoicing value on the given stage (-1 for no stage).
    /// </summary>
    private static async Task<ActivityFixture> InsertFixtureAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int activityStageId)
    {
        var accountId = await SqlTestData.ReadActiveAccountIdAsync(connection, transaction);
        var jobGuid = Guid.NewGuid();
        var activityGuid = Guid.NewGuid();
        var milestoneGuid = Guid.NewGuid();

        const string sql = """
SET IDENTITY_INSERT SJob.RibaStages ON;
IF NOT EXISTS (SELECT 1 FROM SJob.RibaStages WHERE ID = @StageWithFee)
    INSERT INTO SJob.RibaStages (ID, RowStatus, Number, Description, IsRealStage)
    VALUES (@StageWithFee, 1, @StageWithFee, N'CYB-580 stage with fee', 1);
IF NOT EXISTS (SELECT 1 FROM SJob.RibaStages WHERE ID = @StageWithoutFee)
    INSERT INTO SJob.RibaStages (ID, RowStatus, Number, Description, IsRealStage)
    VALUES (@StageWithoutFee, 1, @StageWithoutFee, N'CYB-580 stage without fee', 1);
SET IDENTITY_INSERT SJob.RibaStages OFF;

DECLARE @SurveyorId int = (SELECT ID FROM SCore.Identities WHERE Guid = @SurveyorGuid);
DECLARE @JobId int, @MilestoneId bigint, @ActivityStatusId int;

INSERT INTO SJob.Jobs (RowStatus, Guid, Number, SurveyorID, JobDescription, FinanceAccountID)
VALUES (1, @JobGuid, N'CYB580-JOB', @SurveyorId, N'CYB-580 RIBA stage fixture', @AccountId);
SET @JobId = SCOPE_IDENTITY();

INSERT INTO SJob.JobRibaStageFees (RowStatus, Guid, JobID, RibaStageID, CreatedFromQuoteItemID, AgreedFee)
VALUES (1, NEWID(), @JobId, @StageWithFee, -1, @AgreedFee);

INSERT INTO SJob.Milestones (RowStatus, Guid, JobID, Description)
VALUES (1, @MilestoneGuid, @JobId, N'CYB-580 fixture milestone');
SET @MilestoneId = SCOPE_IDENTITY();

INSERT INTO SJob.ActivityStatus (RowStatus, Guid, Name, IsActive, IsCompleteStatus)
VALUES (1, NEWID(), N'CYB-580 fixture status', 1, 1);
SET @ActivityStatusId = SCOPE_IDENTITY();

INSERT INTO SJob.Activities (RowStatus, Guid, JobID, MilestoneID, SurveyorID, ActivityStatusID, Title, RibaStageId, InvoicingValue, InvoicingQuantity)
VALUES (1, @ActivityGuid, @JobId, @MilestoneId, @SurveyorId, @ActivityStatusId, N'CYB-580 fixture activity', @ActivityStageId, @ActivityValue, 1);

SELECT @JobId,
       CONVERT(bigint, SCOPE_IDENTITY()),
       (SELECT Guid FROM SJob.RibaStages WHERE ID = @StageWithFee),
       (SELECT Guid FROM SJob.RibaStages WHERE ID = @StageWithoutFee);
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@StageWithFee", SqlDbType.Int) { Value = StageWithFee },
                new SqlParameter("@StageWithoutFee", SqlDbType.Int) { Value = StageWithoutFee },
                new SqlParameter("@SurveyorGuid", SqlDbType.UniqueIdentifier) { Value = TestIdentityGuid },
                new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid },
                new SqlParameter("@AccountId", SqlDbType.Int) { Value = accountId },
                new SqlParameter("@MilestoneGuid", SqlDbType.UniqueIdentifier) { Value = milestoneGuid },
                new SqlParameter("@ActivityGuid", SqlDbType.UniqueIdentifier) { Value = activityGuid },
                new SqlParameter("@ActivityStageId", SqlDbType.Int) { Value = activityStageId },
                new SqlParameter("@AgreedFee", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = AgreedFee },
                new SqlParameter("@ActivityValue", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = ActivityValue }
            });

        int jobId;
        long activityId;
        Guid stageWithFeeGuid;
        Guid stageWithoutFeeGuid;
        await using (var reader = await command.ExecuteReaderAsync())
        {
            Assert.True(await reader.ReadAsync());
            jobId = reader.GetInt32(0);
            activityId = reader.GetInt64(1);
            stageWithFeeGuid = reader.GetGuid(2);
            stageWithoutFeeGuid = reader.GetGuid(3);
        }

        await SqlTestData.ExecuteUpsertDataObjectAsync(connection, transaction, jobGuid, "SJob", "Jobs");

        return new ActivityFixture(jobId, activityId, activityGuid, milestoneGuid, stageWithFeeGuid, stageWithoutFeeGuid);
    }

    /// <summary>
    /// Inserts an invoice for the job that is still Batched (awaiting approval), with one line
    /// on the given RIBA stage. SJob.Job_FeeDrawdown does not count it as invoiced yet.
    /// </summary>
    private static async Task InsertBatchedInvoiceAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int jobId,
        int ribaStageId,
        decimal net)
    {
        const string sql = """
IF NOT EXISTS (SELECT 1 FROM SFin.TransactionTypes WHERE Name = N'Invoice')
    INSERT INTO SFin.TransactionTypes (Name, IsActive, IsBank, IsNegated) VALUES (N'Invoice', 1, 0, 0);

DECLARE @TransactionId bigint;

INSERT INTO SFin.Transactions (RowStatus, Guid, TransactionTypeID, AccountID, JobID, Batched, ReservedInvoiceNumber)
VALUES
(
    1,
    NEWID(),
    (SELECT TOP (1) tt.ID FROM SFin.TransactionTypes AS tt WHERE tt.Name = N'Invoice' AND tt.RowStatus NOT IN (0, 254) ORDER BY tt.ID),
    (SELECT j.FinanceAccountID FROM SJob.Jobs AS j WHERE j.ID = @JobId),
    @JobId,
    1,
    N'CYB580-BATCHED'
);
SET @TransactionId = SCOPE_IDENTITY();

INSERT INTO SFin.TransactionDetails (RowStatus, TransactionID, Description, Net, Vat, Gross, RIBAStageId)
VALUES (1, @TransactionId, N'CYB-580 batched invoice line', @Net, @Net * 0.2, @Net * 1.2, @RibaStageId);
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@JobId", SqlDbType.Int) { Value = jobId },
                new SqlParameter("@RibaStageId", SqlDbType.Int) { Value = ribaStageId },
                new SqlParameter("@Net", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = net }
            });
        await command.ExecuteNonQueryAsync();
    }

    private static async Task ExecuteCreateInvoiceRequestAsync(SqlConnection connection, SqlTransaction transaction, Guid activityGuid)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SJob.ActivityCreateInvoiceRequest",
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = activityGuid } });
        command.CommandType = CommandType.StoredProcedure;
        await command.ExecuteNonQueryAsync();
    }

    private static Task ExecuteActivityItemUpsertAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        ItemRow item,
        ActivityFixture fixture,
        Guid ribaStageGuid)
        => ExecuteItemUpsertAsync(connection, transaction, item.InvoiceRequestGuid, item.ItemGuid, fixture.MilestoneGuid, fixture.ActivityGuid, ActivityValue, ribaStageGuid);

    private static Task ExecuteStageItemUpsertAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid invoiceRequestGuid,
        Guid itemGuid,
        decimal net,
        Guid ribaStageGuid)
        => ExecuteItemUpsertAsync(connection, transaction, invoiceRequestGuid, itemGuid, Guid.Empty, Guid.Empty, net, ribaStageGuid);

    private static async Task ExecuteItemUpsertAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid invoiceRequestGuid,
        Guid itemGuid,
        Guid milestoneGuid,
        Guid activityGuid,
        decimal net,
        Guid ribaStageGuid)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SFin.InvoiceRequestItemsUpsert",
            new[]
            {
                new SqlParameter("@InvoiceRequestGuid", SqlDbType.UniqueIdentifier) { Value = invoiceRequestGuid },
                new SqlParameter("@MilestoneGuid", SqlDbType.UniqueIdentifier) { Value = milestoneGuid },
                new SqlParameter("@ActivityGuid", SqlDbType.UniqueIdentifier) { Value = activityGuid },
                new SqlParameter("@Net", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = net },
                new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = itemGuid },
                new SqlParameter("@ShortDescription", SqlDbType.NVarChar, 200) { Value = string.Empty },
                new SqlParameter("@RIBAStageGuid", SqlDbType.UniqueIdentifier) { Value = ribaStageGuid }
            });
        command.CommandType = CommandType.StoredProcedure;
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<ItemRow> ReadItemAsync(SqlConnection connection, SqlTransaction transaction, long activityId)
    {
        const string sql = """
SELECT iri.Guid, ir.Guid, iri.RIBAStageId
FROM SFin.InvoiceRequestItems AS iri
JOIN SFin.InvoiceRequests AS ir ON ir.ID = iri.InvoiceRequestId
WHERE iri.ActivityId = @ActivityId
  AND iri.RowStatus NOT IN (0, 254)
  AND ir.RowStatus NOT IN (0, 254);
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[] { new SqlParameter("@ActivityId", SqlDbType.BigInt) { Value = activityId } });
        await using var reader = await command.ExecuteReaderAsync();

        Assert.True(await reader.ReadAsync(), "No Invoice Request Item exists for the Activity.");
        var row = new ItemRow(reader.GetGuid(0), reader.GetGuid(1), reader.IsDBNull(2) ? null : reader.GetInt32(2));
        Assert.False(await reader.ReadAsync(), "More than one Invoice Request Item exists for the Activity.");
        return row;
    }

    /// <summary>
    /// Ensures the Invoice Request Item Net and RIBAStageId entity properties exist (the R4
    /// fixtures register the SFin.InvoiceRequestItems HoBT) and returns the RIBAStageId Guid.
    /// </summary>
    private static async Task<Guid> SeedInvoiceRequestItemPropertiesAsync(SqlConnection connection, SqlTransaction transaction)
    {
        const string sql = """
INSERT INTO SCore.EntityProperties (RowStatus, Guid, Name, EntityHoBTID)
SELECT 1, NEWID(), seed.Name, eh.ID
FROM (VALUES (N'Net'), (N'RIBAStageId')) AS seed(Name)
JOIN SCore.EntityHobts AS eh
  ON eh.SchemaName = N'SFin'
 AND eh.ObjectName = N'InvoiceRequestItems'
 AND eh.RowStatus NOT IN (0, 254)
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.EntityProperties AS ep
    WHERE ep.EntityHoBTID = eh.ID
      AND ep.Name = seed.Name
);

SELECT ep.Guid
FROM SCore.EntityProperties AS ep
JOIN SCore.EntityHobts AS eh ON eh.ID = ep.EntityHoBTID
WHERE eh.SchemaName = N'SFin'
  AND eh.ObjectName = N'InvoiceRequestItems'
  AND ep.Name = N'RIBAStageId'
  AND ep.RowStatus NOT IN (0, 254);
""";
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql);
        var propertyGuid = await command.ExecuteScalarAsync();
        Assert.False(propertyGuid is null or DBNull, "The SFin.InvoiceRequestItems HoBT fixture is required.");
        return (Guid)propertyGuid;
    }

    /// <summary>
    /// Validates a new Invoice Request Item for the Activity with the given RIBA stage and returns
    /// the result for the RIBAStageId property (not read-only, valid and no message when none).
    /// </summary>
    private static async Task<PropertyValidation> ReadRibaStageValidationAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid ribaStagePropertyGuid,
        Guid activityGuid,
        Guid ribaStageGuid)
    {
        const string sql = """
SELECT v.IsReadOnly, v.IsInvalid, v.Message
FROM SFin.tvf_InvoiceRequestItemsValidate(@Guid, @MilestoneGuid, @ActivityGuid, @RibaStageGuid, @Net) AS v
WHERE v.TargetGuid = @PropertyGuid
  AND v.TargetType = 'P';
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = Guid.NewGuid() },
                new SqlParameter("@MilestoneGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Empty },
                new SqlParameter("@ActivityGuid", SqlDbType.UniqueIdentifier) { Value = activityGuid },
                new SqlParameter("@RibaStageGuid", SqlDbType.UniqueIdentifier) { Value = ribaStageGuid },
                new SqlParameter("@Net", SqlDbType.Decimal) { Value = ActivityValue },
                new SqlParameter("@PropertyGuid", SqlDbType.UniqueIdentifier) { Value = ribaStagePropertyGuid }
            });
        await using var reader = await command.ExecuteReaderAsync();

        if (!await reader.ReadAsync())
        {
            return new PropertyValidation(false, false, string.Empty);
        }

        var result = new PropertyValidation(reader.GetBoolean(0), reader.GetBoolean(1), reader.GetString(2));
        Assert.False(await reader.ReadAsync(), "More than one validation result exists for the RIBA stage.");
        return result;
    }
}
