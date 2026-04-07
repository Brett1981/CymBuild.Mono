SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE	FUNCTION [SCore].[tvf_MergeDocumentItemIncludes]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE 
AS 
RETURN SELECT	
		root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.SortOrder,
		ep.Name AS SourceDocumentEntityProperty,
		ep2.Name AS SourceSharePointItemEntityProperty,
		md.Name AS IncludedMergeDocument,
		md.Guid As MergeDocumentItemGuid
FROM	SCore.MergeDocumentItemIncludes root_hobt
JOIN	SCore.MergeDocumentItems mdi ON (mdi.Id = root_hobt.MergeDocumentItemId)
JOIN	SCore.EntityProperties AS ep ON (ep.ID = root_hobt.SourceDocumentEntityPropertyId)
JOIN	SCore.EntityProperties AS ep2 ON (ep2.ID = root_hobt.SourceSharePointItemEntityPropertyId)
JOIN	SCore.MergeDocuments AS md ON (md.Id = root_hobt.IncludedMergeDocumentId) 
WHERE	(mdi.Guid = @ParentGuid)
	AND	(root_hobt.RowStatus NOT IN (0, 254))
GO