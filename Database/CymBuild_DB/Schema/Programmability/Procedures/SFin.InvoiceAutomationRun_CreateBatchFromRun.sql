SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceAutomationRun_CreateBatchFromRun]')
GO
CREATE PROCEDURE [SFin].[InvoiceAutomationRun_CreateBatchFromRun]
(
    @RunGuid            UNIQUEIDENTIFIER,
    @TriggeredByUserId  INT = NULL,
    @BatchGuid          UNIQUEIDENTIFIER OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    IF (@BatchGuid IS NULL)
        SET @BatchGuid = NEWID();

    IF (@TriggeredByUserId IS NULL)
        SET @TriggeredByUserId = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);

    -- DataObject row for the batch (matches your existing FK pattern)
    DECLARE @IsInsert BIT;
    EXEC SCore.UpsertDataObject
         @Guid = @BatchGuid,
         @SchemeName = N'SFin',
         @ObjectName = N'InvoiceBatches',
         @IncludeDefaultSecurity = 0,
         @IsInsert = @IsInsert OUTPUT;

    -- Business row
    IF NOT EXISTS (SELECT 1 FROM SFin.InvoiceBatches WHERE Guid = @BatchGuid)
    BEGIN
        INSERT SFin.InvoiceBatches
        (
            RowStatus,
            Guid,
            CreatedDateTimeUTC,
            CreatedByUserId,
            AutomationRunGuid,
            CreatedCount,
            Notes,
            LegacyId,
            LegacySystemID
        )
        VALUES
        (
            1,
            @BatchGuid,
            SYSUTCDATETIME(),
            @TriggeredByUserId,
            @RunGuid,
            0,
            N'',
            NULL,
            -1
        );
    END
END
GO