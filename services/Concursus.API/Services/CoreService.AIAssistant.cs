using Concursus.API.Core;
using Concursus.API.Services.AIAssistant;
using Grpc.Core;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Text;
using System.Text.Json;

namespace Concursus.API.Services;

[Authorize]
public partial class CoreService
{
    private static readonly JsonSerializerOptions AIAssistantJsonOptions = new(JsonSerializerDefaults.Web);
    public override async Task<AIAssistantConversationCreateResponse> AIAssistantConversationCreate(
        AIAssistantConversationCreateRequest request,
        ServerCallContext context)
    {
        var response = new AIAssistantConversationCreateResponse();

        try
        {
            if (request.UserId <= 0)
            {
                response.ErrorReturned = "A valid user is required.";
                return response;
            }

            if (string.IsNullOrWhiteSpace(request.Title))
            {
                response.ErrorReturned = "A conversation title is required.";
                return response;
            }

            var conversationGuid = Guid.NewGuid();

            await using var cn = await OpenSqlAsync(context.CancellationToken);
            await using var cmd = new SqlCommand("SAi.AssistantConversationUpsert", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 120
            };

            cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = request.UserId });
            cmd.Parameters.Add(new SqlParameter("@Title", SqlDbType.NVarChar, 250) { Value = request.Title.Trim() });
            cmd.Parameters.Add(new SqlParameter("@ModeCode", SqlDbType.NVarChar, 20) { Value = NormaliseAssistantMode(request.ModeCode) });
            cmd.Parameters.Add(new SqlParameter("@LanguageCode", SqlDbType.NVarChar, 20) { Value = DbValue(request.LanguageCode) });
            cmd.Parameters.Add(new SqlParameter("@IsPinned", SqlDbType.Bit) { Value = false });
            cmd.Parameters.Add(new SqlParameter("@IsArchived", SqlDbType.Bit) { Value = false });
            cmd.Parameters.Add(new SqlParameter("@StartedFromWorkflowTemplateGuid", SqlDbType.UniqueIdentifier)
            {
                Value = TryParseGuidOrNull(request.StartedFromWorkflowTemplateGuid)
            });

            var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
            {
                Direction = ParameterDirection.InputOutput,
                Value = conversationGuid
            };
            cmd.Parameters.Add(guidParameter);

            await cmd.ExecuteNonQueryAsync(context.CancellationToken);

            response.Conversation = await ReadAssistantConversationAsync(
                cn,
                conversationGuid,
                request.UserId,
                context.CancellationToken);

