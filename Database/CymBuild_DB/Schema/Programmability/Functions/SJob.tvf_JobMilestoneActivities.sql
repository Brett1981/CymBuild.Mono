SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobMilestoneActivities]
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
					a.Title,
					a.Date, 
					a.EndDate,
					stat.Name  AS ActivityStatus,
					types.Name AS ActivityType,
					i.FullName AS Surveyor
	   FROM			SJob.Activities				  AS a
	   JOIN			SJob.ActivityStatus			  AS stat ON (stat.ID = a.ActivityStatusID)
	   JOIN			SJob.ActivityTypes			  AS types ON (types.ID = a.ActivityTypeID)
	   JOIN			SCore.Identities			  AS i ON (i.ID = a.SurveyorID)
	   JOIN			SJob.Milestones				  AS m ON (m.ID = a.MilestoneID)
	   WHERE		(a.RowStatus NOT IN (0, 254))
				AND (m.Guid		= @ParentGuid)
AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
			)
		)
GO