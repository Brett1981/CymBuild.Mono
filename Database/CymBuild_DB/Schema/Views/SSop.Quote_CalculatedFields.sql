SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* =============================================================================
   CYB-101 – Quote status calculation fix (Job-based completion)

   KEY FIX:
   - Complete/Part Complete must be driven by Jobs Created vs Jobs Awaiting Creation,
     NOT QuoteItems count (because items can consolidate into fewer jobs).

   RULES:
   - Complete      = CreatedJobsCount >= 1 AND PendingJobsCount = 0
   - Part Complete = CreatedJobsCount >= 1 AND PendingJobsCount >= 1
============================================================================= */
CREATE VIEW [SSop].[Quote_CalculatedFields]
    --WITH SCHEMABINDING
AS
SELECT
    q.ID,
    QuoteStatus =
        CASE
            ------------------------------------------------------------------
            -- 1) JOB-DRIVEN COMPLETION (HIGHEST PRIORITY)  ✅ FIXED
            ------------------------------------------------------------------
            WHEN JobAgg.CreatedJobsCount >= 1
                 AND JobAgg.PendingJobsCount = 0
            THEN N'Complete'

            WHEN JobAgg.CreatedJobsCount >= 1
                 AND JobAgg.PendingJobsCount >= 1
            THEN N'Part Complete'

            ------------------------------------------------------------------
            -- 2) Standard terminals / progress (must beat Expiry)
            ------------------------------------------------------------------
            WHEN LatestWorkflowStatus.Guid = Statuses.Declined
                 OR q.DateDeclinedToQuote IS NOT NULL
            THEN N'Declined'

			WHEN LatestWorkflowStatus.Guid = Statuses.firstChase
				OR q.ChaseDate1 IS NOT NULL
			THEN N'1st Chase'

			WHEN LatestWorkflowStatus.Guid = Statuses.secondChase
				OR q.ChaseDate2 IS NOT NULL
			THEN N'2nd Chase'

            WHEN LatestWorkflowStatus.Guid = Statuses.Dead
                 OR q.DeadDate IS NOT NULL
            THEN N'Dead'

            WHEN LatestWorkflowStatus.Guid = Statuses.Accepted
                 OR q.DateAccepted IS NOT NULL
            THEN N'Accepted'

            WHEN LatestWorkflowStatus.Guid = Statuses.Rejected
                 OR q.DateRejected IS NOT NULL
            THEN N'Rejected'

            WHEN LatestWorkflowStatus.Guid = Statuses.Sent
                 OR q.DateSent IS NOT NULL
            THEN N'Sent'

            WHEN LatestWorkflowStatus.Guid = Statuses.ReadyToSend
                 OR q.IsFinal = 1
            THEN N'Ready to Send'

            ------------------------------------------------------------------
            -- 3) Ready to Send (data-driven)
            ------------------------------------------------------------------
            WHEN QuotePhase.IsPreSentQuoting = 1
                 AND QuoteItemAgg.TotalItems > 0
                 AND QuoteItemAgg.ValuedItems > 0
            THEN N'Ready to Send'

            ------------------------------------------------------------------
            -- 4) Expired ONLY when still quoting-phase (pre-sent)
            ------------------------------------------------------------------
            WHEN QuotePhase.IsPreSentQuoting = 1
                 AND q.ExpiryDate IS NOT NULL
                 AND q.ExpiryDate < NowUtc.NowUtc
            THEN N'Expired'

            ------------------------------------------------------------------
            -- 5) Custom workflow names (non-standard)
            --    IMPORTANT: Do NOT allow operational deadline statuses through.
            ------------------------------------------------------------------
            WHEN LatestWorkflowStatus.Name IS NOT NULL
                 AND LatestWorkflowStatus.Name NOT IN
                 (
                        N'N/A',
                        N'Quoting',
                        N'Sent',
                        N'Accepted',
                        N'Rejected',
                        N'Dead',
                        N'Ready to Send',
                        N'Declined',
                        N'Expired',
                        N'Complete',
                        N'Part Complete',
                        N'Is Final (Ready to Send)',
                        N'Deadline Approaching',
                        N'Deadline Missed'
                 )
            THEN LatestWorkflowStatus.Name

            ------------------------------------------------------------------
            -- 6) Default
            ------------------------------------------------------------------
            ELSE N'Quoting'
        END
