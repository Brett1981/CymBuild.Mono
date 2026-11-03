/* CYB-279 Dev264 apply: drawdown series keep their cadence (multi-month frequencies). Dev264 == release/26.4 before this. */
USE [CymBuild_Dev264];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [SFin].[InvoiceScheduleMonthConfiguration_GenerateMonthlySeries]
(
      @InvoiceScheduleGuid   UNIQUEIDENTIFIER
    , @StartDate             DATE
    , @EndDate               DATE
    , @TotalValueNet         DECIMAL(19,2)
    , @Frequency             VARCHAR(20) = 'Monthly'
    , @OverwriteExisting     BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF (@InvoiceScheduleGuid IS NULL OR @InvoiceScheduleGuid = '00000000-0000-0000-0000-000000000000')
        THROW 60001, 'InvoiceScheduleGuid is required.', 1;

    IF (@StartDate IS NULL OR @EndDate IS NULL)
        THROW 60002, 'StartDate and EndDate are required.', 1;

    IF (@StartDate > @EndDate)
        THROW 60003, 'StartDate must be <= EndDate.', 1;

    IF (ISNULL(@TotalValueNet, 0) <= 0)
        THROW 60004, 'TotalValueNet must be > 0.', 1;

    -- Map Frequency -> step in months
    DECLARE @StepMonths INT =
        CASE @Frequency
            WHEN 'Monthly'     THEN 1
            WHEN 'Bi-monthly'  THEN 2
            WHEN 'Quarterly'   THEN 3
            WHEN 'Bi-annual'   THEN 6
            ELSE NULL
        END;

    IF (@StepMonths IS NULL)
        THROW 60008, 'Frequency must be one of: Monthly, Bi-monthly, Quarterly, Bi-annual.', 1;

    DECLARE @InvoiceScheduleId INT =
    (
        SELECT TOP (1) s.ID
        FROM SFin.InvoiceSchedules s
        WHERE s.RowStatus NOT IN (0,254)
          AND s.Guid = @InvoiceScheduleGuid
        ORDER BY s.ID DESC
    );

    IF (@InvoiceScheduleId IS NULL)
        THROW 60005, 'InvoiceSchedule not found for provided Guid.', 1;

    IF (@OverwriteExisting = 0)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceScheduleMonthConfiguration mc
            WHERE mc.RowStatus NOT IN (0,254)
              AND mc.InvoiceScheduleId = @InvoiceScheduleId
        )
        BEGIN
            ;THROW 60006, 'Monthly schedule rows already exist. Use OverwriteExisting=1 to regenerate.', 1;
        END
    END

    BEGIN TRAN;

    UPDATE SFin.InvoiceSchedules
    SET Frequency = @Frequency
    WHERE ID = @InvoiceScheduleId;

    IF (@OverwriteExisting = 1)
    BEGIN
        UPDATE mc
        SET mc.RowStatus = 254
        FROM SFin.InvoiceScheduleMonthConfiguration mc
        WHERE mc.RowStatus NOT IN (0,254)
          AND mc.InvoiceScheduleId = @InvoiceScheduleId;
    END

    -- Total month span covered by the date range (used to derive how many
    -- periods fit at the chosen frequency)
    DECLARE @TotalMonthSpan INT = DATEDIFF(MONTH, @StartDate, @EndDate) + 1;
    IF (@TotalMonthSpan <= 0)
        THROW 60007, 'Invalid month span.', 1;

    DECLARE @BaseDay INT = DAY(@StartDate);

    -- Number of periods at the given frequency.
    --  * Monthly: the final period lands exactly on @EndDate (original requirement).
    --  * [CYB-279] Bi-monthly / Quarterly / Bi-annual: keep the cadence from @StartDate and stop at
    --    the last cadence date on or before @EndDate. Pinning the final invoice to @EndDate gave
    --    uneven gaps (Quarterly 01/11/2026 - 01/10/2027 produced Nov, Feb, May, Oct).
    DECLARE @PeriodsCount INT = ((@TotalMonthSpan - 1) / @StepMonths) + 1;

    IF (@StepMonths > 1)
    BEGIN
        DECLARE @LastAnchor   DATE = DATEADD(MONTH, (@PeriodsCount - 1) * @StepMonths, @StartDate);
        DECLARE @LastDay      INT  = CASE WHEN @BaseDay > DAY(EOMONTH(@LastAnchor)) THEN DAY(EOMONTH(@LastAnchor)) ELSE @BaseDay END;

        -- Same month as @EndDate but a later day of month: that cadence date is past the end.
        IF (DATEFROMPARTS(YEAR(@LastAnchor), MONTH(@LastAnchor), @LastDay) > @EndDate)
            SET @PeriodsCount -= 1;
    END

    IF (@PeriodsCount <= 0)
        THROW 60007, 'Invalid month span.', 1;

    DECLARE @BaseAmount DECIMAL(19,2) = ROUND(@TotalValueNet / @PeriodsCount, 2);
    DECLARE @LastAmount DECIMAL(19,2) = ROUND(@TotalValueNet - (@BaseAmount * (@PeriodsCount - 1)), 2);

    DECLARE @i INT = 0;

    WHILE (@i < @PeriodsCount)
    BEGIN
        DECLARE @PeriodNumber INT = @i + 1;

        DECLARE @InvoiceDate DATE;

        IF (@i = @PeriodsCount - 1 AND @StepMonths = 1)
        BEGIN
            -- Requirement (Monthly): final invoice is exactly the EndDate provided
            SET @InvoiceDate = @EndDate;
        END
        ELSE
        BEGIN
            -- Clamp to end-of-month if base day doesn't exist (31st -> Feb 28/29)
            DECLARE @MonthAnchor DATE = DATEADD(MONTH, @i * @StepMonths, @StartDate);
            DECLARE @EomDay INT = DAY(EOMONTH(@MonthAnchor));
            DECLARE @DayToUse INT = CASE WHEN @BaseDay > @EomDay THEN @EomDay ELSE @BaseDay END;

            SET @InvoiceDate = DATEFROMPARTS(YEAR(@MonthAnchor), MONTH(@MonthAnchor), @DayToUse);
        END

        DECLARE @Amount DECIMAL(19,2) = CASE WHEN @i = @PeriodsCount - 1 THEN @LastAmount ELSE @BaseAmount END;

        DECLARE @RowGuid UNIQUEIDENTIFIER = NEWID();

        -- DataObject row (EntityTypeId = 201)
        INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
        VALUES (@RowGuid, 1, 201);

        INSERT INTO SFin.InvoiceScheduleMonthConfiguration
        (
              RowStatus
            , Guid
            , InvoiceScheduleId
            , PeriodNumber
            , Amount
            , OnDayOfMonth
            , Description
        )
        VALUES
        (
              1
            , @RowGuid
            , @InvoiceScheduleId
            , @PeriodNumber
            , @Amount
            , @InvoiceDate
            , N''
        );

        SET @i += 1;
    END

    COMMIT;

    SELECT
          InsertedCount = @PeriodsCount
        , MonthsCount  = @PeriodsCount
        
END
GO
SELECT CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SFin.InvoiceScheduleMonthConfiguration_GenerateMonthlySeries')) LIKE N'%CYB-279%' THEN 'OK' ELSE 'CHECK' END AS CadenceUpdated;
GO
