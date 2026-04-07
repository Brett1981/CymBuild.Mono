ALTER PROCEDURE [SSop].[EnquiryCreateQuotes]
	(@Guid UNIQUEIDENTIFIER)
AS
BEGIN

	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SSop.Enquiries AS q
		 WHERE	(q.Guid					 = @Guid)
			AND (q.IsReadyForQuoteReview = 0)
	 )
	   )
	BEGIN
		;
		THROW 60000, N'The enquiry must be marked ready for review first.', 1;
	END;

	IF (NOT EXISTS
	 (
		 SELECT 1
		 FROM	SSop.EnquiryServices AS es
		 JOIN	SSop.Enquiries		 AS e ON (e.ID = es.EnquiryId)
		 WHERE	(e.Guid = @Guid)
			AND (NOT EXISTS
			 (
				 SELECT 1
				 FROM	SSop.Quotes AS q
				 WHERE	(q.EnquiryServiceID = es.ID)
					AND (q.RowStatus NOT IN (0, 254))
			 )
				)
	 )
	   )
	BEGIN
		;
		THROW 60000, N'Nothing to create', 1;
	END;

	/* Get the details of the enquiry. */
	DECLARE @PropertyGuid			   UNIQUEIDENTIFIER,
			@PropertyNameNumber		   NVARCHAR(50),
			@PropertyAddressLine1	   NVARCHAR(50),
			@PropertyAddressLine2	   NVARCHAR(50),
			@PropertyAddressLine3	   NVARCHAR(50),
			@PropertyTown			   NVARCHAR(50),
			@PropertyCountyGuid		   UNIQUEIDENTIFIER,
			@PropertyPostCode		   NVARCHAR(50),
			@PropertyCountryGuid	   UNIQUEIDENTIFIER,
			@ClientAccountGuid		   UNIQUEIDENTIFIER,
			@ClientAddressGuid		   UNIQUEIDENTIFIER,
			@ClientContactGuid		   UNIQUEIDENTIFIER,
			@ClientName				   NVARCHAR(250),
			@ClientAddressNameNumber   NVARCHAR(50),
			@ClientAddressLine1		   NVARCHAR(50),
			@ClientAddressLine2		   NVARCHAR(50),
			@ClientAddressLine3		   NVARCHAR(50),
			@ClientAddressTown		   NVARCHAR(50),
			@ClientAddressCountyGuid   UNIQUEIDENTIFIER,
			@ClientAddressPostCode	   NVARCHAR(50),
			@ClientAddressCountryGuid  UNIQUEIDENTIFIER,
			@AgentAccountGuid		   UNIQUEIDENTIFIER,
			@AgentAddressGuid		   UNIQUEIDENTIFIER,
			@AgentContactGuid		   UNIQUEIDENTIFIER,
			@AgentName				   NVARCHAR(250),
			@AgentAddressNameNumber	   NVARCHAR(50),
			@AgentAddressLine1		   NVARCHAR(50),
			@AgentAddressLine2		   NVARCHAR(50),
			@AgentAddressLine3		   NVARCHAR(50),
			@AgentAddressTown		   NVARCHAR(50),
			@AgentAddressCountyGuid	   UNIQUEIDENTIFIER,
			@AgentAddressPostCode	   NVARCHAR(50),
			@AgentAddressCountryGuid   UNIQUEIDENTIFIER,
			@AccountStatusGuid		   UNIQUEIDENTIFIER,
			@QuotingUserGuid		   UNIQUEIDENTIFIER,
			@FinanceAccountGuid		   UNIQUEIDENTIFIER,
			@FinanceAddressGuid		   UNIQUEIDENTIFIER,
			@FinanceContactGuid		   UNIQUEIDENTIFIER,
			@FinanceName			   NVARCHAR(250),
			@FinanceAddressNameNumber  NVARCHAR(50),
			@FinanceAddressLine1	   NVARCHAR(50),
			@FinanceAddressLine2	   NVARCHAR(50),
			@FinanceAddressLine3	   NVARCHAR(50),
			@FinanceAddressTown		   NVARCHAR(50),
			@FinanceAddressCountyGuid  UNIQUEIDENTIFIER,
			@FinanceAddressPostCode	   NVARCHAR(50),
			@FinanceAddressCountryGuid UNIQUEIDENTIFIER,
			@ProjectGuid			   UNIQUEIDENTIFIER,
			@IsClientFinanceAccount	   BIT,
			@JobTypeId                 INT, --[CBLD-590]
			@BillingInstruction		   NVARCHAR(MAX); --It was missing


	SELECT	@PropertyGuid			   = uprn.Guid,
			@PropertyNameNumber		   = e.PropertyNameNumber,
			@PropertyAddressLine1	   = e.PropertyAddressLine1,
			@PropertyAddressLine2	   = e.PropertyAddressLine2,
			@PropertyAddressLine3	   = e.PropertyAddressLine3,
			@PropertyTown			   = e.PropertyTown,
			@PropertyCountyGuid		   = uprnc.Guid,
			@PropertyPostCode		   = e.PropertyPostCode,
			@PropertyCountryGuid	   = uprncr.Guid,
			@ClientAccountGuid		   = c.Guid,
			@ClientAddressGuid		   = c_add.Guid,
			@ClientContactGuid		   = c_con.Guid,
			@ClientName				   = e.ClientName,
			@ClientAddressNameNumber   = e.ClientAddressNameNumber,
			@ClientAddressLine1		   = e.ClientAddressLine1,
			@ClientAddressLine2		   = e.ClientAddressLine2,
			@ClientAddressLine3		   = e.ClientAddressLine3,
			@ClientAddressTown		   = e.ClientAddressTown,
			@ClientAddressCountyGuid   = c_add_c.Guid,
			@ClientAddressPostCode	   = e.ClientAddressPostCode,
			@ClientAddressCountryGuid  = c_add_cr.Guid,
			@AgentAccountGuid		   = a.Guid,
			@AgentAddressGuid		   = a_add.Guid,
			@AgentContactGuid		   = a_con.Guid,
			@AgentName				   = e.AgentName,
			@AgentAddressNameNumber	   = e.AgentAddressNameNumber,
			@AgentAddressLine1		   = e.AgentAddressLine1,
			@AgentAddressLine2		   = e.AgentAddressLine2,
			@AgentAddressLine3		   = e.AgentAddressLine3,
			@AgentAddressTown		   = e.AgentTown,
			@AgentAddressCountyGuid	   = a_add_c.Guid,
			@AgentAddressPostCode	   = e.AgentAddressPostCode,
			@AgentAddressCountryGuid   = a_add_cr.Guid,
			@FinanceAccountGuid		   = f.Guid,
			@FinanceAddressGuid		   = f_add.Guid,
			@FinanceContactGuid		   = f_con.Guid,
			@FinanceName			   = e.FinanceAccountName,
			@FinanceAddressNameNumber  = e.FinanceAddressNameNumber,
			@FinanceAddressLine1	   = e.FinanceAddressLine1,
			@FinanceAddressLine2	   = e.FinanceAddressLine2,
			@FinanceAddressLine3	   = e.FinanceAddressLine3,
			@FinanceAddressTown		   = e.FinanceTown,
			@FinanceAddressCountyGuid  = f_add_c.Guid,
			@FinanceAddressPostCode	   = e.FinancePostCode,
			@FinanceAddressCountryGuid = f_add_cr.Guid,
			@QuotingUserGuid		   = i.Guid,
			@IsClientFinanceAccount	   = e.IsClientFinanceAccount,
			@ProjectGuid			   = p.Guid
	FROM	SSop.Enquiries			  AS e
	JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID			  = e.OrganisationalUnitID)
	JOIN	SCore.Identities		  AS i ON (i.ID				  = e.CreatedByUserId)
	JOIN	SJob.Properties			  AS uprn ON (uprn.ID		  = e.PropertyId)
	JOIN	SCrm.Counties			  AS uprnc ON (uprnc.ID		  = e.PropertyCountyId)
	JOIN	SCrm.Countries			  AS uprncr ON (uprncr.ID	  = e.PropertyCountryId)
	JOIN	SCrm.Accounts			  AS c ON (c.ID				  = e.ClientAccountId)
	JOIN	SCrm.AccountAddresses	  AS c_add ON (c_add.ID		  = e.ClientAddressId)
	JOIN	SCrm.Counties			  AS c_add_c ON (c_add_c.ID	  = e.ClientAddressCountyId)
	JOIN	SCrm.Countries			  AS c_add_cr ON (c_add_cr.ID = e.ClientAddressCountryId)
	JOIN	SCrm.AccountContacts	  AS c_con ON (c_con.ID		  = e.ClientAccountContactId)
	JOIN	SCrm.Accounts			  AS a ON (a.ID				  = e.AgentAccountId)
	JOIN	SCrm.AccountAddresses	  AS a_add ON (a_add.ID		  = e.AgentAddressId)
	JOIN	SCrm.Counties			  AS a_add_c ON (a_add_c.ID	  = e.AgentCountyId)
	JOIN	SCrm.Countries			  AS a_add_cr ON (a_add_cr.ID = e.AgentCountryId)
	JOIN	SCrm.Accounts			  AS f ON (f.ID				  = e.FinanceAccountId)
	JOIN	SCrm.AccountAddresses	  AS f_add ON (f_add.ID		  = e.FinanceAddressId)
	JOIN	SCrm.Counties			  AS f_add_c ON (f_add_c.ID	  = e.FinanceCountyId)
	JOIN	SCrm.Countries			  AS f_add_cr ON (f_add_cr.ID = f_add_c.CountryID)
	JOIN	SCrm.AccountContacts	  AS f_con ON (f_con.ID		  = e.FinanceContactId)
	JOIN	SCrm.AccountContacts	  AS a_con ON (a_con.ID		  = e.AgentAccountContactId)
	JOIN	SSop.Projects			  AS p ON (p.ID				  = e.ProjectId)
	WHERE	(e.Guid = @Guid);

	/* Convert new structure details */
	IF (@PropertyGuid = '00000000-0000-0000-0000-000000000000')
	BEGIN
		SET @PropertyGuid = NEWID ();

		EXEC SJob.PropertiesUpsert @ParentPropertyGuid = '00000000-0000-0000-0000-000000000000',		-- uniqueidentifier
								   @Name = N'',															-- nvarchar(100)
								   @Number = @PropertyNameNumber,										-- nvarchar(50)
								   @AddressLine1 = @PropertyAddressLine1,								-- nvarchar(50)
								   @AddressLine2 = @PropertyAddressLine2,								-- nvarchar(50)
								   @AddressLine3 = @PropertyAddressLine3,								-- nvarchar(50)
								   @Town = @PropertyTown,												-- nvarchar(50)
								   @CountyGuid = @PropertyCountyGuid,									-- nvarchar(50)
								   @Postcode = @PropertyPostCode,										-- nvarchar(50)
								   @CountryGuid = @PropertyCountryGuid,
								   @LocalAuthorityAccountGuid = '00000000-0000-0000-0000-000000000000', -- uniqueidentifier
								   @FireAuthorityAccountGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
								   @WaterAuthorityAccountGuid = '00000000-0000-0000-0000-000000000000', -- uniqueidentifier
								   @Latitude = 0,														-- decimal(9, 6)
								   @Longitude = 0,														-- decimal(9, 6)
								   @IsHighRiskBuilding = 0,
								   @IsComplexBuilding = 0,
								   @BuildingHeightInMetres = 0,
								   @OwnerAccountGuid = '00000000-0000-0000-0000-000000000000',
								   @Guid = @PropertyGuid;												-- uniqueidentifier

	END;

	SELECT	@AccountStatusGuid = s.Guid
	FROM	SCrm.AccountStatus AS s
	WHERE	(s.Name = N'Prospect');

	/* Convert new client details */
	IF (@ClientAccountGuid = '00000000-0000-0000-0000-000000000000')
   AND	(@ClientName <> N'')
	BEGIN
		SET @ClientAccountGuid = NEWID ();

		EXEC SCrm.AccountsUpsert @Name = @ClientName,											-- nvarchar(250)
								 @Code = N'',													-- nvarchar(10)
								 @AccountStatusGuid = @AccountStatusGuid,						-- uniqueidentifier
								 @ParentAccountGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
								 @IsPurchaseLedger = 0,											-- bit
								 @IsSalesLedger = 1,											-- bit
								 @IsLocalAuthority = 0,											-- bit
								 @IsFireAuthority = 0,											-- bit
								 @IsWaterAuthority = 0,											-- bit
								 @RelationshipManagerUserGuid = @QuotingUserGuid,				-- uniqueidentifier
								 @CompanyRegistrationNumber = N'',								-- nvarchar(50)
								 @MainAccountContactGuid = '00000000-0000-0000-0000-000000000000',
								 @MainAccountAddressGuid = '00000000-0000-0000-0000-000000000000',
								 @Guid = @ClientAccountGuid,									-- uniqueidentifier
								 @BillingInstruction = NULL; --Since it is a new Account record, we can set it to null

	END;

	IF (
		   @ClientAddressGuid = '00000000-0000-0000-0000-000000000000'
	   AND	@ClientAddressNameNumber <> N''
	   )
	BEGIN
		SET @ClientAddressGuid = NEWID ();

		EXEC SCrm.AddressUpsert @AddressNumber = 0,							-- int
								@Name = N'',								-- nvarchar(100)
								@Number = @ClientAddressNameNumber,			-- nvarchar(100)
								@AddressLine1 = @ClientAddressLine1,		-- nvarchar(255)
								@AddressLine2 = @ClientAddressLine2,		-- nvarchar(255)
								@AddressLine3 = @ClientAddressLine3,		-- nvarchar(255)
								@Town = @ClientAddressTown,					-- nvarchar(255)
								@CountyGuid = @ClientAddressCountyGuid,		-- uniqueidentifier
								@Postcode = @ClientAddressPostCode,			-- nvarchar(50)
								@CountryGuid = @ClientAddressCountryGuid,	-- uniqueidentifier
								@Guid = @ClientAddressGuid OUTPUT;			-- uniqueidentifier

		DECLARE @AccountAddressGuid UNIQUEIDENTIFIER = NEWID ();

		EXEC SCrm.AccountAddressesUpsert @AccountGuid = @ClientAccountGuid, -- uniqueidentifier
										 @AddressGuid = @ClientAddressGuid, -- uniqueidentifier
										 @Guid = @AccountAddressGuid;		-- uniqueidentifier

		SET @ClientAddressGuid = @AccountAddressGuid;

		IF (EXISTS
		 (
			 SELECT 1
			 FROM	SCrm.Accounts AS a
			 WHERE	(a.MainAccountAddressId < 0)
				AND (a.Guid					= @ClientAccountGuid)
		 )
		   )
		BEGIN
			UPDATE	a
			SET		a.MainAccountAddressId = aa.ID
			FROM	SCrm.Accounts		  AS a
			JOIN	SCrm.AccountAddresses AS aa ON (aa.AccountID = a.ID)
			WHERE	(a.Guid = @ClientAccountGuid);
		END;
	END;

	IF (@IsClientFinanceAccount = 1)
	BEGIN
		SET @FinanceAccountGuid = @ClientAccountGuid;
		SET @FinanceAddressGuid = @ClientAddressGuid;
		SET @FinanceContactGuid = @ClientContactGuid;
	END;

	/* Convert new agent details */
	IF (@AgentAccountGuid = '00000000-0000-0000-0000-000000000000')
   AND	(@AgentName <> N'')
	BEGIN
		SET @AgentAccountGuid = NEWID ();

		EXEC SCrm.AccountsUpsert @Name = @AgentName,											-- nvarchar(250)
								 @Code = N'',													-- nvarchar(10)
								 @AccountStatusGuid = @AccountStatusGuid,						-- uniqueidentifier
								 @ParentAccountGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
								 @IsPurchaseLedger = 0,											-- bit
								 @IsSalesLedger = 1,											-- bit
								 @IsLocalAuthority = 0,											-- bit
								 @IsFireAuthority = 0,											-- bit
								 @IsWaterAuthority = 0,											-- bit
								 @RelationshipManagerUserGuid = @QuotingUserGuid,				-- uniqueidentifier
								 @CompanyRegistrationNumber = N'',								-- nvarchar(50)
								 @MainAccountAddressGuid = '00000000-0000-0000-0000-000000000000',
								 @MainAccountContactGuid = '00000000-0000-0000-0000-000000000000',
								 @Guid = @AgentAccountGuid,										-- uniqueidentifier
								 @BillingInstruction = NULL; --Same as above --> Since it is new, it can be set to null.

	END;

	IF (
		   @AgentAddressGuid = '00000000-0000-0000-0000-000000000000'
	   AND	@AgentAddressNameNumber <> N''
	   )
	BEGIN
		SET @AgentAddressGuid = NEWID ();

		EXEC SCrm.AddressUpsert @AddressNumber = 0,							-- int
								@Name = N'',								-- nvarchar(100)
								@Number = @AgentAddressNameNumber,			-- nvarchar(100)
								@AddressLine1 = @AgentAddressLine1,			-- nvarchar(255)
								@AddressLine2 = @AgentAddressLine2,			-- nvarchar(255)
								@AddressLine3 = @AgentAddressLine3,			-- nvarchar(255)
								@Town = @AgentAddressTown,					-- nvarchar(255)
								@CountyGuid = @AgentAddressCountyGuid,		-- uniqueidentifier
								@Postcode = @AgentAddressPostCode,			-- nvarchar(50)
								@CountryGuid = @AgentAddressCountryGuid,	-- uniqueidentifier
								@Guid = @AgentAddressGuid OUTPUT;			-- uniqueidentifier

		DECLARE @AgentAccountAddressGuid UNIQUEIDENTIFIER = NEWID ();

		EXEC SCrm.AccountAddressesUpsert @AccountGuid = @AgentAccountGuid,	-- uniqueidentifier
										 @AddressGuid = @AgentAddressGuid,	-- uniqueidentifier
										 @Guid = @AgentAccountAddressGuid;	-- uniqueidentifier

		SET @AgentAddressGuid = @AgentAccountAddressGuid;

		IF (EXISTS
		 (
			 SELECT 1
			 FROM	SCrm.Accounts AS a
			 WHERE	(a.MainAccountAddressId < 0)
				AND (a.Guid					= @AgentAccountGuid)
		 )
		   )
		BEGIN
			UPDATE	a
			SET		a.MainAccountAddressId = aa.ID
			FROM	SCrm.Accounts		  AS a
			JOIN	SCrm.AccountAddresses AS aa ON (aa.AccountID = a.ID)
			WHERE	(a.Guid = @AgentAccountGuid);
		END;
	END;

	/* Convert new finance details */
	IF (@FinanceAccountGuid = '00000000-0000-0000-0000-000000000000')
   AND	(@FinanceName <> N'')
   AND	(@IsClientFinanceAccount = 0)
	BEGIN
		SET @FinanceAccountGuid = NEWID ();

		EXEC SCrm.AccountsUpsert @Name = @FinanceName,											-- nvarchar(250)
								 @Code = N'',													-- nvarchar(10)
								 @AccountStatusGuid = @AccountStatusGuid,						-- uniqueidentifier
								 @ParentAccountGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
								 @IsPurchaseLedger = 0,											-- bit
								 @IsSalesLedger = 1,											-- bit
								 @IsLocalAuthority = 0,											-- bit
								 @IsFireAuthority = 0,											-- bit
								 @IsWaterAuthority = 0,											-- bit
								 @RelationshipManagerUserGuid = @QuotingUserGuid,				-- uniqueidentifier
								 @CompanyRegistrationNumber = N'',								-- nvarchar(50)
								 @MainAccountAddressGuid = '00000000-0000-0000-0000-000000000000',
								 @MainAccountContactGuid = '00000000-0000-0000-0000-000000000000',
								 @Guid = @FinanceAccountGuid,									-- uniqueidentifier
								 @BillingInstruction = NULL; --Same as above -> New record can be set to null
	END;

	IF (
		   @FinanceAddressGuid = '00000000-0000-0000-0000-000000000000'
	   AND	@FinanceAddressNameNumber <> N''
	   AND	(@IsClientFinanceAccount = 0)
	   )
	BEGIN
		SET @FinanceAddressGuid = NEWID ();

		EXEC SCrm.AddressUpsert @AddressNumber = 0,							-- int
								@Name = N'',								-- nvarchar(100)
								@Number = @FinanceAddressNameNumber,		-- nvarchar(100)
								@AddressLine1 = @FinanceAddressLine1,		-- nvarchar(255)
								@AddressLine2 = @FinanceAddressLine2,		-- nvarchar(255)
								@AddressLine3 = @FinanceAddressLine3,		-- nvarchar(255)
								@Town = @FinanceAddressTown,				-- nvarchar(255)
								@CountyGuid = @FinanceAddressCountyGuid,	-- uniqueidentifier
								@Postcode = @FinanceAddressPostCode,		-- nvarchar(50)
								@CountryGuid = @FinanceAddressCountryGuid,	-- uniqueidentifier
								@Guid = @FinanceAddressGuid OUTPUT;			-- uniqueidentifier

		DECLARE @FinanceAccountAddressGuid UNIQUEIDENTIFIER = NEWID ();
		
		
		EXEC SCrm.AddressUpsert @AccountGuid = @FinanceAccountGuid, -- uniqueidentifier
								@AddressGuid = @FinanceAddressGuid, -- uniqueidentifier
								@Guid = @FinanceAccountAddressGuid; -- uniqueidentifier

		

		SET @FinanceAddressGuid = @FinanceAccountAddressGuid;

		IF (EXISTS
		 (
			 SELECT 1
			 FROM	SCrm.Accounts AS a
			 WHERE	(a.MainAccountAddressId < 0)
				AND (a.Guid					= @FinanceAccountGuid)
		 )
		   )
		BEGIN
			UPDATE	a
			SET		a.MainAccountAddressId = aa.ID
			FROM	SCrm.Accounts		  AS a
			JOIN	SCrm.AccountAddresses AS aa ON (aa.AccountID = a.ID)
			WHERE	(a.Guid = @FinanceAccountGuid);
		END;
	END;

	/* Build a consolidated list of quotes to create  */
	DECLARE @QuotesToCreate TABLE
		(
			ID INT NOT NULL PRIMARY KEY,
			Guid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID (),
			OrganisationalUnitGuid UNIQUEIDENTIFIER NOT NULL,
			EnquiryGuid UNIQUEIDENTIFIER NOT NULL,
			DescriptionOfWorks NVARCHAR(4000) NOT NULL,
			JobTypeName NVARCHAR(100) NOT NULL,
			JobTypeId	INT NOT NULL, 
			SendInfoToClient BIT NOT NULL,
			SendInfoToAgent BIT NOT NULL,
			ExternalReference NVARCHAR(50) NOT NULL,
			ValueOfWork DECIMAL(19, 2) NOT NULL,
			CurrentStageGuid UNIQUEIDENTIFIER NOT NULL,
			AppointmentStageGuid UNIQUEIDENTIFIER NOT NULL,
			IsSubjectToNDA BIT NOT NULL,
			EnquiryServiceGuid UNIQUEIDENTIFIER NOT NULL
		);

	INSERT	@QuotesToCreate
		 (ID,
		  OrganisationalUnitGuid,
		  EnquiryGuid,
		  DescriptionOfWorks,
		  JobTypeName,
		  JobTypeId,
		  SendInfoToClient,
		  SendInfoToAgent,
		  ExternalReference,
		  ValueOfWork,
		  CurrentStageGuid,
		  AppointmentStageGuid,
		  IsSubjectToNDA,
		  EnquiryServiceGuid)
	SELECT	es.ID,
			ou.Guid,
			@Guid,
			e.DescriptionOfWorks,
			jt.Name,
			jt.ID, 
			e.SendInfoToClient,
			e.SendInfoToAgent,
			e.ExternalReference,
			e.ValueOfWork,
			cs.Guid,
			aps.Guid,
			e.IsSubjectToNDA,
			es.Guid
	FROM	SSop.EnquiryServices	  AS es
	JOIN	SSop.Enquiries			  AS e ON (e.ID		= es.EnquiryId)
	JOIN	SJob.JobTypes			  AS jt ON (jt.ID	= es.JobTypeId)
	JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID	= jt.OrganisationalUnitID)
	JOIN	SJob.RibaStages			  AS cs ON (cs.ID	= e.CurrentProjectRibaStageID)
	JOIN	SJob.RibaStages			  AS aps ON (aps.ID = es.StartRibaStageId)
	WHERE	(e.Guid = @Guid)
		AND (es.RowStatus NOT IN (0, 254))
		AND (NOT EXISTS
		(
			SELECT	1
			FROM	SSop.Quotes AS q
			WHERE	(q.EnquiryServiceID = es.ID)
				AND (q.RowStatus NOT IN (0, 254))
		)
			);

	IF NOT EXISTS
	 (
		 SELECT 1
		 FROM	@QuotesToCreate
	 )
	BEGIN
		;
		THROW 60000, N'There were no quotes to create', 1;
	END;

	/*
		  Loop through the list of Quotes executing QuotesUpsert
	  */
	DECLARE @CreatedDateTime		DATETIME2 = GETUTCDATE (),
			@ExpiryDate				DATETIME2 = DATEADD (	MONTH,
															6,
															GETUTCDATE ()
														),
			@OrganisationalUnitGuid UNIQUEIDENTIFIER,
			@DescriptionOfWorks		NVARCHAR(4000),
			@QuoteGuid				UNIQUEIDENTIFIER,
			@MaxID					INT,
			@CurrentId				INT,
			@ExternalReference		NVARCHAR(50),
			@CurrentStageGuid		UNIQUEIDENTIFIER,
			@AppointmentStageGuid	UNIQUEIDENTIFIER,
			@EnquiryServiceGuid		UNIQUEIDENTIFIER;


	SELECT	@MaxID	   = MAX (ID),
			@CurrentId = 0
	FROM	@QuotesToCreate;

	WHILE (@CurrentId < @MaxID)
	BEGIN
		SELECT		TOP (1) @CurrentId				= q.ID,
							@DescriptionOfWorks		= q.JobTypeName + N' -- ' + q.DescriptionOfWorks,
							@QuoteGuid				= q.Guid,
							@OrganisationalUnitGuid = q.OrganisationalUnitGuid,
							@ExternalReference		= q.ExternalReference,
							@CurrentStageGuid		= q.CurrentStageGuid,
							@AppointmentStageGuid	= q.AppointmentStageGuid,
							@EnquiryServiceGuid		= q.EnquiryServiceGuid,
							@JobTypeId = q.JobTypeId
		FROM		@QuotesToCreate AS q
		WHERE		(q.ID > @CurrentId)
		ORDER BY	q.ID;

		EXEC SSop.QuotesUpsert @OrganisationalUnitGuid = @OrganisationalUnitGuid,		-- uniqueidentifier
							   @QuotingUserGuid = @QuotingUserGuid,						-- uniqueidentifier
							   @ContractGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
							   @Date = @CreatedDateTime,								-- date
							   @Overview = @DescriptionOfWorks,							-- nvarchar(max)
							   @ExpiryDate = @ExpiryDate,								-- date
							   @DateSent = NULL,										-- date
							   @DateAccepted = NULL,									-- date
							   @DateRejected = NULL,									-- date
							   @RejectionReason = N'',									-- nvarchar(max)
							   @FeeCap = 0,												-- decimal(19, 2)
							   @IsFinal = 0,
							   @ExternalReference = @ExternalReference,
							   @QuotingConsultantGuid = @QuotingUserGuid,
							   @AppointmentFromRibaStageGuid = @AppointmentStageGuid,
							   @CurrentStageGuid = @CurrentStageGuid,
							   @DeadDate = NULL,
							   @EnquiryServiceGuid = @EnquiryServiceGuid,
							   @ProjectGuid = @ProjectGuid,
							   @Guid = @QuoteGuid,
							   @JobType = @EnquiryServiceGuid,	
							   @DescriptionOfWorks = @DescriptionOfWorks,
							   @DeclinedToQuoteReason = N'',
							   @ExclusionsAndLimitations = N'';
							  
	END;

	DECLARE @PropertyID		  INT,
			@ClientID		  INT,
			@AgentID		  INT,
			@FinanceID		  INT,
			@ClientAddressID  INT,
			@AgentAddressID	  INT,
			@FinanceAddressID INT;

	SELECT	@PropertyID = p.ID
	FROM	SJob.Properties AS p
	WHERE	(p.Guid = @PropertyGuid);

	SELECT	@ClientID = a.ID
	FROM	SCrm.Accounts AS a
	WHERE	(a.Guid = @ClientAccountGuid);

	SELECT	@ClientAddressID = a.ID
	FROM	SCrm.AccountAddresses AS a
	WHERE	(a.Guid = @ClientAddressGuid);

	SELECT	@AgentID = a.ID
	FROM	SCrm.Accounts AS a
	WHERE	(a.Guid = @AgentAccountGuid);

	SELECT	@AgentAddressID = a.ID
	FROM	SCrm.AccountAddresses AS a
	WHERE	(a.Guid = @AgentAddressGuid);

	SELECT	@FinanceID = a.ID
	FROM	SCrm.Accounts AS a
	WHERE	(a.Guid = @FinanceAccountGuid);

	SELECT	@FinanceAddressID = a.ID
	FROM	SCrm.AccountAddresses AS a
	WHERE	(a.Guid = @FinanceAddressGuid);

	/* Update the Enquiry with the created records */
	UPDATE	SSop.Enquiries
	SET		PropertyId = @PropertyID,
			ClientAccountId = @ClientID,
			AgentAccountId = @AgentID,
			FinanceAccountId = @FinanceID,
			ClientAddressId = @ClientAddressID,
			AgentAddressId = @AgentAddressID,
			FinanceAddressId = @FinanceAddressID,
			EnterNewClientDetails = 0,
			EnterNewAgentDetails = 0,
			EnterNewFinanceDetails = 0,
			EnterNewStructureDetails = 0
	WHERE	(Guid = @Guid);

END;
GO


