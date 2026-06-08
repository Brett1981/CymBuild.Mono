SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionInvoicePreviewInsert]')
GO

CREATE PROCEDURE [SFin].[TransactionInvoicePreviewInsert]
(
    @TransactionGuid UNIQUEIDENTIFIER,
    @MergeDocumentGuid UNIQUEIDENTIFIER,
    @InvoiceNumberReserved NVARCHAR(30),
    @SharePointDriveId NVARCHAR(200),
    @SharePointItemId NVARCHAR(200),
    @SharePointWebUrl NVARCHAR(1000),
    @Filename NVARCHAR(260),
    @MimeType NVARCHAR(100),
    @FileHash NVARCHAR(128),
    @Guid UNIQUEIDENTIFIER OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TransactionId BIGINT;
    DECLARE @MergeDocumentId INT;
    DECLARE @GeneratedByUserId INT = SCore.GetCurrentUserId();
    DECLARE @SourceTransactionRowVersion VARBINARY(8);
    DECLARE @IsInsert BIT;

    SELECT
        @TransactionId = t.ID,
        @SourceTransactionRowVersion = t.RowVersion
    FROM SFin.Transactions AS t
    WHERE t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0, 254);

    SELECT @MergeDocumentId = md.ID
    FROM SCore.MergeDocuments AS md
    WHERE md.Guid = @MergeDocumentGuid
      AND md.RowStatus NOT IN (0, 254);

    IF @TransactionId IS NULL
        THROW 60002, N'Transaction not found.', 1;

    IF @MergeDocumentId IS NULL
        THROW 60003, N'Merge document not found.', 1;

    EXEC SFin.TransactionInvoicePreviewInvalidateCurrent @TransactionId = @TransactionId;

    EXEC SCore.UpsertDataObject
         @Guid = @Guid,
         @SchemeName = N'SFin',
         @ObjectName = N'TransactionInvoicePreviews',
         @IsInsert = @IsInsert OUTPUT;

    INSERT INTO SFin.TransactionInvoicePreviews
    (
        RowStatus,
        Guid,
        TransactionId,
        MergeDocumentId,
        InvoiceNumberReserved,
        SharePointDriveId,
        SharePointItemId,
        SharePointWebUrl,
        Filename,
        MimeType,
        FileHash,
        SourceTransactionRowVersion,
        GeneratedByUserId,
        GeneratedDateTimeUtc,
        IsCurrent,
        IsPostedToSage,
        PostedToSageDateTimeUtc
    )
    VALUES
    (
        1,
        @Guid,
        @TransactionId,
        @MergeDocumentId,
        @InvoiceNumberReserved,
        @SharePointDriveId,
        @SharePointItemId,
        @SharePointWebUrl,
        @Filename,
        @MimeType,
        @FileHash,
        @SourceTransactionRowVersion,
        @GeneratedByUserId,
        SYSUTCDATETIME(),
        1,
        0,
        NULL
    );
END;
GO