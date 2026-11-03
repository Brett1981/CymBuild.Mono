using System.Data;
using CymBuild.Database.IntegrationTests.Infrastructure;

namespace CymBuild.Database.IntegrationTests.Quoting;

public sealed class QuoteValidateFieldLockTests
{
    // CYB-462: SSop.tvf_QuotesValidate only locked quote fields while the latest
    // status was Ready to Send, so ExpiryDate was locked at Ready to Send and
    // every field unlocked again once Sent (and stayed open through Chase and
    // Accepted). Expected: ExpiryDate editable at Ready to Send; from Sent onward
    // every field locks except the status-change fields; Quote Superusers
    // (QUOTESU) can still edit; a reopened quote is editable again.
    //
    // Transitions are seeded directly rather than through
    // SCore.DataObjectTransitionUpsert: the function under test only reads
    // transition history, and the upsert's quote-item/enquiry-sync rules are
    // out of scope here.

    private static readonly Guid QuotingStatus = Guid.Parse("9A60F983-24BA-4733-907E-C5CCE0B691CB");
    private static readonly Guid ReadyToSendStatus = Guid.Parse("02A2237F-2AE7-4E05-926F-38E8B7D050A0");
    private static readonly Guid SentStatus = Guid.Parse("25D5491C-42A8-4B04-B3AC-D648AF0F8032");
    private static readonly Guid FirstChaseStatus = Guid.Parse("9FF22CEA-A2A6-4907-9B2D-E62DF8150913");
    private static readonly Guid ReopenedStatus = Guid.Parse("34EF363A-C8F7-4BA8-A2C6-067EBAEF12FD");
    private static readonly Guid ExpiredStatus = Guid.Parse("E6FAC201-F98B-4B3A-AB55-83DC9F802D00");

    private const string ExpiryDate = "Quotes.ExpiryDate";
    private const string DescriptionOfWorks = "Quotes.DescriptionOfWorks";
    private const string ChaseDate1 = "Quotes.ChaseDate1";
    private const string DateAccepted = "Quotes.DateAccepted";
    private const string ExtendedInfoField = "Quote_ExtendedInfo.R4ExtendedInfoField";

    private static readonly DateTime SentDate = new(2026, 1, 16);

    [Fact]
    public async Task Quoting_LeavesExpiryDateAndGeneralFieldsEditable()
    {
        var readOnly = await ReadOnlyFieldsAsync(
            dateSent: null,
            isQuoteSuperUser: false,
            (QuotingStatus, null));

        Assert.DoesNotContain(ExpiryDate, readOnly);
        Assert.DoesNotContain(DescriptionOfWorks, readOnly);
    }

    [Fact]
    public async Task ReadyToSend_KeepsExpiryDateEditableButLocksOtherFields()
    {
        var readOnly = await ReadOnlyFieldsAsync(
            dateSent: null,
            isQuoteSuperUser: false,
            (QuotingStatus, null),
            (ReadyToSendStatus, null));

        Assert.DoesNotContain(ExpiryDate, readOnly);
        Assert.Contains(DescriptionOfWorks, readOnly);
        Assert.Contains(ExtendedInfoField, readOnly);
    }

    [Fact]
    public async Task Sent_LocksAllFieldsExceptStatusChangeFieldsForGeneralUser()
    {
        var readOnly = await ReadOnlyFieldsAsync(
            dateSent: SentDate,
            isQuoteSuperUser: false,
            (QuotingStatus, null),
            (ReadyToSendStatus, null),
            (SentStatus, null));

        Assert.Contains(ExpiryDate, readOnly);
        Assert.Contains(DescriptionOfWorks, readOnly);
        Assert.Contains(ExtendedInfoField, readOnly);
        Assert.DoesNotContain(ChaseDate1, readOnly);
        Assert.DoesNotContain(DateAccepted, readOnly);
    }

    [Fact]
    public async Task ChaseAfterSent_StaysLockedForGeneralUser()
    {
        var readOnly = await ReadOnlyFieldsAsync(
            dateSent: SentDate,
            isQuoteSuperUser: false,
            (QuotingStatus, null),
            (ReadyToSendStatus, null),
            (SentStatus, null),
            (FirstChaseStatus, null));

        Assert.Contains(ExpiryDate, readOnly);
        Assert.Contains(DescriptionOfWorks, readOnly);
        Assert.Contains(ExtendedInfoField, readOnly);
        Assert.DoesNotContain(ChaseDate1, readOnly);
        Assert.DoesNotContain(DateAccepted, readOnly);
    }

