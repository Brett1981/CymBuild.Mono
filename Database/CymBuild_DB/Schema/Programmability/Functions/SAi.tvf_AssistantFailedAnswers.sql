SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SAi].[tvf_AssistantFailedAnswers]')
GO

    CREATE FUNCTION [SAi].[tvf_AssistantFailedAnswers]
    (
        @MaxConfidenceScore DECIMAL(5,4),
        @Take INT
    )
    RETURNS TABLE
    AS
    RETURN
    (
        SELECT TOP (CASE WHEN @Take < 1 THEN 25 ELSE @Take END)
            CONVERT(NVARCHAR(36), c.Guid) AS ConversationGuid,
            CONVERT(NVARCHAR(36), m.Guid) AS MessageGuid,
            c.Title AS ConversationTitle,
            LEFT(COALESCE(NULLIF(m.ContentPlainText, N''), m.ContentMarkdown), 300) AS MessagePreview,
            ISNULL(m.ConfidenceScore, 0) AS ConfidenceScore,
            m.CreatedUtc
        FROM SAi.AssistantMessages m
        JOIN SAi.AssistantConversations c ON c.ID = m.ConversationId
        WHERE m.RowStatus NOT IN (0, 254)
          AND c.RowStatus NOT IN (0, 254)
          AND m.MessageRoleCode = N'ASSISTANT'
          AND ISNULL(m.ConfidenceScore, 0) <= ISNULL(@MaxConfidenceScore, 0.50)
        ORDER BY m.CreatedUtc DESC
    );
    
GO