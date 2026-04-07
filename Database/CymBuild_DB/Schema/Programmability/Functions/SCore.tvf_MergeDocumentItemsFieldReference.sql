SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_MergeDocumentItemsFieldReference]
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
		root_hobt.Name AS MergeFieldName,
		mdItems.BookmarkName,
		mdItems.Guid AS MDItemsGuid,
		mdItems.EntityTypeId AS MDItems_EntityTypeID,
		folfu.Label,
		folfu.HelpText
FROM	SCore.EntityProperties AS root_hobt
JOIN	SCore.EntityHobts AS eh ON (eh.ID = root_hobt.EntityHoBTID)
JOIN    SCore.MergeDocumentItems AS mdItems ON (mdItems.EntityTypeId = eh.EntityTypeID)
OUTER APPLY SCore.FullObjectLabelForUser(root_hobt.LanguageLabelID, @UserId) AS folfu
WHERE	(mdItems.Guid = @ParentGuid)
	AND	(root_hobt.RowStatus NOT IN (0, 254) OR mdItems.RowStatus NOT IN (0, 254))
GO