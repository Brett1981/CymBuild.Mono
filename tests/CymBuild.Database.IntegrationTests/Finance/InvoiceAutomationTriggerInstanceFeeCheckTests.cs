using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// CYB-580 QA (job 9889): invoice automation raised requests for completed Activities through
/// SFin.InvoiceAutomation_CreateInvoiceRequests_FromTriggerInstances, which wrote the items
/// directly with no RIBA stage, no fee check and no check that the Activity was already on a
/// request. Stages went negative and one Activity was invoiced twice.
/// Automation now allocates the item to the Activity's stage (-1 when it has none), skips an
/// Activity already on a request or an invoice, and runs the same fee check as
/// SFin.InvoiceRequestItemsUpsert through SFin.tvf_InvoiceRequestItemFeeCheck. A failed fee check
/// does not stop the request being raised; it is flagged for reconciliation with the reason.
/// SFin.InvoiceRequestCreateInvoice then refuses to invoice a request above the agreed fee less
/// invoices already raised, whichever route created it; other requests not yet invoiced are not
/// counted, so a flagged request cannot block a valid one.
/// </summary>
public sealed class InvoiceAutomationTriggerInstanceFeeCheckTests
{
    private static readonly Guid TestIdentityGuid = Guid.Parse("D4D00004-0000-4000-8000-000000000001");

    private const int StageWithFee = 5811;
    private const int StageWithoutFee = 5812;
    private const decimal AgreedFee = 1000.00m;

    [Fact]
    public async Task ActivityItem_IsAllocatedToTheActivitysRibaStage()
    {
        await RunAsync([(StageWithFee, 100.00m)], async (connection, transaction, activities) =>
        {
            Assert.Equal(1, await ExecuteAutomationAsync(connection, transaction));

            var item = await ReadAutomatedItemAsync(connection, transaction, activities[0].Id);
            Assert.Equal(StageWithFee, item.RibaStageId);
            Assert.False(item.ReconciliationRequired);
            Assert.Equal(string.Empty, item.ReconciliationReason);
        });
    }

    [Fact]
    public async Task UnstagedActivityItem_GetsTheNoRibaStageSentinel()
    {
        await RunAsync([(-1, 100.00m)], async (connection, transaction, activities) =>
        {
            Assert.Equal(1, await ExecuteAutomationAsync(connection, transaction));

            Assert.Equal(-1, (await ReadAutomatedItemAsync(connection, transaction, activities[0].Id)).RibaStageId);
        });
    }

    [Fact]
    public async Task ActivityOnAStageWithNoAgreedFee_IsRaisedButFlaggedForReconciliation()
    {
        await RunAsync([(StageWithoutFee, 100.00m)], async (connection, transaction, activities) =>
        {
            Assert.Equal(1, await ExecuteAutomationAsync(connection, transaction));

            var item = await ReadAutomatedItemAsync(connection, transaction, activities[0].Id);
            Assert.Equal(StageWithoutFee, item.RibaStageId);
            Assert.True(item.ReconciliationRequired);
            Assert.Contains("CYB-580 automation stage without fee\" has no agreed fee", item.ReconciliationReason, StringComparison.Ordinal);
        });
    }

    [Fact]
    public async Task ActivityAboveTheRemainingStageFee_IsRaisedButFlaggedForReconciliation()
    {
        await RunAsync([(StageWithFee, AgreedFee + 200.00m)], async (connection, transaction, activities) =>
        {
            Assert.Equal(1, await ExecuteAutomationAsync(connection, transaction));

            var item = await ReadAutomatedItemAsync(connection, transaction, activities[0].Id);
            Assert.Equal(AgreedFee + 200.00m, item.Net);
            Assert.True(item.ReconciliationRequired);
            Assert.Contains("item £1200.00 exceeds the £1000.00 remaining", item.ReconciliationReason, StringComparison.Ordinal);
        });
    }

    [Fact]
    public async Task ActivityAlreadyOnAnInvoiceRequest_IsNotRequestedAgain()
    {
        await RunAsync([(StageWithFee, 100.00m)], async (connection, transaction, activities) =>
        {
            await ExecuteManualCreateInvoiceRequestAsync(connection, transaction, activities[0].Guid);

            Assert.Equal(0, await ExecuteAutomationAsync(connection, transaction));
            Assert.Equal(1, await CountActiveItemsAsync(connection, transaction, activities[0].Id));
        });
    }

