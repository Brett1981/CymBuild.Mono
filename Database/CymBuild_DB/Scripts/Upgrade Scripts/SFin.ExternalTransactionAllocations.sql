SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRAN;

    DECLARE @EntityTypeId_ExternalTransactionAllocations INT;

    SELECT
        @EntityTypeId_ExternalTransactionAllocations = et.ID
    FROM SCore.EntityTypes AS et
    WHERE et.RowStatus NOT IN (0, 254)
      AND et.Name = N'External Transaction Allocations';

    IF @EntityTypeId_ExternalTransactionAllocations IS NULL
    BEGIN
        ;THROW 60000, N'EntityType ''External Transaction Allocations'' must exist before creating allocation rows.', 1;
    END;

    IF OBJECT_ID(N'SFin.ExternalTransactionAllocations', N'U') IS NULL
    BEGIN
        CREATE TABLE SFin.ExternalTransactionAllocations
        (
            ID                        BIGINT IDENTITY(1,1) NOT NULL,
            RowStatus                 TINYINT NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_RowStatus DEFAULT ((1)),
            RowVersion                ROWVERSION NOT NULL,
            Guid                      UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_Guid DEFAULT (NEWID()),

            ExternalTransactionId     BIGINT NOT NULL,
            InvoiceRequestId          INT NULL,
            InvoiceRequestItemId      BIGINT NULL,

            AllocationOrdinal         INT NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_AllocationOrdinal DEFAULT ((0)),
            ExternalAllocationKey     NVARCHAR(250) NOT NULL,

            AllocatedAmount           DECIMAL(19,2) NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_AllocatedAmount DEFAULT ((0)),
            CurrencyCode              NVARCHAR(10) NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_CurrencyCode DEFAULT (N'GBP'),

            MatchRule                 NVARCHAR(50) NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_MatchRule DEFAULT (N'UNMATCHED'),
            MatchScore                INT NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_MatchScore DEFAULT ((0)),
            IsAutoMatched             BIT NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_IsAutoMatched DEFAULT ((1)),
            IsUnapplied               BIT NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_IsUnapplied DEFAULT ((0)),

            ExternalDocumentNumber    NVARCHAR(100) NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_ExternalDocumentNumber DEFAULT (N''),
            ExternalReference         NVARCHAR(200) NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_ExternalReference DEFAULT (N''),

            MatchingSnapshotJson      NVARCHAR(MAX) NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_MatchingSnapshotJson DEFAULT (N'{}'),
            RawAllocationJson         NVARCHAR(MAX) NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_RawAllocationJson DEFAULT (N'{}'),

            CreatedDateTimeUtc        DATETIME2(7) NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_CreatedDateTimeUtc DEFAULT (SYSUTCDATETIME()),
            LastEvaluatedDateTimeUtc  DATETIME2(7) NOT NULL
                CONSTRAINT DF_ExternalTransactionAllocations_LastEvaluatedDateTimeUtc DEFAULT (SYSUTCDATETIME()),

            CONSTRAINT PK_ExternalTransactionAllocations
                PRIMARY KEY CLUSTERED (ID ASC)
                WITH (FILLFACTOR = 80)
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE name = N'IX_UQ_ExternalTransactionAllocations_Guid'
          AND object_id = OBJECT_ID(N'SFin.ExternalTransactionAllocations')
    )
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX IX_UQ_ExternalTransactionAllocations_Guid
            ON SFin.ExternalTransactionAllocations(Guid);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE name = N'UX_ExternalTransactionAllocations_ExternalAllocationKey_Active'
          AND object_id = OBJECT_ID(N'SFin.ExternalTransactionAllocations')
    )
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX UX_ExternalTransactionAllocations_ExternalAllocationKey_Active
            ON SFin.ExternalTransactionAllocations(ExternalAllocationKey)
            WHERE RowStatus <> 0 AND RowStatus <> 254
            WITH (FILLFACTOR = 80);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE name = N'IX_ExternalTransactionAllocations_ExternalTransaction_Active'
          AND object_id = OBJECT_ID(N'SFin.ExternalTransactionAllocations')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_ExternalTransactionAllocations_ExternalTransaction_Active
            ON SFin.ExternalTransactionAllocations(ExternalTransactionId, RowStatus, AllocationOrdinal)
            INCLUDE
            (
                InvoiceRequestId,
                InvoiceRequestItemId,
                AllocatedAmount,
                MatchRule,
                MatchScore,
                IsUnapplied,
                CreatedDateTimeUtc
            )
            WHERE RowStatus <> 0 AND RowStatus <> 254
            WITH (FILLFACTOR = 80);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE name = N'IX_ExternalTransactionAllocations_InvoiceRequest_Active'
          AND object_id = OBJECT_ID(N'SFin.ExternalTransactionAllocations')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_ExternalTransactionAllocations_InvoiceRequest_Active
            ON SFin.ExternalTransactionAllocations(InvoiceRequestId, RowStatus)
            INCLUDE
            (
                ExternalTransactionId,
                InvoiceRequestItemId,
                AllocatedAmount,
                MatchRule,
                MatchScore
            )
            WHERE RowStatus <> 0
              AND RowStatus <> 254
              AND InvoiceRequestId IS NOT NULL
            WITH (FILLFACTOR = 80);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE name = N'IX_ExternalTransactionAllocations_InvoiceRequestItem_Active'
          AND object_id = OBJECT_ID(N'SFin.ExternalTransactionAllocations')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_ExternalTransactionAllocations_InvoiceRequestItem_Active
            ON SFin.ExternalTransactionAllocations(InvoiceRequestItemId, RowStatus)
            INCLUDE
            (
                ExternalTransactionId,
                InvoiceRequestId,
                AllocatedAmount,
                MatchRule,
                MatchScore
            )
            WHERE RowStatus <> 0
              AND RowStatus <> 254
              AND InvoiceRequestItemId IS NOT NULL
            WITH (FILLFACTOR = 80);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_ExternalTransactionAllocations_DataObjects'
    )
    BEGIN
        ALTER TABLE SFin.ExternalTransactionAllocations WITH NOCHECK
        ADD CONSTRAINT FK_ExternalTransactionAllocations_DataObjects
            FOREIGN KEY(Guid)
            REFERENCES SCore.DataObjects(Guid);

        ALTER TABLE SFin.ExternalTransactionAllocations
            NOCHECK CONSTRAINT FK_ExternalTransactionAllocations_DataObjects;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_ExternalTransactionAllocations_RowStatus'
    )
    BEGIN
        ALTER TABLE SFin.ExternalTransactionAllocations WITH CHECK
        ADD CONSTRAINT FK_ExternalTransactionAllocations_RowStatus
            FOREIGN KEY(RowStatus)
            REFERENCES SCore.RowStatus(ID);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_ExternalTransactionAllocations_InvoiceRequests'
    )
    BEGIN
        ALTER TABLE SFin.ExternalTransactionAllocations WITH CHECK
        ADD CONSTRAINT FK_ExternalTransactionAllocations_InvoiceRequests
            FOREIGN KEY(InvoiceRequestId)
            REFERENCES SFin.InvoiceRequests(ID);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_ExternalTransactionAllocations_InvoiceRequestItems'
    )
    BEGIN
        ALTER TABLE SFin.ExternalTransactionAllocations WITH CHECK
        ADD CONSTRAINT FK_ExternalTransactionAllocations_InvoiceRequestItems
            FOREIGN KEY(InvoiceRequestItemId)
            REFERENCES SFin.InvoiceRequestItems(ID);
    END;

    IF OBJECT_ID(N'SFin.ExternalTransactions', N'U') IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM sys.foreign_keys
           WHERE name = N'FK_ExternalTransactionAllocations_ExternalTransactions'
       )
    BEGIN
        ALTER TABLE SFin.ExternalTransactionAllocations WITH CHECK
        ADD CONSTRAINT FK_ExternalTransactionAllocations_ExternalTransactions
            FOREIGN KEY(ExternalTransactionId)
            REFERENCES SFin.ExternalTransactions(ID);
    END;

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    THROW;
END CATCH;
GO