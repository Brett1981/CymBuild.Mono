SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SAi].[tvf_AssistantWorkflowTemplateList]')
GO

    CREATE FUNCTION [SAi].[tvf_AssistantWorkflowTemplateList]
    (
        @PublishedOnly BIT,
        @FeaturedOnly BIT,
        @AudienceCode NVARCHAR(30)
    )
    RETURNS TABLE
    AS
    RETURN
    (
        SELECT
            wt.ID,
            wt.Guid,
            wt.Code,
            wt.Title,
            wt.Summary,
            wt.AudienceCode,
            wt.TemplatePrompt,
            wt.ClarificationSchemaJson,
            wt.OutputFormatCode,
            wt.IsPublished,
            wt.IsFeatured,
            wt.CreatedByUserId,
            wt.CreatedUtc,
            wt.UpdatedUtc
        FROM SAi.AssistantWorkflowTemplates wt
        WHERE wt.RowStatus NOT IN (0, 254)
          AND (@PublishedOnly = 0 OR wt.IsPublished = 1)
          AND (@FeaturedOnly = 0 OR wt.IsFeatured = 1)
          AND (ISNULL(@AudienceCode, N'') = N'' OR wt.AudienceCode = @AudienceCode)
    );
    
GO