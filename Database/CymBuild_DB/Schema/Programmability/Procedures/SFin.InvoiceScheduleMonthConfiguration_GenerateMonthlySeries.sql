SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceScheduleMonthConfiguration_GenerateMonthlySeries]')
GO

CREATE PROCEDURE [SFin].[InvoiceScheduleMonthConfiguration_GenerateMonthlySeries]
(
      @InvoiceScheduleGuid   UNIQUEIDENTIFIER
    , @StartDate             DATE
    , @EndDate               DATE
    , @TotalValueNet         DECIMAL(19,2)
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

    IF (@OverwriteExisting = 1)
    BEGIN
        UPDATE mc
        SET mc.RowStatus = 254
        FROM SFin.InvoiceScheduleMonthConfiguration mc
        WHERE mc.RowStatus NOT IN (0,254)
          AND mc.InvoiceScheduleId = @InvoiceScheduleId;
    END

    DECLARE @MonthsCount INT = DATEDIFF(MONTH, @StartDate, @EndDate) + 1;
    IF (@MonthsCount <= 0)
        THROW 60007, 'Invalid month span.', 1;

    DECLARE @BaseDay INT = DAY(@StartDate);

    DECLARE @BaseAmount DECIMAL(19,2) = ROUND(@TotalValueNet / @MonthsCount, 2);
    DECLARE @LastAmount DECIMAL(19,2) = ROUND(@TotalValueNet - (@BaseAmount * (@MonthsCount - 1)), 2);

    DECLARE @i INT = 0;

    WHILE (@i < @MonthsCount)
    BEGIN
        DECLARE @PeriodNumber INT = @i + 1;

        DECLARE @InvoiceDate DATE;

        IF (@i = @MonthsCount - 1)
        BEGIN
            -- Requirement: final invoice is exactly the EndDate provided
            SET @InvoiceDate = @EndDate;
        END
        ELSE
        BEGIN
            -- Clamp to end-of-month if base day doesn't exist (31st -> Feb 28/29)
            DECLARE @MonthAnchor DATE = DATEADD(MONTH, @i, @StartDate);
            DECLARE @EomDay INT = DAY(EOMONTH(@MonthAnchor));
            DECLARE @DayToUse INT = CASE WHEN @BaseDay > @EomDay THEN @EomDay ELSE @BaseDay END;

            SET @InvoiceDate = DATEFROMPARTS(YEAR(@MonthAnchor), MONTH(@MonthAnchor), @DayToUse);
        END

        DECLARE @Amount DECIMAL(19,2) = CASE WHEN @i = @MonthsCount - 1 THEN @LastAmount ELSE @BaseAmount END;

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
          InsertedCount = @MonthsCount
        , MonthsCount   = @MonthsCount;
END
GO