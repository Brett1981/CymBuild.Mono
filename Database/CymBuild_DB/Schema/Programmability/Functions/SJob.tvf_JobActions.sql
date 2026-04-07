SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobActions]
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
	   join			SJob.ActionStatus ast		on (a.ActionStatusId = ast.Id)
	   JOIN			SCore.Identities			  AS i ON (i.ID = a.CreatedByUserID)
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
			   FROM		SJob.Jobs AS j
			   WHERE	(j.Guid = @ParentGuid)
					AND (j.ID	= a.JobID)
		   )
					  )
				   OR (EXISTS
		   (
			   SELECT	1
			   FROM		SJob.Milestones AS m
			   JOIN		SJob.Jobs		AS jm ON (jm.ID = m.JobID)
			   WHERE	(jm.Guid	   = @ParentGuid)
					AND (a.MilestoneID = m.ID)
					AND (m.RowStatus NOT IN (0, 254))
		   )
					  )
				   OR (EXISTS
		   (
			   SELECT	1
			   FROM		SJob.Activities AS act
			   WHERE	(a.ActivityID = act.ID)
					AND (act.RowStatus NOT IN (0, 254))
					AND
					  (
						  (EXISTS
				   (
					   SELECT	1
					   FROM		SJob.Jobs AS jact
					   WHERE	(jact.Guid = @ParentGuid)
							AND (jact.ID   = act.JobID)
				   )
						  )
					   OR (EXISTS
				   (
					   SELECT	1
					   FROM		SJob.Milestones AS am
					   JOIN		SJob.Jobs		AS amj ON (amj.ID = am.JobID)
					   WHERE	(amj.Guid		 = @ParentGuid)
							AND (act.MilestoneID = am.ID)
							AND (am.RowStatus NOT IN (0, 254))
				   )
						  )
					  )
		   )
					  )
				  );

GO