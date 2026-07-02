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
    SET XACT_ABORT OFF;

    DECLARE @NowUtcEff DATETIME2(7) = COALESCE(@NowUtc, SYSUTCDATETIME());

    SET @CreatedAtUtc = @NowUtcEff;
    SET @CreatedInvoiceRequests = 0;

    DECLARE @RequesterUserId INT;

    SELECT
        @RequesterUserId = i.ID
    FROM SCore.Identities AS i
    WHERE i.Guid = @RequesterUserGuid
      AND i.RowStatus NOT IN (0,254);

    IF (@RequesterUserId IS NULL)
    BEGIN
        RAISERROR(N'RequesterUserGuid not found in SCore.Identities.', 16, 1);
        RETURN;
    END;

    DECLARE @DefaultPaymentStatusId BIGINT;

    IF (@DefaultPaymentStatusGuid IS NOT NULL)
    BEGIN
        SELECT
            @DefaultPaymentStatusId = ps.ID
        FROM SFin.InvoicePaymentStatus AS ps
        WHERE ps.Guid = @DefaultPaymentStatusGuid
          AND ps.RowStatus NOT IN (0,254);
    END
    ELSE
    BEGIN
        SELECT TOP (1)
            @DefaultPaymentStatusId = ps.ID
        FROM SFin.InvoicePaymentStatus AS ps
        WHERE ps.RowStatus NOT IN (0,254)
        ORDER BY ps.ID ASC;
    END;

    IF (@DefaultPaymentStatusId IS NULL)
    BEGIN
        RAISERROR(N'No active InvoicePaymentStatus row found.', 16, 1);
        RETURN;
    END;

    DECLARE @LocalAttempt INT = 0;

    WHILE (1 = 1)
    BEGIN
        SET @LocalAttempt += 1;
        SET @Attempt = @LocalAttempt;

        BEGIN TRY
            IF OBJECT_ID(N'tempdb..#Candidates') IS NOT NULL DROP TABLE #Candidates;
            IF OBJECT_ID(N'tempdb..#ToCreate') IS NOT NULL DROP TABLE #ToCreate;
            IF OBJECT_ID(N'tempdb..#InsertedRequests') IS NOT NULL DROP TABLE #InsertedRequests;
            IF OBJECT_ID(N'tempdb..#ItemsToCreate') IS NOT NULL DROP TABLE #ItemsToCreate;

            CREATE TABLE #Candidates
            (
                  InvoiceScheduleId      INT              NOT NULL
                , JobId                  INT              NOT NULL
                , InstanceType           NVARCHAR(50)     NOT NULL
                , InstanceKey            NVARCHAR(200)    NOT NULL
                , TriggerInstanceGuid    UNIQUEIDENTIFIER NOT NULL
                , CompletedDateTimeUTC   DATETIME2(7)     NULL
                , InvoicingType          NVARCHAR(10)     NOT NULL
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

            -- CYB-419: for Activity trigger instances the InvoiceRequest RequesterUserId
            -- must be the activity assignee (SJob.Activities.SurveyorID), not the
            -- automation/service account running the batch.
            CREATE TABLE #ToCreate
            (
                  InvoiceScheduleId      INT              NOT NULL
                , JobId                  INT              NOT NULL
                , InstanceType           NVARCHAR(50)     NOT NULL
                , InstanceKey            NVARCHAR(200)    NOT NULL
                , TriggerInstanceGuid    UNIQUEIDENTIFIER NOT NULL
                , CompletedDateTimeUTC   DATETIME2(7)     NULL
                , InvoicingType          NVARCHAR(10)     NOT NULL
                , NewInvoiceRequestGuid  UNIQUEIDENTIFIER NOT NULL
                , RequesterUserId        INT              NOT NULL
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
                , RequesterUserId
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
                , COALESCE(activityAssignee.ID, @RequesterUserId)
            FROM #Candidates AS c
            LEFT JOIN SJob.Activities AS activityAssigneeSource
                ON activityAssigneeSource.RowStatus NOT IN (0,254)
               AND c.InvoicingType = N'ACT'
               AND activityAssigneeSource.ID =
                   CASE
                       WHEN c.InstanceKey LIKE N'ACT:%'
                           THEN TRY_CONVERT(BIGINT, SUBSTRING(c.InstanceKey, 5, 200))
                       WHEN CHARINDEX(N'|A', c.InstanceKey) > 0
                           THEN TRY_CONVERT(BIGINT, SUBSTRING(c.InstanceKey, CHARINDEX(N'|A', c.InstanceKey) + 2, 50))
                       ELSE NULL
                   END
            LEFT JOIN SCore.Identities AS activityAssignee
                ON activityAssignee.ID = activityAssigneeSource.SurveyorID
               AND activityAssignee.RowStatus NOT IN (0,254)
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
                  InvoiceRequestId       INT              NOT NULL
                , InvoiceRequestGuid     UNIQUEIDENTIFIER NOT NULL
                , JobId                  INT              NOT NULL
                , TriggerInstanceGuid    UNIQUEIDENTIFIER NOT NULL
                , InvoicingType          NVARCHAR(10)     NOT NULL
                , CompletedDateTimeUTC   DATETIME2(7)     NULL
                , InstanceKey            NVARCHAR(200)    NOT NULL
            );

            DECLARE
                  @JobId INT
                , @TrigGuid UNIQUEIDENTIFIER
                , @InstanceKey NVARCHAR(200)
                , @InvType NVARCHAR(10)
                , @Completed DATETIME2(7)
                , @ReqGuid UNIQUEIDENTIFIER
                , @RequestNotes NVARCHAR(MAX)
                , @RequestRequesterUserId INT;

            DECLARE cur_req CURSOR LOCAL FAST_FORWARD FOR
                SELECT
                      tc.JobId
                    , tc.TriggerInstanceGuid
                    , tc.InstanceKey
                    , tc.InvoicingType
                    , tc.CompletedDateTimeUTC
                    , tc.NewInvoiceRequestGuid
                    , tc.RequesterUserId
                FROM #ToCreate AS tc;

            OPEN cur_req;

            FETCH NEXT FROM cur_req
            INTO @JobId, @TrigGuid, @InstanceKey, @InvType, @Completed, @ReqGuid, @RequestRequesterUserId;

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
                          AND a.ID =
                              CASE
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
                        , @RequestRequesterUserId
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

                FETCH NEXT FROM cur_req
                INTO @JobId, @TrigGuid, @InstanceKey, @InvType, @Completed, @ReqGuid, @RequestRequesterUserId;
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
                  NewItemGuid            UNIQUEIDENTIFIER NOT NULL
                , InvoiceRequestId       INT              NOT NULL
                , MilestoneId            BIGINT           NULL
                , ActivityId             BIGINT           NULL
                , Net                    DECIMAL(19,2)    NOT NULL
                , ShortDescription       NVARCHAR(200)    NOT NULL
                , RIBAStageId            INT              NULL
                , ValueDerivationReason  NVARCHAR(200)    NOT NULL
            );

            ------------------------------------------------------------------
            -- Activity items
            ------------------------------------------------------------------
            INSERT #ItemsToCreate
            (
                  NewItemGuid
                , InvoiceRequestId
                , MilestoneId
                , ActivityId
                , Net
                , ShortDescription
                , RIBAStageId
                , ValueDerivationReason
            )
            SELECT
                  NEWID()
                , ir.InvoiceRequestId
                , a.MilestoneID
                , a.ID
                , CAST
                  (
                      CASE
                          WHEN ISNULL(a.InvoicingQuantity, 0.00) = 0.00
                              THEN ISNULL(a.InvoicingValue, 0.00)
                          ELSE
                              ISNULL(a.InvoicingQuantity, 0.00)
                              * CASE
                                    WHEN ISNULL(a.InvoicingValue, 0.00) = 0.00 THEN 1.00
                                    ELSE a.InvoicingValue
                                END
                      END
                      AS DECIMAL(19,2)
                  )
                , LEFT(ISNULL(NULLIF(a.Title, N''), N'Activity'), 200)
                , NULL
                , CASE
                      WHEN ISNULL(a.InvoicingQuantity, 0.00) = 0.00
                       AND ISNULL(a.InvoicingValue, 0.00) = 0.00
                          THEN N'Activity item created but value could not be determined because quantity and value are both zero.'
                      ELSE N''
                  END
            FROM #InsertedRequests AS ir
            JOIN SJob.Activities AS a
                ON a.RowStatus NOT IN (0,254)
               AND a.ID =
                   CASE
                       WHEN ir.InstanceKey LIKE N'ACT:%'
                           THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 5, 200))
                       WHEN CHARINDEX(N'|A', ir.InstanceKey) > 0
                           THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, CHARINDEX(N'|A', ir.InstanceKey) + 2, 50))
                       ELSE NULL
                   END
            WHERE ir.InvoicingType = N'ACT';

            ------------------------------------------------------------------
            -- Milestone items
            -- Uses Job.SurveyorID -> Identities.BillableRate.
            -- If QuotedHours exist, use QuotedHours * rate.
            -- Otherwise fall back to QuoteItem.Net.
            ------------------------------------------------------------------
            INSERT #ItemsToCreate
            (
                  NewItemGuid
                , InvoiceRequestId
                , MilestoneId
                , ActivityId
                , Net
                , ShortDescription
                , RIBAStageId
                , ValueDerivationReason
            )
            SELECT
                  NEWID()
                , ir.InvoiceRequestId
                , m.ID
                , NULL
                , CAST
                  (
                      CASE
                          WHEN ISNULL(m.QuotedHours, 0.00) > 0.00
                                THEN ISNULL(m.QuotedHours, 0.00) * ISNULL(i.BillableRate, 0.00)
                          ELSE ISNULL(qi.Net, 0.00)
                      END
                      AS DECIMAL(19,2)
                  )
                , LEFT(ISNULL(NULLIF(m.Description, N''), N'Milestone'), 200)
                , NULL
                , CASE
                      WHEN ISNULL(m.QuotedHours, 0.00) > 0.00
                       AND ISNULL(i.BillableRate, 0.00) = 0.00
                          THEN N'Milestone item created with zero value because the job surveyor billable rate is zero.'
                      WHEN ISNULL(m.QuotedHours, 0.00) = 0.00
                       AND ISNULL(qi.Net, 0.00) = 0.00
                          THEN N'Milestone item created but value could not be determined because Quoted Hours and Quote Item value are both zero.'
                      ELSE N''
                  END
            FROM #InsertedRequests AS ir
            JOIN SJob.Milestones AS m
                ON m.RowStatus NOT IN (0,254)
               AND m.ID =
                   CASE
                       WHEN ir.InstanceKey LIKE N'MS:%'
                           THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 4, 200))
                       WHEN CHARINDEX(N'|M', ir.InstanceKey) > 0
                           THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, CHARINDEX(N'|M', ir.InstanceKey) + 2, 50))
                       ELSE NULL
                   END
            JOIN SJob.Jobs AS j
                ON j.ID = ir.JobId
               AND j.RowStatus NOT IN (0,254)
            LEFT JOIN SCore.Identities AS i
                ON i.ID = j.SurveyorID
               AND i.RowStatus NOT IN (0,254)
            LEFT JOIN SSop.QuoteItems AS qi
                ON qi.ID = m.QuoteLineID
               AND qi.CreatedJobId = ir.JobId
               AND qi.RowStatus NOT IN (0,254)
            WHERE ir.InvoicingType = N'MS';

            ------------------------------------------------------------------
            -- RIBA items
            ------------------------------------------------------------------
            INSERT #ItemsToCreate
            (
                  NewItemGuid
                , InvoiceRequestId
                , MilestoneId
                , ActivityId
                , Net
                , ShortDescription
                , RIBAStageId
                , ValueDerivationReason
            )
            SELECT
                  NEWID()
                , ir.InvoiceRequestId
                , a.MilestoneID
                , a.ID
                , CAST(ISNULL(a.InvoicingValue, 0.00) AS DECIMAL(19,2))
                , LEFT(ISNULL(NULLIF(a.Title, N''), N'RIBA stage activity'), 200)
                , NULL
                , CASE
                      WHEN ISNULL(a.InvoicingValue, 0.00) = 0.00
                          THEN N'RIBA item created but activity value is zero.'
                      ELSE N''
                  END
            FROM #InsertedRequests AS ir
            JOIN SJob.JobStages AS js
                ON js.RowStatus NOT IN (0,254)
               AND js.JobID = ir.JobId
               AND js.ID =
                   CASE
                       WHEN ir.InstanceKey LIKE N'RIBA:%'
                           THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 6, 200))
                       ELSE NULL
                   END
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

            ------------------------------------------------------------------
            -- Fallback items.
            -- Never leave an InvoiceRequest without an item.
            ------------------------------------------------------------------
            INSERT #ItemsToCreate
            (
                  NewItemGuid
                , InvoiceRequestId
                , MilestoneId
                , ActivityId
                , Net
                , ShortDescription
                , RIBAStageId
                , ValueDerivationReason
            )
            SELECT
                  NEWID()
                , ir.InvoiceRequestId
                , m.ID
                , a.ID
                , CAST(0.00 AS DECIMAL(19,2))
                , LEFT
                  (
                      CASE
                          WHEN ir.InvoicingType = N'ACT'  THEN ISNULL(NULLIF(a.Title, N''), N'Activity')
                          WHEN ir.InvoicingType = N'MS'   THEN ISNULL(NULLIF(m.Description, N''), N'Milestone')
                          WHEN ir.InvoicingType = N'RIBA' THEN N'RIBA stage invoice item'
                          ELSE N'Invoice item'
                      END,
                      200
                  )
                , NULL
                , CASE
                      WHEN ir.InvoicingType = N'ACT'
                          THEN N'Activity item created for reconciliation because no billable activity value could be derived.'
                      WHEN ir.InvoicingType = N'MS'
                          THEN N'Milestone item created for reconciliation because no milestone or quote value could be derived.'
                      WHEN ir.InvoicingType = N'RIBA'
                          THEN N'RIBA item created for reconciliation because no billable RIBA value could be derived.'
                      ELSE N'Invoice item created for reconciliation because no value could be derived.'
                  END
            FROM #InsertedRequests AS ir
            LEFT JOIN SJob.Activities AS a
                ON a.ID =
                   CASE
                       WHEN ir.InvoicingType = N'ACT' AND ir.InstanceKey LIKE N'ACT:%'
                           THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 5, 200))
                       WHEN ir.InvoicingType = N'ACT' AND CHARINDEX(N'|A', ir.InstanceKey) > 0
                           THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, CHARINDEX(N'|A', ir.InstanceKey) + 2, 50))
                       ELSE NULL
                   END
               AND a.RowStatus NOT IN (0,254)
            LEFT JOIN SJob.Milestones AS m
                ON m.ID =
                   CASE
                       WHEN ir.InvoicingType = N'MS' AND ir.InstanceKey LIKE N'MS:%'
                           THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, 4, 200))
                       WHEN ir.InvoicingType = N'MS' AND CHARINDEX(N'|M', ir.InstanceKey) > 0
                           THEN TRY_CONVERT(BIGINT, SUBSTRING(ir.InstanceKey, CHARINDEX(N'|M', ir.InstanceKey) + 2, 50))
                       ELSE NULL
                   END
               AND m.RowStatus NOT IN (0,254)
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM #ItemsToCreate AS itc
                WHERE itc.InvoiceRequestId = ir.InvoiceRequestId
            );

            ------------------------------------------------------------------
            -- Insert items with required DataObject rows.
            ------------------------------------------------------------------
            DECLARE
                  @ItemGuid UNIQUEIDENTIFIER
                , @ReqId INT
                , @MsId BIGINT
                , @ActId BIGINT
                , @Net DECIMAL(19,2)
                , @Desc NVARCHAR(200)
                , @RIBAStageId INT
                , @ValueDerivationReason NVARCHAR(200);

            DECLARE cur_item CURSOR LOCAL FAST_FORWARD FOR
                SELECT
                      NewItemGuid
                    , InvoiceRequestId
                    , MilestoneId
                    , ActivityId
                    , Net
                    , ShortDescription
                    , RIBAStageId
                    , ValueDerivationReason
                FROM #ItemsToCreate;

            OPEN cur_item;

            FETCH NEXT FROM cur_item
            INTO @ItemGuid, @ReqId, @MsId, @ActId, @Net, @Desc, @RIBAStageId, @ValueDerivationReason;

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
                    , RIBAStageId
                )
                SELECT
                      1
                    , @ItemGuid
                    , @ReqId
                    , ISNULL(@MsId, -1)
                    , ISNULL(@ActId, -1)
                    , @Net
                    , NULL
                    , -1
                    , LEFT(ISNULL(@Desc, N''), 200)
                    , @RIBAStageId
                WHERE NOT EXISTS
                (
                    SELECT 1
                    FROM SFin.InvoiceRequestItems WITH (UPDLOCK, HOLDLOCK)
                    WHERE Guid = @ItemGuid
                );

                FETCH NEXT FROM cur_item
                INTO @ItemGuid, @ReqId, @MsId, @ActId, @Net, @Desc, @RIBAStageId, @ValueDerivationReason;
            END;

            CLOSE cur_item;
            DEALLOCATE cur_item;

            ------------------------------------------------------------------
            -- Mark reconciliation on the header if value is zero or value was
            -- derived with a warning/default.
            ------------------------------------------------------------------
            ;WITH R AS
            (
                SELECT
                    r.ID
                FROM SFin.InvoiceRequests AS r
                WHERE r.RowStatus NOT IN (0,254)
                  AND r.SourceType = N'TriggerInstance'
                  AND r.AutomationRunGuid = @AutomationRunGuid
                  AND r.InvoicingType IN (N'ACT', N'MS', N'RIBA')
            ),
            Totals AS
            (
                SELECT
                      r.ID
                    , TotalNet = ISNULL(SUM(iri.Net), 0.00)
                    , ItemCount = COUNT(iri.ID)
                FROM R AS r
                LEFT JOIN SFin.InvoiceRequestItems AS iri
                    ON iri.InvoiceRequestId = r.ID
                   AND iri.RowStatus NOT IN (0,254)
                GROUP BY
                    r.ID
            ),
            Reasons AS
            (
                SELECT
                      itc.InvoiceRequestId AS ID
                    , MAX(NULLIF(itc.ValueDerivationReason, N'')) AS ValueDerivationReason
                FROM #ItemsToCreate AS itc
                GROUP BY
                    itc.InvoiceRequestId
            )
            UPDATE r
               SET r.IsZeroValuePlaceholder =
                        CASE
                            WHEN t.TotalNet = 0.00 THEN 1
                            ELSE 0
                        END,
                   r.ReconciliationRequired =
                        CASE
                            WHEN t.TotalNet = 0.00
                              OR rs.ValueDerivationReason IS NOT NULL
                              OR t.ItemCount = 0 THEN 1
                            ELSE 0
                        END,
                   r.ReconciliationReason =
                        CASE
                            WHEN rs.ValueDerivationReason IS NOT NULL
                                THEN rs.ValueDerivationReason
                            WHEN t.ItemCount = 0
                                THEN N'Invoice request created but no items could be derived.'
                            WHEN t.TotalNet = 0.00
                                THEN N'Items derived but value is zero'
                            ELSE N''
                        END
            FROM SFin.InvoiceRequests AS r
            JOIN Totals AS t
                ON t.ID = r.ID
            LEFT JOIN Reasons AS rs
                ON rs.ID = r.ID;

            SET @CreatedInvoiceRequests =
            (
                SELECT COUNT(1)
                FROM #InsertedRequests
            );

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