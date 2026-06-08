SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[JobInvoiceProcessingMode_ClearCreditHoldToManual]')
GO
CREATE PROCEDURE [SFin].[JobInvoiceProcessingMode_ClearCreditHoldToManual]
(
    @FinanceAccountId INT
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Ensure the account is actually NOT on hold
    IF EXISTS
    (
        SELECT 1
        FROM SCrm.Accounts a
        JOIN SCrm.AccountStatus st ON st.ID = a.AccountStatusID
        WHERE a.ID = @FinanceAccountId
          AND ISNULL(st.IsHold, 0) = 1
    )
        RETURN;

    -- Only revert jobs that were paused by credit hold marker.
    -- IMPORTANT: do NOT touch user-paused jobs (marker = 0).
    UPDATE j
    SET
          j.InvoiceProcessingMode = 1            -- Manual
        , j.ManualInvoicingEnabled = 1          -- keep legacy manual stop
        , j.InvoicingPausedByCreditHold = 0
    FROM SJob.Jobs j
    WHERE j.RowStatus NOT IN (0,254)
      AND j.FinanceAccountID = @FinanceAccountId
      AND j.InvoicingPausedByCreditHold = 1;
END
GO