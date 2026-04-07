SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SJob].[Jobs_Read]
	--WITH SCHEMABINDING
AS
SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.AgreedFee,
		root_hobt.RibaStage1Fee,
		root_hobt.RibaStage2Fee,
		root_hobt.RibaStage3Fee,
		root_hobt.RibaStage4Fee,
		root_hobt.RibaStage5Fee,
		root_hobt.RibaStage6Fee,
		root_hobt.RibaStage7Fee,
		root_hobt.PreConstructionStageFee,
		root_hobt.ConstructionStageFee,
		root_hobt.ArchiveBoxReference,
		root_hobt.ArchiveReferenceLink,
		root_hobt.CreatedOn,
		root_hobt.ExternalReference,
		root_hobt.IsSubjectToNDA,
		root_hobt.JobCancelled,
		root_hobt.JobCompleted,
		root_hobt.JobDescription,
		root_hobt.JobStarted,
		root_hobt.Number,
		root_hobt.VersionID,
		root_hobt.IsCompleteForReview,
		root_hobt.ReviewedDateTimeUTC,
		root_hobt.LegacyID,
		root_hobt.AppFormReceived,
		root_hobt.FeeCap,
		root_hobt.JobDormant,
		root_hobt.DeadDate,
		root_hobt.PurchaseOrderNumber,
		root_hobt.ClientAppointmentReceived,
		root_hobt.ValueOfWork,
		root_hobt.CannotBeInvoiced,
		root_hobt.CannotBeInvoicedReason,
		rs.Guid								   AS CurrentRibaStageId,
		afs.Guid							   AS AppointedFromStageId,
		t.Guid								   AS JobTypeID,
		s.Guid								   AS SurveyorID,
		cb.Guid								   AS CreatedByUserID,
		ca.Guid								   AS ClientAccountID,
		aa.Guid								   AS AgentAccountID,
		fa.Guid								   AS FinanceAccountID,
		cc.Guid								   AS ClientContactID,
		ac.Guid								   AS AgentContactID,
		fc.Guid								   AS FinanceContactID,
		ou.Guid								   AS OrganisationalUnitID,
		'00000000-0000-0000-0000-000000000000' AS QuoteItemID,
		uprn.Guid							   AS UprnId,
		vow.Guid							   AS ValueOfWorkID,
		Rev.Guid							   AS ReviewedByUserID,
		con.Guid							   AS ContractID,
		cad.Guid							   AS ClientAddressID,
		aad.Guid							   AS AgentAddressID,
		fad.Guid							   AS FinanceAddressID,
		proj.Guid							   AS ProjectId,
		root_hobt.BillingInstruction		   AS BillingInstruction,
		acon.Guid                              AS AgentContractID,
		root_hobt.CompletedForReviewDate,
		sector.Guid as SectorId,
		market.Guid AS MarketId
FROM	SJob.Jobs				  AS root_hobt
JOIN	SJob.JobTypes			  AS t ON (t.ID		  = root_hobt.JobTypeID)
JOIN	SCore.Identities		  AS s ON (s.ID		  = root_hobt.SurveyorID)
JOIN	SCore.Identities		  AS cb ON (cb.ID	  = root_hobt.CreatedByUserID)
JOIN	SCrm.Accounts			  AS ca ON (ca.ID	  = root_hobt.ClientAccountID)
JOIN	SCrm.Accounts			  AS aa ON (aa.ID	  = root_hobt.AgentAccountID)
JOIN	SCrm.Accounts			  AS fa ON (fa.ID	  = root_hobt.FinanceAccountID)
JOIN	SCrm.AccountAddresses	  AS cad ON (cad.ID	  = root_hobt.ClientAddressID)
JOIN	SCrm.AccountAddresses	  AS aad ON (aad.ID	  = root_hobt.AgentAddressID)
JOIN	SCrm.AccountAddresses	  AS fad ON (fad.ID	  = root_hobt.FinanceAddressID)
JOIN	SCrm.AccountContacts	  AS cc ON (cc.ID	  = root_hobt.ClientContactID)
JOIN	SCrm.AccountContacts	  AS ac ON (ac.ID	  = root_hobt.AgentContactID)
JOIN	SCrm.AccountContacts	  AS fc ON (fc.ID	  = root_hobt.FinanceContactID)
JOIN	SJob.Assets				  AS uprn ON (uprn.ID = root_hobt.UprnID)
JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID	  = root_hobt.OrganisationalUnitID)
JOIN	SJob.ValuesOfWork		  AS vow ON (vow.ID	  = root_hobt.ValueOfWorkID)
JOIN	SCore.Identities		  AS Rev ON (Rev.ID	  = root_hobt.ReviewedByUserID)
JOIN	SSop.Contracts			  AS con ON (con.ID	  = root_hobt.ContractID)
JOIN	SSop.Contracts			  AS acon ON (acon.ID  = root_hobt.AgentContractID)
JOIN	SJob.RibaStages			  AS rs ON (rs.ID	  = root_hobt.CurrentRibaStageId)
JOIN	SJob.RibaStages			  AS afs ON (afs.ID	  = root_hobt.AppointedFromStageId)
JOIN	SSop.Projects			  AS proj ON (proj.ID = root_hobt.ProjectId)
JOIN    SCore.Sectors			  AS sector ON (sector.ID = root_hobt.SectorId)
JOIN    SCore.Markets			  AS market ON (market.ID = root_hobt.MarketId)
GO