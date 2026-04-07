SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[JobMileStoneDates]
(	
	@JobTypeCode NVARCHAR(20),
	@JobId INT	
)
RETURNS TABLE 
             --WITH SCHEMABINDING
AS
RETURN 
(
	SELECT	m.ReviewedDateTimeUTC,
			m.CompletedDateTimeUTC,
			m.StartDateTimeUTC,
			m.JobID
	FROM	SJob.Milestones m
	JOIN	SJob.MilestoneTypes mt ON (mt.ID = m.MilestoneTypeID)
	WHERE	(mt.Code = @JobTypeCode)
		AND	(m.JobID = @JobId)
)
GO