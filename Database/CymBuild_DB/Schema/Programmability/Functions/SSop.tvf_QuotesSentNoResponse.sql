SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_QuotesSentNoResponse]
(
	@UserId INT
)
RETURNS TABLE
      --WITH SCHEMABINDING
AS RETURN	
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.FullNumber AS Number,
		LEFT(q.Overview, 200) AS Details, 
		acc.Name + N' / ' + aacc.Name AS Account,
		uprn.FormattedAddressComma,
		qc.FullName AS QuotingConsultant,
		FORMAT(q.DateSent, N'dd MMM yyyy') as DateSent, 
		q.ChaseDate1, 
		q.ChaseDate2,
		qcf.QuoteStatus,
		q.ExternalReference,
		jt.Name AS JobType
FROM    SSop.Quotes q
JOIN	SSop.Quote_CalculatedFields qcf ON (qcf.ID = q.ID)
JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
JOIN	SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
JOIN	SCrm.Accounts acc ON (acc.ID = e.ClientAccountID)
JOIN	SCrm.Accounts aacc ON (aacc.ID = e.AgentAccountID)
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
JOIN	SCore.Identities qc ON (qc.ID = q.QuotingConsultantId)
JOIN	SJob.JobTypes AS jt ON (jt.ID = es.JobTypeId)
WHERE   (q.RowStatus NOT IN (0, 254))
	AND	(q.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, 1479) oscr
			)
		)
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
		(q.DateAccepted IS NULL) AND
		(NOT EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition 
			JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = StatusID)
			WHERE 
				DataObjectGuid = q.Guid AND wfs.Guid = '21A29AEE-2D99-4DA3-8182-F31813B0C498' ))
				
	)
	AND 
	(
		(q.DateRejected IS NULL) AND
		(NOT EXISTS(
			SELECT 1 
			FROM SCore.DataObjectTransition 
			JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = StatusID)
			WHERE 
				DataObjectGuid = q.Guid AND wfs.Guid = '0A6A71F7-B39F-4213-997E-2B3A13B6144C' ))
				
	)
	AND GETDATE() < q.ExpiryDate -- NOT Expired
	AND 
	( 
		(
			q.DateSent IS NOT NULL 
			AND DATEDIFF(DAY, q.DateSent, GETDATE()) >= 21
		)
		OR
		(
			EXISTS (
				SELECT 1
				FROM SCore.DataObjectTransition AS dot
				JOIN SCore.WorkflowStatus AS wfs ON wfs.ID = dot.StatusID
				WHERE
					dot.DataObjectGuid = q.Guid
					AND wfs.Guid = '25D5491C-42A8-4B04-B3AC-D648AF0F8032'
					AND DATEDIFF(DAY, dot.DateTimeUTC, GETUTCDATE()) >= 21
			)
		)
	) 
GO