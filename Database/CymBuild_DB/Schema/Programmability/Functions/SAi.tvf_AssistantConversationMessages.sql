SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SAi].[tvf_AssistantConversationMessages]')
GO

CREATE FUNCTION [SAi].[tvf_AssistantConversationMessages] (@ConversationGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN (
		SELECT m.ID
			,m.Guid
			,c.Guid AS ConversationGuid
			,m.UserId
			,m.MessageRoleCode
			,m.AnswerTypeCode
			,m.ContentMarkdown
			,m.ContentPlainText
			,m.SourcePayloadJson
			,m.FollowUpPayloadJson
			,m.ConfidenceScore
			,m.CreatedUtc
			,m.PromptTokens
			,m.CompletionTokens
			,m.ModelCode
			,m.ParentMessageId
		FROM SAi.AssistantMessages m
		JOIN SAi.AssistantConversations c ON c.ID = m.ConversationId
		WHERE c.Guid = @ConversationGuid
			AND c.RowStatus NOT IN (
				0
				,254
				)
			AND m.RowStatus NOT IN (
				0
				,254
				)
		);
GO