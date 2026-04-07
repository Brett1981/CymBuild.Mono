SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO




ALTER PROCEDURE [SSop].[QuoteCreateJobs]
	(@Guid UNIQUEIDENTIFIER)
AS
BEGIN
	SET NOCOUNT ON;


	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SSop.Quotes AS q
		 WHERE	(q.Guid = @Guid)
			AND (q.DateAccepted IS NULL)
	 )
	   )
	BEGIN
		;
		THROW 60000, N'The quote must be accepted first', 1;
	END;


	PRINT N'Passed pre checks';

	/*
		  Build a consolidated list of jobs to create 
	  */
	DECLARE @JobsToCreate TABLE
		(
			ID INT NOT NULL PRIMARY KEY,
			Guid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID (),
			Net DECIMAL(19, 2) NOT NULL,
			RibaStage1Fee DECIMAL(19, 2) NOT NULL,
			RibaStage2Fee DECIMAL(19, 2) NOT NULL,
			RibaStage3Fee DECIMAL(19, 2) NOT NULL,
			RibaStage4Fee DECIMAL(19, 2) NOT NULL,
			RibaStage5Fee DECIMAL(19, 2) NOT NULL,
			RibaStage6Fee DECIMAL(19, 2) NOT NULL,
			RibaStage7Fee DECIMAL(19, 2) NOT NULL,
			PreConstructionStageFee DECIMAL(19, 2) NOT NULL,
			ConstructionStageFee DECIMAL(19, 2) NOT NULL,
			OrganisationalUnitGuid UNIQUEIDENTIFIER NOT NULL,
			JobTypeGuid UNIQUEIDENTIFIER NOT NULL,
			ContractGuid UNIQUEIDENTIFIER NOT NULL,
			IdentityGuid UNIQUEIDENTIFIER NOT NULL,
			QuoteItemId INT NOT NULL,
			ExternalReference NVARCHAR(50) NOT NULL,
			ValueOfWorkGuid UNIQUEIDENTIFIER NOT NULL,
			FeeCap DECIMAL(19, 2) NOT NULL,
			CurrentRibaStageGuid UNIQUEIDENTIFIER NOT NULL,
			TotalFee DECIMAL(19, 2) NOT NULL,
			AppointedFromStageGuid UNIQUEIDENTIFIER NOT NULL,
			CreatedJobID INT NOT NULL DEFAULT ((-1))
		);


	DECLARE @JobPaymentStages TABLE
		(
			Guid UNIQUEIDENTIFIER NOT NULL,
			JobId INT NOT NULL,
			StagedDate DATE NULL,
			AfterStageId INT NOT NULL,
			Value DECIMAL(19, 2) NOT NULL DEFAULT (0)
		);


	INSERT	@JobsToCreate
		 (ID,
		  Net,
		  RibaStage1Fee,
		  RibaStage2Fee,
		  RibaStage3Fee,
		  RibaStage4Fee,
		  RibaStage5Fee,
		  RibaStage6Fee,
		  RibaStage7Fee,
		  PreConstructionStageFee,
		  ConstructionStageFee,
		  OrganisationalUnitGuid,
		  JobTypeGuid,
		  ContractGuid,
		  IdentityGuid,
		  QuoteItemId,
		  ExternalReference,
		  ValueOfWorkGuid,
		  FeeCap,
		  CurrentRibaStageGuid,
		  TotalFee,
		  AppointedFromStageGuid)
	SELECT	js.ID,
			js.Net,
			js.RibaStage1Fee,
			js.RibaStage2Fee,
			js.RibaStage3Fee,
			js.RibaStage4Fee,
			js.RibaStage5Fee,
			js.RibaStage6Fee,
			js.RibaStage7Fee,
			js.PreConstructionStageFee,
			js.ConstructionStageFee,
			js.OrganisationalUnitGuid,
			js.JobTypeGuid,
			js.ContractGuid,
			js.IdentityGuid,
			js.QuoteItemId,
			js.ExternalReference,
			'00000000-0000-0000-0000-000000000000',
			js.FeeCap,
			js.CurrentRibaStageGuid,
			js.RibaStage1Fee + js.RibaStage2Fee + js.RibaStage3Fee + js.RibaStage4Fee + js.RibaStage5Fee
			+ js.RibaStage6Fee + js.RibaStage7Fee + js.PreConstructionStageFee + js.ConstructionStageFee,
			js.AppointedRibaStageGuid
	FROM	SSop.Quote_JobsSummary AS js
	WHERE	(js.QuoteGuid = @Guid)
		AND (js.DateAccepted IS NOT NULL);

	DECLARE @ClientAccountGuid	UNIQUEIDENTIFIER,
			@ClientAddressGuid	UNIQUEIDENTIFIER,
			@ClientContactGuid	UNIQUEIDENTIFIER,
			@AgentAccountGuid	UNIQUEIDENTIFIER,
			@AgentAddressGuid	UNIQUEIDENTIFIER,
			@AgentContactGuid	UNIQUEIDENTIFIER,
			@FinanceAccountGuid UNIQUEIDENTIFIER,
			@FinanceAddressGuid UNIQUEIDENTIFIER,
			@FinanceContactGuid UNIQUEIDENTIFIER,
			@StructureGuid		UNIQUEIDENTIFIER,
			@ProjectGuid		UNIQUEIDENTIFIER,
			@Overview			NVARCHAR(1000),
			@ValueOfWork		DECIMAL(19, 2);

	SELECT	@ClientAccountGuid	= ca.Guid,
			@ClientAddressGuid	= caa.Guid,
			@ClientContactGuid	= cac.Guid,
			@AgentAccountGuid	= aa.Guid,
			@AgentAddressGuid	= aaa.Guid,
			@AgentContactGuid	= aac.Guid,
			@FinanceAccountGuid = fa.Guid,
			@FinanceAddressGuid = faa.Guid,
			@FinanceContactGuid = fac.Guid,
			@StructureGuid		= p.Guid,
			@ProjectGuid		= p2.Guid,
			@Overview			= e.DescriptionOfWorks,
			@ValueOfWork		= e.ValueOfWork
	FROM	SSop.Quotes				AS q
	JOIN	SSop.Quote_ExtendedInfo AS qei ON (qei.Id = q.ID)
	JOIN	SCrm.Accounts			AS ca ON (ca.ID	  = qei.ClientAccountID)
	JOIN	SCrm.AccountAddresses	AS caa ON (caa.ID = qei.ClientAddressId)
	JOIN	SCrm.AccountContacts	AS cac ON (cac.ID = qei.ClientAccountContactId)
	JOIN	SCrm.Accounts			AS aa ON (aa.ID	  = qei.AgentAccountID)
	JOIN	SCrm.AccountAddresses	AS aaa ON (aaa.ID = qei.AgentAddressId)
	JOIN	SCrm.AccountContacts	AS aac ON (aac.ID = qei.AgentAccountContactId)
	JOIN	SCrm.Accounts			AS fa ON (fa.ID	  = qei.FinanceAccountId)
	JOIN	SCrm.AccountAddresses	AS faa ON (faa.ID = qei.FinanceAddressId)
	JOIN	SCrm.AccountContacts	AS fac ON (fac.ID = qei.FinanceContactId)
	JOIN	SJob.Properties			AS p ON (p.ID	  = qei.PropertyId)
	JOIN	SSop.Projects			AS p2 ON (p2.ID	  = q.ProjectId)
	JOIN	SSop.EnquiryServices	AS es ON (es.ID	  = q.EnquiryServiceID)
	JOIN	SSop.Enquiries			AS e ON (e.ID	  = es.EnquiryId)
	WHERE	(q.Guid = @Guid);


	DECLARE @ActiveAccountStatusID INT;

	SELECT	@ActiveAccountStatusID = ast.ID
	FROM	SCrm.AccountStatus AS ast
	WHERE	(ast.Name = N'Active');

	-- Make sure the client is active. 
	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SCrm.Accounts	   AS a
		 WHERE	(a.Guid = @ClientAccountGuid)
			AND (a.AccountStatusID = @ActiveAccountStatusID)
			AND	(a.Guid <> '00000000-0000-0000-0000-000000000000')
	 )
	   )
	BEGIN
		UPDATE	SCrm.Accounts
		SET		AccountStatusID = @ActiveAccountStatusID
		WHERE	(Guid = @ClientAccountGuid);
	END;

	-- Make sure the Agent is active. 
	IF (EXISTS
	 (
		  SELECT 1
		 FROM	SCrm.Accounts	   AS a
		 WHERE	(a.Guid = @AgentAccountGuid)
			AND (a.AccountStatusID = @ActiveAccountStatusID)
			AND	(a.Guid <> '00000000-0000-0000-0000-000000000000')
	 )
	   )
	BEGIN
		UPDATE	SCrm.Accounts
		SET		AccountStatusID = @ActiveAccountStatusID
		WHERE	(Guid = @AgentAccountGuid);
	END;

	-- Make sure the Finance Account is active. 
	IF (EXISTS
	 (
		  SELECT 1
		 FROM	SCrm.Accounts	   AS a
		 WHERE	(a.Guid = @FinanceAccountGuid)
			AND (a.AccountStatusID = @ActiveAccountStatusID)
			AND	(a.Guid <> '00000000-0000-0000-0000-000000000000')
	 )
	   )
	BEGIN
		UPDATE	SCrm.Accounts
		SET		AccountStatusID = @ActiveAccountStatusID
		WHERE	(Guid = @FinanceAccountGuid);
	END;



	IF NOT EXISTS
	 (
		 SELECT 1
		 FROM	@JobsToCreate
	 )
	BEGIN
		;
		THROW 60000, N'There were no jobs to create', 1;
	END;

	/*
		  Loop through the list of jobs executing JobsUpsert
	  */
	DECLARE @CreatedDateTime		 DATETIME2 = GETUTCDATE (),
			@JobGuid				 UNIQUEIDENTIFIER,
			@OrganisationalUnitGuid	 UNIQUEIDENTIFIER,
			@JobTypeGuid			 UNIQUEIDENTIFIER,
			@ContractGuid			 UNIQUEIDENTIFIER,
			@ValueOfWorkGuid		 UNIQUEIDENTIFIER,
			@RibaStage1Fee			 DECIMAL(19, 2),
			@RibaStage2Fee			 DECIMAL(19, 2),
			@RibaStage3Fee			 DECIMAL(19, 2),
			@RibaStage4Fee			 DECIMAL(19, 2),
			@RibaStage5Fee			 DECIMAL(19, 2),
			@RibaStage6Fee			 DECIMAL(19, 2),
			@RibaStage7Fee			 DECIMAL(19, 2),
			@PreConstructionStageFee DECIMAL(19, 2),
			@ConstructionStageFee	 DECIMAL(19, 2),
			@ExternalReference		 NVARCHAR(50),
			@MaxID					 INT,
			@CurrentId				 INT,
			@QuoteItemID			 INT,
			@CreatedJobID			 INT,
			@FeeCap					 DECIMAL(19, 2),
			@CurrentRibaStageGuid	 UNIQUEIDENTIFIER,
			@AppointedRibaStageGuid	 UNIQUEIDENTIFIER;


	SELECT	@MaxID	   = MAX (ID),
			@CurrentId = 0
	FROM	@JobsToCreate;

	PRINT N'Creating job(s)';

	WHILE (@CurrentId < @MaxID)
	BEGIN
		SELECT		TOP (1) @CurrentId				 = j.ID,
							@OrganisationalUnitGuid	 = j.OrganisationalUnitGuid,
							@JobTypeGuid			 = j.JobTypeGuid,
							@ContractGuid			 = j.ContractGuid,
							@ExternalReference		 = j.ExternalReference,
							@QuoteItemID			 = j.QuoteItemId,
							@ValueOfWorkGuid		 = j.ValueOfWorkGuid,
							@RibaStage1Fee			 = j.RibaStage1Fee,
							@RibaStage2Fee			 = j.RibaStage2Fee,
							@RibaStage3Fee			 = j.RibaStage3Fee,
							@RibaStage4Fee			 = j.RibaStage4Fee,
							@RibaStage5Fee			 = j.RibaStage5Fee,
							@RibaStage6Fee			 = j.RibaStage6Fee,
							@RibaStage7Fee			 = j.RibaStage7Fee,
							@PreConstructionStageFee = j.PreConstructionStageFee,
							@ConstructionStageFee	 = j.ConstructionStageFee,
							@FeeCap					 = j.FeeCap,
							@CurrentRibaStageGuid	 = j.CurrentRibaStageGuid,
							@AppointedRibaStageGuid	 = j.AppointedFromStageGuid,
							@JobGuid				 = j.Guid
		FROM		@JobsToCreate AS j
		WHERE		(j.ID > @CurrentId)
		ORDER BY	j.ID;

		EXEC SJob.JobsUpsert @OrganisationalUnitGuid = @OrganisationalUnitGuid,				-- uniqueidentifier
							 @JobTypeGuid = @JobTypeGuid,									-- uniqueidentifier
							 @UprnGuid = @StructureGuid,									-- uniqueidentifier
							 @ClientAccountGuid = @ClientAccountGuid,						-- uniqueidentifier
							 @ClientAddressGuid = @ClientAddressGuid,
							 @ClientContactGuid = @ClientContactGuid,						-- uniqueidentifier
							 @AgentAccountGuid = @AgentAccountGuid,							-- uniqueidentifier
							 @AgentAddressGuid = @AgentAddressGuid,
							 @AgentContactGuid = @AgentContactGuid,							-- uniqueidentifier
							 @SurveyorGuid = '00000000-0000-0000-0000-000000000000',		-- uniqueidentifier
							 @JobDescription = @Overview,									-- nvarchar(1000)
							 @IsSubjectToNDA = 0,								-- bit
							 @JobStarted = @CreatedDateTime,								-- datetime2(7)
							 @JobCompleted = NULL,											-- datetime2(7)
							 @JobCancelled = NULL,											-- datetime2(7)
							 @ValueOfWorkGuid = @ValueOfWorkGuid,							-- uniqueidentifier
							 @RibaStage1Fee = @RibaStage1Fee,
							 @RibaStage2Fee = @RibaStage2Fee,
							 @RibaStage3Fee = @RibaStage3Fee,
							 @RibaStage4Fee = @RibaStage4Fee,
							 @RibaStage5Fee = @RibaStage5Fee,
							 @RibaStage6Fee = @RibaStage6Fee,
							 @RibaStage7Fee = @RibaStage7Fee,
							 @PreConstructionStageFee = @PreConstructionStageFee,
							 @ConstructionStageFee = @ConstructionStageFee,
							 @FeeCap = @FeeCap,
							 @CurrentRibaStageGuid = @CurrentRibaStageGuid,
							 @JobDormant = NULL,
							 @AgreedFee = 0,
							 @AppFormReceived = FALSE,
							 @ArchiveReferenceLink = N'',									-- nvarchar(500)
							 @ArchiveBoxReference = N'',									-- nvarchar(100)
							 @CreatedOn = @CreatedDateTime,									-- datetime2(7)
							 @ExternalReference = @ExternalReference,						-- nvarchar(50)
							 @IsCompleteForReview = 0,										-- bit
							 @ReviewedByUserGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
							 @ReviewDateTimeUTC = NULL,										-- datetime2(7)
							 @FinanceAccountGuid = @FinanceAccountGuid,
							 @FinanceAddressGuid = @FinanceAddressGuid,
							 @FinanceContactGuid = @FinanceContactGuid,
							 @PurchaseOrderNumber = N'',
							 @ContractGuid = @ContractGuid,
							 @ProjectGuid = @ProjectGuid,
							 @ValueOfWork = @ValueOfWork,
							 @ClientAppointmentReceived = 0,
							 @AppointedFromStageGuid = @AppointedRibaStageGuid,
							 @DeadDate = NULL,
							 @Guid = @JobGuid;												-- uniqueidentifier

		SELECT	@CreatedJobID = ID
		FROM	SJob.Jobs
		WHERE	(Guid = @JobGuid);

		UPDATE	@JobsToCreate
		SET		CreatedJobID = @CreatedJobID
		WHERE	(ID = @CurrentId);

		INSERT INTO @JobPaymentStages
			 (Guid, JobId, StagedDate, AfterStageId, Value)
		SELECT	sps.Guid,
				jtc.CreatedJobID,
				sps.StagedDate,
				sps.AfterStageId,
				sps.Value
		FROM	SSop.Quotes_StagedPaymentSummary (@Guid) AS sps
		JOIN	@JobsToCreate							 AS jtc ON (sps.JobId = jtc.ID)
		WHERE	(jtc.ID = @CurrentId);

		PRINT N'Created job';

		IF (@QuoteItemID > 0)
		BEGIN
			UPDATE	SSop.QuoteItems
			SET		CreatedJobId = @CreatedJobID
			WHERE	(ID = @QuoteItemID);
		END;
		ELSE
		BEGIN
			UPDATE	qi
			SET		qi.CreatedJobId = @CreatedJobID
			FROM	SSop.QuoteItems AS qi
			JOIN	SProd.Products	AS p ON (p.ID			   = qi.ProductId)
			JOIN	SJob.JobTypes	AS jt ON (p.CreatedJobType = jt.ID)
			JOIN	SSop.Quotes		AS q ON (q.ID			   = qi.QuoteId)
			WHERE	(jt.Guid				= @JobTypeGuid)
				AND (q.Guid					= @Guid)
				AND (p.NeverConsolidate		= 0)
				AND (qi.DoNotConsolidateJob = 0)
				AND (qi.RowStatus NOT IN (0, 254));
		END;

		EXEC SJob.JobActivitiesBuildFromTemplate @JobID = @CreatedJobID;
	END;

	DECLARE @GuidList SCore.GuidUniqueList,
			@IsInsert BIT;

	PRINT N'Creating staged payments';

	DELETE	FROM @GuidList;

	INSERT INTO @GuidList
		 (GuidValue)
	SELECT	Guid
	FROM	@JobPaymentStages;

	EXEC SCore.DataObjectBulkUpsert @GuidList = @GuidList,
									@SchemeName = N'SJob',
									@ObjectName = N'JobPaymentStages',
									@IsInsert = @IsInsert;


	INSERT INTO SJob.JobPaymentStages
		 (RowStatus, Guid, JobId, StagedDate, AfterStageId, Value)
	SELECT	1,
			jps.Guid,
			jps.JobId,
			jps.StagedDate,
			jps.AfterStageId,
			jps.Value
	FROM	@JobPaymentStages AS jps;


	PRINT N'Staged Payments Created';

END;
GO

