using Concursus.Common.Shared.Extensions;
using Concursus.Common.Shared.Functions;
using Concursus.EF.Converters;
using Concursus.EF.Types;
using Google.Protobuf;
using Google.Protobuf.WellKnownTypes;
using Microsoft.Data.SqlClient;
using Microsoft.Data.SqlTypes;
using System.Collections.Concurrent;
using System.Data;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.Caching;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace Concursus.EF
{
    public class Core
    {
        #region Protected Fields

        protected readonly ClaimsPrincipal _claimsPrincipal;
        protected readonly string _connectionString;

        #endregion Protected Fields

        #region Private Fields

        private const string ZeroGuidLiteral = "'00000000-0000-0000-0000-000000000000'";
        private static readonly ObjectCache _entityTypeCache = MemoryCache.Default;

        // ------- Merge Document Definition Cache (per EntityTypeGuid + User) -------
        private static readonly ObjectCache _mergeDocCache = MemoryCache.Default;

        // ------- Merge Document Items Cache (per MergeDocumentGuid + User) -------
        private static readonly ObjectCache _mergeDocItemsCache = MemoryCache.Default;

        private int _userId = -1;
        private string _userName;

        #endregion Private Fields

        #region Public Constructors

        public Core(
    string connectionString,
    System.Security.Claims.ClaimsPrincipal user)
        {
            _connectionString = connectionString;
            _claimsPrincipal = user ?? new ClaimsPrincipal(new ClaimsIdentity());

            _userName = ResolveSessionUserEmail(_claimsPrincipal);

            // Preserve the old fallback behaviour only as a final safety net so
            // existing non-HTTP/background paths do not immediately break.
            if (string.IsNullOrWhiteSpace(_userName))
            {
                _userName = "SVC_Concursus@socotec.co.uk";
            }
        }

        #endregion Public Constructors

        #region Public Properties

        public int UserId
        {
            get
            {
                return _userId;
            }
        }

        #endregion Public Properties

        #region Public Methods
        private static string ResolveSessionUserEmail(ClaimsPrincipal? user)
        {
            if (user is null)
            {
                return string.Empty;
            }

            static string GetFirstNonEmptyClaim(ClaimsPrincipal principal, params string[] claimTypes)
            {
                foreach (var claimType in claimTypes)
                {
                    var value = principal.Claims
                        .FirstOrDefault(c => string.Equals(c.Type, claimType, StringComparison.OrdinalIgnoreCase))
                        ?.Value;

                    if (!string.IsNullOrWhiteSpace(value))
                    {
                        return value.Trim();
                    }
                }

                return string.Empty;
            }

            // Prefer true email-style identifiers first.
            var email = GetFirstNonEmptyClaim(
                user,
                ClaimTypes.Email,
                "email",
                "emails",
                "preferred_username",
                ClaimTypes.Upn,
                "upn",
                "unique_name");

            if (!string.IsNullOrWhiteSpace(email))
            {
                return email;
            }

            // Only use Identity.Name if it actually looks like an email address.
            var identityName = user.Identity?.Name?.Trim();
            if (!string.IsNullOrWhiteSpace(identityName) && identityName.Contains("@"))
            {
                return identityName;
            }

            return string.Empty;
        }

        private static string ResolveDisplayNameOrEmail(User? userInfo, int userId)
        {
            if (userInfo is not null)
            {
                if (!string.IsNullOrWhiteSpace(userInfo.FullName))
                {
                    return userInfo.FullName.Trim();
                }

                if (!string.IsNullOrWhiteSpace(userInfo.Email))
                {
                    return userInfo.Email.Trim();
                }
            }

            return userId.ToString();
        }
        // =========================================================================================
        // Result DTO =========================================================================================
        public sealed class AuthorisationDecisionEfResult
        {
            public bool Success { get; set; }
            public string Message { get; set; } = "";
            public Guid? FromStatusGuid { get; set; }
            public Guid? ToStatusGuid { get; set; }
            public string? StoredComment { get; set; }
            public DateTime? DecisionDateTimeUtc { get; set; }
        }

        // =========================================================================================
        // Enquiry Workflow Status GUID constants (single source of truth) =========================================================================================
        private static readonly Guid Enq_BidTeamReview_Guid = Guid.Parse("675CA95D-F03D-4DBC-B83C-3D21BF138635");

        private static readonly Guid Enq_DeclinedToQuote_Guid = Guid.Parse("60B8D960-8F6C-495D-B2E7-F19EBD5506EE");
        private static readonly Guid Enq_ApprovedForQuote_Guid = Guid.Parse("3070A373-0E0A-4261-B942-66CB512EE1B6");
        private static readonly Guid Enq_ReadyForQuote_Guid = Guid.Parse("EB867FA0-9608-4CC7-93BE-CC8E8140E8F0");

        // =========================================================================================
        // Authorisation Decision (EF entry point) =========================================================================================
        /// <summary>
        /// Generic authorisation decision entry point.
        ///
        /// Enquiries:
        /// - Reject: Bid Team Review -&gt; Declined To Quote (comment required)
        /// - Approve: Bid Team Review -&gt; Approved For Quote (default comment if empty) then
        /// Approved For Quote -&gt; Ready for Quote (System Imported)
        ///
        /// Notifications:
        /// - Handled by existing trigger/outbox pipeline: SCore.tr_DataObjectTransition_EnqueueNotifications
        /// -&gt; SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification (only when WorkflowStatus.SendNotification=1)
        ///
        /// IMPORTANT FIX:
        /// - Writes transitions via SCore.DataObjectTransitionUpsert (NOT direct INSERT), ensuring
        /// Record Status grid + audit/history side effects occur.
        /// </summary>
        public async Task<AuthorisationDecisionEfResult> AuthorisationDecisionAsync(
            int userId,
            Guid recordGuid,
            string entityTypeName,
            bool approve,
            string? comment,
            CancellationToken ct = default)
        {
            SqlConnection? connection = null;
            SqlTransaction? tx = null;

            try
            {
                if (recordGuid == Guid.Empty)
                    return new AuthorisationDecisionEfResult { Success = false, Message = "RecordGuid is empty." };

                if (string.IsNullOrWhiteSpace(entityTypeName))
                    return new AuthorisationDecisionEfResult { Success = false, Message = "EntityTypeName is required." };

                if (!approve && string.IsNullOrWhiteSpace(comment))
                    return new AuthorisationDecisionEfResult { Success = false, Message = "Rejection requires a comment." };

                connection = CreateConnection();
                await OpenConnectionAsync(connection);

                tx = connection.BeginTransaction(IsolationLevel.ReadCommitted);

                // 1) Resolve EntityTypeId
                var entityTypeId = await ResolveEntityTypeIdAsync(connection, tx, entityTypeName, ct);
                if (entityTypeId <= 0)
                {
                    await RollbackSafeAsync(tx);
                    return new AuthorisationDecisionEfResult
                    {
                        Success = false,
                        Message = $"Unknown EntityTypeName '{entityTypeName}'."
                    };
                }

                // 2) Validate record exists in auth queue and user can action it
                var queue = await GetQueueRowAsync(connection, tx, userId, entityTypeId, recordGuid, ct);
                if (!queue.Exists)
                {
                    await RollbackSafeAsync(tx);
                    return new AuthorisationDecisionEfResult
                    {
                        Success = false,
                        Message = "This record is no longer awaiting authorisation, or is not visible to this user."
                    };
                }
                if (!queue.CanActionForUser)
                {
                    await RollbackSafeAsync(tx);
                    return new AuthorisationDecisionEfResult
                    {
                        Success = false,
                        Message = "You do not have permission to action this item."
                    };
                }

                var nowUtc = DateTime.UtcNow;

                // Resolve CreatedBy/Surveyor user GUID (proc requires GUIDs)
                var actingUserGuid = await ResolveIdentityGuidByIdAsync(connection, tx, userId, ct);
                if (actingUserGuid == Guid.Empty)
                {
                    await RollbackSafeAsync(tx);
                    return new AuthorisationDecisionEfResult
                    {
                        Success = false,
                        Message = $"Unable to resolve Identity.Guid for userId={userId}."
                    };
                }

                // 3) Enquiry-specific deterministic behavior (GUID driven)
                if (IsEnquiryEntity(entityTypeName, entityTypeId))
                {
                    // Resolve IDs + Names are irrelevant at runtime; Upsert uses GUIDs
                    var bidTeamReviewId = await ResolveWorkflowStatusIdByGuidAsync(connection, tx, Enq_BidTeamReview_Guid, ct);
                    var declinedToQuoteId = await ResolveWorkflowStatusIdByGuidAsync(connection, tx, Enq_DeclinedToQuote_Guid, ct);
                    var approvedForQuoteId = await ResolveWorkflowStatusIdByGuidAsync(connection, tx, Enq_ApprovedForQuote_Guid, ct);
                    var readyForQuoteId = await ResolveWorkflowStatusIdByGuidAsync(connection, tx, Enq_ReadyForQuote_Guid, ct);

                    if (bidTeamReviewId <= 0 || declinedToQuoteId <= 0 || approvedForQuoteId <= 0 || readyForQuoteId <= 0)
                    {
                        await RollbackSafeAsync(tx);
                        return new AuthorisationDecisionEfResult
                        {
                            Success = false,
                            Message = "Enquiry status configuration is invalid: unable to resolve required WorkflowStatus IDs from GUIDs."
                        };
                    }

                    if (!approve)
                    {
                        // REJECT: From current -> Declined To Quote
                        var toStatusId = declinedToQuoteId;

                        // Validate allowed transition exists in workflow
                        var ok = await ExistsTransitionAsync(connection, tx, queue.WorkflowId, queue.LatestStatusId, toStatusId, ct);
                        if (!ok)
                        {
                            await RollbackSafeAsync(tx);
                            return new AuthorisationDecisionEfResult
                            {
                                Success = false,
                                Message = $"No workflow transition found for Enquiry reject from StatusID={queue.LatestStatusId} to Declined To Quote (ID={toStatusId})."
                            };
                        }

                        var storedComment = comment!.Trim();

                        // Write via Upsert (FIX for Record Status grid visibility)
                        await ExecuteDataObjectTransitionUpsertAsync(
                            connection, tx,
                            transitionGuid: Guid.NewGuid(),
                            oldStatusGuid: await ResolveWorkflowStatusGuidByIdAsync(connection, tx, queue.LatestStatusId, ct),
                            newStatusGuid: Enq_DeclinedToQuote_Guid,
                            comment: storedComment,
                            createdByUserGuid: actingUserGuid,
                            surveyorUserGuid: Guid.Empty,
                            dataObjectGuid: recordGuid,
                            isImported: false,
                            ct: ct);

                        var (fromGuid, toGuid) = await ResolveStatusGuidsByIdAsync(connection, tx, queue.LatestStatusId, toStatusId, ct);

                        await tx.CommitAsync(ct);

                        return new AuthorisationDecisionEfResult
                        {
                            Success = true,
                            Message = "Rejected.",
                            FromStatusGuid = fromGuid == Guid.Empty ? null : fromGuid,
                            ToStatusGuid = toGuid == Guid.Empty ? null : toGuid,
                            StoredComment = storedComment,
                            DecisionDateTimeUtc = nowUtc
                        };
                    }
                    else
                    {
                        // APPROVE: Step 1: current -> Approved For Quote Step 2: Approved For Quote
                        // -> Ready for Quote (System Imported)

                        var storedComment = string.IsNullOrWhiteSpace(comment)
                            ? "Bid Review Acceptance - Continue To Quote"
                            : comment!.Trim();

                        // Validate allowed transition exists: current -> approved
                        var ok1 = await ExistsTransitionAsync(connection, tx, queue.WorkflowId, queue.LatestStatusId, approvedForQuoteId, ct);
                        if (!ok1)
                        {
                            await RollbackSafeAsync(tx);
                            return new AuthorisationDecisionEfResult
                            {
                                Success = false,
                                Message = $"No workflow transition found for Enquiry approve from StatusID={queue.LatestStatusId} to Approved For Quote (ID={approvedForQuoteId})."
                            };
                        }

                        await ExecuteDataObjectTransitionUpsertAsync(
                            connection, tx,
                            transitionGuid: Guid.NewGuid(),
                            oldStatusGuid: await ResolveWorkflowStatusGuidByIdAsync(connection, tx, queue.LatestStatusId, ct),
                            newStatusGuid: Enq_ApprovedForQuote_Guid,
                            comment: storedComment,
                            createdByUserGuid: actingUserGuid,
                            surveyorUserGuid: Guid.Empty,
                            dataObjectGuid: recordGuid,
                            isImported: false,
                            ct: ct);

                        // Validate allowed transition exists: approved -> ready
                        var ok2 = await ExistsTransitionAsync(connection, tx, queue.WorkflowId, approvedForQuoteId, readyForQuoteId, ct);
                        if (!ok2)
                        {
                            await RollbackSafeAsync(tx);
                            return new AuthorisationDecisionEfResult
                            {
                                Success = false,
                                Message = $"Enquiry approve inserted Approved For Quote, but workflow has no transition Approved For Quote -> Ready for Quote (ID={readyForQuoteId})."
                            };
                        }

                        // System Imported step: Use CreatedByUserGuid = Guid.Empty to avoid
                        // "Created By = Stephen Brett" if you prefer blank/system. If you want the
                        // user shown, set createdByUserGuid: actingUserGuid.
                        await ExecuteDataObjectTransitionUpsertAsync(
                            connection, tx,
                            transitionGuid: Guid.NewGuid(),
                            oldStatusGuid: Enq_ApprovedForQuote_Guid,
                            newStatusGuid: Enq_ReadyForQuote_Guid,
                            comment: "System Imported",
                            createdByUserGuid: Guid.Empty,
                            surveyorUserGuid: Guid.Empty,
                            dataObjectGuid: recordGuid,
                            isImported: true,
                            ct: ct);

                        var (fromGuid, toGuid) = await ResolveStatusGuidsByIdAsync(connection, tx, queue.LatestStatusId, approvedForQuoteId, ct);

                        await tx.CommitAsync(ct);

                        return new AuthorisationDecisionEfResult
                        {
                            Success = true,
                            Message = "Approved.",
                            FromStatusGuid = fromGuid == Guid.Empty ? null : fromGuid,
                            ToStatusGuid = toGuid == Guid.Empty ? null : toGuid,
                            StoredComment = storedComment,
                            DecisionDateTimeUtc = nowUtc
                        };
                    }
                }

                // ----------------------------------------------------------------- Other entity
                // types (Quotes etc.) - generic chooser -----------------------------------------------------------------
                var nextStatusId = await ChooseNextStatusGenericAsync(connection, tx, queue.WorkflowId, queue.LatestStatusId, approve, ct);
                if (nextStatusId <= 0)
                {
                    await RollbackSafeAsync(tx);
                    return new AuthorisationDecisionEfResult
                    {
                        Success = false,
                        Message = $"No outgoing workflow transitions found from '{queue.LatestWorkflowStatusName}' (StatusID={queue.LatestStatusId})."
                    };
                }
                var genericComment = "";
                var userInfo = await GetUserByGuid(actingUserGuid);

                if (userInfo != null)
                {
                    _userId = userInfo.UserId;

                    // IMPORTANT:
                    // _userName is the session email used by SCore.CreateUserSession.
                    // Never overwrite it with FullName.
                    if (!string.IsNullOrWhiteSpace(userInfo.Email))
                    {
                        _userName = userInfo.Email.Trim();
                    }

                    var displayName = ResolveDisplayNameOrEmail(userInfo, userId);

                    genericComment = approve
                        ? (string.IsNullOrWhiteSpace(comment) ? $"Approved by {displayName}" : comment!.Trim())
                        : comment!.Trim();
                }
                else
                {
                    genericComment = approve
                        ? (string.IsNullOrWhiteSpace(comment) ? $"Approved by {userId}" : comment!.Trim())
                        : comment!.Trim();
                }
                var nextStatusGuid = await ResolveWorkflowStatusGuidByIdAsync(connection, tx, nextStatusId, ct);
                var oldStatusGuidGeneric = await ResolveWorkflowStatusGuidByIdAsync(connection, tx, queue.LatestStatusId, ct);

                await ExecuteDataObjectTransitionUpsertAsync(
                    connection, tx,
                    transitionGuid: Guid.NewGuid(),
                    oldStatusGuid: oldStatusGuidGeneric,
                    newStatusGuid: nextStatusGuid,
                    comment: genericComment,
                    createdByUserGuid: actingUserGuid,
                    surveyorUserGuid: Guid.Empty,
                    dataObjectGuid: recordGuid,
                    isImported: false,
                    ct: ct);

                var (gFrom, gTo) = await ResolveStatusGuidsByIdAsync(connection, tx, queue.LatestStatusId, nextStatusId, ct);

                await tx.CommitAsync(ct);

                return new AuthorisationDecisionEfResult
                {
                    Success = true,
                    Message = approve ? "Approved." : "Rejected.",
                    FromStatusGuid = gFrom == Guid.Empty ? null : gFrom,
                    ToStatusGuid = gTo == Guid.Empty ? null : gTo,
                    StoredComment = genericComment,
                    DecisionDateTimeUtc = nowUtc
                };
            }
            catch
            {
                await RollbackSafeAsync(tx);
                throw;
            }
            finally
            {
                try
                {
                    if (connection != null && connection.State != ConnectionState.Closed)
                        await connection.CloseAsync();
                }
                finally
                {
                    connection?.Dispose();
                }
            }
        }

        // =========================================================================================
        // Writes via SCore.DataObjectTransitionUpsert (the fix) =========================================================================================
        private static async Task RollbackSafeAsync(SqlTransaction? tx)
        {
            if (tx == null) return;
            try { await tx.RollbackAsync(); }
            catch { /* ignore rollback failures */ }
        }

        /// <summary>
        /// Writes a transition through SCore.DataObjectTransitionUpsert. This ensures Record Status
        /// grid + audit/history are consistent.
        /// </summary>
        private static async Task ExecuteDataObjectTransitionUpsertAsync(
            SqlConnection connection,
            SqlTransaction tx,
            Guid transitionGuid,
            Guid oldStatusGuid,
            Guid newStatusGuid,
            string comment,
            Guid createdByUserGuid,
            Guid surveyorUserGuid,
            Guid dataObjectGuid,
            bool isImported,
            CancellationToken ct)
        {
            await using var cmd = new SqlCommand("SCore.DataObjectTransitionUpsert", connection, tx)
            {
                CommandType = CommandType.StoredProcedure
            };

            cmd.Parameters.Add(new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = transitionGuid });
            cmd.Parameters.Add(new SqlParameter("@OldStatusGuid", SqlDbType.UniqueIdentifier) { Value = oldStatusGuid });
            cmd.Parameters.Add(new SqlParameter("@StatusGuid", SqlDbType.UniqueIdentifier) { Value = newStatusGuid });
            cmd.Parameters.Add(new SqlParameter("@Comment", SqlDbType.NVarChar) { Value = comment ?? "" });

            cmd.Parameters.Add(new SqlParameter("@CreatedByUserGuid", SqlDbType.UniqueIdentifier) { Value = createdByUserGuid });
            cmd.Parameters.Add(new SqlParameter("@SurveyorUserGuid", SqlDbType.UniqueIdentifier) { Value = surveyorUserGuid });

            cmd.Parameters.Add(new SqlParameter("@DataObjectGuid", SqlDbType.UniqueIdentifier) { Value = dataObjectGuid });
            cmd.Parameters.Add(new SqlParameter("@IsImported", SqlDbType.Bit) { Value = isImported });

            await cmd.ExecuteNonQueryAsync(ct);
        }

        // =========================================================================================
        // Helpers: Queue row =========================================================================================
        private readonly struct AuthorisationQueueRow
        {
            public bool Exists { get; init; }
            public int WorkflowId { get; init; }
            public int LatestStatusId { get; init; }
            public string LatestWorkflowStatusName { get; init; }
            public bool CanActionForUser { get; init; }
        }

        private static async Task<AuthorisationQueueRow> GetQueueRowAsync(
            SqlConnection connection,
            SqlTransaction tx,
            int userId,
            int entityTypeId,
            Guid recordGuid,
            CancellationToken ct)
        {
            const string sql = @"
SELECT TOP (1)
    q.WorkflowId,
    q.LatestStatusId,
    q.LatestWorkflowStatusName,
    q.CanActionForUser
FROM SCore.tvf_WF_AuthorisationQueue(@UserId, @EntityTypeId) q
WHERE q.DataObjectGuid = @RecordGuid;";

            await using var cmd = new SqlCommand(sql, connection, tx);
            cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });
            cmd.Parameters.Add(new SqlParameter("@EntityTypeId", SqlDbType.Int) { Value = entityTypeId });
            cmd.Parameters.Add(new SqlParameter("@RecordGuid", SqlDbType.UniqueIdentifier) { Value = recordGuid });

            await using var rdr = await cmd.ExecuteReaderAsync(ct);
            if (!await rdr.ReadAsync(ct))
                return new AuthorisationQueueRow { Exists = false, LatestWorkflowStatusName = "" };

            return new AuthorisationQueueRow
            {
                Exists = true,
                WorkflowId = rdr.GetInt32(rdr.GetOrdinal("WorkflowId")),
                LatestStatusId = rdr.GetInt32(rdr.GetOrdinal("LatestStatusId")),
                LatestWorkflowStatusName = rdr.GetString(rdr.GetOrdinal("LatestWorkflowStatusName")),
                CanActionForUser = rdr.GetBoolean(rdr.GetOrdinal("CanActionForUser"))
            };
        }

        // =========================================================================================
        // Helpers: entity type resolution + identification =========================================================================================
        private static async Task<int> ResolveEntityTypeIdAsync(
            SqlConnection connection,
            SqlTransaction tx,
            string entityTypeName,
            CancellationToken ct)
        {
            const string sql = @"
SELECT TOP (1) et.ID
FROM SCore.EntityTypes et
WHERE et.RowStatus NOT IN (0,254)
  AND et.Name = @Name;";

            await using var cmd = new SqlCommand(sql, connection, tx);
            cmd.Parameters.Add(new SqlParameter("@Name", SqlDbType.NVarChar, 200) { Value = entityTypeName });

            var obj = await cmd.ExecuteScalarAsync(ct);
            return obj is null ? -1 : Convert.ToInt32(obj);
        }

        private static bool IsEnquiryEntity(string entityTypeName, int entityTypeId)
        {
            // Safe heuristic:
            // - Prefer name match (canonical)
            // - Still allows ID-based callers if name differs in some env
            return entityTypeName.Trim().Equals("Enquiries", StringComparison.OrdinalIgnoreCase)
                   || entityTypeName.Trim().Equals("Enquiry", StringComparison.OrdinalIgnoreCase);
        }

        // =========================================================================================
        // Helpers: workflow / status resolution =========================================================================================
        private static async Task<int> ResolveWorkflowStatusIdByGuidAsync(
            SqlConnection connection,
            SqlTransaction tx,
            Guid statusGuid,
            CancellationToken ct)
        {
            const string sql = @"
SELECT TOP (1) ws.ID
FROM SCore.WorkflowStatus ws
WHERE ws.RowStatus NOT IN (0,254)
  AND ws.Guid = @Guid;";

            await using var cmd = new SqlCommand(sql, connection, tx);
            cmd.Parameters.Add(new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = statusGuid });

            var obj = await cmd.ExecuteScalarAsync(ct);
            return obj is null ? -1 : Convert.ToInt32(obj);
        }

        private static async Task<Guid> ResolveWorkflowStatusGuidByIdAsync(
            SqlConnection connection,
            SqlTransaction tx,
            int statusId,
            CancellationToken ct)
        {
            const string sql = @"
SELECT TOP (1) ws.Guid
FROM SCore.WorkflowStatus ws
WHERE ws.RowStatus NOT IN (0,254)
  AND ws.ID = @Id;";

            await using var cmd = new SqlCommand(sql, connection, tx);
            cmd.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = statusId });

            var obj = await cmd.ExecuteScalarAsync(ct);
            return obj is null ? Guid.Empty : (Guid)obj;
        }

        private static async Task<(Guid FromGuid, Guid ToGuid)> ResolveStatusGuidsByIdAsync(
            SqlConnection connection,
            SqlTransaction tx,
            int oldStatusId,
            int newStatusId,
            CancellationToken ct)
        {
            const string sql = @"
SELECT
    FromGuid = wsFrom.Guid,
    ToGuid   = wsTo.Guid
FROM SCore.WorkflowStatus wsFrom
CROSS JOIN SCore.WorkflowStatus wsTo
WHERE wsFrom.RowStatus NOT IN (0,254)
  AND wsTo.RowStatus NOT IN (0,254)
  AND wsFrom.ID = @OldStatusId
  AND wsTo.ID = @NewStatusId;";

            await using var cmd = new SqlCommand(sql, connection, tx);
            cmd.Parameters.Add(new SqlParameter("@OldStatusId", SqlDbType.Int) { Value = oldStatusId });
            cmd.Parameters.Add(new SqlParameter("@NewStatusId", SqlDbType.Int) { Value = newStatusId });

            await using var rdr = await cmd.ExecuteReaderAsync(ct);
            if (!await rdr.ReadAsync(ct))
                return (Guid.Empty, Guid.Empty);

            return (rdr.GetGuid(rdr.GetOrdinal("FromGuid")), rdr.GetGuid(rdr.GetOrdinal("ToGuid")));
        }

        private static async Task<bool> ExistsTransitionAsync(
            SqlConnection connection,
            SqlTransaction tx,
            int workflowId,
            int fromStatusId,
            int toStatusId,
            CancellationToken ct)
        {
            const string sql = @"
SELECT TOP (1) 1
FROM SCore.WorkflowTransition wft
WHERE wft.RowStatus NOT IN (0,254)
  AND ISNULL(wft.Enabled,1)=1
  AND wft.WorkflowID = @WorkflowId
  AND wft.FromStatusID = @FromStatusId
  AND wft.ToStatusID = @ToStatusId;";

            await using var cmd = new SqlCommand(sql, connection, tx);
            cmd.Parameters.Add(new SqlParameter("@WorkflowId", SqlDbType.Int) { Value = workflowId });
            cmd.Parameters.Add(new SqlParameter("@FromStatusId", SqlDbType.Int) { Value = fromStatusId });
            cmd.Parameters.Add(new SqlParameter("@ToStatusId", SqlDbType.Int) { Value = toStatusId });

            var obj = await cmd.ExecuteScalarAsync(ct);
            return obj is not null;
        }

        private static async Task<int> ChooseNextStatusGenericAsync(
            SqlConnection connection,
            SqlTransaction tx,
            int workflowId,
            int fromStatusId,
            bool approve,
            CancellationToken ct)
        {
            // Generic heuristic:
            // - Approve: choose the first enabled transition that DOES NOT look reject-like, prefer
            //   active/complete if present
            // - Reject: choose the first enabled transition that looks reject-like (by name) else
            //   fallback to first

            const string sql = @"
SELECT
    wft.ToStatusID,
    ws.Name AS ToStatusName,
    ISNULL(ws.IsActiveStatus,1) AS IsActiveStatus,
    ISNULL(ws.IsCompleteStatus,0) AS IsCompleteStatus
FROM SCore.WorkflowTransition wft
JOIN SCore.WorkflowStatus ws
    ON ws.ID = wft.ToStatusID
   AND ws.RowStatus NOT IN (0,254)
WHERE wft.RowStatus NOT IN (0,254)
  AND ISNULL(wft.Enabled,1)=1
  AND wft.WorkflowID = @WorkflowId
  AND wft.FromStatusID = @FromStatusId;";

            var candidates = new List<(int ToId, string Name, bool IsActive, bool IsComplete)>();

            await using (var cmd = new SqlCommand(sql, connection, tx))
            {
                cmd.Parameters.Add(new SqlParameter("@WorkflowId", SqlDbType.Int) { Value = workflowId });
                cmd.Parameters.Add(new SqlParameter("@FromStatusId", SqlDbType.Int) { Value = fromStatusId });

                await using var rdr = await cmd.ExecuteReaderAsync(ct);
                while (await rdr.ReadAsync(ct))
                {
                    candidates.Add((
                        rdr.GetInt32(rdr.GetOrdinal("ToStatusID")),
                        rdr.GetString(rdr.GetOrdinal("ToStatusName")),
                        rdr.GetBoolean(rdr.GetOrdinal("IsActiveStatus")),
                        rdr.GetBoolean(rdr.GetOrdinal("IsCompleteStatus"))
                    ));
                }
            }

            if (candidates.Count == 0) return -1;

            static bool IsRejectLike(string name)
            {
                if (string.IsNullOrWhiteSpace(name)) return false;
                var n = name.ToLowerInvariant();
                return n.Contains("reject") || n.Contains("declin") || n.Contains("cancel") || n.Contains("dead") || n.Contains("inactive");
            }

            if (approve)
            {
                var pick = candidates
                    .Where(c => c.IsActive && !IsRejectLike(c.Name))
                    .OrderByDescending(c => c.IsComplete)
                    .ThenBy(c => c.Name)
                    .FirstOrDefault();

                if (pick.ToId > 0) return pick.ToId;

                // fallback
                return candidates.OrderByDescending(c => c.IsActive).ThenByDescending(c => c.IsComplete).First().ToId;
            }
            else
            {
                var pick = candidates
                    .OrderByDescending(c => IsRejectLike(c.Name) || !c.IsActive)
                    .ThenBy(c => c.Name)
                    .FirstOrDefault();

                return pick.ToId > 0 ? pick.ToId : candidates.First().ToId;
            }
        }

        // =========================================================================================
        // Helpers: Identity GUID resolution (proc requires GUIDs) =========================================================================================
        private static async Task<Guid> ResolveIdentityGuidByIdAsync(
            SqlConnection connection,
            SqlTransaction tx,
            int identityId,
            CancellationToken ct)
        {
            const string sql = @"
SELECT TOP (1) i.Guid
FROM SCore.Identities i
WHERE i.RowStatus NOT IN (0,254)
  AND i.ID = @Id;";

            await using var cmd = new SqlCommand(sql, connection, tx);
            cmd.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = identityId });

            var obj = await cmd.ExecuteScalarAsync(ct);
            return obj is null ? Guid.Empty : (Guid)obj;
        }

        // Below is for a replacment of the above ReplacePredicateTokens method to parameterize the
        // SQL query
        public static (string Sql, List<SqlParameter> Params) BindStandardTokens(
            string sql,
            int currentUserId,
            int? userId = null,
            Guid? parentGuid = null,
            Guid? recordGuid = null,
            Guid? currentSelectedValueGuid = null)
        {
            var ps = new List<SqlParameter>();

            // map of known tokens -> parameter name + value
            var map = new List<(string token, string pname, object? value)>
                    {
                        ("[[CURRENT_USER_ID]]", "@CURRENT_USER_ID", currentUserId),
                        ("[[UserId]]",            "@UserId",          userId ?? currentUserId),
                        ("[[ParentGuid]]",        "@ParentGuid",      parentGuid),
                        ("[[RecordGuid]]",        "@RecordGuid",      recordGuid),
                        ("[[CurrentSelectedValueGuid]]", "@CurrentSelectedValueGuid", currentSelectedValueGuid)
                    };

            foreach (var (token, pname, value) in map)
            {
                if (sql.Contains(token, StringComparison.OrdinalIgnoreCase) && value is not null)
                {
                    sql = sql.Replace(token, pname, StringComparison.OrdinalIgnoreCase);
                    ps.Add(new SqlParameter(pname, value));
                }
            }
            sql = UnquoteKnownParams(sql);
            return (sql, ps);
        }

        public static string CreatePropertyStatement(string columnName, string operatorToken, Guid filterGuid)
        {
            if (!columnName.Contains('['))
            {
                columnName = "[" + columnName + "]";
            }

            string filterGuidString = filterGuid.ToString("N");
            string stmt = $" ({columnName} ";

            switch (operatorToken.ToLower())
            {
                case "eq":
                case "isequalto":
                    stmt += $"= @{filterGuidString}";
                    break;

                case "ne":
                case "isnotequalto":
                    stmt += $"<> @{filterGuidString}";
                    break;

                case "startswith":
                    stmt += $"LIKE @{filterGuidString} + N'%'";
                    break;

                case "contains":
                    stmt += $"LIKE N'%' + @{filterGuidString} + N'%'";
                    break;

                case "endswith":
                    stmt += $"LIKE N'%' + @{filterGuidString}";
                    break;

                case "islessthan":
                case "lt":
                    stmt += $"< @{filterGuidString}";
                    break;

                case "isgreaterthan":
                case "gt":
                    stmt += $"> @{filterGuidString}";
                    break;

                case "islessthanorequalto":
                case "le":
                    stmt += $"<= @{filterGuidString}";
                    break;

                case "ge":
                    stmt += $">= @{filterGuidString}";
                    break;

                case "doesnotcontain":
                    stmt += $"NOT LIKE N'%' + @{filterGuidString} + N'%'";
                    break;

                case "isnull":
                    stmt += "IS NULL";
                    break;

                case "isnotnull":
                    stmt += "IS NOT NULL";
                    break;

                case "isempty":
                    if (LooksLikeGuidColumn(columnName))
                        // treat both NULL and zero-GUID as empty
                        stmt += $"IS NULL OR {columnName} = {ZeroGuidLiteral}";
                    else
                        stmt += "= N''";
                    break;

                case "isnotempty":
                    if (LooksLikeGuidColumn(columnName))
                        // non-empty = not NULL and not zero-GUID
                        stmt += $"IS NOT NULL AND {columnName} <> {ZeroGuidLiteral}";
                    else
                        stmt += "<> N''";
                    break;

                case "isnullorempty":
                    if (LooksLikeGuidColumn(columnName))
                        // same semantics as isempty for GUIDs
                        stmt += $"IS NULL OR {columnName} = {ZeroGuidLiteral}";
                    else
                        stmt += $"IS NULL OR {columnName} = N''";
                    break;

                case "isnotnullorempty":
                    if (LooksLikeGuidColumn(columnName))
                        // not (null or zero-GUID)
                        stmt += $"IS NOT NULL AND {columnName} <> {ZeroGuidLiteral}";
                    else
                        // not (null or empty string)
                        stmt += $"IS NOT NULL AND {columnName} <> N''";
                    break;

                default:
                    throw new ArgumentException($"Operator token {operatorToken} is not valid.");
            }

            return stmt + ") ";
        }

        public static string DataObjectCompositeFilterListToPredicate(string sqlQuery, List<DataObjectCompositeFilter> dataObjectCompositeFilters, bool includeSystem = false)
        {
            int predicateIndex = sqlQuery.IndexOf("WHERE", StringComparison.OrdinalIgnoreCase);
            string predicate = predicateIndex > -1 ? sqlQuery[predicateIndex..] : string.Empty;

            if (dataObjectCompositeFilters.Count > 0)
            {
                string predicate2 = Core.DataObjectCompositeToSqlPredicate(dataObjectCompositeFilters[0], string.Empty);

                if (!string.IsNullOrEmpty(predicate) && !string.IsNullOrEmpty(predicate2))
                {
                    predicate += " AND " + predicate2;
                }
                else
                {
                    predicate += predicate2;
                }

                if (!string.IsNullOrEmpty(predicate) && predicateIndex < 0)
                {
                    predicate = " WHERE " + predicate;
                }
            }

            // RowStatus Filter
            if (string.IsNullOrEmpty(predicate))
            {
                predicate = " WHERE ";
            }
            else
            {
                predicate += " AND ";
            }

            predicate += includeSystem
                ? "([root_hobt].[RowStatus] <> " + (int)Enums.RowStatus.Deleted + ")"
                : "(([root_hobt].[RowStatus] <> " + (int)Enums.RowStatus.New + ") AND ([root_hobt].[RowStatus] <> " + (int)Enums.RowStatus.Deleted + "))";

            return predicate;
        }

        public static IEnumerable<SqlParameter> DataObjectCompositeFilterListToSqlParameterList(List<DataObjectCompositeFilter> predicates)
        {
            return predicates.Count > 0 ? DataObjectCompositeFilterToSqlParameterList(predicates[0]) : Enumerable.Empty<SqlParameter>();
        }

        public static IEnumerable<SqlParameter> DataObjectCompositeFilterToSqlParameterList(DataObjectCompositeFilter predicate)
        {
            var list = new List<SqlParameter>();

            // Recurse first
            foreach (var gdcf in predicate.CompositeFilters)
                list.AddRange(DataObjectCompositeFilterToSqlParameterList(gdcf));

            foreach (var gdf in predicate.Filters)
            {
                string name = gdf.Guid.ToString("N");

                switch (gdf.Value.KindCase)
                {
                    case Value.KindOneofCase.StringValue:
                        {
                            var s = gdf.Value.StringValue;

                            // If it's a GUID string -> bind as uniqueidentifier
                            if (Guid.TryParse(s, out var g))
                            {
                                list.Add(new SqlParameter(name, System.Data.SqlDbType.UniqueIdentifier) { Value = g });
                            }
                            // If it's empty/whitespace AND the column looks like a GUID column ->
                            // send NULL of type uniqueidentifier
                            else if (LooksLikeGuidColumn(gdf.ColumnName) && string.IsNullOrWhiteSpace(s))
                            {
                                list.Add(new SqlParameter(name, System.Data.SqlDbType.UniqueIdentifier) { Value = DBNull.Value });
                            }
                            else
                            {
                                // normal string
                                list.Add(new SqlParameter(name, (object?)s ?? DBNull.Value));
                            }
                            break;
                        }

                    case Value.KindOneofCase.BoolValue:
                        list.Add(new SqlParameter(name, gdf.Value.BoolValue));
                        break;

                    case Value.KindOneofCase.NumberValue:
                        list.Add(new SqlParameter(name, gdf.Value.NumberValue));
                        break;

                    default:
                        // ignore unsupported kinds or extend as needed
                        break;
                }
            }

            return list;
        }

        public static async Task<EntityType> GetEntityType(
    Guid guid,
    SqlConnection connection,
    int userId,
    bool forRead,
    bool forWrite,
    bool forProcessingOnly = false,
    bool forInformationView = false,
    bool includeEntityQueries = false
)
        {
            var entityType = new EntityType();

            // Helper function to execute SQL and map results.
            async Task ExecuteQueryAsync(string query, Action<SqlDataReader> processRow, params SqlParameter[] parameters)
            {
                using var command = new SqlCommand(query, connection);
                command.Parameters.AddRange(parameters);

                try
                {
                    using var reader = await command.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        processRow(reader);
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(query, parameters);
                    throw new Exception($"Exception occurred getting ExecuteQueryAsync: {ex.Message}", ex);
                }
            }

            // Main query to retrieve entity type details.
            string baseQuery = forProcessingOnly ?
                "SELECT RowStatus, RowVersion, Guid, Name, HasDocuments, CanRead, CanWrite, IsRootEntity FROM SCore.tvf_EntityTypes (@Guid, @UserId)" :
                "SELECT * FROM SCore.tvf_EntityTypes (@Guid, @UserId)";

            await ExecuteQueryAsync(baseQuery, reader =>
            {
                entityType = new EntityType
                {
                    RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                    RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                    Name = reader.GetString(reader.GetOrdinal("Name")),
                    HasDocuments = reader.GetBoolean(reader.GetOrdinal("HasDocuments")),
                    IsRootEntity = reader.GetBoolean(reader.GetOrdinal("IsRootEntity")),
                    ObjectSecurity = new List<Types.ObjectSecurity>
                    {
                        new Types.ObjectSecurity
                        {
                            CanRead = reader.GetBoolean(reader.GetOrdinal("CanRead")),
                            CanWrite = reader.GetBoolean(reader.GetOrdinal("CanWrite"))
                        }
                    }
                };

                if (!forProcessingOnly)
                {
                    entityType.DetailPageUrl = reader.GetString(reader.GetOrdinal("DetailPageUrl"));
                    entityType.Label = reader.GetString(reader.GetOrdinal("Label"));
                    entityType.IconCss = reader.GetString(reader.GetOrdinal("IconCss"));
                    entityType.LanguageLabelGuid = reader.GetGuid(reader.GetOrdinal("LanguageLabelGuid"));
                    entityType.IsReadOnlyOffline = reader.GetBoolean(reader.GetOrdinal("IsReadOnlyOffline"));
                    entityType.IsRequiredSystemData = reader.GetBoolean(reader.GetOrdinal("IsRequiredSystemData"));
                    entityType.DoNotTrackChanges = reader.GetBoolean(reader.GetOrdinal("DoNotTrackChanges"));
                }
            },
            new SqlParameter("@Guid", guid),
            new SqlParameter("@UserId", userId));

            if (entityType.Guid == Guid.Empty)
            {
                return entityType; // No entity type found.
            }

            // Retrieve related data if not for processing only.
            if (!forProcessingOnly)
            {
                await ExecuteQueryAsync(
                    "SELECT * FROM SCore.tvf_PropertyGroupsForEntityType (@Guid, @UserId)",
                    reader =>
                    {
                        entityType.EntityPropertyGroups.Add(new Types.EntityPropertyGroup
                        {
                            RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                            RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                            Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                            Name = reader.GetString(reader.GetOrdinal("Name")),
                            LanguageLabelGuid = reader.GetGuid(reader.GetOrdinal("LanguageLabelGuid")),
                            SortOrder = reader.GetInt16(reader.GetOrdinal("SortOrder")),
                            Label = reader.GetString(reader.GetOrdinal("Label")),
                            Layout = reader.GetString(reader.GetOrdinal("PropertyGroupLayout")),
                            ShowOnMobile = reader.GetBoolean(reader.GetOrdinal("ShowOnMobile")),
                            IsCollapsable = reader.GetBoolean(reader.GetOrdinal("IsCollapsable")),
                            IsDefaultCollapsed = reader.GetBoolean(reader.GetOrdinal("IsDefaultCollapsed")),
                            IsDefaultCollapsed_Mobile = reader.GetBoolean(reader.GetOrdinal("IsDefaultCollapsed_Mobile")),
                        });
                    },
                    new SqlParameter("@Guid", entityType.Guid),
                    new SqlParameter("@UserId", userId));
            }
            await ExecuteQueryAsync(
                "SELECT * FROM SCore.tvf_HoBTsForEntityType (@Guid, @UserId)",
                reader =>
                {
                    var entityHoBT = new EntityHoBT
                    {
                        RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                        RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                        Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                        SchemaName = reader.GetString(reader.GetOrdinal("SchemaName")),
                        ObjectName = reader.GetString(reader.GetOrdinal("ObjectName")),
                        EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")),
                        ObjectType = reader.GetString(reader.GetOrdinal("ObjectType")),
                        IsMainHoBT = reader.GetBoolean(reader.GetOrdinal("IsMainHoBT")),
                        IsReadOnlyOffline = reader.GetBoolean(reader.GetOrdinal("IsReadOnlyOffline")),
                        ObjectSecurity = new List<Types.ObjectSecurity>
                        {
                        new Types.ObjectSecurity
                        {
                            CanRead = reader.GetBoolean(reader.GetOrdinal("CanRead")),
                            CanWrite = reader.GetBoolean(reader.GetOrdinal("CanWrite"))
                        }
                        }
                    };

                    entityType.EntityHoBTs.Add(entityHoBT);
                },
                new SqlParameter("@Guid", entityType.Guid),
                new SqlParameter("@UserId", userId));

            // Load additional properties if required.
            await ExecuteQueryAsync(
                forProcessingOnly ?
                "SELECT RowStatus, RowVersion, Guid, Name, EntityDataTypeGuid, ExternalSearchPageUrl, EntityPropertyGroupGuid, IsReadOnly, IsImmutable, IsCompulsory, MaxLength, Precision, Scale, EntityDataTypeName, IsObjectLabel, DropDownListDefinitionGuid, IsParentRelationship, EntityHobtGuid, IsIncludedInformation, CanRead, CanWrite, IsUpperCase, IsVirtual, ShowOnMobile, IsAlwaysVisibleInGroup, IsAlwaysVisibleInGroup_Mobile   FROM SCore.tvf_PropertiesForEntityType (@Guid, @UserId)" :
                "SELECT * FROM SCore.tvf_PropertiesForEntityType (@Guid, @UserId)",
                reader =>
                {
                    if (!forInformationView || forInformationView && reader.GetBoolean(reader.GetOrdinal("IsIncludedInformation")))
                    {
                        var entityProperty = new EntityProperty
                        {
                            RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                            RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                            Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                            Name = reader.GetString(reader.GetOrdinal("Name")),
                            EntityDataTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityDataTypeGuid")),
                            EntityTypeGuid = guid,
                            EntityPropertyGroupGuid = reader.GetGuid(reader.GetOrdinal("EntityPropertyGroupGuid")),
                            IsReadOnly = reader.GetBoolean(reader.GetOrdinal("IsReadOnly")),
                            IsImmutable = reader.GetBoolean(reader.GetOrdinal("IsImmutable")),
                            IsCompulsory = reader.GetBoolean(reader.GetOrdinal("IsCompulsory")),
                            MaxLength = reader.GetInt32(reader.GetOrdinal("MaxLength")),
                            Precision = reader.GetInt32(reader.GetOrdinal("Precision")),
                            Scale = reader.GetInt32(reader.GetOrdinal("Scale")),
                            EntityDataTypeName = reader.GetString(reader.GetOrdinal("EntityDataTypeName")),
                            DropDownListDefinitionGuid = reader.GetGuid(reader.GetOrdinal("DropDownListDefinitionGuid")),
                            IsObjectLabel = reader.GetBoolean(reader.GetOrdinal("IsObjectLabel")),
                            IsParentRelationship = reader.GetBoolean(reader.GetOrdinal("IsParentRelationship")),
                            EntityHoBTGuid = reader.GetGuid(reader.GetOrdinal("EntityHoBTGuid")),
                            IsUppercase = reader.GetBoolean(reader.GetOrdinal("IsUppercase")),
                            IsIncludedInformation = reader.GetBoolean(reader.GetOrdinal("IsIncludedInformation")),
                            IsVirtual = reader.GetBoolean(reader.GetOrdinal("IsVirtual")),
                            ShowOnMobile = reader.GetBoolean(reader.GetOrdinal("ShowOnMobile")),
                            IsAlwaysVisibleInGroup = reader.GetBoolean(reader.GetOrdinal("IsAlwaysVisibleInGroup")),
                            IsAlwaysVisibleInGroup_Mobile = reader.GetBoolean(reader.GetOrdinal("IsAlwaysVisibleInGroup_Mobile")),
                            ObjectSecurity = new List<Types.ObjectSecurity>
                            {
                            new Types.ObjectSecurity
                            {
                                CanRead = reader.GetBoolean(reader.GetOrdinal("CanRead")),
                                CanWrite = reader.GetBoolean(reader.GetOrdinal("CanWrite"))
                            }
                            }
                        };

                        if (!forProcessingOnly)
                        {
                            entityProperty.IsHidden = reader.GetBoolean(reader.GetOrdinal("IsHidden"));
                            entityProperty.LanguageLabelGuid = reader.GetGuid(reader.GetOrdinal("LanguageLabelGuid"));
                            entityProperty.DoNotTrackChanges = reader.GetBoolean(reader.GetOrdinal("DoNotTrackChanges"));
                            entityProperty.Label = reader.GetString(reader.GetOrdinal("Label"));
                            entityProperty.SortOrder = reader.GetInt16(reader.GetOrdinal("SortOrder"));
                            entityProperty.GroupSortOrder = reader.GetInt16(reader.GetOrdinal("GroupSortOrder"));
                            entityProperty.IsLongitude = reader.GetBoolean(reader.GetOrdinal("IsLongitude"));
                            entityProperty.IsLatitude = reader.GetBoolean(reader.GetOrdinal("IsLatitude"));
                            entityProperty.IsDetailWindowed = reader.GetBoolean(reader.GetOrdinal("IsDetailWindowed"));
                            entityProperty.DetailPageUri = reader.GetString(reader.GetOrdinal("DetailPageUrl"));
                            entityProperty.InformationPageUri = reader.GetString(reader.GetOrdinal("InformationPageUrl"));
                            entityProperty.FixedDefaultValue = reader.GetString(reader.GetOrdinal("FixedDefaultValue"));
                            entityProperty.SqlDefaultValueStatement = reader.GetString(reader.GetOrdinal("SqlDefaultValueStatement"));
                            entityProperty.ForeignEntityTypeGuid = reader.GetGuid(reader.GetOrdinal("ForeignEntityTypeGuid"));
                            entityProperty.AllowBulkChange = reader.GetBoolean(reader.GetOrdinal("AllowBulkChange"));
                            entityProperty.ExternalSearchPageUrl = reader.GetString(reader.GetOrdinal("ExternalSearchPageUrl"));
                        }

                        if (forInformationView)
                        {
                            entityProperty.IsReadOnly = true;
                        }

                        entityType.EntityProperties.Add(entityProperty);
                    }
                },
                new SqlParameter("@Guid", entityType.Guid),
                new SqlParameter("@UserId", userId));

            if (!forProcessingOnly)
            {
                // Retrieve entity property dependants.
                foreach (EntityProperty entityProperty in entityType.EntityProperties)
                {
                    string dependantQuery = @"SELECT epd.ID, epd.RowStatus, epd.Guid, epd.RowVersion, ep.Guid as ParentEntityPropertyID, dep.Guid as DependantPropertyID
                FROM SCore.EntityPropertyDependants epd
                JOIN SCore.EntityProperties ep ON (ep.ID = epd.ParentEntityPropertyID)
                JOIN SCore.EntityProperties dep on (dep.ID = epd.DependantPropertyID)
                WHERE (ep.Guid = @ParentPropertyGuid)";

                    await ExecuteQueryAsync(
                        dependantQuery,
                        reader =>
                        {
                            var dependant = new EntityPropertyDependant
                            {
                                RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                                RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                                Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                ParentEntityPropertyGuid = reader.GetGuid(reader.GetOrdinal("ParentEntityPropertyID")),
                                DependantEntityPropertyGuid = reader.GetGuid(reader.GetOrdinal("DependantPropertyID"))
                            };

                            entityProperty.DependantProperties.Add(dependant);
                        },
                        new SqlParameter("@ParentPropertyGuid", entityProperty.Guid));

                    if (entityProperty.DropDownListDefinitionGuid != Guid.Empty)
                    {
                        var ddld = await UserInterface.DropDownDataListDefinitionGet(connection, entityProperty.DropDownListDefinitionGuid);
                        entityProperty.DropDownListDefinition = ddld.DropDownListDefinition;
                    }
                }
            }

            //OE: CBLD-259 - Retrieve entity property actions.
            if (entityType.EntityProperties != null)
            {
                foreach (var entityProperty in entityType.EntityProperties)
                {
                    await ExecuteQueryAsync(
                        "SELECT RowStatus, RowVersion, Guid, Statement FROM [Score].[tvf_ActionsForEntityProperty] (@Guid)",
                        reader =>
                        {
                            var entityPropertyAction = new EntityPropertyActions
                            {
                                RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                                RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                                Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                Statement = reader.GetString(reader.GetOrdinal("Statement"))
                            };

                            entityProperty.PropertyActions.Add(entityPropertyAction);
                        },
                        new SqlParameter("@Guid", entityProperty.Guid));
                }
            }
            // Include entity queries if required.
            if (includeEntityQueries)
            {
                await ExecuteQueryAsync(
                    "SELECT * FROM [SCore].[tvf_QueriesForEntityType] (@Guid, @UserId)",
                    reader =>
                    {
                        var entityQuery = new EntityQuery
                        {
                            RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                            RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                            Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                            Name = reader.GetString(reader.GetOrdinal("Name")),
                            Statement = reader.GetString(reader.GetOrdinal("Statement")),
                            EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")),
                            IsDefaultCreate = reader.GetBoolean(reader.GetOrdinal("IsDefaultCreate")),
                            IsDefaultRead = reader.GetBoolean(reader.GetOrdinal("IsDefaultRead")),
                            IsDefaultUpdate = reader.GetBoolean(reader.GetOrdinal("IsDefaultUpdate")),
                            IsDefaultDelete = reader.GetBoolean(reader.GetOrdinal("IsDefaultDelete")),
                            IsScalarExecute = reader.GetBoolean(reader.GetOrdinal("IsScalarExecute")),
                            EntityHoBTGuid = reader.GetGuid(reader.GetOrdinal("EntityHoBTGuid")),
                            IsDefaultValidation = reader.GetBoolean(reader.GetOrdinal("IsDefaultValidation")),
                            IsDefaultDataPills = reader.GetBoolean(reader.GetOrdinal("IsDefaultDataPills")),
                            IsDefaultProgressData = reader.GetBoolean(reader.GetOrdinal("IsProgressData"))
                        };

                        entityType.EntityQueries.Add(entityQuery);
                    },
                    new SqlParameter("@Guid", guid),
                    new SqlParameter("@UserId", userId));

                foreach (var entityQuery in entityType.EntityQueries)
                {
                    await ExecuteQueryAsync(
                        "SELECT * FROM SCore.tvf_ParametersForEntityQuery (@Guid, @UserId)",
                        reader =>
                        {
                            var entityQueryParameter = new EntityQueryParameter
                            {
                                RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                                RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                                Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                Name = reader.GetString(reader.GetOrdinal("Name")),
                                MappedEntityPropertyGuid = reader.GetGuid(reader.GetOrdinal("MappedEntityPropertyGuid"))
                            };

                            var entityDataType = new EntityDataType
                            {
                                RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("EdtRowStatus")),
                                RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("EdtRowVersion"))),
                                Guid = reader.GetGuid(reader.GetOrdinal("EdtGuid")),
                                Name = reader.GetString(reader.GetOrdinal("EdtName"))
                            };

                            entityQueryParameter.EntityDataType = entityDataType;
                            entityQuery.EntityQueryParameters.Add(entityQueryParameter);
                        },
                        new SqlParameter("@Guid", entityQuery.Guid),
                        new SqlParameter("@UserId", userId));
                }
            }

            // Validate permissions.
            var objectSecurity = entityType.ObjectSecurity.FirstOrDefault();
            if (objectSecurity != null)
            {
                if (forRead && !objectSecurity.CanRead)
                {
                    throw new Exception("You do not have permission to read objects of this type.");
                }
                if (forWrite && !objectSecurity.CanWrite)
                {
                    throw new Exception("You do not have permission to create or modify objects of this type.");
                }
            }

            return entityType;
        }

        public static async Task<EntityType> GetEntityTypeCached(
            Guid guid, SqlConnection connection, int userId,
            bool forRead, bool forWrite,
            bool forProcessingOnly = false,
            bool forInformationView = false,
            bool includeEntityQueries = false)
        {
            var key = EtKey(guid, userId, forRead, forWrite, forProcessingOnly, forInformationView, includeEntityQueries);

            if (_entityTypeCache.Get(key) is EntityType cached)
                return cached; // treat as read-only

            var fresh = await GetEntityType(guid, connection, userId,
                                            forRead, forWrite, forProcessingOnly,
                                            forInformationView, includeEntityQueries);

            // Cache for 5 minutes (tune as needed). If you change metadata, clear this cache.
            _entityTypeCache.Set(key, fresh, DateTimeOffset.UtcNow.AddMinutes(5));
            return fresh;
        }

        //CBLD-408: OE - Added WidgetLayout field
        public static async Task<UserPreferences> GetUserPreferences(int userId, SqlConnection connection, SqlTransaction transaction)
        {
            // Initialize user preferences
            var userPreferences = new UserPreferences();

            // Define the SQL query to retrieve user preferences
            const string query = @"SELECT up.ID, up.Guid, up.SystemLanguageID, up.WidgetLayout
                           FROM SCore.UserPreferences up
                           WHERE up.ID = @userId";

            // Use a single using block to ensure proper disposal of resources
            using var command = QueryBuilder.CreateCommand(query, connection, transaction);
            command.Parameters.Add(new SqlParameter("@userId", userId));

            try
            {
                using var reader = await command.ExecuteReaderAsync();

                if (await reader.ReadAsync()) // Only fetch one record as ID is unique
                {
                    userPreferences = new UserPreferences
                    {
                        ID = reader.GetInt32(reader.GetOrdinal("ID")),
                        Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                        SystemLanguageID = reader.GetInt32(reader.GetOrdinal("SystemLanguageID")),
                        WidgetLayout = reader.GetString(reader.GetOrdinal("WidgetLayout"))
                    };
                }

                return userPreferences;
            }
            catch (Exception ex)
            {
                ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                throw new Exception($"Exception occurred getting GetUserPreferences: {ex.Message}", ex);
            }
        }

        public static async Task<List<GridViewAction>> GridViewActionsGet(SqlConnection connection, string guid, int userId)
        {
            // Define the SQL query to retrieve grid view actions
            const string query = @"SELECT * FROM SUserInterface.tvf_ActionsForGridView(@Guid, @UserId)";
            var gridViewActions = new List<GridViewAction>();

            // Use a single using block to ensure proper disposal of resources
            using var command = QueryBuilder.CreateCommand(query, connection);
            command.Parameters.Add(new SqlParameter("@Guid", guid));
            command.Parameters.Add(new SqlParameter("@UserId", userId));
            try
            {
                using var reader = await command.ExecuteReaderAsync();
                while (await reader.ReadAsync()) // Fetch all grid view actions
                {
                    var gridViewAction = new GridViewAction
                    {
                        Title = reader.GetString(reader.GetOrdinal("Title")),
                        Statement = reader.GetString(reader.GetOrdinal("Statement")),
                        Guid = reader.GetGuid(reader.GetOrdinal("Guid"))
                    };

                    gridViewActions.Add(gridViewAction);
                }

                return gridViewActions;
            }
            catch (Exception ex)
            {
                ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                throw new Exception($"Exception occurred getting GridViewActionsGet: {ex.Message}", ex);
            }
        }

        public static async Task<List<DataPill>> ReadDataPills(EntityType entityType, DataObject dataObject, SqlConnection connection, SqlTransaction? transaction = null)
        {
            var query = entityType.EntityQueries.FirstOrDefault(q => q.IsDefaultDataPills);
            var results = new List<DataPill>();

            if (query is not null)
            {
                using var command = QueryBuilder.BuildCommandForEntityQuery(query, dataObject, new List<EntityQueryParameterValue>(), connection, transaction);
                try
                {
                    using var reader = await command.ExecuteReaderAsync();

                    while (await reader.ReadAsync())
                    {
                        results.Add(new DataPill
                        {
                            Value = reader.GetString(reader.GetOrdinal("Label")),
                            Class = reader.GetString(reader.GetOrdinal("Class")),
                            SortOrder = reader.GetInt32(reader.GetOrdinal("SortOrder"))
                        });
                    }
                }
                catch (Exception ex)
                {
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting ReadDataPills: {ex.Message}", ex);
                }
            }

            return results;
        }

        public static async Task<ProgressData> ReadProgressData(EntityType entityType, DataObject dataObject, SqlConnection connection, SqlTransaction? transaction = null)
        {
            var query = entityType.EntityQueries.FirstOrDefault(q => q.IsDefaultProgressData);
            var result = new ProgressData();

            if (query is not null)
            {
                using var command = QueryBuilder.BuildCommandForEntityQuery(query, dataObject, new List<EntityQueryParameterValue>(), connection, transaction);
                try
                {
                    using var reader = await command.ExecuteReaderAsync();

                    if (await reader.ReadAsync()) // Fetch only one row
                    {
                        result.FirstValue = reader.GetInt32(reader.GetOrdinal("FirstValue"));
                        result.FirstDescription = reader.GetString(reader.GetOrdinal("FirstDescription"));
                        result.FirstComplete = reader.GetBoolean(reader.GetOrdinal("FirstComplete"));
                        result.PreviousValue = reader.GetInt32(reader.GetOrdinal("PreviousValue"));
                        result.PreviousDescription = reader.GetString(reader.GetOrdinal("PreviousDescription"));
                        result.PreviousComplete = reader.GetBoolean(reader.GetOrdinal("PreviousComplete"));
                        result.MidValue = reader.GetInt32(reader.GetOrdinal("MidValue"));
                        result.MidDescription = reader.GetString(reader.GetOrdinal("MidDescription"));
                        result.MidComplete = reader.GetBoolean(reader.GetOrdinal("MidComplete"));
                        result.NextValue = reader.GetInt32(reader.GetOrdinal("NextValue"));
                        result.NextDescription = reader.GetString(reader.GetOrdinal("NextDescription"));
                        result.NextComplete = reader.GetBoolean(reader.GetOrdinal("NextComplete"));
                        result.LastValue = reader.GetInt32(reader.GetOrdinal("LastValue"));
                        result.LastDescription = reader.GetString(reader.GetOrdinal("LastDescription"));
                        result.LastComplete = reader.GetBoolean(reader.GetOrdinal("LastComplete"));
                    }
                }
                catch (Exception ex)
                {
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting ReadProgressData: {ex.Message}", ex);
                }
            }
            return result;
        }

        [Obsolete("Use Core.BindStandardTokens instead of ReplacePredicateTokens.")]
        public static string ReplacePredicateTokens(string sqlQuery, int currentUserId, int? userId, Guid? parentGuid, Guid? recordGuid)
        {
            if (sqlQuery.Contains("[[CURRENT_USER_ID]]"))
            {
                sqlQuery = sqlQuery.Replace("[[CURRENT_USER_ID]]", currentUserId.ToString());
            }

            if (userId.HasValue)
            {
                sqlQuery = sqlQuery.Replace("[[UserId]]", userId.Value.ToString());
            }

            if (parentGuid.HasValue)
            {
                sqlQuery = sqlQuery.Replace("[[ParentGuid]]", parentGuid.Value.ToString());
            }

            if (recordGuid.HasValue)
            {
                sqlQuery = sqlQuery.Replace("[[RecordGuid]]", recordGuid.Value.ToString());
            }

            return sqlQuery;
        }

        public static async Task ValidateCompositeFilter(DataObjectCompositeFilter dataObjectCompositeFilter)
        {
            foreach (DataObjectCompositeFilter docf in dataObjectCompositeFilter.CompositeFilters)
            {
                await ValidateCompositeFilter(docf);

                //if (docf.LogicalOperator == "")
                //{
                //    throw new Exception("No logical operator specified on the composite filter");
                //}

                foreach (DataObjectFilter dof in docf.Filters)
                {
                    if (dof.Guid == Guid.Empty)
                    {
                        throw new Exception("You must specify a guid for each filter");
                    }
                }
            }
        }

        public static async Task ValidateCompositeFilterList(List<DataObjectCompositeFilter> dataObjectCompositeFilters)
        {
            if (dataObjectCompositeFilters.Count > 0)
            {
                await ValidateCompositeFilter(dataObjectCompositeFilters[0]);
            }
        }

        public SqlConnection CreateConnection()
        {
            if (string.IsNullOrWhiteSpace(_connectionString))
            {
                throw new InvalidOperationException("Connection string cannot be null or empty.");
            }

            return new SqlConnection(_connectionString);
        }

        /// <summary>
        /// Retrieves a list of schedule items for the dashboard. Ensures proper connection and
        /// command management while leveraging extensions for improved readability.
        /// </summary>
        /// <returns> A list of <see cref="ScheduleItem"/> objects. </returns>
        public async Task<List<ScheduleItem>> DashboardScheduleItemsGet()
        {
            List<ScheduleItem> result = new();
            SqlConnection? connection = null;

            try
            {
                connection = CreateConnection();
                await OpenConnectionAsync(connection);

                // Execute within a transaction (ReadCommitted is the default isolation level)
                await connection.ExecuteInTransaction(async transaction =>
                {
                    string query = "SELECT * FROM SCore.tvf_DashboardScheduleItems (@UserId)";
                    await using (var command = QueryBuilder.CreateCommand(query, connection, transaction))
                    {
                        // Add parameter using the AddParameters extension
                        command.AddParameters(new[]
                        {
                    new SqlParameter("@UserId", _userId)
                });

                        // Read data using extensions for improved safety and readability
                        try
                        {
                            await using var reader = await command.ExecuteReaderAsync();
                            while (await reader.ReadAsync())
                            {
                                var scheduleItem = new ScheduleItem
                                {
                                    Id = reader.GetInt64(reader.GetOrdinal("Id")),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                    Title = reader.GetStringOrNull("Title"),
                                    Description = reader.GetStringOrNull("Description"),
                                    IsAllDay = reader.GetBooleanSafe("IsAllDay"),
                                    RecurrenceRule = reader.GetStringOrNull("RecurrenceRule"),
                                    RecurrenceId = reader.GetIntSafe("RecurrenceId"),
                                    RecurrenceExceptions = reader.GetStringOrNull("RecurrenceExceptions"),
                                    StartTimezone = reader.GetStringOrNull("StartTimezone"),
                                    EndTimezone = reader.GetStringOrNull("EndTimezone"),
                                    UserId = reader.GetIntSafe("UserId"),
                                    StatusId = reader.GetIntSafe("StatusId"),
                                    TypeId = reader.GetIntSafe("TypeId"),
                                    JobNumber = reader.GetStringOrNull("JobNumber"),
                                    StartDateTimeUTC = reader.GetDateTimeOrNull("Start") ?? DateTime.UtcNow,
                                    EndDateTimeUTC = reader.GetDateTimeOrNull("End") ?? DateTime.UtcNow
                                };
                                result.Add(scheduleItem);
                            }
                        }
                        catch (Exception ex)
                        {
                            // Attach the SQL query to the exception data so the API logger can pick
                            // it up
                            ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                            throw new Exception($"Exception occurred getting DashboardScheduleItemsGet(): {ex.Message}", ex);
                        }
                    }
                });
            }
            finally
            {
                // Ensure the connection is always closed and disposed
                if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                {
                    connection.Close();
                }
                connection?.Dispose();
            }

            return result;
        }

        public DataObjectCompositeFilter DataObjectCompositeFilterAddGuid(DataObjectCompositeFilter dataObjectCompositeFilter)
        {
            DataObjectCompositeFilter rsl = new();

            foreach (DataObjectCompositeFilter filter in dataObjectCompositeFilter.CompositeFilters)
            {
                rsl.CompositeFilters.Add(DataObjectCompositeFilterAddGuid(filter));
            }

            foreach (DataObjectFilter filter in dataObjectCompositeFilter.Filters)
            {
                filter.Guid = Guid.NewGuid();
                rsl.Filters.Add(filter);
            }

            return rsl;
        }

        public List<DataObjectCompositeFilter> DataObjectCompositeFilterListAddGuid(List<DataObjectCompositeFilter> dataObjectCompositeFilters)
        {
            List<DataObjectCompositeFilter> rsl = new();

            foreach (DataObjectCompositeFilter filter in dataObjectCompositeFilters)
            {
                rsl.Add(DataObjectCompositeFilterAddGuid(filter));
            }

            return rsl;
        }

        /// <summary>
        /// Deletes a data object based on the provided request, ensuring proper validation and
        /// transaction handling.
        /// </summary>
        /// <param name="request"> The data object delete request containing necessary details. </param>
        /// <returns> True if the delete operation was successful; otherwise, false. </returns>
        public async Task<bool> DataObjectDelete(DataObjectDeleteRequest request)
        {
            bool rsl = false;

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                EntityType entityType = await GetEntityType(request.DataObject.EntityTypeGuid, connection, _userId, true, true, true, false, true);

                using (var transaction = QueryBuilder.BeginTransaction(connection))
                {
                    bool rowversionCheck = await Validation.CheckRowVersionMatches(entityType, request.DataObject.RowVersion, request.DataObject.Guid, connection, transaction);

                    if (!rowversionCheck)
                    {
                        throw new Exception("Another user has edited this record, please reload before attempting to delete.");
                    }

                    EntityQuery query = new();

                    foreach (EntityQuery eq in entityType.EntityQueries)
                    {
                        if (eq.Guid == request.EntityQueryGuid)
                        {
                            query = eq;
                            break;
                        }
                        else if (eq.IsDefaultDelete == true && request.EntityQueryGuid == Guid.Empty)
                        {
                            query = eq;
                            break;
                        }
                    }

                    if (query?.Statement is not null)
                    {
                        if (query.Statement != "")
                        {
                            using (var command = QueryBuilder.BuildCommandForEntityQuery(query, request.DataObject, request.EntityQueryParameterValues.ToList(), connection, transaction))
                            {
                                await command.ExecuteScalarAsync();
                            }

                            await QueryBuilder.CommitTransactionAsync(transaction);

                            rsl = true;
                        }
                    }
                }
            }

            return rsl;
        }

        // Single-object convenience wrapper (kept signature; safer return)
        public async Task<DataObject> DataObjectGet(
    Guid objectGuid,
    Guid entityQueryGuid,
    Guid entityTypeGuid,
    bool ForInformationView,
    Dictionary<string, Google.Protobuf.WellKnownTypes.Any>? transientVirtualProperties = null)
        {
            var dataObjects = await DataObjectGet(
    new List<Guid> { objectGuid },
    entityQueryGuid,
    entityTypeGuid,
    ForInformationView,
    transientVirtualProperties);
            return dataObjects.FirstOrDefault() ?? new DataObject { ErrorReturned = "DataObjectGet() returned no data." };
        }

        public async Task<List<DataObject>> DataObjectGet(
    List<Guid> objectGuids,
    Guid entityQueryGuid,
    Guid entityTypeGuid,
    bool ForInformationView,
    Dictionary<string, Google.Protobuf.WellKnownTypes.Any>? transientVirtualProperties = null)
        {
            var listResult = new List<DataObject>();
            var swTotal = Stopwatch.StartNew();

            try
            {
                using (var connection = CreateConnection())
                {
                    await OpenConnectionAsync(connection);

                    // Keep session at READ COMMITTED (pair with DB-level READ_COMMITTED_SNAPSHOT ON)
                    await QueryBuilder.SetReadCommittedAsync(connection);

                    // 1) Resolve entity type once (it drives HoBT processing)
                    var swEntityType = Stopwatch.StartNew();
                    var entityType = await GetEntityTypeCached(entityTypeGuid, connection, _userId, true, false, true, ForInformationView, true);

                    swEntityType.Stop();
                    Console.WriteLine($"[DataObjectGet] GetEntityType {entityTypeGuid} took {swEntityType.ElapsedMilliseconds} ms");

                    // 2) Load each requested object (isolate failures per object)
                    foreach (var objectGuid in objectGuids)
                    {
                        var swObj = Stopwatch.StartNew();

                        try
                        {
                            var dataObject = new DataObject
                            {
                                EntityTypeGuid = entityTypeGuid,
                                HasDocuments = entityType.HasDocuments
                            };

                            // 2a) Security check for this object
                            var swSec = Stopwatch.StartNew();
                            var securityList = await GetObjectSecurityList(connection, objectGuid);
                            swSec.Stop();
                            Console.WriteLine($"[DataObjectGet] GetObjectSecurityList {objectGuid} took {swSec.ElapsedMilliseconds} ms");

                            var securityListItem = securityList.FirstOrDefault();
                            if (securityListItem != null && !securityListItem.CanRead)
                                throw new Exception("You do not have permission to read this object.");

                            dataObject.HasValidationMessages = false;

                            // 2b) Process HoBTs (main first)
                            foreach (var eh in entityType.EntityHoBTs.OrderByDescending(h => h.IsMainHoBT))
                            {
                                var swHobt = Stopwatch.StartNew();
                                dataObject = await ReadEntityHoBT(
    connection,
    dataObject,
    entityType,
    eh,
    entityQueryGuid,
    objectGuid,
    ForInformationView,
    transientVirtualProperties); swHobt.Stop();
                                Console.WriteLine($"[DataObjectGet] ReadEntityHoBT {eh.SchemaName}.{eh.ObjectName} for {objectGuid} took {swHobt.ElapsedMilliseconds} ms");
                            }

                            // 2c) SharePoint folder info (if used by this entity type)
                            if (entityType.HasDocuments)
                            {
                                var swSp = Stopwatch.StartNew();
                                await PopulateSharePointDetails(connection, objectGuid, dataObject);
                                swSp.Stop();
                                Console.WriteLine($"[DataObjectGet] PopulateSharePointDetails {objectGuid} took {swSp.ElapsedMilliseconds} ms");
                            }

                            // 2d) Additional details (skip when ForInformationView=true)
                            if (!ForInformationView)
                            {
                                var swAdd = Stopwatch.StartNew();
                                await PopulateAdditionalDetails(connection, entityType, dataObject, objectGuid);
                                swAdd.Stop();
                                Console.WriteLine($"[DataObjectGet] PopulateAdditionalDetails {objectGuid} took {swAdd.ElapsedMilliseconds} ms");
                            }

                            // 2e) Field-level permissions
                            var swPerm = Stopwatch.StartNew();
                            dataObject = await DisableFieldsBasedOnPermissions(dataObject, connection, objectGuid.ToString());
                            swPerm.Stop();
                            Console.WriteLine($"[DataObjectGet] DisableFieldsBasedOnPermissions {objectGuid} took {swPerm.ElapsedMilliseconds} ms");

                            listResult.Add(dataObject);
                            swObj.Stop();
                            Console.WriteLine($"[DataObjectGet] DONE {objectGuid} in {swObj.ElapsedMilliseconds} ms");
                        }
                        catch (Exception exObj)
                        {
                            // Capture error per object so other GUIDs still return
                            listResult.Add(new DataObject
                            {
                                EntityTypeGuid = entityTypeGuid,
                                ErrorReturned = $"DataObjectGet({objectGuid}) failed: {exObj.Message}"
                            });
                            Console.WriteLine($"[DataObjectGet] FAIL {objectGuid}: {exObj}");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                // Connection/global failure: mirror your existing pattern
                listResult.Add(new DataObject { ErrorReturned = "DataObjectGet() failed: " + ex.Message });
                Console.WriteLine($"[DataObjectGet] GLOBAL FAIL: {ex}");
            }
            finally
            {
                swTotal.Stop();
                Console.WriteLine($"[DataObjectGet] TOTAL {swTotal.ElapsedMilliseconds} ms for {objectGuids.Count} object(s)");
            }

            return listResult;
        }

        public async Task<DataObjectUpsertResponse> DataObjectUpsert(DataObjectUpsertRequest request)
        {
            var response = new DataObjectUpsertResponse();
            try
            {
                using var connection = CreateConnection();
                await OpenConnectionAsync(connection);

                // Fetch entity type
                var entityType = await GetEntityType(
                    request.DataObject.EntityTypeGuid,
                    connection,
                    _userId,
                    forRead: true,
                    forWrite: true,
                    forProcessingOnly: true,
                    forInformationView: false,
                    includeEntityQueries: true);

                // Begin transaction
                using var transaction = QueryBuilder.BeginTransaction(connection, IsolationLevel.Serializable);

                var dataObject = request.DataObject;
                dataObject.ValidationResults = new List<ValidationResult>();
                dataObject.HasValidationMessages = false;

                // Row Version Validation
                var rowVersionValid = await ValidateRowVersion(dataObject, entityType, connection, transaction);
                if (!rowVersionValid)
                {
                    AddRowVersionValidationMessage(dataObject, connection, transaction);
                }

                // Perform Validation and Upsert
                foreach (var entityHoBT in entityType.EntityHoBTs)
                {
                    // Skip EntityHoBT if no default create or update query exists
                    var hasDefaultQuery = entityType.EntityQueries.Any(eq =>
                        eq.EntityHoBTGuid == entityHoBT.Guid &&
                        (eq.IsDefaultCreate || eq.IsDefaultUpdate || eq.Guid == request.EntityQueryGuid));

                    if (!hasDefaultQuery)
                    {
                        continue; // Skip this EntityHoBT
                    }

                    if (!request.SkipValidation)
                    {
                        var validationResults = await Validation.RunObjectValidation(
                            entityType, dataObject, connection, entityHoBT, transaction);

                        // Apply validation results but continue processing
                        Validation.ApplyValidationResults(ref dataObject, false, entityType, validationResults, entityHoBT.Guid, false);
                    }

                    // Perform Upsert Logic (Validation-Only or Actual Upsert)
                    if (!request.ValidateOnly)
                    {
                        await PerformUpsert(request, dataObject, entityType, entityHoBT, connection, transaction);
                    }
                }

                // Commit transaction
                await QueryBuilder.CommitTransactionAsync(transaction);

                // Re-query object if not validate-only
                if (!request.ValidateOnly)
                {
                    response.DataObject = await ReQueryObject(dataObject, request);
                }
                else
                {
                    dataObject.DataPills.Clear();
                    List<DataPill> dataPills = await ReadDataPills(entityType, dataObject, connection, transaction);

                    if (dataPills != null)
                    {
                        dataObject.DataPills.AddRange(dataPills);
                    }
                    response.DataObject = dataObject;
                }

                var models = ProtoDataPropertyConverter.ToProtoModels(dataObject.DataProperties);
                //DataObjectDebugHelper.DumpDataProperties(models);
            }
            catch (Exception ex)
            {
                return new DataObjectUpsertResponse
                {
                    DataObject = new DataObject
                    {
                        ErrorReturned = "DataObjectUpsert() failed: " + ex.Message
                    }
                };
            }

            return response;
        }

        public async Task<bool> DeleteMergeDocumentItemInclude(Guid guid)
        {
            using (SqlConnection connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string sql = @"EXEC SCore.MergeDocumentItemIncludesDelete @Guid";

                using (SqlCommand command = QueryBuilder.CreateCommand(sql, connection))
                {
                    command.Parameters.Add(new SqlParameter("@Guid", guid));
                    try
                    {
                        var result = await command.ExecuteNonQueryAsync();
                        return result > 0; // Return true if rows were affected
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting DeleteMergeDocumentItemInclude: {ex.Message}", ex);
                    }
                }
            }
        }

        //OE: Fix for CBLD-92.
        public async Task<DataObject> DisableFieldsBasedOnPermissions(DataObject rsl, SqlConnection connection, string Guid)
        {
            string query = $@"SELECT CanWrite FROM SCore.ObjectSecurityForUser(@Guid, @UserId)";
            bool CanWrite = true;

            using (var command = QueryBuilder.CreateCommand(query, connection))
            {
                command.Parameters.Add(new SqlParameter("@Guid", Guid));
                command.Parameters.Add(new SqlParameter("@UserId", _userId));

                try
                {
                    using SqlDataReader reader = await command.ExecuteReaderAsync();
                    if (await reader.ReadAsync())
                    {
                        CanWrite = reader.GetBoolean(reader.GetOrdinal("CanWrite"));
                    }
                }
                catch (Exception ex)
                {
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting DisableFieldsBasedOnPermissions: {ex.Message}", ex);
                }
            }

            if (!CanWrite)
            {
                foreach (var fields in rsl.DataProperties) fields.IsReadOnly = true;
                rsl.SaveButtonDisabled = true; //CBLD-382
            }

            return rsl;
        }

        public async Task<IReadOnlyList<JobInvoiceScheduleRow>> GetJobInvoiceSchedulesAsync(
int userId,
Guid parentGuid,
CancellationToken ct)
        {
            var results = new List<JobInvoiceScheduleRow>();

            await using var conn = CreateConnection();
            await conn.OpenAsync(ct);

            const string sql = @"
SELECT root_hobt.ID, root_hobt.Guid, root_hobt.Name, root_hobt.DescriptionOfWork,
       root_hobt.Amount, root_hobt.TriggerId, root_hobt.ExpectedDate
FROM [SFin].[tvf_JobInvoiceSchedules](@UserId, @ParentGuid) AS root_hobt
WHERE root_hobt.RowStatus NOT IN (0,254)
ORDER BY root_hobt.ExpectedDate,
         root_hobt.ID;";

            await using var cmd = new SqlCommand(sql, conn) { CommandType = CommandType.Text };
            cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });
            cmd.Parameters.Add(new SqlParameter("@ParentGuid", SqlDbType.UniqueIdentifier) { Value = parentGuid });

            await using var r = await cmd.ExecuteReaderAsync(ct);
            while (await r.ReadAsync(ct))
            {
                long id = 0;
                if (!r.IsDBNull(0))
                {
                    var t = r.GetFieldType(0);
                    id = t == typeof(long) ? r.GetInt64(0)
                         : t == typeof(int) ? r.GetInt32(0)
                         : Convert.ToInt64(r.GetValue(0));
                }

                results.Add(new JobInvoiceScheduleRow(
                    Id: id,
                    Guid: r.IsDBNull(1) ? Guid.Empty : r.GetGuid(1),
                    Name: r.IsDBNull(2) ? "" : r.GetString(2),
                    DescriptionOfWork: r.IsDBNull(3) ? "" : r.GetString(3),
                    Amount: r.IsDBNull(4) ? 0m : Convert.ToDecimal(r.GetValue(4)),
                    TriggerId: r.IsDBNull(5) ? "Manual" : Convert.ToString(r.GetValue(5)) ?? "",
                    ExpectedDateUtc: r.IsDBNull(6) ? (DateTime?)null : r.GetDateTime(6)
                ));
            }

            return results;
        }

        public async Task<ExecuteEntityQueryResponse> ExecuteEntityQuery(ExecuteEntityQueryRequest request)
        {
            ExecuteEntityQueryResponse response = new();

            try
            {
                Console.WriteLine("Starting ExecuteEntityQuery...");

                await using var connection = CreateConnection();
                Console.WriteLine("Opening database connection...");
                await OpenConnectionAsync(connection);
                Console.WriteLine("Database connection opened.");

                Console.WriteLine($"Retrieving entity type for GUID: {request.DataObject.EntityTypeGuid}");
                EntityType entityType = await GetEntityType(request.DataObject.EntityTypeGuid, connection, _userId, true, true, true, false, true);
                Console.WriteLine($"Entity type retrieved: {entityType.Name}");

                await using var transaction = QueryBuilder.BeginTransaction(connection, IsolationLevel.ReadCommitted);
                Console.WriteLine("Transaction started.");

                DataObject dataObject = request.DataObject;
                string targetGuid = string.Empty;
                bool queryExecuted = false;

                foreach (var entityHoBT in entityType.EntityHoBTs)
                {
                    var query = entityType.EntityQueries.FirstOrDefault(eq => eq.Guid == request.EntityQueryGuid && eq.EntityHoBTGuid == entityHoBT.Guid);
                    if (query == null)
                    {
                        Console.WriteLine($"No matching query found for EntityHoBT: {entityHoBT.SchemaName}.{entityHoBT.ObjectName}");
                        continue;
                    }

                    Console.WriteLine($"Running row version check for EntityHoBT: {entityHoBT.SchemaName}.{entityHoBT.ObjectName}");
                    if (!await Validation.CheckRowVersionMatches(entityType, dataObject.RowVersion, dataObject.Guid, connection, transaction))
                    {
                        throw new Exception("Another user has edited this record, please reload before running the action.");
                    }

                    Console.WriteLine($"Executing entity query: {query.Name}");
                    queryExecuted = true;

                    targetGuid = Functions.ReplaceTargetGuidToken(query);

                    using var command = QueryBuilder.BuildCommandForEntityQuery(query, dataObject, request.EntityQueryParameterValues.ToList(), connection, transaction);
                    await command.ExecuteScalarAsync();
                    Console.WriteLine($"Query {query.Name} executed successfully.");
                }

                if (!queryExecuted)
                {
                    throw new Exception("No valid query found for the entity object.");
                }

                await QueryBuilder.CommitTransactionAsync(transaction);
                Console.WriteLine("Transaction committed.");

                if (!string.IsNullOrEmpty(targetGuid))
                {
                    Console.WriteLine($"Re-querying data object with new target GUID: {targetGuid}");
                    dataObject = await DataObjectGet(Guid.Parse(targetGuid), Guid.Empty, dataObject.EntityTypeGuid, false);
                }
                else
                {
                    Console.WriteLine($"Re-querying data object with current GUID: {dataObject.Guid}");
                    dataObject = await DataObjectGet(dataObject.Guid, Guid.Empty, dataObject.EntityTypeGuid, false);
                }

                Console.WriteLine("Running validation...");
                foreach (var entityHoBT in entityType.EntityHoBTs)
                {
                    var validationResults = await Validation.RunObjectValidation(entityType, dataObject, connection, entityHoBT, transaction);
                    Validation.ApplyValidationResults(ref dataObject, false, entityType, validationResults, entityHoBT.Guid, false);
                    Console.WriteLine($"Validation completed for EntityHoBT: {entityHoBT.SchemaName}.{entityHoBT.ObjectName}");
                }

                if (dataObject.RowStatus != Enums.RowStatus.New)
                {
                    Console.WriteLine("Clearing and re-reading data pills...");
                    dataObject.DataPills.Clear();
                    var dataPills = await ReadDataPills(entityType, dataObject, connection, transaction);
                    dataObject.DataPills.AddRange(dataPills ?? Enumerable.Empty<DataPill>());
                    Console.WriteLine("Data pills read successfully.");
                }

                response.DataObject = dataObject;
                Console.WriteLine("ExecuteEntityQuery process completed.");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error in ExecuteEntityQuery: {ex.Message}");
                response.DataObject = new DataObject { ErrorReturned = ex.Message };
            }

            return response;
        }

        //CBLD-265
        public async Task<ExecuteGridViewActionQueryResponse> ExecuteGridViewActionQuery(ExecuteGridViewActionQueryRequest request)
        {
            SqlConnection connection = null;

            try
            {
                connection = CreateConnection();
                await connection.OpenAsync();

                await using (SqlCommand command = new SqlCommand(request.Statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@Guid", request.Guid));
                    try
                    {
                        ExecuteGridViewActionQueryResponse response = new()
                        {
                            RowsAffected = await command.ExecuteNonQueryAsync()
                        };

                        // Validate rows affected
                        if (response.RowsAffected == -1 || response.RowsAffected == 1)
                        {
                            return response;
                        }
                        else
                        {
                            throw new Exception("Core/ExecuteGridViewActionQuery() There was an error");
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting ExecuteGridViewActionQuery: {ex.Message}", ex);
                    }
                }
            }
            catch (Exception ex)
            {
                return new ExecuteGridViewActionQueryResponse
                {
                    ErrorReturned = ex.Message
                };
            }
            finally
            {
                // Ensure the connection is always closed and disposed
                if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                {
                    connection.Close();
                }
                connection?.Dispose();
            }
        }

        public async Task<List<QuoteDashboardData>> GetQuoteDashboardData()
        {
            List<QuoteDashboardData> QuoteDashboardDate = new();

            using (SqlConnection connection = CreateConnection())
            {
                await connection.OpenAsync();

                string statement = "SELECT * FROM SSop.tvf_Quotes(@UserId)";

                using var command = new SqlCommand(statement, connection);

                command.Parameters.Add(new SqlParameter("@UserId", UserId));

                try
                {
                    using var reader = await command.ExecuteReaderAsync();

                    while (await reader.ReadAsync())
                    {
                        var quote = new QuoteDashboardData
                        {
                            QuoteID = reader.GetInt32(reader.GetOrdinal("ID")),
                            QuoteNumber = reader.GetString(reader.GetOrdinal("Number")),
                            Guid = reader.GetGuid(reader.GetOrdinal("Guid")).ToString(),
                            Date = reader.GetDateTime(reader.GetOrdinal("Date")),
                            Status = reader.GetString(reader.GetOrdinal("QuoteStatus")),
                            Client = reader.GetString(reader.GetOrdinal("Client")),
                            QuoteType = reader.GetString(reader.GetOrdinal("JobType")),
                            QuoteValue = reader.GetDecimal(reader.GetOrdinal("TotalNet"))
                        };

                        QuoteDashboardDate.Add(quote);
                    }

                    return QuoteDashboardDate;
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetNonActivityEvents: {ex.Message}", ex);
                }
            }
        }

        /// <summary>
        /// Returns the threshold / business unit.
        /// </summary>
        /// <param name="_UserId"> </param>
        /// <returns> The threshold itself (for quotes) as a double. </returns>
        /// <exception cref="Exception"> </exception>
        public async Task<double> GetThresholdsForOrgUnit(int _UserId)
        {
            double Threshold = 0;

            using (SqlConnection connection = CreateConnection())
            {
                await connection.OpenAsync();

                string statement = "SELECT QuoteThreshold FROM SCore.tvf_GetThresholdsForOrgUnit(@UserID)";

                using var command = new SqlCommand(statement, connection);

                command.Parameters.Add(new SqlParameter("@UserID", _UserId));

                try
                {
                    using var reader = await command.ExecuteReaderAsync();

                    while (await reader.ReadAsync())
                    {
                        Threshold = (double)reader.GetDecimal(reader.GetOrdinal("QuoteThreshold"));
                    }

                    return Threshold;
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting Quote Threshold: {ex.Message}", ex);
                }
            }
        }

        public async Task<List<string>> GetInvoiceRequestItemsByGuid(int _UserId, string InvoiceReqGuid)
        {
            List<string> InvoiceReqItemsGuid = new List<string>();

            using (SqlConnection connection = CreateConnection())
            {
                await connection.OpenAsync();

                string statement = "SELECT Guid FROM  SFin.tvf_InvoiceRequestItems(@UserID, @ParentGuid)";

                using var command = new SqlCommand(statement, connection);

                command.Parameters.Add(new SqlParameter("@UserID", _UserId));
                command.Parameters.Add(new SqlParameter("@ParentGuid", InvoiceReqGuid));

                try
                {
                    using var reader = await command.ExecuteReaderAsync();

                    while (await reader.ReadAsync())
                    {
                        InvoiceReqItemsGuid.Add(reader.GetGuid(reader.GetOrdinal("Guid")).ToString());
                    }

                    return InvoiceReqItemsGuid;
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting Quote Threshold: {ex.Message}", ex);
                }
            }
        }

        public async Task<bool> MarkInvoiceRequestAsMerged(string InvoiceReqGuid)
        {
            using (var connection = CreateConnection())  // same helper you already use
            {
                await OpenConnectionAsync(connection);

                using (var command = new SqlCommand("[SFin].[InvoiceRequestsMarkAsMerged]", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.AddWithValue("@Guid", InvoiceReqGuid);


                    try
                    {
                        await command.ExecuteNonQueryAsync();

                        return true;
                    }
                    catch (Exception ex)
                    {
                        // Include the SQL command for logging consistency
                        ex.Data["SQL"] = $"[SFin].[InvoiceRequestsMarkAsMerged] @Guid = @Guid";
                        throw new Exception($"Error executing [SFin].[InvoiceRequestsMarkAsMerged]: {ex.Message}", ex);
                    }

                }


            }
        }

        public async Task<List<PublicHoliday>> GetBankHolidays()
        {
            List<PublicHoliday> publicHolidays = new();

            using (SqlConnection connection = CreateConnection())
            {
                await connection.OpenAsync();

                string statement = "SELECT * FROM SCore.BankHolidaysUK WHERE IsBankHoliday = 1 AND (Region IN ('Northern Ireland','UK','Scotland')) ORDER BY DATE";

                using var command = new SqlCommand(statement, connection);
                try
                {
                    using var reader = await command.ExecuteReaderAsync();

                    while (await reader.ReadAsync())
                    {
                        publicHolidays.Add(new PublicHoliday
                        {
                            ID = reader.GetInt32(reader.GetOrdinal("ID")),
                            Date = reader.GetDateTime(reader.GetOrdinal("Date")),
                            DayName = reader.GetString(reader.GetOrdinal("DayName")),
                            MonthName = reader.GetString(reader.GetOrdinal("MonthName")),
                            YearInWords = reader.GetString(reader.GetOrdinal("YearInWords")),
                            FormattedDate = reader.GetString(reader.GetOrdinal("FormattedDate")),
                            HolidayName = reader.GetString(reader.GetOrdinal("HolidayName")),
                            IsBankHoliday = reader.GetBoolean(reader.GetOrdinal("IsBankHoliday")),
                            Region = reader.GetString(reader.GetOrdinal("Region")),
                            FiscalQuarter = reader.GetByte(reader.GetOrdinal("FiscalQuarter")),
                            FiscalYear = reader.GetInt16(reader.GetOrdinal("FiscalYear")),
                            DayOfYear = reader.GetInt16(reader.GetOrdinal("DayOfYear")), //TinyINT
                            WeekOfYear = reader.GetByte(reader.GetOrdinal("WeekOfYear")) //TinyINT
                        });
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetBankHolidays: {ex.Message}", ex);
                }
                return publicHolidays;
            }
        }

        public ClaimsPrincipal GetClaimsPrincipal()
        {
            return _claimsPrincipal;
        }

        public async Task<int> GetCurrentUserId(SqlConnection connection)
        {
            if (_userId == -1 && _userName != "" && _userName != null)
            {
                string statement;

                statement = "SELECT i.Id " +
                    "FROM SCore.Identities i " +
                    "WHERE i.EmailAddress = @UserEmail";

                using (var command = connection.CreateCommand())
                {
                    command.CommandText = statement;
                    command.Parameters.Add(new SqlParameter("@UserEmail", _userName.ToLower()));

                    var result = await command.ExecuteScalarAsync();

                    if (result is null)
                    {
                        /*var azureAppConfig = _configuration.GetSection("AzureAd");
                        var clientId = azureAppConfig.GetValue<string>("ClientId");
                        var tenantId = azureAppConfig.GetValue<string>("TenantId");
                        var clientSecret = azureAppConfig.GetValue<string>("ClientSecret");

                        GraphServiceClient graphClient;

                        var clientSecretCredential = new ClientSecretCredential(tenantId, clientId, clientSecret);
                        graphClient = new(clientSecretCredential);

                        var userRecord = await graphClient.Users[identityName]
                                .GetAsync();

                        if (userRecord != null) {
                            string createIdentityStatement = $@"EXECUTE SCore.UserCreate @EmailAddress = @EmailAddress, @FullName = @FullName, @FirstName = @FirstName, @LastName = @LastName, @MobileNo = @MobileNo, @IdentityID = @IdentityID OUT";

                            using (var command2 = connection.CreateCommand())
                            {
                                command2.CommandText = createIdentityStatement;
                                command2.Parameters.Add(new SqlParameter("@EmailAddress", userRecord.UserPrincipalName));
                                command2.Parameters.Add(new SqlParameter("@FullName", userRecord.DisplayName));
                                command2.Parameters.Add(new SqlParameter("@FirstName", userRecord.GivenName));
                                command2.Parameters.Add(new SqlParameter("@LastName", userRecord.Surname));
                                command2.Parameters.Add(new SqlParameter("@MobileNo", userRecord.MobilePhone));

                                SqlParameter identityId = new SqlParameter("@IdentityId", 0)
                                {
                                    Direction = System.Data.ParameterDirection.Output
                                };

                                command2.Parameters.Add(identityId);

                                await command2.ExecuteNonQueryAsync();

                                _userId = int.Parse(identityId.Value.ToString() ?? "0");
                            }
                        }*/
                    }
                    else
                    {
                        _userId = int.Parse(result.ToString() ?? "0");
                    }
                }
            }

            return _userId;
        }

        public async Task<object?> GetEntityPropertyDefault(EntityProperty entityProperty, Guid ParentGuid, Guid RecordGuid)
        {
            // 1) If there’s a fixed default, just return it
            if (!string.IsNullOrEmpty(entityProperty.FixedDefaultValue))
                return entityProperty.FixedDefaultValue;

            // 2) If there’s a SQL default, execute it with parameters
            if (!string.IsNullOrEmpty(entityProperty.SqlDefaultValueStatement))
            {
                SqlConnection? connection = null;
                try
                {
                    connection = CreateConnection();
                    await OpenConnectionAsync(connection);
                    await QueryBuilder.SetReadCommittedAsync(connection); // safe default for reads

                    // Raw text as stored (may still contain [[UserId]], [[ParentGuid]], etc.)
                    string sql = entityProperty.SqlDefaultValueStatement;

                    // Bind [[...]] tokens into @params (adds SqlParameter objects for any tokens found)
                    var bound = Core.BindStandardTokens(
                        sql,
                        currentUserId: _userId,
                        userId: _userId,
                        parentGuid: ParentGuid,
                        recordGuid: RecordGuid
                    ); // :contentReference[oaicite:1]{index=1}

                    using (var command = QueryBuilder.CreateCommand(bound.Sql, connection)) // :contentReference[oaicite:2]{index=2}
                    {
                        // Add parameters generated from the [[...]] tokens
                        command.Parameters.AddRange(QueryBuilder.CloneParams(bound.Params.ToArray()));

                        // Also support SQL that has already been changed to use
                        // @UserId/@ParentGuid/@RecordGuid directly
                        void AddIfMissing(string name, object? value)
                        {
                            if (value is null) return;
                            // Only add if the SQL references this name and it isn't already supplied
                            if (command.CommandText.IndexOf(name, StringComparison.OrdinalIgnoreCase) >= 0 &&
                                !command.Parameters.Contains(name))
                            {
                                command.Parameters.Add(new SqlParameter(name, value));
                            }
                        }
                        AddIfMissing("@UserId", _userId);
                        AddIfMissing("@CURRENT_USER_ID", _userId);
                        AddIfMissing("@ParentGuid", ParentGuid);
                        AddIfMissing("@RecordGuid", RecordGuid);

                        try
                        {
                            return await command.ExecuteScalarAsync();
                        }
                        catch (Exception ex)
                        {
                            // include the parameterized SQL for diagnostics
                            ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                            throw new Exception($"Exception occurred getting GetEntityPropertyDefault: {ex.Message}", ex);
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"Error in GetEntityPropertyDefault: {ex.Message}");
                    throw; // bubble up
                }
                finally
                {
                    if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                        connection.Close();
                    connection?.Dispose();
                }
            }

            return null;
        }

        public async Task<EntityType> GetEntityType(Guid guid, bool forRead, bool forWrite, bool forProcessingOnly = false, bool forInformationView = false, bool getEntityQueries = false)
        {
            SqlConnection? connection = null;
            try
            {
                connection = CreateConnection();
                await OpenConnectionAsync(connection);

                return await GetEntityType(guid, connection, _userId, forRead, forWrite, forProcessingOnly, forInformationView, getEntityQueries);
            }
            finally
            {
                // Ensure the connection is always closed and disposed
                if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                {
                    connection.Close();
                }
                connection?.Dispose();
            }
        }

        public async Task<DataTable> GetEntityTypeRows(EntityQuery? defaultQuery, string parentGuid)
        {
            // retrieve the records of an EntityType using the defaultQuery and appending a Where
            // clause to filter by the parentGuid
            string query = defaultQuery.Statement + " WHERE [root_hobt].[ParentGuid] = @ParentGuid";

            using (SqlConnection connection = new(_connectionString))
            {
                await connection.OpenAsync();

                using (SqlCommand command = new(query, connection))
                {
                    command.Parameters.AddWithValue("@ParentGuid", parentGuid);

                    try
                    {
                        using (SqlDataReader reader = await command.ExecuteReaderAsync())
                        {
                            DataTable dataTable = new();
                            dataTable.Load(reader);
                            return dataTable;
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting GetEntityTypeRows: {ex.Message}", ex);
                    }
                }
            }
        }

        public async Task<System.IO.MemoryStream> GetFileStreamData(Guid EntityProperty, Guid RecordGuid)
        {
            System.IO.MemoryStream stream = new System.IO.MemoryStream();

            using (SqlConnection sqlConnection = new(_connectionString))
            {
                await sqlConnection.OpenAsync();

                string propertyName = "";
                string objectName = "";
                string schemaName = "";
                string path = "";
                byte[]? transactionContext = Array.Empty<byte>();

                string statement = "SELECT p.Name, h.SchemaName, h.ObjectName from SCore.EntityPropertiesV p JOIN SCore.EntityHobtsV h on (p.HoBTID = h.ID) WHERE (p.Guid = @Guid)";

                using (SqlCommand command = new SqlCommand(statement, sqlConnection))
                {
                    command.Parameters.Add(new SqlParameter("@Guid", EntityProperty));

                    using (SqlDataReader reader = command.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            propertyName = reader.GetString(reader.GetOrdinal("Name"));
                            objectName = reader.GetString(reader.GetOrdinal("ObjectName"));
                            schemaName = reader.GetString(reader.GetOrdinal("SchemaName"));
                        }
                    }
                }

                string statement2 = $"SELECT {propertyName}.PathName(), GET_FILESTREAM_TRANSACTION_CONTEXT() FROM [{schemaName}].[{objectName}]";

                using (SqlTransaction sqlTransaction = sqlConnection.BeginTransaction(IsolationLevel.ReadCommitted))
                {
                    using (SqlCommand command = new SqlCommand(statement2, sqlConnection, sqlTransaction))
                    {
                        using (SqlDataReader reader = command.ExecuteReader())
                        {
                            while (reader.Read())
                            {
                                // Get the pointer for file
                                path = reader.GetString(0);
                                transactionContext = reader.GetSqlBytes(1).Buffer;

                                using (Stream fileStream = new SqlFileStream(path, transactionContext, FileAccess.Read, FileOptions.SequentialScan, allocationSize: 0))
                                {
                                    fileStream.CopyTo(stream);
                                }
                            }
                        }
                    }

                    sqlTransaction.Commit();
                }
            }

            return stream;
        }

        //CBLD-405
        public async Task<JobType> GetJobType(string _jobTypeGuid)
        {
            JobType jobType = new();
            using (SqlConnection connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string securityStatement = "SELECT * FROM SCore.tvf_JobTypeGet(@JobTypeGuid);";

                using (SqlCommand command = QueryBuilder.CreateCommand(securityStatement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@JobTypeGuid", _jobTypeGuid));
                    try
                    {
                        using (SqlDataReader reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                jobType = new()
                                {
                                    Name = reader.GetString(reader.GetOrdinal("Name")),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                    IsActive = reader.GetBoolean(reader.GetOrdinal("IsActive")),
                                    SequenceID = reader.GetInt32(reader.GetOrdinal("SequenceID")),
                                    UseTimeSheets = reader.GetBoolean(reader.GetOrdinal("UseTimeSheets")),
                                    UserPlanChecks = reader.GetBoolean(reader.GetOrdinal("UsePlanChecks")),
                                    OrganisationalUnitGuid = reader.GetGuid(reader.GetOrdinal("OrganisationalUnitGuid"))
                                };
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting GetJobType: {ex.Message}", ex);
                    }
                }
            }

            return jobType;
        }

        public async Task<EF.Types.MergeDocument> GetMergeDocumentByGuid(Guid guid)
        {
            var mergeDocument = new EF.Types.MergeDocument();

            // SQL query to retrieve data with a placeholder for Guid
            string sql = @"SELECT * FROM SCore.MergeDocuments WHERE Guid = @Guid";

            try
            {
                // Create and open the connection
                using (var connection = CreateConnection())
                {
                    await OpenConnectionAsync(connection);

                    using (var command = connection.CreateCommandWithParameters(sql, CommandType.Text,
                               new SqlParameter("@Guid", guid)))
                    {
                        try
                        {
                            using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
                            if (await reader.ReadAsync().ConfigureAwait(false))
                            {
                                mergeDocument = MapMergeDocument(reader);
                            }
                        }
                        catch (Exception ex)
                        {
                            // Attach the SQL query to the exception data so the API logger can pick
                            // it up
                            ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                            throw new Exception($"Exception occurred getting GetMergeDocumentByGuid: {ex.Message}", ex);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                // Log and rethrow the exception
                throw new Exception("Failed to retrieve MergeDocument by Guid.", ex);
            }

            return mergeDocument;
        }

        public async Task<MergeDocument> GetMergeDocumentForItemIncludeByGuid(Guid guid)
        {
            var mergeDocument = new MergeDocument();

            Console.WriteLine($"GUID: {guid}");

            // SQL query to retrieve data with a placeholder for Guid
            string sql = @"SELECT * FROM SCore.tvf_MergeDocumentForItemInclude(@Guid)";

            try
            {
                // Create and open the connection
                using (var connection = CreateConnection())
                {
                    await OpenConnectionAsync(connection);

                    using (var command = connection.CreateCommandWithParameters(sql, CommandType.Text,
                               new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = guid }))
                    {
                        try
                        {
                            using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
                            if (await reader.ReadAsync().ConfigureAwait(false))
                            {
                                mergeDocument = MapMergeDocument(reader);
                            }
                        }
                        catch (Exception ex)
                        {
                            // Attach the SQL query to the exception data so the API logger can pick
                            // it up
                            ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                            throw new Exception($"Exception occurred getting GetMergeDocumentForItemIncludeByGuid: {ex.Message}", ex);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}, StackTrace: {ex.StackTrace}");
                throw new Exception("Failed to retrieve MergeDocument by Guid.", ex);
            }

            return mergeDocument;
        }

        public async Task<List<EF.Types.MergeDocumentItemInclude>> GetMergeDocumentItemIncludes(Guid parentGuid, int userId)
        {
            var mergeDocumentItemIncludes = new List<EF.Types.MergeDocumentItemInclude>();

            // SQL to call the TVF
            string sql = @"SELECT * FROM SCore.tvf_MergeDocumentItemIncludes(@UserId, @ParentGuid)";

            try
            {
                // Create and open the connection
                using (var connection = CreateConnection())
                {
                    await OpenConnectionAsync(connection);

                    using (var command = connection.CreateCommandWithParameters(sql, CommandType.Text,
                               new SqlParameter("@UserId", userId),
                               new SqlParameter("@ParentGuid", parentGuid)))
                    {
                        try
                        {
                            using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
                            while (await reader.ReadAsync().ConfigureAwait(false))
                            {
                                var mergeDocumentItemInclude = MapMergeDocumentItemInclude(reader);
                                mergeDocumentItemIncludes.Add(mergeDocumentItemInclude);
                            }
                        }
                        catch (Exception ex)
                        {
                            // Attach the SQL query to the exception data so the API logger can pick
                            // it up
                            ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                            throw new Exception($"Exception occurred getting GetMergeDocumentItemIncludes: {ex.Message}", ex);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                // Log and rethrow the exception
                throw new Exception("Failed to retrieve MergeDocumentItemIncludes using TVF.", ex);
            }

            return mergeDocumentItemIncludes;
        }

        public async Task<List<EF.Types.MergeDocumentItem>> GetMergeDocumentItems(Guid parentGuid, int userId)
        {
            var mergeDocumentItems = new List<EF.Types.MergeDocumentItem>();

            // SQL to call the TVF
            string sql = @"SELECT * FROM SCore.tvf_MergeDocumentItems(@UserId, @ParentGuid)";

            try
            {
                // Create and open the connection
                using (var connection = CreateConnection())
                {
                    await OpenConnectionAsync(connection);

                    using (var command = connection.CreateCommandWithParameters(sql, CommandType.Text,
                               new SqlParameter("@UserId", userId),
                               new SqlParameter("@ParentGuid", parentGuid)))
                    {
                        try
                        {
                            using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
                            while (await reader.ReadAsync().ConfigureAwait(false))
                            {
                                var mergeDocumentItem = MapMergeDocumentItem(reader);
                                mergeDocumentItems.Add(mergeDocumentItem);
                            }
                        }
                        catch (Exception ex)
                        {
                            // Attach the SQL query to the exception data so the API logger can pick
                            // it up
                            ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                            throw new Exception($"Exception occurred getting GetMergeDocumentItems: {ex.Message}", ex);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                // Log the exception
                throw new Exception("Failed to retrieve MergeDocumentItems using tvf_MergeDocumentItems.", ex);
            }

            return mergeDocumentItems;
        }

        public async Task<List<EF.Types.MergeDocumentItemType>> GetMergeDocumentItemTypes(int userId)
        {
            var mergeDocumentItemTypes = new List<EF.Types.MergeDocumentItemType>();

            // SQL query to retrieve data with a placeholder for UserId (optional filtering)
            string sql = @"SELECT ID, Guid, RowStatus, RowVersion, Name, IsImageType
                   FROM SCore.MergeDocumentItemTypes
                   WHERE RowStatus NOT IN (0, 254)";

            try
            {
                // Create and open the connection
                using (var connection = CreateConnection())
                {
                    await OpenConnectionAsync(connection);

                    using (var command = connection.CreateCommandWithParameters(sql, CommandType.Text,
                               new SqlParameter("@UserId", userId)))
                    {
                        try
                        {
                            using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
                            while (await reader.ReadAsync().ConfigureAwait(false))
                            {
                                var mergeDocumentItemType = MapMergeDocumentItemType(reader);
                                mergeDocumentItemTypes.Add(mergeDocumentItemType);
                            }
                        }
                        catch (Exception ex)
                        {
                            // Attach the SQL query to the exception data so the API logger can pick
                            // it up
                            ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                            throw new Exception($"Exception occurred getting GetMergeDocumentItemTypes: {ex.Message}", ex);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                throw new Exception("Failed to retrieve MergeDocumentItemTypes.", ex);
            }

            return mergeDocumentItemTypes;
        }

        //As this method is rather slow perhaps we can call it only when needed and remove it from PopulateAdditionalDetails?
        public async Task<List<MergeDocument>> GetMergeDocuments(Guid entityTypeGuid, Guid objectGuid)
        {
            using var c = CreateConnection();
            await OpenConnectionAsync(c);
            await QueryBuilder.SetReadCommittedAsync(c);

            var entityType = await GetEntityTypeCached(entityTypeGuid, c, _userId,
                forRead: true, forWrite: false, forProcessingOnly: true, includeEntityQueries: false);

            return await ReadMergeDocumentsWithChildren(entityType, c, null);
        }

        public async Task<List<NonActivityEvents>> GetNonActivityEvents(int UserId, DateTime StartDate, DateTime EndDate)
        {
            List<NonActivityEvents> nonActivityEvents = new();

            using (SqlConnection connection = CreateConnection())
            {
                await connection.OpenAsync();

                string statement = "SELECT * FROM SCore.tvf_GetScheduledAbsences(@UserId, @StartDate, @EndDate)";

                using var command = new SqlCommand(statement, connection);

                command.Parameters.Add(new SqlParameter("@UserId", UserId));
                command.Parameters.Add(new SqlParameter("@StartDate", StartDate));
                command.Parameters.Add(new SqlParameter("@EndDate", EndDate));
                try
                {
                    using var reader = await command.ExecuteReaderAsync();

                    while (await reader.ReadAsync())
                    {
                        var nonActivity = new NonActivityEvents
                        {
                            ID = reader.GetInt32(reader.GetOrdinal("ID")),
                            EventName = reader.GetString(reader.GetOrdinal("Name")),
                            StartTime = reader.GetDateTime(reader.GetOrdinal("StartTime")),
                            EndTime = reader.GetDateTime(reader.GetOrdinal("EndTime")),
                            TeamId = reader.GetInt32(reader.GetOrdinal("TeamGroupId")),
                            MemberId = reader.GetInt32(reader.GetOrdinal("MemberIdentityId")),
                            Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                            AbsenceTypeID = reader.GetInt32(reader.GetOrdinal("AbsenceTypeID"))
                        };

                        nonActivityEvents.Add(nonActivity);
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetNonActivityEvents: {ex.Message}", ex);
                }
            }

            return nonActivityEvents;
        }

        public async Task<OrganisationUnitForUser> GetOrganisationUnitForUsers(int UserId)
        {
            OrganisationUnitForUser orgUnit = new();

            using (SqlConnection connection = CreateConnection())
            {
                await connection.OpenAsync();

                string statement = $"SELECT OriganisationalUnitId FROM SCore.tvf_GetOrgUnitByUser(@UserId)";

                using var command = new SqlCommand(statement, connection);
                command.Parameters.Add(new SqlParameter("@UserId", UserId));
                try
                {
                    using var reader = await command.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        orgUnit.OrganisationUnitId = reader.GetInt32(reader.GetOrdinal("OriganisationalUnitId"));
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetOrganisationUnitForUsers: {ex.Message}", ex);
                }
            }

            return orgUnit;
        }

        public async Task<List<ScheduledActivity>> GetScheduledActivities(int UserId, DateTime StartDate, DateTime EndDate)
        {
            List<ScheduledActivity> ScheduledActivities = new();

            using (SqlConnection connection = CreateConnection())
            {
                await connection.OpenAsync();

                string statement = $"SELECT * FROM  SCore.tvf_GetScheduledActivities(@UserId, @StartDate, @EndDate)";

                using var command = new SqlCommand(statement, connection);
                command.Parameters.Add(new SqlParameter("@UserId", UserId));
                command.Parameters.Add(new SqlParameter("@StartDate", StartDate));
                command.Parameters.Add(new SqlParameter("@EndDate", EndDate));
                try
                {
                    using var reader = await command.ExecuteReaderAsync();

                    while (await reader.ReadAsync())
                    {
                        ScheduledActivities.Add(new ScheduledActivity
                        {
                            UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
                            StartDate = reader.GetDateTime(reader.GetOrdinal("StartDate")),
                            EndDate = reader.GetDateTime(reader.GetOrdinal("EndDate")),
                            Title = reader.GetString(reader.GetOrdinal("Title")),
                            JobNumber = reader.GetString(reader.GetOrdinal("JobNumber")),
                            Note = reader.GetString(reader.GetOrdinal("Note"))
                        });
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetScheduleActivities: {ex.Message}", ex);
                }

                return ScheduledActivities;
            }
        }

        public async Task<List<SharePointDetail>> GetSharePointDetailsForObject(DataObject dataObject)
        {
            var result = new List<SharePointDetail>();
            long? parentObjectId = -1;

            await using var connection = CreateConnection();
            await OpenConnectionAsync(connection);

            // Retrieve entity type
            var entityType = await GetEntityType(dataObject.EntityTypeGuid, connection, _userId, forRead: true, forWrite: false, forProcessingOnly: true, forInformationView: false, includeEntityQueries: true);

            if (!entityType.IsRootEntity)
            {
                // Identify parent column and corresponding EntityHoBT
                var parentColumn = entityType.EntityProperties.FirstOrDefault(p => p.IsParentRelationship);
                if (parentColumn != null)
                {
                    var parentEntityHoBT = entityType.EntityHoBTs.FirstOrDefault(h => h.Guid == parentColumn.EntityHoBTGuid);
                    if (parentEntityHoBT != null)
                    {
                        // Query parent object ID
                        var parentQuery = $"SELECT [{parentColumn.Name}] FROM [{parentEntityHoBT.SchemaName}].[{parentEntityHoBT.ObjectName}] WHERE ([Guid] = @Guid)";

                        // Use a fresh command instance
                        await using (var parentCommand = new SqlCommand(parentQuery, connection))
                        {
                            parentCommand.Parameters.Clear();
                            parentCommand.Parameters.Add(new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = dataObject.Guid });

                            var parentResult = await parentCommand.ExecuteScalarAsync();
                            if (parentResult != null && parentResult != DBNull.Value)
                            {
                                parentObjectId = long.Parse(parentResult.ToString());
                            }
                            else
                            {
                                parentObjectId = -1; // Fallback default
                            }
                        }
                    }
                }
            }

            // Query SharePoint details
            const string sharePointQuery = "SELECT * FROM [SCore].[tvf_GetSharePointDetailsForObject] (@EntityTypeGuid, @ObjectID, @ParentObjectID)";
            await using (var sharePointCommand = new SqlCommand(sharePointQuery, connection))
            {
                sharePointCommand.Parameters.Clear();
                sharePointCommand.Parameters.Add(new SqlParameter("@EntityTypeGuid", SqlDbType.UniqueIdentifier) { Value = dataObject.EntityTypeGuid });
                sharePointCommand.Parameters.Add(new SqlParameter("@ObjectID", SqlDbType.BigInt) { Value = dataObject.DatabaseId });
                sharePointCommand.Parameters.Add(new SqlParameter("@ParentObjectID", SqlDbType.BigInt) { Value = parentObjectId ?? -1 });
                try
                {
                    await using var reader = await sharePointCommand.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        result.Add(new SharePointDetail
                        {
                            Name = reader.GetString(reader.GetOrdinal("Name")),
                            ParentName = reader.GetString(reader.GetOrdinal("ParentName")),
                            ParentObjectId = reader.GetInt64(reader.GetOrdinal("ParentObjectId")),
                            ParentPrimaryKeySplitInterval = reader.GetInt32(reader.GetOrdinal("ParentPrimaryKeySplitInterval")),
                            ParentUseLibraryPerSplit = reader.GetBoolean(reader.GetOrdinal("ParentUseLibraryPerSplit")),
                            ParentStructureId = reader.GetInt32(reader.GetOrdinal("ParentStructureId")),
                            PrimaryKeySplitInterval = reader.GetInt32(reader.GetOrdinal("PrimaryKeySplitInterval")),
                            SiteIdentifier = reader.GetString(reader.GetOrdinal("SiteIdentifier")),
                            UseLibraryPerSplit = reader.GetBoolean(reader.GetOrdinal("UseLibraryPerSplit"))
                        });
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(sharePointCommand.CommandText, sharePointCommand.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetSharePointDetailsForObject: {ex.Message}", ex);
                }
            }

            return result;
        }

        public async Task<string> GetSharepointSiteIdentifier(Guid sharepointSite)
        {
            string rsl = "";

            using (SqlConnection connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string sqlStatement = $"SELECT SiteIdentifier FROM [SCore].[SharePointSites] WHERE ([Guid] = @Guid)";

                using (SqlCommand command = QueryBuilder.CreateCommand(sqlStatement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@Guid", sharepointSite));

                    using (SqlDataReader reader = command.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            rsl = reader.GetString(0);
                        }
                    }
                }
            }

            return rsl;
        }

        public async Task<List<SignatureInfo>> GetSignatoryInfo(
    Guid JobGuid = default,
    Guid QuoteGuid = default,
    Guid EnquiryGuid = default)
        {
            List<SignatureInfo> result = new();
            string columnName = null;
            Guid objectGuid = default;

            // Determine which Guid to use (priority: Job > Quote > Enquiry)
            if (JobGuid != default)
            {
                columnName = "JobGuid";
                objectGuid = JobGuid;
            }
            else if (QuoteGuid != default)
            {
                columnName = "QuoteGuid";
                objectGuid = QuoteGuid;
            }
            else if (EnquiryGuid != default)
            {
                columnName = "EnquiryGuid";
                objectGuid = EnquiryGuid;
            }
            else
            {
                // Return empty list if no valid Guid is provided
                Console.WriteLine("[ERROR] No valid Guid provided.");
                return result;
            }

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);
                string query = $"SELECT * FROM [SJob].[GetJobSignatoryInfo] WHERE {columnName} = @ObjectGuid";
                using (var command = QueryBuilder.CreateCommand(query, connection))
                {
                    command.Parameters.Add(new SqlParameter("@ObjectGuid", objectGuid));
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                var signatureInfo = new SignatureInfo
                                {
                                    EmailAddress = reader.GetString(reader.GetOrdinal("EmailAddress")),
                                    FullName = reader.GetString(reader.GetOrdinal("FullName")),
                                    JobGuid = reader.GetGuid(reader.GetOrdinal("JobGuid")),
                                    EnquiryGuid = reader.GetGuid(reader.GetOrdinal("EnquiryGuid")),
                                    QuoteGuid = reader.GetGuid(reader.GetOrdinal("QuoteGuid")),
                                    IsActive = reader.GetBoolean(reader.GetOrdinal("IsActive")),
                                    JobTitle = reader.GetString(reader.GetOrdinal("JobTitle")),
                                    JobTypeName = reader.GetString(reader.GetOrdinal("JobTypeName")),
                                    Signature = reader.IsDBNull(reader.GetOrdinal("BinarySignature"))
                                            ? Array.Empty<byte>()
                                            : reader.GetFieldValue<byte[]>(reader.GetOrdinal("BinarySignature")),
                                    UserGuid = reader.GetGuid(reader.GetOrdinal("UserGuid"))
                                };
                                result.Add(signatureInfo);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting GetSignatoryInfo: {ex.Message}", ex);
                    }
                }
            }
            return result;
        }

        public async Task<List<TeamMember>> GetTeamMembersAsync(int organisationalUnitId)
        {
            var team = new List<TeamMember>();

            using (SqlConnection connection = new(_connectionString))
            {
                await connection.OpenAsync();

                using (SqlCommand command = connection.CreateCommand())
                {
                    command.CommandText = "SELECT * FROM [SCore].[tvf_GetTeamMembersByUnit](@OrganisationalUnitId)";
                    command.CommandType = CommandType.Text;

                    var param = command.CreateParameter();
                    param.ParameterName = "@OrganisationalUnitId";
                    param.Value = organisationalUnitId;
                    command.Parameters.Add(param);

                    try
                    {
                        using var reader = await command.ExecuteReaderAsync();
                        while (await reader.ReadAsync())
                        {
                            team.Add(new TeamMember
                            {
                                IdentityId = (int?)reader["IdentityId"] ?? -1,
                                Guid = CommonFunctions.ParseAndReturnEmptyGuidIfInvalid(reader["Guid"].ToString()),
                                FullName = reader["FullName"].ToString() ?? "",
                                Color = "#328ca8" //GenerateColorFromGuid(CommonFunctions.ParseAndReturnEmptyGuidIfInvalid(reader["Guid"].ToString()).ToString() ?? "")
                            });
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting GetTeamMembersAsync: {ex.Message}", ex);
                    }
                }
            }

            return team;
        }

        public async Task<List<UsageData>> GetUsageReport(DateTime startDateUtc, DateTime endDateUtc, string userGuid = "")
        {
            List<UsageData> report = new();

            using (SqlConnection connection = CreateConnection())
            {
                await connection.OpenAsync();

                string statement = @"
SELECT Username, FeatureName, UsageCount, WeeklyAverage,
       FORMAT(FirstAccessed, 'dd-MM-yyyy HH:mm:ss') AS FirstAccessed,
       FORMAT(LastAccessed, 'dd-MM-yyyy HH:mm:ss') AS LastAccessed
FROM SCore.SystemUsageStatistics
WHERE LastAccessed BETWEEN @StartDate AND @EndDate"
                + (string.IsNullOrEmpty(userGuid) ? "" : " AND UserGuid = @UserGuid") +
                " ORDER BY UsageCount DESC;";

                Console.WriteLine($"Executing SQL Query: {statement}");
                Console.WriteLine($"Start: {startDateUtc:O}, End: {endDateUtc:O}, UserGuid: {userGuid}");

                using var command = new SqlCommand(statement, connection);
                command.Parameters.Add(new SqlParameter("@StartDate", startDateUtc));
                command.Parameters.Add(new SqlParameter("@EndDate", endDateUtc));
                if (!string.IsNullOrEmpty(userGuid))
                    command.Parameters.Add(new SqlParameter("@UserGuid", userGuid));

                try
                {
                    using var reader = await command.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        report.Add(new UsageData
                        {
                            Username = reader.IsDBNull(0) ? "Unknown" : reader.GetString(0),
                            FeatureName = reader.IsDBNull(1) ? "Unknown" : reader.GetString(1),
                            UsageCount = reader.GetInt32(2),
                            WeeklyAverage = reader.GetInt32(3),
                            FirstAccessed = reader.IsDBNull(4) ? "N/A" : reader.GetString(4),
                            LastAccessed = reader.IsDBNull(5) ? "N/A" : reader.GetString(5)
                        });
                    }
                    return report;
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetUsageReport: {ex.Message}", ex);
                }
            }
        }

        // Get User record by Guid from SCore.Identities
        public async Task<User> GetUserByGuid(Guid guid)
        {
            if (guid == Guid.Empty)
            {
                throw new ArgumentException("No Guid provided. Please ensure you select a valid user.", nameof(guid));
            }

            await using var connection = CreateConnection();
            await OpenConnectionAsync(connection);

            const string sqlStatement = @"
        SELECT
            i.ID AS UserId,
            i.EmailAddress AS Email,
            N'' AS FirstName,
            N'' AS Surname,
            N'' AS Mobile,
            i.JobTitle,
            i.BillableRate,
            i.Signature
        FROM
            SCore.Identities i
        WHERE
            Guid = @Guid";

            await using var command = QueryBuilder.CreateCommand(sqlStatement, connection);
            command.Parameters.Add(new SqlParameter("@Guid", guid));
            try
            {
                await using var reader = await command.ExecuteReaderAsync();
                if (await reader.ReadAsync())
                {
                    return new User
                    {
                        Email = reader.GetString(reader.GetOrdinal("Email")),
                        UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
                        FirstName = reader.GetString(reader.GetOrdinal("FirstName")),
                        LastName = reader.GetString(reader.GetOrdinal("Surname")),
                        MobileNo = reader.GetString(reader.GetOrdinal("Mobile")),
                        JobTitle = reader.GetString(reader.GetOrdinal("JobTitle")),
                        BillableRate = reader.GetDecimal(reader.GetOrdinal("BillableRate")),
                        Signature = reader.IsDBNull(reader.GetOrdinal("Signature"))
                            ? Array.Empty<byte>()
                            : reader.GetFieldValue<byte[]>(reader.GetOrdinal("Signature")),
                        OnHoliday = false,
                    };
                }
            }
            catch (Exception ex)
            {
                // Attach the SQL query to the exception data so the API logger can pick it up
                ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                throw new Exception($"Exception occurred getting GetUserByGuid: {ex.Message}", ex);
            }
            throw new KeyNotFoundException("User with the specified Guid was not found.");
        }

        public async Task<User> GetUserInfo(Guid userGuid, string username)
        {
            if (string.IsNullOrWhiteSpace(username) && userGuid == Guid.Empty)
            {
                throw new ArgumentException("No Username or Guid provided. Please provide at least one identifier.", nameof(username));
            }

            User? user = null;

            await using var connection = CreateConnection();
            await OpenConnectionAsync(connection);

            const string selectStatement = @"
SELECT
    i.ID AS UserId,
    i.EmailAddress AS Email,
    N'' AS FirstName,
    N'' AS Surname,
    N'' AS Mobile,
    i.JobTitle,
    i.BillableRate,
    i.Signature
FROM
    SCore.Identities i
WHERE
    i.EmailAddress = @UserEmail OR i.Guid = @UserGuid";

            await using var command = QueryBuilder.CreateCommand(selectStatement, connection);

            command.Parameters.Add(new SqlParameter("@UserEmail", (object?)username?.ToLower() ?? ""));
            command.Parameters.Add(new SqlParameter("@UserGuid", (object)userGuid ?? Guid.Empty));

            try
            {
                await using var reader = await command.ExecuteReaderAsync();
                if (await reader.ReadAsync())
                {
                    user = new User
                    {
                        Email = reader.GetString(reader.GetOrdinal("Email")),
                        UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
                        FirstName = reader.GetString(reader.GetOrdinal("FirstName")),
                        LastName = reader.GetString(reader.GetOrdinal("Surname")),
                        MobileNo = reader.GetString(reader.GetOrdinal("Mobile")),
                        JobTitle = reader.GetString(reader.GetOrdinal("JobTitle")),
                        BillableRate = reader.GetDecimal(reader.GetOrdinal("BillableRate")),
                        Signature = reader.IsDBNull(reader.GetOrdinal("Signature")) ? Array.Empty<byte>() : reader.GetFieldValue<byte[]>(reader.GetOrdinal("Signature")),
                        OnHoliday = false,
                    };
                }
            }
            catch (Exception ex)
            {
                ex.Data["SQL"] = BuildSqlWithParams(selectStatement, command.Parameters.Cast<SqlParameter>().ToArray());
                throw new Exception($"Exception occurred getting GetUserInfo: {ex.Message}", ex);
            }

            if (user == null)
            {
                if (string.IsNullOrWhiteSpace(username))
                {
                    throw new Exception("Failed to obtain user. No valid username provided.");
                }

                const string createStatement = @"
EXECUTE SCore.UserCreate
    @EmailAddress = @EmailAddress,
    @FullName = @FullName,
    @FirstName = @FirstName,
    @Surname = @Surname,
    @MobileNo = @MobileNo,
    @IdentityID = @IdentityID OUTPUT";

                await using var createCommand = QueryBuilder.CreateCommand(createStatement, connection);

                var loweredUsername = username.ToLower();
                createCommand.Parameters.Add(new SqlParameter("@EmailAddress", loweredUsername));
                createCommand.Parameters.Add(new SqlParameter("@FullName", loweredUsername));
                createCommand.Parameters.Add(new SqlParameter("@FirstName", string.Empty));
                createCommand.Parameters.Add(new SqlParameter("@Surname", string.Empty));
                createCommand.Parameters.Add(new SqlParameter("@MobileNo", string.Empty));

                var identityIdParam = new SqlParameter("@IdentityID", System.Data.SqlDbType.Int)
                {
                    Direction = System.Data.ParameterDirection.Output
                };
                createCommand.Parameters.Add(identityIdParam);

                try
                {
                    await createCommand.ExecuteNonQueryAsync();
                }
                catch (Exception ex)
                {
                    ex.Data["SQL"] = BuildSqlWithParams(createStatement, createCommand.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetUserInfo: {ex.Message}", ex);
                }

                var identityId = identityIdParam.Value != DBNull.Value ? (int)identityIdParam.Value : 0;
                if (identityId == 0)
                {
                    throw new Exception("Failed to create user. No identity ID returned.");
                }

                user = new User
                {
                    Email = loweredUsername,
                    UserId = identityId,
                    FirstName = string.Empty,
                    LastName = string.Empty,
                    MobileNo = string.Empty,
                    JobTitle = string.Empty,
                    BillableRate = 0,
                    Signature = Array.Empty<byte>(),
                    OnHoliday = false,
                };
            }

            return user;
        }

        public async Task<UserPreferences> GetUserPreferences(int userId)
        {
            UserPreferences rsl;

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                using (var transaction = QueryBuilder.BeginTransaction(connection, IsolationLevel.ReadCommitted))
                {
                    rsl = await GetUserPreferences(userId, connection, transaction);
                }
            }

            return rsl;
        }

        /// <summary>
        /// Retrieves a list of GridView actions for a given user and GUID. Ensures proper resource
        /// cleanup and error handling while using ExecuteInTransaction for transaction management.
        /// </summary>
        /// <param name="userId"> The ID of the user requesting actions. </param>
        /// <param name="guid">   The GUID associated with the grid view. </param>
        /// <returns> A list of GridViewAction objects. </returns>
        public async Task<List<GridViewAction>> GridViewActionsGet(int userId, string guid)
        {
            List<GridViewAction> result = new();
            SqlConnection? connection = null;

            try
            {
                connection = CreateConnection();
                await OpenConnectionAsync(connection);

                // Execute the operation within a transaction using ExecuteInTransaction
                await connection.ExecuteInTransaction(async transaction =>
                {
                    result = await GridViewActionsGet(connection, guid, userId);
                }, System.Data.IsolationLevel.ReadCommitted);
            }
            catch (Exception ex)
            {
                // Log the exception for debugging purposes
                Console.Error.WriteLine($"Error in GridViewActionsGet: {ex.Message}");
                throw; // Re-throw the exception to notify the caller
            }
            finally
            {
                // Ensure the connection is always closed and disposed
                if (connection != null && connection.State != System.Data.ConnectionState.Closed)
                {
                    connection.Close();
                }
                connection?.Dispose();
            }

            return result;
        }

        public async Task LogUsage(Guid userGuid, string featureName)
        {
            using (SqlConnection connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string statement = @"
                        INSERT INTO SCore.SystemUsageLog (UserGuid, FeatureName, Accessed)
                        VALUES (@UserGuid, @FeatureName, GETUTCDATE());";

                using (SqlCommand command = QueryBuilder.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@UserGuid", userGuid));
                    command.Parameters.Add(new SqlParameter("@FeatureName", featureName));
                    try
                    {
                        await command.ExecuteNonQueryAsync();
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting LogUsage: {ex.Message}", ex);
                    }
                }
            }
        }

        public async Task<MergeDocument?> MergeDocumentGet(Guid documentGuid)
        {
            MergeDocument? mergeDocument = null;

            try
            {
                using (var connection = CreateConnection())
                {
                    await OpenConnectionAsync(connection).ConfigureAwait(false);

                    string sql = @"SELECT Id, Guid, Name, FilenameTemplate, EntityTypeId, DocumentId, LinkedEntityTypeId, SharePointSiteId
                           FROM SCore.MergeDocuments WHERE Guid = @Guid";

                    using var command = connection.CreateCommandWithParameters(sql, CommandType.Text,
                        new SqlParameter("@Guid", documentGuid));
                    try
                    {
                        using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
                        if (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            mergeDocument = new MergeDocument
                            {
                                Id = reader.GetSafeValue<int>("Id"),
                                Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                Name = reader.GetStringOrNull("Name"),
                                FilenameTemplate = reader.GetStringOrNull("FilenameTemplate"),
                                EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeId")),
                                DocumentId = reader.GetStringOrNull("DocumentId"),
                                LinkedEntityTypeGuid = reader.GetGuid(reader.GetOrdinal("LinkedEntityTypeId")),
                                DriveId = reader.GetSafeValue<int>("SharePointSiteId", -1).ToString(),
                            };
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting MergeDocumentGet: {ex.Message}", ex);
                    }
                }
            }
            catch (Exception ex)
            {
                // Log error (e.g., using a logging framework)
                throw new Exception("Failed to fetch merge document.", ex);
            }

            return mergeDocument;
        }

        public async Task<List<ObjectSharePointPaths>> ObjectSharePointPathCollectionGet()
        {
            List<ObjectSharePointPaths> rsl = new();
            ObjectSharePointPaths osp = new();

            using (SqlConnection connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string sqlStatement = "SELECT ObjectGuid, SharePointSiteIdentifier, FolderPath, FullSharePointUrl FROM SCore.ObjectSharePointPaths Where ObjectGuid <> '00000000-0000-0000-0000-000000000000'; ";

                using (SqlCommand command = QueryBuilder.CreateCommand(sqlStatement, connection))
                {
                    try
                    {
                        using (SqlDataReader reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                osp = new()
                                {
                                    ObjectGuid = reader.GetGuid(reader.GetOrdinal("ObjectGuid")),
                                    SharePointSiteIdentifier = reader.GetString(reader.GetOrdinal("SharePointSiteIdentifier")),
                                    FolderPath = reader.GetString(reader.GetOrdinal("FolderPath")),
                                    FullSharePointUrl = reader.GetString(reader.GetOrdinal("FullSharePointUrl"))
                                };
                                rsl.Add(osp);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting ObjectSharePointPathCollectionGet: {ex.Message}", ex);
                    }
                }
            }

            return rsl;
        }

        public async Task<int> OpenConnectionAsync(SqlConnection connection)
        {
            if (connection.State == System.Data.ConnectionState.Closed)
            {
                await connection.OpenAsync();

                // Check server version and execute session creation if applicable
                if (int.Parse(connection.ServerVersion[..2]) >= 14)
                {
                    await CreateUserSessionAsync(connection);
                }

                _userId = await GetCurrentUserId(connection);
            }

            return _userId;
        }

        //CBLD-405
        public async Task<OrganisationalUnit> OrganisationalUnitsByGuidGet(string _orgUnitGuid)
        {
            OrganisationalUnit rsl = new();

            using (SqlConnection connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string securityStatement = "SELECT * FROM SCore.tvf_OrganisationalUnitsByGuidGet(@OrgUnitGuid);";

                using (SqlCommand command = QueryBuilder.CreateCommand(securityStatement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@OrgUnitGuid", _orgUnitGuid));
                    try
                    {
                        using (SqlDataReader reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                rsl = new()
                                {
                                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                    Name = reader.GetString(reader.GetOrdinal("Name")),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                    ParentOrganisationalUnitGuid = reader.GetGuid(reader.GetOrdinal("ParentOrganisationalUnitGuid")),
                                    IsBusinessUnit = reader.GetBoolean(reader.GetOrdinal("IsBusinessUnit")),
                                    IsDivision = reader.GetBoolean(reader.GetOrdinal("IsDivision")),
                                    IsDepartment = reader.GetBoolean(reader.GetOrdinal("IsDepartment")),
                                    IsTeam = reader.GetBoolean(reader.GetOrdinal("IsTeam")),
                                };
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting OrganisationalUnitsByGuidGet: {ex.Message}", ex);
                    }
                }
            }

            return rsl;
        }

        //CBLD-405
        public async Task<List<OrganisationalUnit>> OrganisationalUnitsGet(int userId)
        {
            List<OrganisationalUnit> rsl = new();

            _userId = userId;
            if (_userId <= 0)
            {
                var _conn = CreateConnection();
                _userId = await GetCurrentUserId(_conn);
            }

            using (SqlConnection connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string securityStatement = "SELECT * FROM SCore.tvf_OrganisationalUnitsGet(@UserId);";

                using (SqlCommand command = QueryBuilder.CreateCommand(securityStatement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@UserId", _userId));
                    try
                    {
                        using (SqlDataReader reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                OrganisationalUnit organisationalUnit = new()
                                {
                                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                    Name = reader.GetString(reader.GetOrdinal("Name")),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                    ParentOrganisationalUnitGuid = reader.GetGuid(reader.GetOrdinal("ParentOrganisationalUnitGuid"))
                                };

                                rsl.Add(organisationalUnit);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting OrganisationalUnitsGet: {ex.Message}", ex);
                    }
                }
            }

            return rsl;
        }

        public async Task<List<ActionMenuItem>> ReadActionMenuItems(EntityType entityType, SqlConnection connection, SqlTransaction? transaction = null)
        {
            List<ActionMenuItem> rsl = new();

            string sql = $@"SELECT *
                        FROM SCore.tvf_ActionMenuItemsForEntityType ( @Guid, @UserId )";

            using (SqlCommand command = new(sql, connection))
            {
                command.Parameters.Add(new SqlParameter("@Guid", entityType.Guid));
                command.Parameters.Add(new SqlParameter("@UserId", _userId));
                try
                {
                    using SqlDataReader reader = await command.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        ActionMenuItem actionMenuItem = new()
                        {
                            RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                            RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                            Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                            Label = reader.GetString(reader.GetOrdinal("Label")),
                            IconCss = reader.GetString(reader.GetOrdinal("IconCss")),
                            Type = reader.GetString(reader.GetOrdinal("Type")),
                            EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")),
                            EntityQueryGuid = reader.GetGuid(reader.GetOrdinal("EntityQueryGuid")),
                            SortOrder = reader.GetInt32(reader.GetOrdinal("SortOrder")),
                            RedirectToTargetGuid = reader.GetBoolean(reader.GetOrdinal("RedirectToTargetGuid")),
                        };

                        rsl.Add(actionMenuItem);
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting ReadActionMenuItems: {ex.Message}", ex);
                }
            }

            return rsl;
        }

        public async Task<List<MergeDocument>> ReadMergeDocuments(EntityType entityType, SqlConnection connection, SqlTransaction? transaction = null)
        {
            var mergeDocuments = new List<MergeDocument>();
            string sql = @"SELECT * FROM SCore.tvf_MergeDocumentsForEntityType(@Guid, @UserId)";

            try
            {
                using (var command = connection.CreateCommandWithParameters(sql, CommandType.Text,
                           new SqlParameter("@Guid", entityType.Guid),
                           new SqlParameter("@UserId", _userId)))
                {
                    if (transaction != null)
                        command.Transaction = transaction;
                    try
                    {
                        using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
                        while (await reader.ReadAsync().ConfigureAwait(false))
                        {
                            var mergeDocument = MapMergeDocument(reader);
                            mergeDocuments.Add(mergeDocument);
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting ReadMergeDocuments: {ex.Message}", ex);
                    }
                }
            }
            catch (Exception ex)
            {
                // Log error (e.g., using a logging framework)
                throw new Exception("Failed to read merge documents.", ex);
            }

            return mergeDocuments;
        }

        public async Task<List<MergeDocument>> ReadMergeDocumentsWithChildren(EntityType entityType, SqlConnection connection, SqlTransaction? transaction = null)
        {
            var result = new List<MergeDocument>();
            try
            {
                // Get (cached) merge document definitions (no Items) for this entity type
                var defs = await GetMergeDocumentDefinitionsCached(connection, entityType.Guid);

                // Throttle parallel item loading to avoid hammering SQL
                const int MAX_PARALLEL = 4;
                using var gate = new SemaphoreSlim(MAX_PARALLEL);

                var tasks = defs.Select(async def =>
                {
                    await gate.WaitAsync().ConfigureAwait(false);
                    try
                    {
                        var sw = System.Diagnostics.Stopwatch.StartNew();

                        // Clone the definition so we don't mutate the cached instance
                        var doc = CloneMergeDocWithoutItems(def);

                        // Load items (cached per doc); uses its own short-lived connection internally
                        doc.Items = await GetMergeDocumentItemsCachedAsync(entityType, doc.Guid);

                        sw.Stop();
                        Console.WriteLine($"[MergeDocs] {doc.Guid} items loaded in {sw.ElapsedMilliseconds} ms");
                        return doc;
                    }
                    finally { gate.Release(); }
                });

                var docs = await Task.WhenAll(tasks).ConfigureAwait(false);
                result.AddRange(docs);
            }
            catch (Exception ex)
            {
                throw new Exception("Failed to read merge documents with children.", ex);
            }

            return result;
        }

        public async Task RecentItemsCreate(RecentItem recentItem)
        {
            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                using (var transaction = QueryBuilder.BeginTransaction(connection, IsolationLevel.ReadCommitted))
                {
                    //using (var command = BuildCommandForEntityQuery(query, dataObject, request.EntityQueryParameterValues.ToList(), connection, transaction))
                    using (var command = QueryBuilder.CreateCommand("EXEC [SCore].[RecentItemsCreate] @UserGuid = @UserGuid, @EntityTypeGuid = @EntityTypeGuid, @RecordGuid = @RecordGuid, @Label = @Label, @Datetime = @Datetime", connection, transaction))
                    {
                        command.Parameters.Add(new SqlParameter("@UserGuid", recentItem.UserGuid));
                        command.Parameters.Add(new SqlParameter("@EntityTypeGuid", recentItem.EntityTypeGuid));
                        command.Parameters.Add(new SqlParameter("@RecordGuid", recentItem.RecordGuid));
                        command.Parameters.Add(new SqlParameter("@Label", recentItem.Label));
                        command.Parameters.Add(new SqlParameter("@Datetime", recentItem.DateTime));

                        await command.ExecuteScalarAsync();
                    }

                    await QueryBuilder.CommitTransactionAsync(transaction);
                }
            }

            return;
        }

        public async Task<WidgetLayoutSaveResponse> SaveWidgetLayout(int UserId, string WidgetLayoutAsJSON = "{}")
        {
            WidgetLayoutSaveResponse response = new();
            var connection = CreateConnection();

            try
            {
                await OpenConnectionAsync(connection);

                // Wrap transaction handling using the ExecuteInTransaction extension
                await connection.ExecuteInTransaction(async transaction =>
                {
                    var command = connection.CreateCommandWithParameters(
                        "UPDATE SCore.UserPreferences SET WidgetLayout = @WidgetLayout WHERE ID = @UserId",
                        CommandType.Text,
                        new SqlParameter("WidgetLayout", WidgetLayoutAsJSON),
                        new SqlParameter("UserId", UserId)
                    );

                    command.Transaction = transaction;

                    try
                    {
                        response.RowsAffected = await command.ExecuteNonQueryAsync();
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting SaveWidgetLayout: {ex.Message}", ex);
                    }
                });
            }
            finally
            {
                // Ensure the connection is closed and disposed even if OpenConnectionAsync fails
                connection.Close();
                connection.Dispose();
            }

            return response;
        }

        public async Task<List<ScheduleItem>> ScheduleItemsGet(bool CurrentUserOnly = false)
        {
            List<ScheduleItem> rsl = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string securityStatement = "SELECT * FROM SCore.tvf_ScheduleItems (@UserId, @CurrentUserOnly)";

                using (var command = QueryBuilder.CreateCommand(securityStatement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@UserId", _userId));
                    command.Parameters.Add(new SqlParameter("@CurrentUserOnly", CurrentUserOnly));
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                ScheduleItem scheduleItem = new()
                                {
                                    Id = reader.GetInt64(reader.GetOrdinal("Id")),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                    Title = reader.GetString(reader.GetOrdinal("Title")),
                                    Description = reader.GetString(reader.GetOrdinal("Description")),
                                    IsAllDay = reader.GetBoolean(reader.GetOrdinal("IsAllDay")),
                                    RecurrenceRule = reader.GetString(reader.GetOrdinal("RecurrenceRule")),
                                    RecurrenceId = reader.GetInt32(reader.GetOrdinal("RecurrenceId")),
                                    RecurrenceExceptions = reader.GetString(reader.GetOrdinal("RecurrenceExceptions")),
                                    StartTimezone = reader.GetString(reader.GetOrdinal("StartTimezone")),
                                    EndTimezone = reader.GetString(reader.GetOrdinal("EndTimezone")),
                                    UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
                                    StatusId = reader.GetInt32(reader.GetOrdinal("StatusId")),
                                    TypeId = reader.GetInt32(reader.GetOrdinal("TypeId")),
                                    JobNumber = reader.GetString(reader.GetOrdinal("JobNumber")),
                                    StartDateTimeUTC = reader.GetDateTime(reader.GetOrdinal("Start")),
                                    EndDateTimeUTC = reader.GetDateTime(reader.GetOrdinal("End"))
                                };
                                rsl.Add(scheduleItem);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting ScheduleItemsGet: {ex.Message}", ex);
                    }
                }
            }

            return rsl;
        }

        public async Task<List<ScheduleItemStatus>> ScheduleItemStatusGet()
        {
            List<ScheduleItemStatus> rsl = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string securityStatement = "SELECT * FROM SCore.ScheduleItemStatus";

                using (var command = QueryBuilder.CreateCommand(securityStatement, connection))
                {
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                ScheduleItemStatus scheduleItemStatus = new()
                                {
                                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                    Name = reader.GetString(reader.GetOrdinal("Name")),
                                    Color = reader.GetString(reader.GetOrdinal("Colour"))
                                };

                                rsl.Add(scheduleItemStatus);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting ScheduleItemStatusGet: {ex.Message}", ex);
                    }
                }
            }

            return rsl;
        }

        public async Task<List<ScheduleItemType>> ScheduleItemTypesGet()
        {
            List<ScheduleItemType> rsl = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string securityStatement = "SELECT * FROM SCore.ScheduleItemTypes";

                using (var command = QueryBuilder.CreateCommand(securityStatement, connection))
                {
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                ScheduleItemType scheduleItemType = new()
                                {
                                    Id = reader.GetInt32(reader.GetOrdinal("Id")),
                                    Name = reader.GetString(reader.GetOrdinal("Name")),
                                    Color = reader.GetString(reader.GetOrdinal("Colour"))
                                };

                                rsl.Add(scheduleItemType);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting ScheduleItemTypesGet: {ex.Message}", ex);
                    }
                }
            }

            return rsl;
        }

        public async Task SetFileStreamData(Guid EntityProperty, Guid RecordGuid, System.IO.Stream data)
        {
            using (SqlConnection sqlConnection = new(_connectionString))
            {
                await sqlConnection.OpenAsync();

                string propertyName = "";
                string objectName = "";
                string schemaName = "";
                string path = "";
                byte[]? transactionContext = Array.Empty<byte>();

                string statement = "SELECT p.Name, h.SchemaName, h.ObjectName from SCore.EntityPropertiesV p JOIN SCore.EntityHobtsV h on (p.HoBTID = h.ID) WHERE (p.Guid = @Guid)";

                using (SqlCommand command = new SqlCommand(statement, sqlConnection))
                {
                    command.Parameters.Add(new SqlParameter("@Guid", EntityProperty));

                    using (SqlDataReader reader = command.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            propertyName = reader.GetString(reader.GetOrdinal("Name"));
                            objectName = reader.GetString(reader.GetOrdinal("ObjectName"));
                            schemaName = reader.GetString(reader.GetOrdinal("SchemaName"));
                        }
                    }
                }

                string statement2 = $"SELECT {propertyName}.PathName(), GET_FILESTREAM_TRANSACTION_CONTEXT() FROM [{schemaName}].[{objectName}]";

                using (SqlTransaction sqlTransaction = sqlConnection.BeginTransaction(IsolationLevel.ReadCommitted))
                {
                    using (SqlCommand command = new SqlCommand(statement2, sqlConnection, sqlTransaction))
                    {
                        using (SqlDataReader reader = command.ExecuteReader())
                        {
                            while (reader.Read())
                            {
                                // Get the pointer for file
                                path = reader.GetString(0);
                                transactionContext = reader.GetSqlBytes(1).Buffer;

                                new SqlFileStream(path, transactionContext, FileAccess.Write, FileOptions.SequentialScan, allocationSize: 0);

                                using (Stream fileStream = new SqlFileStream(path, transactionContext, FileAccess.Write, FileOptions.SequentialScan, allocationSize: 0))
                                {
                                    data.CopyTo(fileStream);
                                }
                            }
                        }
                    }
                }
            }
        }

        public async Task<User> UpdateUserSignature(User user)
        {
            using (SqlConnection connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string statement = "UPDATE SCore.Identities SET Signature = @Signature WHERE EmailAddress = @UserEmail";

                using (SqlCommand command = QueryBuilder.CreateCommand(statement, connection))
                {
                    command.Parameters.Add(new SqlParameter("@Signature", user.Signature));
                    command.Parameters.Add(new SqlParameter("@UserEmail", user.Email.ToLower()));

                    try
                    {
                        await command.ExecuteNonQueryAsync();
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting UpdateUserSignature: {ex.Message}", ex);
                    }
                }
            }

            return user;
        }

        public async Task<EF.Types.MergeDocumentItemInclude> UpsertMergeDocumentItemInclude(EF.Types.MergeDocumentItemInclude efModel)
        {
            using (SqlConnection connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string sql = @"EXEC SCore.MergeDocumentItemIncludesUpsert
                       @MergeDocumentItemGuid,
                       @SortOrder,
                       @SourceDocumentEntityPropertyGuid,
                       @SourceSharePointItemEntityPropertyGuid,
                       @IncludedMergeDocumentGuid,
                       @Guid";

                using (SqlCommand command = QueryBuilder.CreateCommand(sql, connection))
                {
                    command.Parameters.Add(new SqlParameter("@MergeDocumentItemGuid", efModel.MergeDocumentItemGuid));
                    command.Parameters.Add(new SqlParameter("@SortOrder", efModel.SortOrder));
                    command.Parameters.Add(new SqlParameter("@SourceDocumentEntityPropertyGuid", (object?)efModel.SourceDocumentEntityProperty ?? DBNull.Value));
                    command.Parameters.Add(new SqlParameter("@SourceSharePointItemEntityPropertyGuid", (object?)efModel.SourceSharePointItemEntityProperty ?? DBNull.Value));
                    command.Parameters.Add(new SqlParameter("@IncludedMergeDocumentGuid", (object?)efModel.IncludedMergeDocument ?? DBNull.Value));
                    //command.Parameters.Add(new SqlParameter("@Guid", efModel.Guid));
                    try
                    {
                        await command.ExecuteNonQueryAsync();
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting UpsertMergeDocumentItemInclude: {ex.Message}", ex);
                    }
                }
            }

            return efModel;
        }

        public async Task<UserPreferences> UserPreferencesUpdate(UserPreferences request)
        {
            // TODO: Add Row Version Check
            // TODO: Add Validation

            if (request == null)
            {
                throw new ArgumentNullException(nameof(request), "UserPreferences request cannot be null.");
            }

            try
            {
                await using var connection = CreateConnection();
                await OpenConnectionAsync(connection);

                await using var transaction = QueryBuilder.BeginTransaction(connection);

                // Update UserPreferences
                const string updateStatement = @"
            UPDATE SCore.UserPreferences
            SET
                SystemLanguageID = @SystemLanguageID,
                WidgetLayout = @WidgetLayout
            WHERE
                ID = @UserId";

                await using var updateCommand = QueryBuilder.CreateCommand(updateStatement, connection, transaction);
                updateCommand.Parameters.Add(new SqlParameter("@SystemLanguageID", request.SystemLanguageID));
                updateCommand.Parameters.Add(new SqlParameter("@WidgetLayout", request.WidgetLayout ?? (object)DBNull.Value));
                updateCommand.Parameters.Add(new SqlParameter("@UserId", request.ID));
                try
                {
                    await updateCommand.ExecuteNonQueryAsync();
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(updateCommand.CommandText, updateCommand.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting UserPreferencesUpdate: {ex.Message}", ex);
                }

                // Retrieve Updated UserPreferences
                const string selectStatement = @"
            SELECT
                up.ID,
                up.GUID,
                up.SystemLanguageID,
                up.WidgetLayout
            FROM
                SCore.UserPreferences up
            WHERE
                up.ID = @UserId";

                await using var selectCommand = QueryBuilder.CreateCommand(selectStatement, connection);
                selectCommand.Parameters.Add(new SqlParameter("@UserId", request.ID));
                try
                {
                    await using var reader = await selectCommand.ExecuteReaderAsync();
                    if (await reader.ReadAsync())
                    {
                        return new UserPreferences
                        {
                            ID = reader.GetInt32(reader.GetOrdinal("ID")),
                            Guid = reader.GetGuid(reader.GetOrdinal("GUID")),
                            SystemLanguageID = reader.GetInt32(reader.GetOrdinal("SystemLanguageID")),
                            WidgetLayout = reader.IsDBNull(reader.GetOrdinal("WidgetLayout")) ? null : reader.GetString(reader.GetOrdinal("WidgetLayout")),
                        };
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(selectCommand.CommandText, selectCommand.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting UserPreferencesUpdate: {ex.Message}", ex);
                }

                throw new Exception("Failed to retrieve updated UserPreferences.");
            }
            catch (SqlException ex)
            {
                throw new Exception($"Database error while updating UserPreferences: {ex.Message}", ex);
            }
            catch (Exception ex)
            {
                throw new Exception($"Unexpected error while updating UserPreferences: {ex.Message}", ex);
            }
        }

        public async Task<List<User>> UsersGet()
        {
            List<User> rsl = new();

            using (var connection = CreateConnection())
            {
                await OpenConnectionAsync(connection);

                string securityStatement = "SELECT * FROM SCore.UsersGet;";

                using (var command = QueryBuilder.CreateCommand(securityStatement, connection))
                {
                    try
                    {
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                User user = new()
                                {
                                    UserId = reader.GetInt32(reader.GetOrdinal("ID")),
                                    Email = reader.GetString(reader.GetOrdinal("EmailAddress")),
                                    Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                                    FullName = reader.GetString(reader.GetOrdinal("FullName")),
                                    JobTitle = reader.GetString(reader.GetOrdinal("JobTitle")),
                                    BillableRate = reader.GetDecimal(reader.GetOrdinal("BillableRate")),
                                    Signature = reader.IsDBNull(reader.GetOrdinal("Signature")) ? new byte[0] : reader.GetFieldValue<byte[]>(reader.GetOrdinal("Signature"))
                                };

                                rsl.Add(user);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        // Attach the SQL query to the exception data so the API logger can pick it up
                        ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting UsersGet: {ex.Message}", ex);
                    }
                }
            }

            return rsl;
        }

        //CBLD-616: Imports legacy statuses by executing a stored procedure ([SCore].[DataObjectTransitionImportLegacyStatus])
        public async Task<bool> ImportLegacyStatuses()
        {
            using (var connection = CreateConnection())  // same helper you already use
            {
                await OpenConnectionAsync(connection);

                using (var command = new SqlCommand("SCore.DataObjectTransitionImportLegacyStatus", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;

                    try
                    {
                        // Executes the stored procedure and waits for it to complete
                        await command.ExecuteNonQueryAsync();

                        Console.WriteLine("[SCore].[DataObjectTransitionImportLegacyStatus] finished successfully.");

                        return true;
                    }
                    catch (Exception ex)
                    {
                        // Include the SQL command for logging consistency
                        ex.Data["SQL"] = $"EXEC [SCore].[DataObjectTransitionImportLegacyStatus]";
                        throw new Exception($"Error executing [SCore].[DataObjectTransitionImportLegacyStatus]: {ex.Message}", ex);
                    }
                }
            }
        }

        #endregion Public Methods

        #region Private Methods

        private static string BuildSqlWithParams(string query, SqlParameter[] parameters)
        {
            var formattedParams = parameters
                .Select(p => $"@{p.ParameterName} = '{p.Value}'")
                .ToArray();

            return $"{query}\nParams:\n{string.Join("\n", formattedParams)}";
        }

        private static MergeDocumentItem CloneMergeDocItem(MergeDocumentItem src)
        {
            var dest = Activator.CreateInstance<MergeDocumentItem>()!;
            var props = typeof(MergeDocumentItem).GetProperties(BindingFlags.Public | BindingFlags.Instance)
                .Where(p => p.CanRead && p.CanWrite);

            foreach (var p in props)
                p.SetValue(dest, p.GetValue(src));

            return dest;
        }

        private static List<MergeDocumentItem> CloneMergeDocItems(IEnumerable<MergeDocumentItem> src)
            => src.Select(CloneMergeDocItem).ToList();

        /// <summary>
        /// Shallow clone of a MergeDocument excluding the Items property (so we can attach fresh
        /// Items). Copies all public settable properties except those explicitly excluded.
        /// </summary>
        private static MergeDocument CloneMergeDocWithoutItems(MergeDocument src)
        {
            var dest = Activator.CreateInstance<MergeDocument>()!;
            var props = typeof(MergeDocument).GetProperties(BindingFlags.Public | BindingFlags.Instance)
                .Where(p => p.CanRead && p.CanWrite && !string.Equals(p.Name, "Items", StringComparison.OrdinalIgnoreCase));

            foreach (var p in props)
                p.SetValue(dest, p.GetValue(src));

            // ensure Items starts as empty list
            if (typeof(MergeDocument).GetProperty("Items")?.CanWrite == true)
                typeof(MergeDocument).GetProperty("Items")!.SetValue(dest, new List<MergeDocumentItem>());

            return dest;
        }

        private static string DataObjectCompositeToSqlPredicate(
    DataObjectCompositeFilter compositeFilter,
    string logicalOperator,
    string filterSeparator = "")
        {
            if (compositeFilter == null)
            {
                throw new ArgumentNullException(nameof(compositeFilter), "Composite filter cannot be null.");
            }

            var predicateBuilder = new StringBuilder();

            // Add the logical operator and opening parenthesis
            if (!string.IsNullOrWhiteSpace(logicalOperator))
            {
                predicateBuilder.Append(logicalOperator).Append(" (");
            }
            else
            {
                predicateBuilder.Append(" (");
            }

            bool addLogicalOperator = false;

            // Process composite filters recursively
            foreach (var nestedCompositeFilter in compositeFilter.CompositeFilters)
            {
                //OE - CBLD-633 fix:
                //if (addLogicalOperator)
                //{
                //    predicateBuilder.Append(compositeFilter.LogicalOperator);
                //}

                predicateBuilder.Append(DataObjectCompositeToSqlPredicate(
                    nestedCompositeFilter,
                    addLogicalOperator ? compositeFilter.LogicalOperator : "",
                    filterSeparator));

                addLogicalOperator = true;
            }

            // Process individual filters
            int filterIndex = 0;
            foreach (var filter in compositeFilter.Filters)
            {
                if (addLogicalOperator)
                {
                    predicateBuilder.Append(compositeFilter.LogicalOperator);
                }

                if (filterIndex > 0)
                {
                    predicateBuilder.Append(" ").Append(filterSeparator).Append(" ");
                }

                predicateBuilder.Append(Core.CreatePropertyStatement(filter.ColumnName, filter.Operator, filter.Guid));

                addLogicalOperator = true;
                filterIndex++;
            }

            // Close the parenthesis
            predicateBuilder.Append(") ");

            // Remove empty predicates
            if (predicateBuilder.ToString().Trim() == "()")
            {
                return string.Empty;
            }

            return predicateBuilder.ToString();
        }

        private static string EtKey(Guid guid, int userId, bool forRead, bool forWrite,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            bool forProcessingOnly, bool forInformationView, bool includeEntityQueries)
    => $"et:{guid:N}:{userId}:{forRead}:{forWrite}:{forProcessingOnly}:{forInformationView}:{includeEntityQueries}";

        // crude but effective heuristic for your schema
        private static bool LooksLikeGuidColumn(string? columnName)
        {
            if (string.IsNullOrEmpty(columnName)) return false;
            var n = columnName.ToLowerInvariant();
            // matches [Guid], .Guid, Guid] etc.
            return n.Contains("guid]");
        }

        private static string MergeDocCacheKey(Guid entityTypeGuid, int userId) => $"mergedoc_defs:{entityTypeGuid:N}:{userId}";

        private static string MergeDocItemsKey(Guid mergeDocGuid, int userId) => $"mergedoc_items:{mergeDocGuid:N}:{userId}";

        private static Any ProcessFieldValue(SqlDataReader reader, int fieldIndex, Types.EntityProperty currentProperty, ref Types.DataObject dataObject)
        {
            if (reader.IsDBNull(fieldIndex))
            {
                return Any.Pack(new Empty());
            }

            switch (reader.GetFieldType(fieldIndex).Name.ToLowerInvariant())
            {
                case "string":
                    var stringValue = new StringValue { Value = reader.GetString(fieldIndex) };
                    if (currentProperty.IsObjectLabel)
                    {
                        dataObject.Label = stringValue.Value;
                    }
                    return Any.Pack(stringValue);

                case "guid":
                    var guidValue = new StringValue { Value = reader.GetGuid(fieldIndex).ToString() };
                    if (currentProperty.IsObjectLabel)
                    {
                        dataObject.Label = guidValue.Value;
                    }
                    return Any.Pack(guidValue);

                case "byte": // SQL TINYINT
                    var byteAsInt = new Int32Value { Value = reader.GetByte(fieldIndex) };
                    if (currentProperty.IsObjectLabel)
                    {
                        dataObject.Label = byteAsInt.Value.ToString();
                    }
                    return Any.Pack(byteAsInt);

                case "int16":
                    var int16Value = new Int32Value { Value = reader.GetInt16(fieldIndex) };
                    if (currentProperty.IsObjectLabel)
                    {
                        dataObject.Label = int16Value.Value.ToString();
                    }
                    return Any.Pack(int16Value);

                case "int32":
                    var int32Value = new Int32Value { Value = reader.GetInt32(fieldIndex) };
                    if (currentProperty.IsObjectLabel)
                    {
                        dataObject.Label = int32Value.Value.ToString();
                    }
                    return Any.Pack(int32Value);

                case "int64":
                    var int64Value = new Int64Value { Value = reader.GetInt64(fieldIndex) };
                    if (currentProperty.IsObjectLabel)
                    {
                        dataObject.Label = int64Value.Value.ToString();
                    }
                    return Any.Pack(int64Value);

                case "decimal":
                    var decimalValue = new DoubleValue { Value = (double)reader.GetDecimal(fieldIndex) };
                    if (currentProperty.IsObjectLabel)
                    {
                        dataObject.Label = decimalValue.Value.ToString();
                    }
                    return Any.Pack(decimalValue);

                case "boolean":
                    var boolValue = new BoolValue { Value = reader.GetBoolean(fieldIndex) };
                    if (currentProperty.IsObjectLabel)
                    {
                        dataObject.Label = boolValue.Value.ToString();
                    }
                    return Any.Pack(boolValue);

                case "datetime":
                    var timestampValue = Timestamp.FromDateTime(new DateTime((reader.GetDateTime(fieldIndex)).Ticks, DateTimeKind.Utc));
                    if (currentProperty.IsObjectLabel)
                    {
                        dataObject.Label = timestampValue.ToString();
                    }
                    return Any.Pack(timestampValue);

                case "byte[]":
                    var byteValue = new BytesValue { Value = ByteString.CopyFrom((byte[])reader.GetValue(fieldIndex)) };
                    return Any.Pack(byteValue);

                default:
                    throw new InvalidOperationException($"Unsupported field type: {reader.GetFieldType(fieldIndex).Name}");
            }
        }

        private static Types.DataObject ReadEntityProperty(
            SqlDataReader reader,
            Types.DataObject dataObject,
            int fieldIndex,
            Types.EntityType entityType,
            Guid hobtGuid,
            bool forInformationView,
            bool isMainHobt)
        {
            try
            {
                string fieldName = reader.GetName(fieldIndex).ToLowerInvariant();

                switch (fieldName)
                {
                    case "rowstatus":
                        dataObject.RowStatus = (Enums.RowStatus)reader.GetByte(fieldIndex);
                        break;

                    case "id":
                        var fieldType = reader.GetFieldType(fieldIndex);
                        dataObject.DatabaseId = fieldType == typeof(long) ? reader.GetInt64(fieldIndex)
                                            : fieldType == typeof(short) ? long.Parse(reader.GetInt16(fieldIndex).ToString())
                                            : long.Parse(reader.GetInt32(fieldIndex).ToString());
                        break;

                    case "guid":
                        dataObject.Guid = reader.GetGuid(fieldIndex);
                        break;

                    case "rowversion" when isMainHobt:
                        dataObject.RowVersion = Convert.ToBase64String((byte[])reader.GetValue(fieldIndex));
                        break;

                    default:
                        // Skip further processing for rowversion if isMainHobt is false
                        if (fieldName == "rowversion" && !isMainHobt)
                        {
                            break;
                        }
                        var currentProperty = entityType.EntityProperties
                    .FirstOrDefault(p => p.Name.Equals(fieldName, StringComparison.OrdinalIgnoreCase) && p.EntityHoBTGuid == hobtGuid);

                        if (currentProperty == null) break;

                        if (!forInformationView || currentProperty.IsIncludedInformation)
                        {
                            var property = new Types.DataProperty
                            {
                                EntityPropertyGuid = currentProperty.Guid,
                            };

                            SetObjectSecurity(currentProperty.ObjectSecurity.FirstOrDefault(), property);

                            if (property.IsEnabled)
                            {
                                property.Value = ProcessFieldValue(reader, fieldIndex, currentProperty, ref dataObject);
                            }

                            if (forInformationView)
                            {
                                property.IsReadOnly = true;
                            }

                            dataObject.DataProperties.Add(property);
                        }
                        break;
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Failure reading property '{reader.GetName(fieldIndex).ToLowerInvariant()}': {ex.Message}", ex);
            }

            return dataObject;
        }

        private static void SetObjectSecurity(Types.ObjectSecurity? objectSecurity, Types.DataProperty property)
        {
            if (objectSecurity == null)
            {
                property.IsRestricted = true;
                property.IsReadOnly = true;
                property.IsEnabled = false;
                return;
            }

            property.IsEnabled = objectSecurity.CanWrite;
            property.IsReadOnly = !objectSecurity.CanWrite;
            property.IsRestricted = !objectSecurity.CanRead;
        }

        private static string UnquoteKnownParams(string sql)
        {
            // Only strip quotes around the handful of known parameters
            var names = new[] { "@UserId", "@CURRENT_USER_ID", "@ParentGuid", "@EntityGuid", "@EntityTypeGuid", "@RecordGuid", "@CurrentSelectedValueGuid" };
            foreach (var name in names)
            {
                sql = Regex.Replace(sql, $"'{Regex.Escape(name)}'", name, RegexOptions.IgnoreCase);
            }
            return sql;
        }

        private void AddRowVersionValidationMessage(
                    DataObject dataObject,
                    SqlConnection connection,
                    SqlTransaction transaction)
        {
            const string query = "SELECT SCore.GetLastModificationUser(@Guid)";
            var message = "Another user has edited this record, please reload the record before making any changes.";

            using var command = new SqlCommand(query, connection, transaction);
            command.Parameters.AddWithValue("@Guid", dataObject.Guid);

            var result = command.ExecuteScalar();
            if (result != null)
            {
                message = $"{result} has edited this record, please reload the record before making any changes.";
            }

            dataObject.HasValidationMessages = true;
            dataObject.ValidationResults.Add(new ValidationResult
            {
                IsInvalid = true,
                Message = message,
                TargetType = "E",
                TargetGuid = dataObject.Guid
            });
        }

        private string CreateJSonForDataProperties(DataObject dO)
        {
            //Add option to ensure all fields (speicifically, lists) are serialized.
            JsonSerializerOptions serializerOptions = new JsonSerializerOptions() { IncludeFields = true };
            string serializedDataObject = JsonSerializer.Serialize(dO, serializerOptions);

            //Parse the serialized Object as jnode.
            JsonObject dataObjectAsJSON = JsonNode.Parse(serializedDataObject).AsObject();

            //Collection of DataProperties
            JsonArray dataPropertiesJSON = new JsonArray();
            //Body for each property.
            JsonObject newBody;

            foreach (var property in dO.DataProperties)
            {
                newBody = new JsonObject
                {
                    ["EntityPropertyGuid"] = Guid.Empty.ToString(),
                    ["StringValue"] = null,
                    ["DoubleValue"] = null,
                    ["IntValue"] = null,
                    ["BigIntValue"] = null,
                    ["BitValue"] = null,
                    ["DateTimeValue"] = null,
                    ["IsInvalid"] = false,
                    ["ValidationMessage"] = string.Empty,
                    ["IsReadOnly"] = false,
                    ["IsEnabled"] = false,
                    ["IsRestricted"] = false,
                    ["IsHidden"] = false
                };

                //Assign the initial properties.
                newBody["EntityPropertyGuid"] = property.EntityPropertyGuid;
                newBody["IsInvalid"] = property.IsInvalid;
                newBody["ValidationMessage"] = property.ValidationMessage;
                newBody["IsReadOnly"] = property.IsReadOnly;
                newBody["IsEnabled"] = property.IsEnabled;
                newBody["IsRestricted"] = property.IsRestricted;
                newBody["IsHidden"] = property.IsHidden;

                //To prevent error being thrown.
                if (property.Value == null)
                {
                    dataPropertiesJSON.Add(newBody);
                    continue;
                }

                var propertyValue = property.Value;
                var TypeUrl = property.Value.TypeUrl;

                //Unpack values from protobuff.
                if (propertyValue.Value.Count() != 0)
                {
                    switch (TypeUrl)
                    {
                        case "type.googleapis.com/google.protobuf.DoubleValue":
                            propertyValue.TryUnpack(out DoubleValue doubleValue);
                            newBody["DoubleValue"] = doubleValue.Value != 0 ? doubleValue.Value : 0.00;
                            break;

                        case "type.googleapis.com/google.protobuf.StringValue":
                            propertyValue.TryUnpack(out StringValue stringValue);
                            newBody["StringValue"] = !string.IsNullOrEmpty(stringValue.Value) ? stringValue.Value : string.Empty;
                            break;

                        case "type.googleapis.com/google.protobuf.Int16Value":
                            propertyValue.TryUnpack(out Int32Value smallIntValue);
                            newBody["IntValue"] = smallIntValue.Value;
                            break;

                        case "type.googleapis.com/google.protobuf.Int32Value":
                            propertyValue.TryUnpack(out Int32Value int32Value);
                            newBody["IntValue"] = int32Value.Value;
                            break;

                        case "type.googleapis.com/google.protobuf.Int64Value":
                            propertyValue.TryUnpack(out Int64Value int64Value);
                            newBody["BigIntValue"] = int64Value.Value;
                            break;

                        case "type.googleapis.com/google.protobuf.BoolValue":
                            propertyValue.TryUnpack(out BoolValue boolValue);
                            newBody["BitValue"] = boolValue.Value;
                            break;

                        case "type.googleapis.com/google.protobuf.Timestamp":
                            propertyValue.TryUnpack(out Timestamp timestampValue);
                            newBody["DateTimeValue"] = timestampValue.ToDateTime();
                            break;

                        case "type.googleapis.com/google.protobuf.BytesValue":
                            propertyValue.TryUnpack(out BytesValue bytesValue);
                            newBody["StringValue"] = bytesValue.Value.ToString();
                            break;
                    }
                }

                //Add the new body to the collection.
                dataPropertiesJSON.Add(newBody);
            }
                    ;

            //Replace the DataProperties with the new format.
            dataObjectAsJSON.Remove("DataProperties");
            dataObjectAsJSON["DataProperties"] = dataPropertiesJSON;

            return dataObjectAsJSON.ToString();
        }

        private async Task CreateUserSessionAsync(SqlConnection connection)
        {
            if (connection is null)
            {
                throw new ArgumentNullException(nameof(connection));
            }

            if (string.IsNullOrWhiteSpace(_userName))
            {
                _userName = ResolveSessionUserEmail(_claimsPrincipal);

                if (string.IsNullOrWhiteSpace(_userName))
                {
                    throw new Exception("User email is required to create a session.");
                }
            }

            using var command = connection.CreateCommand();
            command.CommandText = "EXECUTE SCore.CreateUserSession @UserEmail=@UserEmail;";
            command.Parameters.Add(new SqlParameter("@UserEmail", _userName.Trim()));

            try
            {
                await command.ExecuteNonQueryAsync();
            }
            catch (Exception ex)
            {
                ex.Data["SQL"] = BuildSqlWithParams(
                    command.CommandText,
                    command.Parameters.Cast<SqlParameter>().ToArray());

                throw new Exception(
                    $"Exception occurred getting CreateUserSessionAsync: {ex.Message}",
                    ex);
            }
        }

        private async Task ExecuteUpsert(
                            DataObject dataObject,
                            EntityType entityType,
                            EntityHoBT entityHoBT,
                            DataObjectUpsertRequest request,
                            SqlConnection connection,
                            SqlTransaction transaction)
        {
            EntityQuery? query = entityType.EntityQueries.FirstOrDefault(eq =>
                eq.Guid == request.EntityQueryGuid ||
                (request.DataObject.Guid == Guid.Empty && eq.IsDefaultCreate && request.EntityQueryGuid == Guid.Empty) ||
                (request.DataObject.Guid != Guid.Empty && eq.IsDefaultUpdate && request.EntityQueryGuid == Guid.Empty));

            if (query == null || string.IsNullOrWhiteSpace(query.Statement))
            {
                throw new InvalidOperationException("No valid query found for upsert operation.");
            }

            if (entityType.HasDocuments)
            {
                await UpsertDocuments(dataObject, connection, transaction);
            }

            await using var command = QueryBuilder.BuildCommandForEntityQuery(query, dataObject, request.EntityQueryParameterValues.ToList(), connection, transaction);
            await command.ExecuteScalarAsync();
        }

        private string GenerateColorFromGuid(string guid)
        {
            if (string.IsNullOrEmpty(guid)) return "#cccccc";

            var hash = guid.GetHashCode();
            var r = (hash & 0xFF0000) >> 16;
            var g = (hash & 0x00FF00) >> 8;
            var b = (hash & 0x0000FF);
            return $"#{r:X2}{g:X2}{b:X2}";
        }

        /// <summary>
        /// Reads merge document "definitions" (no Items) from the TVF and caches them for 10
        /// minutes. Returned list can be considered read-only; use CloneMergeDocWithoutItems when
        /// attaching Items.
        /// </summary>
        private async Task<List<MergeDocument>> GetMergeDocumentDefinitionsCached(SqlConnection connection, Guid entityTypeGuid)
        {
            var key = MergeDocCacheKey(entityTypeGuid, _userId);
            if (_mergeDocCache.Get(key) is List<MergeDocument> cached)
                return cached;

            const string mergeDocumentSql = @"SELECT * FROM SCore.tvf_MergeDocumentsForEntityType(@Guid, @UserId)";
            var buffer = new List<MergeDocument>();

            using (var command = connection.CreateCommandWithParameters(mergeDocumentSql, CommandType.Text,
                       new SqlParameter("@Guid", entityTypeGuid),
                       new SqlParameter("@UserId", _userId)))
            {
                try
                {
                    using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        buffer.Add(MapMergeDocument(reader)); // your existing mapper
                    }
                }
                catch (Exception ex)
                {
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetMergeDocumentDefinitionsCached: {ex.Message}", ex);
                }
            }

            // Cache the definitions (no Items) for 10 minutes
            _mergeDocCache.Set(key, buffer, DateTimeOffset.UtcNow.AddMinutes(10));
            return buffer;
        }

        private async Task<List<MergeDocumentItemInclude>> GetMergeDocumentItemIncludes(SqlConnection connection, Guid parentGuid)
        {
            var includes = new List<MergeDocumentItemInclude>();

            string sql = @"SELECT * FROM SCore.tvf_MergeDocumentItemIncludes(@UserId, @ParentGuid)";

            using (var command = connection.CreateCommandWithParameters(sql, CommandType.Text,
                       new SqlParameter("@UserId", _userId),
                       new SqlParameter("@ParentGuid", parentGuid)))
            {
                try
                {
                    using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        var include = new MergeDocumentItemInclude
                        {
                            Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                            SortOrder = reader.GetInt32(reader.GetOrdinal("SortOrder")),
                            SourceDocumentEntityProperty = reader.GetString(reader.GetOrdinal("SourceDocumentEntityProperty")),
                            SourceSharePointItemEntityProperty = reader.GetString(reader.GetOrdinal("SourceSharePointItemEntityProperty")),
                            IncludedMergeDocument = reader.GetString(reader.GetOrdinal("IncludedMergeDocument"))
                        };
                        includes.Add(include);
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetMergeDocumentItemIncludes: {ex.Message}", ex);
                }
            }

            return includes;
        }

        private async Task<List<MergeDocumentItem>> GetMergeDocumentItems(SqlConnection connection, Guid parentGuid)
        {
            var items = new List<MergeDocumentItem>();
            string sql = @"SELECT * FROM SCore.tvf_MergeDocumentItems(@UserId, @ParentGuid)";

            using (var command = connection.CreateCommandWithParameters(sql, CommandType.Text,
                       new SqlParameter("@UserId", _userId),
                       new SqlParameter("@ParentGuid", parentGuid)))
            {
                try
                {
                    using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        var item = new MergeDocumentItem
                        {
                            Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                            BookmarkName = reader.GetString(reader.GetOrdinal("BookmarkName")),
                            MergeDocumentItemType = reader.GetString(reader.GetOrdinal("MergeDocumentItemType")),
                            EntityType = reader.GetString(reader.GetOrdinal("EntityType")),
                            EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")),
                            LinkedEntityTypeGuid = reader.GetGuid(reader.GetOrdinal("LinkedEntityTypeGuid")),
                            SubFolderPath = reader.GetString(reader.GetOrdinal("SubFolderPath")),
                            ImageColumns = reader.GetInt32(reader.GetOrdinal("ImageColumns"))
                        };
                        items.Add(item);
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetMergeDocumentItems: {ex.Message}", ex);
                }
            }

            return items;
        }

        /// <summary>
        /// Returns cached Items when available; otherwise loads and caches them. Always returns a
        /// clone so the cache isn't mutated by callers.
        /// </summary>
        private async Task<List<MergeDocumentItem>> GetMergeDocumentItemsCachedAsync(EntityType entityType, Guid mergeDocGuid)
        {
            var key = MergeDocItemsKey(mergeDocGuid, _userId);

            if (_mergeDocItemsCache.Get(key) is List<MergeDocumentItem> cached)
                return CloneMergeDocItems(cached);

            var fresh = await LoadMergeDocItemsAsync(entityType, mergeDocGuid);
            _mergeDocItemsCache.Set(key, fresh, DateTimeOffset.UtcNow.AddMinutes(10)); // TTL: 10 min
            return CloneMergeDocItems(fresh);
        }

        private async Task<List<MergeDocumentItem>> GetMergeDocumentItemsSequentially(EntityType entityType, SqlConnection connection, Guid parentGuid)
        {
            var items = new List<MergeDocumentItem>();

            string mergeDocumentItemsSql = @"SELECT * FROM SCore.tvf_MergeDocumentItems(@UserId, @ParentGuid)";

            using (var command = connection.CreateCommandWithParameters(mergeDocumentItemsSql, CommandType.Text,
                       new SqlParameter("@UserId", _userId),
                       new SqlParameter("@ParentGuid", parentGuid)))
            {
                try
                {
                    using var reader = await command.ExecuteReaderAsync().ConfigureAwait(false);
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        var item = new MergeDocumentItem
                        {
                            Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                            BookmarkName = reader.GetString(reader.GetOrdinal("BookmarkName")),
                            MergeDocumentItemType = reader.GetString(reader.GetOrdinal("MergeDocumentItemType")),
                            EntityType = reader.GetString(reader.GetOrdinal("EntityType")),
                            EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")),
                            LinkedEntityTypeGuid = reader.GetGuid(reader.GetOrdinal("LinkedEntityTypeGuid")),
                            SubFolderPath = reader.GetString(reader.GetOrdinal("SubFolderPath")),
                            ImageColumns = reader.GetInt32(reader.GetOrdinal("ImageColumns"))
                        };

                        // Fetch Includes for this item using a new connection
                        await using (var newConnection = new SqlConnection(connection.ConnectionString))
                        {
                            await newConnection.OpenAsync();
                            item.Includes = await GetMergeDocumentItemIncludes(newConnection, item.Guid);
                        }

                        items.Add(item);
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetMergeDocumentItemsSequentially: {ex.Message}", ex);
                }
            }

            return items;
        }

        private async Task<List<ObjectSecurity>> GetObjectSecurityList(SqlConnection connection, Guid objectGuid)
        {
            var securityList = new List<ObjectSecurity>();
            var securityStatement = "SELECT ObjectGuid, CanRead, CanWrite FROM SCore.ObjectSecurityForUser (@ObjectGuid, @UserId)";

            using (var command = QueryBuilder.CreateCommand(securityStatement, connection))
            {
                command.Parameters.Add(new SqlParameter("@ObjectGuid", objectGuid.ToString()));
                command.Parameters.Add(new SqlParameter("@UserId", _userId));
                try
                {
                    using var reader = await command.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        securityList.Add(new ObjectSecurity
                        {
                            ObjectGuid = reader.GetGuid(reader.GetOrdinal("ObjectGuid")),
                            CanRead = reader.GetBoolean(reader.GetOrdinal("CanRead")),
                            CanWrite = reader.GetBoolean(reader.GetOrdinal("CanWrite"))
                        });
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting GetObjectSecurityList: {ex.Message}", ex);
                }
            }

            return securityList;
        }

        private async Task HandleRowVersionCheck(DataObject dataObject, EntityType entityType, SqlConnection connection, SqlTransaction transaction)
        {
            bool rowVersionMatches = await Validation.CheckRowVersionMatches(entityType, dataObject.RowVersion, dataObject.Guid, connection, transaction);

            if (!rowVersionMatches)
            {
                string message = "Another user has edited this record. Please reload the record before making changes.";

                string query = "SELECT SCore.GetLastModificationUser(@Guid)";
                await using var command = new SqlCommand(query, connection, transaction);
                command.Parameters.AddWithValue("@Guid", dataObject.Guid);

                var result = await command.ExecuteScalarAsync();
                if (result != null)
                {
                    message = $"{result} has edited this record. Please reload before making any changes.";
                }

                dataObject.HasValidationMessages = true;
                dataObject.ValidationResults.Add(new ValidationResult
                {
                    IsInvalid = true,
                    Message = message,
                    TargetType = "E",
                    TargetGuid = dataObject.Guid
                });

                throw new InvalidOperationException(message);
            }
        }

        private async Task HandleValidationActions(
                        DataObjectUpsertRequest request,
                        DataObject dataObject,
                        EntityType entityType,
                        SqlConnection connection,
                        SqlTransaction transaction)
        {
            foreach (var entityHoBT in entityType.EntityHoBTs)
            {
                var validationResults = await Validation.RunObjectValidation(
                    entityType, dataObject, connection, entityHoBT, transaction);

                Validation.ApplyValidationResults(ref dataObject, false, entityType, validationResults, entityHoBT.Guid, false);
            }

            /*
             * Execute property actions against the serialized data object.
             * Ensure DataProperties are processed correctly to JSON.
             */
            var firstDataProperty = request.DeltaDataObject.DataProperties.FirstOrDefault();
            var correctEntityToExecute = firstDataProperty?.EntityPropertyGuid.ToString().ToLower() ?? string.Empty;

            foreach (var property in entityType.EntityProperties)
            {
                if (!property.PropertyActions.Any() || correctEntityToExecute != property.Guid.ToString())
                    continue;

                foreach (var action in property.PropertyActions)
                {
                    using (var command = QueryBuilder.CreateCommand(action.Statement, connection))
                    {
                        // Serialize the DataObject to JSON
                        string serializedDataObject = CreateJSonForDataProperties(dataObject);

                        var dataObjectParameter = new SqlParameter("@DataObject", SqlDbType.NVarChar, -1)
                        {
                            Value = serializedDataObject,
                            Direction = ParameterDirection.InputOutput
                        };

                        command.Parameters.Add(dataObjectParameter);
                        try
                        {
                            await command.ExecuteNonQueryAsync();
                        }
                        catch (Exception ex)
                        {
                            // Attach the SQL query to the exception data so the API logger can pick
                            // it up
                            ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                            throw new Exception($"Exception occurred getting HandleValidationActions: {ex.Message}", ex);
                        }
                        // Handle response from the database (JSON)
                        if (dataObjectParameter.Value != null && JsonArray.Parse(dataObjectParameter.Value.ToString()) is JsonArray jsonArray)
                        {
                            foreach (var item in jsonArray.Cast<JsonObject>())
                            {
                                var propertyGuid = Guid.Parse(item["EntityPropertyGuid"].ToString());

                                // Find the matching DataProperty
                                var matchingDataProperty = dataObject.DataProperties
                                    .FirstOrDefault(dp => dp.EntityPropertyGuid == propertyGuid);

                                if (matchingDataProperty == null) continue; // Skip if no matching property

                                // Update the value based on the type in the JSON response
                                foreach (var field in item)
                                {
                                    var fieldName = field.Key;
                                    var fieldValue = field.Value;

                                    switch (fieldName)
                                    {
                                        case "DoubleValue":
                                            if (fieldValue != null && matchingDataProperty.Value?.TypeUrl == "type.googleapis.com/google.protobuf.DoubleValue")
                                            {
                                                matchingDataProperty.Value = Any.Pack(new DoubleValue { Value = (double)fieldValue });
                                            }
                                            break;

                                        case "StringValue":
                                            if (fieldValue != null && matchingDataProperty.Value?.TypeUrl == "type.googleapis.com/google.protobuf.StringValue")
                                            {
                                                matchingDataProperty.Value = Any.Pack(new StringValue { Value = fieldValue.ToString() });
                                            }
                                            break;

                                        case "IntValue":
                                            if (fieldValue != null && (matchingDataProperty.Value?.TypeUrl == "type.googleapis.com/google.protobuf.Int32Value" ||
                                                                       matchingDataProperty.Value?.TypeUrl == "type.googleapis.com/google.protobuf.Int16Value"))
                                            {
                                                matchingDataProperty.Value = Any.Pack(new Int32Value { Value = (int)fieldValue });
                                            }
                                            break;

                                        case "BigIntValue":
                                            if (fieldValue != null && matchingDataProperty.Value?.TypeUrl == "type.googleapis.com/google.protobuf.Int64Value")
                                            {
                                                matchingDataProperty.Value = Any.Pack(new Int64Value { Value = (long)fieldValue });
                                            }
                                            break;

                                        case "BitValue":
                                            if (fieldValue != null && matchingDataProperty.Value?.TypeUrl == "type.googleapis.com/google.protobuf.BoolValue")
                                            {
                                                matchingDataProperty.Value = Any.Pack(new BoolValue { Value = (bool)fieldValue });
                                            }
                                            break;

                                        case "DateTimeValue":
                                            if (fieldValue != null && matchingDataProperty.Value?.TypeUrl == "type.googleapis.com/google.protobuf.Timestamp")
                                            {
                                                matchingDataProperty.Value = Any.Pack(Timestamp.FromDateTime(DateTime.Parse(fieldValue.ToString())));
                                            }
                                            break;

                                        case "BytesValue":
                                            if (fieldValue != null && matchingDataProperty.Value?.TypeUrl == "type.googleapis.com/google.protobuf.BytesValue")
                                            {
                                                matchingDataProperty.Value = Any.Pack(new BytesValue { Value = ByteString.CopyFromUtf8(fieldValue.ToString()) });
                                            }
                                            break;

                                        default:
                                            // Handle unexpected or unsupported field types
                                            Console.WriteLine($"Unexpected field type: {fieldName}");
                                            break;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Handle DataPills
            dataObject.DataPills.Clear();
            var dataPills = await ReadDataPills(entityType, dataObject, connection, transaction);
            if (dataPills != null)
            {
                dataObject.DataPills.AddRange(dataPills);
            }
        }

        /// <summary>
        /// Loads Items for a merge document using a short-lived connection (safe for parallelism).
        /// </summary>
        private async Task<List<MergeDocumentItem>> LoadMergeDocItemsAsync(EntityType entityType, Guid mergeDocGuid)
        {
            await using var c = CreateConnection();
            await OpenConnectionAsync(c);
            await QueryBuilder.SetReadCommittedAsync(c);
            return await GetMergeDocumentItemsSequentially(entityType, c, mergeDocGuid);
        }

        /*
            Returns the Organisation Unit the user belongs to - this is based on the UserID.
         */

        private MergeDocument MapMergeDocument(SqlDataReader reader)
        {
            return new MergeDocument
            {
                RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                Name = reader.GetStringOrNull("Name"),
                EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")),
                DriveId = reader.GetStringOrNull("DriveId"),
                DocumentId = reader.GetStringOrNull("DocumentId"),
                LinkedEntityTypeGuid = reader.GetGuid(reader.GetOrdinal("LinkedEntityTypeGuid")),
                FilenameTemplate = reader.GetStringOrNull("FilenameTemplate"),
                AllowPDFOnly = reader.GetBoolean(reader.GetOrdinal("AllowPDFOutputOnly")),
                AllowExcelOutputOnly = reader.GetBoolean(reader.GetOrdinal("AllowExcelOutputOnly")),
                ProduceOneOutputPerRow = reader.GetBoolean(reader.GetOrdinal("ProduceOneOutputPerRow")),
                Items = new List<MergeDocumentItem>() // Initialize child items
            };
        }

        private EF.Types.MergeDocumentItem MapMergeDocumentItem(SqlDataReader reader)
        {
            return new EF.Types.MergeDocumentItem
            {
                Guid = reader.GetGuid(reader.GetOrdinal("Guid")),
                MergeDocumentItemType = reader.GetStringOrNull("MergeDocumentItemType"),
                BookmarkName = reader.GetStringOrNull("BookmarkName"),
                EntityType = reader.GetStringOrNull("EntityType"),
                EntityTypeGuid = reader.GetGuid(reader.GetOrdinal("EntityTypeGuid")),
                LinkedEntityTypeGuid = reader.GetGuid(reader.GetOrdinal("LinkedEntityTypeGuid")),
                SubFolderPath = reader.GetStringOrNull("SubFolderPath"),
                ImageColumns = reader.GetSafeValue<int>("ImageColumns"),
                RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion")))
            };
        }

        private EF.Types.MergeDocumentItemInclude MapMergeDocumentItemInclude(SqlDataReader reader)
        {
            return new EF.Types.MergeDocumentItemInclude
            {
                Guid = reader.GetGuidOrEmpty(reader.GetOrdinal("Guid").ToString()),
                SortOrder = reader.GetInt32(reader.GetOrdinal("SortOrder")),
                SourceDocumentEntityProperty = reader.GetStringOrNull("SourceDocumentEntityProperty"),
                SourceSharePointItemEntityProperty = reader.GetStringOrNull("SourceSharePointItemEntityProperty"),
                IncludedMergeDocument = reader.GetStringOrNull("IncludedMergeDocument"),
                MergeDocumentItemGuid = reader.GetGuidOrEmpty(reader.GetOrdinal("MergeDocumentItemGuid").ToString()),
                RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion")))
            };
        }

        private EF.Types.MergeDocumentItemType MapMergeDocumentItemType(SqlDataReader reader)
        {
            return new EF.Types.MergeDocumentItemType
            {
                Id = reader.GetInt16(reader.GetOrdinal("ID")),
                Guid = reader.GetGuidOrEmpty(reader.GetOrdinal("Guid").ToString()),
                RowStatus = (Enums.RowStatus)reader.GetByte(reader.GetOrdinal("RowStatus")),
                RowVersion = Convert.ToBase64String(reader.GetFieldValue<byte[]>(reader.GetOrdinal("RowVersion"))),
                Name = reader.GetString(reader.GetOrdinal("Name")),
                IsImageType = reader.GetBoolean(reader.GetOrdinal("IsImageType"))
            };
        }

        private async Task PerformUpsert(
    DataObjectUpsertRequest request,
    DataObject dataObject,
    EntityType entityType,
    EntityHoBT entityHoBT,
    SqlConnection connection,
    SqlTransaction transaction)
        {
            EntityQuery query = null;

            foreach (var eq in entityType.EntityQueries.Where(eq => eq.EntityHoBTGuid == entityHoBT.Guid))
            {
                // Match the exact EntityQueryGuid
                if (eq.Guid == request.EntityQueryGuid)
                {
                    query = eq;
                    break;
                }
                // Match the default create query when Guid is empty
                if (request.DataObject.Guid == Guid.Empty && eq.IsDefaultCreate && request.EntityQueryGuid == Guid.Empty)
                {
                    query = eq;
                    break;
                }
                // Match the default update query when Guid is not empty
                if (request.DataObject.Guid != Guid.Empty && eq.IsDefaultUpdate && request.EntityQueryGuid == Guid.Empty)
                {
                    query = eq;
                    break;
                }
            }

            if (query == null)
            {
                throw new InvalidOperationException("No valid query found for the upsert operation.");
            }
            //        var query = entityType.EntityQueries.FirstOrDefault(eq =>
            //eq.EntityHoBTGuid == entityHoBT.Guid && (
            //    eq.Guid == request.EntityQueryGuid || // Exact match on EntityQueryGuid
            //    (request.DataObject.Guid == Guid.Empty && eq.IsDefaultCreate && request.EntityQueryGuid == Guid.Empty) || // Create case
            //    (request.DataObject.Guid != Guid.Empty && eq.IsDefaultUpdate && request.EntityQueryGuid == Guid.Empty) // Update case
            //));

            // if (query == null) { throw new InvalidOperationException("No valid query found for
            // the upsert operation."); }

            using var command = QueryBuilder.BuildCommandForEntityQuery(
                query, dataObject, request.EntityQueryParameterValues.ToList(), connection, transaction);
            await command.ExecuteScalarAsync();

            if (entityType.HasDocuments)
            {
                const string docQuery = "EXEC SCore.UpsertObjectSharePointPath @ObjectGuid, @SharePointSiteIdentifier, @FolderPath";
                using var docCommand = QueryBuilder.CreateCommand(docQuery, connection, transaction);
                docCommand.Parameters.AddWithValue("@ObjectGuid", dataObject.Guid);
                docCommand.Parameters.AddWithValue("@SharePointSiteIdentifier", dataObject.SharePointSiteIdentifier);
                docCommand.Parameters.AddWithValue("@FolderPath", dataObject.SharePointFolderPath);
                await docCommand.ExecuteScalarAsync();
            }
        }

        private async Task PopulateAdditionalDetails(SqlConnection connection, EntityType entityType, DataObject dataObject, Guid objectGuid)
        {
            var swTotal = Stopwatch.StartNew();

            // Helper: run a function with its own short-lived connection (parallel-safe)
            async Task<T> WithConnection<T>(Func<SqlConnection, Task<T>> work)
            {
                await using var c = CreateConnection();
                await OpenConnectionAsync(c);
                await QueryBuilder.SetReadCommittedAsync(c); // pairs well with RCSI
                return await work(c);
            }

            // Helper: time any async lambda and log its duration
            async Task<T> Timed<T>(string name, Func<Task<T>> func)
            {
                var sw = Stopwatch.StartNew();
                var result = await func();
                sw.Stop();
                Console.WriteLine($"[PopulateAdditionalDetails] {name} took {sw.ElapsedMilliseconds} ms");
                return result;
            }

            // Kick off all independent reads IN PARALLEL on separate connections
            var pillsTask = Timed("ReadDataPills", () =>
                WithConnection(c => ReadDataPills(entityType, dataObject, c, null)));

            var progressTask = Timed("ReadProgressData", () =>
                WithConnection(c => ReadProgressData(entityType, dataObject, c, null)));

            var mergeDocsTask = Timed("ReadMergeDocumentsWithChildren", () =>
                WithConnection(c => ReadMergeDocumentsWithChildren(entityType, c, null)));

            var actionsTask = Timed("ReadActionMenuItems", () =>
                WithConnection(c => ReadActionMenuItems(entityType, c, null)));

            var objectSecurityTask = Timed("ObjectSecurity", async () =>
            {
                var list = new List<ObjectSecurity>();
                const string sql = "SELECT ID, UserIdentity, GroupIdentity, CanRead, DenyRead, CanWrite, DenyWrite FROM SCore.tvf_ObjectSecurityForObject (@Guid, @UserId)";
                return await WithConnection(async c =>
                {
                    using var cmd = QueryBuilder.CreateCommand(sql, c);
                    cmd.CommandTimeout = 120; // harmless if you’ve centralized timeouts
                    cmd.Parameters.Add(new SqlParameter("@Guid", objectGuid));
                    cmd.Parameters.Add(new SqlParameter("@UserId", _userId));
                    try
                    {
                        using var reader = await cmd.ExecuteReaderAsync();
                        while (await reader.ReadAsync())
                        {
                            list.Add(new ObjectSecurity
                            {
                                Id = reader.GetInt64(reader.GetOrdinal("ID")),
                                UserIdentity = reader.GetString(reader.GetOrdinal("UserIdentity")) ?? "",
                                GroupIdentity = reader.GetString(reader.GetOrdinal("GroupIdentity")) ?? "",
                                CanRead = reader.GetBoolean(reader.GetOrdinal("DenyRead")) ? false : reader.GetBoolean(reader.GetOrdinal("CanRead")),
                                CanWrite = reader.GetBoolean(reader.GetOrdinal("DenyWrite")) ? false : reader.GetBoolean(reader.GetOrdinal("CanWrite"))
                            });
                        }
                        return list;
                    }
                    catch (Exception ex)
                    {
                        ex.Data["SQL"] = BuildSqlWithParams(cmd.CommandText, cmd.Parameters.Cast<SqlParameter>().ToArray());
                        throw new Exception($"Exception occurred getting PopulateAdditionalDetails: {ex.Message}", ex);
                    }
                });
            });

            // Await all tasks together (propagates any exception with full stack)
            await Task.WhenAll(pillsTask, progressTask, mergeDocsTask, actionsTask, objectSecurityTask);

            // ----------------------- Apply business logic and assign results back to dataObject -----------------------

            var dataPills = pillsTask.Result;
            if (dataPills != null)
            {
                // Existing business rule: Remove "No Client Appointment Received" pill for CDM jobs
                // where job type != PD/CON/PRE
                string jobEntityType = "63542427-46ab-4078-abd1-1d583c24315c"; // Job entity type
                string jobOrgUnitEntityType = "01a848d9-15b6-486c-8e6d-08e891dfbe30"; // Org unit property guid
                string CDMOrgUnit = "2C9489BD-EAE8-4703-90D7-56C94E802EDA";

                if (dataObject.EntityTypeGuid.ToString().Equals(jobEntityType, StringComparison.OrdinalIgnoreCase))
                {
                    var jobOrgUnitProp = dataObject.DataProperties
                        .FirstOrDefault(x => x.EntityPropertyGuid.ToString().Equals(jobOrgUnitEntityType, StringComparison.OrdinalIgnoreCase))?.Value;

                    var jobOrgUnitGuid = jobOrgUnitProp?.Unpack<StringValue>()?.Value?.ToUpperInvariant();

                    if (jobOrgUnitGuid == CDMOrgUnit)
                    {
                        string[] rolesForNoClientAppointmentReceived =
                        [
                            "3B2BB359-D4DA-417E-8D0D-78C82F0EE043", // CDM-PD
                    "AFFB3DA2-EDD8-42A5-A481-8E4AA5A73EC1", // CMD-CON
                    "57832995-708D-4B9C-8172-07BD94A3EBCA", // CDM-PRE
                ];

                        var jobTypeProp = dataObject.DataProperties
                            .FirstOrDefault(x => x.EntityPropertyGuid.ToString().Equals("39bdadbd-0e5c-48f0-82f5-07f240f1d3bd", StringComparison.OrdinalIgnoreCase))?.Value;

                        var jobType = jobTypeProp?.Unpack<StringValue>()?.Value?.ToUpperInvariant();

                        if (!string.IsNullOrEmpty(jobType) && !rolesForNoClientAppointmentReceived.Contains(jobType))
                        {
                            var pill = dataPills.FirstOrDefault(x => x.Value == "No Client Appointment Received");
                            if (pill != null) dataPills.Remove(pill);
                        }
                    }
                }

                dataObject.DataPills.AddRange(dataPills);
            }

            var progressData = progressTask.Result;
            if (progressData != null)
                dataObject.ProgressData = progressData;

            var mergeDocuments = mergeDocsTask.Result;
            if (mergeDocuments != null)
                dataObject.MergeDocuments = mergeDocuments;

            var actionMenuItems = actionsTask.Result;
            if (actionMenuItems != null)
                dataObject.ActionMenuItems = actionMenuItems;

            dataObject.ObjectSecurity = objectSecurityTask.Result ?? new List<ObjectSecurity>();

            swTotal.Stop();
            Console.WriteLine($"[PopulateAdditionalDetails] TOTAL {swTotal.ElapsedMilliseconds} ms for object {objectGuid}");
        }

        private async Task PopulateSharePointDetails(SqlConnection connection, Guid objectGuid, DataObject dataObject)
        {
            var sharepointStatement = "SELECT SharePointSiteIdentifier, FolderPath, FullSharePointUrl FROM SCore.ObjectSharePointPaths WHERE (ObjectGuid = @ObjectGuid)";

            using (var command = QueryBuilder.CreateCommand(sharepointStatement, connection))
            {
                command.Parameters.Add(new SqlParameter("@ObjectGuid", objectGuid.ToString()));

                try
                {
                    using var reader = await command.ExecuteReaderAsync();
                    while (await reader.ReadAsync())
                    {
                        dataObject.SharePointSiteIdentifier = reader.GetString(reader.GetOrdinal("SharePointSiteIdentifier"));
                        dataObject.SharePointFolderPath = reader.GetString(reader.GetOrdinal("FolderPath"));
                        dataObject.SharePointUrl = reader.GetString(reader.GetOrdinal("FullSharePointUrl"));
                    }
                }
                catch (Exception ex)
                {
                    // Attach the SQL query to the exception data so the API logger can pick it up
                    ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                    throw new Exception($"Exception occurred getting PopulateSharePointDetails: {ex.Message}", ex);
                }
            }
        }

        private static void ApplyTransientVirtualProperties(
    DataObject dataObject,
    EntityType entityType,
    EntityHoBT hobt,
    Dictionary<string, Google.Protobuf.WellKnownTypes.Any>? transientVirtualProperties)
        {
            if (dataObject == null || transientVirtualProperties == null || transientVirtualProperties.Count == 0)
            {
                return;
            }

            var hobtProperties = entityType.EntityProperties
                .Where(x => x.EntityHoBTGuid == hobt.Guid)
                .ToList();

            foreach (var kvp in transientVirtualProperties)
            {
                var entityProperty = hobtProperties.FirstOrDefault(x =>
                    string.Equals(x.Name, kvp.Key, StringComparison.OrdinalIgnoreCase));

                if (entityProperty == null)
                {
                    continue;
                }

                var dataProperty = dataObject.DataProperties
                    .FirstOrDefault(x => x.EntityPropertyGuid == entityProperty.Guid);

                if (dataProperty == null)
                {
                    dataProperty = new DataProperty
                    {
                        EntityPropertyGuid = entityProperty.Guid,
                        IsEnabled = true,
                        IsHidden = entityProperty.IsHidden,
                        IsInvalid = false,
                        IsReadOnly = entityProperty.IsReadOnly,
                        IsRestricted = false,
                        IsVirtual = entityProperty.IsVirtual,
                        ValidationMessage = string.Empty
                    };

                    dataObject.DataProperties.Add(dataProperty);
                }

                dataProperty.Value = kvp.Value;
                dataProperty.IsVirtual = entityProperty.IsVirtual;
                dataProperty.IsHidden = entityProperty.IsHidden;
                dataProperty.IsReadOnly = entityProperty.IsReadOnly;
            }
        }

        private async Task<DataObject> ReadEntityHoBT(SqlConnection connection, DataObject dataObject, EntityType entityType, EntityHoBT hobt, Guid requestQueryGuid, Guid requestGuid, bool ForInformationView, Dictionary<string, Google.Protobuf.WellKnownTypes.Any>? transientVirtualProperties = null)
        {
            try
            {
                EntityQuery readQuery = new();
                EntityQuery validationQuery;

                // get the read and validation queries for the HoBT
                foreach (EntityQuery eq in entityType.EntityQueries.Where(q => q.EntityHoBTGuid == hobt.Guid))
                {
                    if (eq.Guid == requestQueryGuid)
                    {
                        readQuery = eq;
                    }
                    else if (eq.IsDefaultRead == true && requestQueryGuid == Guid.Empty)
                    {
                        readQuery = eq;
                    }
                    else if (eq.IsDefaultValidation == true)
                    {
                        validationQuery = eq;
                    }
                }

                // Read the data from the data object
                if (readQuery.Guid != Guid.Empty)
                {
                    string statement = (readQuery.Statement.Contains("WHERE")) ? readQuery.Statement[..readQuery.Statement.IndexOf("WHERE")] : readQuery.Statement;
                    string statementPredicate = "";

                    if (readQuery.Statement.Contains("ORDER BY"))
                    {
                        throw new Exception("Entity Framework Pre-Validation Error; The Entity Query cannot include the 'ORDER BY' clause.");
                    }

                    if (readQuery.Statement.Contains("OFFSET"))
                    {
                        throw new Exception("Entity Framework Pre-Validation Error; The Entity Query cannot include the 'OFFSET' clause.");
                    }

                    Guid guidParameterGuid = Guid.Parse("B8FE15643BC4478B9CDE0F2B5FF6F503");
                    List<DataObjectCompositeFilter> dataObjectCompositeFilters = new();
                    DataObjectCompositeFilter dataObjectCompositeFilter = new();
                    dataObjectCompositeFilter.Filters.Add(new DataObjectFilter()
                    {
                        ColumnName = "[root_hobt].[Guid]",
                        Operator = "eq",
                        Guid = guidParameterGuid,
                        Value = new() { StringValue = requestGuid.ToString() },
                    });
                    dataObjectCompositeFilters.Add(dataObjectCompositeFilter);

                    statementPredicate = DataObjectCompositeFilterListToPredicate(readQuery.Statement, dataObjectCompositeFilters);

                    try
                    {
                        using (var command = QueryBuilder.CreateCommand(statement + statementPredicate, connection))
                        {
                            var parameters = DataObjectCompositeFilterListToSqlParameterList(dataObjectCompositeFilters).ToArray();
                            command.Parameters.AddRange(parameters);

                            try
                            {
                                using (var reader = await command.ExecuteReaderAsync())
                                {
                                    while (await reader.ReadAsync())
                                    {
                                        for (int i = 0; i < reader.FieldCount; i++)
                                        {
                                            dataObject = ReadEntityProperty(reader, dataObject, i, entityType, hobt.Guid, ForInformationView, hobt.IsMainHoBT);
                                        }
                                    }
                                }

                                /*
                                    Ensure all metadata-defined properties exist on the DataObject before validation runs.
                                    This is essential for virtual properties because they are not returned by the HoBT read query.
                                */
                                await EnsureAllEntityPropertiesMaterialisedAsync(
                                        dataObject,
                                        entityType,
                                        hobt,
                                        requestGuid);

                                ApplyTransientVirtualProperties(
                                    dataObject,
                                    entityType,
                                    hobt,
                                    transientVirtualProperties);
                            }
                            catch (Exception ex)
                            {
                                ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, parameters);
                                throw new Exception($"Exception occurred getting ReadEntityHoBT: {ex.Message}", ex);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        var outer = new Exception($"Error executing read query for HoBT '{hobt.ObjectName}': {ex.Message}", ex);
                        foreach (var key in ex.Data.Keys)
                        {
                            outer.Data[key] = ex.Data[key];
                        }
                        throw outer;
                    }

                    try
                    {
                        // Get the validation results from the temp table.
                        List<Types.ValidationResult> validationResults = await Validation.RunObjectValidation(entityType, dataObject, connection, hobt);
                        Validation.ApplyValidationResults(ref dataObject, true, entityType, validationResults, hobt.Guid, ForInformationView);
                    }
                    catch (Exception ex)
                    {
                        throw new Exception("Exception occured while running object validation : " + ex.Message);
                    }
                }
                else
                {
                    throw new Exception("No read query was found for the entity type " + entityType.Name);
                }

                // before returning the object, ensure we got values for all the properties.
                foreach (EntityProperty property in entityType.EntityProperties.Where(ep => ep.EntityHoBTGuid == hobt.Guid))
                {
                    if (property.Name.ToLower() == "rowstatus")
                    { Console.WriteLine($"Row Status '{dataObject.RowStatus}'"); }
                    if (property.Name.ToLower() == "rowstatus" && dataObject.RowStatus == 0)
                    {
                        throw new Exception("No data returned for the RowStatus or the RowStatus was 0.");
                    }
                    else if (property.Name.ToLower() == "rowversion" && dataObject.RowVersion == "")
                    {
                        throw new Exception("No data returned for the Row Version.");
                    }
                    else if (property.Name.ToLower() == "guid" && dataObject.Guid == Guid.Empty)
                    {
                        throw new Exception("No data returned for the record Guid.");
                    }
                    else if (property.IsVirtual)
                    {
                        if (!dataObject.DataProperties.Any(dp => dp.EntityPropertyGuid == property.Guid))
                        {
                            StringValue stringValue = new() { Value = "" };
                            dataObject.DataProperties.Add(
                                new DataProperty
                                {
                                    EntityPropertyGuid = property.Guid,
                                    IsEnabled = true,
                                    IsHidden = property.IsHidden,
                                    IsInvalid = false,
                                    IsReadOnly = property.IsReadOnly,
                                    IsRestricted = false,
                                    ValidationMessage = "",
                                    Value = Any.Pack(stringValue),
                                    IsVirtual = true
                                }
                            );
                        }
                    }
                    else
                    {
                        if ((dataObject.DataProperties.Where(dp => dp.EntityPropertyGuid == property.Guid).Any() == false)
                            && (property.Name.ToLower() != "guid")
                            && (property.Name.ToLower() != "rowversion")
                            && (property.Name.ToLower() != "rowstatus")
                            && (property.Name.ToLower() != "id")
                            && (!property.IsVirtual)) //4. OE: CBLD-497

                        {
                            throw new Exception($"No data returned for property {property.Name}.");
                        }
                    }
                }

                return dataObject;
            }
            catch (Exception ex)
            {
                throw new Exception($"Error reading HoBT {hobt.ObjectName} : {ex.Message}.");
            }
        }

        private async Task EnsureAllEntityPropertiesMaterialisedAsync(
    DataObject dataObject,
    EntityType entityType,
    EntityHoBT hobt,
    Guid requestGuid)
        {
            var propertiesForHobt = entityType.EntityProperties
                .Where(p => p.EntityHoBTGuid == hobt.Guid)
                .ToList();

            foreach (var entityProperty in propertiesForHobt)
            {
                var existing = dataObject.DataProperties
                    .FirstOrDefault(dp => dp.EntityPropertyGuid == entityProperty.Guid);

                if (existing != null)
                {
                    /*
                        Keep the DataProperty aligned with metadata.
                        This is especially important for virtual properties because they may not
                        have come from the SQL reader at all.
                    */
                    existing.IsVirtual = entityProperty.IsVirtual;
                    continue;
                }

                var newProperty = new DataProperty
                {
                    EntityPropertyGuid = entityProperty.Guid,
                    IsVirtual = entityProperty.IsVirtual,
                    IsHidden = entityProperty.IsHidden,
                    IsReadOnly = entityProperty.IsReadOnly,
                    IsInvalid = false,
                    ValidationMessage = string.Empty
                };

                SetObjectSecurity(entityProperty.ObjectSecurity.FirstOrDefault(), newProperty);

                if (!newProperty.IsEnabled)
                {
                    dataObject.DataProperties.Add(newProperty);
                    continue;
                }

                object? defaultValue = null;

                try
                {
                    defaultValue = await GetEntityPropertyDefault(
                        entityProperty,
                        ParentGuid: Guid.Empty,
                        RecordGuid: requestGuid);
                }
                catch
                {
                    /*
                        Do not fail object loading just because a default could not be resolved.
                        Leave the property present with an empty value so validation can still bind it.
                    */
                    defaultValue = null;
                }

                newProperty.Value = BuildAnyValueForEntityProperty(entityProperty, defaultValue);

                dataObject.DataProperties.Add(newProperty);
            }
        }

        private static Any BuildAnyValueForEntityProperty(EntityProperty entityProperty, object? value)
        {
            var typeName = (entityProperty.EntityDataTypeName ?? string.Empty).Trim().ToLowerInvariant();

            if (value == null || value == DBNull.Value)
            {
                return typeName switch
                {
                    "bool" or "boolean" or "bit" => Any.Pack(new BoolValue { Value = false }),
                    "int" => Any.Pack(new Int32Value { Value = 0 }),
                    "smallint" => Any.Pack(new Int32Value { Value = 0 }),
                    "bigint" => Any.Pack(new Int64Value { Value = 0 }),
                    "decimal" or "numeric" or "money" or "smallmoney" or "double" or "float" => Any.Pack(new DoubleValue { Value = 0d }),
                    "date" or "datetime" or "datetime2" => Any.Pack(new Empty()),
                    _ => Any.Pack(new StringValue { Value = string.Empty })
                };
            }

            try
            {
                return typeName switch
                {
                    "bool" or "boolean" or "bit" => Any.Pack(new BoolValue
                    {
                        Value = value is bool b ? b : Convert.ToBoolean(value)
                    }),

                    "int" => Any.Pack(new Int32Value
                    {
                        Value = value is int i ? i : Convert.ToInt32(value)
                    }),

                    "smallint" => Any.Pack(new Int32Value
                    {
                        Value = value is short s ? s : Convert.ToInt32(value)
                    }),

                    "bigint" => Any.Pack(new Int64Value
                    {
                        Value = value is long l ? l : Convert.ToInt64(value)
                    }),

                    "decimal" or "numeric" or "money" or "smallmoney" or "double" or "float" => Any.Pack(new DoubleValue
                    {
                        Value = value is double d ? d : Convert.ToDouble(value)
                    }),

                    "date" or "datetime" or "datetime2" => Any.Pack(
                        Timestamp.FromDateTime(
                            DateTime.SpecifyKind(Convert.ToDateTime(value), DateTimeKind.Utc))
                    ),

                    _ => Any.Pack(new StringValue
                    {
                        Value = Convert.ToString(value) ?? string.Empty
                    })
                };
            }
            catch
            {
                return typeName switch
                {
                    "bool" or "boolean" or "bit" => Any.Pack(new BoolValue { Value = false }),
                    "int" or "smallint" => Any.Pack(new Int32Value { Value = 0 }),
                    "bigint" => Any.Pack(new Int64Value { Value = 0 }),
                    "decimal" or "numeric" or "money" or "smallmoney" or "double" or "float" => Any.Pack(new DoubleValue { Value = 0d }),
                    "date" or "datetime" or "datetime2" => Any.Pack(new Empty()),
                    _ => Any.Pack(new StringValue { Value = string.Empty })
                };
            }
        }

        private async Task<DataObject> ReQueryObject(DataObject dataObject, DataObjectUpsertRequest request)
        {
            return await DataObjectGet(
                dataObject.Guid,
                request.EntityQueryGuid,
                dataObject.EntityTypeGuid,
                false);
        }

        private async Task UpsertDocuments(DataObject dataObject, SqlConnection connection, SqlTransaction transaction)
        {
            string query = @"
                EXEC SCore.UpsertObjectSharePointPath
                @ObjectGuid = @ObjectGuid,
                @SharePointSiteIdentifier = @SharePointSiteIdentifier,
                @FolderPath = @FolderPath";

            await using var command = QueryBuilder.CreateCommand(query, connection, transaction);
            command.Parameters.Add(new SqlParameter("@ObjectGuid", dataObject.Guid));
            command.Parameters.Add(new SqlParameter("@SharePointSiteIdentifier", dataObject.SharePointSiteIdentifier));
            command.Parameters.Add(new SqlParameter("@FolderPath", dataObject.SharePointFolderPath));

            await command.ExecuteScalarAsync();
        }

        private async Task<bool> ValidateRowVersion(
                                                                                                                                                                                                                                                                                                                                                                                                                                                                    DataObject dataObject,
            EntityType entityType,
            SqlConnection connection,
            SqlTransaction transaction)
        {
            return await Validation.CheckRowVersionMatches(
                entityType,
                dataObject.RowVersion,
                dataObject.Guid,
                connection,
                transaction);
        }

        /*
         * [OE] - [CBLD-259]
         *
         * Turns the dataobject into JSON format.
         *
         * **/

        private async Task WriteDatabaseLog(string severity, string message, string innerMessage, string stackTrace)
        {
            using (SqlConnection sqlConnection = new(_connectionString))
            {
                await sqlConnection.OpenAsync();

                using (SqlTransaction sqlTransaction = sqlConnection.BeginTransaction())
                {
                    string statement = "EXECUTE SCore.SystemLogCreate " +
                        "@DateTime = @DateTime, @Severity = @Severity, @Message = @Message, @InnerMessage = @InnerMessage, @StackTrace= @StackTrace, @ProcessGuid = @ProcessGuid, @UserId = @UserId, @ThreadId = @ThreadId";

                    using (var command = sqlConnection.CreateCommand())
                    {
                        command.Transaction = sqlTransaction;
                        command.CommandText = statement;

                        command.Parameters.Add(new SqlParameter("DateTime", DateTime.Now));
                        command.Parameters.Add(new SqlParameter("Severity", severity));
                        command.Parameters.Add(new SqlParameter("Message", message));
                        command.Parameters.Add(new SqlParameter("InnerMessage", innerMessage));
                        command.Parameters.Add(new SqlParameter("StackTrace", stackTrace));
                        command.Parameters.Add(new SqlParameter("ProcessGuid", Guid.Empty));
                        command.Parameters.Add(new SqlParameter("UserId", _userId));
                        command.Parameters.Add(new SqlParameter("ThreadId", 0));
                        try
                        {
                            await command.ExecuteNonQueryAsync();
                        }
                        catch (Exception ex)
                        {
                            // Attach the SQL query to the exception data so the API logger can pick
                            // it up
                            ex.Data["SQL"] = BuildSqlWithParams(command.CommandText, command.Parameters.Cast<SqlParameter>().ToArray());
                            throw new Exception($"Exception occurred getting WriteDatabaseLog: {ex.Message}", ex);
                        }
                    }

                    await sqlTransaction.CommitAsync();
                }
            }
        }

        #endregion Private Methods
    }

    public sealed record JobInvoiceScheduleRow(
    long Id,
    Guid Guid,
    string Name,
    string DescriptionOfWork,
    decimal Amount,
    string TriggerId,
    DateTime? ExpectedDateUtc
);
}