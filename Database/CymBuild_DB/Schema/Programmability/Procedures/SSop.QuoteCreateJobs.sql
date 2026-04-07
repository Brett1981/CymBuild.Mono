SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create procedure [SSop].[QuoteCreateJobs]')
GO

CREATE PROCEDURE [SSop].[QuoteCreateJobs]
(
    @Guid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------------
    -- Preconditions: Quote must be accepted
    -- FIX: WF check must be scoped to THIS quote (dot.DataObjectGuid = @Guid)
    -- FIX: semicolon before THROW
    -------------------------------------------------------------------------
    IF (
            NOT EXISTS
            (
                SELECT 1
                FROM SSop.EnquiryService_ExtendedInfo AS eex
                JOIN SSop.Quotes AS q ON (q.ID = eex.QuoteID)
                WHERE (q.Guid = @Guid)
                  AND (eex.DateAccepted IS NOT NULL)
            )
            AND NOT EXISTS
            (
                SELECT 1
                FROM SCore.DataObjectTransition AS dot
                JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
                WHERE (dot.DataObjectGuid = @Guid)                  -- << FIX
                  AND (dot.RowStatus NOT IN (0,254))
                  AND (wfs.Guid = '21A29AEE-2D99-4DA3-8182-F31813B0C498') -- Accepted
            )
       )
    BEGIN
        ;THROW 60000, N'The quote must be accepted first', 1;
    END;

    PRINT N'Passed pre checks';

    -------------------------------------------------------------------------
    -- Build list of jobs to create
    -------------------------------------------------------------------------
    DECLARE @JobsToCreate TABLE
    (
        ID INT NOT NULL PRIMARY KEY,
        Guid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
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
        CreatedJobID INT NOT NULL DEFAULT (-1),
        AgentContractGuid UNIQUEIDENTIFIER NOT NULL
    );

    DECLARE @JobPaymentStages TABLE
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        JobId INT NOT NULL,
        StagedDate DATE NULL,
        AfterStageId INT NOT NULL,
        Value DECIMAL(19, 2) NOT NULL DEFAULT (0)
    );

    INSERT @JobsToCreate
    (
        ID, Net,
        RibaStage1Fee, RibaStage2Fee, RibaStage3Fee, RibaStage4Fee, RibaStage5Fee, RibaStage6Fee, RibaStage7Fee,
        PreConstructionStageFee, ConstructionStageFee,
        OrganisationalUnitGuid, JobTypeGuid, ContractGuid, IdentityGuid,
        QuoteItemId, ExternalReference,
        ValueOfWorkGuid, FeeCap, CurrentRibaStageGuid, TotalFee, AppointedFromStageGuid, AgentContractGuid
    )
    SELECT
        js.ID,
        js.Net,
        js.RibaStage1Fee, js.RibaStage2Fee, js.RibaStage3Fee, js.RibaStage4Fee, js.RibaStage5Fee, js.RibaStage6Fee, js.RibaStage7Fee,
        js.PreConstructionStageFee, js.ConstructionStageFee,
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
        js.AppointedRibaStageGuid,
        js.AgentContractGuid
    FROM SSop.Quote_JobsSummary AS js
    WHERE (js.QuoteGuid = @Guid)
      AND (
            js.DateAccepted IS NOT NULL
            OR EXISTS
            (
                SELECT 1
                FROM SCore.DataObjectTransition AS dot
                JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
                WHERE dot.DataObjectGuid = @Guid
                  AND dot.RowStatus NOT IN (0,254)
                  AND wfs.Guid = '21A29AEE-2D99-4DA3-8182-F31813B0C498' -- Accepted
            )
            OR EXISTS
            (
                SELECT 1
                FROM SSop.EnquiryService_ExtendedInfo AS eex
                JOIN SSop.Quotes AS q ON (q.ID = eex.QuoteID)
                WHERE (q.Guid = @Guid)
                  AND (eex.DateAccepted IS NOT NULL)
            )
          );

    -------------------------------------------------------------------------
    -- Load quote context required for job upserts
    -------------------------------------------------------------------------
    DECLARE
        @ClientAccountGuid    UNIQUEIDENTIFIER,
        @ClientAddressGuid    UNIQUEIDENTIFIER,
        @ClientContactGuid    UNIQUEIDENTIFIER,
        @AgentAccountGuid     UNIQUEIDENTIFIER,
        @AgentAddressGuid     UNIQUEIDENTIFIER,
        @AgentContactGuid     UNIQUEIDENTIFIER,
        @FinanceAccountGuid   UNIQUEIDENTIFIER,
        @FinanceAddressGuid   UNIQUEIDENTIFIER,
        @FinanceContactGuid   UNIQUEIDENTIFIER,
        @StructureGuid        UNIQUEIDENTIFIER,
        @ProjectGuid          UNIQUEIDENTIFIER,
        @Overview             NVARCHAR(1000),
        @ValueOfWork          DECIMAL(19, 2),
        @IsNDA                BIT,
		@SectorId			  INT,
		@MarketId			  INT;

    SELECT
        @ClientAccountGuid  = ca.Guid,
        @ClientAddressGuid  = caa.Guid,
        @ClientContactGuid  = cac.Guid,
        @AgentAccountGuid   = aa.Guid,
        @AgentAddressGuid   = aaa.Guid,
        @AgentContactGuid   = aac.Guid,
        @FinanceAccountGuid = fa.Guid,
        @FinanceAddressGuid = faa.Guid,
        @FinanceContactGuid = fac.Guid,
        @StructureGuid      = p.Guid,
        @ProjectGuid        = p2.Guid,
        @Overview           = CASE WHEN q.DescriptionOfWorks = '' THEN e.DescriptionOfWorks ELSE q.DescriptionOfWorks END,
        @ValueOfWork        = e.ValueOfWork,
        @IsNDA              = e.IsSubjectToNDA,
		@SectorId			= q.SectorId,
		@MarketId           = q.MarketId
    FROM SSop.Quotes AS q
    JOIN SSop.Quote_ExtendedInfo AS qei ON (qei.Id = q.ID)
    JOIN SCrm.Accounts AS ca ON (ca.ID = qei.ClientAccountID)
    JOIN SCrm.AccountAddresses AS caa ON (caa.ID = qei.ClientAddressId)
    JOIN SCrm.AccountContacts AS cac ON (cac.ID = qei.ClientAccountContactId)
    JOIN SCrm.Accounts AS aa ON (aa.ID = qei.AgentAccountID)
    JOIN SCrm.AccountAddresses AS aaa ON (aaa.ID = qei.AgentAddressId)
    JOIN SCrm.AccountContacts AS aac ON (aac.ID = qei.AgentAccountContactId)
    JOIN SCrm.Accounts AS fa ON (fa.ID = qei.FinanceAccountId)
    JOIN SCrm.AccountAddresses AS faa ON (faa.ID = qei.FinanceAddressId)
    JOIN SCrm.AccountContacts AS fac ON (fac.ID = qei.FinanceContactId)
    JOIN SJob.Assets AS p ON (p.ID = qei.PropertyId)
    JOIN SSop.Projects AS p2 ON (p2.ID = q.ProjectId)
    JOIN SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
    JOIN SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
    WHERE (q.Guid = @Guid);

    IF NOT EXISTS (SELECT 1 FROM @JobsToCreate)
    BEGIN
        ;THROW 60000, N'There were no jobs to create', 1;
    END;

    -------------------------------------------------------------------------
    -- Create jobs
    -------------------------------------------------------------------------
    DECLARE
        @CreatedDateTime         DATETIME2 = GETUTCDATE(),
        @JobGuid                 UNIQUEIDENTIFIER,
        @OrganisationalUnitGuid  UNIQUEIDENTIFIER,
        @JobTypeGuid             UNIQUEIDENTIFIER,
        @ContractGuid            UNIQUEIDENTIFIER,
        @ValueOfWorkGuid         UNIQUEIDENTIFIER,
        @RibaStage1Fee           DECIMAL(19, 2),
        @RibaStage2Fee           DECIMAL(19, 2),
        @RibaStage3Fee           DECIMAL(19, 2),
        @RibaStage4Fee           DECIMAL(19, 2),
        @RibaStage5Fee           DECIMAL(19, 2),
        @RibaStage6Fee           DECIMAL(19, 2),
        @RibaStage7Fee           DECIMAL(19, 2),
        @PreConstructionStageFee DECIMAL(19, 2),
        @ConstructionStageFee    DECIMAL(19, 2),
        @ExternalReference       NVARCHAR(50),
        @MaxID                   INT,
        @CurrentId               INT,
        @QuoteItemID             INT,
        @CreatedJobID            INT,
        @FeeCap                  DECIMAL(19, 2),
        @CurrentRibaStageGuid    UNIQUEIDENTIFIER,
        @AppointedRibaStageGuid  UNIQUEIDENTIFIER,
        @AgentContractGuid       UNIQUEIDENTIFIER,
        @CompleteForReviewDate   DATETIME2,
		@SectorGuid				 UNIQUEIDENTIFIER,
		@MarketGuid				 UNIQUEIDENTIFIER

    SELECT
        @MaxID = MAX(ID),
        @CurrentId = 0
    FROM @JobsToCreate;

	SELECT @SectorGuid = Guid
	FROM SCore.Sectors
	WHERE (ID = @SectorId)

	SELECT @MarketGuid = Guid
	FROM SCore.Markets
	WHERE (ID = @MarketId)

    PRINT N'Creating job(s)';

    WHILE (@CurrentId < @MaxID)
    BEGIN
        SELECT TOP (1)
            @CurrentId               = j.ID,
            @OrganisationalUnitGuid  = j.OrganisationalUnitGuid,
            @JobTypeGuid             = j.JobTypeGuid,
            @ContractGuid            = j.ContractGuid,
            @ExternalReference       = j.ExternalReference,
            @QuoteItemID             = j.QuoteItemId,
            @ValueOfWorkGuid         = j.ValueOfWorkGuid,
            @RibaStage1Fee           = j.RibaStage1Fee,
            @RibaStage2Fee           = j.RibaStage2Fee,
            @RibaStage3Fee           = j.RibaStage3Fee,
            @RibaStage4Fee           = j.RibaStage4Fee,
            @RibaStage5Fee           = j.RibaStage5Fee,
            @RibaStage6Fee           = j.RibaStage6Fee,
            @RibaStage7Fee           = j.RibaStage7Fee,
            @PreConstructionStageFee = j.PreConstructionStageFee,
            @ConstructionStageFee    = j.ConstructionStageFee,
            @FeeCap                  = j.FeeCap,
            @CurrentRibaStageGuid    = j.CurrentRibaStageGuid,
            @AppointedRibaStageGuid  = j.AppointedFromStageGuid,
            @JobGuid                 = j.Guid,
            @AgentContractGuid       = j.AgentContractGuid,   -- << FIX
            @CompleteForReviewDate   = NULL
        FROM @JobsToCreate AS j
        WHERE (j.ID > @CurrentId)
        ORDER BY j.ID;


        -- Ensure Jobs security enforcement can derive OrgUnit from the SOURCE Quote
        EXEC sys.sp_set_session_context
            @key = N'new_entity_type_guid',
            @value = '63542427-46AB-4078-ABD1-1D583C24315C', -- Jobs EntityTypeGuid
            @read_only = 0;

        EXEC sys.sp_set_session_context
            @key = N'record_guid',
            @value = @Guid, -- QuoteGuid (source record)
            @read_only = 0;
        -- IMPORTANT: create Job as "New"
        -- Do NOT set JobStarted datetime during creation.
        EXEC SJob.JobsUpsert
             @OrganisationalUnitGuid      = @OrganisationalUnitGuid,
             @JobTypeGuid                 = @JobTypeGuid,
             @UprnGuid                    = @StructureGuid,
             @ClientAccountGuid           = @ClientAccountGuid,
             @ClientAddressGuid           = @ClientAddressGuid,
             @ClientContactGuid           = @ClientContactGuid,
             @AgentAccountGuid            = @AgentAccountGuid,
             @AgentAddressGuid            = @AgentAddressGuid,
             @AgentContactGuid            = @AgentContactGuid,
             @SurveyorGuid                = '00000000-0000-0000-0000-000000000000',
             @JobDescription              = @Overview,
             @IsSubjectToNDA              = @IsNDA,
             @JobStarted                  = NULL,              -- << FIX (was setting datetime)
             @JobCompleted                = NULL,
             @JobCancelled                = NULL,
             @ValueOfWorkGuid             = @ValueOfWorkGuid,
             @RibaStage1Fee               = @RibaStage1Fee,
             @RibaStage2Fee               = @RibaStage2Fee,
             @RibaStage3Fee               = @RibaStage3Fee,
             @RibaStage4Fee               = @RibaStage4Fee,
             @RibaStage5Fee               = @RibaStage5Fee,
             @RibaStage6Fee               = @RibaStage6Fee,
             @RibaStage7Fee               = @RibaStage7Fee,
             @PreConstructionStageFee     = @PreConstructionStageFee,
             @ConstructionStageFee        = @ConstructionStageFee,
             @FeeCap                      = @FeeCap,
             @CurrentRibaStageGuid        = @CurrentRibaStageGuid,
             @JobDormant                  = NULL,
             @AgreedFee                   = 0,
             @AppFormReceived             = FALSE,
             @ArchiveReferenceLink        = N'',
             @ArchiveBoxReference         = N'',
             @CreatedOn                   = @CreatedDateTime,
             @ExternalReference           = @ExternalReference,
             @IsCompleteForReview         = 0,
             @ReviewedByUserGuid          = '00000000-0000-0000-0000-000000000000',
             @ReviewDateTimeUTC           = NULL,
             @FinanceAccountGuid          = @FinanceAccountGuid,
             @FinanceAddressGuid          = @FinanceAddressGuid,
             @FinanceContactGuid          = @FinanceContactGuid,
             @PurchaseOrderNumber         = N'',
             @ContractGuid                = @ContractGuid,
             @ProjectGuid                 = @ProjectGuid,
             @ValueOfWork                 = @ValueOfWork,
             @ClientAppointmentReceived   = 0,
             @AppointedFromStageGuid      = @AppointedRibaStageGuid,
             @DeadDate                    = NULL,
             @Guid                        = @JobGuid,
             @BillingInstruction          = NULL,
             @CannotBeInvoiced            = 0,
             @CannotBeInvoicedReason      = N'',
             @AgentContractGuid           = @AgentContractGuid,
             @CompleteForReviewDate       = @CompleteForReviewDate,
			 @SectorGuid				  = @SectorGuid,
			 @MarketGuid				  = @MarketGuid

        EXEC sys.sp_set_session_context @key = N'new_entity_type_guid', @value = NULL, @read_only = 0;
        EXEC sys.sp_set_session_context @key = N'record_guid',         @value = NULL, @read_only = 0;

        SELECT @CreatedJobID = ID
        FROM SJob.Jobs
        WHERE (Guid = @JobGuid);

        UPDATE @JobsToCreate
        SET CreatedJobID = @CreatedJobID
        WHERE (ID = @CurrentId);

        INSERT INTO @JobPaymentStages (Guid, JobId, StagedDate, AfterStageId, Value)
        SELECT
            sps.Guid,
            jtc.CreatedJobID,
            sps.StagedDate,
            sps.AfterStageId,
            sps.Value
        FROM SSop.Quotes_StagedPaymentSummary(@Guid) AS sps
        JOIN @JobsToCreate AS jtc ON (sps.JobId = jtc.ID)
        WHERE (jtc.ID = @CurrentId);

        PRINT N'Created job';

        IF (@QuoteItemID > 0)
        BEGIN
            UPDATE SSop.QuoteItems
            SET CreatedJobId = @CreatedJobID
            WHERE (ID = @QuoteItemID);
        END
        ELSE
        BEGIN
            UPDATE qi
            SET qi.CreatedJobId = @CreatedJobID
            FROM SSop.QuoteItems AS qi
            JOIN SProd.Products AS p ON (p.ID = qi.ProductId)
            JOIN SJob.JobTypes AS jt ON (p.CreatedJobType = jt.ID)
            JOIN SSop.Quotes AS q ON (q.ID = qi.QuoteId)
            WHERE (jt.Guid = @JobTypeGuid)
              AND (q.Guid = @Guid)
              AND (p.NeverConsolidate = 0)
              AND (qi.DoNotConsolidateJob = 0)
              AND (qi.RowStatus NOT IN (0, 254));
        END;

        EXEC SJob.JobActivitiesBuildFromTemplate @JobID = @CreatedJobID;
    END;

    -------------------------------------------------------------------------
    -- Bulk upsert JobPaymentStages (preserved)
    -------------------------------------------------------------------------
    DECLARE @GuidList SCore.GuidUniqueList,
            @IsInsert BIT;

    PRINT N'Creating staged payments';

    DELETE FROM @GuidList;

    INSERT INTO @GuidList (GuidValue)
    SELECT Guid
    FROM @JobPaymentStages;

    EXEC SCore.DataObjectBulkUpsert
         @GuidList   = @GuidList,
         @SchemeName = N'SJob',
         @ObjectName = N'JobPaymentStages',
         @IsInsert   = @IsInsert;

    INSERT INTO SJob.JobPaymentStages (RowStatus, Guid, JobId, StagedDate, AfterStageId, Value)
    SELECT
        1,
        jps.Guid,
        jps.JobId,
        jps.StagedDate,
        jps.AfterStageId,
        jps.Value
    FROM @JobPaymentStages AS jps;

    PRINT N'Staged Payments Created';

    -------------------------------------------------------------------------
    -- NEW: Move Quote WF to "Complete" after successful job creation
    -- IMPORTANT: follow your rule: UpsertDataObject first, then TransitionUpsert
    -------------------------------------------------------------------------
    DECLARE @CompleteQuoteStatusGuid UNIQUEIDENTIFIER = NULL;

    SELECT TOP (1) @CompleteQuoteStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Complete'
    ORDER BY ws.ID;

    IF (@CompleteQuoteStatusGuid IS NOT NULL)
    BEGIN
        DECLARE @LatestQuoteStatusGuid UNIQUEIDENTIFIER = NULL;

        SELECT TOP (1) @LatestQuoteStatusGuid = wfs.Guid
        FROM SCore.DataObjectTransition dot
        JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
        WHERE dot.DataObjectGuid = @Guid
          AND dot.RowStatus NOT IN (0,254)
          AND wfs.RowStatus NOT IN (0,254)
        ORDER BY dot.DateTimeUTC DESC, dot.ID DESC;

        IF (@LatestQuoteStatusGuid IS NULL OR @LatestQuoteStatusGuid <> @CompleteQuoteStatusGuid)
        BEGIN
            DECLARE @QuoteCompleteTransitionGuid UNIQUEIDENTIFIER = NEWID();
            DECLARE @TransitionIsInsert BIT = 0;

            -- Ensure DataObject exists FIRST (your rule)
            EXEC SCore.UpsertDataObject
                @Guid       = @QuoteCompleteTransitionGuid,
                @SchemeName = N'SCore',
                @ObjectName = N'DataObjectTransition',
                @IsInsert   = @TransitionIsInsert OUTPUT;

            -- Now write the transition
            EXEC SCore.DataObjectTransitionUpsert
                @Guid             = @QuoteCompleteTransitionGuid,
                @OldStatusGuid     = '00000000-0000-0000-0000-000000000000',
                @StatusGuid        = @CompleteQuoteStatusGuid,
                @Comment           = N'System Imported (Job creation).',
                @CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
                @SurveyorUserGuid  = '00000000-0000-0000-0000-000000000000',
                @DataObjectGuid    = @Guid,
                @IsImported        = 1;

            PRINT N'Quote moved to Complete';
        END
    END
    ELSE
    BEGIN
        PRINT N'WARNING: Could not resolve Quote "Complete" workflow status (ShowInQuotes=1, Name=Complete).';
    END
END;
GO