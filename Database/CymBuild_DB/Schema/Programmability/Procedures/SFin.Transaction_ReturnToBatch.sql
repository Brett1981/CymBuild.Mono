SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[Transaction_ReturnToBatch]')
GO
CREATE PROCEDURE [SFin].[Transaction_ReturnToBatch]
(
    @TransactionGuid UNIQUEIDENTIFIER,
    @UpdatedByUserID INT = -1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE t
    SET
        t.Batched = 1
    FROM SFin.Transactions AS t
    WHERE t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0, 254)
      AND ISNULL(t.Batched, 0) = 0;
END;
GO