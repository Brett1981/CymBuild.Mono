/*
CYB-165 - Activity trigger-instance automated invoice requests should copy Notes
from SJob.Activities.Notes into SFin.InvoiceRequests.Notes.

What this script does
---------------------
1) Retains the existing CYB-165 fix so ACT / MS trigger-instance requests always get at least
   one InvoiceRequestItem, including zero-value placeholders where required.
2) Adds header Notes population for ACT trigger-instance requests:
      SFin.InvoiceRequests.Notes = SJob.Activities.Notes
3) Falls back safely when activity notes are blank / null.
4) Preserves all existing behaviour for non-ACT trigger types.

Important
---------
- This script does NOT backfill existing InvoiceRequests.Notes values.
- It affects new automated trigger-instance InvoiceRequests created after deployment.
- No original item creation behaviour has been removed.
*/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromTriggerInstances]
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
    SET XACT_ABORT OFF;

    DECLARE @NowUtcEff DATETIME2(7) = COALESCE(@NowUtc, SYSUTCDATETIME());
    SET @CreatedAtUtc = @NowUtcEff;
    SET @CreatedInvoiceRequests = 0;

    DECLARE @RequesterUserId INT;
    SELECT @RequesterUserId = i.ID
    FROM SCore.Identities AS i
    WHERE i.Guid = @RequesterUserGuid;

    IF (@RequesterUserId IS NULL)
    BEGIN
        RAISERROR(N'RequesterUserGuid not found in SCore.Identities.', 16, 1);
        RETURN;
    END;

    DECLARE @DefaultPaymentStatusId BIGINT;

    IF (@DefaultPaymentStatusGuid IS NOT NULL)
    BEGIN
        SELECT @DefaultPaymentStatusId = ps.ID
        FROM SFin.InvoicePaymentStatus AS ps
        WHERE ps.Guid = @DefaultPaymentStatusGuid
          AND ps.RowStatus NOT IN (0,254);
    END
    ELSE
    BEGIN
        SELECT TOP (1) @DefaultPaymentStatusId = ps.ID
        FROM SFin.InvoicePaymentStatus AS ps
        WHERE ps.RowStatus NOT IN (0,254)
        ORDER BY ps.ID ASC;
    END;

    IF (@DefaultPaymentStatusId IS NULL)
    BEGIN
        RAISERROR(N'No active InvoicePaymentStatus row found (and/or DefaultPaymentStatusGuid invalid).', 16, 1);
        RETURN;
    END;

    DECLARE @LocalAttempt INT = 0;

    WHILE (1 = 1)
    BEGIN
        SET @LocalAttempt += 1;
        SET @Attempt = @LocalAttempt;

        BEGIN TRY
            IF OBJECT_ID('tempdb..#Candidates') IS NOT NULL DROP TABLE #Candidates;
            IF OBJECT_ID('tempdb..#ToCreate') IS NOT NULL DROP TABLE #ToCreate;
            IF OBJECT_ID('tempdb..#InsertedRequests') IS NOT NULL DROP TABLE #InsertedRequests;
            IF OBJECT_ID('tempdb..#ItemsToCreate') IS NOT NULL DROP TABLE #ItemsToCreate;
            IF OBJECT_ID('tempdb..#ParsedRequests') IS NOT NULL DROP TABLE #ParsedRequests;

            CREATE TABLE #Candidates
            (
                  InvoiceScheduleId      INT               NOT NULL
                , JobId                  INT               NOT NULL
                , InstanceType           NVARCHAR(50)      NOT NULL
                , InstanceKey            NVARCHAR(200)     NOT NULL
                , TriggerInstanceGuid    UNIQUEIDENTIFIER  NOT NULL
                , CompletedDateTimeUTC   DATETIME2(7)      NULL
                , InvoicingType          NVARCHAR(10)      NOT NULL
            );

            INSERT #Candidates
            (
                  InvoiceScheduleId
                , JobId
                , InstanceType
                , InstanceKey
                , TriggerInstanceGuid
                , CompletedDateTimeUTC
                , InvoicingType
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
            FROM SFin.tvf_InvoiceAutomation_Phase3Detections() AS d
            JOIN SFin.InvoiceScheduleTriggerInstances AS ti
              ON ti.InvoiceScheduleId = d.InvoiceScheduleId
             AND ti.InstanceType = d.InstanceType
             AND ti.InstanceKey = d.InstanceKey
             AND ti.RowStatus NOT IN (0,254)
            WHERE d.CompletedDateTimeUTC IS NOT NULL
              AND d.InstanceType <> N'Percentage';

            IF NOT EXISTS (SELECT 1 FROM #Candidates)
            BEGIN
                SET @CreatedInvoiceRequests = 0;
                RETURN;
            END;

            CREATE TABLE #ToCreate
            (
                  InvoiceScheduleId      INT               NOT NULL
                , JobId                  INT               NOT NULL
                , InstanceType           NVARCHAR(50)      NOT NULL
                , InstanceKey            NVARCHAR(200)     NOT NULL
                , TriggerInstanceGuid    UNIQUEIDENTIFIER  NOT NULL
                , CompletedDateTimeUTC   DATETIME2(7)      NULL
                , InvoicingType          NVARCHAR(10)      NOT NULL
                , NewInvoiceRequestGuid  UNIQUEIDENTIFIER  NOT NULL
            );

            INSERT #ToCreate
            (
                  InvoiceScheduleId
                , JobId
                , InstanceType
                , InstanceKey
                , TriggerInstanceGuid
                , CompletedDateTimeUTC
                , InvoicingType
                , NewInvoiceRequestGuid
            )
            SELECT
                  c.InvoiceScheduleId
                , c.JobId
                , c.InstanceType
                , c.InstanceKey
                , c.TriggerInstanceGuid
                , c.CompletedDateTimeUTC
                , c.InvoicingType
                , NEWID()
            FROM #Candidates AS c
            WHERE c.InvoicingType <> N'UNKNOWN'
              AND NOT EXISTS
              (
                    SELECT 1
                    FROM SFin.InvoiceRequests AS r
                    WHERE r.RowStatus NOT IN (0,254)
                      AND r.SourceType = N'TriggerInstance'
                      AND r.JobId = c.JobId
                      AND r.SourceGuid = c.TriggerInstanceGuid
              );

            IF NOT EXISTS (SELECT 1 FROM #ToCreate)
            BEGIN
                SET @CreatedInvoiceRequests = 0;
                RETURN;
            END;

            CREATE TABLE #InsertedRequests
            (
                  InvoiceRequestId       INT               NOT NULL
                , InvoiceRequestGuid     UNIQUEIDENTIFIER  NOT NULL
                , JobId                  INT               NOT NULL
                , TriggerInstanceGuid    UNIQUEIDENTIFIER  NOT NULL
                , InvoicingType          NVARCHAR(10)      NOT NULL
                , CompletedDateTimeUTC   DATETIME2(7)      NULL
                , InstanceKey            NVARCHAR(200)     NOT NULL
            );

            DECLARE
                  @JobId INT
                , @TrigGuid UNIQUEIDENTIFIER
                , @InstanceKey NVARCHAR(200)
                , @InvType NVARCHAR(10)
                , @Completed DATETIME2(7)
                , @ReqGuid UNIQUEIDENTIFIER
                , @RequestNotes NVARCHAR(MAX);

            DECLARE cur_req CURSOR LOCAL FAST_FORWARD FOR
                SELECT JobId, TriggerInstanceGuid, InstanceKey, InvoicingType, CompletedDateTimeUTC, NewInvoiceRequestGuid
                FROM #ToCreate;

            OPEN cur_req;
            FETCH NEXT FROM cur_req INTO @JobId, @TrigGuid, @InstanceKey, @InvType, @Completed, @ReqGuid;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM SFin.InvoiceRequests AS r
                    WHERE r.RowStatus NOT IN (0,254)
                      AND r.SourceType = N'TriggerInstance'
                      AND r.JobId = @JobId
                      AND r.SourceGuid = @TrigGuid
                )
                BEGIN
                    DECLARE @WasInsert BIT;

                    EXEC SCore.UpsertDataObject
                          @Guid = @ReqGuid
                        , @SchemeName = N'SFin'
                        , @ObjectName = N'InvoiceRequests'
                        , @IncludeDefaultSecurity = 0
                        , @IsInsert = @WasInsert OUTPUT;

                    SET @RequestNotes = N'';

                    IF (@InvType = N'ACT')
                    BEGIN
                        SELECT TOP (1)
                            @RequestNotes = NULLIF(LTRIM(RTRIM(a.Notes)), N'')
                        FROM SJob.Activities AS a
                        WHERE a.RowStatus NOT IN (0,254)
                          AND a.ID = CASE
                                        WHEN @InstanceKey LIKE N'ACT:%'
                                            THEN TRY_CONVERT(BIGINT, SUBSTRING(@InstanceKey, 5, 200))
                                        WHEN CHARINDEX(N'|A', @InstanceKey) > 0
                                            THEN TRY_CONVERT(BIGINT, SUBSTRING(@InstanceKey, CHARINDEX(N'|A', @InstanceKey) + 2, 50))
                                        ELSE NULL
                                     END;
                    END;

                    SET @RequestNotes = ISNULL(@RequestNotes, N'');

                    INSERT SFin.InvoiceRequests
                    (
                          RowStatus
                        , Guid
                        , Notes
                        , RequesterUserId
                        , CreatedDateTimeUTC
                        , JobId
                        , LegacyId
                        , LegacySystemID
                        , InvoicingType
                        , ExpectedDate
                        , ManualStatus
                        , InvoicePaymentStatusID
                        , IsAutomated
                        , IsZeroValuePlaceholder
                        , ReconciliationRequired
                        , ReconciliationReason
                        , SourceType
                        , SourceGuid
                        , SourceIntId
                        , AutomationRunGuid
                        , InvoiceBatchGuid
                        , BlockedReason
                    )
                    SELECT
                          1
                        , @ReqGuid
                        , @RequestNotes
                        , @RequesterUserId
                        , @NowUtcEff
                        , @JobId
                        , NULL
                        , -1
                        , @InvType
                        , CAST(COALESCE(@Completed, @NowUtcEff) AS DATE)
                        , 0
                        , @DefaultPaymentStatusId
                        , 1
                        , 0
                        , 0
                        , N''
                        , N'TriggerInstance'
                        , @TrigGuid
                        , NULL
                        , @AutomationRunGuid
                        , NULL
                        , N''
                    WHERE NOT EXISTS
                    (
                        SELECT 1
                        FROM SFin.InvoiceRequests WITH (UPDLOCK, HOLDLOCK)
                        WHERE Guid = @ReqGuid
                    );

                    INSERT #InsertedRequests
                    (
                          InvoiceRequestId
                        , InvoiceRequestGuid
                        , JobId
                        , TriggerInstanceGuid
                        , InvoicingType
                        , CompletedDateTimeUTC
                        , InstanceKey
                    )
                    SELECT
                          r.ID
                        , r.Guid
                        , r.JobId
                        , r.SourceGuid
                        , r.InvoicingType
                        , @Completed
                        , @InstanceKey
                    FROM SFin.InvoiceRequests AS r
                    WHERE r.Guid = @ReqGuid
                      AND r.RowStatus NOT IN (0,254);
                END;

                FETCH NEXT FROM cur_req INTO @JobId, @TrigGuid, @InstanceKey, @InvType, @Completed, @ReqGuid;
            END;

            CLOSE cur_req;
            DEALLOCATE cur_req;

            IF NOT EXISTS (SELECT 1 FROM #InsertedRequests)
            BEGIN
                SET @CreatedInvoiceRequests = 0;
                RETURN;
            END;

            CREATE TABLE #ItemsToCreate
            (
                  NewItemGuid        UNIQUEIDENTIFIER  NOT NULL
                , InvoiceRequestId   INT               NOT NULL
                , MilestoneId        BIGINT            NULL
                , ActivityId         BIGINT            NULL
                , Net                DECIMAL(19,2)     NOT NULL
                , ShortDescription   NVARCHAR(200)     NOT NULL
            );

            INSERT #ItemsToCreate
            (
                  NewItemGuid
                , InvoiceRequestId
                , MilestoneId
                , ActivityId
                , Net
                , ShortDescription
            )
            SELECT
                  NEWID()
                , ir.InvoiceRequestId
                , a.MilestoneID
                , a.ID
                , CAST(ISNULL(a.InvoicingValue, 0) AS DECIMAL(19,2))
                , LEFT(ISNULL(NULLIF(a.Title, N''), N'Activity'), 200)
            FROM #InsertedRequests AS ir
            JOIN SJob.Activities AS a
              ON a.RowStatus NOT IN (0,254)
             AND a.ID = CASE WHEN ir.InstanceKey LIKE N'ACT:%'
                             THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 5, 200))
                             WHEN CHARINDEX(N'|A', ir.InstanceKey) > 0
                                 THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, CHARINDEX(N'|A', ir.InstanceKey) + 2, 50))
                             ELSE NULL END
            WHERE ir.InvoicingType = N'ACT';

            INSERT #ItemsToCreate
            (
                  NewItemGuid
                , InvoiceRequestId
                , MilestoneId
                , ActivityId
                , Net
                , ShortDescription
            )
            SELECT
                  NEWID()
                , ir.InvoiceRequestId
                , m.ID
                , a.ID
                , CAST(ISNULL(a.InvoicingValue, 0) AS DECIMAL(19,2))
                , LEFT(ISNULL(NULLIF(a.Title, N''), N'Milestone activity'), 200)
            FROM #InsertedRequests AS ir
            JOIN SJob.Milestones AS m
              ON m.RowStatus NOT IN (0,254)
             AND m.ID = CASE WHEN ir.InstanceKey LIKE N'MS:%'
                             THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 4, 200))
                             WHEN CHARINDEX(N'|M', ir.InstanceKey) > 0
                                 THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, CHARINDEX(N'|M', ir.InstanceKey) + 2, 50))
                             ELSE NULL END
            JOIN SJob.Activities AS a
              ON a.RowStatus NOT IN (0,254)
             AND a.MilestoneID = m.ID
            JOIN SJob.ActivityTypes AS t
              ON t.ID = a.ActivityTypeID
            JOIN SJob.ActivityStatus AS s
              ON s.ID = a.ActivityStatusID
            WHERE ir.InvoicingType = N'MS'
              AND t.IsBillable = 1
              AND s.IsCompleteStatus = 1;

            INSERT #ItemsToCreate
            (
                  NewItemGuid
                , InvoiceRequestId
                , MilestoneId
                , ActivityId
                , Net
                , ShortDescription
            )
            SELECT
                  NEWID()
                , ir.InvoiceRequestId
                , a.MilestoneID
                , a.ID
                , CAST(ISNULL(a.InvoicingValue, 0) AS DECIMAL(19,2))
                , LEFT(ISNULL(NULLIF(a.Title, N''), N'RIBA stage activity'), 200)
            FROM #InsertedRequests AS ir
            JOIN SJob.JobStages AS js
              ON js.RowStatus NOT IN (0,254)
             AND js.JobID = ir.JobId
             AND js.ID = CASE WHEN ir.InstanceKey LIKE N'RIBA:%'
                              THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 6, 200))
                              ELSE NULL END
            JOIN SJob.Activities AS a
              ON a.RowStatus NOT IN (0,254)
             AND a.JobID = ir.JobId
             AND a.RibaStageId = js.RIBAStageID
            JOIN SJob.ActivityTypes AS t
              ON t.ID = a.ActivityTypeID
            JOIN SJob.ActivityStatus AS s
              ON s.ID = a.ActivityStatusID
            WHERE ir.InvoicingType = N'RIBA'
              AND t.IsBillable = 1
              AND s.IsCompleteStatus = 1;

            SELECT
                  ir.InvoiceRequestId
                , ir.InvoicingType
                , ir.InstanceKey
                , ParsedActivityId = CASE
                                        WHEN ir.InvoicingType = N'ACT' AND ir.InstanceKey LIKE N'ACT:%'
                                            THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 5, 200))
                                        WHEN ir.InvoicingType = N'ACT' AND CHARINDEX(N'|A', ir.InstanceKey) > 0
                                            THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, CHARINDEX(N'|A', ir.InstanceKey) + 2, 50))
                                        ELSE NULL
                                     END
                , ParsedMilestoneId = CASE
                                         WHEN ir.InvoicingType = N'MS' AND ir.InstanceKey LIKE N'MS:%'
                                             THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 4, 200))
                                         WHEN ir.InvoicingType = N'MS' AND CHARINDEX(N'|M', ir.InstanceKey) > 0
                                             THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, CHARINDEX(N'|M', ir.InstanceKey) + 2, 50))
                                         ELSE NULL
                                      END
            INTO #ParsedRequests
            FROM #InsertedRequests AS ir
            WHERE ir.InvoicingType IN (N'ACT', N'MS');

            INSERT #ItemsToCreate
            (
                  NewItemGuid
                , InvoiceRequestId
                , MilestoneId
                , ActivityId
                , Net
                , ShortDescription
            )
            SELECT
                  NEWID()
                , pr.InvoiceRequestId
                , CASE WHEN pr.InvoicingType = N'MS' THEN m.ID ELSE a.MilestoneID END
                , CASE WHEN pr.InvoicingType = N'ACT' THEN a.ID ELSE NULL END
                , CAST(0 AS DECIMAL(19,2))
                , LEFT(
                    CASE
                        WHEN pr.InvoicingType = N'ACT' THEN ISNULL(NULLIF(a.Title, N''), N'Activity')
                        WHEN pr.InvoicingType = N'MS'  THEN ISNULL(NULLIF(m.Description, N''), N'Milestone')
                        ELSE N'Invoice item'
                    END,
                    200
                  )
            FROM #ParsedRequests AS pr
            LEFT JOIN SJob.Activities AS a
              ON a.ID = pr.ParsedActivityId
             AND a.RowStatus NOT IN (0,254)
            LEFT JOIN SJob.Milestones AS m
              ON m.ID = pr.ParsedMilestoneId
             AND m.RowStatus NOT IN (0,254)
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM #ItemsToCreate AS itc
                WHERE itc.InvoiceRequestId = pr.InvoiceRequestId
            );

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
                DECLARE @ItemWasInsert BIT;

                EXEC SCore.UpsertDataObject
                      @Guid = @ItemGuid
                    , @SchemeName = N'SFin'
                    , @ObjectName = N'InvoiceRequestItems'
                    , @IncludeDefaultSecurity = 0
                    , @IsInsert = @ItemWasInsert OUTPUT;

                INSERT SFin.InvoiceRequestItems
                (
                      RowStatus
                    , Guid
                    , InvoiceRequestId
                    , MilestoneId
                    , ActivityId
                    , Net
                    , LegacyId
                    , LegacySystemID
                    , ShortDescription
                )
                SELECT
                      1
                    , @ItemGuid
                    , @ReqId
                    , @MsId
                    , @ActId
                    , @Net
                    , NULL
                    , -1
                    , LEFT(ISNULL(@Desc, N''), 200)
                WHERE NOT EXISTS
                (
                    SELECT 1
                    FROM SFin.InvoiceRequestItems WITH (UPDLOCK, HOLDLOCK)
                    WHERE Guid = @ItemGuid
                );

                FETCH NEXT FROM cur_item INTO @ItemGuid, @ReqId, @MsId, @ActId, @Net, @Desc;
            END;

            CLOSE cur_item;
            DEALLOCATE cur_item;

            ;WITH R AS
            (
                SELECT r.ID
                FROM SFin.InvoiceRequests AS r
                WHERE r.RowStatus NOT IN (0,254)
                  AND r.SourceType = N'TriggerInstance'
                  AND r.AutomationRunGuid = @AutomationRunGuid
                  AND r.InvoicingType IN (N'ACT', N'MS')
            ),
            Totals AS
            (
                SELECT
                      r.ID
                    , TotalNet = ISNULL(SUM(iri.Net), 0)
                    , ItemCount = COUNT(iri.ID)
                FROM R AS r
                LEFT JOIN SFin.InvoiceRequestItems AS iri
                  ON iri.InvoiceRequestId = r.ID
                 AND iri.RowStatus NOT IN (0,254)
                GROUP BY r.ID
            )
            UPDATE r
               SET r.IsZeroValuePlaceholder = CASE WHEN t.TotalNet = 0 THEN 1 ELSE 0 END
                 , r.ReconciliationRequired = CASE WHEN t.TotalNet = 0 THEN 1 ELSE 0 END
                 , r.ReconciliationReason = CASE WHEN t.TotalNet = 0 THEN N'Items derived but value is zero' ELSE N'' END
            FROM SFin.InvoiceRequests AS r
            JOIN Totals AS t
              ON t.ID = r.ID;

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
            END;

            IF (@ErrNum IN (2601,2627) AND @LocalAttempt < @MaxAttempts)
            BEGIN
                WAITFOR DELAY '00:00:00.050';
                CONTINUE;
            END;

            RAISERROR(N'CreateInvoiceRequests_FromTriggerInstances failed (%d): %s', 16, 1, @ErrNum, @ErrMsg);
            RETURN;
        END CATCH;
    END;
