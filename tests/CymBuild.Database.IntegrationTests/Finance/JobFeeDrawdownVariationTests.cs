using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// CYB-335: SJob.tvf_JobFeeDrawdown (the Job Fees table) shows Variation - New Agreed minus
/// Original Agreed, i.e. the approved fee-amendment change already included in Agreed. Only
/// amendments that count towards Agreed (zero-Guid legacy or Agreed status) are included, so a
/// Pending amendment does not move Variation until it is agreed.
/// </summary>
public sealed class JobFeeDrawdownVariationTests
{
    private static readonly Guid TestIdentityGuid = Guid.Parse("D4D00004-0000-4000-8000-000000000001");
    private static readonly Guid PendingStatusGuid = new("68C95270-1BB9-4E8B-BE4C-38746C4661BB");
    private static readonly Guid AgreedStatusGuid = new("215F258A-CF79-468F-9EB8-A84481F7F8AF");

    private const int StageA = 3351;
    private const int StageB = 3352;

    private const string TotalExFeeCap = "Total (ex. Fee Cap.)";
    private const string TotalIncFeeCap = "Total (inc. Fee Cap)";

    private static string StageKey(int stage) => stage.ToString(System.Globalization.CultureInfo.InvariantCulture);

    [Fact]
    public async Task Variation_IsTheAgreedAmendmentChange_PerStageAndOnBothTotals()
    {
        await RunAsync(async (connection, transaction, job) =>
        {
            await InsertStageFeeAsync(connection, transaction, job.JobId, StageA, 1000.00m);
            await InsertStageFeeAsync(connection, transaction, job.JobId, StageB, 500.00m);

            var agreed = await InsertFeeAmendmentAsync(connection, transaction, job.JobId, AgreedStatusGuid, feeCapChange: 40.00m);
            await InsertCustomAmendmentAsync(connection, transaction, job.JobId, agreed, StageA, 250.00m);
            await InsertCustomAmendmentAsync(connection, transaction, job.JobId, agreed, StageB, -100.00m);

            var pending = await InsertFeeAmendmentAsync(connection, transaction, job.JobId, PendingStatusGuid, feeCapChange: 999.00m);
            await InsertCustomAmendmentAsync(connection, transaction, job.JobId, pending, StageA, 999.00m);

            var rows = await ReadFeeDrawdownAsync(connection, transaction, job.JobGuid);

            Assert.Equal(new FeeRow(1250.00m, 250.00m), rows[StageKey(StageA)]);
            Assert.Equal(new FeeRow(400.00m, -100.00m), rows[StageKey(StageB)]);
            Assert.Equal(new FeeRow(1650.00m, 150.00m), rows[TotalExFeeCap]);
            Assert.Equal(new FeeRow(1690.00m, 190.00m), rows[TotalIncFeeCap]);
        });
    }

    [Fact]
    public async Task StageKeyedAmendment_ShowsOnItsStage_AndEveryRowKeepsAgreedMinusVariationAsTheOriginalFee()
    {
        await RunAsync(async (connection, transaction, job) =>
        {
            await InsertStageFeeAsync(connection, transaction, job.JobId, StageA, 1000.00m);

            var agreed = await InsertFeeAmendmentAsync(connection, transaction, job.JobId, AgreedStatusGuid, feeCapChange: 0m);
            await InsertStageKeyedAmendmentAsync(connection, transaction, job.JobId, agreed, StageA, 300.00m);

            var pending = await InsertFeeAmendmentAsync(connection, transaction, job.JobId, PendingStatusGuid, feeCapChange: 0m);
            await InsertStageKeyedAmendmentAsync(connection, transaction, job.JobId, pending, StageA, 999.00m);

            var rows = await ReadFeeDrawdownAsync(connection, transaction, job.JobGuid);

            Assert.Equal(new FeeRow(1300.00m, 300.00m), rows[StageKey(StageA)]);
            Assert.Equal(new FeeRow(0.00m, 0.00m), rows[StageKey(StageB)]);
            Assert.Equal(1000.00m, rows[TotalExFeeCap].Agreed - rows[TotalExFeeCap].Variation);
            Assert.Equal(1000.00m, rows[TotalIncFeeCap].Agreed - rows[TotalIncFeeCap].Variation);
        });
    }

    [Fact]
    public async Task JobWithNoAmendments_ShowsZeroVariation_OnEveryRow()
    {
        await RunAsync(async (connection, transaction, job) =>
        {
            await InsertStageFeeAsync(connection, transaction, job.JobId, StageA, 1000.00m);

            var rows = await ReadFeeDrawdownAsync(connection, transaction, job.JobGuid);

            Assert.Contains(TotalExFeeCap, rows.Keys);
            Assert.Contains(TotalIncFeeCap, rows.Keys);
            Assert.All(rows.Values, row => Assert.Equal(0.00m, row.Variation));
            Assert.Equal(1000.00m, rows[StageKey(StageA)].Agreed);
        });
    }

    private sealed record JobFixture(int JobId, Guid JobGuid);

    private sealed record FeeRow(decimal Agreed, decimal Variation);

