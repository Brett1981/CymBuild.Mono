SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* =============================================================================
   CYB-101 – QA enforcement fix (write-path)
   Object: SCore.DataObjectTransitionUpsert

   QA issue(s) being resolved:
   - QA BLOCKER: "Quote can be changed to Sent/Accepted without Quote item is created"
     • Enquiry 2569 / Quote 2340
     • Enquiry 2574 (pending confirmation)

   Guardrails (respected):
   - NO workflow meaning / lifecycle / allowed transitions changes.
   - Enforcement/validation only at the write-path.
   - Existing "Ready to Send requires Net > 0" rule remains intact.

   What I changed (and why):
   - Added a hard validation for QUOTES:
       If attempting to set Quote to "Sent" or "Accepted",
       the Quote MUST have at least 1 active QuoteItem.
     This prevents the invalid state QA has recorded, even if the UI is bypassed.
============================================================================= */
CREATE PROCEDURE [SCore].[DataObjectTransitionUpsert]
(
    @Guid UNIQUEIDENTIFIER,
    @OldStatusGuid UNIQUEIDENTIFIER,
    @StatusGuid UNIQUEIDENTIFIER,
    @Comment NVARCHAR(MAX),
    @CreatedByUserGuid UNIQUEIDENTIFIER,
    @SurveyorUserGuid UNIQUEIDENTIFIER,
    @DataObjectGuid UNIQUEIDENTIFIER,
    @IsImported BIT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @DateTimeUTC DATETIME2(7) = SYSUTCDATETIME();

    DECLARE @TraceId UNIQUEIDENTIFIER = NEWID();
    DECLARE @ProcName SYSNAME = QUOTENAME(OBJECT_SCHEMA_NAME(@@PROCID)) + N'.' + QUOTENAME(OBJECT_NAME(@@PROCID));

    BEGIN TRY
        BEGIN TRAN;

        -------------------------------------------------------------------------
        -- Guard: transitioned record must exist in SCore.DataObjects
        -------------------------------------------------------------------------
        IF NOT EXISTS
        (
            SELECT 1
            FROM SCore.DataObjects dob
            WHERE dob.Guid = @DataObjectGuid
              AND dob.RowStatus NOT IN (0,254)
        )
            THROW 60002, N'DataObjectTransitionUpsert: DataObjectGuid not found in SCore.DataObjects (record does not exist).', 1;

        -------------------------------------------------------------------------
        -- Resolve CreatedBy / Surveyor IDs
        -------------------------------------------------------------------------
        DECLARE @CreatedByUserID INT = NULL;
        SELECT @CreatedByUserID = i.ID
        FROM SCore.Identities i
        WHERE i.Guid = @CreatedByUserGuid;

        DECLARE @SurveyorUserID INT = NULL;
        SELECT @SurveyorUserID = i.ID
        FROM SCore.Identities i
        WHERE i.Guid = @SurveyorUserGuid;

        -------------------------------------------------------------------------
        -- Resolve incoming WorkflowStatus
        -------------------------------------------------------------------------
        DECLARE @StatusID INT = NULL;
        DECLARE @StatusName NVARCHAR(255) = NULL;
        DECLARE @ShowInQuotes BIT = 0;
        DECLARE @ShowInEnquiries BIT = 0;
        DECLARE @ShowInJobs BIT = 0;

        SELECT
            @StatusID = wfs.ID,
            @StatusName = wfs.Name,
            @ShowInQuotes = wfs.ShowInQuotes,
            @ShowInEnquiries = wfs.ShowInEnquiries,
            @ShowInJobs = wfs.ShowInJobs
        FROM SCore.WorkflowStatus wfs
        WHERE wfs.Guid = @StatusGuid
          AND wfs.RowStatus NOT IN (0,254);

        IF (@StatusID IS NULL)
            THROW 60001, N'Invalid StatusGuid passed to DataObjectTransitionUpsert (no matching WorkflowStatus).', 1;

        -------------------------------------------------------------------------
        -- Determine entity type guid of the transitioned record
        -------------------------------------------------------------------------
        DECLARE @RecordTypeGuid UNIQUEIDENTIFIER = NULL;

        SELECT TOP (1) @RecordTypeGuid = et.Guid
        FROM SCore.DataObjects dob
        JOIN SCore.EntityTypes et ON et.ID = dob.EntityTypeId
        WHERE dob.Guid = @DataObjectGuid
          AND dob.RowStatus NOT IN (0,254);

        -------------------------------------------------------------------------
        -- ENFORCE: Status must match the entity type being transitioned.
        -------------------------------------------------------------------------
        DECLARE @IsEnquiry UNIQUEIDENTIFIER;
        DECLARE @IsQuote   UNIQUEIDENTIFIER;
        DECLARE @IsJob     UNIQUEIDENTIFIER;

        SELECT @IsEnquiry = Guid FROM SCore.EntityTypes WHERE Name = N'Enquiries';
        SELECT @IsQuote   = Guid FROM SCore.EntityTypes WHERE Name = N'Quotes';
        SELECT @IsJob     = Guid FROM SCore.EntityTypes WHERE Name = N'Jobs';

        IF (@RecordTypeGuid = @IsEnquiry)
        BEGIN
            SELECT TOP (1) @StatusID = ws.ID
            FROM SCore.WorkflowStatus ws
            WHERE ws.RowStatus NOT IN (0,254)
              AND ws.ShowInEnquiries = 1
              AND ws.Name = @StatusName
            ORDER BY ws.ID;

            IF (@StatusID IS NULL)
                THROW 60011, N'Invalid status for Enquiry: no WorkflowStatus exists with this Name where ShowInEnquiries=1.', 1;
        END
        ELSE IF (@RecordTypeGuid = @IsQuote)
        BEGIN
            SELECT TOP (1) @StatusID = ws.ID
            FROM SCore.WorkflowStatus ws
            WHERE ws.RowStatus NOT IN (0,254)
              AND ws.ShowInQuotes = 1
              AND ws.Name = @StatusName
            ORDER BY ws.ID;

            IF (@StatusID IS NULL)
                THROW 60012, N'Invalid status for Quote: no WorkflowStatus exists with this Name where ShowInQuotes=1.', 1;
        END
        ELSE IF (@RecordTypeGuid = @IsJob)
        BEGIN
            SELECT TOP (1) @StatusID = ws.ID
            FROM SCore.WorkflowStatus ws
            WHERE ws.RowStatus NOT IN (0,254)
              AND ws.ShowInJobs = 1
              AND ws.Name = @StatusName
            ORDER BY ws.ID;

            IF (@StatusID IS NULL)
                THROW 60013, N'Invalid status for Job: no WorkflowStatus exists with this Name where ShowInJobs=1.', 1;
        END

        /* ----------------------------------------------------------------------
           CYB-101 QA ENFORCEMENT (WRITE-PATH)
           Quote cannot be set to Sent/Accepted unless it has at least 1 QuoteItem.

           Resolves QA blocker:
           - "Quote can be changed to Sent/Accepted without Quote item is created"
             • Enquiry 2569 / Quote 2340
             • Enquiry 2574 (pending confirmation)
        ---------------------------------------------------------------------- */
        IF (@RecordTypeGuid = @IsQuote AND @StatusName IN (N'Sent', N'Accepted'))
        BEGIN
            DECLARE @QuoteItemCount INT = 0;

            SELECT @QuoteItemCount = COUNT(1)
            FROM SSop.QuoteItems qi
            JOIN SSop.Quotes q ON q.ID = qi.QuoteId
            WHERE q.Guid = @DataObjectGuid
              AND q.RowStatus NOT IN (0,254)
              AND qi.RowStatus NOT IN (0,254);

            IF (ISNULL(@QuoteItemCount, 0) <= 0)
                THROW 60022, N'Cannot set Quote status to "Sent" or "Accepted" until at least one Quote Item has been created for the Quote.', 1;
        END

        -------------------------------------------------------------------------
        -- Existing HARD STOP: Quote "Ready to Send" requires Net > 0
        -------------------------------------------------------------------------
        DECLARE @ReadyToSendStatusGuid UNIQUEIDENTIFIER = '02A2237F-2AE7-4E05-926F-38E8B7D050A0';

        IF (@RecordTypeGuid = @IsQuote AND @StatusGuid = @ReadyToSendStatusGuid)
        BEGIN
            DECLARE @QuoteNetValue DECIMAL(18,2) = 0;

            SELECT @QuoteNetValue =
                ISNULL(
                    (
                        SELECT SUM(qit.LineNet)
                        FROM SSop.QuoteItemTotals AS qit
                        JOIN SSop.QuoteItems      AS qi ON qi.ID = qit.ID
                        JOIN SSop.Quotes          AS q  ON q.ID  = qi.QuoteId
                        WHERE q.Guid = @DataObjectGuid
                          AND qi.RowStatus NOT IN (0,254)
                    ),
                    0
                );

            IF (@QuoteNetValue <= 0)
                THROW 60021, N'Cannot set status to "Ready to Send" until the quote has at least one Quote Item with a net value greater than 0.', 1;
        END

        -------------------------------------------------------------------------
        -- Compute OldStatusID
        -------------------------------------------------------------------------
        DECLARE @OldStatusID INT = NULL;

        SELECT TOP (1) @OldStatusID = dot.StatusID
        FROM SCore.DataObjectTransition dot
        WHERE dot.DataObjectGuid = @DataObjectGuid
          AND dot.RowStatus NOT IN (0,254)
          AND dot.Guid <> @Guid
        ORDER BY dot.ID DESC;

        IF (@OldStatusID IS NULL AND @OldStatusGuid IS NOT NULL AND @OldStatusGuid <> '00000000-0000-0000-0000-000000000000')
        BEGIN
            SELECT TOP (1) @OldStatusID = ws.ID
            FROM SCore.WorkflowStatus ws
            WHERE ws.Guid = @OldStatusGuid
              AND ws.RowStatus NOT IN (0,254);
        END

        IF (@OldStatusID IS NULL)
        BEGIN
            SELECT TOP (1) @OldStatusID = ws.ID
            FROM SCore.WorkflowStatus ws
            WHERE ws.Guid = '00000000-0000-0000-0000-000000000000'
              AND ws.RowStatus NOT IN (0,254);
        END

        -------------------------------------------------------------------------
        -- JOB CREATION FIX
        -------------------------------------------------------------------------
        SELECT @IsJob = Guid FROM SCore.EntityTypes WHERE Name = N'Jobs';

        IF (@RecordTypeGuid = @IsJob)
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM SCore.DataObjectTransition dot
                WHERE dot.DataObjectGuid = @DataObjectGuid
                  AND dot.RowStatus NOT IN (0,254)
            )
            BEGIN
                DECLARE @JobNewStatusID INT = NULL;
                DECLARE @JobNewStatusName NVARCHAR(255) = NULL;

                SELECT TOP (1)
                    @JobNewStatusID = ws.ID,
                    @JobNewStatusName = ws.Name
                FROM SCore.WorkflowStatus ws
                WHERE ws.RowStatus NOT IN (0,254)
                  AND ws.ShowInJobs = 1
                  AND ws.Name = N'New'
                ORDER BY ws.ID;

                IF (@JobNewStatusID IS NOT NULL)
                BEGIN
                    SET @StatusID = @JobNewStatusID;
                    SET @StatusName = @JobNewStatusName;
                    SET @ShowInJobs = 1;
                END
            END
        END

        -------------------------------------------------------------------------
        -- Ensure DataObjects row exists for Transition GUID
        -------------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM SCore.DataObjects WHERE Guid = @Guid)
        BEGIN
            DECLARE @TransitionEntityTypeId INT = NULL;

            SELECT TOP (1) @TransitionEntityTypeId = eh.EntityTypeID
            FROM SCore.EntityHobts eh
            WHERE eh.SchemaName = N'SCore'
              AND eh.ObjectName = N'DataObjectTransition';

            IF (@TransitionEntityTypeId IS NULL)
                THROW 60003, N'DataObjectTransitionUpsert: could not resolve EntityTypeID for SCore.DataObjectTransition from EntityHobts.', 1;

            INSERT SCore.DataObjects (Guid, RowStatus, EntityTypeId)
            VALUES (@Guid, 1, @TransitionEntityTypeId);
        END

        -------------------------------------------------------------------------
        -- Upsert SCore.DataObjectTransition
        -------------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM SCore.DataObjectTransition WHERE Guid = @Guid)
        BEGIN
            INSERT INTO SCore.DataObjectTransition
            (
                Guid,
                RowStatus,
                OldStatusID,
                StatusID,
                Comment,
                DateTimeUTC,
                CreatedByUserId,
                SurveyorUserId,
                DataObjectGuid,
                IsImported
            )
            VALUES
            (
                @Guid,
                1,
                @OldStatusID,
                @StatusID,
                @Comment,
                @DateTimeUTC,
                @CreatedByUserID,
                @SurveyorUserID,
                @DataObjectGuid,
                @IsImported
            );
        END
        ELSE
        BEGIN
            UPDATE SCore.DataObjectTransition
            SET
                OldStatusID      = @OldStatusID,
                StatusID         = @StatusID,
                Comment          = @Comment,
                DateTimeUTC      = @DateTimeUTC,
                CreatedByUserId  = @CreatedByUserID,
                SurveyorUserId   = @SurveyorUserID,
                DataObjectGuid   = @DataObjectGuid,
                IsImported       = @IsImported
            WHERE Guid = @Guid;

            IF (@@ROWCOUNT = 0)
            BEGIN
                INSERT INTO SCore.DataObjectTransition
                (
                    Guid,
                    RowStatus,
                    OldStatusID,
                    StatusID,
                    Comment,
                    DateTimeUTC,
                    CreatedByUserId,
                    SurveyorUserId,
                    DataObjectGuid,
                    IsImported
                )
                VALUES
                (
                    @Guid,
                    1,
                    @OldStatusID,
                    @StatusID,
                    @Comment,
                    @DateTimeUTC,
                    @CreatedByUserID,
                    @SurveyorUserID,
                    @DataObjectGuid,
                    @IsImported
                );
            END
        END;

        -------------------------------------------------------------------------
        -- (Job->Quote completion, Quote->Enquiry sync, etc.)
        -- (left unchanged)
        -------------------------------------------------------------------------

        IF (@RecordTypeGuid = @IsJob)
        BEGIN
            DECLARE @JobID INT = NULL;

            SELECT TOP (1) @JobID = j.ID
            FROM SJob.Jobs j
            WHERE j.Guid = @DataObjectGuid
              AND j.RowStatus NOT IN (0,254);

            IF (@JobID IS NOT NULL)
            BEGIN
                DECLARE @QuoteGuid UNIQUEIDENTIFIER = NULL;
                DECLARE @QuoteDataObjectGuid UNIQUEIDENTIFIER = NULL;

                SELECT TOP (1)
                    @QuoteGuid = q.Guid
                FROM SSop.QuoteItems qi
                JOIN SSop.Quotes q ON q.ID = qi.QuoteId
                WHERE qi.RowStatus NOT IN (0,254)
                  AND q.RowStatus  NOT IN (0,254)
                  AND qi.CreatedJobId = @JobID;

                SET @QuoteDataObjectGuid = @QuoteGuid;

                IF (@QuoteDataObjectGuid IS NOT NULL)
                BEGIN
                    DECLARE @QuoteIsComplete BIT = 0;

                    IF EXISTS
                    (
                        SELECT 1
                        FROM SSop.QuoteItems qi
                        JOIN SSop.Quotes q ON q.ID = qi.QuoteId
                        WHERE q.Guid = @QuoteDataObjectGuid
                          AND q.RowStatus NOT IN (0,254)
                          AND qi.RowStatus NOT IN (0,254)
                    )
                    AND NOT EXISTS
                    (
                        SELECT 1
                        FROM SSop.QuoteItems qi
                        JOIN SSop.Quotes q ON q.ID = qi.QuoteId
                        WHERE q.Guid = @QuoteDataObjectGuid
                          AND q.RowStatus NOT IN (0,254)
                          AND qi.RowStatus NOT IN (0,254)
                          AND ISNULL(qi.CreatedJobId, 0) <= 0
                    )
                    BEGIN
                        SET @QuoteIsComplete = 1;
                    END

                    IF (@QuoteIsComplete = 1)
                    BEGIN
                        DECLARE @QuoteCompleteStatusGuid UNIQUEIDENTIFIER = NULL;

                        SELECT TOP (1) @QuoteCompleteStatusGuid = ws.Guid
                        FROM SCore.WorkflowStatus ws
                        WHERE ws.RowStatus NOT IN (0,254)
                          AND ws.ShowInQuotes = 1
                          AND ws.Name = N'Complete'
                        ORDER BY ws.ID;

                        IF (@QuoteCompleteStatusGuid IS NOT NULL)
                        BEGIN
                            DECLARE @LatestQuoteStatusID INT = NULL;
                            DECLARE @CompleteQuoteStatusID INT = NULL;

                            SELECT TOP (1) @LatestQuoteStatusID = dot.StatusID
                            FROM SCore.DataObjectTransition dot
                            WHERE dot.DataObjectGuid = @QuoteDataObjectGuid
                              AND dot.RowStatus NOT IN (0,254)
                            ORDER BY dot.ID DESC;

                            SELECT TOP (1) @CompleteQuoteStatusID = ws.ID
                            FROM SCore.WorkflowStatus ws
                            WHERE ws.Guid = @QuoteCompleteStatusGuid
                              AND ws.RowStatus NOT IN (0,254);

                            IF (@CompleteQuoteStatusID IS NOT NULL
                                AND ISNULL(@LatestQuoteStatusID, -1) <> @CompleteQuoteStatusID)
                            BEGIN
                                DECLARE @QuoteCompleteTransitionGuid UNIQUEIDENTIFIER = NEWID();

                                EXEC SCore.DataObjectTransitionUpsert
                                    @Guid             = @QuoteCompleteTransitionGuid,
                                    @OldStatusGuid     = '00000000-0000-0000-0000-000000000000',
                                    @StatusGuid        = @QuoteCompleteStatusGuid,
                                    @Comment           = N'System Imported (Job created).',
                                    @CreatedByUserGuid = @CreatedByUserGuid,
                                    @SurveyorUserGuid  = @SurveyorUserGuid,
                                    @DataObjectGuid    = @QuoteDataObjectGuid,
                                    @IsImported        = 1;
                            END
                        END
                    END
                END
            END
        END

        -------------------------------------------------------------------------
        -- Synchronisation: QUOTE -> ENQUIRY (+ EnquiryService)
        -- (left unchanged)
        -------------------------------------------------------------------------
        SELECT @IsQuote = Guid FROM SCore.EntityTypes WHERE Name = N'Quotes';

        IF (@RecordTypeGuid = @IsQuote)
        BEGIN
            DECLARE @EnquiryGuid UNIQUEIDENTIFIER = NULL;
            DECLARE @EnquiryServiceGuid UNIQUEIDENTIFIER = NULL;

            SELECT TOP (1)
                @EnquiryServiceGuid = es.Guid,
                @EnquiryGuid        = e.Guid
            FROM SSop.Quotes q
            JOIN SSop.EnquiryServices es ON es.ID = q.EnquiryServiceID
            JOIN SSop.Enquiries e        ON e.ID  = es.EnquiryId
            WHERE q.Guid = @DataObjectGuid
              AND q.RowStatus NOT IN (0,254)
              AND es.RowStatus NOT IN (0,254)
              AND e.RowStatus NOT IN (0,254);

            DECLARE @TargetEnquiryStatusName NVARCHAR(255) = @StatusName;

            IF (@StatusName = N'Quote Deadline Approaching') SET @TargetEnquiryStatusName = N'Deadline Approaching';
            IF (@StatusName = N'Quote Deadline Missing')     SET @TargetEnquiryStatusName = N'Deadline Missed';
            IF (@StatusName = N'Quote Expired')              SET @TargetEnquiryStatusName = N'Expired';
            IF (@StatusName = N'Is Final (Ready to Send)')   SET @TargetEnquiryStatusName = N'Ready to Send';

            DECLARE @TargetGuid UNIQUEIDENTIFIER;
            DECLARE @TargetOldStatusID INT;
            DECLARE @TargetNewStatusID INT;

            -- 1) Sync to ENQUIRY (unchanged)
            IF (@EnquiryGuid IS NOT NULL)
            BEGIN
                SET @TargetGuid = @EnquiryGuid;

                SELECT TOP (1) @TargetNewStatusID = ws.ID
                FROM SCore.WorkflowStatus ws
                WHERE ws.RowStatus NOT IN (0,254)
                  AND ws.ShowInEnquiries = 1
                  AND ws.Name = @TargetEnquiryStatusName
                ORDER BY ws.ID;

                IF (@TargetNewStatusID = -1)
                    SET @TargetNewStatusID = NULL;

                IF (@TargetNewStatusID IS NOT NULL)
                BEGIN
                    SELECT TOP (1) @TargetOldStatusID = dot.StatusID
                    FROM SCore.DataObjectTransition dot
                    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
                    WHERE dot.DataObjectGuid = @TargetGuid
                      AND dot.RowStatus NOT IN (0,254)
                      AND wfs.RowStatus NOT IN (0,254)
                      AND wfs.ShowInEnquiries = 1
                    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC;

                    IF (ISNULL(@TargetOldStatusID, -999999) <> @TargetNewStatusID)
                    BEGIN
                        DECLARE @SyncEnquiryTransitionGuid UNIQUEIDENTIFIER = NEWID();
                        DECLARE @Tmp BIT = 0;

                        EXEC SCore.UpsertDataObject
                            @Guid       = @SyncEnquiryTransitionGuid,
                            @SchemeName = N'SCore',
                            @ObjectName = N'DataObjectTransition',
                            @IsInsert   = @Tmp OUTPUT;

                        INSERT INTO SCore.DataObjectTransition
                        (
                            Guid, RowStatus, OldStatusID, StatusID, Comment, DateTimeUTC,
                            CreatedByUserId, SurveyorUserId, DataObjectGuid, IsImported
                        )
                        VALUES
                        (
                            @SyncEnquiryTransitionGuid,
                            1,
                            @TargetOldStatusID,
                            @TargetNewStatusID,
                            N'System Imported (Quote sync).',
                            @DateTimeUTC,
                            @CreatedByUserID,
                            @SurveyorUserID,
                            @TargetGuid,
                            1
                        );
                    END
                END
            END

            -- 2) Sync to ENQUIRY SERVICE (unchanged)
            IF (@EnquiryServiceGuid IS NOT NULL)
            BEGIN
                SET @TargetGuid = @EnquiryServiceGuid;

                SELECT TOP (1) @TargetNewStatusID = ws.ID
                FROM SCore.WorkflowStatus ws
                WHERE ws.RowStatus NOT IN (0,254)
                  AND ws.ShowInEnquiries = 1
                  AND ws.Name = @TargetEnquiryStatusName
                ORDER BY ws.ID;

                IF (@TargetNewStatusID = -1)
                    SET @TargetNewStatusID = NULL;

                IF (@TargetNewStatusID IS NOT NULL)
                BEGIN
                    SELECT TOP (1) @TargetOldStatusID = dot.StatusID
                    FROM SCore.DataObjectTransition dot
                    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
                    WHERE dot.DataObjectGuid = @TargetGuid
                      AND dot.RowStatus NOT IN (0,254)
                      AND wfs.RowStatus NOT IN (0,254)
                      AND wfs.ShowInEnquiries = 1
                    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC;

                    IF (ISNULL(@TargetOldStatusID, -999999) <> @TargetNewStatusID)
                    BEGIN
                        DECLARE @SyncEnquiryServiceTransitionGuid UNIQUEIDENTIFIER = NEWID();
                        DECLARE @Tmp2 BIT = 0;

                        EXEC SCore.UpsertDataObject
                            @Guid       = @SyncEnquiryServiceTransitionGuid,
                            @SchemeName = N'SCore',
                            @ObjectName = N'DataObjectTransition',
                            @IsInsert   = @Tmp2 OUTPUT;

                        INSERT INTO SCore.DataObjectTransition
                        (
                            Guid, RowStatus, OldStatusID, StatusID, Comment, DateTimeUTC,
                            CreatedByUserId, SurveyorUserId, DataObjectGuid, IsImported
                        )
                        VALUES
                        (
                            @SyncEnquiryServiceTransitionGuid,
                            1,
                            @TargetOldStatusID,
                            @TargetNewStatusID,
                            N'System Imported (Quote sync).',
                            @DateTimeUTC,
                            @CreatedByUserID,
                            @SurveyorUserID,
                            @TargetGuid,
                            1
                        );
                    END
                END
            END
        END;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;

        DECLARE @ErrMsg NVARCHAR(MAX);
        DECLARE @Final NVARCHAR(MAX);

        SELECT @ErrMsg = ERROR_MESSAGE();

        SET @Final =
            N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
            + N' FAILED | TransitionGuid=' + CONVERT(NVARCHAR(36), @Guid)
            + N' | RecordGuid=' + CONVERT(NVARCHAR(36), @DataObjectGuid)
            + N' | ' + @ErrMsg;

        THROW 61099, @Final, 1;
    END CATCH
END
GO