    [Fact]
    public async Task Sent_StaysEditableForQuoteSuperUser()
    {
        var readOnly = await ReadOnlyFieldsAsync(
            dateSent: SentDate,
            isQuoteSuperUser: true,
            (QuotingStatus, null),
            (ReadyToSendStatus, null),
            (SentStatus, null),
            (FirstChaseStatus, null));

        Assert.DoesNotContain(ExpiryDate, readOnly);
        Assert.DoesNotContain(DescriptionOfWorks, readOnly);
        Assert.DoesNotContain(ExtendedInfoField, readOnly);
    }

    [Fact]
    public async Task ReopenedAfterSent_IsEditableAgain()
    {
        // SSop.QuoteReopen writes Reopened then Quoting, and does not clear DateSent.
        var readOnly = await ReadOnlyFieldsAsync(
            dateSent: SentDate,
            isQuoteSuperUser: false,
            (QuotingStatus, null),
            (ReadyToSendStatus, null),
            (SentStatus, null),
            (ReopenedStatus, "Quote reopened."),
            (QuotingStatus, "Reopened quote returned to quoting."));

        Assert.DoesNotContain(ExpiryDate, readOnly);
        Assert.DoesNotContain(DescriptionOfWorks, readOnly);
    }

    [Fact]
    public async Task ReadyToSendAfterReopen_IgnoresTheEarlierSendAndKeepsExpiryDateEditable()
    {
        var readOnly = await ReadOnlyFieldsAsync(
            dateSent: SentDate,
            isQuoteSuperUser: false,
            (QuotingStatus, null),
            (ReadyToSendStatus, null),
            (SentStatus, null),
            (ReopenedStatus, "Quote reopened."),
            (QuotingStatus, "Reopened quote returned to quoting."),
            (ReadyToSendStatus, null));

        Assert.DoesNotContain(ExpiryDate, readOnly);
        Assert.Contains(DescriptionOfWorks, readOnly);
    }

    [Fact]
    public async Task LegacySentQuoteWithNoWorkflowHistory_IsLocked()
    {
        var readOnly = await ReadOnlyFieldsAsync(
            dateSent: SentDate,
            isQuoteSuperUser: false);

        Assert.Contains(ExpiryDate, readOnly);
        Assert.Contains(DescriptionOfWorks, readOnly);
        Assert.DoesNotContain(ChaseDate1, readOnly);
    }

    // CYB-461: an expired quote was still editable. It had no lock at all if it
    // expired at Quoting or Ready to Send, and it kept the status-change fields
    // open if it expired after Sent. Expected: fully read-only for general
    // users, still editable for Quote Superusers.

    [Fact]
    public async Task ExpiredFromQuoting_IsFullyReadOnlyForGeneralUser()
    {
        var readOnly = await ReadOnlyFieldsAsync(
            dateSent: null,
            isQuoteSuperUser: false,
            (QuotingStatus, null),
            (ExpiredStatus, "Automatically expired: the quote expiry date has passed."));

        Assert.Contains(ExpiryDate, readOnly);
        Assert.Contains(DescriptionOfWorks, readOnly);
        Assert.Contains(ChaseDate1, readOnly);
        Assert.Contains(DateAccepted, readOnly);
        Assert.Contains(ExtendedInfoField, readOnly);
    }

    [Fact]
    public async Task ExpiredAfterSent_LocksStatusChangeFieldsTooForGeneralUser()
    {
        var readOnly = await ReadOnlyFieldsAsync(
            dateSent: SentDate,
            isQuoteSuperUser: false,
            (QuotingStatus, null),
            (ReadyToSendStatus, null),
            (SentStatus, null),
            (ExpiredStatus, "Automatically expired: the quote expiry date has passed."));

        Assert.Contains(DescriptionOfWorks, readOnly);
        Assert.Contains(ChaseDate1, readOnly);
        Assert.Contains(DateAccepted, readOnly);
        Assert.Contains(ExtendedInfoField, readOnly);
    }

    [Fact]
    public async Task Expired_StaysEditableForQuoteSuperUser()
    {
        var readOnly = await ReadOnlyFieldsAsync(
            dateSent: null,
            isQuoteSuperUser: true,
            (QuotingStatus, null),
            (ExpiredStatus, "Automatically expired: the quote expiry date has passed."));

        Assert.DoesNotContain(ExpiryDate, readOnly);
        Assert.DoesNotContain(DescriptionOfWorks, readOnly);
        Assert.DoesNotContain(ExtendedInfoField, readOnly);
    }

