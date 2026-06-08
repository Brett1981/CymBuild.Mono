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
        @HasCreatedJob BIT = 0;

    SELECT
        @InvoiceScheduleId = ins.ID
    FROM SFin.InvoiceSchedules AS ins
    WHERE ins.Guid = @InvoiceScheduleGuid
      AND ins.RowStatus NOT IN (0,254);

    SELECT
        @InvoiceScheduleMonthConfigurationEntityTypeGuid = et.Guid
    FROM SCore.EntityTypes AS et
    WHERE et.Name = N'Invoice Schedule Month Configuration'
      AND et.RowStatus NOT IN (0,254);

    IF (@BypassReadOnlyForAutomationReenable = 0)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceScheduleMonthConfiguration AS imc
            INNER JOIN SFin.InvoiceSchedules AS invsc
                ON invsc.ID = imc.InvoiceScheduleId
               AND invsc.RowStatus NOT IN (0,254)
            INNER JOIN SSop.Quotes AS q
                ON q.ID = invsc.QuoteId
               AND q.RowStatus NOT IN (0,254)
            INNER JOIN SSop.QuoteItems AS qi
                ON qi.QuoteId = q.ID
               AND qi.RowStatus NOT IN (0,254)
               AND qi.CreatedJobId > 0
            INNER JOIN SJob.Jobs AS j
                ON j.ID = qi.CreatedJobId
               AND j.RowStatus NOT IN (0,254)
            WHERE imc.InvoiceScheduleId = @InvoiceScheduleId
              AND imc.RowStatus NOT IN (0,254)
			  AND qi.InvoicingSchedule = imc.ID
			
        )
        BEGIN
            SET @HasCreatedJob = 1;
        END;

		

        IF (@HasCreatedJob = 1)
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
                N'This month configuration is read-only because a Job has already been created from the related Quote Item.'
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
          AND ismc.RowStatus NOT IN (0,254)
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