SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE	FUNCTION [SCore].[tvf_MergeDocumentItems]
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
		mdit.Name MergeDocumentItemType,
		root_hobt.BookmarkName, 
		let.Name AS EntityType,
		et.Guid As EntityTypeGuid,
		let.Guid As LinkedEntityTypeGuid,
		root_hobt.SubFolderPath,
		root_hobt.ImageColumns
FROM	SCore.MergeDocumentItems root_hobt
JOIN	SCore.MergeDocuments md ON (md.Id = root_hobt.MergeDocumentId)
JOIN	SCore.EntityTypes AS et ON (et.ID = md.EntityTypeId)
Left JOIN SCore.EntityTypes AS let ON (let.ID = root_hobt.EntityTypeId)
JOIN	SCore.MergeDocumentItemTypes AS mdit ON (mdit.ID = root_hobt.MergeDocumentItemTypeId)
WHERE	(md.Guid = @ParentGuid)
	AND	(root_hobt.RowStatus NOT IN (0, 254))
GO