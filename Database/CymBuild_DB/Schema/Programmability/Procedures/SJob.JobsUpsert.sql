SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[JobsUpsert]')
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
  @AppointedFromStageGuid  UNIQUEIDENTIFIER,
  @DeadDate                DATE,
  @Guid                    UNIQUEIDENTIFIER OUT,
  @BillingInstruction      NVARCHAR(MAX),
  @CannotBeInvoiced        BIT,
  @CannotBeInvoicedReason  NVARCHAR(MAX),
  @AgentContractGuid       UNIQUEIDENTIFIER,
  @CompleteForReviewDate   DATETIME2,
  @SectorGuid              UNIQUEIDENTIFIER,
  @MarketGuid              UNIQUEIDENTIFIER,
  @DataClassificationGuid  UNIQUEIDENTIFIER,
  @SecurityClassificationGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OrganisationUnitID INT = -1,
            @JobTypeID INT = -1,
            @UprnID INT = -1,
            @ClientAccountID INT = -1,
            @ClientAddressID INT = -1,
            @ClientContactID INT = -1,
            @AgentAccountID INT = -1,
            @AgentAddressID INT = -1,
            @AgentContactID INT = -1,
            @FinanceAccountID INT = -1,
            @FinanceAddressID INT = -1,
            @FinanceContactID INT = -1,
            @SurveyorID INT = -1,
            @ValueOfWorkID INT = -1,
            @IsInsert BIT = 0,
            @JobNumber INT = 0,
            @JobID INT,
            @ReviewedByUserID INT = -1,
            @CurrentRibaStageID INT = -1,
            @VersionId INT = -1,
            @ContractId INT = -1,
            @UserID INT = -1,
            @AppointedFromStageID INT = -1,
            @ProjectId INT = -1,
            @AgentContractID INT = -1,
            @CompletedForReviewDateTime DATETIME2 = @CompleteForReviewDate,
            @SectorId INT = -1,
            @MarketId INT = -1,
            @DataClassificationId INT = -1,
            @SecurityClassificationId INT = -1;

    SELECT @UserID = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);

    SELECT @VersionId = v.ID FROM SCore.Versioning AS v WHERE v.IsCurrent = 1;
    SELECT @OrganisationUnitID = ou.ID FROM SCore.OrganisationalUnits AS ou WHERE ou.Guid = @OrganisationalUnitGuid;
    SELECT @JobTypeID = jt.ID FROM SJob.JobTypes AS jt WHERE jt.Guid = @JobTypeGuid;
    SELECT @ProjectId = p.ID FROM SSop.Projects AS p WHERE p.Guid = @ProjectGuid;
    SELECT @UprnID = a.ID FROM SJob.Assets AS a WHERE a.Guid = @UprnGuid;
    SELECT @ClientAccountID = a.ID FROM SCrm.Accounts AS a WHERE a.Guid = @ClientAccountGuid;
    SELECT @ClientAddressID = aa.ID FROM SCrm.AccountAddresses AS aa WHERE aa.Guid = @ClientAddressGuid;
    SELECT @ClientContactID = ac.ID FROM SCrm.AccountContacts AS ac WHERE ac.Guid = @ClientContactGuid;
    SELECT @AgentAccountID = a.ID FROM SCrm.Accounts AS a WHERE a.Guid = @AgentAccountGuid;
    SELECT @AgentAddressID = aa.ID FROM SCrm.AccountAddresses AS aa WHERE aa.Guid = @AgentAddressGuid;
    SELECT @AgentContactID = ac.ID FROM SCrm.AccountContacts AS ac WHERE ac.Guid = @AgentContactGuid;
    SELECT @FinanceAccountID = a.ID FROM SCrm.Accounts AS a WHERE a.Guid = @FinanceAccountGuid;
    SELECT @FinanceAddressID = aa.ID FROM SCrm.AccountAddresses AS aa WHERE aa.Guid = @FinanceAddressGuid;
    SELECT @FinanceContactID = ac.ID FROM SCrm.AccountContacts AS ac WHERE ac.Guid = @FinanceContactGuid;
    SELECT @SurveyorID = i.ID FROM SCore.Identities AS i WHERE i.Guid = @SurveyorGuid;
    SELECT @ReviewedByUserID = i.ID FROM SCore.Identities AS i WHERE i.Guid = @ReviewedByUserGuid;
    SELECT @ValueOfWorkID = vow.ID FROM SJob.ValuesOfWork AS vow WHERE vow.Guid = @ValueOfWorkGuid;
    SELECT @CurrentRibaStageID = rs.ID FROM SJob.RibaStages AS rs WHERE rs.Guid = @CurrentRibaStageGuid;
    SELECT @ContractId = c.ID FROM SSop.Contracts AS c WHERE c.Guid = @ContractGuid;
    SELECT @AppointedFromStageID = rs.ID FROM SJob.RibaStages AS rs WHERE rs.Guid = @AppointedFromStageGuid;
    SELECT @AgentContractID = c.ID FROM SSop.Contracts AS c WHERE c.Guid = @AgentContractGuid;
    SELECT @SectorId = s.ID FROM SCore.Sectors AS s WHERE s.Guid = @SectorGuid;
    SELECT @MarketId = m.ID FROM SCore.Markets AS m WHERE m.Guid = @MarketGuid;

    -------------------------------------------------------------------------
    -- CYB-340
    -- Job classification is editable independently.
    -- Project and Quote are not updated from Job.
    -------------------------------------------------------------------------
    SELECT @DataClassificationId = dc.ID
    FROM SCore.DataClassifications AS dc
    WHERE dc.Guid = @DataClassificationGuid
      AND dc.RowStatus NOT IN (0,254);

    SELECT @SecurityClassificationId = sc.ID
    FROM SCore.SecurityClassifications AS sc
    WHERE sc.Guid = @SecurityClassificationGuid
      AND sc.RowStatus NOT IN (0,254);

    SET @DataClassificationId = ISNULL(@DataClassificationId, -1);
    SET @SecurityClassificationId = ISNULL(@SecurityClassificationId, -1);

    IF (@CreatedOn IS NULL)
    BEGIN
        SET @CreatedOn = GETUTCDATE();
    END;

    IF (@IsCompleteForReview = 1 AND @CompleteForReviewDate IS NULL)
    BEGIN
        SET @CompletedForReviewDateTime = GETUTCDATE();
    END;

    EXEC SCore.UpsertDataObject
      @Guid = @Guid,
      @SchemeName = N'SJob',
      @ObjectName = N'Jobs',
      @IncludeDefaultSecurity = 1,
      @IsInsert = @IsInsert OUTPUT;

    IF (@IsInsert = 1)
    BEGIN
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
            MarketId,
            DataClassificationID,
            SecurityClassificationID
        )
        VALUES
        (
            0,
            @Guid,
            @OrganisationUnitID,
            @JobTypeID,
            @UprnID,
            @ClientAccountID,
            @ClientAddressID,
            @ClientContactID,
            @AgentAccountID,
            @AgentAddressID,
            @AgentContactID,
            @FinanceAccountID,
            @FinanceAddressID,
            @FinanceContactID,
            @SurveyorID,
            @JobDescription,
            @IsSubjectToNDA,
            @JobStarted,
            @JobCompleted,
            @JobCancelled,
            @ValueOfWorkID,
            @RibaStage1Fee,
            @RibaStage2Fee,
            @RibaStage3Fee,
            @RibaStage4Fee,
            @RibaStage5Fee,
            @RibaStage6Fee,
            @RibaStage7Fee,
            @PreConstructionStageFee,
            @ConstructionStageFee,
            @AgreedFee,
            @ArchiveReferenceLink,
            @ArchiveBoxReference,
            @UserID,
            @CreatedOn,
            @ExternalReference,
            @VersionId,
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
            @MarketId,
            @DataClassificationId,
            @SecurityClassificationId
        );

        DECLARE @DataObjectTransitionGuid UNIQUEIDENTIFIER = NEWID();
        DECLARE @DynamicNewStatusForJobs UNIQUEIDENTIFIER;

        SELECT @DynamicNewStatusForJobs = ws.Guid
        FROM SCore.WorkflowStatus AS ws
        WHERE ws.RowStatus NOT IN (0,254)
          AND ws.ShowInJobs = 1
          AND ws.Name = N'New'
          AND ws.Description = N'Automatically generated status';

        EXEC SCore.DataObjectTransitionUpsert
            @Guid = @DataObjectTransitionGuid,
            @OldStatusGuid = '00000000-0000-0000-0000-000000000000',
            @StatusGuid = @DynamicNewStatusForJobs,
            @Comment = N'System Imported.',
            @CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
            @SurveyorUserGuid = @SurveyorGuid,
            @DataObjectGuid = @Guid,
            @IsImported = 0;

        SELECT @JobID = CONVERT(INT, SCOPE_IDENTITY());
    END;
    ELSE
    BEGIN
        UPDATE SJob.Jobs
        SET OrganisationalUnitID = @OrganisationUnitID,
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
            MarketId = @MarketId,
            DataClassificationID = @DataClassificationId,
            SecurityClassificationID = @SecurityClassificationId
        WHERE Guid = @Guid;

        SELECT @JobID = j.ID
        FROM SJob.Jobs AS j
        WHERE j.Guid = @Guid;
    END;

    EXEC SJob.JobMilestonesBuildFromTemplate @JobID = @JobID;
    EXEC SJob.JobProjectDirectoryBuildFromTemplate @JobID = @JobID;

    IF (@IsInsert = 1)
    BEGIN
        SELECT @JobNumber = NEXT VALUE FOR SJob.JobNumber;

        UPDATE SJob.Jobs
        SET Number = @JobNumber,
            RowStatus = 1
        WHERE ID = @JobID;
    END;

    DECLARE @FilingObjectName NVARCHAR(250),
            @FilingLocation NVARCHAR(MAX);

    SELECT @FilingLocation =
    (
        SELECT ss.SiteIdentifier,
               spf.FolderPath
        FROM SCore.ObjectSharePointFolder AS spf
        JOIN SCore.SharepointSites AS ss
            ON ss.ID = spf.SharepointSiteId
        WHERE spf.ObjectGuid = @Guid
        FOR JSON PATH
    );

    DECLARE @JobNumberString NVARCHAR(100);

    SELECT @FilingObjectName = j.Number + N' ' + p.FormattedAddressComma + N' - ' + client.Name + N' / '
            + agent.Name + N' - ' + j.JobDescription,
           @JobNumberString = j.Number
    FROM SJob.Jobs AS j
    JOIN SJob.Assets AS p
        ON p.ID = j.UprnID
    JOIN SCrm.Accounts AS client
        ON client.ID = j.ClientAccountID
    JOIN SCrm.Accounts AS agent
        ON agent.ID = j.AgentAccountID
    WHERE j.Guid = @Guid;

    EXEC SOffice.TargetObjectUpsert
      @EntityTypeGuid = N'63542427-46ab-4078-abd1-1d583c24315c',
      @RecordGuid = @Guid,
      @Number = @JobNumberString,
      @Name = @FilingObjectName,
      @FilingLocation = @FilingLocation;
END;
GO