using Concursus.API.Infrastructure.Sql;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Data;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Concursus.API.Services.Outbox;

public sealed class WorkflowOutboxRepository
{
    private readonly IConfiguration _config;
    private readonly ILogger<WorkflowOutboxRepository> _logger;

    public WorkflowOutboxRepository(IConfiguration config, ILogger<WorkflowOutboxRepository> logger)
    {
        _config = config;
        _logger = logger;
    }

    private string ConnectionString =>
        _config.GetConnectionString("ShoreDB")
        ?? throw new InvalidOperationException("Missing connection string: ShoreDB");

    private string? NotificationsBaseUrl => _config["Notifications:BaseUrl"];

    public async Task<List<OutboxItem>> ClaimBatchAsync(int batchSize, int maxAttempts, CancellationToken ct)
    {
        var claimToken = Guid.NewGuid();

        var sql = @"
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRAN;

;WITH cte AS
(
    SELECT TOP (@BatchSize) o.ID
    FROM SCore.IntegrationOutbox o WITH (READPAST, UPDLOCK, ROWLOCK)
    WHERE o.RowStatus NOT IN (0,254)
      AND o.EventType IN (N'WorkflowStatusNotification', N'JobCreatedFromProposal', N'JobClosureDecision')
      AND o.PublishedOnUtc IS NULL
      AND o.PublishAttempts < @MaxAttempts
      AND
      (
            o.PublishingToken IS NULL
         OR o.PublishingStartedOnUtc < DATEADD(MINUTE, -@LeaseTimeoutMinutes, SYSUTCDATETIME())
      )
    ORDER BY o.CreatedOnUtc ASC, o.ID ASC
)
UPDATE o
SET
    o.PublishAttempts = o.PublishAttempts + 1,
    o.PublishingToken = @ClaimToken,
    o.PublishingStartedOnUtc = SYSUTCDATETIME(),
    o.LastError = NULL
OUTPUT
    inserted.ID,
    inserted.Guid,
    inserted.CreatedOnUtc,
    inserted.EventType,
    inserted.PayloadJson,
    inserted.PublishAttempts,
    inserted.PublishingToken
FROM SCore.IntegrationOutbox o
JOIN cte ON cte.ID = o.ID;

COMMIT TRAN;
";

        var items = new List<OutboxItem>();

        await using var con = new SqlConnection(ConnectionString);
        await con.OpenAsync(ct);
        await SqlSessionContext.ClearNotificationFlagsAsync(con, tx: null, ct);

        await using var cmd = new SqlCommand(sql, con)
        {
            CommandType = CommandType.Text
        };

        cmd.Parameters.Add(new SqlParameter("@BatchSize", SqlDbType.Int) { Value = batchSize });
        cmd.Parameters.Add(new SqlParameter("@MaxAttempts", SqlDbType.Int) { Value = maxAttempts });
        cmd.Parameters.Add(new SqlParameter("@LeaseTimeoutMinutes", SqlDbType.Int) { Value = 10 });
        cmd.Parameters.Add(new SqlParameter("@ClaimToken", SqlDbType.UniqueIdentifier) { Value = claimToken });

        await using var rdr = await cmd.ExecuteReaderAsync(ct);
        while (await rdr.ReadAsync(ct))
        {
            items.Add(new OutboxItem
            {
                OutboxId = rdr.GetInt64(0),
                OutboxGuid = rdr.GetGuid(1),
                CreatedOnUtc = rdr.GetDateTime(2),
                EventType = rdr.GetString(3),
                PayloadJson = rdr.GetString(4),
                PublishAttempts = rdr.GetInt32(5),
                PublishingToken = rdr.GetGuid(6)
            });
        }

        return items;
    }

