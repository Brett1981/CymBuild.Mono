SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[DataObjectTransitionImportLegacyStatus]
AS
BEGIN
    ----------------------------------------------------------------------
    -- [Enquiries]
    ----------------------------------------------------------------------
    DECLARE @EnquiryID INT;
    DECLARE @EnquiryGuid UNIQUEIDENTIFIER;
    DECLARE @EnquiryStatus NVARCHAR(20);

    ----------------------------------------------------------------------
    -- [Quotes]
    ----------------------------------------------------------------------
    DECLARE @QuoteID INT;
    DECLARE @QuoteGuid UNIQUEIDENTIFIER;
    DECLARE @QuoteStatus NVARCHAR(20);

    ----------------------------------------------------------------------
    -- [Jobs]
    ----------------------------------------------------------------------
    DECLARE @JobID INT;
    DECLARE @JobGuid UNIQUEIDENTIFIER;
    DECLARE @JobStatus NVARCHAR(20);

    ----------------------------------------------------------------------
    -- [Universal - exists across the record types]
    ----------------------------------------------------------------------
    DECLARE @Number NVARCHAR(50);

    ----------------------------------------------------------------------
    -- Clean up temp tables
    ----------------------------------------------------------------------
    DROP TABLE IF EXISTS #RecordStatuses;
    DROP TABLE IF EXISTS #EnquiriesToProcess;
    DROP TABLE IF EXISTS #QuotesToProcess;
    DROP TABLE IF EXISTS #JobsToProcess;

    ----------------------------------------------------------------------
    -- Temp table for all statuses
    ----------------------------------------------------------------------
    CREATE TABLE #RecordStatuses
    (
        RecordType   NVARCHAR(30) NOT NULL,
        Number       NVARCHAR(50) NOT NULL,
        RecordStatus NVARCHAR(20) NOT NULL,
        RecordGuid   UNIQUEIDENTIFIER NOT NULL
    );

    ----------------------------------------------------------------------
    -- 1: Process the enquiries
    ----------------------------------------------------------------------
    SELECT ID, Number, Guid
    INTO #EnquiriesToProcess
    FROM SSop.Enquiries
    WHERE RowStatus NOT IN (0, 254)
    ORDER BY ID DESC;

    WHILE EXISTS(SELECT 1 FROM #EnquiriesToProcess)
    BEGIN
        SELECT TOP 1
            @EnquiryID   = ID,
            @Number      = Number,
            @EnquiryGuid = Guid
        FROM #EnquiriesToProcess
        ORDER BY ID;

        SELECT @EnquiryStatus = QuotingStatus
        FROM SSop.Tvf_GetEnquiryStatuses(@EnquiryID);

        INSERT INTO #RecordStatuses (RecordType, Number, RecordStatus, RecordGuid)
        VALUES (N'Enquiry', @Number, @EnquiryStatus, @EnquiryGuid);

        DELETE FROM #EnquiriesToProcess
        WHERE ID = @EnquiryID;
    END;

    ----------------------------------------------------------------------
    -- 2: Process the quotes
    ----------------------------------------------------------------------
    SELECT ID, Number, Guid
    INTO #QuotesToProcess
    FROM SSop.Quotes
    WHERE RowStatus NOT IN (0, 254)
    ORDER BY ID DESC;

    WHILE EXISTS(SELECT 1 FROM #QuotesToProcess)
    BEGIN
        SELECT TOP 1
            @QuoteID   = ID,
            @Number    = Number,
            @QuoteGuid = Guid
        FROM #QuotesToProcess
        ORDER BY ID;

        SELECT @QuoteStatus = QuoteStatus
        FROM SSop.Quote_CalculatedFields
        WHERE ID = @QuoteID;

        INSERT INTO #RecordStatuses (RecordType, Number, RecordStatus, RecordGuid)
        VALUES (N'Quote', @Number, @QuoteStatus, @QuoteGuid);

        DELETE FROM #QuotesToProcess
        WHERE ID = @QuoteID;
    END;

    ----------------------------------------------------------------------
    -- 3: Process the jobs
    ----------------------------------------------------------------------
    SELECT ID, Number, Guid
    INTO #JobsToProcess
    FROM SJob.Jobs
    WHERE RowStatus NOT IN (0, 254)
    ORDER BY ID DESC;

    WHILE EXISTS(SELECT 1 FROM #JobsToProcess)
    BEGIN
        SELECT TOP 1
            @JobID   = ID,
            @Number  = Number,
            @JobGuid = Guid
        FROM #JobsToProcess
        ORDER BY ID;

        SELECT @JobStatus = JobStatus
        FROM SJob.JobStatus
        WHERE ID = @JobID;

        INSERT INTO #RecordStatuses (RecordType, Number, RecordStatus, RecordGuid)
        VALUES (N'Job', @Number, @JobStatus, @JobGuid);

        DELETE FROM #JobsToProcess
        WHERE ID = @JobID;
    END;

    ----------------------------------------------------------------------
    -- Main loop: turn legacy flags into DataObjectTransition rows
    ----------------------------------------------------------------------
    WHILE EXISTS(SELECT 1 FROM #RecordStatuses)
    BEGIN
        ------------------------------------------------------------------
        -- Values to insert into [SCore].[DataObjectTransition]
        ------------------------------------------------------------------
        DECLARE @NewStatusGuid     UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';
        DECLARE @Comment           NVARCHAR(MAX)    = N'Imported status.';
        DECLARE @DateTimeUTC       DATETIME2        = SYSUTCDATETIME();
        DECLARE @CreatedByUserId   INT              = -1;
        DECLARE @SurveyorUserID    INT;
        DECLARE @IsImported        BIT              = 1;

        --Currently processed record.
        DECLARE @CurrentRecordGuid   UNIQUEIDENTIFIER;
        DECLARE @CurrentRecordType   NVARCHAR(30);
        DECLARE @CurrentRecordStatus NVARCHAR(20);

        -- Dead date (All three record types have this)
        DECLARE @Dead DATE;

        ------------------------------------------------------------------
        -- 1. Get the top record.
        ------------------------------------------------------------------
        SELECT TOP 1 
            @CurrentRecordGuid   = RecordGuid,
            @CurrentRecordType   = RecordType,
            @CurrentRecordStatus = RecordStatus
        FROM #RecordStatuses
        ORDER BY RecordType;

        ------------------------------------------------------------------
        -- 2. Determine status GUID from legacy fields
        ------------------------------------------------------------------
        IF (@CurrentRecordType = N'Enquiry')
        BEGIN
            --Statuses
            DECLARE @ReadyForQuoteStatus UNIQUEIDENTIFIER = 'EB867FA0-9608-4CC7-93BE-CC8E8140E8F0';
            DECLARE @DeclinedStatus      UNIQUEIDENTIFIER = '708C00E6-F45F-4CB2-8E91-A80B8B8E802E';
            DECLARE @FirstChaseStatus    UNIQUEIDENTIFIER = '9FF22CEA-A2A6-4907-9B2D-E62DF8150913';
            DECLARE @SecondChaseStatus   UNIQUEIDENTIFIER = '1F01C16B-1A73-4844-A938-FE357405FD93';
            DECLARE @DeadStatus          UNIQUEIDENTIFIER = '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D';

            --Variables used to determine the last applied status.
            DECLARE @ReadyForQuote BIT;
            DECLARE @Declined      DATE;
            DECLARE @FirstChase    DATE;
            DECLARE @SecondChase   DATE;
            
            --Surveyor
            SELECT @SurveyorUserID = CreatedByUserId 
            FROM [SSop].[Enquiries] 
            WHERE Guid = @CurrentRecordGuid;

            --Get all the status fields.
            SELECT 
                @ReadyForQuote = IsReadyForQuoteReview,
                @Declined      = DeclinedToQuoteDate,
                @FirstChase    = ChaseDate1,
                @SecondChase   = ChaseDate2,
                @Dead          = DeadDate
            FROM SSop.Enquiries 
            WHERE Guid = @CurrentRecordGuid;

            IF (@SecondChase IS NOT NULL)       -- 2nd Chase
                SET @NewStatusGuid = @SecondChaseStatus;
            ELSE IF (@FirstChase IS NOT NULL)   -- 1st Chase
                SET @NewStatusGuid = @FirstChaseStatus;
            ELSE IF (@Dead IS NOT NULL)         -- Dead
                SET @NewStatusGuid = @DeadStatus;
            ELSE IF (@Declined IS NOT NULL)     -- Declined
                SET @NewStatusGuid = @DeclinedStatus;
            ELSE IF (@ReadyForQuote = 1)        -- Ready for Quote
                SET @NewStatusGuid = @ReadyForQuoteStatus;
        END
        ELSE IF (@CurrentRecordType = N'Quote')
        BEGIN
            --Statuses (note: DeclinedStatus / DeadStatus from Enquiry block are batch-scoped constants)
            DECLARE @SentStatus     UNIQUEIDENTIFIER = '25D5491C-42A8-4B04-B3AC-D648AF0F8032';
            DECLARE @AcceptedStatus UNIQUEIDENTIFIER = '21A29AEE-2D99-4DA3-8182-F31813B0C498';
            DECLARE @RejectedStatus UNIQUEIDENTIFIER = '0A6A71F7-B39F-4213-997E-2B3A13B6144C';
            DECLARE @IsFinalStatus  UNIQUEIDENTIFIER = '02A2237F-2AE7-4E05-926F-38E8B7D050A0';

            DECLARE @IsFinal      BIT  = 0;
            DECLARE @Sent         DATE = NULL;
            DECLARE @Accepted     DATE = NULL;
            DECLARE @Rejected     DATE = NULL;
            DECLARE @QuoteDeclined DATE = NULL;
            DECLARE @QuoteDead     DATE = NULL;

            SELECT 
                @IsFinal        = IsFinal,
                @Sent           = DateSent,
                @Accepted       = DateAccepted,
                @Rejected       = DateRejected,
                @QuoteDeclined  = DateDeclinedToQuote,
                @QuoteDead      = DeadDate,
                @SurveyorUserID = QuotingConsultantId
            FROM SSop.Quotes
            WHERE Guid = @CurrentRecordGuid;

            IF (@IsFinal = 1)
            BEGIN
                SET @NewStatusGuid = @IsFinalStatus;

                IF (@Sent IS NOT NULL)
                    SET @NewStatusGuid = @SentStatus;

                IF (@Accepted IS NOT NULL)
                    SET @NewStatusGuid = @AcceptedStatus;
                ELSE IF (@Rejected IS NOT NULL)
                    SET @NewStatusGuid = @RejectedStatus;
            END

            --Check for declined / dead status (using DeclinedStatus/DeadStatus declared above)
            ELSE IF (@QuoteDeclined IS NOT NULL)
                SET @NewStatusGuid = @DeclinedStatus;
            ELSE IF (@QuoteDead IS NOT NULL)
                SET @NewStatusGuid = @DeadStatus;
        END
        ELSE IF (@CurrentRecordType = N'Job')
        BEGIN
            DECLARE @CompletedStatus           UNIQUEIDENTIFIER = '20D22623-283B-4088-9CEB-D944AC3E6516';
            DECLARE @CanceledStatus            UNIQUEIDENTIFIER = '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64';
            DECLARE @DormantStatus             UNIQUEIDENTIFIER = '6708FDB6-29A7-4505-A209-F1E785386122';
            DECLARE @CompletedForReviewStatus  UNIQUEIDENTIFIER = '4BFDB215-3E27-4829-BB44-0468C92DAC82';
            DECLARE @ReviewedStatus            UNIQUEIDENTIFIER = '90407454-9FED-4AAC-AB20-669C5821FE7A';

            DECLARE @Dormant            DATE;
            DECLARE @Cancelled          DATE;
            DECLARE @Completed          DATE;
            DECLARE @DeadJob            DATE;
            DECLARE @CompletedForReview DATE;
            DECLARE @Reviewed           DATE;
            
            --Surveyor
            SELECT @SurveyorUserID = SurveyorID 
            FROM SJob.Jobs
            WHERE Guid = @CurrentRecordGuid;

            SELECT 
                @Dormant            = JobDormant,
                @Cancelled          = JobCancelled,
                @Completed          = JobCompleted,
                @DeadJob            = DeadDate,
                @CompletedForReview = CompletedForReviewDate,
                @Reviewed           = ReviewedDateTimeUTC
            FROM SJob.Jobs
            WHERE Guid = @CurrentRecordGuid;

            IF (@Completed IS NOT NULL)
                SET @NewStatusGuid = @CompletedStatus;
            ELSE IF (@Cancelled IS NOT NULL)
                SET @NewStatusGuid = @CanceledStatus;
            ELSE IF (@Dormant IS NOT NULL)
                SET @NewStatusGuid = @DormantStatus;
            ELSE IF (@DeadJob IS NOT NULL)
                SET @NewStatusGuid = @DeadStatus;
            ELSE IF (@CompletedForReview IS NOT NULL)
                SET @NewStatusGuid = @CompletedForReviewStatus;
            ELSE IF (@Reviewed IS NOT NULL)
                SET @NewStatusGuid = @ReviewedStatus;
        END;

        ------------------------------------------------------------------
        -- 3. Only upsert if we actually resolved a status GUID
        ------------------------------------------------------------------
        IF (@NewStatusGuid <> '00000000-0000-0000-0000-000000000000')
        BEGIN
            DECLARE @RecordGuid  UNIQUEIDENTIFIER = NEWID();
            DECLARE @NewStatusID INT;

            -- FIX: use WorkflowStatus (not Workflow), and handle missing row
            SELECT @NewStatusID = ID
            FROM SCore.WorkflowStatus
            WHERE Guid = @NewStatusGuid;

            IF (@NewStatusID IS NULL)
            BEGIN
                PRINT 'WARNING: No WorkflowStatus found for Guid = '
                      + CONVERT(VARCHAR(36), @NewStatusGuid)
                      + ' | RecordType = ' + ISNULL(@CurrentRecordType, '<NULL>')
                      + ' | RecordGuid = ' + CONVERT(VARCHAR(36), @CurrentRecordGuid)
                      + ' | StatusFromLegacy = ' + ISNULL(@CurrentRecordStatus, '<NULL>');

                -- Skip this record to avoid NULL StatusID insert
            END
            ELSE
            BEGIN
                -- This PRINT usually comes from UpsertDataObject itself, but keep logic clear
                EXEC SCore.UpsertDataObject
                    @Guid       = @RecordGuid,
                    @SchemeName = N'SCore',
                    @ObjectName = N'DataObjectTransition',
                    @IsInsert   = 1;	-- bit		

                INSERT INTO [SCore].[DataObjectTransition]
                (
                    RowStatus, 
                    Guid, 
                    StatusID, 
                    OldStatusID, 
                    Comment, 
                    DateTimeUTC,
                    CreatedByUserId,
                    SurveyorUserId, 
                    DataObjectGuid, 
                    IsImported 
                )
                VALUES
                (
                    1,
                    @RecordGuid,
                    @NewStatusID,
                    -1,
                    @Comment,
                    SYSDATETIME(),
                    @CreatedByUserId,
                    @SurveyorUserID,
                    @CurrentRecordGuid,
                    1
                );
            END
        END
        ELSE
        BEGIN
            -- log that no legacy status was derivable for this record
            PRINT 'INFO: No legacy status mapped for RecordType = '
                  + ISNULL(@CurrentRecordType, '<NULL>')
                  + ' | RecordGuid = ' + CONVERT(VARCHAR(36), @CurrentRecordGuid);
        END;

        ------------------------------------------------------------------
        -- 4. Delete processed record from temp table
        ------------------------------------------------------------------
        DELETE FROM #RecordStatuses
        WHERE RecordGuid = @CurrentRecordGuid;
    END;
END;
GO