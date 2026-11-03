/*
    CYB-568: correct Sage-materialised Receipts / Credit Notes that were stored
    with the wrong value and date.

    Two defects, both fixed in source:
      1. Date  - SageInboundPaymentSyncService parsed UK dd/MM/yyyy dates as US
                 MM/dd, so 04/09/2026 (4 Sep) was stored as 9 Apr.
      2. Value - SFin.SageInboundReceiptAndAllocation_Materialise passed the
                 VAT-inclusive receipt amount as Net, and TransactionDetailsUpsert
                 then added VAT again (1440 -> Net 1440 / VAT 288 / Gross 1728).

    This script:
      a. Re-derives SFin.SageExternalTransactions.TransactionDate from the stored
         RawPayloadJson (ISO first, otherwise UK style 103), for every Sage row.
      b. Re-runs the corrected materialise procedure for every already-
         materialised Invoice-fallback (4) / Credit Note (5) / Receipt (6)
         whose date or net is wrong. Type 4 matters most: the production Sage
         source only flips IsPaid/AllocatedValue on the invoice's own row, so
         nearly every Sage receipt comes from a type 4 row. For type 4 the
         correct net is AllocatedValue (VAT-inclusive cash) back-calculated at
         the invoice VAT rate, exactly as the procedure does.
         The procedure reuses the existing receipt, detail and allocation Guids,
         so this updates rows in place - it never creates duplicates.

    Prerequisites: the CYB-568 version of
    SFin.SageInboundReceiptAndAllocation_Materialise must already be deployed.

    Safe to re-run: rows already correct are not selected.
    Default is @DryRun = 1 (preview only). Set @DryRun = 0 to apply.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @DryRun BIT = 1;

-- The marker is inside the procedure body. The procedure's header comment is in
-- an earlier batch (before GO), so OBJECT_DEFINITION never contains it.
IF ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'SFin.SageInboundReceiptAndAllocation_Materialise')), N'') NOT LIKE N'%CYB-568-VAT-EXCLUSIVE-NET%'
BEGIN
    ;THROW 60568, N'Deploy the CYB-568 version of SFin.SageInboundReceiptAndAllocation_Materialise before running this script.', 1;
END;

DROP TABLE IF EXISTS #Cyb568Dates;
DROP TABLE IF EXISTS #Cyb568Receipts;

/* ---- a. Correct external-transaction dates from the raw Sage payload ---- */

SELECT
    ext.ID                  AS ExternalTransactionID,
    ext.SageTransactionTypeCode,
    ext.TransactionDate     AS StoredDate,
    raw.RawDate,
    CASE
        WHEN raw.RawDate LIKE N'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]%'
            THEN TRY_CONVERT(DATE, LEFT(raw.RawDate, 10), 23)
        ELSE TRY_CONVERT(DATE, LEFT(raw.RawDate, CHARINDEX(N' ', raw.RawDate + N' ') - 1), 103)
    END                     AS CorrectDate
INTO #Cyb568Dates
FROM SFin.SageExternalTransactions AS ext
CROSS APPLY
(
    SELECT RawDate = LTRIM(RTRIM(COALESCE(
        JSON_VALUE(CASE WHEN ISJSON(ext.RawPayloadJson) = 1 THEN ext.RawPayloadJson END, N'$.transactionDate'),
        JSON_VALUE(CASE WHEN ISJSON(ext.RawPayloadJson) = 1 THEN ext.RawPayloadJson END, N'$.TransactionDate'))))
) AS raw
WHERE ext.RowStatus NOT IN (0,254)
  AND NULLIF(raw.RawDate, N'') IS NOT NULL;

/* ---- b. Materialised Credit Notes / Receipts whose date or net is wrong ---- */

