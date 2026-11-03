/*
    Sage allocation sources: type 5 (Credit Note) and type 1 (Receipt) are the
    primary sources. A type 4 Invoice row is also accepted as a Receipt source
    while no distinct 1/5 row has been matched to the same invoice.

    CYB-568: CYB-555 stopped type 4 rows creating receipts, but the production
    Sage source never sends a distinct 1/5 row for a paid invoice - it only
    flips IsPaid/AllocatedValue on the invoice's own row - so no receipt or
    allocation was ever created. The CYB-543 type 4 fallback is restored. Known
    limitation: an invoice settled by a credit note that Sage does not return
    as a type 5 row is recorded as a Receipt.

    CYB-568: a Sage Receipt carries no VAT split - its netAmount is the cash
    received, i.e. the VAT-inclusive gross. SFin.TransactionDetailsUpsert always
    adds VAT from the VAT code on top of @Net, so passing the receipt amount as
    Net double-counted VAT (1440 received -> Net 1440 / VAT 288 / Gross 1728).
    When Sage supplies no tax amount the value is treated as gross and the net
    is back-calculated from the matched invoice's VAT percentage.

    CYB-555 (allocations, v2): with UseSalesAllocations on, the API records
    Sage's allocation sessions (SFin.SageInbound_RecordAllocation) and
    SFin.SageInbound_ReconcileAllocations calls this procedure in pair mode
    (@InvoiceExternalTransactionID): one CymBuild Receipt/Credit Note per
    (counterpart, invoice), for the amount applied to that invoice. It takes
    over any earlier type 4 fallback Receipt, including its type. Once any
    allocation is recorded for an invoice, the type 4 fallback is ignored.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [SFin].[SageInboundReceiptAndAllocation_Materialise]
(
    @ExternalTransactionID BIGINT,
    -- CYB-555 pair mode: @ExternalTransactionID is a counterpart stored once per
    -- URN (SFin.SageInbound_RecordAllocation) and this is the invoice row it
    -- settled. NULL keeps the original single-row behaviour.
    @InvoiceExternalTransactionID BIGINT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @NowUtc DATETIME2(7) = GETUTCDATE(),
        @UserId INT,
        @SessionUserGuid UNIQUEIDENTIFIER,

        @MatchedInvoiceTransactionID BIGINT,
        @MatchedInvoiceTransactionGuid UNIQUEIDENTIFIER,

        @SageTransactionTypeCode INT,
        @AllocatedValue DECIMAL(18,2),
        @NetAmount DECIMAL(18,2),
        @TaxAmount DECIMAL(18,2),
        @TransactionDate DATE,
        @MatchedInvoiceDate DATE,
        @SageTransactionReference NVARCHAR(100),

        @InvoicePurchaseOrderNumber NVARCHAR(28),
        @InvoiceAccountGuid UNIQUEIDENTIFIER,
        @InvoiceJobGuid UNIQUEIDENTIFIER,
        @InvoiceOrganisationalUnitGuid UNIQUEIDENTIFIER,
        @InvoiceSurveyorGuid UNIQUEIDENTIFIER,
        @InvoiceCreditTermsGuid UNIQUEIDENTIFIER,
        @InvoiceDescription NVARCHAR(2000),

        @InvoiceActivityGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000',
        @InvoiceMilestoneGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000',
        @InvoiceJobPaymentStageGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000',
        @InvoiceRibaStageGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000',
        @InvoiceVatCodeGuid UNIQUEIDENTIFIER = NULL,
        @InvoiceVatPercentage DECIMAL(9,4) = NULL,
        @SageGrossAmount DECIMAL(18,2),

        @MaterialisedTransactionTypeName NVARCHAR(50),
        @MaterialisedTransactionTypeGuid UNIQUEIDENTIFIER,
        @ReceiptGuid UNIQUEIDENTIFIER,
        @ReceiptDetailGuid UNIQUEIDENTIFIER,
        @AllocationGuid UNIQUEIDENTIFIER,

        @ReceiptTransactionId BIGINT,
        @AllocationId BIGINT,

        @ReceiptSageTransactionReference NVARCHAR(50),
        @ReceiptDescription NVARCHAR(2000),
        @VatRate DECIMAL(18,2),
        @NetToStore DECIMAL(18,2),
        @CreatedByUserGuid UNIQUEIDENTIFIER,
        @ExpectedDate DATE,

        @ExistingReceiptGuid UNIQUEIDENTIFIER,
        @ExistingAllocationGuid UNIQUEIDENTIFIER,
        @ExistingReceiptTransactionGuid UNIQUEIDENTIFIER,
        @ExistingAllocationMaterialisedGuid UNIQUEIDENTIFIER,

        @InvoiceHasDistinctAllocationSource BIT,

        @IsPairMode BIT = CASE WHEN ISNULL(@InvoiceExternalTransactionID, 0) > 0 THEN 1 ELSE 0 END,
        @CounterpartGrossAmount DECIMAL(18,2);

    SET @UserId = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);
    SET @SessionUserGuid = SCore.GetCurrentUserGuid();

    BEGIN TRY
        SELECT
            @MatchedInvoiceTransactionID        = ext.MatchedTransactionID,
            @SageTransactionTypeCode             = ext.SageTransactionTypeCode,
            @AllocatedValue                     = ext.AllocatedValue,
            @NetAmount                          = ext.NetAmount,
            @TaxAmount                          = ext.TaxAmount,
            @CounterpartGrossAmount             = ext.GrossAmount,
            @TransactionDate                    = ext.TransactionDate,
            @SageTransactionReference           = ext.SageTransactionReference,
            @ExistingReceiptTransactionGuid     = ext.MaterialisedReceiptTransactionGuid,
            @ExistingAllocationMaterialisedGuid = ext.MaterialisedAllocationGuid
        FROM SFin.SageExternalTransactions AS ext
        WHERE ext.ID = @ExternalTransactionID
          AND ext.RowStatus NOT IN (0,254);

        -- CYB-555-PAIR-MODE: the counterpart is shared by every invoice it
        -- settled, so the invoice, the amount and the CymBuild transaction
        -- already made all come from the allocations for this one pair.
        IF @IsPairMode = 1
        BEGIN
            SET @MatchedInvoiceTransactionID = NULL;
            SET @ExistingReceiptTransactionGuid = NULL;
            SET @ExistingAllocationMaterialisedGuid = NULL;

            SELECT @MatchedInvoiceTransactionID = inv.MatchedTransactionID
            FROM SFin.SageExternalTransactions AS inv
            WHERE inv.ID = @InvoiceExternalTransactionID
              AND inv.RowStatus NOT IN (0,254)
              AND inv.SageTransactionTypeCode = 4;

            -- The amount Sage applied to this invoice, summed over its sessions.
            SELECT @AllocatedValue = SUM(pairAllocation.AllocatedAmount)
            FROM SFin.SageExternalAllocations AS pairAllocation
            WHERE pairAllocation.RowStatus NOT IN (0,254)
              AND pairAllocation.SourceExternalTransactionID = @ExternalTransactionID
              AND pairAllocation.TargetExternalTransactionID = @InvoiceExternalTransactionID;

            -- The counterpart's own net/VAT split only describes this
            -- allocation when all of it went to this invoice. Otherwise the
            -- split is derived below from the applied amount and the invoice VAT.
            IF ABS(ISNULL(@CounterpartGrossAmount, 0)) <> ABS(ISNULL(@AllocatedValue, 0))
            BEGIN
                SET @NetAmount = 0;
                SET @TaxAmount = 0;
            END;

            -- A deleted transaction is found too, so a Finance delete is kept.
            SELECT TOP (1)
                @ExistingReceiptTransactionGuid = pairTran.Guid
            FROM SFin.SageExternalAllocations AS pairAllocation
            JOIN SFin.Transactions AS pairTran
                ON pairTran.ID = pairAllocation.MatchedSourceTransactionID
            WHERE pairAllocation.RowStatus NOT IN (0,254)
              AND pairAllocation.SourceExternalTransactionID = @ExternalTransactionID
              AND pairAllocation.TargetExternalTransactionID = @InvoiceExternalTransactionID
              AND pairAllocation.MatchedSourceTransactionID > 0
            ORDER BY
                CASE WHEN pairTran.RowStatus NOT IN (0,254) THEN 0 ELSE 1 END,
                pairAllocation.ID DESC;
        END;

        /*
            Type 5 Credit Note and type 1 Receipt rows are the primary
            allocation sources. Some Sage sources (including production and
            the DEV mock wrapper) never emit a distinct Credit Note/Receipt row:
            they represent a settled invoice purely by flipping
            IsPaid/AllocatedValue on the type 4 Invoice row itself. So a type 4
            row is also accepted as a Receipt source, but only while no
            distinct type 1/5 row has been matched to the same invoice - once a
            real Credit Note/Receipt exists it alone owns the
            receipt/allocation, so the two sources cannot overwrite each other.
        */
        SET @InvoiceHasDistinctAllocationSource = 0;

        IF @SageTransactionTypeCode = 4
           AND ISNULL(@MatchedInvoiceTransactionID, -1) > 0
           AND
           (
               EXISTS
               (
                    SELECT 1
                    FROM SFin.SageExternalTransactions AS distinctSource
                    WHERE distinctSource.RowStatus NOT IN (0,254)
                      AND distinctSource.SageTransactionTypeCode IN (1, 5)
                      AND distinctSource.MatchedTransactionID = @MatchedInvoiceTransactionID
               )
               -- CYB-555-ALLOCATIONS-BLOCK-FALLBACK: once Sage's allocations
               -- for the invoice are recorded they decide, including an
               -- unresolved counterpart (settled, method unknown).
               OR EXISTS
               (
                    SELECT 1
                    FROM SFin.SageExternalAllocations AS sessionSource
                    JOIN SFin.SageExternalTransactions AS invoiceRow
                        ON invoiceRow.ID = sessionSource.TargetExternalTransactionID
                       AND invoiceRow.RowStatus NOT IN (0,254)
                    WHERE sessionSource.RowStatus NOT IN (0,254)
                      AND invoiceRow.MatchedTransactionID = @MatchedInvoiceTransactionID
               )
           )
        BEGIN
            SET @InvoiceHasDistinctAllocationSource = 1;
        END;

        SET @MaterialisedTransactionTypeName =
            CASE @SageTransactionTypeCode
                WHEN 5 THEN N'CreditNote'
                WHEN 1 THEN N'Receipt'
                WHEN 4 THEN CASE WHEN @InvoiceHasDistinctAllocationSource = 0 THEN N'Receipt' ELSE NULL END
                ELSE NULL
            END;

        IF @MaterialisedTransactionTypeName IS NULL
        BEGIN
            RETURN;
        END;

        -- Sage can return negative accounting values for Credit Notes. CymBuild
        -- stores positive detail/allocation values and applies the sign through
        -- TransactionTypes.IsNegated.
        SET @AllocatedValue = ABS(ISNULL(@AllocatedValue, 0));
        SET @NetAmount = ABS(ISNULL(@NetAmount, 0));
        SET @TaxAmount = ABS(ISNULL(@TaxAmount, 0));

        IF ISNULL(@MatchedInvoiceTransactionID, -1) <= 0
        BEGIN
            RETURN;
        END;

        IF ISNULL(@AllocatedValue, 0) <= 0
        BEGIN
            RETURN;
        END;

        -- CYB-555-RECEIPT-DELETE: Finance can delete a non-batched Receipt
        -- (SFin.TransactionBatchDelete). A later poll must leave it deleted,
        -- rather than reviving it or failing the sync for the whole invoice.
        IF EXISTS
        (
            SELECT 1
            FROM SFin.Transactions AS deletedReceipt
            WHERE deletedReceipt.Guid = @ExistingReceiptTransactionGuid
              AND deletedReceipt.RowStatus = 254
        )
        BEGIN
            RETURN;
        END;

        /*
            A type 4 fallback Receipt may already exist when a genuine type 1/5
            row for the same invoice arrives in a later poll. The genuine row
            takes over that Receipt/Allocation in place instead of creating a
            duplicate. Only a type 4 sibling is reused, so explicit Credit Note
            and Receipt rows stay independent allocation sources.
        */
        IF ISNULL(@ExistingReceiptTransactionGuid, '00000000-0000-0000-0000-000000000000') = '00000000-0000-0000-0000-000000000000'
        BEGIN
            SELECT TOP (1)
                @ExistingReceiptTransactionGuid     = siblingExt.MaterialisedReceiptTransactionGuid,
                @ExistingAllocationMaterialisedGuid = siblingExt.MaterialisedAllocationGuid
            FROM SFin.SageExternalTransactions AS siblingExt
            WHERE siblingExt.RowStatus NOT IN (0,254)
              AND siblingExt.ID <> @ExternalTransactionID
              AND siblingExt.SageTransactionTypeCode = 4
              AND siblingExt.MatchedTransactionID = @MatchedInvoiceTransactionID
              AND siblingExt.MaterialisedReceiptTransactionGuid IS NOT NULL
              AND siblingExt.MaterialisedReceiptTransactionGuid <> '00000000-0000-0000-0000-000000000000'
              -- CYB-555: a deleted fallback Receipt is not taken over.
              AND EXISTS
              (
                    SELECT 1
                    FROM SFin.Transactions AS siblingReceipt
                    WHERE siblingReceipt.Guid = siblingExt.MaterialisedReceiptTransactionGuid
                      AND siblingReceipt.RowStatus NOT IN (0,254)
              )
              -- CYB-555: nor one another counterpart has already taken over,
              -- when a receipt and a credit note both settled the invoice.
              AND NOT EXISTS
              (
                    SELECT 1
                    FROM SFin.SageExternalAllocations AS claimed
                    WHERE claimed.RowStatus NOT IN (0,254)
                      AND claimed.MatchedSourceTransactionID = siblingExt.MaterialisedReceiptTransactionID
                      AND claimed.SourceExternalTransactionID <> @ExternalTransactionID
              )
            ORDER BY siblingExt.ID DESC;
        END;

        SELECT
            @MatchedInvoiceTransactionGuid = t.Guid,
            @InvoicePurchaseOrderNumber    = t.PurchaseOrderNumber,
            @MatchedInvoiceDate            = t.[Date]
        FROM SFin.Transactions AS t
        WHERE t.ID = @MatchedInvoiceTransactionID
          AND t.RowStatus NOT IN (0,254);

        IF @MatchedInvoiceTransactionGuid IS NULL
        BEGIN
            RETURN;
        END;

        SELECT TOP (1)
            @InvoiceDescription         = td.Description,
            @InvoiceActivityGuid        = ISNULL(act.Guid, '00000000-0000-0000-0000-000000000000'),
            @InvoiceMilestoneGuid       = ISNULL(ms.Guid, '00000000-0000-0000-0000-000000000000'),
            @InvoiceJobPaymentStageGuid = ISNULL(jps.Guid, '00000000-0000-0000-0000-000000000000'),
            @InvoiceRibaStageGuid       = ISNULL(rs.Guid, '00000000-0000-0000-0000-000000000000'),
            @InvoiceVatCodeGuid         = vc.Guid,
            @InvoiceVatPercentage       = vc.VatPercentage
        FROM SFin.TransactionDetails AS td
        LEFT JOIN SJob.Activities AS act
            ON act.ID = td.ActivityID
        LEFT JOIN SJob.Milestones AS ms
            ON ms.ID = td.MilestoneID
        LEFT JOIN SJob.JobPaymentStages AS jps
            ON jps.ID = td.JobPaymentStageId
        LEFT JOIN SJob.RibaStages AS rs
            ON rs.ID = td.RIBAStageId
        LEFT JOIN SFin.VatCodes AS vc
            ON vc.ID = td.VatCodeID
           AND vc.RowStatus NOT IN (0,254)
           AND vc.Active = 1
        WHERE td.TransactionID = @MatchedInvoiceTransactionID
          AND td.RowStatus NOT IN (0,254)
        ORDER BY td.ID;

        SELECT
            @InvoiceAccountGuid            = acc.Guid,
            @InvoiceJobGuid                = j.Guid,
            @InvoiceOrganisationalUnitGuid = ou.Guid,
            @InvoiceSurveyorGuid           = idn.Guid,
            @InvoiceCreditTermsGuid        = ct.Guid
        FROM SFin.Transactions AS t
        JOIN SCrm.Accounts AS acc
            ON acc.ID = t.AccountID
        JOIN SJob.Jobs AS j
            ON j.ID = t.JobID
        JOIN SCore.OrganisationalUnits AS ou
            ON ou.ID = t.OrganisationalUnitId
        JOIN SCore.Identities AS idn
            ON idn.ID = t.SurveyorUserId
        JOIN SFin.CreditTerms AS ct
            ON ct.ID = t.CreditTermsId
        WHERE t.ID = @MatchedInvoiceTransactionID
          AND t.RowStatus NOT IN (0,254);

        -- Sage's transaction date remains authoritative when supplied. Some
        -- legacy/wrapper rows do not contain transactionDate; in that case the
        -- matched CymBuild invoice date is the deterministic fallback.
        SET @TransactionDate = COALESCE(@TransactionDate, @MatchedInvoiceDate);

        IF @TransactionDate IS NULL
        BEGIN
            ;THROW 60081, N'Allocation-source date could not be resolved from the Sage external transaction or matched CymBuild invoice.', 1;
        END;

        SET @CreatedByUserGuid = ISNULL(@InvoiceSurveyorGuid, @SessionUserGuid);
        SET @ExpectedDate = @TransactionDate;

        SELECT TOP (1)
            @MaterialisedTransactionTypeGuid = tt.Guid
        FROM SFin.TransactionTypes AS tt
        WHERE tt.RowStatus NOT IN (0,254)
          AND tt.IsActive = 1
          AND UPPER(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(tt.Name)), N' ', N''), N'-', N''), N'_', N'')) =
              UPPER(REPLACE(REPLACE(REPLACE(@MaterialisedTransactionTypeName, N' ', N''), N'-', N''), N'_', N''))
        ORDER BY tt.ID;

        IF @MaterialisedTransactionTypeGuid IS NULL
        BEGIN
            ;THROW 60000, N'Could not resolve the finance TransactionType required by the Sage allocation source.', 1;
        END;

        SET @ReceiptSageTransactionReference =
            ISNULL(@SageTransactionReference, N'');

        SET @ReceiptDescription =
            LEFT(ISNULL(@SageTransactionReference, N'')
                + CASE
                    WHEN ISNULL(@InvoiceDescription, N'') = N'' THEN N''
                    ELSE CHAR(13) + CHAR(10) + @InvoiceDescription
                  END,
                2000
            );

        IF @InvoiceVatCodeGuid IS NULL
           OR @InvoiceVatCodeGuid = '00000000-0000-0000-0000-000000000000'
           OR @InvoiceVatPercentage IS NULL
        BEGIN
            ;THROW 60080, N'Invoice VAT code could not be resolved for Sage allocation-source materialisation.', 1;
        END;

        -- CYB-568-VAT-EXCLUSIVE-NET
        -- SFin.TransactionDetailsUpsert derives VAT and Gross from @Net and the
        -- VAT code, so @Net must be the VAT-exclusive value. The marker above is
        -- inside the procedure body so it survives deployment: the header
        -- comment sits in an earlier batch and is not part of the definition,
        -- and CYB-568_SageReceipts_CorrectValueAndDate.sql checks for it.
        IF @SageTransactionTypeCode = 4
        BEGIN
            -- Type 4 fallback: the row's net/tax are the invoice's own values,
            -- not the payment. The receipt is the cash allocated so far, which
            -- is VAT-inclusive, so a part-paid invoice gets a part receipt.
            SET @SageGrossAmount = ISNULL(@AllocatedValue, 0);
            SET @NetToStore = ROUND(@SageGrossAmount * 100.0 / (100.0 + @InvoiceVatPercentage), 2);
        END
        ELSE IF ISNULL(@TaxAmount, 0) > 0
        BEGIN
            -- Sage supplied an explicit net/tax split (e.g. a Credit Note).
            SET @NetToStore =
                CASE
                    WHEN ISNULL(@NetAmount, 0) > 0 THEN @NetAmount
                    ELSE ISNULL(@AllocatedValue, 0) - @TaxAmount
                END;
        END
        ELSE
        BEGIN
            -- No tax split (a Receipt): the Sage value is the VAT-inclusive gross.
            SET @SageGrossAmount =
                CASE
                    WHEN ISNULL(@NetAmount, 0) > 0 THEN @NetAmount
                    ELSE ISNULL(@AllocatedValue, 0)
                END;

            SET @NetToStore = ROUND(@SageGrossAmount * 100.0 / (100.0 + @InvoiceVatPercentage), 2);
        END;

        SET @VatRate = CONVERT(DECIMAL(18,2), @InvoiceVatPercentage);

        SET @ReceiptGuid = NULLIF(
            @ExistingReceiptTransactionGuid,
            '00000000-0000-0000-0000-000000000000');

        -- In pair mode the allocations above are the key. A lookup by reference
        -- would hand two invoices on one job the same CymBuild transaction.
        IF @ReceiptGuid IS NULL
           AND @IsPairMode = 0
           AND NULLIF(LTRIM(RTRIM(@ReceiptSageTransactionReference)), N'') IS NOT NULL
        BEGIN
            SELECT TOP (1)
                @ExistingReceiptGuid = t.Guid
            FROM SFin.Transactions AS t
            JOIN SFin.TransactionTypes AS tt
                ON tt.ID = t.TransactionTypeID
               AND tt.RowStatus NOT IN (0,254)
            WHERE t.RowStatus NOT IN (0,254)
              AND UPPER(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(tt.Name)), N' ', N''), N'-', N''), N'_', N'')) =
                  UPPER(REPLACE(REPLACE(REPLACE(@MaterialisedTransactionTypeName, N' ', N''), N'-', N''), N'_', N''))
              AND t.Date = @TransactionDate
              AND t.SageTransactionReference = @ReceiptSageTransactionReference
              AND t.AccountID = (
                    SELECT TOP (1) a.ID
                    FROM SCrm.Accounts AS a
                    WHERE a.Guid = @InvoiceAccountGuid
                      AND a.RowStatus NOT IN (0,254)
              )
              AND t.JobID = (
                    SELECT TOP (1) j2.ID
                    FROM SJob.Jobs AS j2
                    WHERE j2.Guid = @InvoiceJobGuid
                      AND j2.RowStatus NOT IN (0,254)
              )
            ORDER BY t.ID DESC;

            SET @ReceiptGuid = @ExistingReceiptGuid;
        END;

        IF @ReceiptGuid IS NULL
           OR @ReceiptGuid = '00000000-0000-0000-0000-000000000000'
        BEGIN
            SET @ReceiptGuid = NEWID();
        END;

        EXECUTE SFin.TransactionsUpsert
             @AccountGuid = @InvoiceAccountGuid,
             @JobGuid = @InvoiceJobGuid,
             @TransactionTypeGuid = @MaterialisedTransactionTypeGuid,
             @Date = @TransactionDate,
             @PurchaseOrderNumber = @InvoicePurchaseOrderNumber,
             @SageTransactionReference = @ReceiptSageTransactionReference,
             @OrganisationalUnitGuid = @InvoiceOrganisationalUnitGuid,
             @CreatedByUserGuid = @CreatedByUserGuid,
             @SurveyorGuid = @InvoiceSurveyorGuid,
             @CreditTermsGuid = @InvoiceCreditTermsGuid,
             @Guid = @ReceiptGuid,
             @Batched = 0,
             @ExpectedDate = @ExpectedDate;

        SELECT TOP (1)
            @ReceiptTransactionId = t.ID
        FROM SFin.Transactions AS t
        WHERE t.Guid = @ReceiptGuid
          AND t.RowStatus NOT IN (0,254)
        ORDER BY t.ID DESC;

        IF ISNULL(@ReceiptTransactionId, -1) <= 0
        BEGIN
            ;THROW 60000, N'Sage allocation-source transaction could not be resolved after upsert.', 1;
        END;

        -- SFin.TransactionsUpsert always inserts a brand-new transaction with
        -- Batched = 1 (it ignores @Batched on insert - new manually-raised
        -- transactions must start in the approval batch). A Sage-materialised
        -- receipt is already confirmed by Sage, so it must never sit there
        -- waiting for manual approval; correct it directly here rather than
        -- relying on a later poll to update it through TransactionsUpsert's
        -- update path.
        UPDATE SFin.Transactions
        SET Batched = 0
        WHERE ID = @ReceiptTransactionId
          AND RowStatus NOT IN (0,254)
          AND Batched = 1;

        -- CYB-555-TAKEOVER-TYPE: when a type 1/5 row takes over a type 4
        -- fallback Receipt (above), the transaction must become what Sage says
        -- settled the invoice. SFin.TransactionsUpsert never changes the type
        -- of an existing transaction, so a Credit Note taking over the fallback
        -- would otherwise stay a Receipt. Only Sage-materialised transactions
        -- reach this point; the reference lookup above already matches on type.
        UPDATE t
        SET TransactionTypeID = tt.ID
        FROM SFin.Transactions AS t
        JOIN SFin.TransactionTypes AS tt
            ON tt.Guid = @MaterialisedTransactionTypeGuid
        WHERE t.ID = @ReceiptTransactionId
          AND t.RowStatus NOT IN (0,254)
          AND t.TransactionTypeID <> tt.ID;

        SELECT TOP (1)
            @ReceiptDetailGuid = td.Guid
        FROM SFin.TransactionDetails AS td
        WHERE td.TransactionID = @ReceiptTransactionId
          AND td.RowStatus NOT IN (0,254)
        ORDER BY td.ID DESC;

        IF @ReceiptDetailGuid IS NULL OR @ReceiptDetailGuid = '00000000-0000-0000-0000-000000000000'
        BEGIN
            SET @ReceiptDetailGuid = NEWID();
        END;

        EXECUTE SFin.TransactionDetailsUpsert
             @TransactionGuid = @ReceiptGuid,
             @MilestoneGuid = @InvoiceMilestoneGuid,
             @ActivityGuid = @InvoiceActivityGuid,
             @Net = @NetToStore,
             @Vat = 0,
             @Gross = 0,
             @VatRate = @VatRate,
             @Description = @ReceiptDescription,
             @JobPaymentStageGuid = @InvoiceJobPaymentStageGuid,
             @Guid = @ReceiptDetailGuid,
             @RIBAStageGuid = @InvoiceRibaStageGuid,
             @InvoiceRequestItemGuid = NULL,
             @Qty = 1,
             @VatCodeGuid = @InvoiceVatCodeGuid;

        SET @AllocationGuid = NULLIF(
            @ExistingAllocationMaterialisedGuid,
            '00000000-0000-0000-0000-000000000000');

        IF @AllocationGuid IS NULL
        BEGIN
            SELECT TOP (1)
                @ExistingAllocationGuid = ta.Guid
            FROM SFin.TransactionAllocations AS ta
            WHERE ta.RowStatus NOT IN (0,254)
              AND ta.SourceTransactionID = @ReceiptTransactionId
              AND ta.TargetTransactionID = @MatchedInvoiceTransactionID
            ORDER BY ta.ID DESC;

            SET @AllocationGuid = @ExistingAllocationGuid;
        END;

        IF @AllocationGuid IS NULL
           OR @AllocationGuid = '00000000-0000-0000-0000-000000000000'
        BEGIN
            SET @AllocationGuid = NEWID();
        END;

        -- Reusing the allocation Guid makes later increases in Sage's cumulative
        -- allocated value an update, rather than a duplicate allocation.
        EXECUTE SFin.TransactionAllocationsUpsert
             @SourceTransactionGuid = @ReceiptGuid,
             @TargetTransactionGuid = @MatchedInvoiceTransactionGuid,
             @AllocatedValue = @AllocatedValue,
             @Guid = @AllocationGuid;

        SELECT TOP (1)
            @AllocationId = ta.ID
        FROM SFin.TransactionAllocations AS ta
        WHERE ta.Guid = @AllocationGuid
          AND ta.RowStatus NOT IN (0,254)
        ORDER BY ta.ID DESC;

        IF @IsPairMode = 1
        BEGIN
            -- The counterpart row is shared by every invoice it settled, so the
            -- link to this invoice's CymBuild transaction lives on the allocations.
            UPDATE pairAllocation
            SET
                MatchedSourceTransactionID = @ReceiptTransactionId,
                MatchedTargetTransactionID = @MatchedInvoiceTransactionID,
                UpdatedByUserID            = @UserId,
                UpdatedDateTimeUTC         = @NowUtc
            FROM SFin.SageExternalAllocations AS pairAllocation
            WHERE pairAllocation.RowStatus NOT IN (0,254)
              AND pairAllocation.SourceExternalTransactionID = @ExternalTransactionID
              AND pairAllocation.TargetExternalTransactionID = @InvoiceExternalTransactionID;

            UPDATE ext
            SET
                ReceiptMaterialisationError = N'',
                UpdatedByUserID             = @UserId,
                UpdatedDateTimeUTC          = @NowUtc
            FROM SFin.SageExternalTransactions AS ext
            WHERE ext.ID = @ExternalTransactionID
              AND ext.RowStatus NOT IN (0,254);
        END
        ELSE
        BEGIN
            UPDATE ext
            SET
                MaterialisedReceiptTransactionID   = @ReceiptTransactionId,
                MaterialisedReceiptTransactionGuid = @ReceiptGuid,
                MaterialisedAllocationID           = @AllocationId,
                MaterialisedAllocationGuid         = @AllocationGuid,
                ReceiptMaterialisedOnUtc           = @NowUtc,
                ReceiptMaterialisationError        = N'',
                UpdatedByUserID                    = @UserId,
                UpdatedDateTimeUTC                 = @NowUtc
            FROM SFin.SageExternalTransactions AS ext
            WHERE ext.ID = @ExternalTransactionID
              AND ext.RowStatus NOT IN (0,254);
        END;

    END TRY
    BEGIN CATCH
        UPDATE ext
        SET
            ReceiptMaterialisationError = LEFT(ERROR_MESSAGE(), 2000),
            UpdatedByUserID             = @UserId,
            UpdatedDateTimeUTC          = GETUTCDATE()
        FROM SFin.SageExternalTransactions AS ext
        WHERE ext.ID = @ExternalTransactionID
          AND ext.RowStatus NOT IN (0,254);

        THROW;
    END CATCH;
END;
GO
