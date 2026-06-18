USE [CymBuild_Upgrade_Stage]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER FUNCTION [SFin].[tvf_QuoteInvoiceSchedules]
(
      @UserId INT
    , @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN
SELECT
      invs.ID
    , invs.RowStatus
    , invs.RowVersion
    , invs.Guid
    , invs.Name
    , invs.DescriptionOfWork
    , CAST
      (
          CASE
              WHEN monthly_totals.MonthlyRowCount > 0
                  THEN monthly_totals.MonthlyTotalAmount

              WHEN percentage_totals.PercentageRowCount > 0
                  THEN
                      (
                          COALESCE
                          (
                              NULLIF(quote_item_totals.QuoteItemTotalAmount, 0.00),
                              invs.Amount,
                              0.00
                          )
                          * percentage_totals.PercentageTotalPercentage
                      ) / 100.00

              ELSE ISNULL(invs.Amount, 0.00)
          END
          AS DECIMAL(19, 2)
      ) AS Amount
    , ist.Name AS TriggerId
    , invs.ExpectedDate
FROM SFin.InvoiceSchedules AS invs
JOIN SSop.Quotes AS q
    ON q.ID = invs.QuoteId
   AND q.RowStatus NOT IN (0, 254)
JOIN SFin.InvoiceScheduleTrigger AS ist
    ON ist.ID = invs.TriggerId
   AND ist.RowStatus NOT IN (0, 254)
OUTER APPLY
(
    SELECT
          COUNT_BIG(1) AS MonthlyRowCount
        , CAST(ISNULL(SUM(month_config.Amount), 0.00) AS DECIMAL(19, 2)) AS MonthlyTotalAmount
    FROM SFin.InvoiceScheduleMonthConfiguration AS month_config
    WHERE month_config.RowStatus NOT IN (0, 254)
      AND month_config.InvoiceScheduleId = invs.ID
) AS monthly_totals
OUTER APPLY
(
    SELECT
          COUNT_BIG(1) AS PercentageRowCount
        , CAST(ISNULL(SUM(percentage_config.Percentage), 0.00) AS DECIMAL(19, 2)) AS PercentageTotalPercentage
    FROM SFin.InvoiceSchedulePercentageConfiguration AS percentage_config
    WHERE percentage_config.RowStatus NOT IN (0, 254)
      AND percentage_config.InvoiceScheduleId = invs.ID
) AS percentage_totals
OUTER APPLY
(
    SELECT
        CAST(ISNULL(SUM(qit.LineNet), 0.00) AS DECIMAL(19, 2)) AS QuoteItemTotalAmount
    FROM SSop.QuoteItems AS qi
    JOIN SSop.QuoteItemTotals AS qit
        ON qit.ID = qi.ID
    WHERE qi.RowStatus NOT IN (0, 254)
      AND qi.InvoicingSchedule = invs.ID
) AS quote_item_totals
WHERE q.Guid = @ParentGuid
  AND invs.RowStatus NOT IN (0, 254)
  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurityForUser_CanRead(invs.Guid, @UserId) AS oscr
  );
GO