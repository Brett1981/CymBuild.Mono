SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_MyInvoicing]
	(
		@UserId INT
	)
RETURNS TABLE
     --WITH SCHEMABINDING
AS
RETURN SELECT
    YEAR(t.Date) AS Year,
    MONTH(t.Date) AS Month,
    DATENAME(MONTH, t.Date) AS MonthName,
	DATENAME(MONTH, t.Date) + N' - £' + CONVERT(NVARCHAR,SUM(td.Gross) OVER (
        PARTITION BY YEAR(t.Date), MONTH(t.Date)
    )) AS MonthlyTotal,
	t.ID,
	t.Date,
	t.Guid,
	t.RowStatus,
    td.Gross,
	j.Number AS JobNumber,
	j.JobDescription AS Description,
	asset.FormattedAddressComma AS Asset,
	j.ExternalReference,
	jt.Name AS JobTypeName,
	i.FullName AS Consultant,
	CONVERT(DATE, j.CreatedOn, 106) AS CreatedOn,
	client.Name + N' / ' + agent.Name AS ClientAgent,
	CASE
		WHEN DATEPART(MONTH,
			t.Date
			) = DATEPART(MONTH,
			GETDATE()
			) THEN
			1
		ELSE
		0
	END	   AS IsCurrentMonth
 
FROM
    SFin.Transactions AS t
JOIN
    SFin.TransactionDetails AS td ON td.TransactionID = t.ID
JOIN
    SFin.TransactionTypes AS tt ON tt.ID = t.TransactionTypeID
JOIN
    SJob.Activities AS act ON act.ID = td.ActivityID
JOIN
    SJob.Milestones AS m ON m.ID = td.MilestoneID
JOIN
    SJob.Jobs AS j ON j.ID = m.JobId OR j.ID = t.JobId
JOIN
    SCrm.Accounts AS a ON a.ID = t.AccountID
JOIN
	SJob.Assets AS asset ON (asset.ID = j.UprnID)
JOIN
	SJob.JobTypes AS jt ON (jt.ID = j.JobTypeID)
JOIN
	SCore.Identities AS i ON (i.ID = @UserId)
JOIN
	SCrm.Accounts AS client ON (client.ID = j.ClientAccountID)
JOIN
	SCrm.Accounts AS agent ON (agent.ID = j.AgentAccountID)
WHERE
    t.RowStatus NOT IN (0, 254)
    AND td.RowStatus NOT IN (0, 254)
	AND (tt.Name = N'Invoice')
	AND (j.SurveyorID = @UserId)
    AND (t.ID > 0)
	AND (j.ID > 0)
	AND (td.Gross > 0)	
	AND (j.IsActive = 1)
	AND 
	(
		(j.IsCancelled	= 0) AND  
		(NOT EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition 
			JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = StatusID)
			WHERE 
				DataObjectGuid = j.Guid AND wfs.Guid = '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64' ))
				
	)
	AND 
	(
		(j.IsComplete	= 0) AND  
		(NOT EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition 
			JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = StatusID)
			WHERE 
				DataObjectGuid = j.Guid AND wfs.Guid = '20D22623-283B-4088-9CEB-D944AC3E6516' ))
				
	)
	AND (j.CompletedForReviewDate IS NULL)
	AND 
	(
		(j.CompletedForReviewDate IS NULL) AND  
		(NOT EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition 
			JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = StatusID)
			WHERE 
				DataObjectGuid = j.Guid AND wfs.Guid = '4BFDB215-3E27-4829-BB44-0468C92DAC82' ))
				
	)
    AND EXISTS (SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(t.Guid, @UserId) oscr)
    AND EXISTS (SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr)
	AND t.Date >= DATEADD(MONTH, -12, CAST(GETDATE() AS date)) -- Last 12 months
GO