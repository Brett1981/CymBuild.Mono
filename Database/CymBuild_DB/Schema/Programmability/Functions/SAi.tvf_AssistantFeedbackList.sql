SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SAi].[tvf_AssistantFeedbackList]')
GO

    CREATE FUNCTION [SAi].[tvf_AssistantFeedbackList]
    (
        @IncludeHelpful BIT,
        @IncludeUnhelpful BIT
    )
    RETURNS TABLE
    AS
    RETURN
    (
        SELECT
            f.ID,
            f.Guid,
            f.UserId,
            CONVERT(NVARCHAR(36), c.Guid) AS ConversationGuid,
            CONVERT(NVARCHAR(36), m.Guid) AS MessageGuid,
            f.FeedbackCode,
            f.Comment,
            f.CreatedUtc,
            c.Title AS ConversationTitle,
            LEFT(COALESCE(NULLIF(m.ContentPlainText, N''), m.ContentMarkdown), 300) AS MessagePreview,
            m.AnswerTypeCode,
            m.ConfidenceScore
        FROM SAi.AssistantFeedback f
        JOIN SAi.AssistantConversations c ON c.ID = f.ConversationId
        JOIN SAi.AssistantMessages m ON m.ID = f.MessageId
        WHERE f.RowStatus NOT IN (0, 254)
          AND
          (
              (@IncludeHelpful = 1 AND f.FeedbackCode = N'HELPFUL')
              OR (@IncludeUnhelpful = 1 AND f.FeedbackCode = N'UNHELPFUL')
          )
    );
    
GO