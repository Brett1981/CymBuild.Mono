SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceAutomation_GenerateFromPendingTriggerInstances_ForJob]')
GO
CREATE PROCEDURE [SFin].[InvoiceAutomation_GenerateFromPendingTriggerInstances_ForJob]
(
      @JobGuid             UNIQUEIDENTIFIER
    , @RequesterUserGuid    UNIQUEIDENTIFIER
    , @Notes               NVARCHAR(500) = N''
    , @DefaultPaymentStatusId BIGINT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RequesterUserId INT = ISNULL(SCore.GetCurrentUserId(), -1);

    -- If you have a canonical lookup for default payment status, replace this block.
    IF (@DefaultPaymentStatusId IS NULL)
    BEGIN
        SELECT TOP (1) @DefaultPaymentStatusId = ps.ID
        FROM SFin.InvoicePaymentStatus ps
        WHERE ps.RowStatus NOT IN (0,254)
        ORDER BY ps.ID;
    END

    -- Create only for this job, override blocking (paused/manual) since user confirmed
    EXEC SFin.InvoiceRequests_CreateFromTriggerInstances_ForJob
          @JobGuid = @JobGuid
        , @AutomationRunGuid = NULL
        , @InvoiceBatchGuid = NULL
        , @RequesterUserId = @RequesterUserId
        , @DefaultInvoicePaymentStatusId = @DefaultPaymentStatusId
        , @OverrideBlocking = 1;
END
GO