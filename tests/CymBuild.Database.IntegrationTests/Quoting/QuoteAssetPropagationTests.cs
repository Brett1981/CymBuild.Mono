using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Quoting;

/// <summary>
/// CYB-321: changing the Asset on a quote revision only updated that revision, so the other
/// quotes in the revision chain and the originating Enquiry kept the old Asset. SSop.QuotesUpsert now applies an Asset
/// change to every quote in the same revision chain and to the Enquiry, and leaves other quotes
/// alone.
/// </summary>
public sealed class QuoteAssetPropagationTests
{
    private static readonly Guid TestIdentityGuid = Guid.Parse("D4D00004-0000-4000-8000-000000000001");

    [Fact]
    public async Task ChangingTheAssetOnARevisionUpdatesEveryQuoteInTheChainAndTheEnquiry()
    {
        await RunInRolledBackTransactionAsync(async (connection, transaction) =>
        {
            var fixture = await InsertFixtureAsync(connection, transaction);
            var originalGuid = Guid.NewGuid();
            var revisionGuid = Guid.NewGuid();
            var secondRevisionGuid = Guid.NewGuid();
            var unrelatedGuid = Guid.NewGuid();

            await ExecuteUpsertAsync(connection, transaction, fixture, originalGuid, fixture.EnquiryServiceGuid, fixture.OldAssetGuid);
            await ExecuteUpsertAsync(connection, transaction, fixture, revisionGuid, fixture.EnquiryServiceGuid, fixture.OldAssetGuid);
            await ExecuteUpsertAsync(connection, transaction, fixture, secondRevisionGuid, fixture.EnquiryServiceGuid, fixture.OldAssetGuid);
            await ExecuteUpsertAsync(connection, transaction, fixture, unrelatedGuid, fixture.OtherEnquiryServiceGuid, fixture.OldAssetGuid);

            // A new quote does not persist its Asset, and SSop.QuotesRevise is outside the test
            // schema, so seed the starting Assets and the revision links directly. As QuotesRevise
            // does, every revision points at the original quote, not at the revision before it.
            const string chainSql = """
UPDATE SSop.Quotes SET UprnId = @OldAssetId WHERE Guid IN (@OriginalGuid, @RevisionGuid, @SecondRevisionGuid, @UnrelatedGuid);
UPDATE rev
SET rev.OriginalQuoteId = orig.ID, rev.RevisionNumber = CASE WHEN rev.Guid = @RevisionGuid THEN 1 ELSE 2 END
FROM SSop.Quotes AS rev
JOIN SSop.Quotes AS orig ON orig.Guid = @OriginalGuid
WHERE rev.Guid IN (@RevisionGuid, @SecondRevisionGuid);
""";
            await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, chainSql, new[]
            {
                new SqlParameter("@OldAssetId", SqlDbType.Int) { Value = fixture.OldAssetId },
                new SqlParameter("@OriginalGuid", SqlDbType.UniqueIdentifier) { Value = originalGuid },
                new SqlParameter("@RevisionGuid", SqlDbType.UniqueIdentifier) { Value = revisionGuid },
                new SqlParameter("@SecondRevisionGuid", SqlDbType.UniqueIdentifier) { Value = secondRevisionGuid },
                new SqlParameter("@UnrelatedGuid", SqlDbType.UniqueIdentifier) { Value = unrelatedGuid }
            }))
            {
                await command.ExecuteNonQueryAsync();
            }

            // Edit the middle revision: the change must reach both the quote before it and the one after.
            await ExecuteUpsertAsync(connection, transaction, fixture, revisionGuid, fixture.EnquiryServiceGuid, fixture.NewAssetGuid);

            Assert.Equal(fixture.NewAssetId, await QuoteAssetIdAsync(connection, transaction, revisionGuid));
            Assert.Equal(fixture.NewAssetId, await QuoteAssetIdAsync(connection, transaction, originalGuid));
            Assert.Equal(fixture.NewAssetId, await QuoteAssetIdAsync(connection, transaction, secondRevisionGuid));
            Assert.Equal(fixture.OldAssetId, await QuoteAssetIdAsync(connection, transaction, unrelatedGuid));
            Assert.Equal(fixture.NewAssetId, await EnquiryAssetIdAsync(connection, transaction, fixture.EnquiryId));
            Assert.Equal(fixture.OldAssetId, await EnquiryAssetIdAsync(connection, transaction, fixture.OtherEnquiryId));
        });
    }

    private sealed record Fixture(
        Guid OrganisationalUnitGuid,
        Guid JobTypeGuid,
        Guid StageGuid,
        Guid ProjectGuid,
        Guid EnquiryServiceGuid,
        Guid OtherEnquiryServiceGuid,
        Guid OldAssetGuid,
        Guid NewAssetGuid,
        Guid AccountGuid,
        int OldAssetId,
        int NewAssetId,
        int EnquiryId,
        int OtherEnquiryId);

    private static async Task RunInRolledBackTransactionAsync(Func<SqlConnection, SqlTransaction, Task> body)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            await body(connection, transaction);
        }
        finally
        {
            if (transaction.Connection is not null)
            {
                await transaction.RollbackAsync();
            }
        }
    }

    /// <summary>
    /// Two Enquiries on the old Asset, each with one Enquiry Service, plus a second Asset to move
    /// to, a "Quoting" workflow status (QuotesUpsert moves new quotes and their enquiry to it), and
    /// the -1 Asset/Account placeholder rows QuotesUpsert's filing-name query joins to.
    /// </summary>
    private static async Task<Fixture> InsertFixtureAsync(SqlConnection connection, SqlTransaction transaction)
    {
        const string sql = """
DECLARE @OrgUnitId int = (SELECT TOP (1) ID FROM SCore.OrganisationalUnits WHERE Name = N'CymBuild R4 Test OrgUnit');
DECLARE @JobTypeId int, @StageId int, @ProjectId int, @OldAssetId int, @NewAssetId int, @AccountId int,
        @EnquiryId int, @OtherEnquiryId int, @IsInsert bit;
DECLARE @EnquiryGuid uniqueidentifier = NEWID(), @OtherEnquiryGuid uniqueidentifier = NEWID(),
        @EnquiryServiceGuid uniqueidentifier = NEWID(), @OtherEnquiryServiceGuid uniqueidentifier = NEWID();

IF NOT EXISTS (SELECT 1 FROM SCore.WorkflowStatus WHERE Name = N'Quoting' AND ShowInQuotes = 1 AND Description = N'Automatically generated status')
BEGIN
    INSERT INTO SCore.WorkflowStatus
        (RowStatus, Guid, OrganisationalUnitId, Name, Description, ShowInEnquiries, ShowInQuotes, ShowInJobs, Enabled,
         IsPredefined, SortOrder, Colour, SendNotification, IsCompleteStatus, IsCustomerWaitingStatus, RequiresUsersAction,
         IsActiveStatus, AuthorisationNeeded, IsAuthStatus)
    VALUES (1, NEWID(), -1, N'Quoting', N'Automatically generated status', 1, 1, 0, 1, 1, 0, N'#FFFFFF', 0, 0, 0, 0, 1, 0, 0);
END;

IF NOT EXISTS (SELECT 1 FROM SJob.Assets WHERE ID = -1)
BEGIN
    SET IDENTITY_INSERT SJob.Assets ON;
    INSERT INTO SJob.Assets (ID, RowStatus, Guid) VALUES (-1, 1, '00000000-0000-0000-0000-000000000000');
    SET IDENTITY_INSERT SJob.Assets OFF;
END;
IF NOT EXISTS (SELECT 1 FROM SCrm.Accounts WHERE ID = -1)
BEGIN
    SET IDENTITY_INSERT SCrm.Accounts ON;
    INSERT INTO SCrm.Accounts (ID, RowStatus, Guid) VALUES (-1, 1, '00000000-0000-0000-0000-000000000000');
    SET IDENTITY_INSERT SCrm.Accounts OFF;
END;

INSERT INTO SJob.JobTypes (RowStatus, Guid, Name, IsActive, OrganisationalUnitID) VALUES (1, NEWID(), N'CYB-321 job type', 1, @OrgUnitId);
SET @JobTypeId = SCOPE_IDENTITY();
INSERT INTO SJob.RibaStages (RowStatus, Guid, Description) VALUES (1, NEWID(), N'CYB-321 stage');
SET @StageId = SCOPE_IDENTITY();
INSERT INTO SSop.Projects (RowStatus, Guid, ProjectDescription) VALUES (1, NEWID(), N'CYB-321 project');
SET @ProjectId = SCOPE_IDENTITY();

INSERT INTO SJob.Assets (RowStatus, Guid, Name) VALUES (1, NEWID(), N'CYB-321 old asset');
SET @OldAssetId = SCOPE_IDENTITY();
INSERT INTO SJob.Assets (RowStatus, Guid, Name) VALUES (1, NEWID(), N'CYB-321 new asset');
SET @NewAssetId = SCOPE_IDENTITY();
SET @AccountId = (SELECT TOP (1) ID FROM SCrm.Accounts WHERE ID > 0 AND RowStatus NOT IN (0, 254) ORDER BY ID);

INSERT INTO SSop.Enquiries (RowStatus, Guid, DescriptionOfWorks, ProjectId, CurrentProjectRibaStageID, PropertyId, ClientAccountId, AgentAccountId)
VALUES (1, @EnquiryGuid, N'CYB-321 enquiry', @ProjectId, @StageId, @OldAssetId, @AccountId, @AccountId);
SET @EnquiryId = SCOPE_IDENTITY();
EXEC SCore.UpsertDataObject @Guid = @EnquiryGuid, @SchemeName = N'SSop', @ObjectName = N'Enquiries', @IncludeDefaultSecurity = 0, @IsInsert = @IsInsert OUTPUT;
INSERT INTO SSop.EnquiryServices (RowStatus, Guid, EnquiryId, JobTypeId, StartRibaStageId) VALUES (1, @EnquiryServiceGuid, @EnquiryId, @JobTypeId, @StageId);

INSERT INTO SSop.Enquiries (RowStatus, Guid, DescriptionOfWorks, ProjectId, CurrentProjectRibaStageID, PropertyId, ClientAccountId, AgentAccountId)
VALUES (1, @OtherEnquiryGuid, N'CYB-321 other enquiry', @ProjectId, @StageId, @OldAssetId, @AccountId, @AccountId);
SET @OtherEnquiryId = SCOPE_IDENTITY();
EXEC SCore.UpsertDataObject @Guid = @OtherEnquiryGuid, @SchemeName = N'SSop', @ObjectName = N'Enquiries', @IncludeDefaultSecurity = 0, @IsInsert = @IsInsert OUTPUT;
INSERT INTO SSop.EnquiryServices (RowStatus, Guid, EnquiryId, JobTypeId, StartRibaStageId) VALUES (1, @OtherEnquiryServiceGuid, @OtherEnquiryId, @JobTypeId, @StageId);

SELECT (SELECT Guid FROM SCore.OrganisationalUnits WHERE ID = @OrgUnitId),
       (SELECT Guid FROM SJob.JobTypes WHERE ID = @JobTypeId),
       (SELECT Guid FROM SJob.RibaStages WHERE ID = @StageId),
       (SELECT Guid FROM SSop.Projects WHERE ID = @ProjectId),
       @EnquiryServiceGuid,
       @OtherEnquiryServiceGuid,
       (SELECT Guid FROM SJob.Assets WHERE ID = @OldAssetId),
       (SELECT Guid FROM SJob.Assets WHERE ID = @NewAssetId),
       (SELECT Guid FROM SCrm.Accounts WHERE ID = @AccountId),
       @OldAssetId, @NewAssetId, @EnquiryId, @OtherEnquiryId;
""";
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, Array.Empty<SqlParameter>());
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        return new Fixture(
            reader.GetGuid(0),
            reader.GetGuid(1),
            reader.GetGuid(2),
            reader.GetGuid(3),
            reader.GetGuid(4),
            reader.GetGuid(5),
            reader.GetGuid(6),
            reader.GetGuid(7),
            reader.GetGuid(8),
            reader.GetInt32(9),
            reader.GetInt32(10),
            reader.GetInt32(11),
            reader.GetInt32(12));
    }

    private static async Task ExecuteUpsertAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Fixture fixture,
        Guid quoteGuid,
        Guid enquiryServiceGuid,
        Guid propertyGuid)
    {
        static SqlParameter Id(string name, Guid value) => new(name, SqlDbType.UniqueIdentifier) { Value = value };
        static SqlParameter Text(string name, string value) => new(name, SqlDbType.NVarChar, -1) { Value = value };
        static SqlParameter Date(string name, DateTime? value) => new(name, SqlDbType.Date) { Value = (object?)value ?? DBNull.Value };

        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SSop.QuotesUpsert",
            new[]
            {
                Id("@OrganisationalUnitGuid", fixture.OrganisationalUnitGuid),
                Id("@QuotingUserGuid", TestIdentityGuid),
                Id("@ContractGuid", Guid.Empty),
                Date("@Date", DateTime.Today),
                Text("@Overview", "CYB-321 quote"),
                Date("@ExpiryDate", DateTime.Today.AddDays(30)),
                Date("@DateSent", null),
                Date("@DateAccepted", null),
                Date("@DateRejected", null),
                Text("@RejectionReason", ""),
                new SqlParameter("@FeeCap", SqlDbType.Decimal) { Precision = 19, Scale = 2, Value = 0m },
                new SqlParameter("@IsFinal", SqlDbType.Bit) { Value = false },
                new SqlParameter("@ExternalReference", SqlDbType.NVarChar, 50) { Value = "" },
                Id("@QuotingConsultantGuid", TestIdentityGuid),
                Id("@AppointmentFromRibaStageGuid", fixture.StageGuid),
                Id("@CurrentStageGuid", fixture.StageGuid),
                Date("@DeadDate", null),
                Id("@EnquiryServiceGuid", enquiryServiceGuid),
                Id("@ProjectGuid", fixture.ProjectGuid),
                Id("@Guid", quoteGuid),
                Id("@JobType", fixture.JobTypeGuid),
                Text("@DeclinedToQuoteReason", ""),
                Text("@DescriptionOfWorks", "CYB-321 description"),
                Text("@ExclusionsAndLimitations", ""),
                Id("@AgentContractGuid", Guid.Empty),
                new SqlParameter("@IsSubjectToNDA", SqlDbType.Bit) { Value = false },
                Id("@SectorGuid", Guid.Empty),
                Id("@MarketGuid", Guid.Empty),
                Id("@DataClassificationGuid", Guid.Empty),
                Id("@SecurityClassificationGuid", Guid.Empty),
                Id("@JobTypeGuid", fixture.JobTypeGuid),
                Id("@PropertyGuid", propertyGuid),
                Id("@ClientAccountGuid", fixture.AccountGuid),
                Id("@ClientAddressGuid", Guid.Empty),
                Id("@ClientContactGuid", Guid.Empty),
                Id("@AgentAccountGuid", fixture.AccountGuid),
                Id("@AgentAddressGuid", Guid.Empty),
                Id("@AgentContactGuid", Guid.Empty)
            });
        command.CommandType = CommandType.StoredProcedure;
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<int> QuoteAssetIdAsync(SqlConnection connection, SqlTransaction transaction, Guid quoteGuid)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SELECT q.UprnId FROM SSop.Quotes AS q WHERE q.Guid = @QuoteGuid;",
            [new SqlParameter("@QuoteGuid", SqlDbType.UniqueIdentifier) { Value = quoteGuid }]);
        return Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }

    private static async Task<int> EnquiryAssetIdAsync(SqlConnection connection, SqlTransaction transaction, int enquiryId)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SELECT e.PropertyId FROM SSop.Enquiries AS e WHERE e.ID = @EnquiryId;",
            [new SqlParameter("@EnquiryId", SqlDbType.Int) { Value = enquiryId }]);
        return Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }
}
