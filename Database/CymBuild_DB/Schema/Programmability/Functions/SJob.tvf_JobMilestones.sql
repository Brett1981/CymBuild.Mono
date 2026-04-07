SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobMilestones]
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
                  --WITH SCHEMABINDING
AS
RETURN SELECT		jm.ID,
					jm.RowStatus,
					jm.RowVersion,
					jm.Guid,
					mt.Name,
					jm.Description Description,
					jm.SortOrder,
					jm.ScheduledDateTimeUTC,
					jm.DueDateTimeUTC,
					jm.StartDateTimeUTC,
					jm.CompletedDateTimeUTC,
					jm.SubmittedDateTimeUTC,
					CASE
						WHEN (jm.IsNotApplicable = 1) THEN N'Not Applicable'
						WHEN (ISNULL (	 jm.CompletedDateTimeUTC,
										 '1970-01-02'
									 ) > '1970-01-02'
							 ) THEN N'Complete'
						WHEN
						   (
							   ISNULL (	  jm.DueDateTimeUTC,
										  '1970-01-02'
									  ) < GETUTCDATE ()
						   AND	(ISNULL (	jm.DueDateTimeUTC,
											'1970-01-02'
										) > '1970-01-02'
								)
						   ) THEN N'Overdue'
						WHEN (ISNULL (	 jm.StartDateTimeUTC,
										 '1970-01-02'
									 ) > '1970-01-02'
							 ) THEN N'Started'
						WHEN (ISNULL (	 jm.ScheduledDateTimeUTC,
										 '1970-01-02'
									 ) > '1970-01-02'
							 ) THEN N'Scheduled'
						ELSE N'Incomplete'
					END		AS StatusText
	   FROM			SJob.Milestones				  AS jm
	   JOIN			SJob.MilestoneTypes			  AS mt ON (mt.ID = jm.MilestoneTypeID)
	   JOIN			SJob.Jobs					  AS j ON (j.ID = jm.JobID)
	   WHERE		(jm.RowStatus NOT IN (0, 254))
				AND (j.Guid		= @ParentGuid)
				AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (jm.guid, @UserId) oscr
			)
		)
GO