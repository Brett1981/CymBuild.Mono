SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[QuoteCreateJobsStageScheduleAssert]')
GO
PRINT (N'Create procedure [SSop].[QuoteCreateJobsStageScheduleAssert]')
GO


CREATE PROCEDURE [SSop].[QuoteCreateJobsStageScheduleAssert]
(
    @Guid UNIQUEIDENTIFIER,
    @AllowQuoteItemStageFallback BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @BlockingMessage NVARCHAR(2000) = N'';
    DECLARE @WarningMessage NVARCHAR(2000) = N'';

    IF NOT EXISTS
    (
        SELECT 1
        FROM SSop.Quotes AS q
        JOIN SSop.QuoteItems AS qi
            ON qi.QuoteId = q.ID
           AND qi.RowStatus NOT IN (0,254)
           AND qi.Quantity > 0
        WHERE q.Guid = @Guid
          AND q.RowStatus NOT IN (0,254)
          AND ISNULL(qi.InvoicingSchedule, -1) > 0
          AND
          (
              EXISTS
              (
                  SELECT 1
                  FROM SFin.InvoiceScheduleMonthConfiguration AS mc
                  WHERE mc.InvoiceScheduleId = qi.InvoicingSchedule
                    AND mc.RowStatus NOT IN (0,254)
              )
              OR EXISTS
              (
                  SELECT 1
                  FROM SFin.InvoiceSchedulePercentageConfiguration AS pc
                  WHERE pc.InvoiceScheduleId = qi.InvoicingSchedule
                    AND pc.RowStatus NOT IN (0,254)
              )
          )
    )
    BEGIN
        RETURN;
    END;

    SELECT
        @BlockingMessage = @BlockingMessage
            + CASE WHEN @BlockingMessage = N'' THEN N'' ELSE N'; ' END
            + v.StageName
            + N' - Quote Item total '
            + CONVERT(NVARCHAR(50), CONVERT(DECIMAL(19, 2), v.QuoteItemStageTotal))
            + N', Invoice Schedule total '
            + CONVERT(NVARCHAR(50), CONVERT(DECIMAL(19, 2), ISNULL(v.InvoiceScheduleStageTotal, 0.00)))
    FROM SSop.tvf_QuoteCreateJobsStageScheduleValidation(@Guid) AS v
    WHERE v.SeverityCode = N'B';

    IF @BlockingMessage <> N''
    BEGIN
        SET @BlockingMessage = N'The total of the Invoice Schedule must be equal to the total of the Quote Item(s) before conversion to a Job. '
            + N'Please correct the following total(s): '
            + @BlockingMessage;

        ;THROW 60000, @BlockingMessage, 1;
    END;

    IF ISNULL(@AllowQuoteItemStageFallback, 0) = 0
    BEGIN
        SELECT
            @WarningMessage = @WarningMessage
                + CASE WHEN @WarningMessage = N'' THEN N'' ELSE N', ' END
                + v.StageName
        FROM SSop.tvf_QuoteCreateJobsStageScheduleValidation(@Guid) AS v
        WHERE v.SeverityCode = N'W'
          AND v.ValidationCode = N'QuoteItemStageMissingFromInvoiceSchedule';

        IF @WarningMessage <> N''
        BEGIN
            SET @WarningMessage = N'The quote item stage is not in the Invoice schedule, do you want to continue? Missing stage(s): '
                + @WarningMessage;

            ;THROW 60001, @WarningMessage, 1;
        END;
    END;
END;

GO