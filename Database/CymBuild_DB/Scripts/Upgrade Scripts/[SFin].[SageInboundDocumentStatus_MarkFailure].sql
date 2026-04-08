CREATE OR ALTER PROCEDURE [SFin].[SageInboundDocumentStatus_MarkFailure]
(
    @CymBuildDocumentGuid UNIQUEIDENTIFIER,
    @ErrorMessage NVARCHAR(MAX),
    @IsRetryable BIT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NowUtc DATETIME2(7) = GETUTCDATE();

    UPDATE s
    SET
        StatusCode             = CASE WHEN @IsRetryable = 1 THEN N'RetryPending' ELSE N'Failed' END,
        IsInProgress           = 0,
        InProgressClaimedOnUtc = NULL,
        LastFailedOnUtc        = @NowUtc,
        LastError              = ISNULL(@ErrorMessage, N''),
        LastErrorIsRetryable   = @IsRetryable,
        UpdatedByUserID        = SCore.GetCurrentUserId(),
        UpdatedDateTimeUTC     = @NowUtc
    FROM SFin.SageInboundDocumentStatus s
    WHERE s.CymBuildDocumentGuid = @CymBuildDocumentGuid
      AND s.RowStatus NOT IN (0,254);
END;
GO