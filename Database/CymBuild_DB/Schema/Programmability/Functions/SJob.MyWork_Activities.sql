SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[MyWork_Activities]
(
	@UserId INT
)
RETURNS TABLE
	   --WITH SCHEMABINDING
AS RETURN
SELECT	a.ID,
		a.Guid,
		a.RowVersion,
		a.RowStatus,
		a.Date,
		a.EndDate,
		a.Title,
		aty.Name   AS ActivityType,
		ast.Name   AS ActivityStatus,
		i.FullName AS SurveyorName,
		j.Number   AS JobNumber,
		CONVERT(NVARCHAR(20), CASE WHEN (EXISTS (SELECT 1 FROM SFin.InvoiceRequestItems iri WHERE (iri.ActivityId = a.ID) AND (iri.RowStatus NOT IN (0, 254)))) THEN 1 ELSE 0 END) + N' / '
		+ CONVERT(NVARCHAR(20), CASE WHEN (EXISTS (SELECT 1 FROM SFin.TransactionDetails td WHERE (td.ActivityId = a.ID) AND (td.RowStatus NOT IN (0, 254)))) THEN 1 ELSE 0 END) AS RequestedInvoiced
FROM	SJob.Activities		AS a
JOIN	SJob.ActivityStatus AS ast ON (ast.ID = a.ActivityStatusID)
JOIN	SJob.ActivityTypes	AS aty ON (aty.ID = a.ActivityTypeID)
JOIN	SJob.Jobs			AS j ON (j.ID	  = a.JobID)
JOIN	SCore.Identities	AS i ON (i.ID	  = a.SurveyorID)
WHERE	(a.SurveyorID = @UserId)
	AND	(a.Date BETWEEN DATEADD (	WEEK,
									-1,
									DATEADD (	WEEK,
												DATEDIFF (	 WEEK,
															 0,
															 GETDATE ()
														 ),
												0
											)
								) AND DATEADD (	  WEEK,
												  1,
												  DATEADD (	  WEEK,
															  DATEDIFF (   WEEK,
																		   0,
																		   GETDATE ()
																	   ),
															  0
														  )
											  )
		)
	AND (a.RowStatus NOT IN (0, 254));


GO