            return response;
        }
        catch (SqlException ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantConversationCreate SQL failed.");
            response.ErrorReturned = $"AI assistant conversation create SQL failed: {ex.Message}";
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantConversationCreate failed.");
            response.ErrorReturned = $"AI assistant conversation create failed: {ex.Message}";
            return response;
        }
    }

    public override async Task<AIAssistantConversationListResponse> AIAssistantConversationList(
        AIAssistantConversationListRequest request,
        ServerCallContext context)
    {
        var response = new AIAssistantConversationListResponse();

        try
        {
            if (request.UserId <= 0)
            {
                response.ErrorReturned = "A valid user is required.";
                return response;
            }

            await using var cn = await OpenSqlAsync(context.CancellationToken);
            await using var cmd = new SqlCommand(@"
SELECT
    root_hobt.Guid,
    root_hobt.UserId,
    root_hobt.Title,
    root_hobt.ModeCode,
    root_hobt.LanguageCode,
    root_hobt.LastActivityUtc,
    root_hobt.IsPinned,
    root_hobt.IsArchived,
    root_hobt.LastMessagePlainText
FROM SAi.tvf_AssistantConversationList(@UserId) AS root_hobt
WHERE (@IncludeArchived = 1 OR root_hobt.IsArchived = 0)
ORDER BY root_hobt.IsPinned DESC, root_hobt.LastActivityUtc DESC;", cn)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 120
            };

            cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = request.UserId });
            cmd.Parameters.Add(new SqlParameter("@IncludeArchived", SqlDbType.Bit) { Value = request.IncludeArchived });

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);

            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.Conversations.Add(MapConversation(reader));
            }

            return response;
        }
        catch (SqlException ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantConversationList SQL failed.");
            response.ErrorReturned = $"AI assistant conversation list SQL failed: {ex.Message}";
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantConversationList failed.");
            response.ErrorReturned = $"AI assistant conversation list failed: {ex.Message}";
            return response;
        }
    }

    public override async Task<AIAssistantMessageListResponse> AIAssistantMessageList(
        AIAssistantMessageListRequest request,
        ServerCallContext context)
    {
        var response = new AIAssistantMessageListResponse();

        try
        {
            if (!Guid.TryParse(request.ConversationGuid, out var conversationGuid))
            {
                response.ErrorReturned = "A valid conversation Guid is required.";
                return response;
            }

            await using var cn = await OpenSqlAsync(context.CancellationToken);
            await using var cmd = new SqlCommand(@"
SELECT
    root_hobt.Guid,
    root_hobt.ConversationGuid,
    root_hobt.UserId,
    root_hobt.MessageRoleCode,
    root_hobt.AnswerTypeCode,
    root_hobt.ContentMarkdown,
    root_hobt.ContentPlainText,
    root_hobt.CreatedUtc,
    root_hobt.ConfidenceScore,
    root_hobt.SourcePayloadJson,
    root_hobt.ModelCode
FROM SAi.tvf_AssistantConversationMessages(@ConversationGuid) AS root_hobt
ORDER BY root_hobt.CreatedUtc ASC;", cn)
            {
                CommandType = CommandType.Text,
                CommandTimeout = 120
            };

            cmd.Parameters.Add(new SqlParameter("@ConversationGuid", SqlDbType.UniqueIdentifier) { Value = conversationGuid });

            await using var reader = await cmd.ExecuteReaderAsync(context.CancellationToken);

            while (await reader.ReadAsync(context.CancellationToken))
            {
                response.Messages.Add(MapMessage(reader));
            }

            return response;
        }
        catch (SqlException ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantMessageList SQL failed.");
            response.ErrorReturned = $"AI assistant message list SQL failed: {ex.Message}";
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantMessageList failed.");
            response.ErrorReturned = $"AI assistant message list failed: {ex.Message}";
            return response;
        }
    }

    public override async Task<AIAssistantMessageSendResponse> AIAssistantMessageSend(
    AIAssistantMessageSendRequest request,
    ServerCallContext context)
    {
        var response = new AIAssistantMessageSendResponse();

        try
        {
            if (request.UserId <= 0)
            {
                response.ErrorReturned = "A valid user is required.";
                return response;
            }

            if (!Guid.TryParse(request.ConversationGuid, out var conversationGuid))
            {
                response.ErrorReturned = "A valid conversation Guid is required.";
                return response;
            }

            if (string.IsNullOrWhiteSpace(request.Message))
            {
                response.ErrorReturned = "A message is required.";
                return response;
            }

            var userText = request.Message.Trim();
            var requestedAttachmentCount = CountDistinctValidAssistantUploadGuids(request.AttachedUploadGuids);
            Guid userMessageGuid;
            List<AIAssistantKnowledgeSearchRow> knowledgeItems;
            IReadOnlyList<BlueGenFileReference> attachedFiles;

            await using (var cn = await OpenSqlAsync(context.CancellationToken))
            {
                userMessageGuid = await InsertAssistantMessageAsync(
                    cn,
                    conversationGuid,
                    request.UserId,
                    "USER",
                    string.Empty,
                    userText,
                    userText,
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    context.CancellationToken);

                knowledgeItems = IsLikelyCymBuildQuestion(userText)
                    ? await SearchAssistantKnowledgeRowsAsync(
                        cn,
                        userText,
                        null,
                        publishedOnly: true,
                        authoritativeFirst: true,
                        context.CancellationToken)
                    : new List<AIAssistantKnowledgeSearchRow>();

                attachedFiles = await ReadBlueGenFileReferencesAsync(
                    cn,
                    request.UserId,
                    request.AttachedUploadGuids,
                    context.CancellationToken);
            }

            AIAssistantGeneratedAnswer answer;

            if (requestedAttachmentCount > 0 && attachedFiles.Count == 0)
            {
                answer = BuildAttachmentUnavailableAssistantAnswer(userText, requestedAttachmentCount);
            }
            else if (_aiAssistantAnswerService is null)
            {
                answer = BuildBlueGenUnavailableAssistantAnswer(
                    userText,
                    knowledgeItems,
                    attachedFiles,
                    new InvalidOperationException("The BlueGen assistant answer service is not registered."));
            }
            else
            {
                try
                {
                    var generated = await _aiAssistantAnswerService.GenerateAnswerAsync(
                        userText,
                        NormaliseAssistantMode(request.ModeCode),
                        string.IsNullOrWhiteSpace(request.LanguageCode) ? null : request.LanguageCode.Trim(),
                        knowledgeItems.Select(x => x.Item).ToList(),
                        attachedFiles,
                        context.CancellationToken);

                    answer = new AIAssistantGeneratedAnswer(
                        generated.AnswerTypeCode,
                        generated.ContentMarkdown,
                        generated.ContentPlainText,
                        generated.ConfidenceScore,
                        generated.SourcesJson,
                        generated.FollowUpsJson,
                        generated.Sources,
                        generated.FollowUps,
                        generated.ModelCode);
                }
                catch (Exception ex)
                {
                    _serviceBase.logger.LogException(ex, "BlueGen answer generation failed. Returning explicit BlueGen unavailable response.");

                    answer = BuildBlueGenUnavailableAssistantAnswer(
                        userText,
                        knowledgeItems,
                        attachedFiles,
                        ex);
                }
            }

            await using (var cn = await OpenSqlAsync(context.CancellationToken))
            {
                var assistantMessageGuid = await InsertAssistantMessageAsync(
                    cn,
                    conversationGuid,
                    request.UserId,
                    "ASSISTANT",
                    answer.AnswerTypeCode,
                    answer.ContentMarkdown,
                    answer.ContentPlainText,
                    answer.SourcesJson,
                    answer.FollowUpsJson,
                    answer.ConfidenceScore,
                    null,
                    answer.ModelCode,
                    userMessageGuid,
                    context.CancellationToken);

                response.UserMessage = await ReadAssistantMessageAsync(
                    cn,
                    userMessageGuid,
                    context.CancellationToken);

                response.AssistantMessage = await ReadAssistantMessageAsync(
                    cn,
                    assistantMessageGuid,
                    context.CancellationToken);

                response.Sources.AddRange(answer.Sources);
                response.FollowUps.AddRange(answer.FollowUps);

                try
                {
                    var analyticsPayloadJson = BuildAssistantAnswerAnalyticsPayloadJson(userText, answer, attachedFiles);

                    await InsertAssistantAnalyticsEventAsync(
                        cn,
                        request.UserId,
                        conversationGuid,
                        "QUESTION_ASKED",
                        userText,
                        analyticsPayloadJson,
                        true,
                        context.CancellationToken);
                }
                catch (Exception ex)
                {
                    _serviceBase.logger.LogException(ex, "AI assistant analytics event insert failed. Message send will continue.");
                }
            }

            return response;
        }
        catch (SqlException ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantMessageSend SQL failed.");
            response.ErrorReturned = $"AI assistant message send SQL failed: {ex.Message}";
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantMessageSend failed.");
            response.ErrorReturned = $"AI assistant message send failed: {ex.Message}";
            return response;
        }
    }


    private static int CountDistinctValidAssistantUploadGuids(IEnumerable<string> uploadGuids)
    {
        return uploadGuids
            .Where(value => Guid.TryParse(value, out var guid) && guid != Guid.Empty)
            .Select(value => Guid.Parse(value))
            .Distinct()
            .Count();
    }

    private static bool IsLikelyCymBuildQuestion(string question)
    {
        if (string.IsNullOrWhiteSpace(question))
        {
            return false;
        }

        var terms = ExtractMeaningfulTerms(question);

        if (terms.Count == 0)
        {
            return false;
        }

        var cymBuildTerms = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "cymbuild",
            "enquiry",
            "enquiries",
            "quote",
            "quotes",
            "job",
            "jobs",
            "milestone",
            "milestones",
            "activity",
            "activities",
            "invoice",
            "invoices",
            "schedule",
            "schedules",
            "permission",
            "permissions",
            "user",
            "users",
            "group",
            "groups",
            "workflow",
            "status",
            "transition",
            "approve",
            "approval",
            "authorise",
            "authorisation",
            "merge",
            "document",
            "documents",
            "sharepoint",
            "sage",
            "client",
            "account",
            "contact",
            "project",
            "riba",
            "fee",
            "proposal",
            "service",
            "services",
            "product",
            "products",
            "price",
            "batch",
            "transaction",
            "transactions",
            "outlook",
            "email",
            "emails",
            "folder",
            "folders"
        };

        if (terms.Any(cymBuildTerms.Contains))
        {
            return true;
        }

        var lower = question.ToLowerInvariant();

        return lower.Contains("how do i create", StringComparison.Ordinal)
            || lower.Contains("how do i add", StringComparison.Ordinal)
            || lower.Contains("how do i approve", StringComparison.Ordinal)
            || lower.Contains("why can't i", StringComparison.Ordinal)
            || lower.Contains("why cant i", StringComparison.Ordinal)
            || lower.Contains("what happens next", StringComparison.Ordinal)
            || lower.Contains("what should i do next", StringComparison.Ordinal);
    }

    public override async Task<AIAssistantKnowledgeSearchResponse> AIAssistantKnowledgeSearch(
        AIAssistantKnowledgeSearchRequest request,
        ServerCallContext context)
    {
        var response = new AIAssistantKnowledgeSearchResponse();

        try
        {
            await using var cn = await OpenSqlAsync(context.CancellationToken);

            var rows = await SearchAssistantKnowledgeRowsAsync(
                cn,
                request.SearchText ?? string.Empty,
                string.IsNullOrWhiteSpace(request.CategoryGuid) ? null : request.CategoryGuid,
                request.PublishedOnly,
                request.AuthoritativeFirst,
                context.CancellationToken);

            response.Items.AddRange(rows.Select(x => x.Item));
            return response;
        }
        catch (SqlException ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantKnowledgeSearch SQL failed.");
            response.ErrorReturned = $"AI assistant knowledge search SQL failed: {ex.Message}";
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantKnowledgeSearch failed.");
            response.ErrorReturned = $"AI assistant knowledge search failed: {ex.Message}";
            return response;
        }
    }

    public override async Task<AIAssistantBookmarkCreateResponse> AIAssistantBookmarkCreate(
        AIAssistantBookmarkCreateRequest request,
        ServerCallContext context)
    {
        var response = new AIAssistantBookmarkCreateResponse();

        try
        {
            if (request.UserId <= 0)
            {
                response.ErrorReturned = "A valid user is required.";
                return response;
            }

            if (!Guid.TryParse(request.ConversationGuid, out var conversationGuid))
            {
                response.ErrorReturned = "A valid conversation Guid is required.";
                return response;
            }

            if (!Guid.TryParse(request.MessageGuid, out var messageGuid))
            {
                response.ErrorReturned = "A valid message Guid is required.";
                return response;
            }

            var bookmarkGuid = Guid.NewGuid();

            await using var cn = await OpenSqlAsync(context.CancellationToken);
            await using var cmd = new SqlCommand("SAi.AssistantBookmarkUpsert", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 120
            };

            cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = request.UserId });
            cmd.Parameters.Add(new SqlParameter("@ConversationGuid", SqlDbType.UniqueIdentifier) { Value = conversationGuid });
            cmd.Parameters.Add(new SqlParameter("@MessageGuid", SqlDbType.UniqueIdentifier) { Value = messageGuid });
            cmd.Parameters.Add(new SqlParameter("@Title", SqlDbType.NVarChar, 250)
            {
                Value = string.IsNullOrWhiteSpace(request.Title) ? "Saved assistant answer" : request.Title.Trim()
            });
            cmd.Parameters.Add(new SqlParameter("@Notes", SqlDbType.NVarChar, -1) { Value = DbValue(request.Notes) });
            cmd.Parameters.Add(new SqlParameter("@TagsJson", SqlDbType.NVarChar, -1) { Value = DbValue(request.TagsJson) });

            var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
            {
                Direction = ParameterDirection.InputOutput,
                Value = bookmarkGuid
            };
            cmd.Parameters.Add(guidParameter);

            await cmd.ExecuteNonQueryAsync(context.CancellationToken);

            response.BookmarkGuid = bookmarkGuid.ToString();
            return response;
        }
        catch (SqlException ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantBookmarkCreate SQL failed.");
            response.ErrorReturned = $"AI assistant bookmark create SQL failed: {ex.Message}";
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantBookmarkCreate failed.");
            response.ErrorReturned = $"AI assistant bookmark create failed: {ex.Message}";
            return response;
        }
    }

    public override async Task<AIAssistantFeedbackCreateResponse> AIAssistantFeedbackCreate(
        AIAssistantFeedbackCreateRequest request,
        ServerCallContext context)
    {
        var response = new AIAssistantFeedbackCreateResponse();

        try
        {
            if (request.UserId <= 0)
            {
                response.ErrorReturned = "A valid user is required.";
                return response;
            }

            if (!Guid.TryParse(request.ConversationGuid, out var conversationGuid))
            {
                response.ErrorReturned = "A valid conversation Guid is required.";
                return response;
            }

            if (!Guid.TryParse(request.MessageGuid, out var messageGuid))
            {
                response.ErrorReturned = "A valid message Guid is required.";
                return response;
            }

            var feedbackCode = NormaliseFeedbackCode(request.FeedbackCode);
            if (string.IsNullOrWhiteSpace(feedbackCode))
            {
                response.ErrorReturned = "Feedback must be helpful or unhelpful.";
                return response;
            }

            var feedbackGuid = Guid.NewGuid();

            await using var cn = await OpenSqlAsync(context.CancellationToken);
            await using var cmd = new SqlCommand("SAi.AssistantFeedbackCreate", cn)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 120
            };

            cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = request.UserId });
            cmd.Parameters.Add(new SqlParameter("@ConversationGuid", SqlDbType.UniqueIdentifier) { Value = conversationGuid });
            cmd.Parameters.Add(new SqlParameter("@MessageGuid", SqlDbType.UniqueIdentifier) { Value = messageGuid });
            cmd.Parameters.Add(new SqlParameter("@FeedbackCode", SqlDbType.NVarChar, 20) { Value = feedbackCode });
            cmd.Parameters.Add(new SqlParameter("@Comment", SqlDbType.NVarChar, -1) { Value = DbValue(request.Comment) });

            var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
            {
                Direction = ParameterDirection.InputOutput,
                Value = feedbackGuid
            };
            cmd.Parameters.Add(guidParameter);

            await cmd.ExecuteNonQueryAsync(context.CancellationToken);

            response.FeedbackGuid = feedbackGuid.ToString();
            return response;
        }
        catch (SqlException ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantFeedbackCreate SQL failed.");
            response.ErrorReturned = $"AI assistant feedback create SQL failed: {ex.Message}";
            return response;
        }
        catch (Exception ex)
        {
            _serviceBase.logger.LogException(ex, "AIAssistantFeedbackCreate failed.");
            response.ErrorReturned = $"AI assistant feedback create failed: {ex.Message}";
            return response;
        }
    }

    private static AIAssistantConversation MapConversation(SqlDataReader reader)
    {
        return new AIAssistantConversation
        {
            Guid = Convert.ToString(reader["Guid"]) ?? string.Empty,
            UserId = Convert.ToInt32(reader["UserId"]),
            Title = Convert.ToString(reader["Title"]) ?? string.Empty,
            ModeCode = Convert.ToString(reader["ModeCode"]) ?? string.Empty,
            LanguageCode = Convert.ToString(reader["LanguageCode"]) ?? string.Empty,
            LastActivityUtc = FormatUtc(reader["LastActivityUtc"]),
            IsPinned = Convert.ToBoolean(reader["IsPinned"]),
            IsArchived = Convert.ToBoolean(reader["IsArchived"]),
            LastMessagePreview = Convert.ToString(reader["LastMessagePlainText"]) ?? string.Empty
        };
    }

    private static AIAssistantMessage MapMessage(SqlDataReader reader)
    {
        var messageRoleCode = Convert.ToString(reader["MessageRoleCode"]) ?? string.Empty;
        var answerTypeCode = Convert.ToString(reader["AnswerTypeCode"]) ?? string.Empty;
        var sourcePayloadJson = HasColumn(reader, "SourcePayloadJson")
            ? Convert.ToString(reader["SourcePayloadJson"]) ?? string.Empty
            : string.Empty;
        var modelCode = HasColumn(reader, "ModelCode")
            ? Convert.ToString(reader["ModelCode"]) ?? string.Empty
            : string.Empty;

        var usedBlueGenUnavailable = string.Equals(answerTypeCode, "BLUEGEN_UNAVAILABLE", StringComparison.OrdinalIgnoreCase);
        var usedBlueGen = !usedBlueGenUnavailable && IsAssistantBlueGenModel(modelCode);
        var usedInternalKnowledge = AssistantMessageUsesKnowledge(answerTypeCode, sourcePayloadJson);
        var usedAttachments = AssistantMessageUsesAttachments(sourcePayloadJson);
        var provenanceCode = usedBlueGenUnavailable
            ? "BLUEGEN_UNAVAILABLE"
            : BuildAssistantProvenanceCode(usedBlueGen, usedInternalKnowledge, usedAttachments);

        return new AIAssistantMessage
        {
            Guid = Convert.ToString(reader["Guid"]) ?? string.Empty,
            ConversationGuid = Convert.ToString(reader["ConversationGuid"]) ?? string.Empty,
            UserId = Convert.ToInt32(reader["UserId"]),
            MessageRoleCode = messageRoleCode,
            AnswerTypeCode = answerTypeCode,
            ContentMarkdown = Convert.ToString(reader["ContentMarkdown"]) ?? string.Empty,
            ContentPlainText = Convert.ToString(reader["ContentPlainText"]) ?? string.Empty,
            CreatedUtc = FormatUtc(reader["CreatedUtc"]),
            ConfidenceScore = reader["ConfidenceScore"] == DBNull.Value ? 0d : Convert.ToDouble(reader["ConfidenceScore"]),
            ModelCode = modelCode,
            ProvenanceCode = provenanceCode,
            ProvenanceLabel = BuildAssistantProvenanceLabel(provenanceCode, messageRoleCode),
            UsedBlueGen = usedBlueGen,
            UsedInternalKnowledge = usedInternalKnowledge,
            UsedAttachments = usedAttachments
        };
    }

    private async Task<AIAssistantConversation> ReadAssistantConversationAsync(
        SqlConnection cn,
        Guid conversationGuid,
        int userId,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
SELECT
    root_hobt.Guid,
    root_hobt.UserId,
    root_hobt.Title,
    root_hobt.ModeCode,
    root_hobt.LanguageCode,
    root_hobt.LastActivityUtc,
    root_hobt.IsPinned,
    root_hobt.IsArchived,
    root_hobt.LastMessagePlainText
FROM SAi.tvf_AssistantConversationList(@UserId) AS root_hobt
WHERE root_hobt.Guid = @ConversationGuid;", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 120
        };

        cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });
        cmd.Parameters.Add(new SqlParameter("@ConversationGuid", SqlDbType.UniqueIdentifier) { Value = conversationGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new InvalidOperationException("AI assistant conversation was created but could not be reloaded.");
        }

        return MapConversation(reader);
    }

    private async Task<AIAssistantMessage> ReadAssistantMessageAsync(
        SqlConnection cn,
        Guid messageGuid,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(@"
SELECT
    root_hobt.Guid,
    root_hobt.ConversationGuid,
    root_hobt.UserId,
    root_hobt.MessageRoleCode,
    root_hobt.AnswerTypeCode,
    root_hobt.ContentMarkdown,
    root_hobt.ContentPlainText,
    root_hobt.CreatedUtc,
    root_hobt.ConfidenceScore,
    root_hobt.SourcePayloadJson,
    root_hobt.ModelCode
FROM SAi.AssistantMessages AS m
JOIN SAi.AssistantConversations AS c ON c.ID = m.ConversationId
CROSS APPLY
(
    SELECT
        m.Guid,
        c.Guid AS ConversationGuid,
        m.UserId,
        m.MessageRoleCode,
        m.AnswerTypeCode,
        m.ContentMarkdown,
        m.ContentPlainText,
        m.CreatedUtc,
        m.ConfidenceScore,
        m.SourcePayloadJson,
        m.ModelCode
) AS root_hobt
WHERE m.Guid = @MessageGuid
  AND m.RowStatus NOT IN (0, 254)
  AND c.RowStatus NOT IN (0, 254);", cn)
        {
            CommandType = CommandType.Text,
            CommandTimeout = 120
        };

        cmd.Parameters.Add(new SqlParameter("@MessageGuid", SqlDbType.UniqueIdentifier) { Value = messageGuid });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new InvalidOperationException("AI assistant message was created but could not be reloaded.");
        }

        return MapMessage(reader);
    }

    private async Task<Guid> InsertAssistantMessageAsync(
        SqlConnection cn,
        Guid conversationGuid,
        int userId,
        string messageRoleCode,
        string? answerTypeCode,
        string contentMarkdown,
        string contentPlainText,
        string? sourcePayloadJson,
        string? followUpPayloadJson,
        double? confidenceScore,
        int? promptTokens,
        string? modelCode,
        Guid? parentMessageGuid,
        CancellationToken cancellationToken)
    {
        var messageGuid = Guid.NewGuid();

        await using var cmd = new SqlCommand("SAi.AssistantMessageCreate", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 120
        };

        cmd.Parameters.Add(new SqlParameter("@ConversationGuid", SqlDbType.UniqueIdentifier) { Value = conversationGuid });
        cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId });
        cmd.Parameters.Add(new SqlParameter("@MessageRoleCode", SqlDbType.NVarChar, 20) { Value = messageRoleCode });
        cmd.Parameters.Add(new SqlParameter("@AnswerTypeCode", SqlDbType.NVarChar, 30) { Value = DbValue(answerTypeCode) });
        cmd.Parameters.Add(new SqlParameter("@ContentMarkdown", SqlDbType.NVarChar, -1) { Value = contentMarkdown });
        cmd.Parameters.Add(new SqlParameter("@ContentPlainText", SqlDbType.NVarChar, -1) { Value = contentPlainText });
        cmd.Parameters.Add(new SqlParameter("@SourcePayloadJson", SqlDbType.NVarChar, -1) { Value = DbValue(sourcePayloadJson) });
        cmd.Parameters.Add(new SqlParameter("@FollowUpPayloadJson", SqlDbType.NVarChar, -1) { Value = DbValue(followUpPayloadJson) });
        cmd.Parameters.Add(new SqlParameter("@ConfidenceScore", SqlDbType.Decimal)
        {
            Precision = 5,
            Scale = 4,
            Value = confidenceScore.HasValue ? Math.Round((decimal)confidenceScore.Value, 4) : DBNull.Value
        });
        cmd.Parameters.Add(new SqlParameter("@PromptTokens", SqlDbType.Int) { Value = promptTokens.HasValue ? promptTokens.Value : DBNull.Value });
        cmd.Parameters.Add(new SqlParameter("@CompletionTokens", SqlDbType.Int) { Value = DBNull.Value });
        cmd.Parameters.Add(new SqlParameter("@ModelCode", SqlDbType.NVarChar, 100) { Value = DbValue(modelCode) });
        cmd.Parameters.Add(new SqlParameter("@ParentMessageGuid", SqlDbType.UniqueIdentifier)
        {
            Value = parentMessageGuid.HasValue ? parentMessageGuid.Value : DBNull.Value
        });

        var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
        {
            Direction = ParameterDirection.InputOutput,
            Value = messageGuid
        };
        cmd.Parameters.Add(guidParameter);

        await cmd.ExecuteNonQueryAsync(cancellationToken);

        return messageGuid;
    }

    private async Task<List<AIAssistantKnowledgeSearchRow>> SearchAssistantKnowledgeRowsAsync(
    SqlConnection cn,
    string searchText,
    string? categoryGuid,
    bool publishedOnly,
    bool authoritativeFirst,
    CancellationToken cancellationToken)
    {
        var rows = new List<AIAssistantKnowledgeSearchRow>();

        await using var cmd = new SqlCommand("SAi.AssistantKnowledgeSearch", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 120
        };

        cmd.Parameters.Add(new SqlParameter("@SearchText", SqlDbType.NVarChar, 1000)
        {
            Value = string.IsNullOrWhiteSpace(searchText) ? string.Empty : searchText.Trim()
        });

        cmd.Parameters.Add(new SqlParameter("@CategoryGuid", SqlDbType.UniqueIdentifier)
        {
            Value = Guid.TryParse(categoryGuid, out var parsedCategoryGuid)
                ? parsedCategoryGuid
                : DBNull.Value
        });

        cmd.Parameters.Add(new SqlParameter("@PublishedOnly", SqlDbType.Bit)
        {
            Value = publishedOnly
        });

        cmd.Parameters.Add(new SqlParameter("@AuthoritativeFirst", SqlDbType.Bit)
        {
            Value = authoritativeFirst
        });

        cmd.Parameters.Add(new SqlParameter("@Top", SqlDbType.Int)
        {
            Value = 5
        });

        cmd.Parameters.Add(new SqlParameter("@MinimumScore", SqlDbType.Int)
        {
            Value = 80
        });

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            var item = new AIAssistantKnowledgeItem
            {
                Guid = Convert.ToString(reader["Guid"]) ?? string.Empty,
                Title = Convert.ToString(reader["Title"]) ?? string.Empty,
                Slug = Convert.ToString(reader["Slug"]) ?? string.Empty,
                CategoryName = Convert.ToString(reader["CategoryName"]) ?? string.Empty,
                ContentTypeCode = Convert.ToString(reader["ContentTypeCode"]) ?? string.Empty,
                SourceTypeCode = Convert.ToString(reader["SourceTypeCode"]) ?? string.Empty,
                StorageUrl = Convert.ToString(reader["StorageUrl"]) ?? string.Empty,
                PreviewUrl = Convert.ToString(reader["PreviewUrl"]) ?? string.Empty,
                Summary = Convert.ToString(reader["Summary"]) ?? string.Empty,
                IsAuthoritative = reader["IsAuthoritative"] != DBNull.Value && Convert.ToBoolean(reader["IsAuthoritative"]),
                IsPublished = reader["IsPublished"] != DBNull.Value && Convert.ToBoolean(reader["IsPublished"]),
                CurrentVersionNumber = reader["VersionNumber"] == DBNull.Value ? 0 : Convert.ToInt32(reader["VersionNumber"])
            };

            var matchScore = reader["MatchScore"] == DBNull.Value
            ? 0
            : Convert.ToInt32(reader["MatchScore"]);

                    rows.Add(new AIAssistantKnowledgeSearchRow(
                        item,
                        Convert.ToString(reader["ExtractedText"]) ?? string.Empty,
                        matchScore));
                }

        return rows;
    }

    private async Task InsertAssistantAnalyticsEventAsync(
        SqlConnection cn,
        int? userId,
        Guid? conversationGuid,
        string eventTypeCode,
        string? topicText,
        string? payloadJson,
        bool? successFlag,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand("SAi.AssistantAnalyticsEventCreate", cn)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 120
        };

        cmd.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = userId.HasValue ? userId.Value : DBNull.Value });
        cmd.Parameters.Add(new SqlParameter("@ConversationGuid", SqlDbType.UniqueIdentifier) { Value = conversationGuid.HasValue ? conversationGuid.Value : DBNull.Value });
        cmd.Parameters.Add(new SqlParameter("@EventTypeCode", SqlDbType.NVarChar, 50) { Value = eventTypeCode });
        cmd.Parameters.Add(new SqlParameter("@TopicText", SqlDbType.NVarChar, 1000) { Value = DbValue(topicText) });
        cmd.Parameters.Add(new SqlParameter("@PayloadJson", SqlDbType.NVarChar, -1) { Value = DbValue(payloadJson) });
        cmd.Parameters.Add(new SqlParameter("@SuccessFlag", SqlDbType.Bit) { Value = successFlag.HasValue ? successFlag.Value : DBNull.Value });

        var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
        {
            Direction = ParameterDirection.InputOutput,
            Value = Guid.NewGuid()
        };
        cmd.Parameters.Add(guidParameter);

        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private static AIAssistantGeneratedAnswer BuildDeterministicAssistantAnswer(
        string userQuestion,
        string modeCode,
        IReadOnlyList<AIAssistantKnowledgeSearchRow> knowledgeRows,
        IReadOnlyList<BlueGenFileReference>? attachedFiles = null)
    {
        var safeAttachedFiles = attachedFiles ?? Array.Empty<BlueGenFileReference>();
        var topRows = knowledgeRows
            .OrderByDescending(row => row.Item.IsAuthoritative)
            .ThenByDescending(row => row.MatchScore)
            .Take(5)
            .ToList();

        var sources = topRows.Select(row => new AIAssistantSource
        {
            Title = row.Item.Title,
            TypeCode = row.Item.ContentTypeCode,
            Url = !string.IsNullOrWhiteSpace(row.Item.PreviewUrl)
                ? row.Item.PreviewUrl
                : row.Item.StorageUrl,
            KnowledgeItemGuid = row.Item.Guid,
            VersionNumber = row.Item.CurrentVersionNumber,
            Excerpt = BuildExcerpt(row),
            IsAuthoritative = row.Item.IsAuthoritative
        }).ToList();

        sources.AddRange(safeAttachedFiles.Select(file => new AIAssistantSource
        {
            Title = string.IsNullOrWhiteSpace(file.FileName) ? "Attached file" : $"Attached: {file.FileName}",
            TypeCode = "ATTACHMENT",
            Url = file.Url,
            KnowledgeItemGuid = string.Empty,
            VersionNumber = 0,
            Excerpt = string.IsNullOrWhiteSpace(file.ContentType) ? "User attachment" : file.ContentType,
            IsAuthoritative = false
        }));

        var confidenceScore = CalculateDeterministicConfidence(userQuestion, topRows);
        if (topRows.Count == 0 && safeAttachedFiles.Count > 0)
        {
            confidenceScore = 0.5500d;
        }

        var answerType = topRows.Count > 0 && confidenceScore >= 0.80d
            ? "TRUSTED_KNOWLEDGE"
            : safeAttachedFiles.Count > 0 ? "ATTACHMENT_RECEIVED" : "GENERATED_SUGGESTION";


        var answer = new StringBuilder();

        answer.AppendLine("CymBuild assistant");
        answer.AppendLine();

        if (topRows.Count > 0)
        {
            var top = topRows[0];

            var topContent = !string.IsNullOrWhiteSpace(top.ExtractedText)
                ? top.ExtractedText
                : top.Item.Summary;

            var matchDescription = confidenceScore >= 0.80d
                ? "best matching source"
                : "closest related source";

            answer.AppendLine($"Based on the CymBuild knowledge base, the {matchDescription} is: {top.Item.Title}.");
            answer.AppendLine();

            var steps = IsProceduralQuestion(userQuestion)
                ? BuildKnowledgeSteps(topContent)
                : Array.Empty<string>();

            if (steps.Count >= 2)
            {
                answer.AppendLine("Steps");
                answer.AppendLine();

                for (var i = 0; i < steps.Count; i++)
                {
                    answer.AppendLine($"{i + 1}. {steps[i]}");
                }

                answer.AppendLine();
            }
            else
            {
                answer.AppendLine("Guidance");
                answer.AppendLine();

                answer.AppendLine(BuildKnowledgeSummary(topContent));
                answer.AppendLine();

                if (IsProceduralQuestion(userQuestion))
                {
                    answer.AppendLine("I found related CymBuild knowledge, but the imported document did not contain a clean step-by-step section that I can safely reproduce.");
                    answer.AppendLine("Please open the source document below for the original training material.");
                    answer.AppendLine();
                }
            }

            if (string.Equals(modeCode, "BEGINNER", StringComparison.OrdinalIgnoreCase))
            {
                answer.AppendLine("Plain language explanation");
                answer.AppendLine();
                answer.AppendLine("This answer is based on published CymBuild help material. The source link below opens the original training document if you need to check the full detail.");
                answer.AppendLine();
            }

            answer.AppendLine("Source");
            answer.AppendLine();
            answer.AppendLine($"- {top.Item.Title}");
            answer.AppendLine($"- Confidence: {Math.Round(confidenceScore * 100, 0)}%");
            answer.AppendLine($"- Match score: {top.MatchScore}");

            if (top.Item.IsAuthoritative)
            {
                answer.AppendLine("- Source status: Authoritative");
            }

            answer.AppendLine();

            if (topRows.Count > 1)
            {
                answer.AppendLine("Related sources");
                answer.AppendLine();

                foreach (var related in topRows.Skip(1))
                {
                    answer.AppendLine($"- {related.Item.Title} ({related.MatchScore})");
                }

                answer.AppendLine();
            }
        }
        else
        {
            if (!IsLikelyCymBuildQuestion(userQuestion) && safeAttachedFiles.Count == 0)
            {
                answer.AppendLine("I can help with CymBuild questions, but this does not look like a CymBuild-related request.");
                answer.AppendLine();
                answer.AppendLine("Try asking about a CymBuild process, screen, workflow status, permission, quote, job, enquiry, invoice, document, or SharePoint task.");
            }
            else if (safeAttachedFiles.Count > 0)
            {
                answer.AppendLine("I received your attachment, but the internal fallback could not inspect the image/file content directly.");
                answer.AppendLine();
                answer.AppendLine("The attachment has still been linked to this assistant request and will show in the answer provenance. BlueGen attachment analysis is needed for screenshot description or file-content interpretation.");
            }
            else
            {
                answer.AppendLine("I could not find a strong published CymBuild knowledge match yet.");
                answer.AppendLine();
                answer.AppendLine("Suggested checks");
                answer.AppendLine();
                answer.AppendLine("1. Confirm which CymBuild screen you are on.");
                answer.AppendLine("2. Check whether the record is in the correct workflow status.");
                answer.AppendLine("3. Check whether your user has the required permission.");
                answer.AppendLine("4. Re-ask the question with the exact page name, status, or error message.");
            }
            answer.AppendLine();

        }

        if (safeAttachedFiles.Count > 0)
        {
            answer.AppendLine("Attachment context");
            answer.AppendLine();
            answer.AppendLine($"- {safeAttachedFiles.Count} attachment(s) were received and linked to this assistant request.");
            answer.AppendLine("- The internal fallback can record and pass attachment references, but it cannot safely inspect image content without the BlueGen attachment analysis provider completing successfully.");
            answer.AppendLine("- If you asked about a screenshot, retry once BlueGen is available or include the visible error/text in the question.");
            answer.AppendLine();
        }

        answer.AppendLine("Your question");
        answer.AppendLine();
        answer.AppendLine(userQuestion);

        var followUps = new List<AIAssistantFollowUp>
    {
        new() { Text = "Turn this into a checklist", Prompt = "Turn this answer into a short checklist." },
        new() { Text = "Explain the likely blockers", Prompt = "What are the likely blockers for this in CymBuild?" },
        new() { Text = "Show the admin view", Prompt = "Explain this from an admin/support perspective." }
    };

        var answerText = answer.ToString();

        return new AIAssistantGeneratedAnswer(
            answerType,
            answerText,
            StripMarkdown(answerText),
            confidenceScore,
            JsonSerializer.Serialize(sources, AIAssistantJsonOptions),
            JsonSerializer.Serialize(followUps, AIAssistantJsonOptions),
            sources,
            followUps,
            "deterministic");
    }



    private static AIAssistantGeneratedAnswer BuildBlueGenUnavailableAssistantAnswer(
        string userQuestion,
        IReadOnlyList<AIAssistantKnowledgeSearchRow> knowledgeRows,
        IReadOnlyList<BlueGenFileReference>? attachedFiles,
        Exception exception)
    {
        var safeAttachedFiles = attachedFiles ?? Array.Empty<BlueGenFileReference>();
        var topRows = knowledgeRows
            .OrderByDescending(row => row.Item.IsAuthoritative)
            .ThenByDescending(row => row.MatchScore)
            .Take(3)
            .ToList();

        var sources = new List<AIAssistantSource>
        {
            new()
            {
                Title = "BlueGen provider did not complete",
                TypeCode = "BLUEGEN_ERROR",
                Url = string.Empty,
                KnowledgeItemGuid = string.Empty,
                VersionNumber = 0,
                Excerpt = SanitiseProviderDiagnostic(exception),
                IsAuthoritative = false
            }
        };

        sources.AddRange(safeAttachedFiles.Select(file => new AIAssistantSource
        {
            Title = string.IsNullOrWhiteSpace(file.FileName) ? "Attached file" : $"Attached: {file.FileName}",
            TypeCode = "ATTACHMENT",
            Url = file.Url,
            KnowledgeItemGuid = string.Empty,
            VersionNumber = 0,
            Excerpt = string.IsNullOrWhiteSpace(file.ContentType) ? "User attachment" : file.ContentType,
            IsAuthoritative = false
        }));

        var followUps = new List<AIAssistantFollowUp>
        {
            new() { Text = "Retry with BlueGen", Prompt = "Retry this question using BlueGen and the same CymBuild context." },
            new() { Text = "Show support checks", Prompt = "What should support check when BlueGen is unavailable in CymBuild?" },
            new() { Text = "Use visible screen text", Prompt = "I will paste the visible screen text instead. Help me with this CymBuild screen." }
        };

        var answer = new StringBuilder();
        answer.AppendLine("CymBuild assistant");
        answer.AppendLine();
        answer.AppendLine("BlueGen was selected for this assistant answer, but it did not return a usable response.");
        answer.AppendLine();
        answer.AppendLine("I have not silently replaced the BlueGen answer with an internal knowledge answer, so the provenance is clear.");
        answer.AppendLine();
        answer.AppendLine("Diagnostic");
        answer.AppendLine();
        answer.AppendLine($"- Provider status: BlueGen unavailable");
        answer.AppendLine($"- Error: {SanitiseProviderDiagnostic(exception)}");

        if (topRows.Count > 0)
        {
            answer.AppendLine($"- CymBuild knowledge context prepared: {topRows.Count} source(s)");
            answer.AppendLine($"- Best context source: {topRows[0].Item.Title} ({topRows[0].MatchScore})");
        }
        else
        {
            answer.AppendLine("- CymBuild knowledge context prepared: none");
        }

        answer.AppendLine($"- Attachment references prepared: {safeAttachedFiles.Count}");
        answer.AppendLine();
        answer.AppendLine("What to check next");
        answer.AppendLine();
        answer.AppendLine("1. Confirm the API environment has the BlueGen settings populated.");
        answer.AppendLine("2. Check the API logs for the BlueGen token/chat request status at the time of this question.");
        answer.AppendLine("3. If the provider returned a non-standard response shape, update the BlueGen response parser rather than falling back internally.");
        answer.AppendLine("4. Retry the same question once BlueGen is available.");
        answer.AppendLine();
        answer.AppendLine("Your question");
        answer.AppendLine();
        answer.AppendLine(userQuestion);

        var answerText = answer.ToString();

        return new AIAssistantGeneratedAnswer(
            "BLUEGEN_UNAVAILABLE",
            answerText,
            StripMarkdown(answerText),
            0.0500d,
            JsonSerializer.Serialize(sources, AIAssistantJsonOptions),
            JsonSerializer.Serialize(followUps, AIAssistantJsonOptions),
            sources,
            followUps,
            "internal");
    }

    private static string SanitiseProviderDiagnostic(Exception exception)
    {
        var diagnostic = exception.GetType().Name;

        if (!string.IsNullOrWhiteSpace(exception.Message))
        {
            diagnostic += $": {exception.Message}";
        }

        diagnostic = diagnostic
            .Replace("\r", " ", StringComparison.Ordinal)
            .Replace("\n", " ", StringComparison.Ordinal)
            .Replace("\t", " ", StringComparison.Ordinal);

        diagnostic = System.Text.RegularExpressions.Regex.Replace(
            diagnostic,
            @"(?i)(password|pwd|secret|token|authorization)\s*[:=]\s*[^,;\s]+",
            "$1=***");

        return diagnostic.Length <= 500
            ? diagnostic
            : diagnostic[..500] + "...";
    }

    private static AIAssistantGeneratedAnswer BuildAttachmentUnavailableAssistantAnswer(
        string userQuestion,
        int requestedAttachmentCount)
    {
        var safeRequestedAttachmentCount = Math.Max(requestedAttachmentCount, 1);

        var sources = new List<AIAssistantSource>
        {
            new()
            {
                Title = safeRequestedAttachmentCount == 1
                    ? "Attachment was selected but was not available to the assistant"
                    : $"{safeRequestedAttachmentCount} attachments were selected but were not available to the assistant",
                TypeCode = "ATTACHMENT_UNAVAILABLE",
                Url = string.Empty,
                KnowledgeItemGuid = string.Empty,
                VersionNumber = 0,
                Excerpt = "The selected attachment upload could not be resolved as an uploaded assistant file for this user.",
                IsAuthoritative = false
            }
        };

        var followUps = new List<AIAssistantFollowUp>
        {
            new() { Text = "Try again with the attachment", Prompt = "I have re-attached the screenshot/file. Please analyse it now." },
            new() { Text = "Describe the visible text", Prompt = "I will paste the visible screen text instead. Help me identify the CymBuild screen." },
            new() { Text = "Show upload checks", Prompt = "What should I check if a CymBuild assistant attachment is not being used?" }
        };

        var answer = new StringBuilder();
        answer.AppendLine("CymBuild assistant");
        answer.AppendLine();
        answer.AppendLine("I could see that an attachment was selected for this question, but the assistant could not resolve it as a completed upload.");
        answer.AppendLine();
        answer.AppendLine("What to check");
        answer.AppendLine();
        answer.AppendLine("1. Re-attach the screenshot or file and wait until it appears in the ready-to-send attachment list.");
        answer.AppendLine("2. Send the question only after the upload status shows as ready.");
        answer.AppendLine("3. If the file is large, try a smaller screenshot or image crop.");
        answer.AppendLine("4. If this keeps happening, check the assistant upload audit row and BlueGen upload response for the selected upload Guid.");
        answer.AppendLine();
        answer.AppendLine("Your question");
        answer.AppendLine();
        answer.AppendLine(userQuestion);

        var answerText = answer.ToString();

        return new AIAssistantGeneratedAnswer(
            "ATTACHMENT_UNAVAILABLE",
            answerText,
            StripMarkdown(answerText),
            0.2000d,
            JsonSerializer.Serialize(sources, AIAssistantJsonOptions),
            JsonSerializer.Serialize(followUps, AIAssistantJsonOptions),
            sources,
            followUps,
            "internal");
    }

    private static bool HasColumn(IDataRecord reader, string columnName)
    {
        for (var i = 0; i < reader.FieldCount; i++)
        {
            if (string.Equals(reader.GetName(i), columnName, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    private static bool IsAssistantBlueGenModel(string? modelCode)
    {
        if (string.IsNullOrWhiteSpace(modelCode))
        {
            return false;
        }

        return !string.Equals(modelCode.Trim(), "deterministic", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(modelCode.Trim(), "internal", StringComparison.OrdinalIgnoreCase);
    }

    private static bool AssistantMessageUsesKnowledge(string? answerTypeCode, string? sourcePayloadJson)
    {
        if (string.Equals(answerTypeCode, "TRUSTED_KNOWLEDGE", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return EnumerateAssistantSourcePayload(sourcePayloadJson)
            .Any(source =>
                !IsAssistantAttachmentSourceType(source.TypeCode)
                && !IsAssistantProviderDiagnosticSourceType(source.TypeCode)
                && (!string.IsNullOrWhiteSpace(source.KnowledgeItemGuid)
                    || !string.IsNullOrWhiteSpace(source.Title)));
    }

    private static bool AssistantMessageUsesAttachments(string? sourcePayloadJson)
    {
        return EnumerateAssistantSourcePayload(sourcePayloadJson)
            .Any(source => IsAssistantAttachmentSourceType(source.TypeCode));
    }

    private static IEnumerable<AIAssistantSource> EnumerateAssistantSourcePayload(string? sourcePayloadJson)
    {
        if (string.IsNullOrWhiteSpace(sourcePayloadJson))
        {
            return Array.Empty<AIAssistantSource>();
        }

        try
        {
            var parsedSources = JsonSerializer.Deserialize<List<AIAssistantSource>>(
                sourcePayloadJson,
                AIAssistantJsonOptions);

            return parsedSources is not null
                ? parsedSources
                : Array.Empty<AIAssistantSource>();
        }
        catch
        {
            return sourcePayloadJson.Contains("ATTACHMENT", StringComparison.OrdinalIgnoreCase)
                ? new[] { new AIAssistantSource { TypeCode = "ATTACHMENT" } }
                : Array.Empty<AIAssistantSource>();
        }
    }

    private static bool IsAssistantAttachmentSourceType(string? typeCode)
    {
        return !string.IsNullOrWhiteSpace(typeCode)
            && typeCode.Contains("ATTACHMENT", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsAssistantProviderDiagnosticSourceType(string? typeCode)
    {
        if (string.IsNullOrWhiteSpace(typeCode))
        {
            return false;
        }

        return typeCode.Contains("BLUEGEN", StringComparison.OrdinalIgnoreCase)
            || typeCode.Contains("PROVIDER", StringComparison.OrdinalIgnoreCase)
            || typeCode.Contains("DIAGNOSTIC", StringComparison.OrdinalIgnoreCase);
    }

    private static string BuildAssistantProvenanceCode(bool usedBlueGen, bool usedInternalKnowledge, bool usedAttachments)
    {
        if (usedBlueGen && usedInternalKnowledge && usedAttachments)
        {
            return "BLUEGEN_KNOWLEDGE_ATTACHMENT";
        }

        if (usedBlueGen && usedInternalKnowledge)
        {
            return "BLUEGEN_KNOWLEDGE";
        }

        if (usedBlueGen && usedAttachments)
        {
            return "BLUEGEN_ATTACHMENT";
        }

        if (usedBlueGen)
        {
            return "BLUEGEN";
        }

        if (usedInternalKnowledge && usedAttachments)
        {
            return "INTERNAL_KNOWLEDGE_ATTACHMENT";
        }

        if (usedInternalKnowledge)
        {
            return "INTERNAL_KNOWLEDGE";
        }

        if (usedAttachments)
        {
            return "INTERNAL_ATTACHMENT";
        }

        return "INTERNAL";
    }

    private static string BuildAssistantProvenanceLabel(string provenanceCode, string? messageRoleCode)
    {
        if (!string.Equals(messageRoleCode, "ASSISTANT", StringComparison.OrdinalIgnoreCase))
        {
            return string.Empty;
        }

        return provenanceCode switch
        {
            "BLUEGEN_UNAVAILABLE" => "BlueGen unavailable",
            "BLUEGEN_KNOWLEDGE_ATTACHMENT" => "BlueGen + CymBuild knowledge + attachment",
            "BLUEGEN_KNOWLEDGE" => "BlueGen + CymBuild knowledge",
            "BLUEGEN_ATTACHMENT" => "BlueGen + attachment",
            "BLUEGEN" => "BlueGen",
            "INTERNAL_KNOWLEDGE_ATTACHMENT" => "Internal knowledge + attachment",
            "INTERNAL_KNOWLEDGE" => "Internal knowledge",
            "INTERNAL_ATTACHMENT" => "Internal attachment",
            _ => "Internal response"
        };
    }

    private static string BuildAssistantAnswerAnalyticsPayloadJson(
        string userQuestion,
        AIAssistantGeneratedAnswer answer,
        IReadOnlyList<BlueGenFileReference>? attachedFiles)
    {
        var topSource = answer.Sources.Count > 0
            ? answer.Sources[0]
            : null;

        var isLikelyCymBuildQuestion = IsLikelyCymBuildQuestion(userQuestion);

        var safeAttachedFiles = attachedFiles ?? Array.Empty<BlueGenFileReference>();
        var blueGenUnavailable = string.Equals(answer.AnswerTypeCode, "BLUEGEN_UNAVAILABLE", StringComparison.OrdinalIgnoreCase);
        var usedBlueGen = !blueGenUnavailable && IsAssistantBlueGenModel(answer.ModelCode);
        var usedAttachments = safeAttachedFiles.Count > 0 || answer.Sources.Any(source => IsAssistantAttachmentSourceType(source.TypeCode));
        var usedKnowledge = answer.Sources.Any(source =>
            !IsAssistantAttachmentSourceType(source.TypeCode)
            && !IsAssistantProviderDiagnosticSourceType(source.TypeCode));
        var provenanceCode = blueGenUnavailable
            ? "BLUEGEN_UNAVAILABLE"
            : BuildAssistantProvenanceCode(usedBlueGen, usedKnowledge, usedAttachments);

        var payload = new
        {
            answerTypeCode = answer.AnswerTypeCode,
            provenanceCode,
            confidenceScore = Math.Round(answer.ConfidenceScore, 4),
            sourceCount = answer.Sources.Count,
            attachmentCount = safeAttachedFiles.Count,
            usedBlueGen,
            usedKnowledge,
            usedAttachments,
            topSourceTitle = topSource?.Title,
            topSourceTypeCode = topSource?.TypeCode,
            topSourceKnowledgeItemGuid = topSource?.KnowledgeItemGuid,
            topSourceVersionNumber = topSource?.VersionNumber,
            isTopSourceAuthoritative = topSource?.IsAuthoritative,
            hasSources = answer.Sources.Count > 0,
            isLikelyCymBuildQuestion,
            isOutOfScope = !isLikelyCymBuildQuestion && safeAttachedFiles.Count == 0,
            modelCode = answer.ModelCode ?? "deterministic",
            generatedUtc = DateTime.UtcNow
        };

        return JsonSerializer.Serialize(payload, AIAssistantJsonOptions);
    }

    private static string BuildExcerpt(AIAssistantKnowledgeSearchRow row)
    {
        var source = !string.IsNullOrWhiteSpace(row.ExtractedText)
            ? row.ExtractedText
            : row.Item.Summary;

        if (string.IsNullOrWhiteSpace(source))
        {
            return string.Empty;
        }

        source = BuildKnowledgeSummary(source);

        return source.Length <= 500
            ? source
            : source[..500];
    }

    private static double CalculateDeterministicConfidence(
    string userQuestion,
    IReadOnlyList<AIAssistantKnowledgeSearchRow> rows)
    {
        if (rows.Count == 0)
        {
            return 0.3500d;
        }

        var top = rows[0];

        var questionTerms = ExtractMeaningfulTerms(userQuestion);
        var titleTerms = ExtractMeaningfulTerms(top.Item.Title);
        var contentTerms = ExtractMeaningfulTerms(top.ExtractedText);

        var titleCoverage = CalculateCoverage(questionTerms, titleTerms);
        var contentCoverage = CalculateCoverage(questionTerms, contentTerms);

        var scoreComponent = Math.Min(top.MatchScore, 200) / 200.0d;

        var confidence =
              (scoreComponent * 0.35d)
            + (titleCoverage * 0.35d)
            + (contentCoverage * 0.20d)
            + (top.Item.IsAuthoritative ? 0.10d : 0.00d);

        return Math.Round(Math.Clamp(confidence, 0.2500d, 0.9200d), 4);
    }

    private static IReadOnlyList<string> ExtractMeaningfulTerms(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return Array.Empty<string>();
        }

        var stopWords = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "how", "do", "i", "to", "a", "an", "the", "and", "or", "of",
        "in", "on", "for", "with", "from", "this", "that", "is", "are",
        "can", "you", "please", "cymbuild", "tm", "training", "material"
    };

        return value
            .ToLowerInvariant()
            .Replace("?", " ", StringComparison.Ordinal)
            .Replace(".", " ", StringComparison.Ordinal)
            .Replace(",", " ", StringComparison.Ordinal)
            .Replace("-", " ", StringComparison.Ordinal)
            .Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(term => term.Length >= 3)
            .Where(term => !stopWords.Contains(term))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static double CalculateCoverage(
    IReadOnlyList<string> questionTerms,
    IReadOnlyList<string> candidateTerms)
    {
        if (questionTerms.Count == 0 || candidateTerms.Count == 0)
        {
            return 0.0d;
        }

        var candidateSet = candidateTerms.ToHashSet(StringComparer.OrdinalIgnoreCase);

        var matched = questionTerms.Count(candidateSet.Contains);

        return matched / (double)questionTerms.Count;
    }

    private static bool IsProceduralQuestion(string question)
    {
        if (string.IsNullOrWhiteSpace(question))
        {
            return false;
        }

        var q = question.Trim().ToLowerInvariant();

        return q.Contains("how do i", StringComparison.Ordinal)
            || q.Contains("how to", StringComparison.Ordinal)
            || q.Contains("create", StringComparison.Ordinal)
            || q.Contains("add", StringComparison.Ordinal)
            || q.Contains("set up", StringComparison.Ordinal)
            || q.Contains("setup", StringComparison.Ordinal)
            || q.Contains("configure", StringComparison.Ordinal)
            || q.Contains("merge", StringComparison.Ordinal)
            || q.Contains("permissions", StringComparison.Ordinal);
    }

    private static IReadOnlyList<string> BuildKnowledgeSteps(string content)
    {
        if (string.IsNullOrWhiteSpace(content))
        {
            return Array.Empty<string>();
        }

        var candidateLines = content
            .Replace("\r\n", "\n", StringComparison.Ordinal)
            .Replace('\r', '\n')
            .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(CleanKnowledgeLine)
            .Where(line => IsUsefulInstructionLine(line))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(7)
            .ToList();

        return candidateLines;
    }

    private static bool IsUsefulInstructionLine(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        var line = value.Trim();

        if (line.Length < 18 || line.Length > 220)
        {
            return false;
        }

        if (LooksLikeKnowledgeNoise(line))
        {
            return false;
        }

        if (LooksLikeDocumentHeading(line))
        {
            return false;
        }

        var lower = line.ToLowerInvariant();

        return lower.StartsWith("click ", StringComparison.Ordinal)
            || lower.StartsWith("select ", StringComparison.Ordinal)
            || lower.StartsWith("open ", StringComparison.Ordinal)
            || lower.StartsWith("enter ", StringComparison.Ordinal)
            || lower.StartsWith("choose ", StringComparison.Ordinal)
            || lower.StartsWith("go to ", StringComparison.Ordinal)
            || lower.StartsWith("navigate ", StringComparison.Ordinal)
            || lower.StartsWith("press ", StringComparison.Ordinal)
            || lower.StartsWith("save ", StringComparison.Ordinal)
            || lower.Contains(" click ", StringComparison.Ordinal)
            || lower.Contains(" select ", StringComparison.Ordinal)
            || lower.Contains(" enter ", StringComparison.Ordinal)
            || lower.Contains(" choose ", StringComparison.Ordinal)
            || lower.Contains(" save ", StringComparison.Ordinal);
    }

    private static bool LooksLikeDocumentHeading(string value)
    {
        var line = value.Trim();

        if (line.EndsWith("Training Material", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        if (line.Contains("Training Material", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        if (line.StartsWith("TM -", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        if (line.Count(char.IsDigit) > 0 && line.Length < 40)
        {
            return true;
        }

        var wordCount = line.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length;

        if (wordCount <= 6 && !line.EndsWith(".", StringComparison.Ordinal))
        {
            return true;
        }

        return false;
    }
    private static string BuildKnowledgeSummary(string content)
    {
        if (string.IsNullOrWhiteSpace(content))
        {
            return "The matching CymBuild source did not contain enough extracted text to produce detailed guidance.";
        }

        var lines = content
            .Replace("\r\n", "\n", StringComparison.Ordinal)
            .Replace('\r', '\n')
            .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(CleanKnowledgeLine)
            .Where(line => line.Length >= 20)
            .Where(line => !LooksLikeKnowledgeNoise(line))
            .Where(line => !LooksLikeDocumentHeading(line))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(5)
            .ToList();

        if (lines.Count == 0)
        {
            return "The matching CymBuild source was found, but the extracted text appears to contain headings, document navigation, or page labels rather than clear guidance.";
        }

        return string.Join(Environment.NewLine, lines.Select(line => $"- {line}"));
    }

    private static string CleanKnowledgeLine(string value)
    {
        var result = value.Trim();

        while (result.Length > 0
               && (result[0] == '-'
                   || result[0] == '*'
                   || result[0] == '•'))
        {
            result = result[1..].Trim();
        }

        if (result.Length > 3
            && char.IsDigit(result[0])
            && result[1] == '.')
        {
            result = result[2..].Trim();
        }

        return result;
    }

    private static bool LooksLikeKnowledgeNoise(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return true;
        }

        var v = value.Trim();

        return v.Equals("table of contents", StringComparison.OrdinalIgnoreCase)
            || v.Equals("contents", StringComparison.OrdinalIgnoreCase)
            || v.StartsWith("page ", StringComparison.OrdinalIgnoreCase)
            || v.StartsWith("http://", StringComparison.OrdinalIgnoreCase)
            || v.StartsWith("https://", StringComparison.OrdinalIgnoreCase)
            || v.Length < 10;
    }

    private static string NormaliseAssistantMode(string? modeCode)
    {
        return string.Equals(modeCode, "EXPERT", StringComparison.OrdinalIgnoreCase)
            ? "EXPERT"
            : "BEGINNER";
    }

    private static string NormaliseFeedbackCode(string? feedbackCode)
    {
        if (string.Equals(feedbackCode, "HELPFUL", StringComparison.OrdinalIgnoreCase)
            || string.Equals(feedbackCode, "helpful", StringComparison.OrdinalIgnoreCase))
        {
            return "helpful";
        }

        if (string.Equals(feedbackCode, "UNHELPFUL", StringComparison.OrdinalIgnoreCase)
            || string.Equals(feedbackCode, "unhelpful", StringComparison.OrdinalIgnoreCase))
        {
            return "unhelpful";
        }

        return string.Empty;
    }

    private static object DbValue(string? value)
    {
        return string.IsNullOrWhiteSpace(value)
            ? DBNull.Value
            : value.Trim();
    }

    private static object TryParseGuidOrNull(string? value)
    {
        return Guid.TryParse(value, out var guid) && guid != Guid.Empty
            ? guid
            : DBNull.Value;
    }

    private static string FormatUtc(object value)
    {
        if (value == DBNull.Value)
        {
            return string.Empty;
        }

        var dateTime = Convert.ToDateTime(value);
        return DateTime.SpecifyKind(dateTime, DateTimeKind.Utc).ToString("O");
    }

    private static string StripMarkdown(string markdown)
    {
        return markdown
            .Replace("###", string.Empty, StringComparison.Ordinal)
            .Replace("####", string.Empty, StringComparison.Ordinal)
            .Replace("**", string.Empty, StringComparison.Ordinal)
            .Replace("`", string.Empty, StringComparison.Ordinal)
            .Trim();
    }

    private sealed record AIAssistantKnowledgeSearchRow(
       AIAssistantKnowledgeItem Item,
       string ExtractedText,
       int MatchScore);

    private sealed record AIAssistantGeneratedAnswer(
        string AnswerTypeCode,
        string ContentMarkdown,
        string ContentPlainText,
        double ConfidenceScore,
        string SourcesJson,
        string FollowUpsJson,
        IReadOnlyList<AIAssistantSource> Sources,
        IReadOnlyList<AIAssistantFollowUp> FollowUps,
        string? ModelCode);
}
