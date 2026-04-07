SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromTriggerInstances]')
GO
PRINT (N'Create procedure [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromTriggerInstances]')
GO
PRINT (N'Create procedure [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromTriggerInstances]')
GO

CREATE PROCEDURE [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromTriggerInstances]
(
      @AutomationRunGuid         UNIQUEIDENTIFIER
    , @RequesterUserGuid         UNIQUEIDENTIFIER
    , @DefaultPaymentStatusGuid  UNIQUEIDENTIFIER = NULL
    , @NowUtc                    DATETIME2(7) = NULL
    , @MaxAttempts               INT = 5

    , @CreatedInvoiceRequests    INT = 0 OUTPUT
    , @Attempt                   INT = NULL OUTPUT
    , @CreatedAtUtc              DATETIME2(7) = NULL OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    /* IMPORTANT: do NOT doom the session on error */
    SET XACT_ABORT OFF;

    DECLARE @NowUtcEff DATETIME2(7) = COALESCE(@NowUtc, SYSUTCDATETIME());
    SET @CreatedAtUtc = @NowUtcEff;
    SET @CreatedInvoiceRequests = 0;

    /* Resolve RequesterUserId */
    DECLARE @RequesterUserId INT;
    SELECT @RequesterUserId = i.ID
    FROM SCore.Identities i
    WHERE i.Guid = @RequesterUserGuid;

    IF (@RequesterUserId IS NULL)
    BEGIN
        RAISERROR(N'RequesterUserGuid not found in SCore.Identities.', 16, 1);
        RETURN;
    END

    /* Resolve default payment status ID */
    DECLARE @DefaultPaymentStatusId BIGINT;

    IF (@DefaultPaymentStatusGuid IS NOT NULL)
    BEGIN
        SELECT @DefaultPaymentStatusId = ps.ID
        FROM SFin.InvoicePaymentStatus ps
        WHERE ps.Guid = @DefaultPaymentStatusGuid
          AND ps.RowStatus NOT IN (0,254);
    END
    ELSE
    BEGIN
        SELECT TOP (1) @DefaultPaymentStatusId = ps.ID
        FROM SFin.InvoicePaymentStatus ps
        WHERE ps.RowStatus NOT IN (0,254)
        ORDER BY ps.ID ASC;
    END

    IF (@DefaultPaymentStatusId IS NULL)
    BEGIN
        RAISERROR(N'No active InvoicePaymentStatus row found (and/or DefaultPaymentStatusGuid invalid).', 16, 1);
        RETURN;
    END

    DECLARE @LocalAttempt INT = 0;

    WHILE (1=1)
    BEGIN
        SET @LocalAttempt += 1;
        SET @Attempt = @LocalAttempt;

        BEGIN TRY
            IF OBJECT_ID('tempdb..#Candidates') IS NOT NULL DROP TABLE #Candidates;
            IF OBJECT_ID('tempdb..#ToCreate') IS NOT NULL DROP TABLE #ToCreate;
            IF OBJECT_ID('tempdb..#InsertedRequests') IS NOT NULL DROP TABLE #InsertedRequests;
            IF OBJECT_ID('tempdb..#ItemsToCreate') IS NOT NULL DROP TABLE #ItemsToCreate;

            CREATE TABLE #Candidates
            (
                  InvoiceScheduleId      INT              NOT NULL
                , JobId                 INT              NOT NULL
                , InstanceType          NVARCHAR(50)      NOT NULL
                , InstanceKey           NVARCHAR(200)     NOT NULL
                , TriggerInstanceGuid   UNIQUEIDENTIFIER  NOT NULL
                , CompletedDateTimeUTC  DATETIME2(7)      NULL
                , InvoicingType         NVARCHAR(10)      NOT NULL
            );

            INSERT #Candidates
            (
                  InvoiceScheduleId, JobId, InstanceType, InstanceKey,
                  TriggerInstanceGuid, CompletedDateTimeUTC, InvoicingType
            )
            SELECT
                  d.InvoiceScheduleId
                , d.JobId
                , d.InstanceType
                , d.InstanceKey
                , ti.Guid
                , d.CompletedDateTimeUTC
                , CASE d.InstanceType
                      WHEN N'Activity'  THEN N'ACT'
                      WHEN N'Milestone' THEN N'MS'
                      WHEN N'RIBA'      THEN N'RIBA'
                      ELSE N'UNKNOWN'
                  END
            FROM SFin.tvf_InvoiceAutomation_Phase3Detections() d
            JOIN SFin.InvoiceScheduleTriggerInstances ti
                 ON  ti.InvoiceScheduleId = d.InvoiceScheduleId
                 AND ti.InstanceType      = d.InstanceType
                 AND ti.InstanceKey       = d.InstanceKey
                 AND ti.RowStatus NOT IN (0,254)
            WHERE
                d.CompletedDateTimeUTC IS NOT NULL
                AND d.InstanceType <> N'Percentage';

            IF NOT EXISTS (SELECT 1 FROM #Candidates)
            BEGIN
                SET @CreatedInvoiceRequests = 0;
                RETURN;
            END

            CREATE TABLE #ToCreate
            (
                  InvoiceScheduleId      INT              NOT NULL
                , JobId                 INT              NOT NULL
                , InstanceType          NVARCHAR(50)      NOT NULL
                , InstanceKey           NVARCHAR(200)     NOT NULL
                , TriggerInstanceGuid   UNIQUEIDENTIFIER  NOT NULL
                , CompletedDateTimeUTC  DATETIME2(7)      NULL
                , InvoicingType         NVARCHAR(10)      NOT NULL
                , NewInvoiceRequestGuid UNIQUEIDENTIFIER  NOT NULL
            );

            INSERT #ToCreate
            (
                  InvoiceScheduleId, JobId, InstanceType, InstanceKey,
                  TriggerInstanceGuid, CompletedDateTimeUTC, InvoicingType,
                  NewInvoiceRequestGuid
            )
            SELECT
                  c.InvoiceScheduleId, c.JobId, c.InstanceType, c.InstanceKey,
                  c.TriggerInstanceGuid, c.CompletedDateTimeUTC, c.InvoicingType,
                  NEWID()
            FROM #Candidates c
            WHERE
                c.InvoicingType <> N'UNKNOWN'
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM SFin.InvoiceRequests r
                    WHERE r.RowStatus NOT IN (0,254)
                      AND r.SourceType = N'TriggerInstance'
                      AND r.JobId = c.JobId
                      AND r.SourceGuid = c.TriggerInstanceGuid
                );

            IF NOT EXISTS (SELECT 1 FROM #ToCreate)
            BEGIN
                SET @CreatedInvoiceRequests = 0;
                RETURN;
            END

            CREATE TABLE #InsertedRequests
            (
                  InvoiceRequestId       INT              NOT NULL
                , InvoiceRequestGuid     UNIQUEIDENTIFIER  NOT NULL
                , JobId                  INT              NOT NULL
                , TriggerInstanceGuid    UNIQUEIDENTIFIER  NOT NULL
                , InvoicingType          NVARCHAR(10)      NOT NULL
                , CompletedDateTimeUTC   DATETIME2(7)      NULL
                , InstanceKey            NVARCHAR(200)     NOT NULL
            );

            /* Row-by-row: DataObject then InvoiceRequests insert */
            DECLARE
                  @JobId INT
                , @TrigGuid UNIQUEIDENTIFIER
                , @InstanceKey NVARCHAR(200)
                , @InvType NVARCHAR(10)
                , @Completed DATETIME2(7)
                , @ReqGuid UNIQUEIDENTIFIER;

            DECLARE cur_req CURSOR LOCAL FAST_FORWARD FOR
            SELECT JobId, TriggerInstanceGuid, InstanceKey, InvoicingType, CompletedDateTimeUTC, NewInvoiceRequestGuid
            FROM #ToCreate;

            OPEN cur_req;
            FETCH NEXT FROM cur_req INTO @JobId, @TrigGuid, @InstanceKey, @InvType, @Completed, @ReqGuid;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                /* Re-check under concurrency */
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM SFin.InvoiceRequests r
                    WHERE r.RowStatus NOT IN (0,254)
                      AND r.SourceType = N'TriggerInstance'
                      AND r.JobId = @JobId
                      AND r.SourceGuid = @TrigGuid
                )
                BEGIN
                    DECLARE @WasInsert bit;

                    EXEC SCore.UpsertDataObject
                        @Guid = @ReqGuid,
                        @SchemeName = N'SFin',
                        @ObjectName = N'InvoiceRequests',
                        @IncludeDefaultSecurity = 0,
                        @IsInsert = @WasInsert OUTPUT;

                    INSERT SFin.InvoiceRequests
                    (
                          RowStatus, Guid, Notes, RequesterUserId, CreatedDateTimeUTC,
                          JobId, LegacyId, LegacySystemID,
                          InvoicingType, ExpectedDate, ManualStatus, InvoicePaymentStatusID,
                          IsAutomated, IsZeroValuePlaceholder,
                          ReconciliationRequired, ReconciliationReason,
                          SourceType, SourceGuid, SourceIntId,
                          AutomationRunGuid, InvoiceBatchGuid, BlockedReason
                    )
                    SELECT
                          1, @ReqGuid, N'', @RequesterUserId, @NowUtcEff,
                          @JobId, NULL, -1,
                          @InvType, CAST(COALESCE(@Completed, @NowUtcEff) AS DATE), 0, @DefaultPaymentStatusId,
                          1, 0,
                          0, N'',
                          N'TriggerInstance', @TrigGuid, NULL,
                          @AutomationRunGuid, NULL, N''
                    WHERE NOT EXISTS (SELECT 1 FROM SFin.InvoiceRequests WITH (UPDLOCK, HOLDLOCK) WHERE Guid = @ReqGuid);

                    INSERT #InsertedRequests
                    (InvoiceRequestId, InvoiceRequestGuid, JobId, TriggerInstanceGuid, InvoicingType, CompletedDateTimeUTC, InstanceKey)
                    SELECT r.ID, r.Guid, r.JobId, r.SourceGuid, r.InvoicingType, @Completed, @InstanceKey
                    FROM SFin.InvoiceRequests r
                    WHERE r.Guid = @ReqGuid
                      AND r.RowStatus NOT IN (0,254);
                END

                FETCH NEXT FROM cur_req INTO @JobId, @TrigGuid, @InstanceKey, @InvType, @Completed, @ReqGuid;
            END

            CLOSE cur_req;
            DEALLOCATE cur_req;

            IF NOT EXISTS (SELECT 1 FROM #InsertedRequests)
            BEGIN
                SET @CreatedInvoiceRequests = 0;
                RETURN;
            END

            /* Stage items set-based */
            CREATE TABLE #ItemsToCreate
            (
                  NewItemGuid        UNIQUEIDENTIFIER NOT NULL
                , InvoiceRequestId   INT              NOT NULL
                , MilestoneId        BIGINT           NOT NULL
                , ActivityId         BIGINT           NOT NULL
                , Net                DECIMAL(19,2)    NOT NULL
                , ShortDescription   NVARCHAR(200)    NOT NULL
            );

            /* ACT */
            INSERT #ItemsToCreate (NewItemGuid, InvoiceRequestId, MilestoneId, ActivityId, Net, ShortDescription)
            SELECT
                  NEWID(), ir.InvoiceRequestId,
                  ISNULL(a.MilestoneID, -1),
                  a.ID,
                  CAST(ISNULL(a.InvoicingValue, 0) AS DECIMAL(19,2)),
                  LEFT(ISNULL(NULLIF(a.Title, N''), N'Activity'), 200)
            FROM #InsertedRequests ir
            JOIN SJob.Activities a
              ON a.RowStatus NOT IN (0,254)
             AND a.ID = CASE WHEN ir.InstanceKey LIKE N'ACT:%'
                             THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 5, 200))
                             ELSE NULL END
            WHERE ir.InvoicingType = N'ACT';

            /* MS */
            INSERT #ItemsToCreate (NewItemGuid, InvoiceRequestId, MilestoneId, ActivityId, Net, ShortDescription)
            SELECT
                  NEWID(), ir.InvoiceRequestId,
                  m.ID,
                  a.ID,
                  CAST(ISNULL(a.InvoicingValue, 0) AS DECIMAL(19,2)),
                  LEFT(ISNULL(NULLIF(a.Title, N''), N'Milestone activity'), 200)
            FROM #InsertedRequests ir
            JOIN SJob.Milestones m
              ON m.RowStatus NOT IN (0,254)
             AND m.ID = CASE WHEN ir.InstanceKey LIKE N'MS:%'
                             THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 4, 200))
                             ELSE NULL END
            JOIN SJob.Activities a
              ON a.RowStatus NOT IN (0,254)
             AND a.MilestoneID = m.ID
            JOIN SJob.ActivityTypes t ON t.ID = a.ActivityTypeID
            JOIN SJob.ActivityStatus s ON s.ID = a.ActivityStatusID
            WHERE ir.InvoicingType = N'MS'
              AND t.IsBillable = 1
              AND s.IsCompleteStatus = 1;

            /* RIBA */
            INSERT #ItemsToCreate (NewItemGuid, InvoiceRequestId, MilestoneId, ActivityId, Net, ShortDescription)
            SELECT
                  NEWID(), ir.InvoiceRequestId,
                  ISNULL(a.MilestoneID, -1),
                  a.ID,
                  CAST(ISNULL(a.InvoicingValue, 0) AS DECIMAL(19,2)),
                  LEFT(ISNULL(NULLIF(a.Title, N''), N'RIBA stage activity'), 200)
            FROM #InsertedRequests ir
            JOIN SJob.JobStages js
              ON js.RowStatus NOT IN (0,254)
             AND js.JobID = ir.JobId
             AND js.ID = CASE WHEN ir.InstanceKey LIKE N'RIBA:%'
                              THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 6, 200))
                              ELSE NULL END
            JOIN SJob.Activities a
              ON a.RowStatus NOT IN (0,254)
             AND a.JobID = ir.JobId
             AND a.RibaStageId = js.RIBAStageID
            JOIN SJob.ActivityTypes t ON t.ID = a.ActivityTypeID
            JOIN SJob.ActivityStatus s ON s.ID = a.ActivityStatusID
            WHERE ir.InvoicingType = N'RIBA'
              AND t.IsBillable = 1
              AND s.IsCompleteStatus = 1;

            /* Insert items row-by-row: DataObject then InvoiceRequestItems */
            DECLARE
                  @ItemGuid UNIQUEIDENTIFIER
                , @ReqId INT
                , @MsId BIGINT
                , @ActId BIGINT
                , @Net DECIMAL(19,2)
                , @Desc NVARCHAR(200);

            DECLARE cur_item CURSOR LOCAL FAST_FORWARD FOR
            SELECT NewItemGuid, InvoiceRequestId, MilestoneId, ActivityId, Net, ShortDescription
            FROM #ItemsToCreate;

            OPEN cur_item;
            FETCH NEXT FROM cur_item INTO @ItemGuid, @ReqId, @MsId, @ActId, @Net, @Desc;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                DECLARE @ItemWasInsert bit;

                EXEC SCore.UpsertDataObject
                    @Guid = @ItemGuid,
                    @SchemeName = N'SFin',
                    @ObjectName = N'InvoiceRequestItems',
                    @IncludeDefaultSecurity = 0,
                    @IsInsert = @ItemWasInsert OUTPUT;

                INSERT SFin.InvoiceRequestItems
                (
                      RowStatus, Guid, InvoiceRequestId,
                      MilestoneId, ActivityId, Net,
                      LegacyId, LegacySystemID, ShortDescription
                )
                SELECT
                      1, @ItemGuid, @ReqId,
                      CONVERT(BIGINT, ISNULL(@MsId, -1)),
                      CONVERT(BIGINT, ISNULL(@ActId, -1)),
                      @Net,
                      NULL, -1,
                      LEFT(ISNULL(@Desc, N''), 200)
                WHERE NOT EXISTS (SELECT 1 FROM SFin.InvoiceRequestItems WITH (UPDLOCK, HOLDLOCK) WHERE Guid = @ItemGuid);

                FETCH NEXT FROM cur_item INTO @ItemGuid, @ReqId, @MsId, @ActId, @Net, @Desc;
            END

            CLOSE cur_item;
            DEALLOCATE cur_item;

            SET @CreatedInvoiceRequests = (SELECT COUNT(1) FROM #InsertedRequests);
            RETURN;
        END TRY
        BEGIN CATCH
            DECLARE @ErrNum INT = ERROR_NUMBER();
            DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

            IF (@ErrNum = 1205 AND @LocalAttempt < @MaxAttempts)
            BEGIN
                WAITFOR DELAY '00:00:00.250';
                CONTINUE;
            END

            IF ((@ErrNum IN (2601,2627)) AND @LocalAttempt < @MaxAttempts)
            BEGIN
                WAITFOR DELAY '00:00:00.050';
                CONTINUE;
            END

            RAISERROR(N'CreateInvoiceRequests_FromTriggerInstances failed (%d): %s', 16, 1, @ErrNum, @ErrMsg);
            RETURN;
        END CATCH
    END
END
GO