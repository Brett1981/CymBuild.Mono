SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceScheduleMonthlyDrawdownAmendmentAssert]')
GO

CREATE PROCEDURE [SFin].[InvoiceScheduleMonthlyDrawdownAmendmentAssert]
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
