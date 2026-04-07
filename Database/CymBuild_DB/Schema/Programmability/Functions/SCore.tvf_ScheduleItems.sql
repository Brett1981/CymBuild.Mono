SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_ScheduleItems] 
(
    @UserId INT,
    @CurrentUserOnly bit
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS
RETURN  
SELECT      a.ID,
            a.Guid,
            j.Number as JobNumber,
            a.[Date] as [Start],
            a.EndDate as [End],
            a.Title,
            a.Notes as [Description],
            CAST(0 as BIT) as IsAllDay,
            N'' as RecurrenceRule,
            0 as RecurrenceId,
            N'' as RecurrenceExceptions,
            N'' as StartTimezone,
            N'' as EndTimezone,
            a.SurveyorID as UserId,
            a.ActivityStatusID as StatusId,
            a.ActivityTypeID as TypeId
FROM        SJob.Activities a
JOIN		SJob.Jobs j ON (j.ID = a.JobID)
WHERE       (a.RowStatus NOT IN (0, 254))
        AND (EXISTS 
				(SELECT	1
				FROM	SJob.ActivityTypes t
				WHERE	(t.IsScheduleItem = 1)
					AND	(t.Id = a.ActivityTypeID)
				)
			)
		AND	(
				(@CurrentUserOnly = 0)
				OR (
						(@CurrentUserOnly = 1)
					AND	(a.SurveyorID = @UserId)
				)
			)
		AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
			)
		)
GO