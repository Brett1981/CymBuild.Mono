SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRAN;

    DECLARE @EntityTypeId_TransactionInvoicePreviews INT;

    SELECT @EntityTypeId_TransactionInvoicePreviews = et.ID
    FROM SCore.EntityTypes AS et
    WHERE et.RowStatus NOT IN (0, 254)
      AND et.Name = N'Transaction Invoice Previews';

    IF @EntityTypeId_TransactionInvoicePreviews IS NULL
    BEGIN
        ;THROW 60000, N'EntityType ''Transaction Invoice Previews'' must exist before creating SFin.TransactionInvoicePreviews.', 1;
    END;

    IF OBJECT_ID(N'SFin.TransactionInvoicePreviews', N'U') IS NULL
    BEGIN
        CREATE TABLE SFin.TransactionInvoicePreviews
        (
            ID BIGINT IDENTITY(1,1) NOT NULL,
            RowStatus TINYINT NOT NULL,
            RowVersion ROWVERSION NOT NULL,
            Guid UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL,
            TransactionId BIGINT NOT NULL,
            MergeDocumentId INT NOT NULL,
            InvoiceNumberReserved NVARCHAR(30) NOT NULL,
            SharePointDriveId NVARCHAR(200) NOT NULL,
            SharePointItemId NVARCHAR(200) NOT NULL,
            SharePointWebUrl NVARCHAR(1000) NOT NULL,
            Filename NVARCHAR(260) NOT NULL,
            MimeType NVARCHAR(100) NOT NULL,
            FileHash NVARCHAR(128) NOT NULL,
            SourceTransactionRowVersion VARBINARY(8) NOT NULL,
            GeneratedByUserId INT NOT NULL,
            GeneratedDateTimeUtc DATETIME2(7) NOT NULL,
            IsCurrent BIT NOT NULL,
            IsPostedToSage BIT NOT NULL,
            PostedToSageDateTimeUtc DATETIME2(7) NULL,
            CONSTRAINT PK_TransactionInvoicePreviews PRIMARY KEY CLUSTERED (ID ASC),
            CONSTRAINT UQ_TransactionInvoicePreviews_Guid UNIQUE NONCLUSTERED (Guid ASC)
        );

        ALTER TABLE SFin.TransactionInvoicePreviews ADD CONSTRAINT DF_TransactionInvoicePreviews_RowStatus DEFAULT ((1)) FOR RowStatus;
        ALTER TABLE SFin.TransactionInvoicePreviews ADD CONSTRAINT DF_TransactionInvoicePreviews_Guid DEFAULT (NEWID()) FOR Guid;
        ALTER TABLE SFin.TransactionInvoicePreviews ADD CONSTRAINT DF_TransactionInvoicePreviews_IsCurrent DEFAULT ((1)) FOR IsCurrent;
        ALTER TABLE SFin.TransactionInvoicePreviews ADD CONSTRAINT DF_TransactionInvoicePreviews_IsPostedToSage DEFAULT ((0)) FOR IsPostedToSage;
        ALTER TABLE SFin.TransactionInvoicePreviews ADD CONSTRAINT DF_TransactionInvoicePreviews_GeneratedDate DEFAULT (SYSUTCDATETIME()) FOR GeneratedDateTimeUtc;

        CREATE NONCLUSTERED INDEX IX_TransactionInvoicePreviews_Transaction_Current
            ON SFin.TransactionInvoicePreviews(TransactionId, IsCurrent)
            INCLUDE (InvoiceNumberReserved, SharePointItemId, SharePointWebUrl, GeneratedDateTimeUtc, SourceTransactionRowVersion, IsPostedToSage)
            WHERE RowStatus <> 0 AND RowStatus <> 254

        CREATE NONCLUSTERED INDEX IX_TransactionInvoicePreviews_SharePointItem
            ON SFin.TransactionInvoicePreviews(SharePointDriveId, SharePointItemId)
            WHERE RowStatus <> 0 AND RowStatus <> 254

        ALTER TABLE SFin.TransactionInvoicePreviews WITH CHECK ADD CONSTRAINT FK_TransactionInvoicePreviews_Transactions
            FOREIGN KEY (TransactionId) REFERENCES SFin.Transactions(ID);

        ALTER TABLE SFin.TransactionInvoicePreviews WITH CHECK ADD CONSTRAINT FK_TransactionInvoicePreviews_MergeDocuments
            FOREIGN KEY (MergeDocumentId) REFERENCES SCore.MergeDocuments(ID);

        ALTER TABLE SFin.TransactionInvoicePreviews WITH CHECK ADD CONSTRAINT FK_TransactionInvoicePreviews_RowStatus
            FOREIGN KEY (RowStatus) REFERENCES SCore.RowStatus(ID);

        ALTER TABLE SFin.TransactionInvoicePreviews WITH CHECK ADD CONSTRAINT FK_TransactionInvoicePreviews_Identities
            FOREIGN KEY (GeneratedByUserId) REFERENCES SCore.Identities(ID);

        ALTER TABLE SFin.TransactionInvoicePreviews WITH NOCHECK ADD CONSTRAINT FK_TransactionInvoicePreviews_DataObjects
            FOREIGN KEY (Guid) REFERENCES SCore.DataObjects(Guid);

        ALTER TABLE SFin.TransactionInvoicePreviews NOCHECK CONSTRAINT FK_TransactionInvoicePreviews_DataObjects;
    END;

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH;
GO