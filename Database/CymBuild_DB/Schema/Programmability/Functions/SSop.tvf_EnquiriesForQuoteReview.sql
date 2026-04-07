SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_EnquiriesForQuoteReview]
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
		e.Number,
		e.ExternalReference,
		LEFT(e.DescriptionOfWorks, 200) AS DescriptionOfWorks, 
		CASE WHEN acc.Name <> N'' THEN acc.Name ELSE e.ClientName END AS Account,
		-- New fields
		CASE WHEN client.Name <> N'' THEN client.Name ELSE e.ClientName END + N' / ' + CASE WHEN agent.Name <> N'' THEN agent.Name ELSE e.AgentName END  AS ClientAgentAccount,
		CASE WHEN uprn.AssetNumber > 0 THEN uprn.FormattedAddressComma ELSE e.PropertyNameNumber + N' ' + e.PropertyAddressLine1 END AS Property,
		ecf.EnquiryStatus,
		org.Name AS OrgUnit,
		e.Date,
		ISNULL(ServiceTypes.Name, N'Multi Discipline') AS Disciplines,
		e.QuotingDeadlineDate AS Deadline
FROM    SSop.Enquiries e
JOIN	SCrm.Accounts acc ON (acc.ID = e.ClientAccountID)
JOIN	SSop.Enquiry_CalculatedFields AS ecf ON (ecf.ID = e.ID)
JOIN	SCrm.Accounts client ON (client.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountId)
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
JOIN	SCore.OrganisationalUnits AS org ON (org.ID = e.OrganisationalUnitID)
OUTER APPLY (
	SELECT	jt.Name
	FROM	SJob.JobTypes AS jt
	WHERE	(EXISTS
				(
					SELECT	1
					FROM 	SSop.EnquiryServices AS es 
					WHERE	(es.JobTypeId = jt.ID)
						AND	(es.EnquiryId = e.ID)
						AND	(es.RowStatus NOT IN (0, 254))
						AND	(NOT EXISTS
								(
									SELECT	1
									FROM	SSop.EnquiryServices es2 
									WHERE	(es2.ID <> es.ID)
										AND	(es2.EnquiryId = es.EnquiryId)
										AND	(es2.RowStatus NOT IN (0, 254))
								)
							)
				)
			)
) AS ServiceTypes
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
	AND (e.QuotingDeadlineDate > GETDATE())
	--Last applied status must be "Ready for Quote Review"
	AND EXISTS
		(
				SELECT 1 
				FROM SCore.DataObjectTransition AS dob
				JOIN SCore.WorkflowStatus as wfs ON (dob.StatusID = wfs.ID)
				WHERE 
						(dob.DataObjectGuid = e.Guid)
					AND (dob.RowStatus NOT IN (0,254))
					--Ready for Quote Review
					AND (
							wfs.Guid = 'EB867FA0-9608-4CC7-93BE-CC8E8140E8F0'  
						
						)
					--Exclude enquiries with status "Withdrawn" or "Declined"
					AND (
								(wfs.Guid <> 'B41290F9-C0CE-44E2-A5E7-364D6CD52446')  --Withdrawn
							OR	(wfs.Guid <> '708C00E6-F45F-4CB2-8E91-A80B8B8E802E')  --Declined
						)
					AND NOT EXISTS
						(
							SELECT 1 
							FROM SCore.DataObjectTransition AS dob2
							WHERE 
								(dob2.DataObjectGuid = e.Guid)
							AND (dob2.RowStatus NOT IN (0,254))
							AND (dob2.ID > dob.ID)

						)

		)
	
	AND	(EXISTS
			(
				SELECT	1
				FROM	SSop.EnquiryServices es
				WHERE	(es.EnquiryId = e.ID)
					AND	(es.RowStatus NOT IN (0, 254))
					AND	(NOT EXISTS
							(
								SELECT	1
								FROM	SSop.Quotes AS q
								WHERE	(q.EnquiryServiceID = es.ID)
									AND	(q.RowStatus NOT IN (0, 254))
							)
						)
			)
		)
GO