SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SAi].[tvf_AssistantUploadListByGuids]')
GO

    CREATE FUNCTION [SAi].[tvf_AssistantUploadListByGuids]
    (
        @UploadGuids SCore.GuidUniqueList READONLY
    )
    RETURNS TABLE
    AS
    RETURN
    (
        SELECT
            u.ID,
            u.Guid,
            CONVERT(NVARCHAR(36), c.Guid) AS ConversationGuid,
            CONVERT(NVARCHAR(36), ki.Guid) AS KnowledgeItemGuid,
            u.UserId,
            u.StorageUrl,
            u.FileName,
            u.ContentType,
            u.FileSizeBytes,
            u.UploadPurposeCode,
            u.ProcessingStatusCode,
            u.VisionSummary,
            u.CreatedUtc
        FROM SAi.AssistantUploads u
        JOIN @UploadGuids g ON g.GuidValue = u.Guid
        LEFT JOIN SAi.AssistantConversations c ON c.ID = u.ConversationId
        LEFT JOIN SAi.AssistantKnowledgeItems ki ON ki.ID = u.KnowledgeItemId
        WHERE u.RowStatus NOT IN (0, 254)
    );
    
GO