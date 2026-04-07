SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_QuotesChaseTwo] 
(
    @UserId INT
)
RETURNS TABLE
               --WITH SCHEMABINDING
AS
RETURN 
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.Number,
		q.ExpiryDate,
		q.DescriptionOfWorks AS Description,
		client.Name + N' / ' + agent.Name AS ClientAgent,
		asset.FormattedAddressComma AS Asset,
		q.ExternalReference,
		JobType.Name AS JobTypeName,
		CONVERT(DATE,q.Date, 106) as Date,
		q.DateRejected,
		e.ChaseDate1
FROM    
	SSop.Quotes  AS q

JOIN 
	SSop.EnquiryService_ExtendedInfo AS ese ON (ese.QuoteID = q.ID)
JOIN	
	SJob.Assets AS asset ON (asset.ID = q.UprnId)
JOIN
	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
JOIN
	SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
JOIN
	SCrm.Accounts AS client ON (q.ClientAccountId = client.ID)
JOIN
	SCrm.Accounts AS agent ON (q.AgentAccountId = agent.ID)
OUTER APPLY (
    SELECT jt.Name
    FROM SSop.EnquiryServices es2
    JOIN SJob.JobTypes jt ON jt.ID = es2.JobTypeId
    WHERE es2.EnquiryId = e.ID
      AND NOT EXISTS (
          SELECT 1
          FROM SSop.EnquiryServices es3
          JOIN SJob.JobTypes jt2 ON jt2.ID = es3.JobTypeId
          WHERE es3.QuoteId = q.ID
            AND jt2.ID > jt.ID
      )
) AS JobType
WHERE   
	(q.QuotingConsultantId = @UserId) AND
	(q.RowStatus  NOT IN (0, 254)) 
	AND 
	(
		(q.DateSent IS NOT NULL) OR  
		(EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition 
			JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = StatusID)
			WHERE 
				DataObjectGuid = q.Guid AND wfs.Guid = '25D5491C-42A8-4B04-B3AC-D648AF0F8032' ))
				
	)
	AND 
	(
		(e.ChaseDate1 IS NOT NULL) OR  
		(EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition 
			JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = StatusID)
			WHERE 
				DataObjectGuid = e.Guid AND wfs.Guid = '9FF22CEA-A2A6-4907-9B2D-E62DF8150913' ))
				
	)
	AND 
	(
		(q.DateRejected IS  NULL) AND  
		(NOT EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition 
			JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = StatusID)
			WHERE 
				DataObjectGuid = q.Guid AND wfs.Guid = '0A6A71F7-B39F-4213-997E-2B3A13B6144C' ))
				
	)
	AND 
	(
		(DATEDIFF(DAY, e.ChaseDate1, GETDATE()) > 21)
		OR  
		EXISTS (
			SELECT 1
			FROM SCore.DataObjectTransition AS dot
			JOIN SCore.WorkflowStatus AS wfs 
				ON wfs.ID = dot.StatusID
			WHERE 
				dot.DataObjectGuid = e.Guid
				AND wfs.Guid = '9FF22CEA-A2A6-4907-9B2D-E62DF8150913'
				AND DATEDIFF(DAY, dot.DateTimeUTC, GETDATE()) > 21
		)
	)
	
	AND (GETDATE() < q.ExpiryDate) AND
	NOT EXISTS
	(
		SELECT 1 
		FROM SJob.Jobs 
		WHERE q.OriginalQuoteId = q.ID
	
	) AND
	(EXISTS
		(
			SELECT
					1
			FROM
					SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
		)
	)
GO