    /// <summary>
    /// Seeds a quote with the given transition history (oldest first), calls
    /// SSop.tvf_QuotesValidate as a general user or a Quote Superuser, and
    /// returns the read-only properties as "Hobt.Name".
    /// </summary>
    private static async Task<HashSet<string>> ReadOnlyFieldsAsync(
        DateTime? dateSent,
        bool isQuoteSuperUser,
        params (Guid Status, string? Comment)[] transitions)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var identityId = await SeedMetadataAndStatusesAsync(connection, transaction);
            var quoteGuid = await InsertQuoteAsync(connection, transaction, dateSent);

            Guid? previousStatus = null;
            foreach (var (status, comment) in transitions)
            {
                await InsertTransitionAsync(connection, transaction, quoteGuid, status, previousStatus, comment, identityId);
                previousStatus = status;
            }

            if (isQuoteSuperUser)
            {
                await AddToQuoteSuperUsersAsync(connection, transaction, identityId);
            }

            return await ReadReadOnlyPropertiesAsync(connection, transaction, quoteGuid, dateSent);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    private static async Task<int> SeedMetadataAndStatusesAsync(SqlConnection connection, SqlTransaction transaction)
    {
        const string sql = """
DECLARE @EntityTypeId int =
(
    SELECT et.ID
    FROM SCore.EntityTypes AS et
    WHERE et.Guid = 'D4D00001-0000-4000-8000-000000000001'
      AND et.RowStatus NOT IN (0, 254)
);

IF NOT EXISTS (SELECT 1 FROM SCore.EntityHobts WHERE SchemaName = N'SSop' AND ObjectName = N'Quotes')
BEGIN
    INSERT INTO SCore.EntityHobts (RowStatus, Guid, SchemaName, ObjectName, EntityTypeID, ObjectType, IsMainHoBT)
    VALUES (1, NEWID(), N'SSop', N'Quotes', @EntityTypeId, 'U', 1);
END;

IF NOT EXISTS (SELECT 1 FROM SCore.EntityHobts WHERE SchemaName = N'SSop' AND ObjectName = N'Quote_ExtendedInfo')
BEGIN
    INSERT INTO SCore.EntityHobts (RowStatus, Guid, SchemaName, ObjectName, EntityTypeID, ObjectType, IsMainHoBT)
    VALUES (1, NEWID(), N'SSop', N'Quote_ExtendedInfo', @EntityTypeId, 'V', 0);
END;

INSERT INTO SCore.EntityProperties (RowStatus, Guid, Name, EntityHoBTID)
SELECT 1, NEWID(), seed.Name, eh.ID
FROM (VALUES
    (N'Quotes', N'ExpiryDate'),
    (N'Quotes', N'DescriptionOfWorks'),
    (N'Quotes', N'ChaseDate1'),
    (N'Quotes', N'DateAccepted'),
    (N'Quote_ExtendedInfo', N'R4ExtendedInfoField')
) AS seed(ObjectName, Name)
JOIN SCore.EntityHobts AS eh
  ON eh.SchemaName = N'SSop'
 AND eh.ObjectName = seed.ObjectName
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.EntityProperties AS ep
    WHERE ep.EntityHoBTID = eh.ID
      AND ep.Name = seed.Name
);

INSERT INTO SCore.WorkflowStatus (RowStatus, Guid, Name, ShowInQuotes)
SELECT 1, seed.Guid, seed.Name, 1
FROM (VALUES
    (CONVERT(uniqueidentifier, '9A60F983-24BA-4733-907E-C5CCE0B691CB'), N'Quoting'),
    (CONVERT(uniqueidentifier, '02A2237F-2AE7-4E05-926F-38E8B7D050A0'), N'Ready to Send'),
    (CONVERT(uniqueidentifier, '25D5491C-42A8-4B04-B3AC-D648AF0F8032'), N'Sent'),
    (CONVERT(uniqueidentifier, '9FF22CEA-A2A6-4907-9B2D-E62DF8150913'), N'1st Chase'),
    (CONVERT(uniqueidentifier, '34EF363A-C8F7-4BA8-A2C6-067EBAEF12FD'), N'Reopened'),
    (CONVERT(uniqueidentifier, 'E6FAC201-F98B-4B3A-AB55-83DC9F802D00'), N'Expired')
) AS seed(Guid, Name)
WHERE NOT EXISTS (SELECT 1 FROM SCore.WorkflowStatus AS ws WHERE ws.Guid = seed.Guid);

SELECT i.ID
FROM SCore.Identities AS i
WHERE i.Guid = 'D4D00004-0000-4000-8000-000000000001'
  AND i.RowStatus NOT IN (0, 254);
""";

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql);
        var identityId = await command.ExecuteScalarAsync();
        Assert.False(identityId is null or DBNull, "The R4 identity fixture is required for quote validation tests.");

