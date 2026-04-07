SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[Quote_JobsSummary]
	  --WITH SCHEMABINDING
AS
SELECT		MIN (qi.ID)							   AS ID,
			q.RowStatus,
			q.Guid								   AS QuoteGuid,
			q.Overview,
			--p.Guid								   AS UprnGuid,
			q.IsSubjectToNDA,
			SUM (qit.LineNet)					   AS Net,
			SUM (	CASE
						WHEN rs.Number = 1 THEN qit.LineNet
						ELSE 0
					END
				)								   AS RibaStage1Fee,
			SUM (	CASE
						WHEN rs.Number = 2 THEN qit.LineNet
						ELSE 0
					END
				)								   AS RibaStage2Fee,
			SUM (	CASE
						WHEN rs.Number = 3 THEN qit.LineNet
						ELSE 0
					END
				)								   AS RibaStage3Fee,
			SUM (	CASE
						WHEN rs.Number = 4 THEN qit.LineNet
						ELSE 0
					END
				)								   AS RibaStage4Fee,
			SUM (	CASE
						WHEN rs.Number = 5 THEN qit.LineNet
						ELSE 0
					END
				)								   AS RibaStage5Fee,
			SUM (	CASE
						WHEN rs.Number = 6 THEN qit.LineNet
						ELSE 0
					END
				)								   AS RibaStage6Fee,
			SUM (	CASE
						WHEN rs.Number = 7 THEN qit.LineNet
						ELSE 0
					END
				)								   AS RibaStage7Fee,
			SUM (	CASE
						WHEN rs.Number = 99 THEN qit.LineNet
						ELSE 0
					END
				)								   AS PreConstructionStageFee,
			SUM (	CASE
						WHEN rs.Number = 999 THEN qit.LineNet
						ELSE 0
					END
				)								   AS ConstructionStageFee,
			ou.Guid								   AS OrganisationalUnitGuid,
			jt.Guid								   AS JobTypeGuid,
			--acc.Guid							   AS ClientAccountGuid,
			--ad.Guid								   AS ClientAddressGuid,
			--c.Guid								   AS ClientContactGuid,
			cr.Guid								   AS ContractGuid,
			--agent_acc.Guid						   AS AgentAccountGuid,
			--agent_ad.Guid						   AS AgentAddressGuid,
			--agent_c.Guid						   AS AgentContactGuid,
			'00000000-0000-0000-0000-000000000000' AS IdentityGuid,
			-1									   AS QuoteItemId,
			q.ExternalReference,
			SUM (qit.LineNet)					   AS AgreedFee,
			jt.Name								   AS JobType,
			(
				SELECT MAX(dot.DateTimeUTC)
				FROM SCore.DataObjectTransition AS dot
				WHERE dot.DataObjectGuid = q.Guid
				  AND dot.StatusID = 7
			) AS DateAccepted,

			--q.DateAccepted,
			q.FeeCap,
			--proj.Guid							   AS ProjectGuid,
			ISNULL (   crs.Guid,
					   '00000000-0000-0000-0000-000000000000'
				   )							   AS CurrentRibaStageGuid,
			ISNULL (   ars.Guid,
					   '00000000-0000-0000-0000-000000000000'
				   )							   AS AppointedRibaStageGuid,
			q.ValueOfWork,
			acr.Guid							   AS AgentContractGuid
FROM		SSop.QuoteItems			  AS qi
JOIN		SSop.QuoteItemTotals	  AS qit ON (qit.ID				= qi.ID)
JOIN		SJob.RibaStages			  AS rs ON (rs.ID				= qi.ProvideAtStageID)
JOIN		SProd.Products			  AS p2 ON (p2.ID				= qi.ProductId)
JOIN		SJob.JobTypes			  AS jt ON (p2.CreatedJobType	= jt.ID)
JOIN		SSop.Quotes				  AS q ON (q.ID					= qi.QuoteId)
JOIN		SCore.OrganisationalUnits AS ou ON (ou.ID				= q.OrganisationalUnitID)
JOIN		SSop.Contracts			  AS cr ON (cr.ID				= q.ContractID)
JOIN		SSop.Contracts			  AS acr ON (acr.ID				= q.AgentContractID)
JOIN		SSop.EnquiryServices	  AS es ON (es.ID				= q.EnquiryServiceID)
JOIN		SSop.Enquiries			  AS e ON (e.ID					= es.EnquiryId)
JOIN		SJob.RibaStages			  AS crs ON (crs.ID				= e.CurrentProjectRibaStageID)
JOIN		SJob.RibaStages			  AS ars ON (ars.ID				= q.AppointmentFromRibaStageId)
--JOIN		SCrm.Accounts			  AS acc ON (acc.ID				= e.ClientAccountId)
--JOIN		SCrm.AccountAddresses	  AS ad ON (ad.ID				= e.ClientAddressId)
--JOIN		SCrm.AccountContacts	  AS c ON (c.ID					= e.ClientAccountContactId)
--JOIN		SCrm.Accounts			  AS agent_acc ON (agent_acc.ID = e.AgentAccountId)
--JOIN		SCrm.AccountAddresses	  AS agent_ad ON (agent_ad.ID	= e.AgentAddressId)
--JOIN		SCrm.AccountContacts	  AS agent_c ON (agent_c.ID		= e.AgentAccountContactId)
--JOIN		SJob.Properties			  AS p ON (p.ID					= e.PropertyId)
--JOIN		SSop.Projects			  AS proj ON (proj.ID			= e.ProjectId)
WHERE		(qi.RowStatus NOT IN (0, 254))
		AND (qi.Quantity			> 0)
		AND (qi.CreatedJobId		< 0)
		AND (qi.DoNotConsolidateJob = 0)
		AND (NOT EXISTS
	(
		SELECT	1
		FROM	SProd.Products AS prod2
		WHERE	(prod2.NeverConsolidate = 1)
			AND (qi.ProductId			= prod2.ID)
	)
			)
