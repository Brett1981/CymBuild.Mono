SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceRequests_CreateFromTriggerInstances]')
GO
CREATE PROCEDURE [SFin].[InvoiceRequests_CreateFromTriggerInstances]
(
      @AutomationRunGuid             UNIQUEIDENTIFIER = NULL
    , @InvoiceBatchGuid              UNIQUEIDENTIFIER = NULL
    , @RequesterUserId               INT
    , @DefaultInvoicePaymentStatusId BIGINT
    , @OverrideBlocking              BIT = 0
    , @MaxAttempts                   INT = 5
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Attempt INT = 0;

    WHILE (1=1)
    BEGIN
        SET @Attempt += 1;

        BEGIN TRY
            BEGIN TRAN;

            -----------------------------------------------------------------------------------------
            -- 1) Schedule×Job scope (QuoteItem-driven) + blocking resolution
            -----------------------------------------------------------------------------------------
            ;WITH ScheduleJobScope AS
            (
                SELECT DISTINCT
                      qi.InvoicingSchedule AS InvoiceScheduleId
                    , qi.CreatedJobId      AS JobId
                FROM SSop.QuoteItems qi
                WHERE
                    qi.RowStatus NOT IN (0,254)
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
                FROM ScheduleJobScope sjs
                JOIN SJob.Jobs j
                    ON j.ID = sjs.JobId
                    AND j.RowStatus NOT IN (0,254)
                LEFT JOIN SCrm.Accounts a
                    ON a.ID = j.FinanceAccountID
                LEFT JOIN SCrm.AccountStatus acs
                    ON acs.ID = a.AccountStatusID
            ),
            -----------------------------------------------------------------------------------------
            -- 2) Candidate TriggerInstances that are "completed" (CompletedDateTimeUTC IS NOT NULL)
            --    and then expanded per Schedule×Job (by joining on ScheduleId)
            -----------------------------------------------------------------------------------------
            Candidate AS
            (
                SELECT
                      b.InvoiceScheduleId
                    , sch.Guid               AS InvoiceScheduleGuid
                    , b.JobId
                    , ti.Guid                AS TriggerInstanceGuid
                    , ti.InstanceType
                    , ti.InstanceKey
                    , ti.CompletedDateTimeUTC
                FROM Blocking b
                JOIN SFin.InvoiceSchedules sch
                    ON sch.ID = b.InvoiceScheduleId
                    AND sch.RowStatus NOT IN (0,254)
                JOIN SFin.InvoiceScheduleTriggerInstances ti
                    ON ti.InvoiceScheduleId = b.InvoiceScheduleId
                    AND ti.RowStatus NOT IN (0,254)
                WHERE
                    ti.CompletedDateTimeUTC IS NOT NULL
                    AND (
                        @OverrideBlocking = 1
                        OR b.IsBlocked = 0
                    )
            ),
            -----------------------------------------------------------------------------------------
            -- 3) New requests only (idempotency per JobId + SourceGuid + SourceType)
            -----------------------------------------------------------------------------------------
            ToCreate AS
            (
                SELECT c.*
                FROM Candidate c
                WHERE NOT EXISTS
                (
                    SELECT 1
                    FROM SFin.InvoiceRequests r
                    WHERE
                        r.RowStatus <> 0 AND r.RowStatus <> 254
                        AND r.JobId      = c.JobId
                        AND r.SourceType = N'TriggerInstance'
                        AND r.SourceGuid = c.TriggerInstanceGuid
                )
            ),
            -----------------------------------------------------------------------------------------
            -- 4) Map InstanceType -> InvoicingType (ACT/MS/RIBA/PCT/MON)
            -----------------------------------------------------------------------------------------
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
                FROM ToCreate t
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
                , Notes = CONCAT(N'Auto-created from TriggerInstance. InstanceType=', i.InstanceType, N', InstanceKey=', i.InstanceKey)
                , @RequesterUserId
                , SYSUTCDATETIME()
                , i.JobId
                , i.InvoicingType
                , ExpectedDate = CAST(i.CompletedDateTimeUTC AS date)
                , ManualStatus = 0
                , @DefaultInvoicePaymentStatusId
                , IsAutomated = 1
                , IsZeroValuePlaceholder = 0  -- set later after item calc (for ACT/MS); others may remain 0 or be toggled later
                , ReconciliationRequired = 0
                , ReconciliationReason = N''
                , SourceType = N'TriggerInstance'
                , SourceGuid = i.TriggerInstanceGuid
                , SourceIntId = NULL
                , @AutomationRunGuid
                , @InvoiceBatchGuid
                , BlockedReason = CASE WHEN @OverrideBlocking = 1 THEN N'OVERRIDE_BLOCKING' ELSE N'' END
            FROM ToInsert i;

            -----------------------------------------------------------------------------------------
            -- 5) Phase 6 (partial): create InvoiceRequestItems for ACT/MS using InstanceKey parsing.
            --
            -- NOTE: InvoiceRequestItems only supports MilestoneId / ActivityId references.
            --       For RIBA/PCT/MON we do NOT create items here (no safe FK target).
            -----------------------------------------------------------------------------------------

            ;WITH NewReq AS
            (
                SELECT
                      r.ID AS InvoiceRequestId
                    , r.JobId
                    , r.SourceGuid
                    , r.InvoicingType
                FROM SFin.InvoiceRequests r
                WHERE
                    r.RowStatus <> 0 AND r.RowStatus <> 254
                    AND r.IsAutomated = 1
                    AND r.SourceType  = N'TriggerInstance'
                    AND r.AutomationRunGuid = @AutomationRunGuid
            ),
            ReqWithTi AS
            (
                SELECT
                      nr.InvoiceRequestId
                    , nr.JobId
                    , nr.InvoicingType
                    , ti.InstanceKey
                FROM NewReq nr
                JOIN SFin.InvoiceScheduleTriggerInstances ti
                    ON ti.Guid = nr.SourceGuid
                    AND ti.RowStatus NOT IN (0,254)
            ),
            Parsed AS
            (
                SELECT
                      r.*
                    , ActivityId =
                        CASE
                            WHEN r.InvoicingType = N'ACT' AND CHARINDEX(N'|A', r.InstanceKey) > 0
                                THEN TRY_CONVERT(BIGINT, SUBSTRING(r.InstanceKey, CHARINDEX(N'|A', r.InstanceKey) + 2, 50))
                            WHEN r.InvoicingType = N'ACT' AND CHARINDEX(N'ACT:', r.InstanceKey) > 0
                                THEN TRY_CONVERT(BIGINT, SUBSTRING(r.InstanceKey, CHARINDEX(N'ACT:', r.InstanceKey) + 4, 50))
                            ELSE NULL
                        END
                    , MilestoneId =
                        CASE
                            WHEN r.InvoicingType = N'MS' AND CHARINDEX(N'|M', r.InstanceKey) > 0
                                THEN TRY_CONVERT(BIGINT, SUBSTRING(r.InstanceKey, CHARINDEX(N'|M', r.InstanceKey) + 2, 50))
                            WHEN r.InvoicingType = N'MS' AND CHARINDEX(N'MS:', r.InstanceKey) > 0
                                THEN TRY_CONVERT(BIGINT, SUBSTRING(r.InstanceKey, CHARINDEX(N'MS:', r.InstanceKey) + 3, 50))
                            ELSE NULL
                        END
                FROM ReqWithTi r
            )
            INSERT SFin.InvoiceRequestItems
            (
                  RowStatus
                , InvoiceRequestId
                , MilestoneId
                , ActivityId
                , Net
                , LegacySystemID
                , ShortDescription
            )
            SELECT
                  1
                , p.InvoiceRequestId
                , MilestoneId = COALESCE(p.MilestoneId, m.ID)
                , ActivityId  = COALESCE(p.ActivityId, a.ID)
                , Net         = COALESCE(a.InvoicingValue, 0)
                , -1
                , ShortDescription =
                    CASE
                        WHEN p.InvoicingType = N'ACT' THEN COALESCE(a.Title, N'Activity')
                        WHEN p.InvoicingType = N'MS'  THEN COALESCE(m.Description, N'Milestone')
                        ELSE N''
                    END
            FROM Parsed p
            LEFT JOIN SJob.Activities a
                ON a.ID = p.ActivityId
                AND a.RowStatus NOT IN (0,254)
            LEFT JOIN SJob.Milestones m
                ON m.ID = p.MilestoneId
                AND m.RowStatus NOT IN (0,254)
            WHERE
                p.InvoicingType IN (N'ACT', N'MS')
                AND (
                    (p.InvoicingType = N'ACT' AND a.ID IS NOT NULL)
                    OR
                    (p.InvoicingType = N'MS'  AND m.ID IS NOT NULL)
                );

            -----------------------------------------------------------------------------------------
            -- 6) Mark requests as zero-value placeholders when no items exist OR total net = 0
            -----------------------------------------------------------------------------------------
            ;WITH R AS
            (
                SELECT r.ID
                FROM SFin.InvoiceRequests r
                WHERE
                    r.RowStatus <> 0 AND r.RowStatus <> 254
                    AND r.IsAutomated = 1
                    AND r.SourceType  = N'TriggerInstance'
                    AND r.AutomationRunGuid = @AutomationRunGuid
                    AND r.InvoicingType IN (N'ACT', N'MS')
            ),
            Totals AS
            (
                SELECT
                      r.ID
                    , TotalNet = ISNULL(SUM(iri.Net), 0)
                    , ItemCount = COUNT(iri.ID)
                FROM R r
                LEFT JOIN SFin.InvoiceRequestItems iri
                    ON iri.InvoiceRequestId = r.ID
                    AND iri.RowStatus <> 0 AND iri.RowStatus <> 254
                GROUP BY r.ID
            )
            UPDATE r
            SET
                  r.IsZeroValuePlaceholder =
                        CASE WHEN t.ItemCount = 0 OR t.TotalNet = 0 THEN 1 ELSE 0 END
                , r.ReconciliationRequired =
                        CASE WHEN t.ItemCount = 0 OR t.TotalNet = 0 THEN 1 ELSE 0 END
                , r.ReconciliationReason =
                        CASE WHEN t.ItemCount = 0 THEN N'No items could be derived'
                             WHEN t.TotalNet = 0 THEN N'Items derived but value is zero'
                             ELSE r.ReconciliationReason END
            FROM SFin.InvoiceRequests r
            JOIN Totals t ON t.ID = r.ID;

            COMMIT;

            SELECT
                  CreatedRequests = @@ROWCOUNT; -- last statement count; keep it simple (or we can return a richer summary)
            RETURN;
        END TRY
        BEGIN CATCH
            IF (XACT_STATE() <> 0) ROLLBACK;

            DECLARE
                  @ErrNum INT = ERROR_NUMBER()
                , @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

            IF (@ErrNum = 1205 AND @Attempt < @MaxAttempts)
            BEGIN
                WAITFOR DELAY '00:00:00.250';
                CONTINUE;
            END

            IF ((@ErrNum IN (2601,2627)) AND @Attempt < @MaxAttempts)
            BEGIN
                WAITFOR DELAY '00:00:00.050';
                CONTINUE;
            END
            DECLARE @ThrowMessage nvarchar(4000);

        SET @ThrowMessage =
            CONCAT(
                N'create InvoiceRequests failed failed. Error ',
                @ErrNum,
                N': ',
                @ErrMsg
            );

        THROW 60020, @ThrowMessage, 1;
        END CATCH
    END
END
GO