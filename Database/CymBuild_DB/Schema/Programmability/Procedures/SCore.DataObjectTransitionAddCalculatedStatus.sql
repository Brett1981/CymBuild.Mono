SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[DataObjectTransitionAddCalculatedStatus]
AS
BEGIN
    DECLARE @RecordTypeName NVARCHAR(250);
    DECLARE @WorkflowStatusID INT;
    DECLARE @OldStatusID INT = -1;
    DECLARE @NewStatusID INT;
    DECLARE @Comment NVARCHAR(50) = N'System Imported.';
    DECLARE @CreatedByUserId INT = -1;
    DECLARE @SurveyorUserID INT;

    CREATE TABLE #RecordsToProcess(
        Guid UNIQUEIDENTIFIER,
        Status NVARCHAR(50)
    );

    ----------------------------------------------------------------------
    -- Seed temp table from Enquiries, Quotes, Jobs
    ----------------------------------------------------------------------
    INSERT INTO #RecordsToProcess
        -- Enquiries (using Enquiry_CalculatedFields) – now ALL statuses
        SELECT  
            e.Guid,
            ecf.EnquiryStatus AS Status
        FROM SSop.Enquiries AS e
        JOIN SSop.Enquiry_CalculatedFields AS ecf ON (ecf.ID = e.ID)
        UNION ALL
        -- Quotes (using Quote_CalculatedFields) - include Sent/Rejected/Expired/etc
        SELECT 
            q.Guid,
            qcf.QuoteStatus AS Status
        FROM SSop.Quotes AS q
        JOIN SSop.Quote_CalculatedFields qcf ON (qcf.ID = q.ID)
        WHERE 
            (q.RowStatus NOT IN (0,254)) 
            AND (q.LegacyId IS NULL)  -- Exclude imported jobs
        UNION ALL
        -- Jobs (using JobStatus view) - include Completed, Cancelled, etc
        SELECT 
            j.Guid,
            js.JobStatus AS Status
        FROM SJob.Jobs AS j
        JOIN SJob.JobStatus AS js ON (js.ID = j.ID) 
        WHERE 
            (j.RowStatus NOT IN (0,254));

    DECLARE @Remaining INT;
    SELECT @Remaining = COUNT(1) FROM #RecordsToProcess;

    PRINT 'DataObjectTransitionAddCalculatedStatus: Starting. RecordsToProcess = ' 
        + CAST(@Remaining AS VARCHAR(20));

    ----------------------------------------------------------------------
    -- Iterate over the collection.
    ----------------------------------------------------------------------
    WHILE (EXISTS(SELECT 1 FROM #RecordsToProcess))
    BEGIN
        DECLARE @RecordGuid UNIQUEIDENTIFIER;
        DECLARE @Status NVARCHAR(50);

        -- Reset per-iteration variables
        SET @RecordGuid = NULL;
        SET @Status = NULL;
        SET @RecordTypeName = NULL;
        SET @SurveyorUserID = NULL;
        SET @OldStatusID = NULL;
        SET @NewStatusID = NULL;

        SELECT TOP 1 
               @RecordGuid  = Guid, 
               @Status      = Status
        FROM #RecordsToProcess;

        PRINT '---';
        PRINT 'Processing record: ' + ISNULL(CONVERT(VARCHAR(36), @RecordGuid), '<NULL>')
              + ' | Status = ' + ISNULL(@Status, '<NULL>');

        ------------------------------------------------------------------
        -- Get the record type -> then get the surveyor for the correct type.
        ------------------------------------------------------------------
        SELECT @RecordTypeName = et.Name
        FROM SCore.DataObjects root_hobt
        JOIN SCore.EntityTypes AS et ON et.ID = root_hobt.EntityTypeId
        WHERE root_hobt.Guid = @RecordGuid;

        PRINT 'Record type name = ' + ISNULL(@RecordTypeName, '<NULL>');

        --Get the surveyor
        IF (@RecordTypeName = N'Enquiries')
        BEGIN
            SELECT @SurveyorUserID = CreatedByUserId 
            FROM [SSop].[Enquiries] 
            WHERE Guid = @RecordGuid;
        END
        ELSE IF (@RecordTypeName = N'Quotes')
        BEGIN
            SELECT @SurveyorUserID = QuotingConsultantId
            FROM SSop.Quotes
            WHERE Guid = @RecordGuid;
        END
        ELSE IF (@RecordTypeName = N'Jobs')
        BEGIN
            SELECT @SurveyorUserID = SurveyorID
            FROM SJob.Jobs
            WHERE Guid = @RecordGuid;
        END

        PRINT 'SurveyorUserID = ' + ISNULL(CAST(@SurveyorUserID AS VARCHAR(20)), '<NULL>');

        ------------------------------------------------------------------
        -- Ensure WorkflowStatus + DataObjectTransition for this Status
        ------------------------------------------------------------------
        IF (EXISTS(SELECT 1 FROM SCore.WorkflowStatus WHERE Name = @Status))
        BEGIN
            PRINT 'Status "' + ISNULL(@Status, '<NULL>') + '" exists in WorkflowStatus. Using existing status.';

            DECLARE @ExistingDynamicStatusGuid UNIQUEIDENTIFIER;

            SELECT @ExistingDynamicStatusGuid = Guid
            FROM SCore.WorkflowStatus
            WHERE (Name = @Status);					

            -- Ensure visibility flags are up-to-date for this record type
            DECLARE @ShowEnq BIT, @ShowQuo BIT, @ShowJob BIT;

            SELECT 
                @ShowEnq = ShowInEnquiries,
                @ShowQuo = ShowInQuotes,
                @ShowJob = ShowInJobs
            FROM SCore.WorkflowStatus
            WHERE Guid = @ExistingDynamicStatusGuid;

            IF (@RecordTypeName = N'Enquiries' AND ISNULL(@ShowEnq, 0) = 0)
            BEGIN
                UPDATE SCore.WorkflowStatus
                SET ShowInEnquiries = 1
                WHERE Guid = @ExistingDynamicStatusGuid;
            END

            IF (@RecordTypeName = N'Quotes' AND ISNULL(@ShowQuo, 0) = 0)
            BEGIN
                UPDATE SCore.WorkflowStatus
                SET ShowInQuotes = 1
                WHERE Guid = @ExistingDynamicStatusGuid;
            END

            IF (@RecordTypeName = N'Jobs' AND ISNULL(@ShowJob, 0) = 0)
            BEGIN
                UPDATE SCore.WorkflowStatus
                SET ShowInJobs = 1
                WHERE Guid = @ExistingDynamicStatusGuid;
            END

            -- Check if this status is already present for this record
            IF NOT EXISTS
            (
                SELECT 1 
                FROM SCore.DataObjectTransition AS dob
                JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dob.StatusID)
                WHERE 
                    (dob.DataObjectGuid = @RecordGuid) 
                    AND (dob.RowStatus NOT IN (0,254))
                    AND (wfs.Guid = @ExistingDynamicStatusGuid)
            )
            BEGIN
                PRINT 'Status not yet present on record. Determining OldStatusID and NewStatusID (existing status branch).';

                --Get the last status 
                SELECT @OldStatusID = dot1.StatusID
                FROM SCore.DataObjectTransition AS dot1
                WHERE 
                    (dot1.DataObjectGuid = @RecordGuid)
                    AND (dot1.RowStatus NOT IN (0,254))
                    AND (NOT EXISTS
                            (
                                SELECT 1
                                FROM SCore.DataObjectTransition AS dot2
                                WHERE 
                                    (dot2.DataObjectGuid = @RecordGuid)
                                    AND (dot2.RowStatus NOT IN (0,254))
                                    AND (dot2.ID > dot1.ID)
                            )
                        );

                --Get the new status ID
                SELECT @NewStatusID = ID 
                FROM SCore.WorkflowStatus
                WHERE Name = @Status;

                PRINT 'Existing status branch: OldStatusID = ' 
                    + ISNULL(CAST(@OldStatusID AS VARCHAR(20)), '<NULL>')
                    + ', NewStatusID = ' 
                    + ISNULL(CAST(@NewStatusID AS VARCHAR(20)), '<NULL>');

                --Create data object for the status.
                DECLARE @NewTransitionGuid UNIQUEIDENTIFIER = NEWID();

                PRINT 'Calling UpsertDataObject for DataObjectTransition, Guid = ' 
                    + CONVERT(VARCHAR(36), @NewTransitionGuid);

                EXEC SCore.UpsertDataObject
                    @Guid       = @NewTransitionGuid,					
                    @SchemeName = N'SCore',			
                    @ObjectName = N'DataObjectTransition',		
                    @IsInsert   = 1;	-- bit		

                PRINT 'Inserting DataObjectTransition (existing status branch) for RecordGuid = '
                    + CONVERT(VARCHAR(36), @RecordGuid);

                --Save the new status to the data object transition record.
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
                    @NewTransitionGuid,
                    @NewStatusID,
                    @OldStatusID,
                    @Comment,
                    SYSDATETIME(),
                    @CreatedByUserId,
                    -1,
                    @RecordGuid,
                    1
                );
            END
            ELSE
            BEGIN
                PRINT 'Status already present on record. No new DataObjectTransition required.';
            END
        END
        ELSE
        BEGIN
            ------------------------------------------------------------------
            -- WorkflowStatus does NOT exist -> create it first, using type-aware flags
            ------------------------------------------------------------------
            PRINT 'Status "' + ISNULL(@Status, '<NULL>') + '" does NOT exist. Creating new WorkflowStatus.';

            DECLARE @NewStatusGuid UNIQUEIDENTIFIER = NEWID();

            DECLARE @ShowInEnquiries BIT = 0;
            DECLARE @ShowInQuotes    BIT = 0;
            DECLARE @ShowInJobs      BIT = 0;

            IF (@RecordTypeName = N'Enquiries')
            BEGIN
                SET @ShowInEnquiries = 1;
            END
            ELSE IF (@RecordTypeName = N'Quotes')
            BEGIN
                SET @ShowInQuotes = 1;
            END
            ELSE IF (@RecordTypeName = N'Jobs')
            BEGIN
                SET @ShowInJobs = 1;
            END
            ELSE
            BEGIN
                -- Fallback: show everywhere if we don't recognise the type
                SET @ShowInEnquiries = 1;
                SET @ShowInQuotes    = 1;
                SET @ShowInJobs      = 1;
            END

            PRINT 'ShowInEnquiries=' + CAST(@ShowInEnquiries AS VARCHAR(1))
                + ', ShowInQuotes=' + CAST(@ShowInQuotes AS VARCHAR(1))
                + ', ShowInJobs='   + CAST(@ShowInJobs AS VARCHAR(1));

            PRINT 'Calling UpsertDataObject for WorkflowStatus, Guid = '
                + CONVERT(VARCHAR(36), @NewStatusGuid);

            EXEC SCore.UpsertDataObject
                @Guid       = @NewStatusGuid,					
                @SchemeName = N'SCore',			
                @ObjectName = N'WorkflowStatus',		
                @IsInsert   = 1;	-- bit		

            INSERT INTO [SCore].[WorkflowStatus]
            (
                [RowStatus],
                [Guid],
                [OrganisationalUnitId],
                [Name],
                [Description],
                [ShowInEnquiries],
                [ShowInQuotes],
                [ShowInJobs],
                [Enabled],
                [IsPredefined],
                [SortOrder],
                [Colour],
                [Icon],
                [SendNotification],
                [IsCompleteStatus],
                [IsCustomerWaitingStatus],
                [RequiresUsersAction],
                [IsActiveStatus]
            )
            VALUES
            (
                1,                      -- RowStatus
                @NewStatusGuid,         -- Guid
                -1,                     -- OrganisationalUnitId (global)
                @Status,                -- Name
                N'Automatically generated status', -- Description
                @ShowInEnquiries,
                @ShowInQuotes,
                @ShowInJobs,
                1,                      -- Enabled
                1,                      -- IsPredefined
                -1,                     -- SortOrder
                N'#000000',              -- Colour
                N'bi-gear',              -- Icon
                0,                      -- SendNotification
                0,                      -- IsCompleteStatus
                0,                      -- IsCustomerWaitingStatus
                0,                      -- RequiresUsersAction
                1                       -- IsActiveStatus
            );

            --Get the newly created status
            SELECT @NewStatusID = ID
            FROM SCore.WorkflowStatus
            WHERE Guid = @NewStatusGuid;

            --Get the last status 
            SELECT @OldStatusID = dot1.StatusID
            FROM SCore.DataObjectTransition AS dot1
            WHERE 
                (dot1.DataObjectGuid = @RecordGuid)
                AND (dot1.RowStatus NOT IN (0,254))
                AND (NOT EXISTS
                        (
                            SELECT 1
                            FROM SCore.DataObjectTransition AS dot2
                            WHERE 
                                (dot2.DataObjectGuid = @RecordGuid)
                                AND (dot2.RowStatus NOT IN (0,254))
                                AND (dot2.ID > dot1.ID)
                        )
                    );

            PRINT 'New status branch: OldStatusID = ' 
                + ISNULL(CAST(@OldStatusID AS VARCHAR(20)), '<NULL>')
                + ', NewStatusID = ' 
                + ISNULL(CAST(@NewStatusID AS VARCHAR(20)), '<NULL>');

            ---Next, add it to the record
            DECLARE @TransitionGuid UNIQUEIDENTIFIER = NEWID();

            PRINT 'Calling UpsertDataObject for DataObjectTransition, Guid = '
                + CONVERT(VARCHAR(36), @TransitionGuid);

            EXEC SCore.UpsertDataObject
                @Guid       = @TransitionGuid,					
                @SchemeName = N'SCore',			
                @ObjectName = N'DataObjectTransition',		
                @IsInsert   = 1;	-- bit		

            PRINT 'Inserting DataObjectTransition (new status branch) for RecordGuid = '
                + CONVERT(VARCHAR(36), @RecordGuid);

            --Save the new status to the data object transition record.
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
                @TransitionGuid,
                @NewStatusID,
                @OldStatusID,
                @Comment,
                SYSDATETIME(),
                @CreatedByUserId,
                @SurveyorUserID,
                @RecordGuid,
                1
            );
        END;

        ------------------------------------------------------------------
        -- Remove the currently processed record and print remaining
        ------------------------------------------------------------------
        DELETE TOP (1) 
        FROM #RecordsToProcess
        WHERE Guid = @RecordGuid;

        SELECT @Remaining = COUNT(1) FROM #RecordsToProcess;

        PRINT 'Finished record: ' + CONVERT(VARCHAR(36), @RecordGuid)
            + '. Remaining = ' + CAST(@Remaining AS VARCHAR(20));
    END;

    PRINT 'DataObjectTransitionAddCalculatedStatus: Completed.';
END;
GO