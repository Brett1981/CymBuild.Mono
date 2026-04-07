SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE	FUNCTION [SCore].[tvf_MergeDocumentFieldReference]
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
		folfu.Label,
		folfu.HelpText
FROM	SCore.EntityProperties AS root_hobt
JOIN	SCore.EntityHobts AS eh ON (eh.ID = root_hobt.EntityHoBTID)
JOIN	SCore.MergeDocuments AS md ON (md.LinkedEntityTypeId = eh.EntityTypeID) 
OUTER APPLY SCore.FullObjectLabelForUser(root_hobt.LanguageLabelID, @UserId) AS folfu
WHERE	(md.Guid = @ParentGuid)
	AND	(root_hobt.RowStatus NOT IN (0, 254))
GO