SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[JobsUpsert]
  @OrganisationalUnitGuid  UNIQUEIDENTIFIER,
  @JobTypeGuid             UNIQUEIDENTIFIER,
  @UprnGuid                UNIQUEIDENTIFIER,
  @ClientAccountGuid       UNIQUEIDENTIFIER,
  @ClientAddressGuid       UNIQUEIDENTIFIER,
  @ClientContactGuid       UNIQUEIDENTIFIER,
  @AgentAccountGuid        UNIQUEIDENTIFIER,
  @AgentAddressGuid        UNIQUEIDENTIFIER,
  @AgentContactGuid        UNIQUEIDENTIFIER,
  @FinanceAccountGuid      UNIQUEIDENTIFIER,
  @FinanceAddressGuid      UNIQUEIDENTIFIER,
  @FinanceContactGuid      UNIQUEIDENTIFIER,
  @SurveyorGuid            UNIQUEIDENTIFIER,
  @JobDescription          NVARCHAR(1000),
  @IsSubjectToNDA          BIT,
  @JobStarted              DATETIME2,
  @JobCompleted            DATETIME2,
  @JobCancelled            DATETIME2,
  @ValueOfWorkGuid         UNIQUEIDENTIFIER,
  @AgreedFee               DECIMAL(19, 2),
  @RibaStage1Fee           DECIMAL(19, 2),
  @RibaStage2Fee           DECIMAL(19, 2),
  @RibaStage3Fee           DECIMAL(19, 2),
  @RibaStage4Fee           DECIMAL(19, 2),
  @RibaStage5Fee           DECIMAL(19, 2),
  @RibaStage6Fee           DECIMAL(19, 2),
  @RibaStage7Fee           DECIMAL(19, 2),
  @PreConstructionStageFee DECIMAL(19, 2),
  @ConstructionStageFee    DECIMAL(19, 2),
  @ArchiveReferenceLink    NVARCHAR(500),
  @ArchiveBoxReference     NVARCHAR(100),
  @CreatedOn               DATETIME2,
  @ExternalReference       NVARCHAR(50),
  @IsCompleteForReview     BIT,
  @ReviewedByUserGuid      UNIQUEIDENTIFIER,
  @ReviewDateTimeUTC       DATETIME2,
  @AppFormReceived         BIT,
  @FeeCap                  DECIMAL(19, 2),
  @CurrentRibaStageGuid    UNIQUEIDENTIFIER,
  @JobDormant              DATETIME2,
  @PurchaseOrderNumber     NVARCHAR(28),
  @ContractGuid            UNIQUEIDENTIFIER,
  @ProjectGuid             UNIQUEIDENTIFIER,
  @ValueOfWork             DECIMAL(19, 2),
  @ClientAppointmentReceived  BIT,
  @AppointedFromStageGuid	UNIQUEIDENTIFIER,
  @DeadDate					DATE,
  @Guid						UNIQUEIDENTIFIER OUT,
  @BillingInstruction		NVARCHAR(MAX),
  @CannotBeInvoiced			BIT,
  @CannotBeInvoicedReason	NVARCHAR(MAX),
  @AgentContractGuid		UNIQUEIDENTIFIER,
  @CompleteForReviewDate	DATETIME2,
  @SectorGuid				UNIQUEIDENTIFIER,
  @MarketGuid				UNIQUEIDENTIFIER
 
