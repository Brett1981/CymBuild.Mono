SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[EnquiriesRevise] @SourceGuid UNIQUEIDENTIFIER,
									 @TargetGuid UNIQUEIDENTIFIER
AS
BEGIN

	DECLARE @SourceID INT,
			@ID		  INT,
			@IsInsert BIT;

	SELECT	@SourceID = ID
	FROM	SSop.Enquiries
	WHERE	(Guid = @SourceGuid);

	IF (@@ROWCOUNT > 1)
	BEGIN
		;
		THROW 60000, N'Invalid source Enquiry', 1;
	END;

	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SSop.Enquiries AS e
		 WHERE	(e.Guid = @SourceGuid)
			AND (EXISTS
					(
						SELECT	1
						FROM	SSop.EnquiryServices AS es
						JOIN	SSop.EnquiryService_ExtendedInfo esei ON (esei.Id = es.ID)
						WHERE	(es.EnquiryId = e.ID)
							AND	(esei.DateAccepted IS NOT NULL)
					)
				)
	 )
	   )
	BEGIN
		; THROW 60000, N'You cannot revise an accepted Enquiry', 1;
	END;

	EXEC SCore.UpsertDataObject @Guid = @TargetGuid,
								@SchemeName = N'SSop',
								@ObjectName = N'Enquiries',
								@IncludeDefaultSecurity = 1,
								@IsInsert = @IsInsert;

	INSERT	SSop.Enquiries
		 (RowStatus,
		  Guid,
		  OrganisationalUnitID,
		  Date,
		  CreatedByUserId,
		  Number,
		  PropertyId,
		  PropertyNameNumber,
		  PropertyAddressLine1,
		  PropertyAddressLine2,
		  PropertyAddressLine3,
		  PropertyTown,
		  PropertyCountyId,
		  PropertyPostCode,
		  PropertyCountryId,
		  ClientAccountId,
		  ClientAddressId,
		  ClientAccountContactId,
		  ClientName,
		  ClientAddressNameNumber,
		  ClientAddressLine1,
		  ClientAddressLine2,
		  ClientAddressLine3,
		  ClientAddressTown,
		  ClientAddressCountyId,
		  ClientAddressPostCode,
		  ClientAddressCountryId,
		  AgentAccountId,
		  AgentAddressId,
		  AgentAccountContactId,
		  AgentName,
		  AgentAddressNameNumber,
		  AgentAddressLine1,
		  AgentAddressLine2,
		  AgentAddressLine3,
		  AgentTown,
		  AgentCountyId,
		  AgentAddressPostCode,
		  AgentCountryId,
		  DescriptionOfWorks,
		  ValueOfWork,
		  CurrentProjectRibaStageID,
		  RibaStage0Months,
		  RibaStage1Months,
		  RibaStage2Months,
		  RibaStage3Months,
		  RibaStage4Months,
		  RibaStage5Months,
		  RibaStage6Months,
		  RibaStage7Months,
		  PreConstructionStageMonths,
		  ConstructionStageMonths,
		  SendInfoToClient,
		  SendInfoToAgent,
		  KeyDates,
		  ExpectedProcurementRoute,
		  Notes,
		  EnquirySourceId,
		  IsReadyForQuoteReview,
		  QuotingDeadlineDate,
		  DeclinedToQuoteDate,
		  DeclinedToQuoteReason,
		  ExternalReference,
		  ProjectId,
		  IsSubjectToNDA,
		  DeadDate,
		  ChaseDate1,
		  ChaseDate2,
		  IsClientFinanceAccount,
		  FinanceAccountId,
		  FinanceAddressId,
		  FinanceContactId,
		  FinanceAccountName,
		  FinanceAddressNameNumber,
		  FinanceAddressLine1,
		  FinanceAddressLine2,
		  FinanceAddressLine3,
		  FinanceTown,
		  FinanceCountyId,
		  FinancePostCode,
		  EnterNewClientDetails,
		  EnterNewAgentDetails,
		  EnterNewFinanceDetails,
		  EnterNewStructureDetails,
		  SignatoryIdentityId,
		  ProposalLetter,
		  Revision,
		  OriginalEnquiryId,
		  ClientContactDisplayName,
		  ClientContactDetailType,
		  ClientContactDetailTypeName,
		  ClientContactDetailTypeValue,
		  AgentContactDisplayName,
		  AgentContactDetailType,
		  AgentContactDetailTypeName,
		  AgentContactDetailTypeValue,
		  FinanceContactDisplayName,
		  FinanceContactDetailType,
		  FinanceContactDetailTypeName,
		  FinanceContactDetailTypeValue,
		  ContractID,
		  AgentContractID)

	SELECT	0,								-- RowStatus - tinyint
			@TargetGuid,					-- Guid - uniqueidentifier
			e.OrganisationalUnitID,			-- OrganisationalUnitID - int
			e.Date,							-- Date - datetime2(7)
			e.CreatedByUserId,				-- CreatedByUserId - int
			e.Number,							-- Number - nvarchar(50)
			e.PropertyId,					-- PropertyId - int
			e.PropertyNameNumber,			-- PropertyNameNumber - nvarchar(100)
			e.PropertyAddressLine1,			-- PropertyAddressLine1 - nvarchar(255)
			e.PropertyAddressLine2,			-- PropertyAddressLine2 - nvarchar(255)
			e.PropertyAddressLine3,			-- PropertyAddressLine3 - nvarchar(255)
			e.PropertyTown,					-- PropertyTown - nvarchar(255)
			e.PropertyCountyId,				-- PropertyCountyId - int
			e.PropertyPostCode,				-- PropertyPostCode - nvarchar(30)
			e.PropertyCountryId,			-- PropertyCountryId - int
			e.ClientAccountId,				-- ClientAccountId - int
			e.ClientAddressId,				-- ClientAddressId - int
			e.ClientAccountContactId,		-- ClientAccountContactId - int
			e.ClientName,					-- ClientName - nvarchar(250)
			e.ClientAddressNameNumber,		-- ClientAddressNameNumber - nvarchar(100)
			e.ClientAddressLine1,			-- ClientAddressLine1 - nvarchar(255)
			e.ClientAddressLine2,			-- ClientAddressLine2 - nvarchar(255)
			e.ClientAddressLine3,			-- ClientAddressLine3 - nvarchar(255)
			e.ClientAddressTown,			-- ClientAddressTown - nvarchar(255)
			e.ClientAddressCountyId,		-- ClientAddressCountyId - int
			e.ClientAddressPostCode,		-- ClientAddressPostCode - nvarchar(30)
			e.ClientAddressCountryId,		-- ClientAddressCountryId - int
			e.AgentAccountId,				-- AgentAccountId - int
			e.AgentAddressId,				-- AgentAddressId - int
			e.AgentAccountContactId,		-- AgentAccountContactId - int
			e.AgentName,					-- AgentName - nvarchar(250)
			e.AgentAddressNameNumber,		-- AgentAddressNameNumber - nvarchar(100)
			e.AgentAddressLine1,			-- AgentAddressLine1 - nvarchar(255)
			e.AgentAddressLine2,			-- AgentAddressLine2 - nvarchar(255)
			e.AgentAddressLine3,			-- AgentAddressLine3 - nvarchar(255)
			e.AgentTown,					-- AgentTown - nvarchar(255)
			e.AgentCountyId,				-- AgentCountyId - int
			e.AgentAddressPostCode,			-- AgentAddressPostCode - nvarchar(30)
			e.AgentCountryId,				-- AgentCountryId - int
			e.DescriptionOfWorks,			-- DescriptionOfWorks - nvarchar(4000)
			e.ValueOfWork,					-- ValueOfWork - decimal(19, 2)
			e.CurrentProjectRibaStageID,	-- CurrentProjectRibaStageID - int
			e.RibaStage0Months,				-- RibaStage0Months - int
			e.RibaStage1Months,				-- RibaStage1Months - int
			e.RibaStage2Months,				-- RibaStage2Months - int
			e.RibaStage3Months,				-- RibaStage3Months - int
			e.RibaStage4Months,				-- RibaStage4Months - int
			e.RibaStage5Months,				-- RibaStage5Months - int
			e.RibaStage6Months,				-- RibaStage6Months - int
			e.RibaStage7Months,				-- RibaStage7Months - int
			e.PreConstructionStageMonths,	-- PreConstructionStageMonths - int
			e.ConstructionStageMonths,		-- ConstructionStageMonths - int
			e.SendInfoToClient,				-- SendInfoToClient - bit
			e.SendInfoToAgent,				-- SendInfoToAgent - bit
			e.KeyDates,						-- KeyDates - nvarchar(2000)
			e.ExpectedProcurementRoute,		-- ExpectedProcurementRoute - nvarchar(200)
			e.Notes,						-- Notes - nvarchar(max)
			e.EnquirySourceId,				-- EnquirySourceId - int
			(1),							-- IsReadyForQuoteReview - bit
			NULL,			-- QuotingDeadlineDate - date
			NULL,			-- DeclinedToQuoteDate - date
			N'',		-- DeclinedToQuoteReason - nvarchar(4000)
			e.ExternalReference,			-- ExternalReference - nvarchar(50)
			e.ProjectId,					-- ProjectId - int
			e.IsSubjectToNDA,				-- IsSubjectToNDA - bit
			NULL,							-- DeadDate - date
			NULL,							-- ChaseDate1 - date
			NULL,							-- ChaseDate2 - date
			e.IsClientFinanceAccount,		-- IsClientFinanceAccount - bit
			e.FinanceAccountId,				-- FinanceAccountId - int
			e.FinanceAddressId,				-- FinanceAddressId - int
			e.FinanceContactId,				-- FinanceContactId - int
			e.FinanceAccountName,			-- FinanceAccountName - nvarchar(250)
			e.FinanceAddressNameNumber,		-- FinanceAddressNameNumber - nvarchar(100)
			e.FinanceAddressLine1,			-- FinanceAddressLine1 - nvarchar(255)
			e.FinanceAddressLine2,			-- FinanceAddressLine2 - nvarchar(255)
			e.FinanceAddressLine3,			-- FinanceAddressLine3 - nvarchar(255)
			e.FinanceTown,					-- FinanceTown - nvarchar(255)
			e.FinanceContactId,				-- FinanceCountyId - int
			e.FinancePostCode,				-- FinancePostCode - nvarchar(30)
			e.EnterNewClientDetails,		-- EnterNewClientDetails - bit
			e.EnterNewAgentDetails,			-- EnterNewAgentDetails - bit
			e.EnterNewFinanceDetails,		-- EnterNewFinanceDetails - bit
			e.EnterNewStructureDetails,		-- EnterNewStructureDetails - bit
			e.SignatoryIdentityId,			-- SignatoryIdentityId - int
			e.ProposalLetter,				-- ProposalLetter - nvarchar(max)
			ISNULL (   latest_revision.rev,
					   0
				   ) + 1,
			CASE
				WHEN e.OriginalEnquiryId = (-1) THEN e.ID
				ELSE e.OriginalEnquiryId
			END,
			 e.ClientContactDisplayName, --ClientContactDisplayName nvarchar(250)
			 e.ClientContactDetailType,  --ClientContactDetailType smallint
			 e.ClientContactDetailTypeName, --ClientContactDetailTypeName nvarchar(100)
			 e.ClientContactDetailTypeValue, --ClientContactDetailTypeValue nvarchar(250)
			 e.AgentContactDisplayName, --AgentContactDisplayName nvarchar(250)
			 e.AgentContactDetailType,  --AgentContactDetailType smallint
			 e.AgentContactDetailTypeName, --AgentContactDetailTypeName nvarchar(100)
			 e.AgentContactDetailTypeValue, --AgentContactDetailTypeValue nvarchar(250)
			 e.FinanceContactDisplayName, --FinanceContactDisplayName nvarchar(250)
			 e.FinanceContactDetailType, --FinanceContactDetailType smallint
			 e.FinanceContactDetailTypeName, --FinanceContactDetailTypeName nvarchar(100)
			 e.FinanceContactDetailTypeValue, --FinanceContactDetailTypeValue nvarchar(250)
			 e.ContractID, --ContractID int
			 e.AgentContractID --AgentContractID int

	FROM	SSop.Enquiries AS e
	OUTER APPLY
			(
				SELECT	MAX (q1.Revision) AS rev
				FROM	SSop.Enquiries AS q1
				WHERE	(q1.OriginalEnquiryId = CASE
												  WHEN e.OriginalEnquiryId = (-1) THEN e.ID
												  ELSE e.OriginalEnquiryId
											  END
						)
			)			AS latest_revision
	WHERE	(e.Guid = @SourceGuid);

	SELECT	@ID = SCOPE_IDENTITY ();

	-- Build the collection of Enquiry Services to duplicate. 
	DECLARE @EnquiryServices SCore.TwoGuidUniqueList;

	INSERT	@EnquiryServices
		 (GuidValue, GuidValueTwo)
	SELECT	es.Guid,
			NEWID ()
	FROM	SSop.EnquiryServices AS es
	JOIN	SSop.Enquiries		 AS e ON (e.ID = es.EnquiryId)
	WHERE	(e.Guid = @SourceGuid);

	-- Create the data objects. 
	DECLARE @NewGuidList SCore.GuidUniqueList;

	INSERT	@NewGuidList
		 (GuidValue)
	SELECT	GuidValueTwo
	FROM	@EnquiryServices;

	EXEC SCore.DataObjectBulkUpsert @GuidList = @NewGuidList,			-- GuidUniqueList
									@SchemeName = N'SSop',				-- nvarchar(255)
									@ObjectName = N'EnquiryServices',	-- nvarchar(255)
									@IsInsert = @IsInsert OUTPUT;		-- bit

	DELETE	FROM @NewGuidList;

	INSERT	SSop.EnquiryServices
		 (RowStatus, Guid, EnquiryId, JobTypeId, StartRibaStageId, EndRibaStageId, QuoteId)
	SELECT	1,
			es.GuidValueTwo,
			@ID,
			es2.JobTypeId,
			es2.StartRibaStageId,
			es2.EndRibaStageId,
			-1
	FROM	@EnquiryServices	 AS es
	JOIN	SSop.EnquiryServices AS es2 ON (es.GuidValue = es2.Guid);

	DECLARE @ServiceQuoteList AS SCore.ThreeGuidUniqueList,
			@CurrentQuote	  UNIQUEIDENTIFIER,
			@NewQuoteGuid	  UNIQUEIDENTIFIER,
			@MaxQuote		  UNIQUEIDENTIFIER;

	INSERT	@ServiceQuoteList
		 (GuidValue, GuidValueTwo, GuidValueThree)
	SELECT	q.Guid,
			NEWID (),
			es2.GuidValueTwo
	FROM	SSop.Quotes			 AS q
	JOIN	SSop.EnquiryServices AS es ON (es.ID	= q.EnquiryServiceID)
	JOIN	@EnquiryServices	 AS es2 ON (es.Guid = es2.GuidValue);


	INSERT	@NewGuidList
		 (GuidValue)
	SELECT	GuidValueTwo
	FROM	@EnquiryServices;

	EXEC SCore.DataObjectBulkUpsert @GuidList = @NewGuidList,			-- GuidUniqueList
									@SchemeName = N'SSop',				-- nvarchar(255)
									@ObjectName = N'EnquiryServices',	-- nvarchar(255)
									@IsInsert = @IsInsert OUTPUT;		-- bit	

	DELETE	FROM @NewGuidList;

	SELECT	@MaxQuote	  = MAX (tgul.GuidValue),
			@CurrentQuote = '00000000-0000-0000-0000-000000000000'
	FROM	@ServiceQuoteList AS tgul;

	WHILE @CurrentQuote < @MaxQuote
	BEGIN
		SELECT		@CurrentQuote = GuidValue,
					@NewQuoteGuid = GuidValueTwo
		FROM		@ServiceQuoteList
		WHERE		(GuidValue > @CurrentQuote)
		ORDER BY	GuidValue;

		EXEC SSop.QuotesRevise @SourceGuid = @CurrentQuote,	-- uniqueidentifier
								  @TargetGuid = @NewQuoteGuid;	-- uniqueidentifier

		UPDATE	q
		SET		q.EnquiryServiceID = es.ID
		FROM	SSop.Quotes			 AS q
		JOIN	@ServiceQuoteList	 AS ql ON (q.Guid  = ql.GuidValueTwo)
		JOIN	SSop.EnquiryServices AS es ON (es.Guid = ql.GuidValueThree);

	END;


	-- Allocate a new Enquiry number. 

	UPDATE	SSop.Enquiries
	SET		RowStatus = 1
	WHERE	(ID = @ID);
END;
GO