using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// CYB-572: the "Activities Complete Not Invoiced" grid (SJob.tvf_UnBilledActivities) must hide
/// an activity as soon as any live SFin.TransactionDetails row references it. The previous body
/// only hid activities with exactly one live line, so an activity invoiced across two or more
/// lines (job 9800 "SUS Report Issued") was reported as unbilled.
/// </summary>
public sealed class UnBilledActivitiesTransactionTests
{
    private const byte Active = 1;
    private const byte SoftDeleted = 254;
    private const int CompletedActivityStatusId = 3;

    [Theory]
    [InlineData(0, Active, true)]
    [InlineData(1, Active, false)]
    [InlineData(2, Active, false)]
    [InlineData(2, SoftDeleted, true)]
    public async Task UnBilledActivities_HidesAnActivityWithAnyLiveTransactionLine(
        int transactionLineCount,
        byte lineRowStatus,
        bool expectListed)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var (userId, activityId) = await InsertCompletedBillableActivityAsync(connection, transaction);

            for (var line = 0; line < transactionLineCount; line++)
            {
                await InsertTransactionLineAsync(connection, transaction, activityId, lineRowStatus);
            }

            Assert.Equal(expectListed, await IsListedAsync(connection, transaction, userId, activityId));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    private static async Task<(int UserId, long ActivityId)> InsertCompletedBillableActivityAsync(
        SqlConnection connection,
        SqlTransaction transaction)
    {
        const string sql = """
DECLARE @UserId int, @OrgUnitId int, @JobTypeId int, @SectorId int, @ActivityTypeId int, @JobId int;
DECLARE @Ids TABLE (ID bigint NOT NULL);

INSERT INTO SCore.Identities (RowStatus, Guid, FullName, EmailAddress, UserGuid)
VALUES (1, NEWID(), N'CYB-572 unbilled fixture', @Email, NEWID());
SET @UserId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO SCore.OrganisationalUnits (RowStatus, Name) VALUES (1, N'CYB-572 unbilled BU');
SET @OrgUnitId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO SJob.JobTypes (RowStatus, Guid, Name) VALUES (1, NEWID(), N'CYB-572 unbilled job type');
SET @JobTypeId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO SCore.Sectors (RowStatus, Guid, Name) VALUES (1, NEWID(), N'CYB-572 unbilled sector');
SET @SectorId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO SJob.ActivityTypes (RowStatus, Guid, Name, IsBillable) VALUES (1, NEWID(), N'CYB-572 billable', 1);
SET @ActivityTypeId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO SJob.Jobs (RowStatus, Guid, Number, SurveyorID, JobDescription, OrganisationalUnitId, JobTypeID, SectorId)
VALUES (1, NEWID(), N'CYB572-UB', @UserId, N'CYB-572 unbilled fixture job', @OrgUnitId, @JobTypeId, @SectorId);
SET @JobId = CONVERT(int, SCOPE_IDENTITY());

INSERT INTO SJob.Activities (RowStatus, Guid, JobID, SurveyorID, ActivityStatusID, ActivityTypeID, Title)
OUTPUT INSERTED.ID INTO @Ids (ID)
VALUES (1, NEWID(), @JobId, @UserId, @CompletedStatusId, @ActivityTypeId, N'CYB-572 SUS Report Issued');

SELECT @UserId AS UserId, (SELECT ID FROM @Ids) AS ActivityId;
""";

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@Email", SqlDbType.NVarChar, 250) { Value = $"cyb572-{Guid.NewGuid():N}@invalid.local" },
                new SqlParameter("@CompletedStatusId", SqlDbType.Int) { Value = CompletedActivityStatusId }
            });
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        return (reader.GetInt32(0), reader.GetInt64(1));
    }

    private static async Task InsertTransactionLineAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long activityId,
        byte rowStatus)
    {
        const string sql = """
INSERT INTO SFin.TransactionDetails (RowStatus, ActivityID, Description, Net, Vat, Gross)
VALUES (@RowStatus, @ActivityId, N'CYB-572 invoiced line', 100, 20, 120);
""";

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@RowStatus", SqlDbType.TinyInt) { Value = rowStatus },
                new SqlParameter("@ActivityId", SqlDbType.BigInt) { Value = activityId }
            });
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<bool> IsListedAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int userId,
        long activityId)
    {
        const string sql = """
SELECT COUNT(*)
FROM SJob.tvf_UnBilledActivities(@UserId) AS u
WHERE u.ID = @ActivityId;
""";

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@UserId", SqlDbType.Int) { Value = userId },
                new SqlParameter("@ActivityId", SqlDbType.BigInt) { Value = activityId }
            });
        return Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture) > 0;
    }
}
