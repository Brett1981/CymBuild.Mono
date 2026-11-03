SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter function [SFin].[tvf_Transactions_ReadyForSageSubmission]')
GO

CREATE OR ALTER FUNCTION [SFin].[tvf_Transactions_ReadyForSageSubmission]
(
    @SinceUtc DATETIME2(7) = NULL
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
(
    SELECT
        t.ID,
        t.Guid,
        t.Number AS InvoiceNumber,
        t.Batched,
        t.RowStatus,
        t.RowVersion,
        t.JobID,
        t.AccountID,
        t.OrganisationalUnitId,
        t.SageTransactionReference
    FROM SFin.Transactions AS t
    INNER JOIN SFin.TransactionTypes AS tt
        ON tt.ID = t.TransactionTypeID
       AND tt.RowStatus NOT IN (0, 254)
       AND tt.IsActive = 1
    WHERE
            t.RowStatus NOT IN (0, 254)
        AND t.Batched = 0
        AND tt.IsBank = 0
        AND UPPER(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(tt.Name)), N' ', N''), N'-', N''), N'_', N''))
            = N'INVOICE'
        AND NULLIF(LTRIM(RTRIM(t.Number)), N'') IS NOT NULL
        AND (
                @SinceUtc IS NULL
                OR t.CreatedDateTimeUTC >= @SinceUtc
            )
        AND NOT EXISTS
        (
            SELECT 1
            FROM SFin.SageExportTransactions AS setx
            WHERE   setx.TransactionID = t.ID
                AND setx.RowStatus NOT IN (0, 254)
        )
);
GO
