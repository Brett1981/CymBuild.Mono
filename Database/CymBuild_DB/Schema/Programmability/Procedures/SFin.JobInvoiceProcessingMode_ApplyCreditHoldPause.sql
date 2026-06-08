SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[JobInvoiceProcessingMode_ApplyCreditHoldPause]')
GO
CREATE PROCEDURE [SFin].[JobInvoiceProcessingMode_ApplyCreditHoldPause]
(
    @FinanceAccountId INT
)
AS
BEGIN
    SET NOCOUNT ON;

    -- Ensure the account is actually on hold
    IF NOT EXISTS
    (
        SELECT 1
        FROM SCrm.Accounts a
        JOIN SCrm.AccountStatus st ON st.ID = a.AccountStatusID
        WHERE a.ID = @FinanceAccountId
          AND ISNULL(st.IsHold, 0) = 1
    )
        RETURN;

    -- Pause only jobs that are currently Automated (0). Leave Manual/Pause untouched.
    UPDATE j
    SET
          j.InvoiceProcessingMode = 2            -- Paused
        , j.ManualInvoicingEnabled = 1          -- legacy sync
        , j.InvoicingPausedByCreditHold = 1     -- marker
    FROM SJob.Jobs j
    WHERE j.RowStatus NOT IN (0,254)
      AND j.FinanceAccountID = @FinanceAccountId
      AND j.InvoiceProcessingMode = 0;          -- Automated only
END
GO