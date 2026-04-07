SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SJob].[JobMilestoneMetric]
            --WITH SCHEMABINDING
AS
SELECT	j.ID,
		j.Guid,
		ISNULL(FirstDataPoint.SortOrder, 1) AS FirstValue,
		ISNULL(LEFT(FirstDataPoint.Name, 10), N'') AS FirstDescription,
		ISNULL(FirstDataPoint.Complete, 0) AS FirstComplete,
		ISNULL(PreviousDataPoint.SortOrder, 2) AS PreviousValue,
		ISNULL(LEFT(PreviousDataPoint.Name, 10), N'') AS PreviousDescription,
		ISNULL(PreviousDataPoint.Complete, 0) AS PreviousComplete,
		ISNULL(MidDataPoint.SortOrder, 3)  AS MidValue,
		ISNULL(LEFT(MidDataPoint.Name, 10), N'') AS MidDescription,
		ISNULL(MidDataPoint.Complete, 0) AS MidComplete,
		ISNULL(NextDataPoint.SortOrder, 4) AS NextValue,
		ISNULL(LEFT(NextDataPoint.Name, 10), N'') AS NextDescription,
		ISNULL(NextDataPoint.Complete, 0) AS NextComplete,
		ISNULL(LastDataPoint.SortOrder, 5) AS LastValue,
		ISNULL(LEFT(LastDataPoint.Name, 10), N'') AS LastDescription,
		ISNULL(LastDataPoint.Complete, 0) AS LastComplete
FROM	SJob.Jobs j
OUTER APPLY 
(
	SELECT	jm.SortOrder
	FROM	SJob.Milestones jm
	WHERE	(jm.JobID = j.ID)
		AND (jm.RowStatus NOT IN (0, 254))	
		AND (
				(
					((jm.CompletedDateTimeUTC IS NULL) OR (jm.IsNotApplicable = 0))
				AND	(NOT EXISTS
						(
							SELECT	1
							FROM	SJob.Milestones jm2
							WHERE	(jm2.JobID = jm.JobID)
								AND (jm2.RowStatus NOT IN (0, 254))	
								AND ((jm2.CompletedDateTimeUTC IS NULL) OR (jm2.IsNotApplicable = 0))
								AND	(jm2.SortOrder < jm.SortOrder)
						)
					)
				)
				OR 
				(
					((jm.CompletedDateTimeUTC IS NOT NULL) OR (jm.IsNotApplicable = 1))
				AND	(NOT EXISTS
						(
							SELECT	1
							FROM	SJob.Milestones jm2
							WHERE	(jm2.JobID = jm.JobID)
								AND (jm2.RowStatus NOT IN (0, 254))	
								AND ((jm2.CompletedDateTimeUTC IS NOT NULL) OR (jm2.IsNotApplicable = 1))
								AND	(jm2.SortOrder < jm.SortOrder)
						)
					)
				)
			)

) AS CurrentDataPoint
OUTER APPLY
(
	SELECT	jm.SortOrder,
			mt.Name,
			CONVERT(BIT, CASE WHEN jm.CompletedDateTimeUTC IS NOT NULL OR jm.IsNotApplicable = 1 THEN 1 ELSE 0 END) AS Complete
	FROM	SJob.Milestones jm
	JOIN	SJob.MilestoneTypes mt ON (mt.ID = jm.MilestoneTypeID)
	WHERE	(jm.SortOrder = 1)
		AND	(jm.JobID = j.ID)
		AND (jm.RowStatus NOT IN (0, 254))
) AS FirstDataPoint
OUTER APPLY
(
	SELECT	jm.SortOrder,
			mt.Name,
			CONVERT(BIT, CASE WHEN jm.CompletedDateTimeUTC IS NOT NULL OR jm.IsNotApplicable = 1 THEN 1 ELSE 0 END) AS Complete
	FROM	SJob.Milestones jm
	JOIN	SJob.MilestoneTypes mt ON (mt.ID = jm.MilestoneTypeID)
	WHERE	(jm.JobID = j.ID)
		AND (jm.RowStatus NOT IN (0, 254))
		AND	(
				((jm.SortOrder = 3) AND (CurrentDataPoint.SortOrder <= 3))
				OR ((jm.SortOrder = CurrentDataPoint.SortOrder) AND (CurrentDataPoint.SortOrder > 3))
			)
) AS MidDataPoint
OUTER APPLY
(
	SELECT	jm.SortOrder,
			mt.Name,
			CONVERT(BIT, CASE WHEN jm.CompletedDateTimeUTC IS NOT NULL OR jm.IsNotApplicable = 1 THEN 1 ELSE 0 END) AS Complete
	FROM	SJob.Milestones jm
	JOIN	SJob.MilestoneTypes mt ON (mt.ID = jm.MilestoneTypeID)
	WHERE	(jm.JobID = j.ID)
		AND (jm.RowStatus NOT IN (0, 254))
		AND (
				((CurrentDataPoint.SortOrder > 2) AND (jm.SortOrder = CurrentDataPoint.SortOrder - 1))
				OR ((CurrentDataPoint.SortOrder < 3) AND (jm.SortOrder = 2))
			)
) AS PreviousDataPoint
OUTER APPLY
(
	SELECT	jm.SortOrder,
			mt.Name,
			CONVERT(BIT, CASE WHEN jm.CompletedDateTimeUTC IS NOT NULL OR jm.IsNotApplicable = 1 THEN 1 ELSE 0 END) AS Complete
	FROM	SJob.Milestones jm
	JOIN	SJob.MilestoneTypes mt ON (mt.ID = jm.MilestoneTypeID)
	WHERE	(jm.JobID = j.ID)
		AND (jm.RowStatus NOT IN (0, 254))
		AND (
				((CurrentDataPoint.SortOrder <=3) AND (jm.SortOrder = 4))
				OR ((CurrentDataPoint.SortOrder > 3) AND (jm.SortOrder = CurrentDataPoint.SortOrder + 1))
			)
) AS NextDataPoint
OUTER APPLY
(
	SELECT	jm.SortOrder,
			mt.Name,
			CONVERT(BIT, CASE WHEN jm.CompletedDateTimeUTC IS NOT NULL OR jm.IsNotApplicable = 1 THEN 1 ELSE 0 END) AS Complete
	FROM	SJob.Milestones jm
	JOIN	SJob.MilestoneTypes mt ON (mt.ID = jm.MilestoneTypeID)
	WHERE	(jm.JobID = j.ID)
		AND (jm.RowStatus NOT IN (0, 254))
		AND	(NOT EXISTS 
				(
					SELECT	1
					FROM	SJob.Milestones jm2 
					WHERE	(jm2.JobID = jm.JobID)
						AND	(jm2.RowStatus NOT IN (0, 254))
						AND (jm2.SortOrder > jm.SortOrder)
				)
			)
) AS LastDataPoint
WHERE	(j.RowStatus NOT IN (0, 254))
GO