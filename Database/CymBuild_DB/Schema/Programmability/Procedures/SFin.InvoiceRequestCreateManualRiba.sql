SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceRequestCreateManualRiba]')
GO
/* =============================================================================
   SFin.InvoiceRequestCreateManualRiba

   Purpose:
   - Manual creation helper for a RIBA-stage-linked InvoiceRequest
   - Delegates to SFin.InvoiceRequestAutomationCreate (manual-capable)

   Notes:
   - Always terminates statements with semicolons (avoids “Incorrect syntax near …”)
   - Defaults ExpectedDate to today (UTC date) if not supplied
   - Keeps flags manual-friendly: not automated, not zero placeholder, not reconciliation
============================================================================= */

CREATE PROCEDURE [SFin].[InvoiceRequestCreateManualRiba]
(
      @JobGuid                 UNIQUEIDENTIFIER
    , @RequesterUserGuid        UNIQUEIDENTIFIER
    , @RibaStageGuid            UNIQUEIDENTIFIER
    , @ExpectedDate             DATE = NULL
    , @PaymentStatusGuid        UNIQUEIDENTIFIER = NULL
    , @Notes                    NVARCHAR(MAX) = NULL
    , @CreatedGuid              UNIQUEIDENTIFIER OUTPUT
    , @WasInserted              BIT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Normalise inputs
    SET @Notes = ISNULL(@Notes, N'');
    SET @ExpectedDate = COALESCE(@ExpectedDate, CAST(SYSUTCDATETIME() AS DATE));

    -- Initialise OUT params defensively
    SET @CreatedGuid = NULL;
    SET @WasInserted = 0;

    -- Delegate to existing entry point (supports manual flags)
    EXEC [SFin].[InvoiceRequestAutomationCreate]
          @JobGuid                 = @JobGuid
        , @Guid                    = NULL
        , @RequesterUserGuid        = @RequesterUserGuid
        , @Notes                   = @Notes

        , @InvoicingType           = N'RIBA'
        , @ExpectedDate            = @ExpectedDate
        , @PaymentStatusGuid       = @PaymentStatusGuid

        , @IsZeroValuePlaceholder  = 0
        , @ReconciliationRequired  = 0
        , @ReconciliationReason    = N''

        , @SourceType              = N'RibaStage'
        , @SourceGuid              = @RibaStageGuid
        , @SourceIntId             = NULL

        , @AutomationRunGuid       = NULL
        , @InvoiceBatchGuid        = NULL

        , @BlockedReason           = N''

        , @CreatedGuid             = @CreatedGuid OUTPUT
        , @WasInserted             = @WasInserted OUTPUT;
END;
GO