    private static async Task RunAsync(Func<SqlConnection, SqlTransaction, JobFixture, Task> test)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            await SqlTestData.EnsureRibaStagesAsync(connection, transaction, new[] { StageA, StageB });
            var job = await InsertJobAsync(connection, transaction);
            await test(connection, transaction, job);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    private static async Task<JobFixture> InsertJobAsync(SqlConnection connection, SqlTransaction transaction)
    {
        var jobGuid = Guid.NewGuid();

        const string sql = """
IF NOT EXISTS (SELECT 1 FROM SJob.FeeAmendmentStatus WHERE Guid = @PendingStatusGuid)
    INSERT INTO SJob.FeeAmendmentStatus (RowStatus, Guid, Name) VALUES (1, @PendingStatusGuid, N'Pending');
IF NOT EXISTS (SELECT 1 FROM SJob.FeeAmendmentStatus WHERE Guid = @AgreedStatusGuid)
    INSERT INTO SJob.FeeAmendmentStatus (RowStatus, Guid, Name) VALUES (1, @AgreedStatusGuid, N'Agreed');

DECLARE @SurveyorId int = (SELECT ID FROM SCore.Identities WHERE Guid = @SurveyorGuid);

INSERT INTO SJob.Jobs (RowStatus, Guid, Number, SurveyorID, JobDescription)
OUTPUT INSERTED.ID
VALUES (1, @JobGuid, N'CYB335-JOB', @SurveyorId, N'CYB-335 fee variation fixture');
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@PendingStatusGuid", SqlDbType.UniqueIdentifier) { Value = PendingStatusGuid },
                new SqlParameter("@AgreedStatusGuid", SqlDbType.UniqueIdentifier) { Value = AgreedStatusGuid },
                new SqlParameter("@SurveyorGuid", SqlDbType.UniqueIdentifier) { Value = TestIdentityGuid },
                new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid }
            });
        var jobId = Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
        return new JobFixture(jobId, jobGuid);
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

    private static async Task<long> InsertFeeAmendmentAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int jobId,
        Guid statusGuid,
        decimal feeCapChange)
    {
        const string sql = """
INSERT INTO SJob.FeeAmendment (RowStatus, Guid, JobID, FeeCapChange, FeeAmendmentStatusID, Reason)
OUTPUT INSERTED.ID
SELECT 1, NEWID(), @JobId, @FeeCapChange, fas.ID, N'CYB-335 fixture'
FROM SJob.FeeAmendmentStatus AS fas
WHERE fas.Guid = @StatusGuid;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@JobId", SqlDbType.Int) { Value = jobId },
                new SqlParameter("@FeeCapChange", SqlDbType.Decimal) { Precision = 9, Scale = 2, Value = feeCapChange },
                new SqlParameter("@StatusGuid", SqlDbType.UniqueIdentifier) { Value = statusGuid }
            });
        return Convert.ToInt64(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }

    private static async Task InsertCustomAmendmentAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int jobId,
        long feeAmendmentId,
        int stageId,
        decimal stageChange)
    {
        const string sql = """
INSERT INTO SJob.CustomFeeAmendment (RowStatus, Guid, JobID, StageId, StageChange, FeeAmendmentId, Reason)
VALUES (1, NEWID(), @JobId, @StageId, @StageChange, @FeeAmendmentId, N'CYB-335 fixture');
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@JobId", SqlDbType.Int) { Value = jobId },
                new SqlParameter("@StageId", SqlDbType.Int) { Value = stageId },
                new SqlParameter("@StageChange", SqlDbType.Decimal) { Precision = 9, Scale = 2, Value = stageChange },
                new SqlParameter("@FeeAmendmentId", SqlDbType.BigInt) { Value = feeAmendmentId }
            });
        await command.ExecuteNonQueryAsync();
    }

    private static async Task InsertStageKeyedAmendmentAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int jobId,
        long feeAmendmentId,
        int ribaStageId,
        decimal feeChange)
    {
        const string sql = """
INSERT INTO SJob.FeeAmendmentRibaStages (RowStatus, Guid, FeeAmendmentID, JobID, RibaStageID, FeeChange)
VALUES (1, NEWID(), @FeeAmendmentId, @JobId, @RibaStageId, @FeeChange);
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@FeeAmendmentId", SqlDbType.BigInt) { Value = feeAmendmentId },
                new SqlParameter("@JobId", SqlDbType.Int) { Value = jobId },
                new SqlParameter("@RibaStageId", SqlDbType.Int) { Value = ribaStageId },
                new SqlParameter("@FeeChange", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = feeChange }
            });
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<Dictionary<string, FeeRow>> ReadFeeDrawdownAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid jobGuid)
    {
        const string sql = """
DECLARE @UserId int = (SELECT ID FROM SCore.Identities WHERE Guid = @UserGuid);

SELECT fd.Stage, fd.Agreed, fd.Variation
FROM SJob.tvf_JobFeeDrawdown(@UserId, @JobGuid) AS fd;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@UserGuid", SqlDbType.UniqueIdentifier) { Value = TestIdentityGuid },
                new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid }
            });
        await using var reader = await command.ExecuteReaderAsync();

        var rows = new Dictionary<string, FeeRow>(StringComparer.Ordinal);
        while (await reader.ReadAsync())
        {
            rows.Add(reader.GetString(0), new FeeRow(reader.GetDecimal(1), reader.GetDecimal(2)));
        }

        return rows;
    }
}
