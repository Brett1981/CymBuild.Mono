/*
    CYB-464 - Allow direct amendments to Automated Monthly Drawdowns

    Deployment-safe, idempotent schema script.
    Apply through the controlled CymBuild schema deployment process only.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE [SFin].[InvoiceScheduleMonthlyDrawdownAmendmentAssert]
(
    @UserId INT,
    @InvoiceScheduleGuid UNIQUEIDENTIFIER,
    @BypassReadOnlyForAutomationReenable BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @InvoiceScheduleId INT,
        @TriggerName NVARCHAR(100),
        @AutomatedInvoiceProcessingMode TINYINT = 0;

    SELECT
        @InvoiceScheduleId = invsch.ID,
        @TriggerName = triggerType.Name
    FROM SFin.InvoiceSchedules AS invsch
    INNER JOIN SFin.InvoiceScheduleTrigger AS triggerType
        ON triggerType.ID = invsch.TriggerId
       AND triggerType.RowStatus <> 0
       AND triggerType.RowStatus <> 254
    WHERE invsch.Guid = @InvoiceScheduleGuid
      AND invsch.RowStatus <> 0
      AND invsch.RowStatus <> 254;

    IF @InvoiceScheduleId IS NULL
    BEGIN
        THROW 51000, 'Invoice schedule was not found or is inactive.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanWritev AS canWrite
        WHERE canWrite.Guid = @InvoiceScheduleGuid
          AND canWrite.ID = @UserId
    )
    BEGIN
        THROW 51000, 'The current user does not have permission to amend this invoice schedule.', 1;
    END;

    IF @TriggerName <> N'Monthly Drawdowns'
    BEGIN
        THROW 51000, 'Only Monthly Drawdowns are supported by the monthly drawdown amendment operation.', 1;
    END;

    IF @BypassReadOnlyForAutomationReenable = 1
    BEGIN
        RETURN;
    END;

    /*
        CYB-464: direct amendments are allowed only when every active Job linked to
        this schedule remains in Automated invoicing mode. Quote schedules that have
        not yet created a Job retain their existing editable behaviour.
    */
    IF EXISTS
    (
        SELECT 1
        FROM SSop.QuoteItems AS qi
        INNER JOIN SJob.Jobs AS j
            ON j.ID = qi.CreatedJobId
           AND j.RowStatus <> 0
           AND j.RowStatus <> 254
        WHERE qi.InvoicingSchedule = @InvoiceScheduleId
          AND qi.CreatedJobId > 0
          AND qi.RowStatus <> 0
          AND qi.RowStatus <> 254
          AND j.InvoiceProcessingMode <> @AutomatedInvoiceProcessingMode
    )
    BEGIN
        THROW 51000, 'Monthly drawdowns can only be amended directly while every related Job is in Automated invoicing mode.', 1;
    END;
END;
GO

CREATE OR ALTER FUNCTION [SFin].[tvf_InvoiceScheduleMonthConfigurationValidate]
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

IF OBJECT_ID(N'[SFin].[InvoiceScheduleMonthlyDrawdownAmendmentAssert]', N'P') IS NULL
BEGIN
    THROW 51000, 'CYB-464 deployment validation failed: amendment assertion procedure is missing.', 1;
END;
GO

IF OBJECT_ID(N'[SFin].[tvf_InvoiceScheduleMonthConfigurationValidate]', N'TF') IS NULL
BEGIN
    THROW 51000, 'CYB-464 deployment validation failed: month configuration validation function is missing.', 1;
END;
GO
