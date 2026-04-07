SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobActivity] 
(
    @UserId INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
            --WITH SCHEMABINDING
AS
RETURN 
SELECT  a.ID,
        a.RowStatus, 
        a.RowVersion,
        a.Guid,
        a.Title,
        a.[Date] AS [Start],
        a.EndDate AS [End],
        s.Name AS [Status],
        t.Name AS [Type],
		i.Guid SurveyorGuid,
		i.FullName AS SurveyorName,
		ActionCount.Total AS TotalActions,
		ISNULL(ActionCount.Outstanding, 0) AS OutstandingActions,
		CONVERT(NVARCHAR(30), ActionCount.Total) + N' | ' + CONVERT(NVARCHAR(30), ISNULL(ActionCount.Outstanding, 0)) AS Actions,
		CONVERT(NVARCHAR(20), CASE WHEN (EXISTS (SELECT 1 FROM SFin.InvoiceRequestItems iri WHERE (iri.ActivityId = a.ID) AND (iri.RowStatus NOT IN (0, 254)))) THEN 1 ELSE 0 END) + N' | '
		+ CONVERT(NVARCHAR(20), CASE WHEN (EXISTS (SELECT 1 FROM SFin.TransactionDetails td WHERE (td.ActivityId = a.ID) AND (td.RowStatus NOT IN (0, 254)))) THEN 1 ELSE 0 END) AS RequestedInvoiced,
		j.FinanceAccountID, -- NEW [CBLD-535]
		CASE
			WHEN t.IsBillable = 0 THEN 'No' ELSE 'Yes' -- [CBLD-534] => Checking if an activity isbi
		END AS IsBillable
FROM    SJob.Activities a
JOIN	SJob.Jobs AS j ON (a.JobID = j.ID) --NEW [CBLD-535]
JOIN    SJob.ActivityStatus s ON (s.Id = a.ActivityStatusID)
JOIN    SJob.ActivityTypes t ON (t.Id = a.ActivityTypeID)
JOIN    SCore.Identities i ON (a.SurveyorID = i.ID)
OUTER APPLY 
(
	SELECT	COUNT(1) AS Total,
			SUM(CASE WHEN act.IsComplete = 0 THEN 1 ELSE 0 END) AS Outstanding
	FROM	SJob.Actions act
	WHERE	(act.RowStatus NOT IN (0, 254))
		AND	(act.ActivityID = a.ID)
) AS ActionCount
WHERE   (a.RowStatus  NOT IN (0, 254))
    AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (a.guid, @UserId) oscr
			)
		)
	AND	(
			(EXISTS
				(
					SELECT	1
					FROM	SJob.Jobs j 
					WHERE	 (j.Guid = @ParentGuid)
						AND	(j.RowStatus NOT IN (0, 254))
						AND (j.Id = a.JobID)
				)
			)
		)
GO