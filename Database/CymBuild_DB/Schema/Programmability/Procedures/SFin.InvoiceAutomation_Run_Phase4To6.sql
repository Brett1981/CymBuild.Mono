SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceAutomation_Run_Phase4To6]')
GO
PRINT (N'Create procedure [SFin].[InvoiceAutomation_Run_Phase4To6]')
GO

/* =============================================================================
   SFin.InvoiceAutomation_Run_Phase4To6 (REPLACEMENT - hardened)

   Fixes Msg 3930 ("transaction cannot be committed") by:
   - SET XACT_ABORT OFF (do not doom the session transaction on inner errors)
   - Guard all logging writes with IF XACT_STATE() <> -1
   - Still raises the real underlying error

   Notes:
   - No explicit BEGIN TRAN / COMMIT / ROLLBACK
   - Keeps your OUTPUT-param child proc approach
============================================================================= */
CREATE PROCEDURE [SFin].[InvoiceAutomation_Run_Phase4To6]
(
      @AutomationRunGuid        UNIQUEIDENTIFIER
    , @RequesterUserGuid        UNIQUEIDENTIFIER
    , @DefaultPaymentStatusGuid UNIQUEIDENTIFIER = NULL
    , @Notes                    NVARCHAR(MAX) = NULL
    , @NowUtc                   DATETIME2(7) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    /* IMPORTANT: avoid "doomed transaction" behavior */
    SET XACT_ABORT OFF;

    DECLARE @NowUtcEff DATETIME2(7) = COALESCE(@NowUtc, SYSUTCDATETIME());
    DECLARE @TriggeredByUserId INT;

    SELECT @TriggeredByUserId = i.ID
    FROM SCore.Identities i
    WHERE i.Guid = @RequesterUserGuid;

    IF (@TriggeredByUserId IS NULL)
    BEGIN
        RAISERROR(N'RequesterUserGuid not found in SCore.Identities.', 16, 1);
        RETURN;
    END

    /* Ensure Run header exists (idempotent upsert) */
    IF NOT EXISTS (SELECT 1 FROM SFin.InvoiceAutomationRuns r WHERE r.Guid = @AutomationRunGuid)
    BEGIN
        INSERT SFin.InvoiceAutomationRuns
        (
              RowStatus, Guid, StartedDateTimeUTC, CompletedDateTimeUTC,
              EnvironmentName, TriggeredByUserId,
              CreatedCount, SkippedCount, BlockedCount, ReconciledCount, ErrorCount,
              InvoiceBatchGuid, Notes, LegacyId, LegacySystemID, WasBatchCreated
        )
        VALUES
        (
              1, @AutomationRunGuid, @NowUtcEff, NULL,
              DB_NAME(), @TriggeredByUserId,
              0, 0, 0, 0, 0,
              NULL, ISNULL(@Notes, N''), NULL, -1, 0
        );
    END
    ELSE
    BEGIN
        UPDATE r
            SET r.EnvironmentName   = DB_NAME(),
                r.TriggeredByUserId = @TriggeredByUserId,
                r.Notes             = ISNULL(@Notes, r.Notes)
        FROM SFin.InvoiceAutomationRuns r
        WHERE r.Guid = @AutomationRunGuid;
    END

    DECLARE
          @Created_TriggerInstances INT = 0
        , @Created_MonthConfig      INT = 0
        , @Created_PercentageConfig INT = 0
        , @BatchGuid                UNIQUEIDENTIFIER = NULL;

    DECLARE
          @ChildCreated INT = 0
        , @ChildAttempt INT = NULL
        , @ChildCreatedAtUtc DATETIME2(7) = NULL;

    DECLARE
          @BatchAssignedCount INT = 0
        , @BatchAttempt INT = NULL
        , @BatchCreatedAtUtc DATETIME2(7) = NULL;

    BEGIN TRY
        /* -------------------------
           Phase 4: Materialise TriggerInstances
        ------------------------- */

        IF (XACT_STATE() <> -1)
        BEGIN
            INSERT SFin.InvoiceAutomationRunDetails
            (
                  RowStatus, Guid, AutomationRunGuid,
                  InvoiceScheduleId, SourceType, SourceGuid, SourceIntId,
                  InstanceType, InstanceKey, Outcome, Message, InvoiceRequestGuid,
                  CreatedDateTimeUTC, LegacyId, LegacySystemID
            )
            VALUES
            (
                  1, NEWID(), @AutomationRunGuid,
                  -1, N'', NULL, NULL,
                  N'RUN', N'PHASE4', N'Started',
                  N'Phase 4: Materialising TriggerInstances from Phase 3 detections.',
                  NULL,
                  SYSUTCDATETIME(), NULL, -1
            );
        END

        EXEC [SFin].[InvoiceScheduleTriggerInstances_Materialise]
              @DetectedDateTimeUTC = @NowUtcEff;

        IF (XACT_STATE() <> -1)
        BEGIN
            INSERT SFin.InvoiceAutomationRunDetails
            (
                  RowStatus, Guid, AutomationRunGuid,
                  InvoiceScheduleId, SourceType, SourceGuid, SourceIntId,
                  InstanceType, InstanceKey, Outcome, Message, InvoiceRequestGuid,
                  CreatedDateTimeUTC, LegacyId, LegacySystemID
            )
            VALUES
            (
                  1, NEWID(), @AutomationRunGuid,
                  -1, N'', NULL, NULL,
                  N'RUN', N'PHASE4', N'Success',
                  N'Phase 4 completed.',
                  NULL,
                  SYSUTCDATETIME(), NULL, -1
            );
        END

        /* -------------------------
           Phase 5: Create InvoiceRequests
        ------------------------- */

        /* TriggerInstance-driven: ACT/MS/RIBA */
        IF OBJECT_ID(N'[SFin].[InvoiceAutomation_CreateInvoiceRequests_FromTriggerInstances]', N'P') IS NOT NULL
        BEGIN
            SET @ChildCreated = 0; SET @ChildAttempt = NULL; SET @ChildCreatedAtUtc = NULL;

            EXEC [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromTriggerInstances]
                  @AutomationRunGuid        = @AutomationRunGuid
                , @RequesterUserGuid        = @RequesterUserGuid
                , @DefaultPaymentStatusGuid = @DefaultPaymentStatusGuid
                , @NowUtc                   = @NowUtcEff
                , @MaxAttempts              = 5
                , @CreatedInvoiceRequests   = @ChildCreated OUTPUT
                , @Attempt                  = @ChildAttempt OUTPUT
                , @CreatedAtUtc             = @ChildCreatedAtUtc OUTPUT;

            SET @Created_TriggerInstances = ISNULL(@ChildCreated, 0);

            IF (XACT_STATE() <> -1)
            BEGIN
                INSERT SFin.InvoiceAutomationRunDetails
                (
                      RowStatus, Guid, AutomationRunGuid,
                      InvoiceScheduleId, SourceType, SourceGuid, SourceIntId,
                      InstanceType, InstanceKey, Outcome, Message, InvoiceRequestGuid,
                      CreatedDateTimeUTC, LegacyId, LegacySystemID
                )
                VALUES
                (
                      1, NEWID(), @AutomationRunGuid,
                      -1, N'TriggerInstance', NULL, NULL,
                      N'RUN', N'TRIGGERINSTANCES', N'Success',
                      CONCAT(N'Created from TriggerInstances (ACT/MS/RIBA): ', @Created_TriggerInstances),
                      NULL,
                      SYSUTCDATETIME(), NULL, -1
                );
            END
        END

        /* MonthConfig-driven: MON */
        IF OBJECT_ID(N'[SFin].[InvoiceAutomation_CreateInvoiceRequests_FromMonthConfig]', N'P') IS NOT NULL
        BEGIN
            SET @ChildCreated = 0; SET @ChildAttempt = NULL; SET @ChildCreatedAtUtc = NULL;

            EXEC [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromMonthConfig]
                  @AutomationRunGuid        = @AutomationRunGuid
                , @RequesterUserGuid        = @RequesterUserGuid
                , @DefaultPaymentStatusGuid = @DefaultPaymentStatusGuid
                , @NowUtc                   = @NowUtcEff
                , @MaxAttempts              = 5
                , @CreatedInvoiceRequests   = @ChildCreated OUTPUT
                , @Attempt                  = @ChildAttempt OUTPUT
                , @CreatedAtUtc             = @ChildCreatedAtUtc OUTPUT;

            SET @Created_MonthConfig = ISNULL(@ChildCreated, 0);

            IF (XACT_STATE() <> -1)
            BEGIN
                INSERT SFin.InvoiceAutomationRunDetails
                (
                      RowStatus, Guid, AutomationRunGuid,
                      InvoiceScheduleId, SourceType, SourceGuid, SourceIntId,
                      InstanceType, InstanceKey, Outcome, Message, InvoiceRequestGuid,
                      CreatedDateTimeUTC, LegacyId, LegacySystemID
                )
                VALUES
                (
                      1, NEWID(), @AutomationRunGuid,
                      -1, N'MonthConfig', NULL, NULL,
                      N'RUN', N'MONTHCONFIG', N'Success',
                      CONCAT(N'Created from MonthConfig: ', @Created_MonthConfig),
                      NULL,
                      SYSUTCDATETIME(), NULL, -1
                );
            END
        END

        /* PercentageConfig-driven: PCT */
        IF OBJECT_ID(N'[SFin].[InvoiceAutomation_CreateInvoiceRequests_FromPercentageConfig]', N'P') IS NOT NULL
        BEGIN
            SET @ChildCreated = 0; SET @ChildAttempt = NULL; SET @ChildCreatedAtUtc = NULL;

            EXEC [SFin].[InvoiceAutomation_CreateInvoiceRequests_FromPercentageConfig]
                  @AutomationRunGuid        = @AutomationRunGuid
                , @RequesterUserGuid        = @RequesterUserGuid
                , @DefaultPaymentStatusGuid = @DefaultPaymentStatusGuid
                , @NowUtc                   = @NowUtcEff
                , @MaxAttempts              = 5
                , @CreatedInvoiceRequests   = @ChildCreated OUTPUT
                , @Attempt                  = @ChildAttempt OUTPUT
                , @CreatedAtUtc             = @ChildCreatedAtUtc OUTPUT;

            SET @Created_PercentageConfig = ISNULL(@ChildCreated, 0);

            IF (XACT_STATE() <> -1)
            BEGIN
                INSERT SFin.InvoiceAutomationRunDetails
                (
                      RowStatus, Guid, AutomationRunGuid,
                      InvoiceScheduleId, SourceType, SourceGuid, SourceIntId,
                      InstanceType, InstanceKey, Outcome, Message, InvoiceRequestGuid,
                      CreatedDateTimeUTC, LegacyId, LegacySystemID
                )
                VALUES
                (
                      1, NEWID(), @AutomationRunGuid,
                      -1, N'PercentageConfig', NULL, NULL,
                      N'RUN', N'PERCENTAGECONFIG', N'Success',
                      CONCAT(N'Created from PercentageConfig: ', @Created_PercentageConfig),
                      NULL,
                      SYSUTCDATETIME(), NULL, -1
                );
            END
        END

        /* -------------------------
           Phase 6: batch + assign
        ------------------------- */

        IF (XACT_STATE() <> -1)
        BEGIN
            INSERT SFin.InvoiceAutomationRunDetails
            (
                  RowStatus, Guid, AutomationRunGuid,
                  InvoiceScheduleId, SourceType, SourceGuid, SourceIntId,
                  InstanceType, InstanceKey, Outcome, Message, InvoiceRequestGuid,
                  CreatedDateTimeUTC, LegacyId, LegacySystemID
            )
            VALUES
            (
                  1, NEWID(), @AutomationRunGuid,
                  -1, N'', NULL, NULL,
                  N'RUN', N'BATCH', N'Started',
                  N'Phase 6: Creating/assigning InvoiceBatch for this run.',
                  NULL,
                  SYSUTCDATETIME(), NULL, -1
            );
        END

        EXEC [SFin].[InvoiceAutomation_CreateBatch_AssignRequests]
              @AutomationRunGuid = @AutomationRunGuid
            , @RequesterUserGuid = @RequesterUserGuid
            , @Notes             = @Notes
            , @NowUtc            = @NowUtcEff
            , @MaxAttempts       = 5
            , @InvoiceBatchGuid  = @BatchGuid OUTPUT
            , @AssignedCount     = @BatchAssignedCount OUTPUT
            , @Attempt           = @BatchAttempt OUTPUT
            , @CreatedAtUtc      = @BatchCreatedAtUtc OUTPUT;

        IF (XACT_STATE() <> -1)
        BEGIN
            INSERT SFin.InvoiceAutomationRunDetails
            (
                  RowStatus, Guid, AutomationRunGuid,
                  InvoiceScheduleId, SourceType, SourceGuid, SourceIntId,
                  InstanceType, InstanceKey, Outcome, Message, InvoiceRequestGuid,
                  CreatedDateTimeUTC, LegacyId, LegacySystemID
            )
            VALUES
            (
                  1, NEWID(), @AutomationRunGuid,
                  -1, N'', NULL, NULL,
                  N'RUN', N'BATCH', N'Success',
                  CONCAT(N'Batch assign completed. InvoiceBatchGuid=',
                         COALESCE(CONVERT(NVARCHAR(36), @BatchGuid), N'<none>'),
                         N', Assigned=', CONVERT(NVARCHAR(20), ISNULL(@BatchAssignedCount,0))),
                  NULL,
                  SYSUTCDATETIME(), NULL, -1
            );
        END

        /* -------------------------
           Totals / header update
        ------------------------- */

        DECLARE
              @CreatedCount     INT = 0
            , @ReconciledCount  INT = 0
            , @BlockedCount     INT = 0
            , @SkippedCount     INT = 0;

        SELECT @CreatedCount = COUNT(1)
        FROM SFin.InvoiceRequests r
        WHERE r.RowStatus NOT IN (0,254)
          AND r.AutomationRunGuid = @AutomationRunGuid
          AND r.IsAutomated = 1;

        SELECT @ReconciledCount = COUNT(1)
        FROM SFin.InvoiceRequests r
        WHERE r.RowStatus NOT IN (0,254)
          AND r.AutomationRunGuid = @AutomationRunGuid
          AND r.ReconciliationRequired = 1;

        ;WITH Scope AS
        (
            SELECT DISTINCT
                  qi.InvoicingSchedule AS InvoiceScheduleId
                , qi.CreatedJobId      AS JobId
            FROM SSop.QuoteItems qi
            JOIN SFin.InvoiceSchedules sch ON sch.ID = qi.InvoicingSchedule
            WHERE qi.RowStatus NOT IN (0,254)
              AND sch.RowStatus NOT IN (0,254)
              AND qi.CreatedJobId NOT IN (-1,0)
              AND qi.InvoicingSchedule NOT IN (-1,0)
        )
        SELECT @BlockedCount = COUNT(1)
        FROM Scope s
        JOIN SFin.vw_InvoiceAutomation_BlockingDiagnostics bd
            ON bd.InvoiceScheduleId = s.InvoiceScheduleId
           AND bd.JobId = s.JobId
        WHERE bd.IsBlocked = 1;

        SET @SkippedCount = 0;

        IF (XACT_STATE() <> -1)
        BEGIN
            UPDATE r
                SET r.CompletedDateTimeUTC = SYSUTCDATETIME(),
                    r.CreatedCount        = @CreatedCount,
                    r.BlockedCount        = @BlockedCount,
                    r.ReconciledCount     = @ReconciledCount,
                    r.SkippedCount        = @SkippedCount,
                    r.ErrorCount          = 0,
                    r.InvoiceBatchGuid    = @BatchGuid,
                    r.WasBatchCreated     = CASE WHEN @BatchGuid IS NULL THEN 0 ELSE 1 END
            FROM SFin.InvoiceAutomationRuns r
            WHERE r.Guid = @AutomationRunGuid;
        END

        RETURN;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrNum INT = ERROR_NUMBER();

        /* If transaction is doomed, we cannot write run details safely. */
        IF (XACT_STATE() <> -1)
        BEGIN
            INSERT SFin.InvoiceAutomationRunDetails
            (
                  RowStatus, Guid, AutomationRunGuid,
                  InvoiceScheduleId, SourceType, SourceGuid, SourceIntId,
                  InstanceType, InstanceKey, Outcome, Message, InvoiceRequestGuid,
                  CreatedDateTimeUTC, LegacyId, LegacySystemID
            )
            VALUES
            (
                  1, NEWID(), @AutomationRunGuid,
                  -1, N'', NULL, NULL,
                  N'RUN', N'ERROR', N'Failed',
                  CONCAT(N'Run failed (', @ErrNum, N'): ', @ErrMsg),
                  NULL,
                  SYSUTCDATETIME(), NULL, -1
            );

            UPDATE r
                SET r.CompletedDateTimeUTC = SYSUTCDATETIME(),
                    r.ErrorCount          = r.ErrorCount + 1
            FROM SFin.InvoiceAutomationRuns r
            WHERE r.Guid = @AutomationRunGuid;
        END

        RAISERROR(N'InvoiceAutomation_Run_Phase4To6 failed (%d): %s', 16, 1, @ErrNum, @ErrMsg);
        RETURN;
    END CATCH
END
GO