GROUP BY	q.RowStatus,
			q.Guid,
			q.Overview,
			--p.Guid,
			q.IsSubjectToNDA,
			jt.Guid,
			jt.Name,
			ou.Guid,
			--acc.Guid,
			--ad.Guid,
			--c.Guid,
			cr.Guid,
			--agent_acc.Guid,
			--agent_ad.Guid,
			--agent_c.Guid,
			q.ExternalReference,
			q.DateAccepted,
			q.FeeCap,
			--proj.Guid,
			crs.Guid,
			ars.Guid,
			q.ValueOfWork,
			q.AgentContractID,
			acr.Guid
UNION ALL
SELECT		qi.ID								  AS ID,
			q.RowStatus,
			q.Guid,
			q.Overview,
			--p.Guid,
			q.IsSubjectToNDA,
			qit.LineNet,
			CASE
				WHEN rs.Number = 1 THEN qit.LineNet
				ELSE 0
			END,
			CASE
				WHEN rs.Number = 2 THEN qit.LineNet
				ELSE 0
			END,
			CASE
				WHEN rs.Number = 3 THEN qit.LineNet
				ELSE 0
			END,
			CASE
				WHEN rs.Number = 4 THEN qit.LineNet
				ELSE 0
			END,
			CASE
				WHEN rs.Number = 5 THEN qit.LineNet
				ELSE 0
			END,
			CASE
				WHEN rs.Number = 6 THEN qit.LineNet
				ELSE 0
			END,
			CASE
				WHEN rs.Number = 7 THEN qit.LineNet
				ELSE 0
			END,
			CASE
				WHEN rs.Number = 99 THEN qit.LineNet
				ELSE 0
			END,
			CASE
				WHEN rs.Number = 999 THEN qit.LineNet
				ELSE 0
			END,
			ou.Guid,
			jt.Guid,
			--acc.Guid,
			--ad.Guid,
			--c.Guid,
			cr.Guid,
			--agent_acc.Guid,
			--agent_ad.Guid,
			--agent_c.Guid,
			'00000000-0000-0000-0000-000000000000',
			qi.ID,
			q.ExternalReference,
			--vow.Guid,
			qi.Net,
			jt.Name,
			--q.DateAccepted,
			(
				SELECT MAX(dot.DateTimeUTC)
				FROM SCore.DataObjectTransition AS dot
				JOIN SCore.WorkflowTransition AS wfs ON (wfs.ID = dot.StatusID)
				WHERE 
					(dot.DataObjectGuid = q.Guid)
				    AND (wfs.Guid = '21A29AEE-2D99-4DA3-8182-F31813B0C498')
			) AS DateAccepted,

			q.FeeCap,
			--proj.Guid							  AS ProjectGuid,
			ISNULL (   crs.Guid,
					   '00000000-0000-0000-0000-000000000000'
				   ),
			ISNULL (   ars.Guid,
					   '00000000-0000-0000-0000-000000000000'
				   ),
			q.ValueOfWork,
			acr.Guid
FROM		SSop.QuoteItems			  AS qi
JOIN		SSop.QuoteItemTotals	  AS qit ON (qit.ID				= qi.ID)
JOIN		SJob.RibaStages			  AS rs ON (rs.ID				= qi.ProvideAtStageID)
JOIN		SSop.Quotes				  AS q ON (q.ID					= qi.QuoteId)
JOIN		SProd.Products			  AS prod ON (prod.ID			= qi.ProductId)
JOIN		SJob.JobTypes			  AS jt ON (jt.ID				= prod.CreatedJobType)
JOIN		SCore.OrganisationalUnits AS ou ON (ou.ID				= q.OrganisationalUnitID)
JOIN		SSop.Contracts			  AS cr ON (cr.ID				= q.ContractID)
JOIN		SSop.Contracts			  AS acr ON (acr.ID				= q.AgentContractID)
JOIN		SSop.EnquiryServices	  AS es ON (es.ID				= q.EnquiryServiceID)
JOIN		SSop.Enquiries			  AS e ON (e.ID					= es.EnquiryId)
JOIN		SJob.RibaStages			  AS crs ON (crs.ID				= e.CurrentProjectRibaStageID)
JOIN		SJob.RibaStages			  AS ars ON (ars.ID				= q.AppointmentFromRibaStageId)
--JOIN		SCrm.Accounts			  AS acc ON (acc.ID				= e.ClientAccountId)
--JOIN		SCrm.AccountAddresses	  AS ad ON (ad.ID				= e.ClientAddressId)
--JOIN		SCrm.AccountContacts	  AS c ON (c.ID					= e.ClientAccountContactId)
--JOIN		SCrm.Accounts			  AS agent_acc ON (agent_acc.ID = e.AgentAccountId)
--JOIN		SCrm.AccountAddresses	  AS agent_ad ON (agent_ad.ID	= e.AgentAddressId)
--JOIN		SCrm.AccountContacts	  AS agent_c ON (agent_c.ID		= e.AgentAccountContactId)
--JOIN		SJob.Properties			  AS p ON (p.ID					= e.PropertyId)
--JOIN		SSop.Projects			  AS proj ON (proj.ID			= e.ProjectId)
WHERE		(qi.RowStatus NOT IN (0, 254))
		AND (qi.Quantity			  > 0)
		AND (qi.CreatedJobId		  < 0)
		AND
		  (
			  (prod.NeverConsolidate  = 1)
		   OR (qi.DoNotConsolidateJob = 1)
		  );
GO