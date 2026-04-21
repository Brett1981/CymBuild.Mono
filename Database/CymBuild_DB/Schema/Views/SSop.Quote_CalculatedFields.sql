SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[Quote_CalculatedFields]
AS
SELECT
    q.ID,
    QuoteStatus =
        CASE
            ----------------------------------------------------------------------
            -- 1) JOB-DRIVEN COMPLETION (highest priority)
            --    Explicit calculated override retained by design.
            ----------------------------------------------------------------------
			WHEN LatestWorkflowStatus.Guid = Statuses.Reopened
                THEN N'Reopened'

            WHEN JobAgg.CreatedJobsCount >= 1
                 AND JobAgg.PendingJobsCount = 0
                THEN N'Complete'

            WHEN JobAgg.CreatedJobsCount >= 1
                 AND JobAgg.PendingJobsCount >= 1
                THEN N'Part Complete'

            ----------------------------------------------------------------------
            -- 2) WORKFLOW IS SOURCE OF TRUTH
            --    If there is a latest workflow transition, show it.
            --    This prevents inferred "Ready to Send" / legacy flags from
            --    overriding a real latest workflow such as "Quoting".
            ----------------------------------------------------------------------
			

            WHEN LatestWorkflowStatus.Guid = Statuses.Declined
                THEN N'Declined'

            WHEN LatestWorkflowStatus.Guid = Statuses.Dead
                THEN N'Dead'

            WHEN LatestWorkflowStatus.Guid = Statuses.Accepted
                THEN N'Accepted'

            WHEN LatestWorkflowStatus.Guid = Statuses.Rejected
                THEN N'Rejected'

            WHEN LatestWorkflowStatus.Guid = Statuses.secondChase
                THEN N'2nd Chase'

            WHEN LatestWorkflowStatus.Guid = Statuses.firstChase
                THEN N'1st Chase'

            WHEN LatestWorkflowStatus.Guid = Statuses.Sent
                THEN N'Sent'

            WHEN LatestWorkflowStatus.Guid = Statuses.ReadyToSend
                THEN N'Ready to Send'

			

            ----------------------------------------------------------------------
            -- 3) CUSTOM / OTHER WORKFLOW NAMES
            --    Preserve non-standard workflow names once standard mappings above
            --    have been handled.
            ----------------------------------------------------------------------
            WHEN LatestWorkflowStatus.Name IS NOT NULL
                 AND LatestWorkflowStatus.Name NOT IN
                 (
                     N'N/A',
                     N'Sent',
                     N'Accepted',
                     N'Rejected',
                     N'Dead',
                     N'Ready to Send',
                     N'Declined',
                     N'Complete',
                     N'Part Complete',
                     N'1st Chase',
                     N'2nd Chase'
                 )
                THEN LatestWorkflowStatus.Name

            ----------------------------------------------------------------------
            -- 4) LEGACY FALLBACK ONLY WHEN NO WORKFLOW EXISTS
            --    Retained for backward compatibility with older rows that do not
            --    yet have transition history.
            ----------------------------------------------------------------------
            WHEN LatestWorkflowStatus.Guid IS NULL
                 AND q.DateDeclinedToQuote IS NOT NULL
                THEN N'Declined'

            WHEN LatestWorkflowStatus.Guid IS NULL
                 AND q.DeadDate IS NOT NULL
                THEN N'Dead'

            WHEN LatestWorkflowStatus.Guid IS NULL
                 AND q.DateAccepted IS NOT NULL
                THEN N'Accepted'

            WHEN LatestWorkflowStatus.Guid IS NULL
                 AND q.DateRejected IS NOT NULL
                THEN N'Rejected'

            WHEN LatestWorkflowStatus.Guid IS NULL
                 AND q.ChaseDate2 IS NOT NULL
                THEN N'2nd Chase'

            WHEN LatestWorkflowStatus.Guid IS NULL
                 AND q.ChaseDate1 IS NOT NULL
                THEN N'1st Chase'

            WHEN LatestWorkflowStatus.Guid IS NULL
                 AND q.DateSent IS NOT NULL
                THEN N'Sent'

            WHEN LatestWorkflowStatus.Guid IS NULL
                 AND q.IsFinal = 1
                THEN N'Ready to Send'

            WHEN LatestWorkflowStatus.Guid IS NULL
                 AND q.ExpiryDate IS NOT NULL
                 AND q.ExpiryDate < NowUtc.NowUtc
                THEN N'Expired'

            ----------------------------------------------------------------------
            -- 5) DEFAULT
            ----------------------------------------------------------------------
            ELSE N'Quoting'
        END
