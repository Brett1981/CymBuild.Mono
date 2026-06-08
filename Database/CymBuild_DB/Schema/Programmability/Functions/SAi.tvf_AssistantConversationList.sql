SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SAi].[tvf_AssistantConversationList]')
GO

/* =========================================================================================
       9.12 Read TVFs / Views
    ========================================================================================= */
CREATE FUNCTION [SAi].[tvf_AssistantConversationList] (@UserId INT)
RETURNS TABLE
AS
RETURN (
		SELECT c.ID
			,c.Guid
			,c.UserId
			,c.Title
			,c.ModeCode
			,c.LanguageCode
			,c.LastActivityUtc
			,c.IsPinned
			,c.IsArchived
			,c.StartedFromWorkflowTemplateId
			,c.LastMessageId
			,m.ContentPlainText AS LastMessagePlainText
			,m.ContentMarkdown AS LastMessageMarkdown
			,m.MessageRoleCode AS LastMessageRoleCode
			,m.CreatedUtc AS LastMessageCreatedUtc
		FROM SAi.AssistantConversations AS c
		LEFT JOIN SAi.AssistantMessages AS m ON m.ID = c.LastMessageId
			AND m.RowStatus NOT IN (
				0
				,254
				)
		WHERE c.UserId = @UserId
			AND c.RowStatus NOT IN (
				0
				,254
				)
		);
GO