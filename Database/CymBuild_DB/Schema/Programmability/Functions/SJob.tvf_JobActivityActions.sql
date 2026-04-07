SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobActivityActions]
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
   --WITH SCHEMABINDING
AS
RETURN SELECT		a.ID,
					a.RowStatus,
					a.RowVersion,
					a.Guid,
					a.Notes,
					a.IsComplete,
					a.CreatedDateTimeUTC,
					i.FullName AS CreatedBy,
					ast.Name as ActionStatus
	   FROM			SJob.Actions				  AS a
	   JOIN			SJob.ActionStatus ast		on (a.ActionStatusId = ast.Id)
	   JOIN			SCore.Identities			  AS i ON (i.ID = a.CreatedByUserID)
	   JOIN			SJob.Activities				  AS ac ON (ac.ID = a.ActivityID)
	   WHERE		(a.RowStatus NOT IN (0, 254))
				AND (ac.Guid	= @ParentGuid)
AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
			)
		)
GO