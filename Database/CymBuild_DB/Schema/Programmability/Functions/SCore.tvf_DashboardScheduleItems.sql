SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_DashboardScheduleItems] 
(
    @UserId INT
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS
RETURN  
SELECT      a.ID,
            a.Guid,
            a.Id AS JobActivityId,
            a.[Date] AS [Start],
            a.EndDate AS [End],
            a.Title,
            a.Notes AS [Description],
            CAST(0 AS BIT) AS IsAllDay,
            N'' AS RecurrenceRule,
            0 AS RecurrenceId,
            N'' AS RecurrenceExceptions,
            N'' AS StartTimezone,
            N'' AS EndTimezone,
            a.SurveyorID AS UserId,
            a.ActivityStatusID AS StatusId,
            a.ActivityTypeID AS TypeId
FROM        SJob.Activities a
JOIN        sjOB.ActivityTypes t ON (t.Id = a.ActivityTypeID)
WHERE       (a.RowStatus NOT IN (0, 254))
        AND (t.IsScheduleItem = 1)
		AND	(a.SurveyorID = @UserId)
		AND	(EXISTS
				(				
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
				)
			)
GO