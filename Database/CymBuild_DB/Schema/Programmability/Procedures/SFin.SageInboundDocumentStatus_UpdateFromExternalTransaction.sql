SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[SageInboundDocumentStatus_UpdateFromExternalTransaction]')
GO
CREATE PROCEDURE [SFin].[SageInboundDocumentStatus_UpdateFromExternalTransaction]
(
    @CymBuildDocumentGuid UNIQUEIDENTIFIER,
    @ExternalTransactionID BIGINT,
    @NextPollDueOnUtc DATETIME2(7) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @NowUtc                    DATETIME2(7) = GETUTCDATE(),
        @GrossAmount               DECIMAL(18,2),
        @AllocatedValue            DECIMAL(18,2),
        @OutstandingAmount         DECIMAL(18,2),
        @DocumentDiscountedValue   DECIMAL(18,2),
        @IsPaid                    BIT,
        @IsFullyPaid               BIT,
        @PaymentStateCode          NVARCHAR(30),
        @TransactionDate           DATE,
        @SageTransactionReference  NVARCHAR(100),
        @SecondReference           NVARCHAR(100),
        @SageTransactionTypeCode   INT,
        @TerminalStatusCode        NVARCHAR(30),
        @IsTerminalState           BIT;

    SELECT
        @GrossAmount               = ext.GrossAmount,
        @AllocatedValue            = ext.AllocatedValue,
        @OutstandingAmount         = ext.OutstandingAmount,
        @DocumentDiscountedValue   = ext.DocumentDiscountedValue,
        @IsPaid                    = ext.IsPaid,
        @IsFullyPaid               = ext.IsFullyPaid,
        @PaymentStateCode          = ext.PaymentStateCode,
        @TransactionDate           = ext.TransactionDate,
        @SageTransactionReference  = ext.SageTransactionReference,
        @SecondReference           = ext.SecondReference,
        @SageTransactionTypeCode   = ext.SageTransactionTypeCode
    FROM SFin.SageExternalTransactions AS ext
    WHERE ext.ID = @ExternalTransactionID
      AND ext.RowStatus NOT IN (0,254);

    IF @PaymentStateCode IS NULL
    BEGIN
        RAISERROR('Sage external transaction not found for status update.', 16, 1);
        RETURN;
    END;

    SET @IsTerminalState =
        CASE
            WHEN ISNULL(@IsFullyPaid, 0) = 1
              OR ISNULL(@OutstandingAmount, 0) <= 0
                THEN 1
            ELSE 0
        END;

    SET @TerminalStatusCode =
        CASE
            WHEN @IsTerminalState = 1 THEN N'Succeeded'
            WHEN @PaymentStateCode = N'PartiallyPaid' THEN N'PartiallyPaid'
            WHEN @PaymentStateCode = N'Unpaid' THEN N'Pending'
            WHEN @PaymentStateCode = N'OverAllocated' THEN N'Succeeded'
            ELSE N'Pending'
        END;

    UPDATE s
    SET
        LastGrossAmount               = ISNULL(@GrossAmount, 0),
        LastAllocatedValue            = ISNULL(@AllocatedValue, 0),
        LastOutstandingAmount         = ISNULL(@OutstandingAmount, 0),
        LastDocumentDiscountedValue   = ISNULL(@DocumentDiscountedValue, 0),
        LastIsPaid                    = ISNULL(@IsPaid, 0),
        LastIsFullyPaid               = ISNULL(@IsFullyPaid, 0),
        LastPaymentStateCode          = ISNULL(@PaymentStateCode, N'Unknown'),
        LastTransactionDate           = @TransactionDate,
        LastSageTransactionReference  = ISNULL(@SageTransactionReference, N''),
        LastSecondReference           = ISNULL(@SecondReference, N''),
        LastSageTransactionTypeCode   = ISNULL(@SageTransactionTypeCode, -1),
        StatusCode                    = @TerminalStatusCode,
        LastSucceededOnUtc            = @NowUtc,
        LastSourceWatermarkUtc        = @NowUtc,
        NextPollDueOnUtc              = CASE
                                            WHEN @IsTerminalState = 1 THEN NULL
                                            ELSE @NextPollDueOnUtc
                                        END,
        PollAttemptCount              = ISNULL(s.PollAttemptCount, 0) + 1,
        IsTerminalState               = @IsTerminalState,
        IsInProgress                  = 0,
        InProgressClaimedOnUtc        = NULL,
        LastError                     = NULL,
        UpdatedByUserID               = SCore.GetCurrentUserId(),
        UpdatedDateTimeUTC            = @NowUtc
    FROM SFin.SageInboundDocumentStatus AS s
    WHERE s.CymBuildDocumentGuid = @CymBuildDocumentGuid
      AND s.RowStatus NOT IN (0,254);

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('Sage inbound document status row not found.', 16, 1);
        RETURN;
    END;
END;
GO