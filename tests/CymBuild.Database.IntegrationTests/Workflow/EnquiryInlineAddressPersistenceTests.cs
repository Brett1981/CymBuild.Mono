using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;
using static CymBuild.Database.IntegrationTests.Workflow.EnquiryAuthorisationRoutingTests;

namespace CymBuild.Database.IntegrationTests.Workflow;

/// <summary>
/// Proves the Enquiry form's inline "enter new … details" address blocks are persisted by the
/// real SSop.EnquiriesUpsert. The Town fields were never written (no parameter existed), so
/// SSop.EnquiryCreateQuotes created Assets/Accounts with a blank Town; and the Agent/Finance
/// County lookups were swapped between the two blocks, so each County was only kept when the
/// other block was also being entered.
/// </summary>
public sealed class EnquiryInlineAddressPersistenceTests
{
    [Fact]
    public async Task EnquiriesUpsert_InlineDetails_PersistsTownOnInsertAndUpdate()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var shared = await ResolveSharedFixturesAsync(connection, transaction);
            var orgUnitGuid = await ReadOrganisationalUnitGuidAsync(connection, transaction, "R4 Test CDM OrgUnit");
            var projectGuid = await CreateProjectAsync(connection, transaction, "R4 inline town test project");

            var enquiryGuid = await CreateEnquiryAsync(
                connection, transaction, shared, orgUnitGuid, projectGuid, "R4 inline town test enquiry",
                InlineDetails("Bristol", "Leeds", "York", "Bath"));

            Assert.Equal(
                ("Bristol", "Leeds", "York", "Bath"),
                await ReadTownsAsync(connection, transaction, enquiryGuid));

            var overrides = InlineDetails("Exeter", "Hull", "Derby", "Wells");
            overrides["@Guid"] = enquiryGuid;
            await CreateEnquiryAsync(
                connection, transaction, shared, orgUnitGuid, projectGuid, "R4 inline town test enquiry", overrides);

            Assert.Equal(
                ("Exeter", "Hull", "Derby", "Wells"),
                await ReadTownsAsync(connection, transaction, enquiryGuid));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task EnquiriesUpsert_InlineDetailsNotEntered_BlanksTown()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var shared = await ResolveSharedFixturesAsync(connection, transaction);
            var orgUnitGuid = await ReadOrganisationalUnitGuidAsync(connection, transaction, "R4 Test CDM OrgUnit");
            var projectGuid = await CreateProjectAsync(connection, transaction, "R4 inline town blank test project");

            var overrides = InlineDetails("Bristol", "Leeds", "York", "Bath");
            overrides["@EnterNewStructureDetails"] = false;
            overrides["@EnterNewClientDetails"] = false;
            overrides["@EnterNewAgentDetails"] = false;
            overrides["@EnterNewFinanceDetails"] = false;

            var enquiryGuid = await CreateEnquiryAsync(
                connection, transaction, shared, orgUnitGuid, projectGuid, "R4 inline town blank test enquiry", overrides);

            Assert.Equal(("", "", "", ""), await ReadTownsAsync(connection, transaction, enquiryGuid));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public async Task EnquiriesUpsert_AgentAndFinanceCounty_ResolvedIndependently(bool enterAgent, bool enterFinance)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var shared = await ResolveSharedFixturesAsync(connection, transaction);
            var orgUnitGuid = await ReadOrganisationalUnitGuidAsync(connection, transaction, "R4 Test CDM OrgUnit");
            var projectGuid = await CreateProjectAsync(connection, transaction, "R4 inline county test project");
            var (countyId, countyGuid) = await InsertCountyAsync(connection, transaction, "R4 Inline County Test");

            var overrides = new Dictionary<string, object>
            {
                ["@EnterNewAgentDetails"] = enterAgent,
                ["@EnterNewFinanceDetails"] = enterFinance,
                ["@AgentAddressCountyGuid"] = countyGuid,
                ["@FinanceCountyGuid"] = countyGuid
            };

            var enquiryGuid = await CreateEnquiryAsync(
                connection, transaction, shared, orgUnitGuid, projectGuid, "R4 inline county test enquiry", overrides);

            var (agentCountyId, financeCountyId) = await ReadAgentFinanceCountyIdsAsync(connection, transaction, enquiryGuid);
            Assert.Equal(enterAgent ? countyId : -1, agentCountyId);
            Assert.Equal(enterFinance ? countyId : -1, financeCountyId);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    private static Dictionary<string, object> InlineDetails(
        string propertyTown, string clientTown, string agentTown, string financeTown) => new()
    {
        ["@EnterNewStructureDetails"] = true,
        ["@EnterNewClientDetails"] = true,
        ["@EnterNewAgentDetails"] = true,
        ["@EnterNewFinanceDetails"] = true,
        ["@PropertyTown"] = propertyTown,
        ["@ClientAddressTown"] = clientTown,
        ["@AgentTown"] = agentTown,
        ["@FinanceTown"] = financeTown
    };

    private static async Task<(string Property, string Client, string Agent, string Finance)> ReadTownsAsync(
        SqlConnection connection, SqlTransaction transaction, Guid enquiryGuid)
    {
        const string sql = """
SELECT e.PropertyTown, e.ClientAddressTown, e.AgentTown, e.FinanceTown
FROM SSop.Enquiries AS e
WHERE e.Guid = @Guid;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, sql,
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = enquiryGuid } });
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync(), "SSop.EnquiriesUpsert did not create the enquiry row.");

        return (reader.GetString(0), reader.GetString(1), reader.GetString(2), reader.GetString(3));
    }

    private static async Task<(int AgentCountyId, int FinanceCountyId)> ReadAgentFinanceCountyIdsAsync(
        SqlConnection connection, SqlTransaction transaction, Guid enquiryGuid)
    {
        const string sql = """
SELECT e.AgentCountyId, e.FinanceCountyId
FROM SSop.Enquiries AS e
WHERE e.Guid = @Guid;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, sql,
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = enquiryGuid } });
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync(), "SSop.EnquiriesUpsert did not create the enquiry row.");

        return (reader.GetInt32(0), reader.GetInt32(1));
    }

    private static async Task<(int Id, Guid Guid)> InsertCountyAsync(
        SqlConnection connection, SqlTransaction transaction, string name)
    {
        // Lookup-table fixture inside the rolled-back transaction; the R4 database has no
        // EntityType for SCrm.Counties, so no DataObjects row is created for it.
        var countyGuid = Guid.NewGuid();

        const string sql = """
INSERT SCrm.Counties (RowStatus, Guid, Name, CountryID)
VALUES (1, @Guid, @Name, -1);

SELECT CONVERT(INT, SCOPE_IDENTITY());
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, sql,
            new[]
            {
                new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = countyGuid },
                new SqlParameter("@Name", SqlDbType.NVarChar, 100) { Value = name }
            });
        var id = await command.ExecuteScalarAsync();

        return ((int)id!, countyGuid);
    }
}
