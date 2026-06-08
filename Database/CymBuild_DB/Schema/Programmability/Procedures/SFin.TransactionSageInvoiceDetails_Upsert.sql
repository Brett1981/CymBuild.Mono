SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionSageInvoiceDetails_Upsert]')
GO
CREATE PROCEDURE [SFin].[TransactionSageInvoiceDetails_Upsert]
(
    @TransactionGuid UNIQUEIDENTIFIER,
    @SageInvoiceNumber NVARCHAR(50) = NULL,
    @SageSalesOrderNumber NVARCHAR(50) = NULL,
    @UpdatedByUserID INT = -1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE t
    SET
        t.SageInvoiceNumber = NULLIF(LTRIM(RTRIM(@SageInvoiceNumber)), N''),
        t.SageSalesOrderNumber = NULLIF(LTRIM(RTRIM(@SageSalesOrderNumber)), N''),
        t.SageInvoiceGeneratedDateTimeUtc = SYSUTCDATETIME()
    FROM SFin.Transactions AS t
    WHERE t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0, 254);
END
GO