SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SAi].[tvf_AssistantKnowledgeSearch]')
GO

CREATE FUNCTION [SAi].[tvf_AssistantKnowledgeSearch] (@SearchText NVARCHAR(500))
RETURNS TABLE
AS
RETURN (
		SELECT ki.ID
			,ki.Guid
			,ki.Title
			,ki.Slug
			,kc.Name AS CategoryName
			,kc.Code AS CategoryCode
			,ki.ContentTypeCode
			,ki.SourceTypeCode
			,ki.StorageUrl
			,ki.PreviewUrl
			,ki.Summary
			,ki.IsAuthoritative
			,ki.IsPublished
			,ki.PublishedUtc
			,ki.CreatedUtc
			,ki.UpdatedUtc
			,kv.VersionNumber
			,kv.ExtractionStatusCode
			,kv.ExtractedText
		FROM SAi.AssistantKnowledgeItems ki
		LEFT JOIN SAi.AssistantKnowledgeCategories kc ON kc.ID = ki.KnowledgeCategoryId
		OUTER APPLY (
			SELECT TOP (1) v.VersionNumber
				,v.ExtractionStatusCode
				,v.ExtractedText
			FROM SAi.AssistantKnowledgeItemVersions v
			WHERE v.KnowledgeItemId = ki.ID
				AND v.RowStatus NOT IN (
					0
					,254
					)
				AND v.IsCurrent = 1
			ORDER BY v.VersionNumber DESC
			) kv
		WHERE ki.RowStatus NOT IN (
				0
				,254
				)
			AND ki.IsPublished = 1
			AND (
				@SearchText = N''
				OR ki.Title LIKE N' % ' + @SearchText + N' % '
				OR ISNULL(ki.Summary, N'') LIKE N' % ' + @SearchText + N' % '
				OR ISNULL(kv.ExtractedText, N'') LIKE N' % ' + @SearchText + N' % '
				)
		);
GO