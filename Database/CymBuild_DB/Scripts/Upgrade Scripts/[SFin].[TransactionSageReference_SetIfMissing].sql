CREATE OR ALTER PROCEDURE [SFin].[TransactionSageReference_SetIfMissing]
(
      @TransactionID BIGINT
    , @SageTransactionReference NVARCHAR(100)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @TransactionID IS NULL OR @TransactionID <= 0
        THROW 50000, 'TransactionID is required.', 1;

    IF NULLIF(LTRIM(RTRIM(@SageTransactionReference)), N'') IS NULL
        THROW 50000, 'SageTransactionReference is required.', 1;

    UPDATE t
    SET
        t.SageTransactionReference = LTRIM(RTRIM(@SageTransactionReference))
    FROM SFin.Transactions AS t
    WHERE t.ID = @TransactionID
      AND t.RowStatus NOT IN (0, 254)
      AND NULLIF(LTRIM(RTRIM(t.SageTransactionReference)), N'') IS NULL;

    SELECT
        Applied = CAST(CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END AS BIT);
END;
GO