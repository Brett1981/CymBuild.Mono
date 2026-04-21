SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SFin].[MarkLegacySageExportsAsBatched] 
AS
BEGIN
/*
    Purpose:
        Marks transactions as batched where they have not been exported to Sage.

    Description:
        This procedure identifies invoice transactions that have no Sage export
        reference and are not present in the SageExportTransactions table, meaning
        they have not been exported via either the legacy process.

        These transactions are then marked as Batched = 1 to exclude them from
        future export runs.

    Notes:
        - Only transactions not already linked to a Sage export are considered.
        - Only applies to invoice transactions.
        - Excludes rows with RowStatus values of 0 and 254.
        - Only includes records with no LegacyId.
        - Acts as a safeguard to prevent unintended export of transactions that
          should not be sent to Sage.

    Usage:
        Execute as a one-off or maintenance task to ensure non-exportable
        transactions are excluded from Sage export processing.
*/


	--Create table for holding older transactions that were exported.
	CREATE TABLE #LegacySageExports (
		ID INT
	);

	--Get all records where SageTransactionReference <> N''
	INSERT INTO #LegacySageExports
		SELECT t.ID
		FROM SFin.Transactions AS t 
		JOIN	SFin.TransactionTypes AS tt ON (tt.ID = t.TransactionTypeID)
		WHERE 
			 (t.RowStatus NOT IN (0,254))
		AND (t.LegacyId IS NULL)
		AND  (t.Batched = 0)
		AND  (tt.Name = N'Invoice')
		AND  (t.SageTransactionReference = N'')
		AND (NOT EXISTS
			(
				SELECT	1
				FROM	SFin.SageExportTransactions AS e
				WHERE	(e.TransactionID = t.ID)
					AND (e.RowStatus NOT IN (0, 254))
			))


	--Iterate over the collection & mark them as batched. 
	WHILE EXISTS (SELECT 1 FROM #LegacySageExports)
		BEGIN

			DECLARE @CurrentTransaction INT;

			SELECT @CurrentTransaction = ID
			FROM #LegacySageExports;

			UPDATE SFin.Transactions
			SET Batched = 1
			WHERE ID = @CurrentTransaction;

			DELETE FROM #LegacySageExports 
			WHERE ID = @CurrentTransaction;
		END;

	PRINT(N'Legacy transactions have beeen marked as batched.');

END;
GO