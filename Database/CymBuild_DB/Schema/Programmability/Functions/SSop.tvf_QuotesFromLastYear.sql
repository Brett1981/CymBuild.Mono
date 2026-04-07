SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SSop].[tvf_QuotesFromLastYear]')
GO

CREATE FUNCTION [SSop].[tvf_QuotesFromLastYear]
(
	@UserId INT
)
RETURNS TABLE
          --WITH SCHEMABINDING
AS RETURN	

SELECT 
    q.ID ,
    q.Guid,
	q.RowStatus,
    CONVERT(date, q.Date) AS QuoteDate,
	q.Number,
	acc.Name AS Client,
    ISNULL(SUM(qi.Net), 0) AS TotalNet,
	--Sent Date
    CONVERT(date, ISNULL(
        MAX(CASE WHEN ws.Guid = WorkflowStatuses.SentStatus THEN dot.DateTimeUTC END),
        MAX(q.DateSent)
    )) AS QuoteSentDate,
	--Chase Date 1 (ISNULL is used with q.ChaseDate1/2 to ensure "legacy" statuses are captured.
    CONVERT(date, ISNULL(
        MAX(CASE WHEN ws.Guid = WorkflowStatuses.ChaseOneStatus THEN dot.DateTimeUTC END),
        MAX(q.ChaseDate1)
    )) AS QuoteChaseDateOne,
	--Case Date 2
    CONVERT(date, ISNULL(
        MAX(CASE WHEN ws.Guid = WorkflowStatuses.ChaseTwoStatus THEN dot.DateTimeUTC END),
        MAX(q.ChaseDate2)
    )) AS QuoteChaseDateTwo

FROM SSop.Quotes AS q
LEFT JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
LEFT JOIN	SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
LEFT JOIN	SCrm.Accounts acc ON (acc.ID = e.ClientAccountID)
LEFT JOIN SSop.QuoteItems AS qi 
    ON qi.QuoteId = q.ID
LEFT JOIN SCore.DataObjectTransition AS dot 
    ON dot.DataObjectGuid = q.Guid
LEFT JOIN SCore.WorkflowStatus AS ws 
    ON ws.ID = dot.StatusID
CROSS APPLY (
        SELECT  
            CONVERT(UNIQUEIDENTIFIER, '9FF22CEA-A2A6-4907-9B2D-E62DF8150913') AS ChaseOneStatus,
            CONVERT(UNIQUEIDENTIFIER, '1F01C16B-1A73-4844-A938-FE357405FD93') AS ChaseTwoStatus,
            CONVERT(UNIQUEIDENTIFIER, '25D5491C-42A8-4B04-B3AC-D648AF0F8032') AS SentStatus
    ) AS WorkflowStatuses
WHERE   
	(q.ID > 0) AND
    q.Date >= DATEADD(MONTH, -15, GETDATE())  -- Last 15 months (Should be only 12, but to be on the safe side.)
    AND q.RowStatus NOT IN (0, 254)
	AND	
	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
GROUP BY 
    q.ID,
    q.Guid,
	q.RowStatus,
    q.Date,
	q.Number,
	acc.Name

GO