SELECT
    ext.ID                              AS ExternalTransactionID,
    ext.SageTransactionTypeCode,
    ext.SageTransactionReference,
    rcpt.ID                             AS ReceiptTransactionID,
    rcpt.Number                         AS ReceiptNumber,
    rcpt.[Date]                         AS CurrentReceiptDate,
    COALESCE(d.CorrectDate, ext.TransactionDate, inv.[Date]) AS CorrectReceiptDate,
    td.Net                              AS CurrentNet,
    td.Vat                              AS CurrentVat,
    td.Gross                            AS CurrentGross,
    invRates.DistinctVatRates,
    CONVERT(DECIMAL(18,2),
        CASE
            -- Type 4 fallback: the row's net/tax are the invoice's own values,
            -- so the receipt is the allocated cash (VAT-inclusive).
            WHEN ext.SageTransactionTypeCode = 4
                THEN ROUND(ABS(ISNULL(ext.AllocatedValue, 0)) * 100.0 / (100.0 + invVat.VatPercentage), 2)
            WHEN ABS(ISNULL(ext.TaxAmount, 0)) > 0
                THEN CASE WHEN ABS(ISNULL(ext.NetAmount, 0)) > 0
                          THEN ABS(ext.NetAmount)
                          ELSE ABS(ISNULL(ext.AllocatedValue, 0)) - ABS(ext.TaxAmount) END
            ELSE ROUND(
                    CASE WHEN ABS(ISNULL(ext.NetAmount, 0)) > 0
                         THEN ABS(ext.NetAmount)
                         ELSE ABS(ISNULL(ext.AllocatedValue, 0)) END
                    * 100.0 / (100.0 + invVat.VatPercentage), 2)
        END)                            AS CorrectNet
INTO #Cyb568Receipts
FROM SFin.SageExternalTransactions AS ext
JOIN SFin.Transactions AS rcpt
    ON rcpt.ID = ext.MaterialisedReceiptTransactionID
   AND rcpt.RowStatus NOT IN (0,254)
JOIN SFin.Transactions AS inv
    ON inv.ID = ext.MatchedTransactionID
   AND inv.RowStatus NOT IN (0,254)
OUTER APPLY
(
    SELECT TOP (1) td2.Net, td2.Vat, td2.Gross
    FROM SFin.TransactionDetails AS td2
    WHERE td2.TransactionID = rcpt.ID
      AND td2.RowStatus NOT IN (0,254)
    ORDER BY td2.ID DESC
) AS td
OUTER APPLY
(
    -- Same VAT code the materialise procedure uses: the invoice's first line.
    SELECT TOP (1) vc.VatPercentage
    FROM SFin.TransactionDetails AS itd
    JOIN SFin.VatCodes AS vc
        ON vc.ID = itd.VatCodeID
       AND vc.RowStatus NOT IN (0,254)
       AND vc.Active = 1
    WHERE itd.TransactionID = inv.ID
      AND itd.RowStatus NOT IN (0,254)
    ORDER BY itd.ID
) AS invVat
OUTER APPLY
(
    -- VAT-code safety: the net is back-calculated at ONE rate (the invoice's
    -- first line, as the procedure does). An invoice whose lines carry more
    -- than one VAT rate (e.g. standard + zero-rated or reverse charge) cannot
    -- be split correctly that way, so it is skipped and listed for a manual
    -- check instead of being guessed.
    SELECT DistinctVatRates = COUNT(DISTINCT vc2.VatPercentage)
    FROM SFin.TransactionDetails AS itd2
    JOIN SFin.VatCodes AS vc2
        ON vc2.ID = itd2.VatCodeID
    WHERE itd2.TransactionID = inv.ID
      AND itd2.RowStatus NOT IN (0,254)
) AS invRates
LEFT JOIN #Cyb568Dates AS d
    ON d.ExternalTransactionID = ext.ID
WHERE ext.RowStatus NOT IN (0,254)
  AND ext.SageTransactionTypeCode IN (4, 5, 6)
  -- The procedure ignores a type 4 row once a genuine 5/6 row is matched to
  -- the same invoice, so re-running it for that row would change nothing.
  AND NOT
  (
      ext.SageTransactionTypeCode = 4
      AND EXISTS
      (
          SELECT 1
          FROM SFin.SageExternalTransactions AS distinctSource
          WHERE distinctSource.RowStatus NOT IN (0,254)
            AND distinctSource.SageTransactionTypeCode IN (5, 6)
            AND distinctSource.MatchedTransactionID = ext.MatchedTransactionID
      )
  )
  AND invVat.VatPercentage IS NOT NULL;

DELETE r
FROM #Cyb568Receipts AS r
WHERE r.CurrentReceiptDate = r.CorrectReceiptDate
  AND r.CurrentNet = r.CorrectNet;

-- Mixed-VAT-rate invoices: reported, never corrected automatically.
DROP TABLE IF EXISTS #Cyb568MixedVat;

SELECT r.*
INTO #Cyb568MixedVat
FROM #Cyb568Receipts AS r
WHERE ISNULL(r.DistinctVatRates, 0) <> 1;

DELETE r
FROM #Cyb568Receipts AS r
WHERE ISNULL(r.DistinctVatRates, 0) <> 1;

