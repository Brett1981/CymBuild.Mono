SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[SageInboundReceiptAndAllocation_Materialise]')
GO

CREATE PROCEDURE [SFin].[SageInboundReceiptAndAllocation_Materialise]
(
    @ExternalTransactionID BIGINT
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

        @AllocatedValue DECIMAL(18,2),
        @NetAmount DECIMAL(18,2),
        @TaxAmount DECIMAL(18,2),
        @TransactionDate DATE,
        @SageTransactionReference NVARCHAR(100),

        @InvoiceNumber NVARCHAR(30),
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

        @ReceiptTransactionTypeGuid UNIQUEIDENTIFIER,
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
        @ExistingAllocationMaterialisedGuid UNIQUEIDENTIFIER;

    SET @UserId = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);
    SET @SessionUserGuid = SCore.GetCurrentUserGuid();

    BEGIN TRY
        SELECT
            @MatchedInvoiceTransactionID        = ext.MatchedTransactionID,
            @AllocatedValue                     = ext.AllocatedValue,
            @NetAmount                          = ext.NetAmount,
            @TaxAmount                          = ext.TaxAmount,
            @TransactionDate                    = ext.TransactionDate,
            @SageTransactionReference           = ext.SageTransactionReference,
            @ExistingReceiptTransactionGuid     = ext.MaterialisedReceiptTransactionGuid,
            @ExistingAllocationMaterialisedGuid = ext.MaterialisedAllocationGuid
        FROM SFin.SageExternalTransactions AS ext
        WHERE ext.ID = @ExternalTransactionID
          AND ext.RowStatus NOT IN (0,254);

        IF ISNULL(@MatchedInvoiceTransactionID, -1) <= 0
        BEGIN
            RETURN;
        END;

        IF ISNULL(@AllocatedValue, 0) <= 0
        BEGIN
            RETURN;
        END;

        IF @ExistingReceiptTransactionGuid IS NOT NULL
           AND @ExistingReceiptTransactionGuid <> '00000000-0000-0000-0000-000000000000'
           AND @ExistingAllocationMaterialisedGuid IS NOT NULL
           AND @ExistingAllocationMaterialisedGuid <> '00000000-0000-0000-0000-000000000000'
        BEGIN
            RETURN;
        END;

        SELECT
            @MatchedInvoiceTransactionGuid = t.Guid,
            @InvoiceNumber                 = t.Number,
            @InvoicePurchaseOrderNumber    = t.PurchaseOrderNumber
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
            @InvoiceVatCodeGuid         = vc.Guid
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

        SET @CreatedByUserGuid = ISNULL(@InvoiceSurveyorGuid, @SessionUserGuid);
        SET @ExpectedDate = @TransactionDate;

        SELECT TOP (1)
            @ReceiptTransactionTypeGuid = tt.Guid
        FROM SFin.TransactionTypes AS tt
        WHERE tt.RowStatus NOT IN (0,254)
          AND tt.Name = N'Receipt'
        ORDER BY tt.ID;

        IF @ReceiptTransactionTypeGuid IS NULL
        BEGIN
            ;THROW 60000, N'Could not resolve finance TransactionType = Receipt.', 1;
        END;

        SET @ReceiptSageTransactionReference =
            LEFT(N'PMT - ' + ISNULL(@SageTransactionReference, N'') + N' / ' + ISNULL(@InvoiceNumber, N''), 50);

        SET @ReceiptDescription =
            LEFT(
                N'PMT - ' + ISNULL(@SageTransactionReference, N'') + N' / ' + ISNULL(@InvoiceNumber, N'')
                + CASE
                    WHEN ISNULL(@InvoiceDescription, N'') = N'' THEN N''
                    ELSE CHAR(13) + CHAR(10) + @InvoiceDescription
                  END,
                2000
            );

        SET @NetToStore =
            CASE
                WHEN ISNULL(@NetAmount, 0) > 0 THEN @NetAmount
                ELSE ISNULL(@AllocatedValue, 0) - ISNULL(@TaxAmount, 0)
            END;

        SET @VatRate =
            CASE
                WHEN ISNULL(@NetToStore, 0) > 0
                 AND ISNULL(@TaxAmount, 0) > 0
                    THEN ROUND((@TaxAmount / NULLIF(@NetToStore, 0)) * 100.0, 2)
                ELSE 0
            END;

        SELECT TOP (1)
            @ExistingReceiptGuid = t.Guid
        FROM SFin.Transactions AS t
        JOIN SFin.TransactionTypes AS tt
            ON tt.ID = t.TransactionTypeID
        WHERE t.RowStatus NOT IN (0,254)
          AND tt.RowStatus NOT IN (0,254)
          AND tt.Name = N'Receipt'
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

        IF @ReceiptGuid IS NULL OR @ReceiptGuid = '00000000-0000-0000-0000-000000000000'
        BEGIN
            SET @ReceiptGuid = NEWID();

             EXECUTE SFin.TransactionsUpsert
                 @AccountGuid = @InvoiceAccountGuid,
                 @JobGuid = @InvoiceJobGuid,
                 @TransactionTypeGuid = @ReceiptTransactionTypeGuid,
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
        END;

        SELECT TOP (1)
            @ReceiptTransactionId = t.ID
        FROM SFin.Transactions AS t
        WHERE t.Guid = @ReceiptGuid
          AND t.RowStatus NOT IN (0,254)
        ORDER BY t.ID DESC;

        IF ISNULL(@ReceiptTransactionId, -1) <= 0
        BEGIN
            ;THROW 60000, N'Receipt transaction could not be resolved after upsert.', 1;
        END;

        SELECT TOP (1)
            @ReceiptDetailGuid = td.Guid
        FROM SFin.TransactionDetails AS td
        WHERE td.TransactionID = @ReceiptTransactionId
          AND td.RowStatus NOT IN (0,254)
        ORDER BY td.ID DESC;

        IF @ReceiptDetailGuid IS NULL OR @ReceiptDetailGuid = '00000000-0000-0000-0000-000000000000'
        BEGIN
            SET @ReceiptDetailGuid = NEWID();

            IF @InvoiceVatCodeGuid IS NULL
               OR @InvoiceVatCodeGuid = '00000000-0000-0000-0000-000000000000'
            BEGIN
                ;THROW 60080, N'Invoice VAT code could not be resolved for receipt materialisation.', 1;
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
        END;

        SELECT TOP (1)
            @ExistingAllocationGuid = ta.Guid
        FROM SFin.TransactionAllocations AS ta
        WHERE ta.RowStatus NOT IN (0,254)
          AND ta.SourceTransactionID = @ReceiptTransactionId
          AND ta.TargetTransactionID = @MatchedInvoiceTransactionID
          AND ta.AllocatedAmount = @AllocatedValue
        ORDER BY ta.ID DESC;

        SET @AllocationGuid = @ExistingAllocationGuid;

        IF @AllocationGuid IS NULL OR @AllocationGuid = '00000000-0000-0000-0000-000000000000'
        BEGIN
            SET @AllocationGuid = NEWID();

            EXECUTE SFin.TransactionAllocationsUpsert
                 @SourceTransactionGuid = @ReceiptGuid,
                 @TargetTransactionGuid = @MatchedInvoiceTransactionGuid,
                 @AllocatedValue = @AllocatedValue,
                 @Guid = @AllocationGuid;
        END;

        SELECT TOP (1)
            @AllocationId = ta.ID
        FROM SFin.TransactionAllocations AS ta
        WHERE ta.Guid = @AllocationGuid
          AND ta.RowStatus NOT IN (0,254)
        ORDER BY ta.ID DESC;

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