AS
  BEGIN
    DECLARE @OrganisationUnitID INT = -1,
            @JobTypeID          INT = -1,
            @UprnID             INT = -1,
            @ClientAccountID    INT = -1,
            @ClientAddressID    INT = -1,
            @ClientContactID    INT = -1,
            @AgentAccountID     INT = -1,
            @AgentAddressID     INT = -1,
            @AgentContactID     INT = -1,
            @FinanceAccountID   INT = -1,
            @FinanceAddressID   INT = -1,
            @FinanceContactID   INT = -1,
            @SurveyorID         INT = -1,
            @ValueOfWorkID      INT = -1,
            @IsInsert           BIT = 0,
            @JobNumber          INT = 0,
            @JobID              INT,
            @ReviewedByUserID   INT = -1,
            @CurrentRibaStageID INT = -1,
            @VersionId          INT = -1,
            @ContractId         INT = -1,
            @UserID             INT = -1,
			@AppointedFromStageID INT = -1,
            @ProjectId          INT = -1,
			@AgentContractID    INT = -1,
			@CompletedForReviewDateTime DATETIME2 = @CompleteForReviewDate,
			@SectorId			INT = -1,
			@MarketId			INT = -1;

    SELECT
            @UserID = ISNULL(CONVERT(INT,
            SESSION_CONTEXT(N'user_id')
            ),
            -1
            );

    SELECT
            @VersionId = ID
    FROM
            SCore.Versioning
    WHERE
            (IsCurrent = 1);

    SELECT
            @OrganisationUnitID = ID
    FROM
            SCore.OrganisationalUnits
    WHERE
            (Guid = @OrganisationalUnitGuid);

    SELECT
            @JobTypeID = ID
    FROM
            SJob.JobTypes
    WHERE
            (Guid = @JobTypeGuid);

    SELECT
            @ProjectId = ID
    FROM
            SSop.Projects
    WHERE
            (Guid = @ProjectGuid)

    SELECT
            @UprnID = ID
    FROM
            SJob.Assets
    WHERE
            (Guid = @UprnGuid);

    SELECT
            @ClientAccountID = ID
    FROM
            SCrm.Accounts
    WHERE
            (Guid = @ClientAccountGuid);

    SELECT
            @ClientAddressID = ID
    FROM
            SCrm.AccountAddresses
    WHERE
            (Guid = @ClientAddressGuid);

    SELECT
            @ClientContactID = ID
    FROM
            SCrm.AccountContacts
    WHERE
            (Guid = @ClientContactGuid);

    SELECT
            @AgentAccountID = ID
    FROM
            SCrm.Accounts
    WHERE
            (Guid = @AgentAccountGuid);

    SELECT
            @AgentAddressID = ID
    FROM
            SCrm.AccountAddresses
    WHERE
            (Guid = @AgentAddressGuid);

    SELECT
            @AgentContactID = ID
    FROM
            SCrm.AccountContacts
    WHERE
            (Guid = @AgentContactGuid);

    SELECT
            @FinanceAccountID = ID
    FROM
            SCrm.Accounts
    WHERE
            (Guid = @FinanceAccountGuid);

    SELECT
            @FinanceAddressID = ID
    FROM
            SCrm.AccountAddresses
    WHERE
            (Guid = @FinanceAddressGuid);

    SELECT
            @FinanceContactID = ID
    FROM
            SCrm.AccountContacts
    WHERE
            (Guid = @FinanceContactGuid);

    SELECT
            @SurveyorID = ID
    FROM
            SCore.Identities
    WHERE
            (Guid = @SurveyorGuid);

    SELECT
            @ReviewedByUserID = ID
    FROM
            SCore.Identities
    WHERE
            (Guid = @ReviewedByUserGuid);

    SELECT
            @ValueOfWorkID = ID
    FROM
            SJob.ValuesOfWork
    WHERE
            (Guid = @ValueOfWorkGuid);

    SELECT
            @CurrentRibaStageID = ID
    FROM
            SJob.RibaStages
    WHERE
            (Guid = @CurrentRibaStageGuid);

    SELECT
            @ContractId = ID
    FROM
            SSop.Contracts
    WHERE
            (Guid = @ContractGuid);

	SELECT
			@AppointedFromStageID = ID
	FROM	
			SJob.RibaStages AS rs
	WHERE	
			(Guid = @AppointedFromStageGuid)

	SELECT 
			@AgentContractID = ID
	FROM 
			SSop.Contracts
	WHERE
			(Guid = @AgentContractGuid);

	SELECT
			@SectorId = ID
	FROM
			SCore.Sectors
	WHERE
			([Guid] = @SectorGuid)

	SELECT 
			@MarketId = ID
	FROM
			SCore.Markets 
	WHERE
			([Guid] = @MarketGuid)


    IF (@CreatedOn IS NULL)
      BEGIN
        SET @CreatedOn = GETUTCDATE();
      END;

	-- If the @IsCompletedForReview is true, set the datetime it was set.
	-- Also, check if @CompleteForReviewDate to prevent resetting the date on every save.
	IF(@IsCompleteForReview = 1 AND @CompleteForReviewDate IS NULL)
		BEGIN
			SET @CompletedForReviewDateTime = GETUTCDATE();
		END;
	

    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SJob',				-- nvarchar(255)
      @ObjectName = N'Jobs',				-- nvarchar(255)
	  @IncludeDefaultSecurity = 1,
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        /* Create the basic job record */
        INSERT SJob.Jobs
              (
                RowStatus,
                Guid,
                OrganisationalUnitID,
                JobTypeID,
                UprnID,
                ClientAccountID,
                ClientAddressID,
                ClientContactID,
                AgentAccountID,
                AgentAddressID,
                AgentContactID,
                FinanceAccountID,
                FinanceAddressID,
                FinanceContactID,
                SurveyorID,
                JobDescription,
                IsSubjectToNDA,
                JobStarted,
                JobCompleted,
                JobCancelled,
                ValueOfWorkID,
                RibaStage1Fee,
                RibaStage2Fee,
                RibaStage3Fee,
                RibaStage4Fee,
                RibaStage5Fee,
                RibaStage6Fee,
                RibaStage7Fee,
                PreConstructionStageFee,
                ConstructionStageFee,
                AgreedFee,
                ArchiveReferenceLink,
                ArchiveBoxReference,
                CreatedByUserID,
                CreatedOn,
                ExternalReference,
                VersionID,
                IsCompleteForReview,
                ReviewedByUserID,
                ReviewedDateTimeUTC,
                AppFormReceived,
                FeeCap,
                JobDormant,
                CurrentRibaStageId,
                PurchaseOrderNumber,
                ContractID,
                ProjectId,
                ValueOfWork,
                ClientAppointmentReceived,
				AppointedFromStageId,
				DeadDate,
				BillingInstruction,
				CannotBeInvoiced,
				CannotBeInvoicedReason,
				AgentContractID,
				CompletedForReviewDate,
				SectorId,
				MarketId
              )
        VALUES
                (
                  0,						-- RowStatus - tinyint
                  @Guid,					-- Guid - uniqueidentifier
                  @OrganisationUnitID,	-- OrganisationalUnitID - int
                  @JobTypeID,			-- JobTypeID - int
                  @UprnID,				-- UprnID - int
                  @ClientAccountID,		-- ClientAccountID - int
                  @ClientAddressID,
                  @ClientContactID,		-- ClientContactID - int
                  @AgentAccountID,		-- AgentAccountID - int
                  @AgentAddressID,
                  @AgentContactID,		-- AgentContactID - int
                  @FinanceAccountID,		-- AgentAccountID - int
                  @FinanceAddressID,
                  @FinanceContactID,		-- AgentContactID - int
                  @SurveyorID,			-- SurveyorID - int
                  @JobDescription,		-- JobDescription - nvarchar(1000)
                  @IsSubjectToNDA,		-- IsSubjectToNDA - bit
                  @JobStarted,			-- JobStarted - datetime2(7)
                  @JobCompleted,			-- JobCompleted - datetime2(7)
                  @JobCancelled,			-- JobCancelled - datetime2(7)
                  @ValueOfWorkID,		-- ValueOfWorkID - smallint
                  @RibaStage1Fee,
                  @RibaStage2Fee,
                  @RibaStage3Fee,
                  @RibaStage4Fee,
                  @RibaStage5Fee,
                  @RibaStage6Fee,
                  @RibaStage7Fee,
                  @PreConstructionStageFee,
                  @ConstructionStageFee,
                  @AgreedFee,			-- AgreedFee - decimal(19, 2)
                  @ArchiveReferenceLink, -- ArchiveReferenceLink - nvarchar(500)
                  @ArchiveBoxReference,	-- ArchiveBoxReference - nvarchar(100)
                  @UserID,				-- CreatedByUserID - int
                  @CreatedOn,			-- CreatedOn - datetime2(7)
                  @ExternalReference,	-- ExternalReference - nvarchar(50)
                  @VersionId,			-- VersionID - int
                  @IsCompleteForReview,
                  @ReviewedByUserID,
                  @ReviewDateTimeUTC,
                  @AppFormReceived,
                  @FeeCap,
                  @JobDormant,
                  @CurrentRibaStageID,
                  @PurchaseOrderNumber,
                  @ContractId,
                  @ProjectId,
                  @ValueOfWork,
                  @ClientAppointmentReceived,
				  @AppointedFromStageID,
				  @DeadDate,
				  @BillingInstruction,
				  @CannotBeInvoiced,
				  @CannotBeInvoicedReason,
				  @AgentContractID,
				  @CompletedForReviewDateTime,
				  @SectorId,
				  @MarketId
                );

		DECLARE @DataObjectTransitionGuid UNIQUEIDENTIFIER = NEWID();



		/*
			We need to insert "New" to the job upon creation.
		*/

		DECLARE @DynamicNewStatusForJobs UNIQUEIDENTIFIER;

			SELECT	@DynamicNewStatusForJobs = Guid
			FROM	SCore.WorkflowStatus
			WHERE 
					(RowStatus NOT IN (0,254))
				AND (ShowInJobs = 1)
				AND (Name = N'New')
				AND (Description = N'Automatically generated status')
		


		--Insert "New"
		EXEC SCore.DataObjectTransitionUpsert
			@Guid = @DataObjectTransitionGuid,
			@OldStatusGuid = '00000000-0000-0000-0000-000000000000',
			@StatusGuid = @DynamicNewStatusForJobs, --New
			@Comment = N'System Imported.',
			@CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
			@SurveyorUserGuid = @SurveyorGuid,
			@DataObjectGuid = @Guid,
			@IsImported = 0

        SELECT
                @JobID = SCOPE_IDENTITY();
      END;
    ELSE
      BEGIN
        UPDATE  SJob.Jobs
        SET     OrganisationalUnitID = @OrganisationUnitID,
                JobTypeID = @JobTypeID,
                UprnID = @UprnID,
                ClientAccountID = @ClientAccountID,
                ClientAddressID = @ClientAddressID,
                ClientContactID = @ClientContactID,
                AgentAccountID = @AgentAccountID,
                AgentAddressID = @AgentAddressID,
                AgentContactID = @AgentContactID,
                FinanceAccountID = @FinanceAccountID,
                FinanceAddressID = @FinanceAddressID,
                FinanceContactID = @FinanceContactID,
                SurveyorID = @SurveyorID,
                JobDescription = @JobDescription,
                IsSubjectToNDA = @IsSubjectToNDA,
                JobStarted = @JobStarted,
                JobCompleted = @JobCompleted,
                JobCancelled = @JobCancelled,
                ValueOfWorkID = @ValueOfWorkID,
                RibaStage1Fee = @RibaStage1Fee,
                RibaStage2Fee = @RibaStage2Fee,
                RibaStage3Fee = @RibaStage3Fee,
                RibaStage4Fee = @RibaStage4Fee,
                RibaStage5Fee = @RibaStage5Fee,
                RibaStage6Fee = @RibaStage6Fee,
                RibaStage7Fee = @RibaStage7Fee,
                PreConstructionStageFee = @PreConstructionStageFee,
                ConstructionStageFee = @ConstructionStageFee,
                AgreedFee = @AgreedFee,
                ArchiveReferenceLink = @ArchiveReferenceLink,
                ArchiveBoxReference = @ArchiveBoxReference,
                ExternalReference = @ExternalReference,
                IsCompleteForReview = @IsCompleteForReview,
                ReviewedDateTimeUTC = @ReviewDateTimeUTC,
                ReviewedByUserID = @ReviewedByUserID,
                AppFormReceived = @AppFormReceived,
                FeeCap = @FeeCap,
                JobDormant = @JobDormant,
                CurrentRibaStageId = @CurrentRibaStageID,
                PurchaseOrderNumber = @PurchaseOrderNumber,
                ContractID = @ContractId,
                ProjectId = @ProjectId,
                ValueOfWork = @ValueOfWork,
                ClientAppointmentReceived = @ClientAppointmentReceived,
				AppointedFromStageId = @AppointedFromStageID,
				DeadDate = @DeadDate,
				BillingInstruction = @BillingInstruction,
				CannotBeInvoiced = @CannotBeInvoiced,
				CannotBeInvoicedReason = @CannotBeInvoicedReason,
				AgentContractID = @AgentContractID,
				CompletedForReviewDate = @CompletedForReviewDateTime,
				SectorId = @SectorId,
				MarketId = @MarketId
        WHERE
          (Guid = @Guid);

        SELECT
                @JobID = ID
        FROM
                SJob.Jobs
        WHERE
                (Guid = @Guid);
      END;

    /* Create the milestones from the template */
    EXEC SJob.JobMilestonesBuildFromTemplate
      @JobID = @JobID;	-- int

    /* Create the project directory from the template */
    EXEC SJob.JobProjectDirectoryBuildFromTemplate
      @JobID = @JobID; -- int

    /* Set the Job number if this is an insert */
    IF (@IsInsert = 1)
      BEGIN
        SELECT
                @JobNumber = NEXT VALUE FOR SJob.JobNumber;

        UPDATE  SJob.Jobs
        SET     Number = @JobNumber,
                RowStatus = 1
        WHERE
          (ID = @JobID);
      END;


    /* Tempoary addition until have have the System Bus */
    DECLARE @FilingObjectName NVARCHAR(250),
            @FilingLocation   NVARCHAR(MAX);

    SELECT
            @FilingLocation =
            (
                SELECT
                        ss.SiteIdentifier,
                        spf.FolderPath
                FROM
                        SCore.ObjectSharePointFolder AS spf
                JOIN
                        SCore.SharepointSites ss ON (ss.ID = spf.SharepointSiteId)
                WHERE
                        (spf.ObjectGuid = @Guid)
                FOR JSON PATH
            );

    DECLARE @JobNumberString NVARCHAR(100)

    SELECT
            @FilingObjectName = j.Number + N' ' + p.FormattedAddressComma + N' - ' + client.Name + N' / '
            + agent.Name + N' - ' + j.JobDescription,
            @JobNumberString  = j.Number
    FROM
            SJob.Jobs AS j
    JOIN
            SJob.Assets AS p ON (p.ID = j.UprnID)
    JOIN
            SCrm.Accounts AS client ON (client.ID = j.ClientAccountID)
    JOIN
            SCrm.Accounts AS agent ON (agent.ID = j.AgentAccountID)
    WHERE
            (j.Guid = @Guid);

    EXEC SOffice.TargetObjectUpsert
      @EntityTypeGuid = N'63542427-46ab-4078-abd1-1d583c24315c',	-- uniqueidentifier
      @RecordGuid     = @Guid,										-- uniqueidentifier
      @Number         = @JobNumberString,										-- bigint
      @Name           = @FilingObjectName,									-- nvarchar(250)	
      @FilingLocation = @FilingLocation
  END;

GO