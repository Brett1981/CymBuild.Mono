SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceRequests_CreateFromTriggerInstances_ForJob]')
GO
PRINT (N'Create procedure [SFin].[InvoiceRequests_CreateFromTriggerInstances_ForJob]')
GO

CREATE PROCEDURE [SFin].[InvoiceRequests_CreateFromTriggerInstances_ForJob]
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
    -- CYB-419: ACT trigger-instance requests use the activity assignee as consultant/requester.
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
        , COALESCE(activityAssignee.ID, @RequesterUserId)
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
     AND a.RowStatus NOT IN (0,254)
    LEFT JOIN SCore.Identities AS activityAssignee
      ON activityAssignee.ID = a.SurveyorID
     AND activityAssignee.RowStatus NOT IN (0,254);

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