/* ---- Preview ---- */

SELECT
    DatesToCorrect    = (SELECT COUNT(1) FROM #Cyb568Dates AS d
                         WHERE d.CorrectDate IS NOT NULL
                           AND ISNULL(d.StoredDate, '19000101') <> d.CorrectDate),
    UnparseableDates  = (SELECT COUNT(1) FROM #Cyb568Dates AS d WHERE d.CorrectDate IS NULL),
    ReceiptsToCorrect = (SELECT COUNT(1) FROM #Cyb568Receipts),
    SkippedMixedVat   = (SELECT COUNT(1) FROM #Cyb568MixedVat);

-- Skipped because the invoice's lines carry more than one VAT rate: check these by hand.
SELECT
    m.ExternalTransactionID, m.SageTransactionReference, m.ReceiptNumber,
    m.CurrentNet, m.CurrentVat, m.CurrentGross, m.DistinctVatRates
FROM #Cyb568MixedVat AS m
ORDER BY m.ExternalTransactionID;

SELECT
    d.ExternalTransactionID, d.SageTransactionTypeCode, d.RawDate, d.StoredDate, d.CorrectDate
FROM #Cyb568Dates AS d
WHERE d.CorrectDate IS NULL
   OR ISNULL(d.StoredDate, '19000101') <> d.CorrectDate
ORDER BY d.ExternalTransactionID;

SELECT
    r.ExternalTransactionID, r.SageTransactionTypeCode, r.SageTransactionReference,
    r.ReceiptTransactionID, r.ReceiptNumber,
    r.CurrentReceiptDate, r.CorrectReceiptDate,
    r.CurrentNet, r.CurrentVat, r.CurrentGross, r.CorrectNet
FROM #Cyb568Receipts AS r
ORDER BY r.ExternalTransactionID;

IF @DryRun = 1
BEGIN
    PRINT N'CYB-568 dry run only. Review the rows above, then set @DryRun = 0 to apply.';
    RETURN;
END;

/* ---- Apply ---- */

UPDATE ext
SET
    TransactionDate    = d.CorrectDate,
    UpdatedDateTimeUTC = GETUTCDATE()
FROM SFin.SageExternalTransactions AS ext
JOIN #Cyb568Dates AS d
    ON d.ExternalTransactionID = ext.ID
WHERE ext.RowStatus NOT IN (0,254)
  AND d.CorrectDate IS NOT NULL
  AND ISNULL(ext.TransactionDate, '19000101') <> d.CorrectDate;

PRINT CONCAT(N'CYB-568: corrected ', @@ROWCOUNT, N' Sage external transaction date(s).');

DECLARE
    @ExternalTransactionID BIGINT,
    @Corrected INT = 0,
    @Failed INT = 0;

DECLARE receipt_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT r.ExternalTransactionID
    FROM #Cyb568Receipts AS r
    ORDER BY r.ExternalTransactionID;

OPEN receipt_cursor;
FETCH NEXT FROM receipt_cursor INTO @ExternalTransactionID;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC SFin.SageInboundReceiptAndAllocation_Materialise
            @ExternalTransactionID = @ExternalTransactionID;

        COMMIT TRANSACTION;
        SET @Corrected += 1;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @Failed += 1;
        PRINT CONCAT(N'CYB-568: external transaction ', @ExternalTransactionID, N' failed: ', ERROR_MESSAGE());
    END CATCH;

    FETCH NEXT FROM receipt_cursor INTO @ExternalTransactionID;
END;

CLOSE receipt_cursor;
DEALLOCATE receipt_cursor;

PRINT CONCAT(N'CYB-568: re-materialised ', @Corrected, N' receipt(s); ', @Failed, N' failed.');

/* ---- Verify: should return no rows ---- */

SELECT
    r.ExternalTransactionID, r.ReceiptNumber,
    t.[Date] AS ReceiptDate, r.CorrectReceiptDate,
    td.Net, r.CorrectNet
FROM #Cyb568Receipts AS r
JOIN SFin.Transactions AS t
    ON t.ID = r.ReceiptTransactionID
OUTER APPLY
(
    SELECT TOP (1) td2.Net
    FROM SFin.TransactionDetails AS td2
    WHERE td2.TransactionID = t.ID
      AND td2.RowStatus NOT IN (0,254)
    ORDER BY td2.ID DESC
) AS td
WHERE t.[Date] <> r.CorrectReceiptDate
   OR td.Net <> r.CorrectNet;