END;
GO

ALTER PROCEDURE [SFin].[InvoiceRequests_CreateFromTriggerInstances_ForJob]
(
      @JobGuid                       UNIQUEIDENTIFIER
    , @AutomationRunGuid             UNIQUEIDENTIFIER = NULL
    , @InvoiceBatchGuid              UNIQUEIDENTIFIER = NULL
    , @RequesterUserId               INT
    , @DefaultInvoicePaymentStatusId BIGINT
    , @OverrideBlocking              BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @JobId INT;

    SELECT TOP (1) @JobId = j.ID
    FROM SJob.Jobs AS j
    WHERE j.Guid = @JobGuid
      AND j.RowStatus NOT IN (0,254);

    IF (@JobId IS NULL)
        THROW 60021, N'Job not found (or inactive).', 1;

    BEGIN TRAN;

    ;WITH ScheduleJobScope AS
    (
        SELECT DISTINCT
              qi.InvoicingSchedule AS InvoiceScheduleId
            , qi.CreatedJobId      AS JobId
        FROM SSop.QuoteItems AS qi
        WHERE qi.RowStatus NOT IN (0,254)
          AND qi.CreatedJobId = @JobId
          AND qi.CreatedJobId NOT IN (-1,0)
          AND qi.InvoicingSchedule NOT IN (-1,0)
    ),
    Blocking AS
    (
        SELECT
              sjs.InvoiceScheduleId
            , sjs.JobId
            , j.ManualInvoicingEnabled
            , ISNULL(acs.IsHold, 0) AS AccountIsOnHold
            , CASE
                  WHEN ISNULL(j.ManualInvoicingEnabled, 0) = 1 THEN 1
                  WHEN ISNULL(acs.IsHold, 0) = 1 THEN 1
                  ELSE 0
              END AS IsBlocked
        FROM ScheduleJobScope AS sjs
        JOIN SJob.Jobs AS j
          ON j.ID = sjs.JobId
         AND j.RowStatus NOT IN (0,254)
        LEFT JOIN SCrm.Accounts AS a
          ON a.ID = j.FinanceAccountID
        LEFT JOIN SCrm.AccountStatus AS acs
          ON acs.ID = a.AccountStatusID
    ),
    Candidate AS
    (
        SELECT
              b.InvoiceScheduleId
            , b.JobId
            , ti.Guid AS TriggerInstanceGuid
            , ti.InstanceType
            , ti.InstanceKey
            , ti.CompletedDateTimeUTC
        FROM Blocking AS b
        JOIN SFin.InvoiceScheduleTriggerInstances AS ti
          ON ti.InvoiceScheduleId = b.InvoiceScheduleId
         AND ti.RowStatus NOT IN (0,254)
        WHERE ti.CompletedDateTimeUTC IS NOT NULL
          AND (@OverrideBlocking = 1 OR b.IsBlocked = 0)
    ),
    ToCreate AS
    (
        SELECT c.*
        FROM Candidate AS c
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceRequests AS r
            WHERE r.RowStatus NOT IN (0,254)
              AND r.JobId = c.JobId
              AND r.SourceType = N'TriggerInstance'
              AND r.SourceGuid = c.TriggerInstanceGuid
        )
    ),
    ToInsert AS
    (
        SELECT
              t.*
            , CASE
                  WHEN t.InstanceType = N'Activity'   THEN N'ACT'
                  WHEN t.InstanceType = N'Milestone'  THEN N'MS'
                  WHEN t.InstanceType = N'RIBA'       THEN N'RIBA'
                  WHEN t.InstanceType = N'Percentage' THEN N'PCT'
                  WHEN t.InstanceType = N'Monthly'    THEN N'MON'
                  ELSE N''
              END AS InvoicingType
            , CASE
                  WHEN t.InstanceType = N'Activity' AND t.InstanceKey LIKE N'ACT:%'
                      THEN TRY_CONVERT(BIGINT, SUBSTRING(t.InstanceKey, 5, 200))
                  WHEN t.InstanceType = N'Activity' AND CHARINDEX(N'|A', t.InstanceKey) > 0
                      THEN TRY_CONVERT(BIGINT, SUBSTRING(t.InstanceKey, CHARINDEX(N'|A', t.InstanceKey) + 2, 50))
                  ELSE NULL
              END AS ParsedActivityId
        FROM ToCreate AS t
    )
    INSERT SFin.InvoiceRequests
    (
          RowStatus
        , Notes
        , RequesterUserId
        , CreatedDateTimeUTC
        , JobId
        , InvoicingType
        , ExpectedDate
        , ManualStatus
        , InvoicePaymentStatusID
        , IsAutomated
        , IsZeroValuePlaceholder
        , ReconciliationRequired
        , ReconciliationReason
        , SourceType
        , SourceGuid
        , SourceIntId
        , AutomationRunGuid
        , InvoiceBatchGuid
        , BlockedReason
    )
    SELECT
          1
        , CASE
              WHEN i.InvoicingType = N'ACT'
                   THEN ISNULL(NULLIF(LTRIM(RTRIM(a.Notes)), N''),
                               CONCAT(N'Created from TriggerInstance. InstanceType=', i.InstanceType, N', InstanceKey=', i.InstanceKey))
              ELSE CONCAT(N'Created from TriggerInstance. InstanceType=', i.InstanceType, N', InstanceKey=', i.InstanceKey)
          END
        , @RequesterUserId
        , SYSUTCDATETIME()
        , i.JobId
        , i.InvoicingType
        , CAST(i.CompletedDateTimeUTC AS DATE)
        , 0
        , @DefaultInvoicePaymentStatusId
        , 1
        , 0
        , 0
        , N''
        , N'TriggerInstance'
        , i.TriggerInstanceGuid
        , NULL
        , @AutomationRunGuid
        , @InvoiceBatchGuid
        , CASE WHEN @OverrideBlocking = 1 THEN N'OVERRIDE_BLOCKING' ELSE N'' END
    FROM ToInsert AS i
    LEFT JOIN SJob.Activities AS a
      ON a.ID = i.ParsedActivityId
     AND a.RowStatus NOT IN (0,254);

    IF OBJECT_ID('tempdb..#ItemSeed') IS NOT NULL DROP TABLE #ItemSeed;

    CREATE TABLE #ItemSeed
    (
          ItemGuid          UNIQUEIDENTIFIER NOT NULL
        , InvoiceRequestId  INT              NOT NULL
        , MilestoneId       BIGINT           NULL
        , ActivityId        BIGINT           NULL
        , Net               DECIMAL(19,2)    NOT NULL
        , ShortDescription  NVARCHAR(200)    NOT NULL
    );

    ;WITH NewReq AS
    (
        SELECT
              r.ID AS InvoiceRequestId
            , r.JobId
            , r.SourceGuid
            , r.InvoicingType
        FROM SFin.InvoiceRequests AS r
        WHERE r.RowStatus NOT IN (0,254)
          AND r.SourceType = N'TriggerInstance'
          AND r.JobId = @JobId
          AND (@AutomationRunGuid IS NULL OR r.AutomationRunGuid = @AutomationRunGuid)
    ),
    ReqWithTi AS
    (
        SELECT
              nr.InvoiceRequestId
            , nr.JobId
            , nr.InvoicingType
            , ti.InstanceKey
        FROM NewReq AS nr
        JOIN SFin.InvoiceScheduleTriggerInstances AS ti
          ON ti.Guid = nr.SourceGuid
         AND ti.RowStatus NOT IN (0,254)
    ),
    Parsed AS
    (
        SELECT
              r.*
            , ActivityId = CASE
                              WHEN r.InvoicingType = N'ACT' AND CHARINDEX(N'|A', r.InstanceKey) > 0
                                  THEN TRY_CONVERT(BIGINT, SUBSTRING(r.InstanceKey, CHARINDEX(N'|A', r.InstanceKey) + 2, 50))
                              WHEN r.InvoicingType = N'ACT' AND CHARINDEX(N'ACT:', r.InstanceKey) > 0
                                  THEN TRY_CONVERT(BIGINT, SUBSTRING(r.InstanceKey, CHARINDEX(N'ACT:', r.InstanceKey) + 4, 50))
                              ELSE NULL
                           END
            , MilestoneId = CASE
                               WHEN r.InvoicingType = N'MS' AND CHARINDEX(N'|M', r.InstanceKey) > 0
                                   THEN TRY_CONVERT(BIGINT, SUBSTRING(r.InstanceKey, CHARINDEX(N'|M', r.InstanceKey) + 2, 50))
                               WHEN r.InvoicingType = N'MS' AND CHARINDEX(N'MS:', r.InstanceKey) > 0
                                   THEN TRY_CONVERT(BIGINT, SUBSTRING(r.InstanceKey, CHARINDEX(N'MS:', r.InstanceKey) + 3, 50))
                               ELSE NULL
                            END
        FROM ReqWithTi AS r
    )
    INSERT #ItemSeed
    (
          ItemGuid
        , InvoiceRequestId
        , MilestoneId
        , ActivityId
        , Net
        , ShortDescription
    )
    SELECT
          NEWID()
        , p.InvoiceRequestId
        , CASE WHEN p.InvoicingType = N'MS' THEN m.ID ELSE a.MilestoneID END
        , CASE WHEN p.InvoicingType = N'ACT' THEN a.ID ELSE NULL END
        , CAST(COALESCE(a.InvoicingValue, 0) AS DECIMAL(19,2))
        , LEFT(
            CASE
                WHEN p.InvoicingType = N'ACT' THEN COALESCE(a.Title, N'Activity')
                WHEN p.InvoicingType = N'MS'  THEN COALESCE(m.Description, N'Milestone')
                ELSE N''
            END,
            200
          )
    FROM Parsed AS p
    LEFT JOIN SJob.Activities AS a
      ON a.ID = p.ActivityId
     AND a.RowStatus NOT IN (0,254)
    LEFT JOIN SJob.Milestones AS m
      ON m.ID = p.MilestoneId
     AND m.RowStatus NOT IN (0,254)
    WHERE p.InvoicingType IN (N'ACT', N'MS')
      AND (
            (p.InvoicingType = N'ACT' AND a.ID IS NOT NULL)
         OR (p.InvoicingType = N'MS'  AND m.ID IS NOT NULL)
      );

    ;WITH Req AS
    (
        SELECT
              r.ID AS InvoiceRequestId
            , r.InvoicingType
            , ti.InstanceKey
        FROM SFin.InvoiceRequests AS r
        JOIN SFin.InvoiceScheduleTriggerInstances AS ti
          ON ti.Guid = r.SourceGuid
         AND ti.RowStatus NOT IN (0,254)
        WHERE r.RowStatus NOT IN (0,254)
          AND r.SourceType = N'TriggerInstance'
          AND r.JobId = @JobId
          AND r.InvoicingType IN (N'ACT', N'MS')
          AND (@AutomationRunGuid IS NULL OR r.AutomationRunGuid = @AutomationRunGuid)
    ),
    ParsedReq AS
    (
        SELECT
              r.InvoiceRequestId
            , r.InvoicingType
            , ParsedActivityId = CASE
                                    WHEN r.InvoicingType = N'ACT' AND r.InstanceKey LIKE N'ACT:%'
                                        THEN TRY_CONVERT(BIGINT, SUBSTRING(r.InstanceKey, 5, 200))
                                    WHEN r.InvoicingType = N'ACT' AND CHARINDEX(N'|A', r.InstanceKey) > 0
                                        THEN TRY_CONVERT(BIGINT, SUBSTRING(r.InstanceKey, CHARINDEX(N'|A', r.InstanceKey) + 2, 50))
                                    ELSE NULL
                                 END
            , ParsedMilestoneId = CASE
                                     WHEN r.InvoicingType = N'MS' AND r.InstanceKey LIKE N'MS:%'
                                         THEN TRY_CONVERT(BIGINT, SUBSTRING(r.InstanceKey, 4, 200))
                                     WHEN r.InvoicingType = N'MS' AND CHARINDEX(N'|M', r.InstanceKey) > 0
                                         THEN TRY_CONVERT(BIGINT, SUBSTRING(r.InstanceKey, CHARINDEX(N'|M', r.InstanceKey) + 2, 50))
                                     ELSE NULL
                                  END
        FROM Req AS r
    )
    INSERT #ItemSeed
    (
          ItemGuid
        , InvoiceRequestId
        , MilestoneId
        , ActivityId
        , Net
        , ShortDescription
    )
    SELECT
          NEWID()
        , pr.InvoiceRequestId
        , CASE WHEN pr.InvoicingType = N'MS' THEN m.ID ELSE a.MilestoneID END
        , CASE WHEN pr.InvoicingType = N'ACT' THEN a.ID ELSE NULL END
        , CAST(0 AS DECIMAL(19,2))
        , LEFT(
            CASE
                WHEN pr.InvoicingType = N'ACT' THEN ISNULL(NULLIF(a.Title, N''), N'Activity')
                WHEN pr.InvoicingType = N'MS'  THEN ISNULL(NULLIF(m.Description, N''), N'Milestone')
                ELSE N'Invoice item'
            END,
            200
          )
    FROM ParsedReq AS pr
    LEFT JOIN SJob.Activities AS a
      ON a.ID = pr.ParsedActivityId
     AND a.RowStatus NOT IN (0,254)
    LEFT JOIN SJob.Milestones AS m
      ON m.ID = pr.ParsedMilestoneId
     AND m.RowStatus NOT IN (0,254)
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM #ItemSeed AS s
        WHERE s.InvoiceRequestId = pr.InvoiceRequestId
    );

    DECLARE
          @ItemGuid UNIQUEIDENTIFIER
        , @InvoiceRequestId INT
        , @MilestoneId BIGINT
        , @ActivityId BIGINT
        , @Net DECIMAL(19,2)
        , @ShortDescription NVARCHAR(200)
        , @ItemWasInsert BIT;

    DECLARE cur_item CURSOR LOCAL FAST_FORWARD FOR
        SELECT ItemGuid, InvoiceRequestId, MilestoneId, ActivityId, Net, ShortDescription
        FROM #ItemSeed;

    OPEN cur_item;
    FETCH NEXT FROM cur_item INTO @ItemGuid, @InvoiceRequestId, @MilestoneId, @ActivityId, @Net, @ShortDescription;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject
              @Guid = @ItemGuid
            , @SchemeName = N'SFin'
            , @ObjectName = N'InvoiceRequestItems'
            , @IncludeDefaultSecurity = 0
            , @IsInsert = @ItemWasInsert OUTPUT;

        INSERT SFin.InvoiceRequestItems
        (
              RowStatus
            , Guid
            , InvoiceRequestId
            , MilestoneId
            , ActivityId
            , Net
            , LegacySystemID
            , ShortDescription
        )
        SELECT
              1
            , @ItemGuid
            , @InvoiceRequestId
            , @MilestoneId
            , @ActivityId
            , @Net
            , -1
            , @ShortDescription
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceRequestItems AS iri
            WHERE iri.Guid = @ItemGuid
        );

        FETCH NEXT FROM cur_item INTO @ItemGuid, @InvoiceRequestId, @MilestoneId, @ActivityId, @Net, @ShortDescription;
    END;

    CLOSE cur_item;
    DEALLOCATE cur_item;

    ;WITH R AS
    (
        SELECT r.ID
        FROM SFin.InvoiceRequests AS r
        WHERE r.RowStatus NOT IN (0,254)
          AND r.SourceType = N'TriggerInstance'
          AND r.JobId = @JobId
          AND r.InvoicingType IN (N'ACT', N'MS')
          AND (@AutomationRunGuid IS NULL OR r.AutomationRunGuid = @AutomationRunGuid)
    ),
    Totals AS
    (
        SELECT
              r.ID
            , TotalNet = ISNULL(SUM(iri.Net), 0)
            , ItemCount = COUNT(iri.ID)
        FROM R AS r
        LEFT JOIN SFin.InvoiceRequestItems AS iri
          ON iri.InvoiceRequestId = r.ID
         AND iri.RowStatus NOT IN (0,254)
        GROUP BY r.ID
    )
    UPDATE r
       SET r.IsZeroValuePlaceholder = CASE WHEN t.TotalNet = 0 THEN 1 ELSE 0 END
         , r.ReconciliationRequired = CASE WHEN t.TotalNet = 0 THEN 1 ELSE 0 END
         , r.ReconciliationReason = CASE WHEN t.TotalNet = 0 THEN N'Items derived but value is zero' ELSE N'' END
    FROM SFin.InvoiceRequests AS r
    JOIN Totals AS t
      ON t.ID = r.ID;

    COMMIT;
END;
GO