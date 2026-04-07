SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceAutomationRun_EmitRequests_TriggerInstances]')
GO

CREATE PROCEDURE [SFin].[InvoiceAutomationRun_EmitRequests_TriggerInstances]
(
    @RunGuid                    UNIQUEIDENTIFIER,
    @AsOfUtc                    DATETIME2(7),

    @DefaultInvoicingType       NVARCHAR(10) = N'',
    @DefaultPaymentStatusGuid   UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000',

    @CreatedCount               INT OUTPUT,
    @SkippedCount               INT OUTPUT,
    @BlockedCount               INT OUTPUT,
    @ReconciledCount            INT OUTPUT,
    @ErrorCount                 INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @CreatedCount = 0;
    SET @SkippedCount = 0;
    SET @BlockedCount = 0;
    SET @ReconciledCount = 0;
    SET @ErrorCount = 0;

    ;WITH Instances AS
    (
        SELECT
            ti.ID              AS TriggerInstanceId,
            ti.Guid            AS TriggerInstanceGuid,
            ti.InvoiceScheduleId,
            ti.InstanceType,
            ti.InstanceKey,
            ti.DetectedDateTimeUTC
        FROM SFin.InvoiceScheduleTriggerInstances ti
        JOIN SFin.InvoiceSchedules s
            ON s.ID = ti.InvoiceScheduleId
           AND s.RowStatus NOT IN (0, 254)
        WHERE ti.RowStatus NOT IN (0, 254)
          AND ti.CompletedDateTimeUTC IS NULL
          AND ti.DetectedDateTimeUTC <= @AsOfUtc
    ),
    Work AS
    (
        SELECT
            i.*,
            qi.ID AS QuoteItemId,
            qi.CreatedJobId AS JobId
        FROM Instances i
        JOIN SSop.QuoteItems qi
            ON qi.InvoicingSchedule = i.InvoiceScheduleId
           AND qi.RowStatus NOT IN (0, 254)
           AND qi.CreatedJobId IS NOT NULL
    )
    SELECT
        w.*,
        j.Guid AS JobGuid,
        j.ManualInvoicingEnabled,
        ac.AccountStatusID,
        IsCreditHold = CASE WHEN ac.AccountStatusID = 4 THEN 1 ELSE 0 END
    INTO #Work
    FROM Work w
    JOIN SJob.Jobs j
        ON j.ID = w.JobId
       AND j.RowStatus NOT IN (0, 254)
    JOIN SCrm.Accounts ac
        ON ac.ID = j.FinanceAccountID
       AND ac.RowStatus NOT IN (0, 254);

    DECLARE
        @TriggerInstanceId BIGINT,
        @TriggerInstanceGuid UNIQUEIDENTIFIER,
        @ScheduleId INT,
        @InstanceType NVARCHAR(100),
        @InstanceKey NVARCHAR(400),
        @DetectedUtc DATETIME2(7),
        @JobGuid UNIQUEIDENTIFIER,
        @QuoteItemId INT,
        @Manual BIT,
        @IsCreditHold BIT,
        @ExpectedDate DATE,
        @BlockedReason NVARCHAR(200),
        @CreatedGuid UNIQUEIDENTIFIER,
        @WasInserted BIT;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            TriggerInstanceId, TriggerInstanceGuid, InvoiceScheduleId, InstanceType, InstanceKey, DetectedDateTimeUTC,
            JobGuid, QuoteItemId, ManualInvoicingEnabled, IsCreditHold
        FROM #Work;

    OPEN cur;
    FETCH NEXT FROM cur INTO
        @TriggerInstanceId, @TriggerInstanceGuid, @ScheduleId, @InstanceType, @InstanceKey, @DetectedUtc,
        @JobGuid, @QuoteItemId, @Manual, @IsCreditHold;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            IF (@Manual = 1)
            BEGIN
                SET @SkippedCount += 1;

                INSERT SFin.InvoiceAutomationRunDetails
                (
                    RowStatus, Guid, AutomationRunGuid, InvoiceScheduleId,
                    SourceType, SourceGuid, SourceIntId,
                    InstanceType, InstanceKey,
                    Outcome, Message, InvoiceRequestGuid,
                    CreatedDateTimeUTC, LegacyId, LegacySystemID
                )
                VALUES
                (
                    1, NEWID(), @RunGuid, @ScheduleId,
                    N'TriggerInstance', @TriggerInstanceGuid, @QuoteItemId,
                    @InstanceType, @InstanceKey,
                    N'Skipped', N'Job has ManualInvoicingEnabled=1 (skip entirely).', NULL,
                    SYSUTCDATETIME(), NULL, -1
                );

                FETCH NEXT FROM cur INTO
                    @TriggerInstanceId, @TriggerInstanceGuid, @ScheduleId, @InstanceType, @InstanceKey, @DetectedUtc,
                    @JobGuid, @QuoteItemId, @Manual, @IsCreditHold;

                CONTINUE;
            END

            SET @ExpectedDate = CONVERT(date, @DetectedUtc);
            SET @BlockedReason = CASE WHEN @IsCreditHold = 1 THEN N'Credit Hold' ELSE N'' END;

            EXEC SFin.InvoiceRequestAutomationCreate
                @JobGuid                = @JobGuid,
                @Guid                   = NULL,
                @RequesterUserGuid      = NULL,
                @Notes                  = N'',
                @InvoicingType          = @DefaultInvoicingType,
                @ExpectedDate           = @ExpectedDate,
                @PaymentStatusGuid      = @DefaultPaymentStatusGuid,
                @IsZeroValuePlaceholder = 0,
                @ReconciliationRequired = 0,
                @ReconciliationReason   = N'',
                @SourceType             = N'TriggerInstance',
                @SourceGuid             = @TriggerInstanceGuid,
                @SourceIntId            = @QuoteItemId,
                @AutomationRunGuid      = @RunGuid,
                @InvoiceBatchGuid       = NULL,
                @BlockedReason          = @BlockedReason,
                @CreatedGuid            = @CreatedGuid OUTPUT,
                @WasInserted            = @WasInserted OUTPUT;

            IF (@WasInserted = 1) SET @CreatedCount += 1 ELSE SET @SkippedCount += 1;
            IF (@BlockedReason <> N'') SET @BlockedCount += 1;

            INSERT SFin.InvoiceAutomationRunDetails
            (
                RowStatus, Guid, AutomationRunGuid, InvoiceScheduleId,
                SourceType, SourceGuid, SourceIntId,
                InstanceType, InstanceKey,
                Outcome, Message, InvoiceRequestGuid,
                CreatedDateTimeUTC, LegacyId, LegacySystemID
            )
            VALUES
            (
                1, NEWID(), @RunGuid, @ScheduleId,
                N'TriggerInstance', @TriggerInstanceGuid, @QuoteItemId,
                @InstanceType, @InstanceKey,
                CASE WHEN @WasInserted = 1 THEN N'Created' ELSE N'AlreadyExists' END,
                CASE
                    WHEN @BlockedReason <> N'' THEN N'Created with BlockedReason (Credit Hold).'
                    WHEN @WasInserted = 1 THEN N'Created.'
                    ELSE N'Already existed (idempotent).'
                END,
                @CreatedGuid,
                SYSUTCDATETIME(), NULL, -1
            );

        END TRY
        BEGIN CATCH
            SET @ErrorCount += 1;

            INSERT SFin.InvoiceAutomationRunDetails
            (
                RowStatus, Guid, AutomationRunGuid, InvoiceScheduleId,
                SourceType, SourceGuid, SourceIntId,
                InstanceType, InstanceKey,
                Outcome, Message, InvoiceRequestGuid,
                CreatedDateTimeUTC, LegacyId, LegacySystemID
            )
            VALUES
            (
                1, NEWID(), @RunGuid, @ScheduleId,
                N'TriggerInstance', @TriggerInstanceGuid, @QuoteItemId,
                @InstanceType, @InstanceKey,
                N'Error', ERROR_MESSAGE(), NULL,
                SYSUTCDATETIME(), NULL, -1
            );
        END CATCH

        FETCH NEXT FROM cur INTO
            @TriggerInstanceId, @TriggerInstanceGuid, @ScheduleId, @InstanceType, @InstanceKey, @DetectedUtc,
            @JobGuid, @QuoteItemId, @Manual, @IsCreditHold;
    END

    CLOSE cur;
    DEALLOCATE cur;

    -------------------------------------------------------------------------
    -- Mark processed trigger instances (even if some jobs were skipped/errors).
    -- This stops re-detection loops; idempotency still prevents duplicates.
    -------------------------------------------------------------------------
    UPDATE ti
    SET ti.CompletedDateTimeUTC = @AsOfUtc
    FROM SFin.InvoiceScheduleTriggerInstances ti
    WHERE ti.RowStatus NOT IN (0, 254)
      AND ti.CompletedDateTimeUTC IS NULL
      AND EXISTS
      (
          SELECT 1
          FROM #Work w
          WHERE w.TriggerInstanceGuid = ti.Guid
      );

    DROP TABLE #Work;
END
GO