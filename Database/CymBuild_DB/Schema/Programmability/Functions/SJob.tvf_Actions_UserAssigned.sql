SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Actions_UserAssigned]
	(
		@UserId		INT
	)
RETURNS TABLE
   --WITH SCHEMABINDING
AS
	RETURN SELECT
			a.ID,
			a.RowStatus,
			a.RowVersion,
			a.Guid,
			a.Notes,
			a.IsComplete,
			a.CreatedDateTimeUTC,
			i.FullName  AS CreatedBy,
			i1.FullName AS Assignee,
			ap.Name		AS Priority,
			at.Name		AS Type,
			[as].Name   AS Status
	FROM
			SJob.Actions as a
	JOIN
			SCore.Identities as i ON (i.ID = a.CreatedByUserID)
	JOIN
			SCore.Identities i1 ON (a.AssigneeUserId = i1.ID)
	JOIN
			SJob.ActionPriorities ap ON (a.ActionPriorityId = ap.ID)
	JOIN
			SJob.ActionTypes at ON a.ActionTypeId = at.ID
	JOIN
			SJob.ActionStatus [as] ON a.ActionStatusId = [as].ID
	WHERE
			(a.RowStatus NOT IN (0, 254))
			AND (i1.ID = @UserId)
			AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
			)
		)
GO