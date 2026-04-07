USE [CymBuild_Dev]
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
    WHERE
            t.RowStatus NOT IN (0, 254)
        AND t.Batched = 0
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