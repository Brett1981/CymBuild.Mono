using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// CYB-572: the Activity "Request Invoice" action (SJob.ActivityCreateInvoiceRequest) failed
/// with "expects parameter '@IsWIP', which was not supplied" once SFin.InvoiceRequestUpsert
/// gained the required @IsWIP/@WIPReason parameters for Invoice Request WIP. The action now
/// creates a non-WIP request, matching the column defaults.
/// </summary>
public sealed class ActivityCreateInvoiceRequestTests
{
    private static readonly Guid TestIdentityGuid = Guid.Parse("D4D00004-0000-4000-8000-000000000001");
    private static readonly Guid InvoiceRequestsEntityTypeGuid = Guid.Parse("D4D00572-0000-4000-8000-000000000001");

    [Fact]
    public async Task ActivityCreateInvoiceRequest_CreatesANonWipRequestForACompletedActivity()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var fixture = await InsertActivityFixtureAsync(connection, transaction, isComplete: true);

            await ExecuteCreateInvoiceRequestAsync(connection, transaction, fixture.ActivityGuid);

            const string sql = """
SELECT ir.JobId, ir.isWIP, ir.WIPReason, et.Guid AS EntityTypeGuid
FROM SFin.InvoiceRequestItems AS iri
JOIN SFin.InvoiceRequests AS ir ON ir.ID = iri.InvoiceRequestId
JOIN SCore.DataObjects AS dob ON dob.Guid = ir.Guid
JOIN SCore.EntityTypes AS et ON et.ID = dob.EntityTypeId
WHERE iri.ActivityId = @ActivityId
  AND iri.RowStatus NOT IN (0, 254)
  AND ir.RowStatus NOT IN (0, 254);
""";
            await using var command = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                sql,
                new[] { new SqlParameter("@ActivityId", SqlDbType.BigInt) { Value = fixture.ActivityId } });
            await using var reader = await command.ExecuteReaderAsync();

            Assert.True(await reader.ReadAsync(), "Request Invoice did not create an Invoice Request for the Activity.");
            Assert.Equal(fixture.JobId, reader.GetInt32(0));
            Assert.False(reader.GetBoolean(1));
            Assert.Equal(string.Empty, reader.GetString(2));
            Assert.Equal(InvoiceRequestsEntityTypeGuid, reader.GetGuid(3));
            Assert.False(await reader.ReadAsync(), "Request Invoice created more than one Invoice Request for the Activity.");
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task ActivityCreateInvoiceRequest_RefusesAnIncompleteActivity()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var fixture = await InsertActivityFixtureAsync(connection, transaction, isComplete: false);

            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteCreateInvoiceRequestAsync(connection, transaction, fixture.ActivityGuid));
            Assert.Equal(60000, error.Number);
            Assert.Contains("The Activity must be complete before it can be invoiced.", error.Message, StringComparison.Ordinal);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    private sealed record ActivityFixture(int JobId, long ActivityId, Guid ActivityGuid);

    /// <summary>
    /// Inserts a Job (surveyed and finance-accounted by the R4 fixtures), a Milestone, an
    /// ActivityStatus and an Activity on that Milestone. Zero fee/value keeps
    /// SFin.InvoiceRequestItemsUpsert's remaining-fee check satisfied without fee rows.
    /// </summary>
    private static async Task<ActivityFixture> InsertActivityFixtureAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        bool isComplete)
    {
        var accountId = await SqlTestData.ReadActiveAccountIdAsync(connection, transaction);
        var jobGuid = Guid.NewGuid();
        var activityGuid = Guid.NewGuid();

        const string sql = """
DECLARE @SurveyorId int = (SELECT ID FROM SCore.Identities WHERE Guid = @SurveyorGuid);
DECLARE @JobId int, @MilestoneId bigint, @ActivityStatusId int;

INSERT INTO SJob.Jobs (RowStatus, Guid, Number, SurveyorID, JobDescription, FinanceAccountID)
VALUES (1, @JobGuid, N'CYB572-JOB', @SurveyorId, N'CYB-572 Request Invoice fixture', @AccountId);
SET @JobId = SCOPE_IDENTITY();

INSERT INTO SJob.Milestones (RowStatus, Guid, JobID, Description)
VALUES (1, NEWID(), @JobId, N'CYB-572 fixture milestone');
SET @MilestoneId = SCOPE_IDENTITY();

INSERT INTO SJob.ActivityStatus (RowStatus, Guid, Name, IsActive, IsCompleteStatus)
VALUES (1, NEWID(), N'CYB-572 fixture status', 1, @IsComplete);
SET @ActivityStatusId = SCOPE_IDENTITY();

INSERT INTO SJob.Activities (RowStatus, Guid, JobID, MilestoneID, SurveyorID, ActivityStatusID, Title)
VALUES (1, @ActivityGuid, @JobId, @MilestoneId, @SurveyorId, @ActivityStatusId, N'CYB-572 fixture activity');

SELECT @JobId, CONVERT(bigint, SCOPE_IDENTITY());
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@SurveyorGuid", SqlDbType.UniqueIdentifier) { Value = TestIdentityGuid },
                new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid },
                new SqlParameter("@AccountId", SqlDbType.Int) { Value = accountId },
                new SqlParameter("@IsComplete", SqlDbType.Bit) { Value = isComplete },
                new SqlParameter("@ActivityGuid", SqlDbType.UniqueIdentifier) { Value = activityGuid }
            });

        int jobId;
        long activityId;
        await using (var reader = await command.ExecuteReaderAsync())
        {
            Assert.True(await reader.ReadAsync());
            jobId = reader.GetInt32(0);
            activityId = reader.GetInt64(1);
        }

        await SqlTestData.ExecuteUpsertDataObjectAsync(connection, transaction, jobGuid, "SJob", "Jobs");

        return new ActivityFixture(jobId, activityId, activityGuid);
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
}
