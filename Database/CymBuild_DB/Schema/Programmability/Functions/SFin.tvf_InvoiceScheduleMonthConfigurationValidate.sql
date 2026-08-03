SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SFin].[tvf_InvoiceScheduleMonthConfigurationValidate]')
GO

CREATE FUNCTION [SFin].[tvf_InvoiceScheduleMonthConfigurationValidate]
(
    @Guid                                   UNIQUEIDENTIFIER,
    @OnDayOfMonth                           DATE,
    @PeriodNumber                           INT,
    @Amount                                 DECIMAL(19,2),
    @InvoiceScheduleGuid                    UNIQUEIDENTIFIER,
    @BypassReadOnlyForAutomationReenable    BIT
)
RETURNS @ValidationResult TABLE
(
    ID INT IDENTITY(1, 1) NOT NULL,
    TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
    TargetType CHAR(1) NOT NULL DEFAULT (''),
    IsReadOnly BIT NOT NULL DEFAULT ((0)),
    IsHidden BIT NOT NULL DEFAULT ((0)),
    IsInvalid BIT NOT NULL DEFAULT ((0)),
    IsInformationOnly BIT NOT NULL DEFAULT ((0)),
    Message NVARCHAR(2000) NOT NULL DEFAULT ('')
)
AS
BEGIN
    DECLARE
        @InvoiceScheduleId INT,
        @InvoiceScheduleMonthConfigurationEntityTypeGuid UNIQUEIDENTIFIER,
        @HasNonAutomatedCreatedJob BIT = 0,
        @AutomatedInvoiceProcessingMode TINYINT = 0;

    SELECT
        @InvoiceScheduleId = ins.ID
    FROM SFin.InvoiceSchedules AS ins
    WHERE ins.Guid = @InvoiceScheduleGuid
      AND ins.RowStatus <> 0
      AND ins.RowStatus <> 254;

    SELECT
        @InvoiceScheduleMonthConfigurationEntityTypeGuid = et.Guid
    FROM SCore.EntityTypes AS et
    WHERE et.Name = N'Invoice Schedule Month Configuration'
      AND et.RowStatus <> 0
      AND et.RowStatus <> 254;

    /*
        CYB-464:
        Monthly drawdowns may be amended directly while every related active Job
        remains in Automated invoicing mode. Manual/Paused Jobs retain the original
        read-only behaviour unless the approved automation re-enable review explicitly
        supplies @BypassReadOnlyForAutomationReenable = 1.
    */
    IF (@BypassReadOnlyForAutomationReenable = 0)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceSchedules AS invsc
            INNER JOIN SSop.Quotes AS q
                ON q.ID = invsc.QuoteId
               AND q.RowStatus <> 0
               AND q.RowStatus <> 254
            INNER JOIN SSop.QuoteItems AS qi
                ON qi.QuoteId = q.ID
               AND qi.InvoicingSchedule = invsc.ID
               AND qi.CreatedJobId > 0
               AND qi.RowStatus <> 0
               AND qi.RowStatus <> 254
            INNER JOIN SJob.Jobs AS j
                ON j.ID = qi.CreatedJobId
               AND j.RowStatus <> 0
               AND j.RowStatus <> 254
            WHERE invsc.ID = @InvoiceScheduleId
              AND invsc.RowStatus <> 0
              AND invsc.RowStatus <> 254
              AND j.InvoiceProcessingMode <> @AutomatedInvoiceProcessingMode
        )
        BEGIN
            SET @HasNonAutomatedCreatedJob = 1;
        END;

        IF (@HasNonAutomatedCreatedJob = 1)
        BEGIN
            INSERT INTO @ValidationResult
            (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                IsInformationOnly,
                Message
            )
            VALUES
            (
                ISNULL(@InvoiceScheduleMonthConfigurationEntityTypeGuid, '00000000-0000-0000-0000-000000000000'),
                N'E',
                1,
                0,
                0,
                1,
                N'This month configuration is read-only because a related Job is not in Automated invoicing mode.'
            );
        END;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM SFin.InvoiceScheduleMonthConfiguration AS ismc
        WHERE ismc.InvoiceScheduleId = @InvoiceScheduleId
          AND ismc.Guid <> @Guid
          AND ismc.PeriodNumber = @PeriodNumber
          AND ismc.RowStatus <> 0
          AND ismc.RowStatus <> 254
    )
    BEGIN
        INSERT INTO @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        SELECT
            epfvv.Guid,
            N'P',
            0,
            0,
            1,
            N'Period has already been defined!'
        FROM SCore.EntityPropertiesForValidationV AS epfvv
        WHERE epfvv.[Schema] = N'SFin'
          AND epfvv.Hobt = N'InvoiceScheduleMonthConfiguration'
          AND epfvv.Name = N'PeriodNumber';
    END;

    RETURN;
END;
GO
