SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_ClosedEnquiries]
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
			  AND NOT EXISTS (
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
				--Ensure the record is  declined.
				AND (
						(e.DeclinedToQuoteDate IS NOT NULL)
						OR EXISTS
							(
								SELECT 1 
								FROM SCore.DataObjectTransition AS dot
								JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
								WHERE 
									(dot.RowStatus NOT IN (0,254))
									AND (dot.DataObjectGuid = e.Guid)
									AND (wfs.Guid = '708C00E6-F45F-4CB2-8E91-A80B8B8E802E' ) --Declined
							)
					) 
				--Ensure the record is not dead.
				AND (
						(e.DeadDate IS NULL)
						AND NOT EXISTS
							(
								SELECT 1 
								FROM SCore.DataObjectTransition AS dot
								JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
								WHERE 
									(dot.RowStatus NOT IN (0,254))
									AND (dot.DataObjectGuid = e.Guid)
									AND (wfs.Guid = '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D' ) --Declined
							)
					) 
				-- Include records where status "Withdrawn" is present
				OR (
					EXISTS
						(
							SELECT 1 
							FROM SCore.DataObjectTransition AS dot
							JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
							WHERE 
								(dot.RowStatus NOT IN (0,254))
								AND (dot.DataObjectGuid = e.Guid)
								AND (wfs.Name = N'Withdrawn' ) 
								AND NOT EXISTS
								(
									SELECT 1 
									FROM SCore.DataObjectTransition AS dot2
									JOIN
										SCore.WorkflowStatus AS wfs2 ON (wfs2.ID = dot2.StatusID)
									WHERE
										(dot2.RowStatus NOT IN (0,254))
										AND (dot2.DataObjectGuid = e.Guid )
										AND (wfs2.Name <> N'Withdrawn')
										AND (dot2.ID > dot.ID)
								)
						)
					) 
				--Check if there is no associated job.
				AND NOT EXISTS
					(
						SELECT 
							1
						FROM 
							SSop.EnquiryServices AS es
						JOIN
							SSop.QuoteItems as qi ON (qi.QuoteId = es.QuoteId)
						WHERE 
							(es.EnquiryId = e.ID) AND
							(qi.CreatedJobId <> -1)
					)  
				AND (EXISTS
					(
						SELECT	1
						FROM	SCore.ObjectSecurityForUser_CanRead (e.guid, @UserId) oscr
					)
		)
GO