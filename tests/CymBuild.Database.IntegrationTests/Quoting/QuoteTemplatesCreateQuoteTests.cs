using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Quoting;

/// <summary>
/// CYB-576: SSop.QuoteTemplatesCreateQuote looped forever on any template with sections and
/// never created items. It now creates a Quote for an Enquiry Service from a Quote Template, in
/// one transaction, through the real SSop.QuotesUpsert and SSop.QuoteItemsUpsert.
/// </summary>
public sealed class QuoteTemplatesCreateQuoteTests
{
    private static readonly Guid TestIdentityGuid = Guid.Parse("D4D00004-0000-4000-8000-000000000001");
    private static readonly Guid QuotesEntityTypeGuid = Guid.Parse("D4D00007-0000-4000-8000-000000000017");
    private static readonly Guid QuoteItemsEntityTypeGuid = Guid.Parse("D4D00576-0000-4000-8000-000000000001");

    [Fact]
    public async Task CreatesTheQuoteAndOneItemPerTemplateItemInOrder()
    {
        await RunInRolledBackTransactionAsync(async (connection, transaction) =>
        {
            var fixture = await InsertFixtureAsync(connection, transaction, invalidSecondItemProduct: false);
            var quoteGuid = Guid.NewGuid();

            await ExecuteCreateAsync(connection, transaction, fixture.TemplateGuid, fixture.EnquiryServiceGuid, quoteGuid);

            const string quoteSql = """
SELECT q.EnquiryServiceID, q.FeeCap, q.Overview, q.JobTypeId, et.Guid
FROM SSop.Quotes AS q
JOIN SCore.DataObjects AS dob ON dob.Guid = q.Guid
JOIN SCore.EntityTypes AS et ON et.ID = dob.EntityTypeId
WHERE q.Guid = @QuoteGuid AND q.RowStatus NOT IN (0, 254);
""";
            await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, quoteSql, QuoteParameter(quoteGuid)))
            await using (var reader = await command.ExecuteReaderAsync())
            {
                Assert.True(await reader.ReadAsync(), "No quote was created.");
                Assert.Equal(fixture.EnquiryServiceId, reader.GetInt32(0));
                Assert.Equal(1500m, reader.GetDecimal(1));
                Assert.Equal("CYB-576 template overview", reader.GetString(2));
                Assert.Equal(fixture.JobTypeId, reader.GetInt32(3));
                Assert.Equal(QuotesEntityTypeGuid, reader.GetGuid(4));
            }

            const string itemsSql = """
SELECT qi.Details, qi.SortOrder, qi.ProvideAtStageID, qi.NumberOfMeetings, qi.NumberOfSiteVisits, qi.Net, et.Guid
FROM SSop.QuoteItems AS qi
JOIN SSop.Quotes AS q ON q.ID = qi.QuoteId
JOIN SCore.DataObjects AS dob ON dob.Guid = qi.Guid
JOIN SCore.EntityTypes AS et ON et.ID = dob.EntityTypeId
WHERE q.Guid = @QuoteGuid AND qi.RowStatus NOT IN (0, 254)
ORDER BY qi.SortOrder;
""";
            var items = new List<(string Details, int SortOrder, int Stage, int Meetings, int Visits, decimal Net, Guid EntityType)>();
            await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, itemsSql, QuoteParameter(quoteGuid)))
            await using (var reader = await command.ExecuteReaderAsync())
            {
                while (await reader.ReadAsync())
                {
                    items.Add((reader.GetString(0), reader.GetInt32(1), reader.GetInt32(2), reader.GetInt32(3), reader.GetInt32(4), reader.GetDecimal(5), reader.GetGuid(6)));
                }
            }

            // Section A (sort 1) items in their own order, then section B (sort 2).
            Assert.Equal(["A1", "A2", "B1"], items.Select(item => item.Details));
            Assert.Equal([1, 2, 3], items.Select(item => item.SortOrder));
            Assert.Equal([fixture.StageAId, fixture.StageAId, fixture.StageBId], items.Select(item => item.Stage));
            // A section's meetings and site visits go on its first item only.
            Assert.Equal([2, 0, 5], items.Select(item => item.Meetings));
            Assert.Equal([3, 0, 7], items.Select(item => item.Visits));
            Assert.Equal([100m, 200m, 300m], items.Select(item => item.Net));
            Assert.All(items, item => Assert.Equal(QuoteItemsEntityTypeGuid, item.EntityType));
        });
    }

    [Fact]
    public async Task CreatesNothingWhenATemplateItemIsInvalid()
    {
        // No surrounding transaction, so the procedure owns its own: the quote is created first,
        // then the second item fails (product not valid for the quote's job type), and the
        // procedure's rollback must remove the quote and the first item. The fixture is
        // committed, so it is removed explicitly afterwards.
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await SqlTestDatabase.DisableAuditTriggersAsync(connection, null);
        var fixture = await InsertFixtureAsync(connection, null, invalidSecondItemProduct: true);

        try
        {
            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteCreateAsync(connection, null, fixture.TemplateGuid, fixture.EnquiryServiceGuid, Guid.NewGuid()));
            Assert.Equal(604172, error.Number);

            await using var command = SqlTestDatabase.CreateCommand(
                connection,
                null,
                """
SELECT (SELECT COUNT(*) FROM SSop.Quotes WHERE EnquiryServiceID = @EnquiryServiceId)
     + (SELECT COUNT(*) FROM SSop.QuoteItems AS qi JOIN SSop.Quotes AS q ON q.ID = qi.QuoteId WHERE q.EnquiryServiceID = @EnquiryServiceId)
     + @@TRANCOUNT;
""",
                [new SqlParameter("@EnquiryServiceId", SqlDbType.Int) { Value = fixture.EnquiryServiceId }]);
            Assert.Equal(0, Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture));
        }
        finally
        {
            await DeleteFixtureAsync(connection, fixture);
        }
    }

    [Fact]
    public async Task RefusesAnEnquiryServiceThatAlreadyHasAQuote()
    {
        await RunInRolledBackTransactionAsync(async (connection, transaction) =>
        {
            var fixture = await InsertFixtureAsync(connection, transaction, invalidSecondItemProduct: false);
            await ExecuteCreateAsync(connection, transaction, fixture.TemplateGuid, fixture.EnquiryServiceGuid, Guid.NewGuid());

            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteCreateAsync(connection, transaction, fixture.TemplateGuid, fixture.EnquiryServiceGuid, Guid.NewGuid()));
            Assert.Equal(60000, error.Number);
            Assert.Contains("already has a quote", error.Message, StringComparison.Ordinal);
        });
    }

    [Fact]
    public async Task RefusesAnUnknownTemplate()
    {
        await RunInRolledBackTransactionAsync(async (connection, transaction) =>
        {
            var fixture = await InsertFixtureAsync(connection, transaction, invalidSecondItemProduct: false);

            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteCreateAsync(connection, transaction, Guid.NewGuid(), fixture.EnquiryServiceGuid, Guid.NewGuid()));
            Assert.Equal(60000, error.Number);
            Assert.Contains("Quote Template could not be found", error.Message, StringComparison.Ordinal);
        });
    }

    private sealed record Fixture(
        Guid TemplateGuid,
        Guid EnquiryServiceGuid,
        int EnquiryServiceId,
        int JobTypeId,
        int StageAId,
        int StageBId,
        int OtherJobTypeId,
        int EnquiryId,
        int TemplateId,
        int ProductId,
        int OtherProductId,
        int? InsertedQuotingStatusId,
        bool InsertedAssetSentinel,
        bool InsertedAccountSentinel);

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
    /// An Enquiry with one Enquiry Service on a job type in the R4 test org unit, two RIBA stages,
    /// a "Quoting" workflow status (QuotesUpsert moves the quote and enquiry to it), and a template
    /// with two sections: A (sort 1, stage A, 2 meetings, 3 visits) holding items A2 then A1 by id
    /// but A1 then A2 by sort order, and B (sort 2, stage B, 5 meetings, 7 visits) holding B1.
    /// </summary>
    private static async Task<Fixture> InsertFixtureAsync(SqlConnection connection, SqlTransaction? transaction, bool invalidSecondItemProduct)
    {
        var templateGuid = Guid.NewGuid();
        var enquiryServiceGuid = Guid.NewGuid();

        const string sql = """
DECLARE @OrgUnitId int = (SELECT TOP (1) ID FROM SCore.OrganisationalUnits WHERE Name = N'CymBuild R4 Test OrgUnit');
DECLARE @JobTypeId int, @OtherJobTypeId int, @StageAId int, @StageBId int, @EnquiryId int, @EnquiryServiceId int,
        @TemplateId int, @SectionAId int, @SectionBId int, @ProductId int, @OtherProductId int, @QuotingStatusId int;

IF NOT EXISTS (SELECT 1 FROM SCore.WorkflowStatus WHERE Name = N'Quoting' AND ShowInQuotes = 1 AND Description = N'Automatically generated status')
BEGIN
    INSERT INTO SCore.WorkflowStatus
        (RowStatus, Guid, OrganisationalUnitId, Name, Description, ShowInEnquiries, ShowInQuotes, ShowInJobs, Enabled,
         IsPredefined, SortOrder, Colour, SendNotification, IsCompleteStatus, IsCustomerWaitingStatus, RequiresUsersAction,
         IsActiveStatus, AuthorisationNeeded, IsAuthStatus)
    VALUES (1, NEWID(), -1, N'Quoting', N'Automatically generated status', 1, 1, 0, 1, 1, 0, N'#FFFFFF', 0, 0, 0, 0, 1, 0, 0);
    SET @QuotingStatusId = SCOPE_IDENTITY();
END;

INSERT INTO SJob.JobTypes (RowStatus, Guid, Name, IsActive, OrganisationalUnitID) VALUES (1, NEWID(), N'CYB-576 job type', 1, @OrgUnitId);
SET @JobTypeId = SCOPE_IDENTITY();
INSERT INTO SJob.JobTypes (RowStatus, Guid, Name, IsActive, OrganisationalUnitID) VALUES (1, NEWID(), N'CYB-576 other job type', 1, @OrgUnitId);
SET @OtherJobTypeId = SCOPE_IDENTITY();

INSERT INTO SJob.RibaStages (RowStatus, Guid, Description) VALUES (1, NEWID(), N'CYB-576 stage A');
SET @StageAId = SCOPE_IDENTITY();
INSERT INTO SJob.RibaStages (RowStatus, Guid, Description) VALUES (1, NEWID(), N'CYB-576 stage B');
SET @StageBId = SCOPE_IDENTITY();

INSERT INTO SProd.Products (RowStatus, Guid, Code, Description, CreatedJobType) VALUES (1, NEWID(), N'CYB576', N'CYB-576 product', -1);
SET @ProductId = SCOPE_IDENTITY();
INSERT INTO SProd.Products (RowStatus, Guid, Code, Description, CreatedJobType) VALUES (1, NEWID(), N'CYB576X', N'CYB-576 other job type product', @OtherJobTypeId);
SET @OtherProductId = SCOPE_IDENTITY();

DECLARE @EnquiryGuid uniqueidentifier = NEWID(), @IsInsert bit, @ProjectId int;
INSERT INTO SSop.Projects (RowStatus, Guid, ProjectDescription) VALUES (1, NEWID(), N'CYB-576 project');
SET @ProjectId = SCOPE_IDENTITY();
-- QuotesUpsert writes a new quote's property, client and agent only on update, so a new quote
-- keeps -1 for them, and its filing name inner-joins those -1 placeholder rows. Every real
-- database has them; the shared test fixtures do not (a -1 account would become the "first
-- active account" other tests pick), so add them here only if missing.
DECLARE @InsertedAssetSentinel bit = 0, @InsertedAccountSentinel bit = 0;
IF NOT EXISTS (SELECT 1 FROM SJob.Assets WHERE ID = -1)
BEGIN
    SET IDENTITY_INSERT SJob.Assets ON;
    INSERT INTO SJob.Assets (ID, RowStatus, Guid) VALUES (-1, 1, '00000000-0000-0000-0000-000000000000');
    SET IDENTITY_INSERT SJob.Assets OFF;
    SET @InsertedAssetSentinel = 1;
END;
IF NOT EXISTS (SELECT 1 FROM SCrm.Accounts WHERE ID = -1)
BEGIN
    SET IDENTITY_INSERT SCrm.Accounts ON;
    INSERT INTO SCrm.Accounts (ID, RowStatus, Guid) VALUES (-1, 1, '00000000-0000-0000-0000-000000000000');
    SET IDENTITY_INSERT SCrm.Accounts OFF;
    SET @InsertedAccountSentinel = 1;
END;

DECLARE @AssetId int = (SELECT TOP (1) ID FROM SJob.Assets WHERE ID > 0 AND RowStatus NOT IN (0, 254) ORDER BY ID);
DECLARE @AccountId int = (SELECT TOP (1) ID FROM SCrm.Accounts WHERE ID > 0 AND RowStatus NOT IN (0, 254) ORDER BY ID);
INSERT INTO SSop.Enquiries (RowStatus, Guid, DescriptionOfWorks, ProjectId, CurrentProjectRibaStageID, PropertyId, ClientAccountId, AgentAccountId)
VALUES (1, @EnquiryGuid, N'CYB-576 enquiry', @ProjectId, @StageAId, @AssetId, @AccountId, @AccountId);
SET @EnquiryId = SCOPE_IDENTITY();
-- QuotesUpsert records the Enquiry's move to "Quoting", so the Enquiry is a registered DataObject.
EXEC SCore.UpsertDataObject @Guid = @EnquiryGuid, @SchemeName = N'SSop', @ObjectName = N'Enquiries', @IncludeDefaultSecurity = 0, @IsInsert = @IsInsert OUTPUT;
INSERT INTO SSop.EnquiryServices (RowStatus, Guid, EnquiryId, JobTypeId, StartRibaStageId) VALUES (1, @EnquiryServiceGuid, @EnquiryId, @JobTypeId, @StageAId);
SET @EnquiryServiceId = SCOPE_IDENTITY();

INSERT INTO SSop.QuoteTemplates (RowStatus, Guid, OrganisationalUnitID, Number, Overview, FeeCap)
VALUES (1, @TemplateGuid, @OrgUnitId, 576, N'CYB-576 template overview', 1500);
SET @TemplateId = SCOPE_IDENTITY();

INSERT INTO SSop.QuoteTemplateSections (RowStatus, Guid, QuoteTemplateId, Name, Overview, SortOrder, RibaStageId, NumberOfMeetings, NumberOfSiteVisits)
VALUES (1, NEWID(), @TemplateId, N'Section B', N'', 2, @StageBId, 5, 7);
SET @SectionBId = SCOPE_IDENTITY();
INSERT INTO SSop.QuoteTemplateSections (RowStatus, Guid, QuoteTemplateId, Name, Overview, SortOrder, RibaStageId, NumberOfMeetings, NumberOfSiteVisits)
VALUES (1, NEWID(), @TemplateId, N'Section A', N'', 1, @StageAId, 2, 3);
SET @SectionAId = SCOPE_IDENTITY();

INSERT INTO SSop.QuoteTemplateItems (RowStatus, Guid, QuoteTemplateSectionId, ProductId, Details, Net, VatRate, SortOrder, Quantity)
VALUES (1, NEWID(), @SectionAId, IIF(@InvalidSecondItemProduct = 1, @OtherProductId, @ProductId), N'A2', 200, 20, 2, 1),
       (1, NEWID(), @SectionAId, @ProductId, N'A1', 100, 20, 1, 1),
       (1, NEWID(), @SectionBId, @ProductId, N'B1', 300, 20, 1, 1);

SELECT @EnquiryServiceId, @JobTypeId, @StageAId, @StageBId, @OtherJobTypeId, @EnquiryId, @TemplateId, @ProductId, @OtherProductId, @QuotingStatusId,
       @InsertedAssetSentinel, @InsertedAccountSentinel;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@TemplateGuid", SqlDbType.UniqueIdentifier) { Value = templateGuid },
                new SqlParameter("@EnquiryServiceGuid", SqlDbType.UniqueIdentifier) { Value = enquiryServiceGuid },
                new SqlParameter("@InvalidSecondItemProduct", SqlDbType.Bit) { Value = invalidSecondItemProduct }
            });
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        return new Fixture(
            templateGuid,
            enquiryServiceGuid,
            reader.GetInt32(0),
            reader.GetInt32(1),
            reader.GetInt32(2),
            reader.GetInt32(3),
            reader.GetInt32(4),
            reader.GetInt32(5),
            reader.GetInt32(6),
            reader.GetInt32(7),
            reader.GetInt32(8),
            reader.IsDBNull(9) ? null : reader.GetInt32(9),
            reader.GetBoolean(10),
            reader.GetBoolean(11));
    }

    // Removes a committed fixture (children first). Quotes, items and their DataObjects were
    // already rolled back by the procedure, which is what the calling test asserts.
    private static async Task DeleteFixtureAsync(SqlConnection connection, Fixture fixture)
    {
        const string sql = """
DELETE qti FROM SSop.QuoteTemplateItems AS qti JOIN SSop.QuoteTemplateSections AS qts ON qts.ID = qti.QuoteTemplateSectionId WHERE qts.QuoteTemplateId = @TemplateId;
DELETE FROM SSop.QuoteTemplateSections WHERE QuoteTemplateId = @TemplateId;
DELETE FROM SSop.QuoteTemplates WHERE ID = @TemplateId;
DELETE FROM SSop.EnquiryServices WHERE ID = @EnquiryServiceId;
DECLARE @ProjectId int = (SELECT ProjectId FROM SSop.Enquiries WHERE ID = @EnquiryId);
DELETE dob FROM SCore.DataObjects AS dob JOIN SSop.Enquiries AS e ON e.Guid = dob.Guid WHERE e.ID = @EnquiryId;
DELETE FROM SSop.Enquiries WHERE ID = @EnquiryId;
DELETE FROM SSop.Projects WHERE ID = @ProjectId;
DELETE FROM SProd.Products WHERE ID IN (@ProductId, @OtherProductId);
DELETE FROM SJob.RibaStages WHERE ID IN (@StageAId, @StageBId);
DELETE FROM SJob.JobTypes WHERE ID IN (@JobTypeId, @OtherJobTypeId);
DELETE FROM SCore.WorkflowStatus WHERE ID = @QuotingStatusId;
IF (@InsertedAssetSentinel = 1) DELETE FROM SJob.Assets WHERE ID = -1;
IF (@InsertedAccountSentinel = 1) DELETE FROM SCrm.Accounts WHERE ID = -1;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            null,
            sql,
            new[]
            {
                new SqlParameter("@TemplateId", SqlDbType.Int) { Value = fixture.TemplateId },
                new SqlParameter("@EnquiryServiceId", SqlDbType.Int) { Value = fixture.EnquiryServiceId },
                new SqlParameter("@EnquiryId", SqlDbType.Int) { Value = fixture.EnquiryId },
                new SqlParameter("@ProductId", SqlDbType.Int) { Value = fixture.ProductId },
                new SqlParameter("@OtherProductId", SqlDbType.Int) { Value = fixture.OtherProductId },
                new SqlParameter("@StageAId", SqlDbType.Int) { Value = fixture.StageAId },
                new SqlParameter("@StageBId", SqlDbType.Int) { Value = fixture.StageBId },
                new SqlParameter("@JobTypeId", SqlDbType.Int) { Value = fixture.JobTypeId },
                new SqlParameter("@OtherJobTypeId", SqlDbType.Int) { Value = fixture.OtherJobTypeId },
                new SqlParameter("@QuotingStatusId", SqlDbType.Int) { Value = (object?)fixture.InsertedQuotingStatusId ?? DBNull.Value },
                new SqlParameter("@InsertedAssetSentinel", SqlDbType.Bit) { Value = fixture.InsertedAssetSentinel },
                new SqlParameter("@InsertedAccountSentinel", SqlDbType.Bit) { Value = fixture.InsertedAccountSentinel }
            });
        await command.ExecuteNonQueryAsync();
    }

    private static async Task ExecuteCreateAsync(SqlConnection connection, SqlTransaction? transaction, Guid templateGuid, Guid enquiryServiceGuid, Guid quoteGuid)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            "SSop.QuoteTemplatesCreateQuote",
            new[]
            {
                new SqlParameter("@TemplateGuid", SqlDbType.UniqueIdentifier) { Value = templateGuid },
                new SqlParameter("@EnquiryServiceGuid", SqlDbType.UniqueIdentifier) { Value = enquiryServiceGuid },
                new SqlParameter("@QuoteGuid", SqlDbType.UniqueIdentifier) { Value = quoteGuid },
                new SqlParameter("@UserGuid", SqlDbType.UniqueIdentifier) { Value = TestIdentityGuid }
            });
        command.CommandType = CommandType.StoredProcedure;
        await command.ExecuteNonQueryAsync();
    }

    private static SqlParameter[] QuoteParameter(Guid quoteGuid) =>
        [new SqlParameter("@QuoteGuid", SqlDbType.UniqueIdentifier) { Value = quoteGuid }];
}
