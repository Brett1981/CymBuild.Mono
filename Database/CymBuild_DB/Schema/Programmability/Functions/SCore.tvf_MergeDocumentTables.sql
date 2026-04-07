SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE	FUNCTION [SCore].[tvf_MergeDocumentTables]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE 
AS 
RETURN SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.TableName,
		et.Name AS LinkedEntityType
FROM	SCore.MergeDocumentTables root_hobt
JOIN	SCore.MergeDocuments md ON md.Id = root_hobt.MergeDocumentId
JOIN	SCore.EntityTypes et ON root_hobt.LinkedEntityTypeId = et.ID
WHERE	(md.Guid = @ParentGuid)
	AND	(root_hobt.RowStatus NOT IN (0, 254))
GO