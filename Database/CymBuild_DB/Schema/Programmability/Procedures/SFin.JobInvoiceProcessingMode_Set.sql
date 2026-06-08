SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[JobInvoiceProcessingMode_Set]')
GO
/* =========================================================
   4) Set Job InvoiceProcessingMode (audited + synced)
   ========================================================= */
CREATE PROCEDURE [SFin].[JobInvoiceProcessingMode_Set]
(
      @JobGuid            UNIQUEIDENTIFIER
    , @NewMode            TINYINT
    , @ChangedByUserGuid  UNIQUEIDENTIFIER = NULL
    , @Reason             NVARCHAR(500) = N''
    , @Source             NVARCHAR(50) = N'UI'
)
AS
BEGIN
    SET NOCOUNT ON;

    IF (@NewMode NOT IN (0,1,2))
        THROW 50001, 'Invalid InvoiceProcessingMode. Allowed values: 0=Automated,1=Manual,2=Paused.', 1;

    DECLARE @JobId INT, @OldMode TINYINT, @ChangedByUserId INT;

    SELECT TOP (1)
          @JobId = j.ID
        , @OldMode = j.InvoiceProcessingMode
    FROM SJob.Jobs j
    WHERE j.Guid = @JobGuid
      AND j.RowStatus NOT IN (0,254);

    IF (@JobId IS NULL)
        THROW 50002, 'Job not found (or inactive).', 1;

    SET @ChangedByUserId = ISNULL(SCore.GetCurrentUserId(), -1);

    IF (@OldMode = @NewMode)
        RETURN;

    BEGIN TRAN;

    UPDATE j
    SET
          j.InvoiceProcessingMode = @NewMode
        , j.ManualInvoicingEnabled = CASE WHEN @NewMode = 1 THEN 1 ELSE 0 END
    FROM SJob.Jobs j
    WHERE j.ID = @JobId;

    INSERT INTO SFin.InvoiceProcessingModeHistory
    (
          JobId, JobGuid, OldMode, NewMode
        , ChangedByUserId, ChangedByUserGuid
        , Reason, Source
    )
    VALUES
    (
          @JobId, @JobGuid, @OldMode, @NewMode
        , @ChangedByUserId, @ChangedByUserGuid
        , ISNULL(@Reason, N''), ISNULL(@Source, N'UI')
    );

    COMMIT;
END
GO