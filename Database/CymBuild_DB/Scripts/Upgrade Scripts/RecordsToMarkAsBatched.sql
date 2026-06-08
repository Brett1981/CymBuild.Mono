BEGIN TRANSACTION;

DECLARE @RecordsToMarkAsBatched TABLE
(
    TransactionID INT PRIMARY KEY
);

INSERT INTO @RecordsToMarkAsBatched
(
    TransactionID
)
SELECT
    t.ID
FROM SFin.Transactions AS t
JOIN SFin.TransactionTypes AS tt
    ON tt.ID = t.TransactionTypeID
LEFT JOIN SCore.OrganisationalUnits AS ou
    ON ou.ID = t.OrganisationalUnitId
WHERE
    tt.Name = N'Invoice'
    AND t.LegacyId IS NULL
    AND ISNULL(t.Batched, 0) = 0
    
    AND NOT EXISTS
    (
        SELECT
            1
        FROM SFin.SageExportTransactions AS e
        WHERE
            e.TransactionID = t.ID
            AND e.RowStatus NOT IN (0, 254)
    );

-- Review before update
SELECT
    t.ID,
    t.Guid,
    t.Number,
    t.Date,
    t.SageTransactionReference,
    t.Batched,
    tt.Name AS TransactionTypeName,
    ou.Name AS OrganisationalUnitName
FROM @RecordsToMarkAsBatched AS r
JOIN SFin.Transactions AS t
    ON t.ID = r.TransactionID
JOIN SFin.TransactionTypes AS tt
    ON tt.ID = t.TransactionTypeID
LEFT JOIN SCore.OrganisationalUnits AS ou
    ON ou.ID = t.OrganisationalUnitId
ORDER BY
    t.Date,
    t.Number;

-- Update only reviewed set
UPDATE t
SET
    Batched = 1
FROM SFin.Transactions AS t
JOIN @RecordsToMarkAsBatched AS r
    ON r.TransactionID = t.ID;

SELECT
    @@ROWCOUNT AS TransactionsMarkedAsBatched;

--ROLLBACK;
-- COMMIT;