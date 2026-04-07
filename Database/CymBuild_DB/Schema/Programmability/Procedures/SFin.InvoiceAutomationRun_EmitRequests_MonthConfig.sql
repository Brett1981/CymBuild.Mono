SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceAutomationRun_EmitRequests_MonthConfig]')
GO

CREATE PROCEDURE [SFin].[InvoiceAutomationRun_EmitRequests_MonthConfig]
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

    DECLARE @AsOfDate DATE = CONVERT(date, @AsOfUtc);

    SET @CreatedCount = 0;
    SET @SkippedCount = 0;
    SET @BlockedCount = 0;
    SET @ReconciledCount = 0;
    SET @ErrorCount = 0;

    ;WITH Candidates AS
    (
        SELECT
            mc.InvoiceScheduleId,
            mc.ID               AS MonthConfigId,
            mc.Guid             AS MonthConfigGuid,
            mc.OnDayOfMonth     AS OnDate,
            qi.ID               AS QuoteItemId,
            qi.Guid             AS QuoteItemGuid,
            qi.CreatedJobId     AS JobId
        FROM SFin.InvoiceScheduleMonthConfiguration mc
        JOIN SFin.InvoiceSchedules s
            ON s.ID = mc.InvoiceScheduleId
           AND s.RowStatus NOT IN (0, 254)
        JOIN SSop.QuoteItems qi
            ON qi.InvoicingSchedule = mc.InvoiceScheduleId
           AND qi.RowStatus NOT IN (0, 254)
           AND qi.CreatedJobId IS NOT NULL
        WHERE mc.RowStatus NOT IN (0, 254)
          AND mc.OnDayOfMonth IS NOT NULL
          AND mc.OnDayOfMonth <= @AsOfDate
    )
    SELECT
        c.*,
        j.Guid AS JobGuid,
        j.ManualInvoicingEnabled,
        j.FinanceAccountID,
        ac.Guid AS FinanceAccountGuid,
        IsCreditHold = CASE WHEN ac.AccountStatusID = 4 THEN 1 ELSE 0 END
    INTO #Work
    FROM Candidates c
    JOIN SJob.Jobs j
        ON j.ID = c.JobId
       AND j.RowStatus NOT IN (0, 254)
    JOIN SCrm.Accounts ac
        ON ac.ID = j.FinanceAccountID
       AND ac.RowStatus NOT IN (0, 254);

    -------------------------------------------------------------------------
    -- Process each row (cursor-style but safe & explicit)
    -------------------------------------------------------------------------
    DECLARE
        @JobGuid UNIQUEIDENTIFIER,
        @MonthConfigGuid UNIQUEIDENTIFIER,
        @QuoteItemId INT,
        @ExpectedDate DATE,
        @Manual BIT,
        @IsCreditHold BIT,
        @BlockedReason NVARCHAR(200),
        @CreatedGuid UNIQUEIDENTIFIER,
        @WasInserted BIT;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            JobGuid,
            MonthConfigGuid,
            QuoteItemId,
            OnDate,
            ManualInvoicingEnabled,
            IsCreditHold
        FROM #Work;

    OPEN cur;
    FETCH NEXT FROM cur INTO @JobGuid, @MonthConfigGuid, @QuoteItemId, @ExpectedDate, @Manual, @IsCreditHold;

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
                SELECT
                    1, NEWID(), @RunGuid, w.InvoiceScheduleId,
                    N'MonthConfig', @MonthConfigGuid, @QuoteItemId,
                    N'MonthConfig', CONVERT(nvarchar(400), @MonthConfigGuid),
                    N'Skipped', N'Job has ManualInvoicingEnabled=1 (skip entirely).', NULL,
                    SYSUTCDATETIME(), NULL, -1
                FROM #Work w
                WHERE w.JobGuid = @JobGuid AND w.MonthConfigGuid = @MonthConfigGuid AND w.QuoteItemId = @QuoteItemId;

                FETCH NEXT FROM cur INTO @JobGuid, @MonthConfigGuid, @QuoteItemId, @ExpectedDate, @Manual, @IsCreditHold;
                CONTINUE;
            END

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
                @SourceType             = N'MonthConfig',
                @SourceGuid             = @MonthConfigGuid,
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
            SELECT
                1, NEWID(), @RunGuid, w.InvoiceScheduleId,
                N'MonthConfig', @MonthConfigGuid, @QuoteItemId,
                N'MonthConfig', CONVERT(nvarchar(400), @MonthConfigGuid),
                CASE WHEN @WasInserted = 1 THEN N'Created' ELSE N'AlreadyExists' END,
                CASE
                    WHEN @BlockedReason <> N'' THEN N'Created with BlockedReason (Credit Hold).'
                    WHEN @WasInserted = 1 THEN N'Created.'
                    ELSE N'Already existed (idempotent).'
                END,
                @CreatedGuid,
                SYSUTCDATETIME(), NULL, -1
            FROM #Work w
            WHERE w.JobGuid = @JobGuid AND w.MonthConfigGuid = @MonthConfigGuid AND w.QuoteItemId = @QuoteItemId;
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
            SELECT
                1, NEWID(), @RunGuid, w.InvoiceScheduleId,
                N'MonthConfig', @MonthConfigGuid, @QuoteItemId,
                N'MonthConfig', CONVERT(nvarchar(400), @MonthConfigGuid),
                N'Error', ERROR_MESSAGE(), NULL,
                SYSUTCDATETIME(), NULL, -1
            FROM #Work w
            WHERE w.JobGuid = @JobGuid AND w.MonthConfigGuid = @MonthConfigGuid AND w.QuoteItemId = @QuoteItemId;
        END CATCH

        FETCH NEXT FROM cur INTO @JobGuid, @MonthConfigGuid, @QuoteItemId, @ExpectedDate, @Manual, @IsCreditHold;
    END

    CLOSE cur;
    DEALLOCATE cur;

    DROP TABLE #Work;
END
GO