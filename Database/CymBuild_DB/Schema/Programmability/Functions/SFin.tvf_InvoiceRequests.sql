SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_InvoiceRequests]
	(
		@UserId INT
	)
RETURNS TABLE
       --WITH SCHEMABINDING
AS
RETURN  SELECT				ir.ID,
					ir.RowStatus,
					ir.RowVersion,
					ir.Guid,
					ir.Notes,
					ir.CreatedDateTimeUTC,
					ir.InvoicingType,
					ir.ExpectedDate,
					ir.ManualStatus,
					i.Guid					  AS RequesterUserId,
					i.FullName				  AS SurveyorName,
					j.Guid					  AS JobId,
					j.Number,
					j.FinanceAccountID,
					FinAcc.Name AS FinanceAccountName,
																		-- [CBLD-522]
					STRING_AGG (   ActT.Name,
								   ', '
							   )			  AS ActivityID,			-- Activity name
																		-- [CBLD-525]
					Acc.Name				  AS ClientName,			-- Client the request is associated with
					SUM (IRI.Net)			  AS Net,					-- Invoice Request Amount
					MAX (Act.EndDate)		  AS EndDate,				-- On or prior to today's date
					j.BillingInstruction	  AS JobBillingInstruction, -- Job billing instruction
					FinAcc.BillingInstruction AS CRMBillingInstruction, -- CRM billing instruction
					CASE
						WHEN MAX (	 CASE
										 WHEN ActT.IsBillable = 0 THEN 'No'
										 ELSE 'Yes'
									 END
								 ) = 'Yes' THEN 'Yes'
						ELSE 'No'
					END						  AS IsBillable,
					OrgUnit.Name AS OrgUnit
					
	   FROM			SFin.InvoiceRequests	 AS ir
	   JOIN			SJob.Jobs				 AS j ON (j.ID					 = ir.JobId)
	   JOIN			SCore.Identities		 AS i ON (i.ID					 = ir.RequesterUserId)
	   JOIN			SCore.OrganisationalUnits AS OrgUnit ON (OrgUnit.ID = j.OrganisationalUnitID)
	   INNER JOIN	SFin.InvoiceRequestItems AS IRI ON (IRI.InvoiceRequestId = ir.ID) 
	   INNER JOIN	SJob.Activities			 AS Act ON (IRI.ActivityId		 = Act.ID) 
	   INNER JOIN	SJob.ActivityTypes		 AS ActT ON (Act.ActivityTypeID	 = ActT.ID) 
	   INNER JOIN	SCrm.Accounts			 AS Acc ON (Acc.ID				 = j.ClientAccountID) 
	   LEFT JOIN	SCrm.Accounts			 AS FinAcc ON (FinAcc.ID		 = j.FinanceAccountID)
	   WHERE		(ir.RowStatus NOT IN (0, 254))
				AND (ir.ID			  > 0)
				AND (j.CannotBeInvoiced <> 1)
				AND (ir.IsMerged = 0)
				AND (EXISTS
					   (
						   SELECT	1
						   FROM		SFin.InvoiceRequestItems AS iri
						   WHERE	(iri.RowStatus NOT IN (0, 254))
								AND (iri.InvoiceRequestId = ir.ID)
					   )
					)
				-- Completed Activity
				AND
				  (
					  (EXISTS
						   (
							   SELECT		1
							   FROM			SFin.InvoiceRequestItems AS iri
							   INNER JOIN	SJob.Activities			 AS act ON (iri.ActivityId = act.ID)
							   WHERE		(
												act.ActivityStatusID = 3
												OR act.ID				 < 0
											)
										AND (iri.InvoiceRequestId	 = ir.ID)  -- Always connect back to main query
										AND	(iri.RowStatus NOT IN (0, 254))
										AND	(act.RowStatus NOT IN (0, 254))
						   )
					  )
				   OR (IRI.ActivityId < 0)
				  )
				
				--Activity is on or prior to today's date.
				AND
				  (
					  (EXISTS
						   (
							   SELECT		1
							   FROM			SFin.InvoiceRequestItems AS iri
							   INNER JOIN	SJob.Activities			 AS Act ON (iri.ActivityId = Act.ID)
							   WHERE		(iri.RowStatus NOT IN (0, 254))
										AND	(act.RowStatus NOT IN (0, 254))
										AND (CAST (Act.EndDate AS DATE) <= CAST (GETDATE () AS DATE))
										AND (iri.InvoiceRequestId		= ir.ID)  -- Always connect back to main query
						   )
					  )
				   OR (IRI.ActivityId < 0)
				  )
				AND (EXISTS
						   (
							   SELECT	1
							   FROM		SCore.ObjectSecurityForUser_CanRead (	j.Guid,
																				@UserId
																			) AS oscr
						   )
					)
				AND (EXISTS
						   (
							   SELECT	1
							   FROM		SCore.ObjectSecurityForUser_CanRead (	ir.Guid,
																				@UserId
																			) AS oscr
						   )
					)
				AND (NOT EXISTS
							(
								SELECT		1
								FROM			SFin.TransactionDetails	 AS td
								INNER JOIN	SFin.InvoiceRequestItems AS iri ON (iri.ID = td.InvoiceRequestItemId)
								WHERE		(iri.InvoiceRequestId = ir.ID)
										AND	(td.RowStatus NOT IN (0, 254))
										AND	(iri.RowStatus NOT IN (0, 254))
						
							)
					)
	   GROUP BY		ir.ID,
					ir.RowStatus,
					ir.RowVersion,
					ir.Guid,
					ir.Notes,
					ir.CreatedDateTimeUTC,
					ir.InvoicingType,
					ir.ExpectedDate,
					ir.ManualStatus,
					i.Guid,
					i.FullName,
					j.Guid,
					j.Number,
					FinAcc.Name,
					j.FinanceAccountID,
					Acc.Name,
					j.BillingInstruction,
					FinAcc.BillingInstruction,
					OrgUnit.Name;
GO