    public async Task<List<string>> GetRecipientsAsync(long outboxId, CancellationToken ct)
    {
        const string getEventSql = @"
SELECT TOP (1)
    o.EventType,
    o.PayloadJson
FROM SCore.IntegrationOutbox o
WHERE o.ID = @OutboxId
  AND o.RowStatus NOT IN (0,254);
";

        await using var con = new SqlConnection(ConnectionString);
        await con.OpenAsync(ct);
        await SqlSessionContext.ClearNotificationFlagsAsync(con, tx: null, ct);

        string? eventType = null;
        string? payloadJson = null;

        await using (var cmd = new SqlCommand(getEventSql, con))
        {
            cmd.Parameters.Add(new SqlParameter("@OutboxId", SqlDbType.BigInt) { Value = outboxId });

            await using var rdr = await cmd.ExecuteReaderAsync(ct);
            if (await rdr.ReadAsync(ct))
            {
                eventType = rdr.IsDBNull(0) ? null : rdr.GetString(0);
                payloadJson = rdr.IsDBNull(1) ? null : rdr.GetString(1);
            }
        }

        if (string.Equals(eventType, "JobCreatedFromProposal", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(eventType, "JobClosureDecision", StringComparison.OrdinalIgnoreCase))
        {
            return ParseRecipientsFromPayload(payloadJson);
        }

        const string sql = @"
SELECT DISTINCT EmailAddress
FROM SCore.IntegrationOutboxNotificationRecipients
WHERE OutboxId = @OutboxId
  AND EmailAddress IS NOT NULL
  AND LTRIM(RTRIM(EmailAddress)) <> N'';
";

        var recipients = new List<string>();

        await using var recipientsCmd = new SqlCommand(sql, con);
        recipientsCmd.Parameters.Add(new SqlParameter("@OutboxId", SqlDbType.BigInt) { Value = outboxId });

        await using var recipientsRdr = await recipientsCmd.ExecuteReaderAsync(ct);
        while (await recipientsRdr.ReadAsync(ct))
        {
            recipients.Add(recipientsRdr.GetString(0));
        }

        return recipients;
    }

    public async Task<List<string>> GetDistinctGroupSourcesAsync(string? targetGroupIdsCsv, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(targetGroupIdsCsv))
            return new List<string>();

        const string sql = @"
DECLARE @csv NVARCHAR(MAX) = @TargetGroupIdsCsv;

;WITH tokens AS
(
    SELECT LTRIM(RTRIM(value)) AS token
    FROM string_split(@csv, ',')
    WHERE LTRIM(RTRIM(value)) <> N''
),
as_ids AS
(
    SELECT TRY_CONVERT(INT, token) AS GroupId
    FROM tokens
),
as_guids AS
(
    SELECT TRY_CONVERT(UNIQUEIDENTIFIER, token) AS GroupGuid
    FROM tokens
)
SELECT DISTINCT
    LTRIM(RTRIM(g.Source)) AS Source
FROM SCore.Groups g
LEFT JOIN as_ids i
    ON i.GroupId IS NOT NULL
   AND g.ID = i.GroupId
LEFT JOIN as_guids u
    ON u.GroupGuid IS NOT NULL
   AND g.Guid = u.GroupGuid
WHERE g.RowStatus NOT IN (0,254)
  AND (i.GroupId IS NOT NULL OR u.GroupGuid IS NOT NULL)
  AND g.Source IS NOT NULL
  AND LTRIM(RTRIM(g.Source)) <> N'';
";

        var sources = new List<string>();

        await using var con = new SqlConnection(ConnectionString);
        await con.OpenAsync(ct);
        await SqlSessionContext.ClearNotificationFlagsAsync(con, tx: null, ct);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.Add(new SqlParameter("@TargetGroupIdsCsv", SqlDbType.NVarChar) { Value = targetGroupIdsCsv });

        await using var rdr = await cmd.ExecuteReaderAsync(ct);
        while (await rdr.ReadAsync(ct))
        {
            sources.Add(rdr.GetString(0));
        }

        return sources;
    }

    public async Task MarkPublishedAsync(long outboxId, Guid publishingToken, CancellationToken ct)
    {
        const string sql = @"
UPDATE SCore.IntegrationOutbox
SET
    PublishedOnUtc = SYSUTCDATETIME(),
    LastError = NULL,
    PublishingToken = NULL,
    PublishingStartedOnUtc = NULL
WHERE ID = @OutboxId
  AND PublishingToken = @PublishingToken;
";

        await ExecuteNonQueryAsync(
            sql,
            new[]
            {
                new SqlParameter("@OutboxId", SqlDbType.BigInt) { Value = outboxId },
                new SqlParameter("@PublishingToken", SqlDbType.UniqueIdentifier) { Value = publishingToken }
            },
            ct);
    }

