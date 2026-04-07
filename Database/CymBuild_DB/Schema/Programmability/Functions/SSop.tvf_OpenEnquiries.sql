SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_OpenEnquiries]
(
	@UserId INT
)
RETURNS TABLE
           --WITH SCHEMABINDING
AS RETURN	
SELECT  e.ID,
        e.RowStatus,
        e.RowVersion,
        e.Guid,
		CASE WHEN e.Revision = 0 THEN e.Number ELSE (e.Number + N' (' + CONVERT(NVARCHAR(2), e.Revision) + N') ') END AS Number,
		e.QuotingDeadlineDate,
		e.ExternalReference,
		LEFT(e.DescriptionOfWorks, 200) AS DescriptionOfWorks, 
		CASE WHEN client.Name <> N'' THEN client.Name ELSE e.ClientName END + N' / ' + CASE WHEN agent.Name <> N'' THEN agent.Name ELSE e.AgentName END  AS ClientAgentAccount,
		CASE WHEN uprn.AssetNumber > 0 THEN uprn.FormattedAddressComma ELSE e.PropertyNameNumber + N' ' + e.PropertyAddressLine1 END AS Property,
		calculatedFields.EnquiryStatus
FROM    SSop.Enquiries e
--JOIN	SSop.Enquiry_CalculatedFields AS ecf ON (ecf.ID = e.ID)
JOIN	SCrm.Accounts client ON (client.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountId)
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
OUTER APPLY
	(
		SELECT ecf.EnquiryStatus
		FROM SSop.Enquiry_CalculatedFields AS ecf
		WHERE 
			(ecf.ID = e.ID)
	) calculatedFields
WHERE   (e.RowStatus NOT IN (0, 254))
	AND	(e.ID > 0)
	AND	(EXISTS
			(
				SELECT
						1
				FROM
				SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
			)
		)
	--Not declined.
	AND	(
		(e.DeclinedToQuoteDate IS NULL)
		AND ( NOT EXISTS(
				SELECT 1 
				FROM SCore.DataObjectTransition AS dot
				JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
				WHERE 
					(dot.DataObjectGuid = e.Guid)
					AND (dot.RowStatus NOT IN (0,254))
					AND (wfs.Guid = '708C00E6-F45F-4CB2-8E91-A80B8B8E802E') --DECLINED
			))
		)
	-- Not dead
	AND	(
		(e.DeadDate IS NULL)
		AND ( NOT EXISTS(
				SELECT 1 
				FROM SCore.DataObjectTransition AS dot
				JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
				WHERE 
					(dot.DataObjectGuid = e.Guid)
					AND (dot.RowStatus NOT IN (0,254))
					AND (wfs.Guid = '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D') --DEAD
			))
		)
	AND	(NOT EXISTS
			(
				SELECT 1
				FROM SSop.Quotes AS q
				JOIN SSop.EnquiryServices AS es ON (q.EnquiryServiceID = es.ID)
				WHERE 
					(es.EnquiryId = e.ID)
					AND (es.RowStatus NOT IN (0,254))
					
			)
		)
	AND (calculatedFields.EnquiryStatus NOT IN (N'Complete', N'Sent', N'Quoting', N'Accepted', N'Rejected', N'Withdrawn', N'Expired'))
	AND	(e.Date > DATEADD(MONTH, -6, GETDATE()))
GO