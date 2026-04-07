SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SCore].[tvf_WorkflowStatusNotificationGroups]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
       --WITH SCHEMABINDING
AS RETURN	
SELECT  
		root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.CanAction,
		wfs.Name AS WorkflowStatusGuid,
		g.Name AS GroupID
FROM    SCore.WorkflowStatusNotificationGroups AS root_hobt
JOIN	SCore.Workflow AS wf ON (wf.ID = root_hobt.WorkflowID)
JOIN    SCore.WorkflowStatus AS wfs ON (wfs.Guid = root_hobt.WorkflowStatusGuid)
JOIN    SCore.Groups as g ON (g.ID = root_hobt.GroupID)
WHERE   (root_hobt.RowStatus NOT IN (0, 254))
	AND	(root_hobt.ID > 0)
	AND (wf.Guid = @ParentGuid)
	AND (root_hobt.RowStatus NOT IN (0,254))
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (root_hobt.guid, @UserId) oscr
			)
		)
GO