SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[QuoteCreateJobs]')
GO
PRINT (N'Create procedure [SSop].[QuoteCreateJobs]')
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
    -------------------------------------------------------------------------
    IF (
            NOT EXISTS
            (
                SELECT 1
                FROM SSop.EnquiryService_ExtendedInfo AS eex
                JOIN SSop.Quotes AS q ON q.ID = eex.QuoteID
                WHERE q.Guid = @Guid
                  AND eex.DateAccepted IS NOT NULL
            )
            AND NOT EXISTS
            (
                SELECT 1
                FROM SCore.DataObjectTransition AS dot
                JOIN SCore.WorkflowStatus AS wfs ON wfs.ID = dot.StatusID
                WHERE dot.DataObjectGuid = @Guid
                  AND dot.RowStatus NOT IN (0,254)
                  AND wfs.Guid = '21A29AEE-2D99-4DA3-8182-F31813B0C498' -- Customer Accepted
            )
       )
    BEGIN
        ;THROW 60000, N'The quote must be accepted first', 1;
    END;

    PRINT N'Passed pre checks';

    -------------------------------------------------------------------------
    -- NEW: Collect ONLY quote items that have NOT yet created a job
    -- This is the key idempotency / re-run protection
    -------------------------------------------------------------------------
    DECLARE @EligibleQuoteItems TABLE
    (
        QuoteItemID            INT NOT NULL PRIMARY KEY,
        QuoteID                INT NOT NULL,
        ProductID              INT NOT NULL,
        CreatedJobTypeID       INT NOT NULL,
        DoNotConsolidateJob    BIT NOT NULL,
        NeverConsolidate       BIT NOT NULL,
        ExistingCreatedJobID   INT NOT NULL
    );

    INSERT INTO @EligibleQuoteItems
    (
        QuoteItemID,
        QuoteID,
        ProductID,
        CreatedJobTypeID,
        DoNotConsolidateJob,
        NeverConsolidate,
        ExistingCreatedJobID
    )
    SELECT
        qi.ID,
        qi.QuoteId,
        qi.ProductId,
        p.CreatedJobType,
        ISNULL(qi.DoNotConsolidateJob, 0),
        ISNULL(p.NeverConsolidate, 0),
        ISNULL(qi.CreatedJobId, -1)
    FROM SSop.QuoteItems AS qi
    JOIN SSop.Quotes     AS q ON q.ID = qi.QuoteId
    JOIN SProd.Products  AS p ON p.ID = qi.ProductId
    WHERE q.Guid = @Guid
      AND qi.RowStatus NOT IN (0,254)
      AND q.RowStatus NOT IN (0,254)
      AND ISNULL(qi.CreatedJobId, -1) <= 0;   -- ONLY items not already linked to a job

    IF NOT EXISTS (SELECT 1 FROM @EligibleQuoteItems)
    BEGIN
        ;THROW 60000, N'There are no new quote items to create jobs for.', 1;
    END;

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

    -------------------------------------------------------------------------
    -- IMPORTANT:
    -- Only create rows from Quote_JobsSummary where there is NEW eligible work.
    --
    -- If js.QuoteItemId > 0  -> only include if that exact quote item is uncreated
    -- If js.QuoteItemId <= 0 -> only include if at least one consolidatable eligible
    --                           quote item exists for the same quote / job type
    -------------------------------------------------------------------------
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
        js.AppointedRibaStageGuid,
        js.AgentContractGuid
    FROM SSop.Quote_JobsSummary AS js
    WHERE js.QuoteGuid = @Guid
      AND (
            js.DateAccepted IS NOT NULL
            OR EXISTS
            (
                SELECT 1
                FROM SCore.DataObjectTransition AS dot
                JOIN SCore.WorkflowStatus AS wfs ON wfs.ID = dot.StatusID
                WHERE dot.DataObjectGuid = @Guid
                  AND dot.RowStatus NOT IN (0,254)
                  AND wfs.Guid = '21A29AEE-2D99-4DA3-8182-F31813B0C498'
            )
            OR EXISTS
            (
                SELECT 1
                FROM SSop.EnquiryService_ExtendedInfo AS eex
                JOIN SSop.Quotes AS q ON q.ID = eex.QuoteID
                WHERE q.Guid = @Guid
                  AND eex.DateAccepted IS NOT NULL
            )
          )
      AND
      (
            (
                js.QuoteItemId > 0
                AND EXISTS
                (
                    SELECT 1
                    FROM @EligibleQuoteItems eqi
                    WHERE eqi.QuoteItemID = js.QuoteItemId
                )
            )
            OR
            (
                js.QuoteItemId <= 0
                AND EXISTS
                (
                    SELECT 1
                    FROM @EligibleQuoteItems eqi
                    JOIN SJob.JobTypes jt ON jt.ID = eqi.CreatedJobTypeID
                    WHERE eqi.DoNotConsolidateJob = 0
                      AND eqi.NeverConsolidate = 0
                      AND jt.Guid = js.JobTypeGuid
                )
            )
      );

    IF NOT EXISTS (SELECT 1 FROM @JobsToCreate)
    BEGIN
        ;THROW 60000, N'There were no new jobs to create.', 1;
    END;

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
        @SectorId             INT,
        @MarketId             INT,
        @DataClassificationId INT,
        @SecurityClassificationId INT;

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
        @SectorId           = q.SectorId,
        @MarketId           = q.MarketId,
        @DataClassificationId = q.DataClassificationID,
        @SecurityClassificationId = q.SecurityClassificationID
    FROM SSop.Quotes AS q
    JOIN SSop.Quote_ExtendedInfo AS qei ON qei.Id = q.ID
    JOIN SCrm.Accounts AS ca ON ca.ID = qei.ClientAccountID
    JOIN SCrm.AccountAddresses AS caa ON caa.ID = qei.ClientAddressId
    JOIN SCrm.AccountContacts AS cac ON cac.ID = qei.ClientAccountContactId
    JOIN SCrm.Accounts AS aa ON aa.ID = qei.AgentAccountID
    JOIN SCrm.AccountAddresses AS aaa ON aaa.ID = qei.AgentAddressId
    JOIN SCrm.AccountContacts AS aac ON aac.ID = qei.AgentAccountContactId
    JOIN SCrm.Accounts AS fa ON fa.ID = qei.FinanceAccountId
    JOIN SCrm.AccountAddresses AS faa ON faa.ID = qei.FinanceAddressId
    JOIN SCrm.AccountContacts AS fac ON fac.ID = qei.FinanceContactId
    JOIN SJob.Assets AS p ON p.ID = qei.PropertyId
    JOIN SSop.Projects AS p2 ON p2.ID = q.ProjectId
    JOIN SSop.EnquiryServices AS es ON es.ID = q.EnquiryServiceID
    JOIN SSop.Enquiries AS e ON e.ID = es.EnquiryId
    WHERE q.Guid = @Guid;

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
        @SectorGuid              UNIQUEIDENTIFIER,
        @MarketGuid              UNIQUEIDENTIFIER,
        @DataClassificationGuid  UNIQUEIDENTIFIER,
        @SecurityClassificationGuid UNIQUEIDENTIFIER;

    SELECT
        @MaxID = MAX(ID),
        @CurrentId = 0
    FROM @JobsToCreate;

    SELECT @SectorGuid = Guid
    FROM SCore.Sectors
    WHERE ID = @SectorId;

    SELECT @MarketGuid = Guid
    FROM SCore.Markets
    WHERE ID = @MarketId;

    SELECT @DataClassificationGuid = dc.Guid
    FROM SCore.DataClassifications AS dc
    WHERE dc.ID = ISNULL(@DataClassificationId, -1)
      AND dc.RowStatus NOT IN (0,254);

    SELECT @SecurityClassificationGuid = sc.Guid
    FROM SCore.SecurityClassifications AS sc
    WHERE sc.ID = ISNULL(@SecurityClassificationId, -1)
      AND sc.RowStatus NOT IN (0,254);

    SET @DataClassificationGuid = ISNULL(@DataClassificationGuid, '31E24091-52B4-480E-9A85-7052F614567A');
    SET @SecurityClassificationGuid = ISNULL(@SecurityClassificationGuid, 'B4EF7A4D-454B-4C4B-AF3D-5996312FD038');

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
            @AgentContractGuid       = j.AgentContractGuid,
            @CompleteForReviewDate   = NULL
        FROM @JobsToCreate AS j
        WHERE j.ID > @CurrentId
        ORDER BY j.ID;

        EXEC sys.sp_set_session_context
            @key = N'new_entity_type_guid',
            @value = '63542427-46AB-4078-ABD1-1D583C24315C',
            @read_only = 0;

        EXEC sys.sp_set_session_context
            @key = N'record_guid',
            @value = @Guid,
            @read_only = 0;

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
             @JobStarted                  = NULL,
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
             @SectorGuid                  = @SectorGuid,
             @MarketGuid                  = @MarketGuid,
             @DataClassificationGuid      = @DataClassificationGuid,
             @SecurityClassificationGuid  = @SecurityClassificationGuid;

        EXEC sys.sp_set_session_context @key = N'new_entity_type_guid', @value = NULL, @read_only = 0;
        EXEC sys.sp_set_session_context @key = N'record_guid',         @value = NULL, @read_only = 0;

        SELECT @CreatedJobID = ID
        FROM SJob.Jobs
        WHERE Guid = @JobGuid;

        UPDATE @JobsToCreate
        SET CreatedJobID = @CreatedJobID
        WHERE ID = @CurrentId;

        INSERT INTO @JobPaymentStages (Guid, JobId, StagedDate, AfterStageId, Value)
        SELECT
            sps.Guid,
            jtc.CreatedJobID,
            sps.StagedDate,
            sps.AfterStageId,
            sps.Value
        FROM SSop.Quotes_StagedPaymentSummary(@Guid) AS sps
        JOIN @JobsToCreate AS jtc ON sps.JobId = jtc.ID
        WHERE jtc.ID = @CurrentId;

        PRINT N'Created job';

        ---------------------------------------------------------------------
        -- NEW: Never re-point already-created quote items
        ---------------------------------------------------------------------
        IF (@QuoteItemID > 0)
        BEGIN
            UPDATE SSop.QuoteItems
            SET CreatedJobId = @CreatedJobID
            WHERE ID = @QuoteItemID
              AND ISNULL(CreatedJobId, -1) <= 0;
        END
        ELSE
        BEGIN
            UPDATE qi
            SET qi.CreatedJobId = @CreatedJobID
            FROM SSop.QuoteItems AS qi
            JOIN @EligibleQuoteItems AS eqi ON eqi.QuoteItemID = qi.ID
            JOIN SProd.Products AS p ON p.ID = qi.ProductId
            JOIN SJob.JobTypes AS jt ON p.CreatedJobType = jt.ID
            JOIN SSop.Quotes AS q ON q.ID = qi.QuoteId
            WHERE jt.Guid = @JobTypeGuid
              AND q.Guid = @Guid
              AND p.NeverConsolidate = 0
              AND qi.DoNotConsolidateJob = 0
              AND qi.RowStatus NOT IN (0,254)
              AND ISNULL(qi.CreatedJobId, -1) <= 0;
        END;

        ---------------------------------------------------------------------
        -- CYB-339
        -- Carry quote item Net into dynamic job stage fees by RibaStageID.
        -- This supports standard and user-created RIBA stages without
        -- hardcoding the stage number into SJob.Jobs or FeeAmendment.
        ---------------------------------------------------------------------
        EXEC SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems
             @JobID = @CreatedJobID;

        ---------------------------------------------------------------------
        -- CYB-275
        -- Ensure one default Manual invoice schedule exists per created job
        -- only when none of that job's quote items already has a schedule.
        ---------------------------------------------------------------------
        DECLARE @ExistingInvoiceScheduleId INT = -1;
        DECLARE @ManualInvoiceScheduleGuid UNIQUEIDENTIFIER;
        DECLARE @ManualTriggerGuid UNIQUEIDENTIFIER = NULL;

        SELECT TOP (1)
               @ExistingInvoiceScheduleId = qi.InvoicingSchedule
        FROM SSop.QuoteItems AS qi
        WHERE qi.RowStatus NOT IN (0, 254)
          AND qi.CreatedJobId = @CreatedJobID
          AND ISNULL(qi.InvoicingSchedule, -1) NOT IN (-1, 0)
        ORDER BY qi.ID;

        IF (@ExistingInvoiceScheduleId <= 0)
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM SSop.QuoteItems AS qi
                WHERE qi.RowStatus NOT IN (0, 254)
                  AND qi.CreatedJobId = @CreatedJobID
                  AND ISNULL(qi.InvoicingSchedule, -1) IN (-1, 0)
            )
            BEGIN
                SELECT TOP (1)
                       @ManualTriggerGuid = ist.Guid
                FROM SFin.InvoiceScheduleTrigger AS ist
                WHERE ist.RowStatus NOT IN (0, 254)
                  AND ist.Name = N'Manual'
                ORDER BY ist.ID;

                IF (@ManualTriggerGuid IS NULL)
                BEGIN
                    ;THROW 60000, N'Could not resolve the Manual invoice schedule trigger.', 1;
                END;

                SET @ManualInvoiceScheduleGuid = NEWID();

                EXEC SFin.InvoiceSchedulesUpsert
                     @Guid                             = @ManualInvoiceScheduleGuid,
                     @Name                             = N'Manual',
                     @TriggerGuid                      = @ManualTriggerGuid,
                     @ExpectedDate                     = NULL,
                     @DescriptionOfWork                = N'System generated manual invoice schedule created during job creation.',
                     @Amount                           = 0,
                     @QuoteGuid                        = @Guid,
                     @RibaOnCompletion                 = 0,
                     @RibaOnPartCompletion             = 0,
                     @OnMilestoneCompletion            = 0,
                     @OnActivityCompletion             = 0,
                     @OnActivityAndMilestonCompletion  = 0,
                     @ScheduleReenabled                = 0;

                SELECT @ExistingInvoiceScheduleId = s.ID
                FROM SFin.InvoiceSchedules AS s
                WHERE s.Guid = @ManualInvoiceScheduleGuid
                  AND s.RowStatus NOT IN (0, 254);

                UPDATE qi
                SET qi.InvoicingSchedule = @ExistingInvoiceScheduleId
                FROM SSop.QuoteItems AS qi
                WHERE qi.RowStatus NOT IN (0, 254)
                  AND qi.CreatedJobId = @CreatedJobID
                  AND ISNULL(qi.InvoicingSchedule, -1) IN (-1, 0);
            END;
        END;

        ---------------------------------------------------------------------
        -- Invoice mode initialisation
        ---------------------------------------------------------------------
        DECLARE @InitialInvoiceProcessingMode TINYINT = 1;
        DECLARE @InitialManualInvoicingEnabled BIT = 1;

        DECLARE @SchedulesForJob TABLE
        (
            InvoiceScheduleId INT NOT NULL,
            TriggerId INT NOT NULL
        );

        INSERT INTO @SchedulesForJob (InvoiceScheduleId, TriggerId)
        SELECT DISTINCT
            qi.InvoicingSchedule,
            sch.TriggerId
        FROM SSop.QuoteItems qi
        JOIN SFin.InvoiceSchedules sch
            ON sch.ID = qi.InvoicingSchedule
           AND sch.RowStatus NOT IN (0,254)
        WHERE qi.RowStatus NOT IN (0,254)
          AND qi.CreatedJobId = @CreatedJobID
          AND qi.InvoicingSchedule NOT IN (-1,0);

        IF EXISTS (SELECT 1 FROM @SchedulesForJob)
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM
                (
                    SELECT COUNT(DISTINCT CASE WHEN sfj.TriggerId = -1 THEN 1 ELSE 0 END) AS ModeVariants
                    FROM @SchedulesForJob sfj
                ) x
                WHERE x.ModeVariants > 1
            )
            BEGIN
                SET @InitialInvoiceProcessingMode = 1;
                SET @InitialManualInvoicingEnabled = 1;
            END
            ELSE
            BEGIN
                SELECT TOP (1)
                    @InitialInvoiceProcessingMode = CASE WHEN sfj.TriggerId IN (-1, 8) THEN 1 ELSE 0 END,
                    @InitialManualInvoicingEnabled = CASE WHEN sfj.TriggerId IN (-1, 8) THEN 1 ELSE 0 END
                FROM @SchedulesForJob sfj
                ORDER BY sfj.InvoiceScheduleId;
            END
        END;

        UPDATE j
        SET
            j.InvoiceProcessingMode = @InitialInvoiceProcessingMode,
            j.ManualInvoicingEnabled = @InitialManualInvoicingEnabled
        FROM SJob.Jobs j
        WHERE j.ID = @CreatedJobID
          AND j.RowStatus NOT IN (0,254);

        EXEC SJob.JobActivitiesBuildFromTemplate @JobID = @CreatedJobID;
    END;

    -------------------------------------------------------------------------
    -- Bulk upsert JobPaymentStages
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
    -- Move Quote WF to Complete after successful job creation
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

            EXEC SCore.UpsertDataObject
                @Guid       = @QuoteCompleteTransitionGuid,
                @SchemeName = N'SCore',
                @ObjectName = N'DataObjectTransition',
                @IsInsert   = @TransitionIsInsert OUTPUT;

            EXEC SCore.DataObjectTransitionUpsert
                @Guid              = @QuoteCompleteTransitionGuid,
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