    public async Task MarkFailedAsync(long outboxId, Guid publishingToken, string error, CancellationToken ct)
    {
        const string sql = @"
UPDATE SCore.IntegrationOutbox
SET
    LastError = @Err,
    PublishingToken = NULL,
    PublishingStartedOnUtc = NULL
WHERE ID = @OutboxId
  AND PublishingToken = @PublishingToken;
";

        if (error.Length > 2000)
            error = error[..2000];

        await ExecuteNonQueryAsync(
            sql,
            new[]
            {
                new SqlParameter("@OutboxId", SqlDbType.BigInt) { Value = outboxId },
                new SqlParameter("@PublishingToken", SqlDbType.UniqueIdentifier) { Value = publishingToken },
                new SqlParameter("@Err", SqlDbType.NVarChar, 2000) { Value = error }
            },
            ct);
    }

    public async Task MarkFailedAsync(long outboxId, string error, CancellationToken ct)
    {
        const string sql = @"
UPDATE SCore.IntegrationOutbox
SET LastError = @Err
WHERE ID = @OutboxId;
";

        if (error.Length > 2000)
            error = error[..2000];

        await ExecuteNonQueryAsync(
            sql,
            new[]
            {
                new SqlParameter("@OutboxId", SqlDbType.BigInt) { Value = outboxId },
                new SqlParameter("@Err", SqlDbType.NVarChar, 2000) { Value = error }
            },
            ct);
    }

    private async Task ExecuteNonQueryAsync(string sql, SqlParameter p1, CancellationToken ct)
        => await ExecuteNonQueryAsync(sql, new[] { p1 }, ct);

    private async Task ExecuteNonQueryAsync(string sql, SqlParameter p1, SqlParameter p2, CancellationToken ct)
        => await ExecuteNonQueryAsync(sql, new[] { p1, p2 }, ct);

    private async Task ExecuteNonQueryAsync(string sql, IEnumerable<SqlParameter> parameters, CancellationToken ct)
    {
        await using var con = new SqlConnection(ConnectionString);
        await con.OpenAsync(ct);
        await SqlSessionContext.ClearNotificationFlagsAsync(con, tx: null, ct);

        await using var cmd = new SqlCommand(sql, con);
        foreach (var p in parameters)
            cmd.Parameters.Add(p);

        await cmd.ExecuteNonQueryAsync(ct);
    }

