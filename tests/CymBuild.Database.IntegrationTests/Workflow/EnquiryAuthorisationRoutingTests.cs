using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Workflow;

/// <summary>
/// R5 slice 2: proves the real, data-driven Enquiry authorisation-routing rule -
/// an Enquiry only surfaces in SCore.tvf_WF_AuthorisationQueue when its organisational
/// unit has its own SCore.Workflow/WorkflowTransition rows reaching an
/// AuthorisationNeeded=1 status (Fire Engineering, per the R4 test fixtures); an
/// organisational unit with no such Workflow row at all (CDM) can never surface,
/// even when forced into the exact same status. Enquiry creation goes through the
/// real SSop.EnquiriesUpsert (and SSop.ProjectsUpsert for its required Project), not a
/// raw fixture insert, so a breaking change to either procedure fails this test.
/// </summary>
public sealed class EnquiryAuthorisationRoutingTests
{
    [Fact]
    public async Task AuthorisationQueue_FireEngineeringEnquiry_Surfaces()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var shared = await ResolveSharedFixturesAsync(connection, transaction);
            var orgUnitGuid = await ReadOrganisationalUnitGuidAsync(connection, transaction, "R4 Test Fire Engineering OrgUnit");
            var projectGuid = await CreateProjectAsync(connection, transaction, "R4 Fire Engineering routing test project");
            var enquiryGuid = await CreateEnquiryAsync(
                connection, transaction, shared, orgUnitGuid, projectGuid, "R4 Fire Engineering routing test enquiry");

            await TransitionToAuthNeededStatusAsync(connection, transaction, shared, enquiryGuid);

            Assert.True(
                await IsInAuthorisationQueueAsync(connection, transaction, enquiryGuid),
                "A Fire Engineering enquiry sitting in the AuthorisationNeeded status must surface in SCore.tvf_WF_AuthorisationQueue.");
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task AuthorisationQueue_CdmEnquiry_NeverSurfaces()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var shared = await ResolveSharedFixturesAsync(connection, transaction);
            var orgUnitGuid = await ReadOrganisationalUnitGuidAsync(connection, transaction, "R4 Test CDM OrgUnit");
            var projectGuid = await CreateProjectAsync(connection, transaction, "R4 CDM routing test project");
            var enquiryGuid = await CreateEnquiryAsync(
                connection, transaction, shared, orgUnitGuid, projectGuid, "R4 CDM routing test enquiry");

            // CDM has no SCore.Workflow row for (OrgUnit, Enquiries EntityType) at all, so even
            // forcing the same AuthorisationNeeded status via the same real transition procedure
            // must never make the enquiry resolvable in the queue.
            await TransitionToAuthNeededStatusAsync(connection, transaction, shared, enquiryGuid);

            Assert.False(
                await IsInAuthorisationQueueAsync(connection, transaction, enquiryGuid),
                "A CDM enquiry has no Workflow row reaching the AuthorisationNeeded status and must never surface in SCore.tvf_WF_AuthorisationQueue.");
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    internal sealed record SharedFixtures(Guid CreatedByUserGuid, Guid AccountGuid, Guid AssetGuid);

    internal static async Task<SharedFixtures> ResolveSharedFixturesAsync(
        SqlConnection connection, SqlTransaction transaction)
    {
        const string sql = """
SELECT
    (SELECT TOP (1) i.Guid FROM SCore.Identities AS i WHERE i.RowStatus NOT IN (0,254) ORDER BY i.ID) AS CreatedByUserGuid,
    (SELECT a.Guid FROM SCrm.Accounts AS a WHERE a.Name = N'CymBuild R4 Finance Test Account') AS AccountGuid,
    (SELECT p.Guid FROM SJob.Assets AS p WHERE p.Name = N'CymBuild R4 Test Asset') AS AssetGuid;
""";

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync(), "The Enquiry shared-fixture lookup query did not return a row.");

