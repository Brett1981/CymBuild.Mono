SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/*
	[*] Returns upcoming scheduled activities for a user.
	[*] Used in the "Scheduler" to popuate the calendar.
*/
CREATE FUNCTION [SCore].[tvf_GetScheduledActivities] 
(
	@UserId INT,
	@StartDate DATETIME,
	@EndDate DATETIME
)
RETURNS TABLE
AS
RETURN
(
   SELECT 
	root_hobt.SurveyorID AS UserId,
	root_hobt.Date AS StartDate,
	root_hobt.EndDate,
	root_hobt.Title,
	j.Number as JobNumber,
	root_hobt.Notes AS Note
FROM 
	SJob.Activities root_hobt
LEFT JOIN SJob.Jobs AS j ON j.ID = root_hobt.JobID
WHERE 
	(
		root_hobt.SurveyorID = @UserId AND 
		(root_hobt.Date >= @StartDate AND root_hobt.Date < @EndDate) AND
		EXISTS
		(
			--Get the Tentative status ID with an EXIST check
			SELECT 1 
			FROM SJob.ActivityStatus Acts
			WHERE 
				(
					Acts.ID = root_hobt.ActivityStatusID AND 
					Acts.IsActive = 1 AND
					Acts.IsCompleteStatus = 0 AND
					Acts.ID <> 1 
				)
			
		)
		
	) 
);
GO