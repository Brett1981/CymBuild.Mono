using System.Data;
using CymBuild.Database.IntegrationTests.Infrastructure;

namespace CymBuild.Database.IntegrationTests.Documents;

public sealed class UserCanUseInactiveMergeDocumentsTests
{
    // CYB-496: an inactive merge document is hidden from the Document Tasks list
    // (SCore.tvf_MergeDocumentsForEntityType) and refused at generation, except for
    // full Super Users (SU) and System Administrators (SYSADM). The scoped
    // superuser groups (Job/Quote/Enquiry) must not see inactive documents.
    // SCore.tvf_UserCanUseInactiveMergeDocuments is the single definition of that
    // rule, shared by the list function and the API guard.

    [Fact]
    public async Task UserWithNoGroups_CannotUseInactiveDocuments()
    {
        Assert.False(await CanUseInactiveAsync(groupCode: null));
    }

    [Theory]
    [InlineData("SU")]
    [InlineData("SYSADM")]
    public async Task SuperUserOrSystemAdministrator_CanUseInactiveDocuments(string groupCode)
    {
        Assert.True(await CanUseInactiveAsync(groupCode));
    }

    [Theory]
    [InlineData("JOBSU")]
    [InlineData("QUOTESU")]
    [InlineData("ENQUIRYSU")]
    public async Task ScopedSuperUser_CannotUseInactiveDocuments(string groupCode)
    {
        Assert.False(await CanUseInactiveAsync(groupCode));
    }

    [Fact]
    public async Task DeletedSuperUserMembership_CannotUseInactiveDocuments()
    {
        Assert.False(await CanUseInactiveAsync("SU", membershipRowStatus: 254));
    }

    private static async Task<bool> CanUseInactiveAsync(string? groupCode, byte membershipRowStatus = 1)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var identityId = await CreateIdentityAsync(connection, transaction);
            if (groupCode is not null)
            {
                await AddToGroupAsync(connection, transaction, identityId, groupCode, membershipRowStatus);
            }

            const string sql = """
SELECT ia.CanUseInactive
FROM SCore.tvf_UserCanUseInactiveMergeDocuments(@UserId) AS ia;
""";
            var parameters = new[] { new SqlParameter("@UserId", SqlDbType.Int) { Value = identityId } };

            await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
            var result = await command.ExecuteScalarAsync();
            Assert.False(result is null or DBNull, "tvf_UserCanUseInactiveMergeDocuments must always return one row.");

            return (bool)result!;
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    // A fresh identity per test, so memberships the shared R4 fixture identity
    // picks up elsewhere cannot leak into these assertions.
    private static async Task<int> CreateIdentityAsync(SqlConnection connection, SqlTransaction transaction)
    {
        var identityGuid = Guid.NewGuid();
        const string sql = """
INSERT INTO SCore.Identities (RowStatus, Guid, FullName, EmailAddress, UserGuid, IsActive)
VALUES (1, @Guid, N'CYB-496 R4 User', @Email, @Guid, 1);

SELECT CONVERT(int, SCOPE_IDENTITY());
""";
        var parameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = identityGuid },
            new SqlParameter("@Email", SqlDbType.NVarChar, 250) { Value = $"cyb496-{identityGuid:N}@r4.test" }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        return Convert.ToInt32(await command.ExecuteScalarAsync(), System.Globalization.CultureInfo.InvariantCulture);
    }

    private static async Task AddToGroupAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        int identityId,
        string groupCode,
        byte membershipRowStatus)
    {
        const string sql = """
DECLARE @GroupId int = (SELECT TOP (1) g.ID FROM SCore.Groups AS g WHERE g.Code = @Code AND g.RowStatus NOT IN (0, 254) ORDER BY g.ID);

IF @GroupId IS NULL
BEGIN
    INSERT INTO SCore.Groups (RowStatus, Guid, DirectoryId, Code, Name)
    VALUES (1, NEWID(), N'CYB-496-R4-' + @Code, @Code, N'CYB-496 R4 ' + @Code);

    SET @GroupId = SCOPE_IDENTITY();
END;

INSERT INTO SCore.UserGroups (RowStatus, Guid, IdentityID, GroupID)
VALUES (@MembershipRowStatus, NEWID(), @IdentityId, @GroupId);
""";
        var parameters = new[]
        {
            new SqlParameter("@IdentityId", SqlDbType.Int) { Value = identityId },
            new SqlParameter("@Code", SqlDbType.NVarChar, 50) { Value = groupCode },
            new SqlParameter("@MembershipRowStatus", SqlDbType.TinyInt) { Value = membershipRowStatus }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await command.ExecuteNonQueryAsync();
    }
}