        Assert.False(reader.IsDBNull(0), "At least one active SCore.Identities row is required in the dedicated test database.");
        Assert.False(reader.IsDBNull(1), "The R4 Finance test Account fixture is required in the dedicated test database.");
        Assert.False(reader.IsDBNull(2), "The R4 Test Asset fixture is required in the dedicated test database.");

        return new SharedFixtures(reader.GetGuid(0), reader.GetGuid(1), reader.GetGuid(2));
    }

    internal static async Task<Guid> ReadOrganisationalUnitGuidAsync(
        SqlConnection connection, SqlTransaction transaction, string organisationalUnitName)
    {
        const string sql = """
SELECT ou.Guid FROM SCore.OrganisationalUnits AS ou WHERE ou.Name = @Name;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, sql,
            new[] { new SqlParameter("@Name", SqlDbType.NVarChar, 250) { Value = organisationalUnitName } });
        var value = await command.ExecuteScalarAsync();
        Assert.False(value is null or DBNull, $"The '{organisationalUnitName}' R4 fixture OrganisationalUnit is required in the dedicated test database.");

        return (Guid)value!;
    }

    internal static async Task<Guid> CreateProjectAsync(
        SqlConnection connection, SqlTransaction transaction, string projectDescription)
    {
        var projectGuid = Guid.NewGuid();
        var parameters = new[]
        {
            new SqlParameter("@ExternalReference", SqlDbType.NVarChar, 50) { Value = "" },
            new SqlParameter("@ProjectDescription", SqlDbType.NVarChar, -1) { Value = projectDescription },
            new SqlParameter("@ProjectProjectedStartDate", SqlDbType.Date) { Value = DBNull.Value },
            new SqlParameter("@ProjectProjectedEndDate", SqlDbType.Date) { Value = DBNull.Value },
            new SqlParameter("@ProjectCompleted", SqlDbType.Date) { Value = DBNull.Value },
            new SqlParameter("@IsSubjectToNDA", SqlDbType.Bit) { Value = false },
            new SqlParameter("@DataClassificationGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Empty },
            new SqlParameter("@SecurityClassificationGuid", SqlDbType.UniqueIdentifier) { Value = Guid.Empty },
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = projectGuid }
        };

        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, "SSop.ProjectsUpsert", parameters, CommandType.StoredProcedure);
        await command.ExecuteNonQueryAsync();

        return projectGuid;
    }

    /// <summary>
    /// Calls the real SSop.EnquiriesUpsert. <paramref name="overrides"/> replaces the value of a
    /// named parameter, or adds a parameter the baseline list does not pass (e.g. the optional
    /// Town parameters); pass "@Guid" to update an existing enquiry.
    /// </summary>
    internal static async Task<Guid> CreateEnquiryAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        SharedFixtures shared,
        Guid organisationalUnitGuid,
        Guid projectGuid,
        string descriptionOfWorks,
        IReadOnlyDictionary<string, object>? overrides = null)
    {
        var enquiryGuid = overrides is not null && overrides.TryGetValue("@Guid", out var overrideGuid)
            ? (Guid)overrideGuid
            : Guid.NewGuid();
        var zero = Guid.Empty;

        var parameters = new[]
        {
            new SqlParameter("@OrganisationalUnitGuid", SqlDbType.UniqueIdentifier) { Value = organisationalUnitGuid },
            new SqlParameter("@Date", SqlDbType.DateTime2) { Value = DateTime.UtcNow },
            new SqlParameter("@CreatedByUserGuid", SqlDbType.UniqueIdentifier) { Value = shared.CreatedByUserGuid },
            new SqlParameter("@PropertyGuid", SqlDbType.UniqueIdentifier) { Value = shared.AssetGuid },
            new SqlParameter("@PropertyNameNumber", SqlDbType.NVarChar, 100) { Value = "" },
            new SqlParameter("@PropertyAddressLine1", SqlDbType.NVarChar, 255) { Value = "" },
            new SqlParameter("@PropertyAddressLine2", SqlDbType.NVarChar, 255) { Value = "" },
            new SqlParameter("@PropertyAddressLine3", SqlDbType.NVarChar, 255) { Value = "" },
            new SqlParameter("@PropertyCountyGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },
            new SqlParameter("@PropertyPostCode", SqlDbType.NVarChar, 30) { Value = "" },
            new SqlParameter("@PropertyCountryGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },

            new SqlParameter("@ClientAccountGuid", SqlDbType.UniqueIdentifier) { Value = shared.AccountGuid },
            new SqlParameter("@ClientAddressGuid", SqlDbType.UniqueIdentifier) { Value = zero },
            new SqlParameter("@ClientAccountContactGuid", SqlDbType.UniqueIdentifier) { Value = zero },
            new SqlParameter("@ClientName", SqlDbType.NVarChar, 250) { Value = "" },
            new SqlParameter("@ClientAddressNameNumber", SqlDbType.NVarChar, 100) { Value = "" },
            new SqlParameter("@ClientAddressLine1", SqlDbType.NVarChar, 255) { Value = "" },
            new SqlParameter("@ClientAddressLine2", SqlDbType.NVarChar, 255) { Value = "" },
            new SqlParameter("@ClientAddressLine3", SqlDbType.NVarChar, 255) { Value = "" },
            new SqlParameter("@ClientAddressCountyGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },
            new SqlParameter("@ClientAddressPostCode", SqlDbType.NVarChar, 30) { Value = "" },
            new SqlParameter("@ClientAddressCountryGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },
            new SqlParameter("@ClientContactDisplayName", SqlDbType.NVarChar, 250) { Value = "" },
            new SqlParameter("@ClientContactDetailTypeGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },
            new SqlParameter("@ClientContactDetailTypeName", SqlDbType.NVarChar, 100) { Value = "" },
            new SqlParameter("@ClientContactDetailTypeValue", SqlDbType.NVarChar, 250) { Value = "" },

            new SqlParameter("@AgentAccountGuid", SqlDbType.UniqueIdentifier) { Value = shared.AccountGuid },
            new SqlParameter("@AgentAddressGuid", SqlDbType.UniqueIdentifier) { Value = zero },
            new SqlParameter("@AgentAccountContactGuid", SqlDbType.UniqueIdentifier) { Value = zero },
            new SqlParameter("@AgentName", SqlDbType.NVarChar, 250) { Value = "" },
            new SqlParameter("@AgentAddressNameNumber", SqlDbType.NVarChar, 100) { Value = "" },
            new SqlParameter("@AgentAddressLine1", SqlDbType.NVarChar, 255) { Value = "" },
            new SqlParameter("@AgentAddressLine2", SqlDbType.NVarChar, 255) { Value = "" },
            new SqlParameter("@AgentAddressLine3", SqlDbType.NVarChar, 255) { Value = "" },
            new SqlParameter("@AgentAddressCountyGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },
            new SqlParameter("@AgentAddressPostCode", SqlDbType.NVarChar, 30) { Value = "" },
            new SqlParameter("@AgentAddressCountryGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },
            new SqlParameter("@AgentContactDisplayName", SqlDbType.NVarChar, 250) { Value = "" },
            new SqlParameter("@AgentContactDetailTypeGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },
            new SqlParameter("@AgentContactDetailTypeName", SqlDbType.NVarChar, 100) { Value = "" },
            new SqlParameter("@AgentContactDetailTypeValue", SqlDbType.NVarChar, 250) { Value = "" },

            new SqlParameter("@DescriptionOfWorks", SqlDbType.NVarChar, 4000) { Value = descriptionOfWorks },
            new SqlParameter("@ValueOfWork", SqlDbType.Decimal) { Value = 1000m },
            new SqlParameter("@CurrentProjectRobaStageGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },
            new SqlParameter("@RibaStage0Months", SqlDbType.Int) { Value = 0 },
            new SqlParameter("@RibaStage1Months", SqlDbType.Int) { Value = 0 },
            new SqlParameter("@RibaStage2Months", SqlDbType.Int) { Value = 0 },
            new SqlParameter("@RibaStage3Months", SqlDbType.Int) { Value = 0 },
            new SqlParameter("@RibaStage4Months", SqlDbType.Int) { Value = 0 },
            new SqlParameter("@RibaStage5Months", SqlDbType.Int) { Value = 0 },
            new SqlParameter("@RibaStage6Months", SqlDbType.Int) { Value = 0 },
            new SqlParameter("@RibaStage7Months", SqlDbType.Int) { Value = 0 },
            new SqlParameter("@PreConstructionStageMonths", SqlDbType.Int) { Value = 0 },
            new SqlParameter("@ConstructionStageMonths", SqlDbType.Int) { Value = 0 },
            new SqlParameter("@SendInfoToClient", SqlDbType.Bit) { Value = false },
            new SqlParameter("@SendInfoToAgent", SqlDbType.Bit) { Value = false },
            new SqlParameter("@KeyDates", SqlDbType.NVarChar, 2000) { Value = "" },
            new SqlParameter("@ExpectedProcurementRoute", SqlDbType.NVarChar, 200) { Value = "" },
            new SqlParameter("@Notes", SqlDbType.NVarChar, -1) { Value = "" },
            new SqlParameter("@EnquirySourceGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },
            new SqlParameter("@IsReadyForQuoteReview", SqlDbType.Bit) { Value = false },
            new SqlParameter("@QuotingDeadlineDate", SqlDbType.Date) { Value = DBNull.Value },
            new SqlParameter("@DeclinedToQuoteDate", SqlDbType.Date) { Value = DBNull.Value },
            new SqlParameter("@DeclinedToQuoteReason", SqlDbType.NVarChar, 4000) { Value = "" },
            new SqlParameter("@ExternalReference", SqlDbType.NVarChar, 50) { Value = "" },
            new SqlParameter("@ProjectGuid", SqlDbType.UniqueIdentifier) { Value = projectGuid },
            new SqlParameter("@IsSubjectToNDA", SqlDbType.Bit) { Value = false },
            new SqlParameter("@DeadDate", SqlDbType.Date) { Value = DBNull.Value },
            new SqlParameter("@ChaseDate1", SqlDbType.Date) { Value = DBNull.Value },
            new SqlParameter("@ChaseDate2", SqlDbType.Date) { Value = DBNull.Value },

            new SqlParameter("@FinanceAccountGuid", SqlDbType.UniqueIdentifier) { Value = zero },
            new SqlParameter("@FinanceAddressGuid", SqlDbType.UniqueIdentifier) { Value = zero },
            new SqlParameter("@FinanceContactGuid", SqlDbType.UniqueIdentifier) { Value = zero },
            new SqlParameter("@FinanceAccountName", SqlDbType.NVarChar, 250) { Value = "" },
            new SqlParameter("@FinanceAddressNameNumber", SqlDbType.NVarChar, 100) { Value = "" },
            new SqlParameter("@FinanceAddressLine1", SqlDbType.NVarChar, 255) { Value = "" },
            new SqlParameter("@FinanceAddressLine2", SqlDbType.NVarChar, 255) { Value = "" },
            new SqlParameter("@FinanceAddressLine3", SqlDbType.NVarChar, 255) { Value = "" },
            new SqlParameter("@FinanceCountyGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },
            new SqlParameter("@FinancePostCode", SqlDbType.NVarChar, 30) { Value = "" },
            new SqlParameter("@FinanceContactDisplayName", SqlDbType.NVarChar, 250) { Value = "" },
            new SqlParameter("@FinanceContactDetailTypeGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },
            new SqlParameter("@FinanceContactDetailTypeName", SqlDbType.NVarChar, 100) { Value = "" },
            new SqlParameter("@FinanceContactDetailTypeValue", SqlDbType.NVarChar, 250) { Value = "" },

            new SqlParameter("@EnterNewClientDetails", SqlDbType.Bit) { Value = false },
            new SqlParameter("@EnterNewAgentDetails", SqlDbType.Bit) { Value = false },
            new SqlParameter("@EnterNewFinanceDetails", SqlDbType.Bit) { Value = false },
            new SqlParameter("@EnterNewStructureDetails", SqlDbType.Bit) { Value = false },
            new SqlParameter("@IsClientFinanceAccount", SqlDbType.Bit) { Value = false },
            new SqlParameter("@SignatoryIdentityGuid", SqlDbType.UniqueIdentifier) { Value = DBNull.Value },
            new SqlParameter("@ProposalLetter", SqlDbType.NVarChar, -1) { Value = "" },
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = enquiryGuid },

            new SqlParameter("@ContractGuid", SqlDbType.UniqueIdentifier) { Value = zero },
            new SqlParameter("@AgentContractGuid", SqlDbType.UniqueIdentifier) { Value = zero },

            new SqlParameter("@AssetJSONDetails", SqlDbType.NVarChar, 500) { Value = "" }
        }.ToList();

        foreach (var (name, value) in overrides ?? new Dictionary<string, object>())
        {
            var existing = parameters.Find(p => p.ParameterName == name);
            if (existing is not null)
            {
                existing.Value = value;
            }
            else
            {
                parameters.Add(new SqlParameter(name, value));
            }
        }

        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, "SSop.EnquiriesUpsert", parameters.ToArray(), CommandType.StoredProcedure);
        await command.ExecuteNonQueryAsync();

        return enquiryGuid;
    }

    private static async Task TransitionToAuthNeededStatusAsync(
        SqlConnection connection, SqlTransaction transaction, SharedFixtures shared, Guid enquiryGuid)
    {
        const string statusSql = """
SELECT
    (SELECT Guid FROM SCore.WorkflowStatus WHERE Name = N'New' AND Description = N'Automatically generated status') AS NewStatusGuid,
    (SELECT Guid FROM SCore.WorkflowStatus WHERE Name = N'R4 Test Bid Team Review') AS AuthNeededStatusGuid;
""";
        Guid newStatusGuid;
        Guid authNeededStatusGuid;
        await using (var command = SqlTestDatabase.CreateCommand(connection, transaction, statusSql))
        await using (var reader = await command.ExecuteReaderAsync())
        {
            Assert.True(await reader.ReadAsync(), "The Enquiry workflow-status lookup query did not return a row.");
            Assert.False(reader.IsDBNull(0), "The R4 Enquiry 'New' WorkflowStatus fixture is required in the dedicated test database.");
            Assert.False(reader.IsDBNull(1), "The R4 'R4 Test Bid Team Review' WorkflowStatus fixture is required in the dedicated test database.");
            newStatusGuid = reader.GetGuid(0);
            authNeededStatusGuid = reader.GetGuid(1);
        }

        var transitionGuid = Guid.NewGuid();
        await SqlTestData.ExecuteUpsertDataObjectAsync(connection, transaction, transitionGuid, "SCore", "DataObjectTransition");
        await SqlTestData.ExecuteTransitionUpsertAsync(
            connection,
            transaction,
            transitionGuid,
            newStatusGuid,
            authNeededStatusGuid,
            "R4 Enquiry authorisation-routing test transition",
            shared.CreatedByUserGuid,
            enquiryGuid);
    }

    private static async Task<bool> IsInAuthorisationQueueAsync(
        SqlConnection connection, SqlTransaction transaction, Guid dataObjectGuid)
    {
        const string sql = """
SELECT COUNT(1)
FROM SCore.tvf_WF_AuthorisationQueue(NULL, -1) AS queue
WHERE queue.DataObjectGuid = @DataObjectGuid;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, sql,
            new[] { new SqlParameter("@DataObjectGuid", SqlDbType.UniqueIdentifier) { Value = dataObjectGuid } });
        var count = await command.ExecuteScalarAsync();

        return Convert.ToInt32(count, System.Globalization.CultureInfo.InvariantCulture) > 0;
    }
}