FROM SSop.Quotes AS q

OUTER APPLY
(
    SELECT NowUtc = CONVERT(datetime2(7), SYSUTCDATETIME())
) AS NowUtc

OUTER APPLY
(
    SELECT
        IsRevision =
            CASE
                WHEN ISNULL(q.RevisionNumber, 0) > 0
                     OR q.OriginalQuoteId <> -1
                    THEN 1
                ELSE 0
            END
) AS IsRevision

OUTER APPLY
(
    SELECT
        TotalItems  = COUNT(1),
        ValuedItems = SUM(CASE WHEN qi.Net > 0 THEN 1 ELSE 0 END)
    FROM SSop.QuoteItems qi
    WHERE qi.QuoteId = q.ID
      AND qi.RowStatus NOT IN (0,254)
) AS QuoteItemAgg

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
        Declined    = CONVERT(uniqueidentifier, '708C00E6-F45F-4CB2-8E91-A80B8B8E802E'),
        Dead        = CONVERT(uniqueidentifier, '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D'),
        Accepted    = CONVERT(uniqueidentifier, '21A29AEE-2D99-4DA3-8182-F31813B0C498'),
        ReadyToSend = CONVERT(uniqueidentifier, '02A2237F-2AE7-4E05-926F-38E8B7D050A0'),
        Rejected    = CONVERT(uniqueidentifier, '0A6A71F7-B39F-4213-997E-2B3A13B6144C'),
        Sent        = CONVERT(uniqueidentifier, '25D5491C-42A8-4B04-B3AC-D648AF0F8032'),
        firstChase  = CONVERT(uniqueidentifier, '9FF22CEA-A2A6-4907-9B2D-E62DF8150913'),
        secondChase = CONVERT(uniqueidentifier, '1F01C16B-1A73-4844-A938-FE357405FD93'),
		Reopened    = CONVERT(uniqueidentifier, '34EF363A-C8F7-4BA8-A2C6-067EBAEF12FD')
) AS Statuses

OUTER APPLY
(
    SELECT TOP (1)
        Name = wfs.Name,
        Guid = wfs.Guid
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs
        ON wfs.ID = dot.StatusID
    WHERE dot.DataObjectGuid = q.Guid
      AND dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
    ORDER BY dot.ID DESC
) AS LatestWorkflowStatus

OUTER APPLY
(
    SELECT
        IsPreSentQuoting =
            CASE
                WHEN ISNULL
                     (
                         LatestWorkflowStatus.Guid,
                         CONVERT(uniqueidentifier, '00000000-0000-0000-0000-000000000000')
                     ) NOT IN
                     (
                         Statuses.Sent,
                         Statuses.Accepted,
                         Statuses.Rejected,
                         Statuses.Declined,
                         Statuses.Dead,
                         Statuses.firstChase,
                         Statuses.secondChase
                     )
                     AND q.DateSent IS NULL
                     AND q.DateAccepted IS NULL
                     AND q.DateRejected IS NULL
                     AND q.DateDeclinedToQuote IS NULL
                     AND q.DeadDate IS NULL
                     AND q.ChaseDate1 IS NULL
                     AND q.ChaseDate2 IS NULL
                     AND q.IsFinal = 0
                    THEN 1
                ELSE 0
            END
) AS QuotePhase;
GO