        return Convert.ToInt32(identityId, System.Globalization.CultureInfo.InvariantCulture);
    }

    private static async Task<Guid> InsertQuoteAsync(SqlConnection connection, SqlTransaction transaction, DateTime? dateSent)
    {
        var quoteGuid = Guid.NewGuid();
        const string sql = """
INSERT INTO SSop.Quotes (RowStatus, Guid, EnquiryServiceID, Number, RevisionNumber, DateSent)
VALUES (1, @Guid, -1, @Number, 1, @DateSent);
""";
        var parameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = quoteGuid },
            new SqlParameter("@Number", SqlDbType.NVarChar, 50) { Value = $"CYB-462-{quoteGuid:N}" },
            new SqlParameter("@DateSent", SqlDbType.Date) { Value = (object?)dateSent ?? DBNull.Value }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await command.ExecuteNonQueryAsync();

        return quoteGuid;
    }

    private static async Task InsertTransitionAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid quoteGuid,
        Guid statusGuid,
        Guid? oldStatusGuid,
        string? comment,
        int identityId)
    {
        const string sql = """
INSERT INTO SCore.DataObjectTransition
    (RowStatus, Guid, StatusID, OldStatusID, Comment, CreatedByUserId, SurveyorUserId, DataObjectGuid, IsImported)
SELECT
    1,
    NEWID(),
    (SELECT ws.ID FROM SCore.WorkflowStatus AS ws WHERE ws.Guid = @StatusGuid),
    (SELECT ws.ID FROM SCore.WorkflowStatus AS ws WHERE ws.Guid = @OldStatusGuid),
    @Comment,
    @IdentityId,
    NULL,
    @QuoteGuid,
    0;
""";
        var parameters = new[]
        {
            new SqlParameter("@StatusGuid", SqlDbType.UniqueIdentifier) { Value = statusGuid },
            new SqlParameter("@OldStatusGuid", SqlDbType.UniqueIdentifier) { Value = (object?)oldStatusGuid ?? DBNull.Value },
            new SqlParameter("@Comment", SqlDbType.NVarChar, -1) { Value = (object?)comment ?? DBNull.Value },
            new SqlParameter("@IdentityId", SqlDbType.Int) { Value = identityId },
            new SqlParameter("@QuoteGuid", SqlDbType.UniqueIdentifier) { Value = quoteGuid }
        };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task AddToQuoteSuperUsersAsync(SqlConnection connection, SqlTransaction transaction, int identityId)
    {
        const string sql = """
DECLARE @GroupId int = (SELECT g.ID FROM SCore.Groups AS g WHERE g.Code = N'QUOTESU' AND g.RowStatus NOT IN (0, 254));

IF @GroupId IS NULL
BEGIN
    INSERT INTO SCore.Groups (RowStatus, Guid, DirectoryId, Code, Name)
    VALUES (1, NEWID(), N'CYB-462-R4-QUOTESU', N'QUOTESU', N'CYB-462 R4 Quote Superusers');

    SET @GroupId = SCOPE_IDENTITY();
END;

INSERT INTO SCore.UserGroups (RowStatus, Guid, IdentityID, GroupID)
VALUES (1, NEWID(), @IdentityId, @GroupId);

EXEC sys.sp_set_session_context @key = N'user_id', @value = @IdentityId, @read_only = 0;
""";
        var parameters = new[] { new SqlParameter("@IdentityId", SqlDbType.Int) { Value = identityId } };

        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<HashSet<string>> ReadReadOnlyPropertiesAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid quoteGuid,
        DateTime? dateSent)
    {
        const string sql = """
SELECT DISTINCT eh.ObjectName + N'.' + ep.Name
FROM SSop.tvf_QuotesValidate
(
    @Guid,
    @DateSent,
    NULL,
    NULL,
    0,
    1,
    '00000000-0000-0000-0000-000000000000',
    NULL,
    N'',
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000000000'
) AS vr
JOIN SCore.EntityProperties AS ep ON ep.Guid = vr.TargetGuid
JOIN SCore.EntityHobts AS eh ON eh.ID = ep.EntityHoBTID
WHERE vr.TargetType = N'P'
  AND vr.IsReadOnly = 1;
""";
        var parameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = quoteGuid },
            new SqlParameter("@DateSent", SqlDbType.Date) { Value = (object?)dateSent ?? DBNull.Value }
        };

        var readOnly = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        await using var command = SqlTestDatabase.CreateCommand(connection, transaction, sql, parameters);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            readOnly.Add(reader.GetString(0));
        }

        return readOnly;
    }
}
