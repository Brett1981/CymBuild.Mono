SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter procedure [SFin].[SageInbound_RecordAllocation]')
GO

/*
    CYB-555: records one row of a Sage allocation session against the invoice
    it settled, as returned by the wrapper's GET /api/v2/sales-allocations.

    - The counterpart (the receipt or credit note) is stored once in
      SFin.SageExternalTransactions, keyed by its URN, even when it settled
      several invoices. SageDocumentNo holds N'URN:' + the URN, so the row can
      never be mistaken for, or reconciled as, an invoice. Its type is updated
      on every call, so a counterpart first seen unresolved (stored as -1) takes
      its real type once Sage resolves it.
    - The allocation is stored once in SFin.SageExternalAllocations per
      (session, counterpart URN, invoice). SourceHash holds that key, so a
      re-sync of the same session updates the row instead of adding one.
    - @AppliedAmount is the part of this session that settled this invoice,
      positive. The counterpart amounts are its whole value, signed as Sage
      returns them (receipts and credit notes are negative).

    Nothing is materialised here; SFin.SageInbound_ReconcileAllocations does that.
*/
CREATE OR ALTER PROCEDURE [SFin].[SageInbound_RecordAllocation]
(
    @InvoiceExternalTransactionID BIGINT,
    @CounterpartUrn               NVARCHAR(50),
    @CounterpartTypeCode          INT = NULL,      -- 1 Receipt, 5 Credit Note, NULL = not resolved
    @CounterpartReference         NVARCHAR(100) = N'',
    @CounterpartSecondReference   NVARCHAR(100) = N'',
    @CounterpartTransactionDate   DATE = NULL,
    @CounterpartNetAmount         DECIMAL(18,2) = 0,
    @CounterpartTaxAmount         DECIMAL(18,2) = 0,
    @CounterpartGrossAmount       DECIMAL(18,2) = 0,
    @CounterpartRawPayloadJson    NVARCHAR(MAX) = NULL,
    @AllocationHeaderID           NVARCHAR(50),
    @SessionDate                  DATE = NULL,
    @AppliedAmount                DECIMAL(18,2),
    @AllocationRawPayloadJson     NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @NowUtc                    DATETIME2(7) = GETUTCDATE(),
        @UserId                    INT = SCore.GetCurrentUserId(),
        @SageDataset               NVARCHAR(30),
        @SageAccountReference      NVARCHAR(100),
        @InvoiceTransactionID      BIGINT,
        @CounterpartDocumentNo     NVARCHAR(100),
        @StoredTypeCode            INT = ISNULL(@CounterpartTypeCode, -1),
        @AllocationKey             NVARCHAR(128),
        @CounterpartGuid           UNIQUEIDENTIFIER,
        @CounterpartID             BIGINT,
        @AllocationGuid            UNIQUEIDENTIFIER,
        @AllocationID              BIGINT,
        @IsInsert                  BIT;

    SET @CounterpartUrn = LTRIM(RTRIM(ISNULL(@CounterpartUrn, N'')));
    SET @AllocationHeaderID = LTRIM(RTRIM(ISNULL(@AllocationHeaderID, N'')));

    IF @CounterpartUrn = N'' OR @AllocationHeaderID = N''
    BEGIN
        ;THROW 60090, N'A Sage allocation needs both the session id and the counterpart URN.', 1;
    END;

    IF @StoredTypeCode NOT IN (-1, 1, 5)
    BEGIN
        ;THROW 60091, N'Only a Receipt (1), a Credit Note (5) or an unresolved counterpart can settle an invoice.', 1;
    END;

    SELECT
        @SageDataset          = inv.SageDataset,
        @SageAccountReference = inv.SageAccountReference,
        @InvoiceTransactionID = inv.MatchedTransactionID
    FROM SFin.SageExternalTransactions AS inv
    WHERE inv.ID = @InvoiceExternalTransactionID
      AND inv.RowStatus NOT IN (0,254)
      AND inv.SageTransactionTypeCode = 4;

    IF @SageDataset IS NULL
    BEGIN
        ;THROW 60092, N'The Sage invoice row for this allocation was not found.', 1;
    END;

    SET @CounterpartDocumentNo = N'URN:' + @CounterpartUrn;
    SET @AllocationKey = N'SESSION:' + @AllocationHeaderID + N'|URN:' + @CounterpartUrn;

    BEGIN TRANSACTION;

    ---------------------------------------------------------------------------
    -- The counterpart, once per URN.
    ---------------------------------------------------------------------------
    SELECT TOP (1)
        @CounterpartID   = ext.ID,
        @CounterpartGuid = ext.Guid
    FROM SFin.SageExternalTransactions AS ext WITH (UPDLOCK, HOLDLOCK)
    WHERE ext.RowStatus NOT IN (0,254)
      AND ext.SageDataset = @SageDataset
      AND ext.SageAccountReference = @SageAccountReference
      AND ext.SageDocumentNo = @CounterpartDocumentNo
      AND ext.SageTransactionTypeCode IN (-1, 1, 5)
    ORDER BY ext.ID DESC;

    IF @CounterpartID IS NOT NULL
    BEGIN
        UPDATE ext
        SET
            SageTransactionTypeCode  = @StoredTypeCode,
            SageTransactionReference = ISNULL(@CounterpartReference, N''),
            SecondReference          = ISNULL(@CounterpartSecondReference, N''),
            TransactionDate          = @CounterpartTransactionDate,
            NetAmount                = ISNULL(@CounterpartNetAmount, 0),
            TaxAmount                = ISNULL(@CounterpartTaxAmount, 0),
            GrossAmount              = ISNULL(@CounterpartGrossAmount, 0),
            AllocatedValue           = ISNULL(@CounterpartGrossAmount, 0),
            LastSeenOnUtc            = @NowUtc,
            RawPayloadJson           = @CounterpartRawPayloadJson,
            UpdatedByUserID          = @UserId,
            UpdatedDateTimeUTC       = @NowUtc
        FROM SFin.SageExternalTransactions AS ext
        WHERE ext.ID = @CounterpartID;
    END
    ELSE
    BEGIN
        SET @CounterpartGuid = NEWID();

        EXEC SCore.UpsertDataObject
             @Guid       = @CounterpartGuid,
             @SchemeName = N'SFin',
             @ObjectName = N'SageExternalTransactions',
             @IsInsert   = @IsInsert OUTPUT;

        INSERT INTO SFin.SageExternalTransactions
        (
            RowStatus,
            Guid,
            SageDataset,
            SageAccountReference,
            SageDocumentNo,
            SageTransactionReference,
            SecondReference,
            SageTransactionTypeCode,
            TransactionDate,
            NetAmount,
            TaxAmount,
            GrossAmount,
            AllocatedValue,
            OutstandingAmount,
            DocumentDiscountedValue,
            IsPaid,
            IsFullyPaid,
            PaymentStateCode,
            MatchedTransactionID,
            MatchedInvoiceRequestID,
            MatchedJobID,
            SourceHash,
            LastSeenOnUtc,
            RawPayloadJson,
            CreatedByUserID,
            CreatedDateTimeUTC,
            UpdatedByUserID,
            UpdatedDateTimeUTC
        )
        VALUES
        (
            1,
            @CounterpartGuid,
            @SageDataset,
            @SageAccountReference,
            @CounterpartDocumentNo,
            ISNULL(@CounterpartReference, N''),
            ISNULL(@CounterpartSecondReference, N''),
            @StoredTypeCode,
            @CounterpartTransactionDate,
            ISNULL(@CounterpartNetAmount, 0),
            ISNULL(@CounterpartTaxAmount, 0),
            ISNULL(@CounterpartGrossAmount, 0),
            ISNULL(@CounterpartGrossAmount, 0),
            0,
            0,
            1,
            1,
            N'Unknown',
            -1,
            -1,
            -1,
            @CounterpartDocumentNo,
            @NowUtc,
            @CounterpartRawPayloadJson,
            @UserId,
            @NowUtc,
            @UserId,
            @NowUtc
        );

        SELECT @CounterpartID = ext.ID
        FROM SFin.SageExternalTransactions AS ext
        WHERE ext.Guid = @CounterpartGuid;
    END;

    ---------------------------------------------------------------------------
    -- The allocation, once per (session, counterpart URN, invoice).
    ---------------------------------------------------------------------------
    SELECT TOP (1)
        @AllocationID   = a.ID,
        @AllocationGuid = a.Guid
    FROM SFin.SageExternalAllocations AS a WITH (UPDLOCK, HOLDLOCK)
    WHERE a.RowStatus NOT IN (0,254)
      AND a.TargetExternalTransactionID = @InvoiceExternalTransactionID
      AND a.SourceHash = @AllocationKey
    ORDER BY a.ID DESC;

    IF @AllocationID IS NOT NULL
    BEGIN
        UPDATE a
        SET
            SourceExternalTransactionID = @CounterpartID,
            AllocatedAmount             = ABS(@AppliedAmount),
            AllocationDate              = @SessionDate,
            MatchedTargetTransactionID  = ISNULL(@InvoiceTransactionID, -1),
            LastSeenOnUtc               = @NowUtc,
            RawPayloadJson              = @AllocationRawPayloadJson,
            UpdatedByUserID             = @UserId,
            UpdatedDateTimeUTC          = @NowUtc
        FROM SFin.SageExternalAllocations AS a
        WHERE a.ID = @AllocationID;
    END
    ELSE
    BEGIN
        SET @AllocationGuid = NEWID();

        EXEC SCore.UpsertDataObject
             @Guid       = @AllocationGuid,
             @SchemeName = N'SFin',
             @ObjectName = N'SageExternalAllocations',
             @IsInsert   = @IsInsert OUTPUT;

        INSERT INTO SFin.SageExternalAllocations
        (
            RowStatus,
            Guid,
            SourceExternalTransactionID,
            TargetExternalTransactionID,
            AllocatedAmount,
            AllocationDate,
            MatchedSourceTransactionID,
            MatchedTargetTransactionID,
            SourceHash,
            LastSeenOnUtc,
            RawPayloadJson,
            CreatedByUserID,
            CreatedDateTimeUTC,
            UpdatedByUserID,
            UpdatedDateTimeUTC
        )
        VALUES
        (
            1,
            @AllocationGuid,
            @CounterpartID,
            @InvoiceExternalTransactionID,
            ABS(@AppliedAmount),
            @SessionDate,
            -1,
            ISNULL(@InvoiceTransactionID, -1),
            @AllocationKey,
            @NowUtc,
            @AllocationRawPayloadJson,
            @UserId,
            @NowUtc,
            @UserId,
            @NowUtc
        );

        SELECT @AllocationID = a.ID
        FROM SFin.SageExternalAllocations AS a
        WHERE a.Guid = @AllocationGuid;
    END;

    COMMIT TRANSACTION;

    SELECT
        CounterpartExternalTransactionID = @CounterpartID,
        ExternalAllocationID             = @AllocationID;
END;
GO
