SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobMilestoneActions]
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
	   JOIN			SJob.Milestones				  AS m ON (m.ID = a.MilestoneID)
	   WHERE		(a.RowStatus NOT IN (0, 254))
				AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
			)
		)
				AND
				  (
					  (EXISTS
		   (
			   SELECT	1
			   FROM		SJob.Milestones AS m
			   WHERE	(m.Guid		   = @ParentGuid)
					AND (a.MilestoneID = m.ID)
					AND (m.RowStatus NOT IN (0, 254))
		   )
					  )
				   OR (EXISTS
		   (
			   SELECT	1
			   FROM		SJob.Activities AS act
			   JOIN		SJob.Milestones AS m ON (m.ID = act.MilestoneID)
			   WHERE	(m.Guid		  = @ParentGuid)
					AND (a.ActivityID = act.ID)
					AND (act.RowStatus NOT IN (0, 254))
		   )
					  )
				  );
GO