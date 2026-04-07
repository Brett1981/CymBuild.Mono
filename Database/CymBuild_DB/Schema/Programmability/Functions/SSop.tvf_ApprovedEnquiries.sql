SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SSop].[tvf_ApprovedEnquiries]
	(
		@UserId INT
	)
RETURNS TABLE
                    --WITH SCHEMABINDING
AS
RETURN SELECT		
	e.ID,
	e.Number,
	e.Guid,
	e.RowStatus,
	e.RowVersion,
	e.DescriptionOfWorks AS Description,
	client.Name + N' / ' + agent.Name AS ClientAgent,
	e.ExternalReference,
	CASE WHEN JobType.Name IS NULL THEN N'N/A' ELSE JobType.Name END AS JobTypeName ,
	e.Date AS CreatedOn,
	CONVERT(DATE,e.DeclinedToQuoteDate, 103) AS DateDeclined,
	asset.FormattedAddressComma as Asset,
	ecf.EnquiryStatus
FROM			
	SSop.Enquiries as e
OUTER APPLY (
				SELECT jt.Name
				FROM SSop.EnquiryServices es2
				JOIN SJob.JobTypes jt ON jt.ID = es2.JobTypeId
				WHERE es2.EnquiryId = e.ID
					AND NOT EXISTS 
					(
						SELECT 1
						FROM SSop.EnquiryServices es3
						JOIN SJob.JobTypes jt2 ON jt2.ID = es3.JobTypeId
						WHERE es3.EnquiryId = es2.EnquiryId
						AND jt2.ID > jt.ID
					)
			) AS JobType
JOIN
	SCrm.Accounts as client ON (client.ID = e.ClientAccountId)
JOIN
	SCrm.Accounts as agent ON (agent.ID = e.AgentAccountId)
JOIN
	SJob.Assets as asset ON (asset.ID = e.PropertyId)
JOIN
	SSop.Enquiry_CalculatedFields AS ecf ON (ecf.ID = e.ID)
		
WHERE		
		(e.RowStatus NOT IN (0, 254))
	AND (EXISTS
			(
				SELECT 1
				FROM SCore.DataObjectTransition AS dot
				JOIN SCore.WorkflowStatus AS wfs ON (dot.StatusID = wfs.ID)
				WHERE
						(dot.RowStatus NOT IN (0, 254))
					AND (dot.DataObjectGuid = e.Guid)
					AND (wfs.Guid = '3070A373-0E0A-4261-B942-66CB512EE1B6')
					AND NOT EXISTS
						(
							SELECT 1 
							FROM SCore.DataObjectTransition AS dot2
							WHERE 
									(dot2.RowStatus NOT IN (0,254))
								AND (dot2.DataObjectGuid = e.Guid)
								AND (dot2.ID > dot.ID)
						)
			)
		)
	AND (EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (e.guid, @UserId) oscr
			)
		)
GO