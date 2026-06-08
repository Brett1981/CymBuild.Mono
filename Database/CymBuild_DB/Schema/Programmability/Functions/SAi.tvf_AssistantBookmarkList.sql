SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SAi].[tvf_AssistantBookmarkList]')
GO

    CREATE FUNCTION [SAi].[tvf_AssistantBookmarkList]
    (
        @UserId INT
    )
    RETURNS TABLE
    AS
    RETURN
    (
        SELECT
            b.ID,
            b.Guid,
            CONVERT(NVARCHAR(36), c.Guid) AS ConversationGuid,
            CONVERT(NVARCHAR(36), m.Guid) AS MessageGuid,
            b.UserId,
            b.Title,
            b.Notes,
            b.TagsJson,
            b.CreatedUtc
        FROM SAi.AssistantBookmarks b
        JOIN SAi.AssistantConversations c ON c.ID = b.ConversationId
        JOIN SAi.AssistantMessages m ON m.ID = b.MessageId
        WHERE b.UserId = @UserId
          AND b.RowStatus NOT IN (0, 254)
    );
    
GO