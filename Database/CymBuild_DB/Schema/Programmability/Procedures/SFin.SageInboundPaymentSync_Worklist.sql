SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[SageInboundPaymentSync_Worklist]')
GO

        CREATE PROCEDURE [SFin].[SageInboundPaymentSync_Worklist]
        (
            @BatchSize INT = 25,
            @StaleClaimMinutes INT = 15
        )
        AS
        BEGIN
            SET NOCOUNT ON;
            SET XACT_ABORT ON;

            DECLARE @NowUtc DATETIME2(7) = GETUTCDATE();

            ;WITH Claimable AS
            (
                SELECT TOP (@BatchSize)
                    s.ID
                FROM SFin.SageInboundDocumentStatus AS s WITH (UPDLOCK, READPAST, ROWLOCK)
                WHERE s.RowStatus NOT IN (0,254)
                  AND ISNULL(s.IsTerminalState, 0) = 0
                  AND
                  (
                        ISNULL(s.IsInProgress, 0) = 0
                     OR (
                            s.IsInProgress = 1
                        AND s.InProgressClaimedOnUtc IS NOT NULL
                        AND DATEADD(MINUTE, @StaleClaimMinutes, s.InProgressClaimedOnUtc) <= @NowUtc
                        )
                  )
                  AND
                  (
                        s.NextPollDueOnUtc IS NULL
                     OR s.NextPollDueOnUtc <= @NowUtc
                  )
                ORDER BY
                    CASE
                        WHEN s.StatusCode = N'PartiallyPaid' THEN 0
                        WHEN s.StatusCode = N'RetryPending' THEN 1
                        WHEN s.StatusCode = N'Pending' THEN 2
                        ELSE 3
                    END,
                    ISNULL(s.NextPollDueOnUtc, '19000101'),
                    s.ID
            )
            UPDATE s
            SET
                IsInProgress = 1,
                InProgressClaimedOnUtc = @NowUtc,
                StatusCode = CASE
                                WHEN s.StatusCode IN (N'Pending', N'RetryPending', N'PartiallyPaid')
                                    THEN N'InProgress'
                                ELSE s.StatusCode
                             END,
                UpdatedByUserID = SCore.GetCurrentUserId(),
                UpdatedDateTimeUTC = @NowUtc
            OUTPUT
                inserted.ID,
                inserted.CymBuildEntityTypeID,
                inserted.CymBuildDocumentGuid,
                inserted.CymBuildDocumentID,
                inserted.InvoiceRequestID,
                inserted.TransactionID,
                inserted.JobID,
                inserted.SageDataset,
                inserted.SageAccountReference,
                inserted.SageDocumentNo,
                inserted.StatusCode
            FROM SFin.SageInboundDocumentStatus AS s
            JOIN Claimable AS c
                ON c.ID = s.ID;
        END;
        
GO