    public WorkflowOutboxPayload ParsePayload(string payloadJson)
    {
        var payload = JsonSerializer.Deserialize<WorkflowOutboxPayload>(
            payloadJson,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        return payload ?? throw new InvalidOperationException("Outbox payload could not be deserialized.");
    }

    public JobCreatedFromProposalOutboxPayload ParseJobCreatedFromProposalPayload(string payloadJson)
    {
        var payload = JsonSerializer.Deserialize<JobCreatedFromProposalOutboxPayload>(
            payloadJson,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        return payload ?? throw new InvalidOperationException("JobCreatedFromProposal payload could not be deserialized.");
    }

    public JobClosureDecisionOutboxPayload ParseJobClosureDecisionPayload(string payloadJson)
    {
        var payload = JsonSerializer.Deserialize<JobClosureDecisionOutboxPayload>(
            payloadJson,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        return payload ?? throw new InvalidOperationException("JobClosureDecision payload could not be deserialized.");
    }

    private List<string> ParseRecipientsFromPayload(string? payloadJson)
    {
        if (string.IsNullOrWhiteSpace(payloadJson))
            return new List<string>();

        try
        {
            using var doc = JsonDocument.Parse(payloadJson);

            if (!doc.RootElement.TryGetProperty("recipients", out var recipientsElement))
                return new List<string>();

            if (recipientsElement.ValueKind != JsonValueKind.Array)
                return new List<string>();

            var recipients = new List<string>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var item in recipientsElement.EnumerateArray())
            {
                if (item.ValueKind != JsonValueKind.String)
                    continue;

                var value = item.GetString()?.Trim();
                if (string.IsNullOrWhiteSpace(value))
                    continue;

                if (seen.Add(value))
                    recipients.Add(value);
            }

            return recipients;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to parse recipients from outbox payload JSON.");
            return new List<string>();
        }
    }

    public sealed record NotificationEnrichment(
        string? EntityTypeName,
        string? DetailPageUrl,
        string? RecordUrl,
        string? DisplayRef,
        string? DisplayTitle,
        string? DisplayOrganisationName,
        string? DisplayProjectName,
        string? DisplayClientName,
        string? DisplayAgentName,
        string? DisplayAddress,
        string? Description);

    public async Task<NotificationEnrichment> GetNotificationEnrichmentAsync(
        Guid recordGuid,
        int entityTypeId,
        int? organisationalUnitId,
        CancellationToken ct)
    {
        var et = await GetEntityTypeMetaAsync(entityTypeId, ct);
        var display = await GetRecordDisplayFieldsAsync(recordGuid, entityTypeId, ct);
        var recordUrl = BuildCymBuildRecordUrl(et, entityTypeId, recordGuid);

        var orgName = display.DisplayOrganisationName;
        if (string.IsNullOrWhiteSpace(orgName) && organisationalUnitId.HasValue)
        {
            orgName = await TryResolveOrganisationalUnitNameAsync(organisationalUnitId.Value, ct);
        }

        return new NotificationEnrichment(
            EntityTypeName: et.EntityTypeName,
            DetailPageUrl: et.DetailPageUrl,
            RecordUrl: recordUrl,
            DisplayRef: display.DisplayRef,
            DisplayTitle: display.DisplayTitle,
            DisplayOrganisationName: orgName,
            DisplayProjectName: display.DisplayProjectName,
            DisplayClientName: display.DisplayClientName,
            DisplayAgentName: display.DisplayAgentName,
            DisplayAddress: display.DisplayAddress,
            Description: display.Description);
    }

    private sealed record EntityTypeMeta(string? EntityTypeName, string? DetailPageUrl, Guid? EntityTypeGuid);

    public async Task<List<Guid>> DequeueNotificationQueueAsync(int take, int maxAttempts, CancellationToken ct)
    {
        const string sql = @"
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRAN;

;WITH cte AS
(
    SELECT TOP (@Take) q.ID, q.TransitionGuid
    FROM SCore.WorkflowNotificationQueue q WITH (READPAST, UPDLOCK, ROWLOCK)
    WHERE q.ProcessedOnUtc IS NULL
      AND q.AttemptCount < @MaxAttempts
    ORDER BY q.CreatedOnUtc ASC
)
UPDATE q
SET q.AttemptCount = q.AttemptCount + 1
OUTPUT inserted.TransitionGuid
FROM SCore.WorkflowNotificationQueue q
JOIN cte ON cte.ID = q.ID;

COMMIT TRAN;
";

        var result = new List<Guid>();

        await using var con = new SqlConnection(ConnectionString);
        await con.OpenAsync(ct);
        await SqlSessionContext.ClearNotificationFlagsAsync(con, tx: null, ct);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.Add(new SqlParameter("@Take", SqlDbType.Int) { Value = take });
        cmd.Parameters.Add(new SqlParameter("@MaxAttempts", SqlDbType.Int) { Value = maxAttempts });

        await using var rdr = await cmd.ExecuteReaderAsync(ct);
        while (await rdr.ReadAsync(ct))
        {
            result.Add(rdr.GetGuid(0));
        }

        return result;
    }

    public async Task MarkQueueProcessedAsync(Guid transitionGuid, CancellationToken ct)
    {
        const string sql = @"
UPDATE SCore.WorkflowNotificationQueue
SET ProcessedOnUtc = SYSUTCDATETIME(),
    LastError = NULL
WHERE TransitionGuid = @TransitionGuid;
";
        await ExecuteNonQueryAsync(sql, new SqlParameter("@TransitionGuid", SqlDbType.UniqueIdentifier) { Value = transitionGuid }, ct);
    }

    public async Task MarkQueueFailedAsync(Guid transitionGuid, string error, CancellationToken ct)
    {
        const string sql = @"
UPDATE SCore.WorkflowNotificationQueue
SET LastError = @Err
WHERE TransitionGuid = @TransitionGuid;
";
        if (error.Length > 2000)
            error = error[..2000];

        await ExecuteNonQueryAsync(sql,
            new SqlParameter("@TransitionGuid", SqlDbType.UniqueIdentifier) { Value = transitionGuid },
            new SqlParameter("@Err", SqlDbType.NVarChar, 2000) { Value = error },
            ct);
    }

    public async Task EnqueueOutboxForTransitionAsync(Guid transitionGuid, CancellationToken ct)
    {
        await using var con = new SqlConnection(ConnectionString);
        await con.OpenAsync(ct);
        await SqlSessionContext.ClearNotificationFlagsAsync(con, tx: null, ct);

        await using var cmd = new SqlCommand("[SCore].[IntegrationOutbox_EnqueueWorkflowStatusNotification]", con)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 0
        };

        cmd.Parameters.Add(new SqlParameter("@TransitionGuid", SqlDbType.UniqueIdentifier) { Value = transitionGuid });

        await cmd.ExecuteNonQueryAsync(ct);
    }

    private async Task<EntityTypeMeta> GetEntityTypeMetaAsync(int entityTypeId, CancellationToken ct)
    {
        const string sql = @"
SELECT TOP (1)
    et.Name,
    NULLIF(LTRIM(RTRIM(et.DetailPageUrl)), N'') AS DetailPageUrl,
    et.Guid
FROM SCore.EntityTypes et
WHERE et.RowStatus NOT IN (0,254)
  AND et.ID = @EntityTypeId;
";

        await using var con = new SqlConnection(ConnectionString);
        await con.OpenAsync(ct);
        await SqlSessionContext.ClearNotificationFlagsAsync(con, tx: null, ct);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.Add(new SqlParameter("@EntityTypeId", SqlDbType.Int) { Value = entityTypeId });

        await using var rdr = await cmd.ExecuteReaderAsync(ct);

        if (await rdr.ReadAsync(ct))
        {
            var name = rdr.IsDBNull(0) ? null : rdr.GetString(0);
            var detailUrl = rdr.IsDBNull(1) ? null : rdr.GetString(1);
            var guid = rdr.IsDBNull(2) ? (Guid?)null : rdr.GetGuid(2);
            return new EntityTypeMeta(name, detailUrl, guid);
        }

        return new EntityTypeMeta(null, null, null);
    }

    private sealed record DisplayFields(
        string? DisplayRef,
        string? DisplayTitle,
        string? DisplayOrganisationName,
        string? DisplayProjectName,
        string? DisplayClientName,
        string? DisplayAgentName,
        string? DisplayAddress,
        string? Description);

    private async Task<DisplayFields> GetRecordDisplayFieldsAsync(Guid recordGuid, int entityTypeId, CancellationToken ct)
    {
        const string sql = @"
SELECT TOP (1)
    d.DisplayRef,
    d.DisplayTitle,
    d.DisplayOrganisationName,
    d.DisplayProjectName,
    d.DisplayClientName,
    d.DisplayAgentName,
    d.DisplayAddress,
    d.Description
FROM SCore.tvf_NotificationDisplayInfo(@EntityTypeId, @RecordGuid) d;
";

        await using var con = new SqlConnection(ConnectionString);
        await con.OpenAsync(ct);
        await SqlSessionContext.ClearNotificationFlagsAsync(con, tx: null, ct);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.Add(new SqlParameter("@EntityTypeId", SqlDbType.Int) { Value = entityTypeId });
        cmd.Parameters.Add(new SqlParameter("@RecordGuid", SqlDbType.UniqueIdentifier) { Value = recordGuid });

        await using var rdr = await cmd.ExecuteReaderAsync(ct);

        if (await rdr.ReadAsync(ct))
        {
            var displayTitle = ReadAsString(rdr, 1);
            var description = ReadAsString(rdr, 7);

            return new DisplayFields(
                DisplayRef: ReadAsString(rdr, 0),
                DisplayTitle: displayTitle,
                DisplayOrganisationName: ReadAsString(rdr, 2),
                DisplayProjectName: ReadAsString(rdr, 3),
                DisplayClientName: ReadAsString(rdr, 4),
                DisplayAgentName: ReadAsString(rdr, 5),
                DisplayAddress: ReadAsString(rdr, 6),
                Description: description
            );
        }

        return new DisplayFields(null, null, null, null, null, null, null, null);
    }

    private async Task<string?> TryResolveOrganisationalUnitNameAsync(int organisationalUnitId, CancellationToken ct)
    {
        const string sql = @"
SELECT TOP (1) ou.Name
FROM SCore.OrganisationalUnits ou
WHERE ou.RowStatus NOT IN (0,254)
  AND ou.ID = @OuId;
";
        await using var con = new SqlConnection(ConnectionString);
        await con.OpenAsync(ct);
        await SqlSessionContext.ClearNotificationFlagsAsync(con, tx: null, ct);

        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.Add(new SqlParameter("@OuId", SqlDbType.Int) { Value = organisationalUnitId });

        var result = await cmd.ExecuteScalarAsync(ct);
        return result is string s && !string.IsNullOrWhiteSpace(s) ? s : null;
    }

    private string? BuildCymBuildRecordUrl(EntityTypeMeta et, int entityTypeId, Guid recordGuid)
    {
        if (string.IsNullOrWhiteSpace(NotificationsBaseUrl))
            return null;

        var baseUrl = NotificationsBaseUrl!.Trim();
        if (string.IsNullOrWhiteSpace(baseUrl))
            return null;

        baseUrl = baseUrl.TrimEnd('/');

        if (string.IsNullOrWhiteSpace(et.DetailPageUrl))
            return $"{baseUrl}/record/{recordGuid:D}";

        var detailPageUrl = et.DetailPageUrl.Trim().TrimStart('/').TrimEnd('/');

        if (!et.EntityTypeGuid.HasValue || et.EntityTypeGuid.Value == Guid.Empty)
            return $"{baseUrl}/{detailPageUrl}/{recordGuid:D}";

        var parentRefJson = JsonSerializer.Serialize(new
        {
            DataObjectGuid = recordGuid,
            EntityTypeGuid = et.EntityTypeGuid.Value
        });

        var encodedParentRef = Uri.EscapeDataString(parentRefJson);

        var segment = GetListRouteSegment(entityTypeId);
        var returnUrl = $"{baseUrl}/{segment}/{Guid.Empty:D}";
        var encodedReturnUrl = Uri.EscapeDataString(returnUrl);

        return $"{baseUrl}/{detailPageUrl}/{recordGuid:D}/{encodedParentRef}/{encodedReturnUrl}";
    }

    private static string GetListRouteSegment(int entityTypeId) => entityTypeId switch
    {
        9 => "jobs",
        55 => "quotes",
        83 => "enquiries",
        _ => "records"
    };

    private static string? ReadAsString(SqlDataReader rdr, int ordinal)
    {
        if (rdr.IsDBNull(ordinal))
            return null;

        var v = rdr.GetValue(ordinal);
        if (v is string s)
            return string.IsNullOrWhiteSpace(s) ? null : s;

        var str = Convert.ToString(v, CultureInfo.InvariantCulture);
        return string.IsNullOrWhiteSpace(str) ? null : str;
    }

    public sealed class OutboxItem
    {
        public long OutboxId { get; init; }
        public Guid OutboxGuid { get; init; }
        public DateTime CreatedOnUtc { get; init; }
        public string EventType { get; init; } = "";
        public string PayloadJson { get; init; } = "";
        public int PublishAttempts { get; init; }
        public Guid PublishingToken { get; init; }
    }

    public abstract class OutboxWorkflowStatusPayload
    {
        [JsonPropertyName("eventGuid")]
        public Guid EventGuid { get; set; }

        [JsonPropertyName("eventType")]
        public string EventType { get; set; } = "";

        [JsonPropertyName("occurredOnUtc")]
        public DateTime OccurredOnUtc { get; set; }

        [JsonPropertyName("dataObjectGuid")]
        public Guid DataObjectGuid { get; set; }

        [JsonPropertyName("entityTypeId")]
        public int EntityTypeId { get; set; }

        [JsonPropertyName("organisationalUnitId")]
        public int? OrganisationalUnitId { get; set; }

        [JsonPropertyName("organisationalUnitName")]
        public string? OrganisationalUnitName { get; set; }

        [JsonPropertyName("workflowId")]
        public int WorkflowId { get; set; }

        [JsonPropertyName("workflowName")]
        public string? WorkflowName { get; set; }

        [JsonPropertyName("statusId")]
        public int? StatusId { get; set; }

        [JsonPropertyName("statusGuid")]
        public Guid? StatusGuid { get; set; }

        [JsonPropertyName("statusName")]
        public string? StatusName { get; set; }

        [JsonPropertyName("workflowStatusId")]
        public int? WorkflowStatusId { get; set; }

        [JsonPropertyName("workflowStatusGuid")]
        public Guid? WorkflowStatusGuid { get; set; }

        [JsonPropertyName("workflowStatusName")]
        public string? WorkflowStatusName { get; set; }

        [JsonPropertyName("oldStatusId")]
        public int? OldStatusId { get; set; }

        [JsonPropertyName("oldStatusGuid")]
        public Guid? OldStatusGuid { get; set; }

        [JsonPropertyName("oldStatusName")]
        public string? OldStatusName { get; set; }

        [JsonPropertyName("oldWorkflowStatusId")]
        public int? OldWorkflowStatusId { get; set; }

        [JsonPropertyName("oldWorkflowStatusGuid")]
        public Guid? OldWorkflowStatusGuid { get; set; }

        [JsonPropertyName("oldWorkflowStatusName")]
        public string? OldWorkflowStatusName { get; set; }

        [JsonPropertyName("transitionId")]
        public int? TransitionId { get; set; }

        [JsonPropertyName("transitionGuid")]
        public Guid TransitionGuid { get; set; }

        [JsonPropertyName("comment")]
        public string? Comment { get; set; }

        [JsonPropertyName("actorIdentityId")]
        public int? ActorIdentityId { get; set; }

        [JsonPropertyName("actorName")]
        public string? ActorName { get; set; }

        [JsonPropertyName("actorEmail")]
        public string? ActorEmail { get; set; }

        [JsonPropertyName("surveyorIdentityId")]
        public int? SurveyorIdentityId { get; set; }

        [JsonPropertyName("surveyorName")]
        public string? SurveyorName { get; set; }

        [JsonPropertyName("surveyorEmail")]
        public string? SurveyorEmail { get; set; }

        [JsonPropertyName("targetGroupIdsCsv")]
        public string? TargetGroupIdsCsv { get; set; }

        /* CYB-4: Enquiry notification enrichment */
        [JsonPropertyName("displayAddress")]
        public string? DisplayAddress { get; set; }

        [JsonPropertyName("dueDateUtc")]
        public DateTime? DueDateUtc { get; set; }

        [JsonPropertyName("dueDateDisplay")]
        public string? DueDateDisplay { get; set; }
    }

    public sealed class OutboxTargetGroupPayload
    {
        [JsonPropertyName("groupId")]
        public int GroupId { get; set; }

        [JsonPropertyName("groupCode")]
        public string? GroupCode { get; set; }

        [JsonPropertyName("groupName")]
        public string? GroupName { get; set; }

        [JsonPropertyName("canAction")]
        public bool CanAction { get; set; }
    }

    public sealed class WorkflowOutboxPayload : OutboxWorkflowStatusPayload
    {
        [JsonPropertyName("targetGroups")]
        public List<OutboxTargetGroupPayload> TargetGroups { get; set; } = new();

        public Guid CanonicalStatusGuid => StatusGuid ?? WorkflowStatusGuid ?? Guid.Empty;

        public string CanonicalStatusName => StatusName ?? WorkflowStatusName ?? string.Empty;

        public int? CanonicalStatusId => StatusId ?? WorkflowStatusId;
    }

    public sealed class JobCreatedFromProposalOutboxPayload
    {
        [JsonPropertyName("eventGuid")]
        public Guid EventGuid { get; set; }

        [JsonPropertyName("eventType")]
        public string EventType { get; set; } = "";

        [JsonPropertyName("occurredOnUtc")]
        public DateTime OccurredOnUtc { get; set; }

        [JsonPropertyName("jobGuid")]
        public Guid? JobGuid { get; set; }

        [JsonPropertyName("jobNumber")]
        public string? JobNumber { get; set; }

        [JsonPropertyName("jobCreatedOnUtc")]
        public DateTime? JobCreatedOnUtc { get; set; }

        [JsonPropertyName("quoteGuid")]
        public Guid? QuoteGuid { get; set; }

        [JsonPropertyName("quoteReference")]
        public string? QuoteReference { get; set; }

        [JsonPropertyName("clientName")]
        public string? ClientName { get; set; }

        [JsonPropertyName("projectDescription")]
        public string? ProjectDescription { get; set; }

        [JsonPropertyName("description")]
        public string? Description { get; set; }

        [JsonPropertyName("actor")]
        public OutboxPersonPayload? Actor { get; set; }

        [JsonPropertyName("drafter")]
        public OutboxPersonPayload? Drafter { get; set; }

        [JsonPropertyName("recipients")]
        public List<string> Recipients { get; set; } = new();
    }

    public sealed class JobClosureDecisionOutboxPayload
    {
        [JsonPropertyName("eventGuid")]
        public Guid EventGuid { get; set; }

        [JsonPropertyName("eventType")]
        public string EventType { get; set; } = "";

        [JsonPropertyName("occurredOnUtc")]
        public DateTime OccurredOnUtc { get; set; }

        [JsonPropertyName("dataObjectGuid")]
        public Guid? DataObjectGuid { get; set; }

        [JsonPropertyName("jobGuid")]
        public Guid? JobGuid { get; set; }

        [JsonPropertyName("jobNumber")]
        public string? JobNumber { get; set; }

        [JsonPropertyName("jobTitle")]
        public string? JobTitle { get; set; }

        [JsonPropertyName("description")]
        public string? Description { get; set; }

        [JsonPropertyName("organisationalUnitId")]
        public int? OrganisationalUnitId { get; set; }

        [JsonPropertyName("organisationalUnitName")]
        public string? OrganisationalUnitName { get; set; }

        [JsonPropertyName("workflowId")]
        public int? WorkflowId { get; set; }

        [JsonPropertyName("workflowName")]
        public string? WorkflowName { get; set; }

        [JsonPropertyName("statusId")]
        public int? StatusId { get; set; }

        [JsonPropertyName("statusGuid")]
        public Guid? StatusGuid { get; set; }

        [JsonPropertyName("statusName")]
        public string? StatusName { get; set; }

        [JsonPropertyName("oldStatusId")]
        public int? OldStatusId { get; set; }

        [JsonPropertyName("oldStatusGuid")]
        public Guid? OldStatusGuid { get; set; }

        [JsonPropertyName("oldStatusName")]
        public string? OldStatusName { get; set; }

        [JsonPropertyName("comment")]
        public string? Comment { get; set; }

        [JsonPropertyName("actor")]
        public OutboxPersonPayload? Actor { get; set; }

        [JsonPropertyName("recipients")]
        public List<string> Recipients { get; set; } = new();
    }

    public sealed class OutboxPersonPayload
    {
        [JsonPropertyName("identityId")]
        public int? IdentityId { get; set; }

        [JsonPropertyName("fullName")]
        public string? FullName { get; set; }

        [JsonPropertyName("emailAddress")]
        public string? EmailAddress { get; set; }
    }
}