FROM SSop.Quotes AS q

OUTER APPLY
(
    SELECT NowUtc = CONVERT(datetime2(7), SYSUTCDATETIME())
) AS NowUtc

-- Keep QuoteItems for valued-items and pre-sent quoting checks
OUTER APPLY
(
    SELECT
        TotalItems   = COUNT(1),
        ValuedItems  = SUM(CASE WHEN qi.Net > 0 THEN 1 ELSE 0 END)
    FROM SSop.QuoteItems qi
    WHERE qi.QuoteId = q.ID
      AND qi.RowStatus NOT IN (0,254)
) AS QuoteItemAgg

-- ✅ NEW: Job-based completion aggregation
OUTER APPLY
(
    SELECT
        CreatedJobsCount =
        (
            SELECT COUNT(DISTINCT qi.CreatedJobId)
            FROM SSop.QuoteItems qi
            WHERE qi.QuoteId = q.ID
              AND qi.RowStatus NOT IN (0,254)
              AND qi.CreatedJobId IS NOT NULL
              AND qi.CreatedJobId > 0
        ),
        PendingJobsCount =
        (
            SELECT COUNT(1)
            FROM SSop.Quote_JobsSummary js
            WHERE js.QuoteGuid = q.Guid
              AND js.RowStatus NOT IN (0,254)
        )
) AS JobAgg

OUTER APPLY
(
    SELECT
        Declined    = CONVERT(UNIQUEIDENTIFIER, '708C00E6-F45F-4CB2-8E91-A80B8B8E802E'),
        Dead        = CONVERT(UNIQUEIDENTIFIER, '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D'),
        Accepted    = CONVERT(UNIQUEIDENTIFIER, '21A29AEE-2D99-4DA3-8182-F31813B0C498'),
        ReadyToSend = CONVERT(UNIQUEIDENTIFIER, '02A2237F-2AE7-4E05-926F-38E8B7D050A0'),
        Rejected    = CONVERT(UNIQUEIDENTIFIER, '0A6A71F7-B39F-4213-997E-2B3A13B6144C'),
        Sent        = CONVERT(UNIQUEIDENTIFIER, '25D5491C-42A8-4B04-B3AC-D648AF0F8032'),
		firstChase  = CONVERT(UNIQUEIDENTIFIER, '9FF22CEA-A2A6-4907-9B2D-E62DF8150913'),
		secondChase = CONVERT(UNIQUEIDENTIFIER, '1F01C16B-1A73-4844-A938-FE357405FD93')
) AS Statuses

OUTER APPLY
(
    SELECT TOP (1)
        Name = wfs.Name,
        Guid = wfs.Guid
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.DataObjectGuid = q.Guid
      AND dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
) AS LatestWorkflowStatus

OUTER APPLY
(
    SELECT
        IsPreSentQuoting =
            CASE
                WHEN
                    ISNULL(LatestWorkflowStatus.Guid, CONVERT(uniqueidentifier, '00000000-0000-0000-0000-000000000000'))
                        NOT IN (Statuses.Sent, Statuses.Accepted, Statuses.Rejected, Statuses.Declined, Statuses.Dead)
                    AND q.DateSent IS NULL
                    AND q.DateAccepted IS NULL
                    AND q.DateRejected IS NULL
                    AND q.DateDeclinedToQuote IS NULL
                    AND q.DeadDate IS NULL
                    AND q.IsFinal = 0
                THEN 1 ELSE 0
            END
) AS QuotePhase;
GO