    [Fact]
    public async Task CreateInvoice_InvoicesARequestWithinTheStageFee()
    {
        await RunAsync([(StageWithFee, 100.00m)], async (connection, transaction, activities) =>
        {
            await ExecuteManualCreateInvoiceRequestAsync(connection, transaction, activities[0].Guid);

            await ExecuteCreateInvoiceAsync(connection, transaction, await ReadRequestGuidAsync(connection, transaction, activities[0].Id));

            Assert.Equal((100.00m, StageWithFee), await ReadInvoiceLineAsync(connection, transaction, activities[0].Id));
        });
    }

    [Fact]
    public async Task CreateInvoice_RefusesAFlaggedRequestOnAStageWithNoAgreedFee()
    {
        await RunAsync([(StageWithoutFee, 100.00m)], async (connection, transaction, activities) =>
        {
            Assert.Equal(1, await ExecuteAutomationAsync(connection, transaction));
            var requestGuid = await ReadRequestGuidAsync(connection, transaction, activities[0].Id);

            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteCreateInvoiceAsync(connection, transaction, requestGuid));
            Assert.Equal(51003, error.Number);
            Assert.Contains("CYB-580 automation stage without fee\" has no agreed fee", error.Message, StringComparison.Ordinal);
            Assert.Null(await ReadInvoiceLineAsync(connection, transaction, activities[0].Id));
        });
    }

    [Fact]
    public async Task CreateInvoice_AFlaggedRequestDoesNotBlockAValidOne()
    {
        // The manual request takes 600 of the 1000 agreed; automation then raises 600 more and
        // flags it. The manual request still invoices; the flagged one is refused.
        await RunAsync([(StageWithFee, 600.00m), (StageWithFee, 600.00m)], async (connection, transaction, activities) =>
        {
            await ExecuteManualCreateInvoiceRequestAsync(connection, transaction, activities[0].Guid);
            Assert.Equal(1, await ExecuteAutomationAsync(connection, transaction));
            Assert.True((await ReadAutomatedItemAsync(connection, transaction, activities[1].Id)).ReconciliationRequired);

            await ExecuteCreateInvoiceAsync(connection, transaction, await ReadRequestGuidAsync(connection, transaction, activities[0].Id));
            Assert.Equal((600.00m, StageWithFee), await ReadInvoiceLineAsync(connection, transaction, activities[0].Id));

            var flaggedRequestGuid = await ReadRequestGuidAsync(connection, transaction, activities[1].Id);
            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteCreateInvoiceAsync(connection, transaction, flaggedRequestGuid));
            Assert.Equal(51003, error.Number);
            Assert.Contains("only £400.00 for RIBA stage \"CYB-580 automation stage with fee\"", error.Message, StringComparison.Ordinal);
            Assert.Contains("this request invoices £600.00", error.Message, StringComparison.Ordinal);
            Assert.Null(await ReadInvoiceLineAsync(connection, transaction, activities[1].Id));
        });
    }

    private sealed record FixtureActivity(long Id, Guid Guid);

    private sealed record AutomatedItem(int? RibaStageId, decimal Net, bool ReconciliationRequired, string ReconciliationReason);

    private static async Task RunAsync(
        (int StageId, decimal Value)[] activities,
        Func<SqlConnection, SqlTransaction, IReadOnlyList<FixtureActivity>, Task> test)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var jobId = await InsertJobFixtureAsync(connection, transaction);

            var inserted = new List<FixtureActivity>();
            foreach (var (stageId, value) in activities)
            {
                inserted.Add(await InsertCompletedActivityAsync(connection, transaction, jobId, stageId, value));
            }

            await test(connection, transaction, inserted);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    /// <summary>
    /// Inserts two RIBA stages, an invoiceable Job (coded finance account, org unit, job type and
    /// asset) open to invoice automation with an agreed fee on only the first stage, and an
    /// invoice schedule linked to the Job through a quote item. Returns the Job ID.
    /// </summary>
    private static async Task<int> InsertJobFixtureAsync(SqlConnection connection, SqlTransaction transaction)
    {
        var jobGuid = Guid.NewGuid();

        const string sql = """
SET IDENTITY_INSERT SJob.RibaStages ON;
IF NOT EXISTS (SELECT 1 FROM SJob.RibaStages WHERE ID = @StageWithFee)
    INSERT INTO SJob.RibaStages (ID, RowStatus, Number, Description, IsRealStage)
    VALUES (@StageWithFee, 1, @StageWithFee, N'CYB-580 automation stage with fee', 1);
IF NOT EXISTS (SELECT 1 FROM SJob.RibaStages WHERE ID = @StageWithoutFee)
    INSERT INTO SJob.RibaStages (ID, RowStatus, Number, Description, IsRealStage)
    VALUES (@StageWithoutFee, 1, @StageWithoutFee, N'CYB-580 automation stage without fee', 1);
SET IDENTITY_INSERT SJob.RibaStages OFF;

IF NOT EXISTS (SELECT 1 FROM SFin.InvoicePaymentStatus WHERE RowStatus NOT IN (0, 254))
    INSERT INTO SFin.InvoicePaymentStatus (RowStatus, Guid, Name) VALUES (1, NEWID(), N'CYB-580 unpaid');

IF NOT EXISTS (SELECT 1 FROM SFin.TransactionTypes WHERE Name = N'Invoice')
    INSERT INTO SFin.TransactionTypes (Name, IsActive, IsBank, IsNegated) VALUES (N'Invoice', 1, 0, 0);

DECLARE @CreditTermsId int = (SELECT TOP (1) ID FROM SFin.CreditTerms WHERE RowStatus NOT IN (0, 254) ORDER BY ID);
DECLARE @SurveyorId int = (SELECT ID FROM SCore.Identities WHERE Guid = @SurveyorGuid);
DECLARE @AccountId int, @OrgUnitId int, @JobTypeId int, @AssetId int, @JobId int, @ScheduleId int;

INSERT INTO SCrm.Accounts (RowStatus, Name, Code, DefaultCreditTermsId)
VALUES (1, N'CYB-580 automation account', N'CYB580', @CreditTermsId);
SET @AccountId = SCOPE_IDENTITY();

INSERT INTO SCore.OrganisationalUnits (RowStatus, Name, DepartmentPrefix)
VALUES (1, N'CYB-580 automation org unit', N'CYB580-');
SET @OrgUnitId = SCOPE_IDENTITY();

INSERT INTO SJob.JobTypes (RowStatus, Guid, Name) VALUES (1, NEWID(), N'CYB-580 automation job type');
SET @JobTypeId = SCOPE_IDENTITY();

INSERT INTO SJob.Assets (RowStatus, Guid, Name) VALUES (1, NEWID(), N'CYB-580 automation asset');
SET @AssetId = SCOPE_IDENTITY();

INSERT INTO SJob.Jobs (RowStatus, Guid, Number, SurveyorID, JobDescription, FinanceAccountID, OrganisationalUnitId, JobTypeID, UprnID, PurchaseOrderNumber, InvoiceProcessingMode)
VALUES (1, @JobGuid, N'CYB580-AUTO', @SurveyorId, N'CYB-580 invoice automation fixture', @AccountId, @OrgUnitId, @JobTypeId, @AssetId, N'PO-CYB580', 0);
SET @JobId = SCOPE_IDENTITY();

INSERT INTO SJob.JobRibaStageFees (RowStatus, Guid, JobID, RibaStageID, CreatedFromQuoteItemID, AgreedFee)
VALUES (1, NEWID(), @JobId, @StageWithFee, -1, @AgreedFee);

INSERT INTO SFin.InvoiceSchedules (RowStatus, Name, QuoteId)
VALUES (1, N'CYB-580 activity schedule', -1);
SET @ScheduleId = SCOPE_IDENTITY();

INSERT INTO SSop.QuoteItems (RowStatus, QuoteId, CreatedJobId, InvoicingSchedule)
VALUES (1, -1, @JobId, @ScheduleId);

SELECT @JobId;
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
                new SqlParameter("@AgreedFee", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = AgreedFee }
            });
        var jobId = Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);

        await SqlTestData.ExecuteUpsertDataObjectAsync(connection, transaction, jobGuid, "SJob", "Jobs");

        return jobId;
    }

    /// <summary>
    /// Inserts a completed billable Activity with an invoicing value on the given stage (-1 for no
    /// stage) and its Activity trigger instance on the Job's invoice schedule.
    /// </summary>
    private static async Task<FixtureActivity> InsertCompletedActivityAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int jobId,
        int stageId,
        decimal value)
    {
        var activityGuid = Guid.NewGuid();

        const string sql = """
DECLARE @SurveyorId int = (SELECT ID FROM SCore.Identities WHERE Guid = @SurveyorGuid);
DECLARE @MilestoneId bigint, @ActivityStatusId int, @ActivityTypeId int, @ActivityId bigint;
DECLARE @ScheduleId int =
(
    SELECT TOP (1) qi.InvoicingSchedule
    FROM SSop.QuoteItems AS qi
    WHERE qi.CreatedJobId = @JobId
      AND qi.RowStatus NOT IN (0, 254)
    ORDER BY qi.ID
);

INSERT INTO SJob.Milestones (RowStatus, Guid, JobID, Description)
VALUES (1, NEWID(), @JobId, N'CYB-580 automation milestone');
SET @MilestoneId = SCOPE_IDENTITY();

INSERT INTO SJob.ActivityStatus (RowStatus, Guid, Name, IsActive, IsCompleteStatus)
VALUES (1, NEWID(), CONCAT(N'CYB-580 automation complete ', NEWID()), 1, 1);
SET @ActivityStatusId = SCOPE_IDENTITY();

INSERT INTO SJob.ActivityTypes (RowStatus, Guid, Name, IsActive, IsBillable)
VALUES (1, NEWID(), CONCAT(N'CYB-580 automation billable ', NEWID()), 1, 1);
SET @ActivityTypeId = SCOPE_IDENTITY();

INSERT INTO SJob.Activities (RowStatus, Guid, JobID, MilestoneID, SurveyorID, ActivityStatusID, ActivityTypeID, Title, RibaStageId, InvoicingValue, InvoicingQuantity, CompletedDateTimeUTC)
VALUES (1, @ActivityGuid, @JobId, @MilestoneId, @SurveyorId, @ActivityStatusId, @ActivityTypeId, N'CYB-580 automation activity', @StageId, @Value, 1, SYSUTCDATETIME());
SET @ActivityId = SCOPE_IDENTITY();

INSERT INTO SFin.InvoiceScheduleTriggerInstances (RowStatus, Guid, InvoiceScheduleId, InstanceType, InstanceKey, CompletedDateTimeUTC)
VALUES (1, NEWID(), @ScheduleId, N'Activity', N'ACT:' + CONVERT(nvarchar(50), @ActivityId), SYSUTCDATETIME());

SELECT @ActivityId;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@SurveyorGuid", SqlDbType.UniqueIdentifier) { Value = TestIdentityGuid },
                new SqlParameter("@JobId", SqlDbType.Int) { Value = jobId },
                new SqlParameter("@ActivityGuid", SqlDbType.UniqueIdentifier) { Value = activityGuid },
                new SqlParameter("@StageId", SqlDbType.Int) { Value = stageId },
                new SqlParameter("@Value", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = value }
            });
        var activityId = Convert.ToInt64(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
        return new FixtureActivity(activityId, activityGuid);
    }

    private static async Task<int> ExecuteAutomationAsync(SqlConnection connection, SqlTransaction transaction)
    {
        var created = new SqlParameter("@CreatedInvoiceRequests", SqlDbType.Int) { Direction = ParameterDirection.InputOutput, Value = 0 };
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SFin.InvoiceAutomation_CreateInvoiceRequests_FromTriggerInstances",
            new[]
            {
                new SqlParameter("@AutomationRunGuid", SqlDbType.UniqueIdentifier) { Value = Guid.NewGuid() },
                new SqlParameter("@RequesterUserGuid", SqlDbType.UniqueIdentifier) { Value = TestIdentityGuid },
                created
            });
        command.CommandType = CommandType.StoredProcedure;
        await command.ExecuteNonQueryAsync();
        return (int)created.Value;
    }

    private static Task ExecuteManualCreateInvoiceRequestAsync(SqlConnection connection, SqlTransaction transaction, Guid activityGuid)
        => ExecuteGuidProcedureAsync(connection, transaction, "SJob.ActivityCreateInvoiceRequest", activityGuid);

    private static Task ExecuteCreateInvoiceAsync(SqlConnection connection, SqlTransaction transaction, Guid invoiceRequestGuid)
        => ExecuteGuidProcedureAsync(connection, transaction, "SFin.InvoiceRequestCreateInvoice", invoiceRequestGuid);

    private static async Task ExecuteGuidProcedureAsync(SqlConnection connection, SqlTransaction transaction, string procedure, Guid guid)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            procedure,
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = guid } });
        command.CommandType = CommandType.StoredProcedure;
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<AutomatedItem> ReadAutomatedItemAsync(SqlConnection connection, SqlTransaction transaction, long activityId)
    {
        const string sql = """
SELECT iri.RIBAStageId, iri.Net, ir.ReconciliationRequired, ir.ReconciliationReason
FROM SFin.InvoiceRequestItems AS iri
JOIN SFin.InvoiceRequests AS ir ON ir.ID = iri.InvoiceRequestId
WHERE iri.ActivityId = @ActivityId
  AND iri.RowStatus NOT IN (0, 254)
  AND ir.RowStatus NOT IN (0, 254)
  AND ir.SourceType = N'TriggerInstance';
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[] { new SqlParameter("@ActivityId", SqlDbType.BigInt) { Value = activityId } });
        await using var reader = await command.ExecuteReaderAsync();

        Assert.True(await reader.ReadAsync(), "Automation raised no Invoice Request Item for the Activity.");
        var item = new AutomatedItem(
            reader.IsDBNull(0) ? null : reader.GetInt32(0),
            reader.GetDecimal(1),
            reader.GetBoolean(2),
            reader.GetString(3));
        Assert.False(await reader.ReadAsync(), "Automation raised more than one Invoice Request Item for the Activity.");
        return item;
    }

    private static async Task<Guid> ReadRequestGuidAsync(SqlConnection connection, SqlTransaction transaction, long activityId)
    {
        const string sql = """
SELECT ir.Guid
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
        var requestGuid = await command.ExecuteScalarAsync();
        Assert.False(requestGuid is null or DBNull, "No Invoice Request exists for the Activity.");
        return (Guid)requestGuid;
    }

    /// <summary>Returns the Activity's active invoice line (net and RIBA stage), or null when it has none.</summary>
    private static async Task<(decimal Net, int RibaStageId)?> ReadInvoiceLineAsync(SqlConnection connection, SqlTransaction transaction, long activityId)
    {
        const string sql = """
SELECT td.Net, td.RIBAStageID
FROM SFin.TransactionDetails AS td
JOIN SFin.Transactions AS t ON t.ID = td.TransactionID
WHERE td.ActivityID = @ActivityId
  AND td.RowStatus NOT IN (0, 254)
  AND t.RowStatus NOT IN (0, 254);
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[] { new SqlParameter("@ActivityId", SqlDbType.BigInt) { Value = activityId } });
        await using var reader = await command.ExecuteReaderAsync();

        if (!await reader.ReadAsync())
        {
            return null;
        }

        var line = (reader.GetDecimal(0), reader.GetInt32(1));
        Assert.False(await reader.ReadAsync(), "More than one invoice line exists for the Activity.");
        return line;
    }

    private static async Task<int> CountActiveItemsAsync(SqlConnection connection, SqlTransaction transaction, long activityId)
    {
        const string sql = """
SELECT COUNT(1)
FROM SFin.InvoiceRequestItems AS iri
WHERE iri.ActivityId = @ActivityId
  AND iri.RowStatus NOT IN (0, 254);
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[] { new SqlParameter("@ActivityId", SqlDbType.BigInt) { Value = activityId } });
        return Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }
}
