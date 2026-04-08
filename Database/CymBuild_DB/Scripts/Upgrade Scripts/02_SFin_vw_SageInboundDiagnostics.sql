SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
    Convenience view for unfiltered admin grids and ad-hoc support queries.
*/
CREATE OR ALTER VIEW [SFin].[vw_SageInboundDiagnostics]
AS
SELECT
    d.ID,
    d.Guid,
    d.CymBuildEntityTypeID,
    d.CymBuildDocumentGuid,
    d.CymBuildDocumentID,
    d.InvoiceRequestID,
    d.TransactionID,
    d.JobID,
    d.SageDataset,
    d.SageAccountReference,
    d.SageDocumentNo,
    d.LastOperationName,
    d.StatusCode,
    d.IsInProgress,
    d.InProgressClaimedOnUtc,
    d.LastSucceededOnUtc,
    d.LastFailedOnUtc,
    d.LastError,
    d.LastErrorIsRetryable,
    d.LastSourceWatermarkUtc,
    d.CreatedByUserID,
    d.CreatedDateTimeUTC,
    d.UpdatedByUserID,
    d.UpdatedDateTimeUTC,
    d.LastAttemptedOnUtc,
    d.LastCompletedOnUtc,
    d.LastAttemptIsSuccess,
    d.LastAttemptErrorMessage,
    d.LastAttemptIsRetryableFailure,
    d.LastAttemptResponseStatus,
    d.LastAttemptResponseDetail,
    d.CanRequeue,
    d.CanForceRequeue
FROM SFin.tvf_SageInboundDiagnostics(DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS d;
GO
