CREATE OR ALTER PROCEDURE [SFin].[SageInboundDocumentStatus_MarkSuccess]
(
    @CymBuildDocumentGuid UNIQUEIDENTIFIER,
    @LastSourceWatermarkUtc DATETIME2(7) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2(7) = GETUTCDATE();

    UPDATE s
    SET
        StatusCode             = N'Succeeded',
        IsInProgress           = 0,
        InProgressClaimedOnUtc = NULL,
        LastSucceededOnUtc     = @NowUtc,
        LastError              = N'',
        LastErrorIsRetryable   = NULL,
        LastSourceWatermarkUtc = @LastSourceWatermarkUtc,
        UpdatedByUserID        = SCore.GetCurrentUserId(),
        UpdatedDateTimeUTC     = @NowUtc
    FROM SFin.SageInboundDocumentStatus s
    WHERE s.CymBuildDocumentGuid = @CymBuildDocumentGuid
      AND s.RowStatus NOT IN (0,254);
END;
GO