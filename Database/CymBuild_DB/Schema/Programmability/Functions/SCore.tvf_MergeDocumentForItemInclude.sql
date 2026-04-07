SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE	FUNCTION [SCore].[tvf_MergeDocumentForItemInclude]
(
	@IncludeGuid UNIQUEIDENTIFIER
)
RETURNS TABLE 
AS 
RETURN SELECT	
		md.ID,
		md.RowStatus,
		md.RowVersion,
		md.Guid,
		md.Name,		
		e.Guid AS EntityTypeGuid,
		ss.SiteIdentifier AS DriveId,
		md.DocumentId,
		le.Guid AS LinkedEntityTypeGuid,
		md.FilenameTemplate,
		md.SharepointSiteId,
		md.AllowPDFOutputOnly,
		md.AllowExcelOutputOnly,
		md.ProduceOneOutputPerRow
FROM	SCore.MergeDocuments md 
LEFT JOIN	SCore.MergeDocumentItems AS mdi ON (mdi.MergeDocumentId = md.ID)
LEFT JOIN	SCore.MergeDocumentItemIncludes AS mdii ON (mdii.IncludedMergeDocumentId = md.ID)
JOIN	SCore.EntityTypesV		AS e ON (md.EntityTypeID = e.ID)
JOIN	SCore.EntityTypesV		AS le ON (md.LinkedEntityTypeID = le.ID)
JOIN	SCore.SharepointSites	AS ss ON (ss.ID = md.SharepointSiteId)
WHERE	(mdii.Guid  = @IncludeGuid)

GO