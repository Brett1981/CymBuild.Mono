CREATE OR ALTER PROCEDURE [SFin].[SageInboundDiagnostics_ApplyTransactionReferences]
(
      @StatusGuid UNIQUEIDENTIFIER = NULL
    , @TransactionID BIGINT = NULL
    , @DryRun BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2(7) = SYSUTCDATETIME();

    ;WITH Candidate AS
    (
        SELECT
              s.ID AS InboundStatusID
            , s.Guid AS InboundStatusGuid
            , COALESCE(NULLIF(s.TransactionID, -1), ext.MatchedTransactionID) AS TargetTransactionID
            , NULLIF(LTRIM(RTRIM(s.LastSageTransactionReference)), N'') AS SageTransactionReference
            , s.SageDataset
            , s.SageAccountReference
            , s.SageDocumentNo
        FROM SFin.SageInboundDocumentStatus AS s
        OUTER APPLY
        (
            SELECT TOP (1)
                  ext.ID
                , ext.MatchedTransactionID
            FROM SFin.SageExternalTransactions AS ext
            WHERE ext.RowStatus NOT IN (0, 254)
              AND
              (
                    (
                        ext.SageDataset = s.SageDataset
                    AND ext.SageAccountReference = s.SageAccountReference
                    AND ext.SageDocumentNo = s.SageDocumentNo
                    )
                 OR (
                        ext.MatchedTransactionID = s.TransactionID
                    AND s.TransactionID > 0
                    )
                 OR (
                        ext.MatchedInvoiceRequestID = s.InvoiceRequestID
                    AND s.InvoiceRequestID > 0
                    )
              )
            ORDER BY
                CASE
                    WHEN ext.MatchedTransactionID = s.TransactionID
                         AND s.TransactionID > 0 THEN 0
                    WHEN ext.MatchedInvoiceRequestID = s.InvoiceRequestID
                         AND s.InvoiceRequestID > 0 THEN 1
                    WHEN ext.SageDataset = s.SageDataset
                     AND ext.SageAccountReference = s.SageAccountReference
                     AND ext.SageDocumentNo = s.SageDocumentNo THEN 2
                    ELSE 9
                END,
                ext.LastSeenOnUtc DESC,
                ext.ID DESC
        ) AS ext
        WHERE s.RowStatus NOT IN (0, 254)
          AND s.StatusCode IN (N'Succeeded', N'Pending', N'PartiallyPaid')
          AND NULLIF(LTRIM(RTRIM(s.LastSageTransactionReference)), N'') IS NOT NULL
          AND (@StatusGuid IS NULL OR s.Guid = @StatusGuid)
          AND (@TransactionID IS NULL OR s.TransactionID = @TransactionID OR ext.MatchedTransactionID = @TransactionID)
    )
    SELECT
          c.InboundStatusID
        , c.InboundStatusGuid
        , c.TargetTransactionID
        , t.Guid AS TransactionGuid
        , t.Number AS TransactionNumber
        , ExistingSageTransactionReference = t.SageTransactionReference
        , NewSageTransactionReference = c.SageTransactionReference
        , WouldUpdate =
            CAST
            (
                CASE
                    WHEN c.TargetTransactionID IS NULL THEN 0
                    WHEN c.TargetTransactionID <= 0 THEN 0
                    WHEN NULLIF(LTRIM(RTRIM(t.SageTransactionReference)), N'') IS NOT NULL THEN 0
                    WHEN c.SageTransactionReference IS NULL THEN 0
                    ELSE 1
                END
                AS BIT
            )
    INTO #Candidate
    FROM Candidate AS c
    INNER JOIN SFin.Transactions AS t
        ON t.ID = c.TargetTransactionID
       AND t.RowStatus NOT IN (0, 254);

    IF @DryRun = 0
    BEGIN
        UPDATE t
        SET
              t.SageTransactionReference = c.NewSageTransactionReference
        FROM SFin.Transactions AS t
        INNER JOIN #Candidate AS c
            ON c.TargetTransactionID = t.ID
        WHERE c.WouldUpdate = 1
          AND t.RowStatus NOT IN (0, 254)
          AND NULLIF(LTRIM(RTRIM(t.SageTransactionReference)), N'') IS NULL;
    END;

    SELECT
          c.InboundStatusID
        , c.InboundStatusGuid
        , c.TargetTransactionID
        , c.TransactionGuid
        , c.TransactionNumber
        , c.ExistingSageTransactionReference
        , c.NewSageTransactionReference
        , c.WouldUpdate
        , Applied = CAST(CASE WHEN @DryRun = 0 AND c.WouldUpdate = 1 THEN 1 ELSE 0 END AS BIT)
    FROM #Candidate AS c
    ORDER BY
        c.InboundStatusID DESC;
END;
GO