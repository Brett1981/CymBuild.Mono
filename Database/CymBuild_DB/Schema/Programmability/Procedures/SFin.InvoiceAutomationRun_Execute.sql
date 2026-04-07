SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceAutomationRun_Execute]')
GO
CREATE PROCEDURE [SFin].[InvoiceAutomationRun_Execute]
(
    @RunGuid            UNIQUEIDENTIFIER = NULL OUTPUT,
    @AsOfUtc            DATETIME2(7) = NULL,
    @BatchGuid          UNIQUEIDENTIFIER = NULL OUTPUT,

    -- Optional but recommended: makes the run deterministic
    @RequesterUserGuid  UNIQUEIDENTIFIER = NULL,

    -- Defaults you said you are using
    @DefaultInvoicingType      NVARCHAR(10) = N'',  -- currently not used by Phase4To6 procs in the ZIP
    @DefaultPaymentStatusGuid  UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000',

    @Notes              NVARCHAR(MAX) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2(7) = COALESCE(@AsOfUtc, SYSUTCDATETIME());

    IF (@RunGuid IS NULL)
        SET @RunGuid = NEWID();

    -- Resolve RequesterUserGuid
    IF (@RequesterUserGuid IS NULL)
    BEGIN
        -- You already use this in EntityProperty SqlDefaultValueStatement, so it should exist
        BEGIN TRY
            SET @RequesterUserGuid = SCore.GetCurrentUserGuid();
        END TRY
        BEGIN CATCH
            -- If function missing for any reason, leave NULL and fail below
            SET @RequesterUserGuid = NULL;
        END CATCH
    END

    IF (@RequesterUserGuid IS NULL)
    BEGIN
        RAISERROR(N'InvoiceAutomationRun_Execute: RequesterUserGuid was not supplied and could not be resolved (SCore.GetCurrentUserGuid()).', 16, 1);
        RETURN;
    END

    -- Execute the real orchestration pipeline (exists in Database.zip)
    EXEC [SFin].[InvoiceAutomation_Run_Phase4To6]
          @AutomationRunGuid        = @RunGuid
        , @RequesterUserGuid        = @RequesterUserGuid
        , @DefaultPaymentStatusGuid = @DefaultPaymentStatusGuid
        , @Notes                    = @Notes
        , @NowUtc                   = @NowUtc;

    -- Return BatchGuid if created
    SELECT @BatchGuid = r.InvoiceBatchGuid
    FROM SFin.InvoiceAutomationRuns r
    WHERE r.Guid = @RunGuid;
END
GO