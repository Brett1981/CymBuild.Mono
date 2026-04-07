SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* =============================================================================
   CYB-101 – Enquiry QuotingStatus (TVF) alignment fixes
   (NO workflow process changes – calculation / sync logic only)

   Why this TVF is being amended:
   - This TVF still feeds UI/legacy logic for QuotingStatus and can surface
     stale/incorrect “Quoting” indicators even when the Enquiry has no valid
     quote content, or when deadline-based statuses should update automatically.

   QA issues targeted by this change:
   - “Enquiry status still = Quoting without Quote item (no warning message).”
     (We cannot add UI messages here, but we can prevent QuotingStatus being
      driven by “empty” quotes that have zero QuoteItems.)
   - “Expired not auto changed when Quoting Deadline Date = past date.”
     (Align QuotingStatus with the same past-deadline -> Expired expectation.)
   - Supports the same “auto update” principle as the Enquiry_CalculatedFields fix:
     deadline/chase derived from Enquiry fields must not depend on creating a new
     Record Status.

   Constraints respected:
   - No changes to workflow meanings, allowed transitions, or lifecycle rules.
   - We are only adjusting how QuotingStatus is *calculated* for UI/legacy usage.
============================================================================= */
CREATE FUNCTION [SSop].[Tvf_GetEnquiryStatuses](@id INT)
RETURNS TABLE
--WITH SCHEMABINDING
AS
RETURN
(
    WITH Enq AS
    (
        SELECT
            e.ID,
            e.Guid,
            e.RowStatus,
            e.DeadDate,
            e.DeclinedToQuoteDate,
            e.QuotingDeadlineDate,
            e.ChaseDate1,
            e.ChaseDate2,
            e.IsReadyForQuoteReview
        FROM SSop.Enquiries e
        WHERE e.ID = @id
          AND e.RowStatus NOT IN (0,254)
    ),
    NowUtc AS
    (
        -- Single “now” value for consistent comparisons throughout the TVF
        SELECT NowUtc = CONVERT(datetime2(7), SYSUTCDATETIME())
    ),
    LatestEnqStatus AS
    (
        SELECT
            e.ID,
            LatestWorkflowStatusName = wfs.Name
        FROM Enq e
        OUTER APPLY
        (
            SELECT TOP (1) wfs1.Name
            FROM SCore.DataObjectTransition dot
            JOIN SCore.WorkflowStatus wfs1 ON wfs1.ID = dot.StatusID
            WHERE dot.DataObjectGuid = e.Guid
              AND dot.RowStatus NOT IN (0,254)
              AND wfs1.RowStatus NOT IN (0,254)
            ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
        ) wfs
    ),
    ServiceAgg AS
    (
        SELECT
            e.ID,
            ActiveServices = COUNT(1)
        FROM Enq e
        JOIN SSop.EnquiryServices es
            ON es.EnquiryId = e.ID
           AND es.RowStatus NOT IN (0,254)
        GROUP BY e.ID
    ),

    /* ------------------------------------------------------------------------
       Quote aggregation – IMPORTANT CHANGE:
       We only allow “quote-driven” quoting indicators to be influenced by quotes
       that have at least ONE QuoteItem.

       This directly addresses QA:
       - “Enquiry status still = Quoting without Quote item (no warning message).”

       Rationale:
       - If a quote exists but contains no items, it should not drive Enquiry-level
         quoting indicators in the legacy/TVF logic.
       - This is calculation-only; it does not prevent the quote from existing.
    ------------------------------------------------------------------------- */
    QuoteAgg AS
    (
        SELECT
            e.ID,

            TotalQuotes = COUNT(1),

            AnyComplete     = SUM(CASE WHEN qcf.QuoteStatus = N'Complete' THEN 1 ELSE 0 END),
            AnyPartComplete = SUM(CASE WHEN qcf.QuoteStatus = N'Part Complete' THEN 1 ELSE 0 END),
            AnyAccepted     = SUM(CASE WHEN qcf.QuoteStatus = N'Accepted' THEN 1 ELSE 0 END),
            AnySent         = SUM(CASE WHEN qcf.QuoteStatus = N'Sent' THEN 1 ELSE 0 END),
            AnyReadyToSend  = SUM(CASE WHEN qcf.QuoteStatus = N'Ready to Send' THEN 1 ELSE 0 END),
            AnyQuoting      = SUM(CASE WHEN qcf.QuoteStatus = N'Quoting' THEN 1 ELSE 0 END),
            AnyExpired      = SUM(CASE WHEN qcf.QuoteStatus = N'Expired' THEN 1 ELSE 0 END),

            -- derived flags (use integer math, never NULL)
            AllComplete =
                CASE
                    WHEN COUNT(1) > 0
                     AND SUM(CASE WHEN qcf.QuoteStatus = N'Complete' THEN 1 ELSE 0 END) = COUNT(1)
                    THEN 1 ELSE 0
                END,

            AllExpiredNoPositive =
                CASE
                    WHEN COUNT(1) > 0
                     AND SUM(CASE WHEN qcf.QuoteStatus = N'Expired' THEN 1 ELSE 0 END) = COUNT(1)
                     AND SUM(CASE WHEN qcf.QuoteStatus IN (N'Complete', N'Part Complete', N'Accepted', N'Sent', N'Ready to Send', N'Quoting')
                                  THEN 1 ELSE 0 END) = 0
                    THEN 1 ELSE 0
                END
        FROM Enq e
        JOIN SSop.EnquiryServices es
            ON es.EnquiryId = e.ID
           AND es.RowStatus NOT IN (0,254)
        JOIN SSop.Quotes q
            ON q.EnquiryServiceID = es.ID
           AND q.RowStatus NOT IN (0,254)

        -- Only include quotes that have at least one QuoteItem
        JOIN
        (
            SELECT qi.QuoteId
            FROM SSop.QuoteItems qi
            WHERE qi.RowStatus NOT IN (0,254)
            GROUP BY qi.QuoteId
            HAVING COUNT(1) > 0
        ) AS qHasItems
            ON qHasItems.QuoteId = q.ID

        JOIN SSop.Quote_CalculatedFields qcf
            ON qcf.ID = q.ID
        GROUP BY e.ID
    ),
    PerServiceFlags AS
    (
        SELECT
            e.ID,

            ServicesWithAnyQuote =
                COUNT(DISTINCT CASE WHEN q.ID IS NOT NULL THEN es.ID END),

            ServicesWithSent =
                COUNT(DISTINCT CASE WHEN qcf.QuoteStatus = N'Sent' THEN es.ID END),

            ServicesWithReadyToSend =
                COUNT(DISTINCT CASE WHEN qcf.QuoteStatus = N'Ready to Send' THEN es.ID END),

            ServicesWithBeyondReady =
                COUNT(DISTINCT CASE WHEN qcf.QuoteStatus IN (N'Sent', N'Accepted', N'Rejected', N'Declined', N'Dead', N'Complete', N'Part Complete')
                                    THEN es.ID END)
        FROM Enq e
        LEFT JOIN SSop.EnquiryServices es
               ON es.EnquiryId = e.ID
              AND es.RowStatus NOT IN (0,254)
        LEFT JOIN SSop.Quotes q
               ON q.EnquiryServiceID = es.ID
              AND q.RowStatus NOT IN (0,254)

        -- Only allow quotes with items to drive per-service flags too
        LEFT JOIN
        (
            SELECT qi.QuoteId
            FROM SSop.QuoteItems qi
            WHERE qi.RowStatus NOT IN (0,254)
            GROUP BY qi.QuoteId
            HAVING COUNT(1) > 0
        ) AS qHasItems
            ON qHasItems.QuoteId = q.ID

        LEFT JOIN SSop.Quote_CalculatedFields qcf
               ON qcf.ID = q.ID
              AND qHasItems.QuoteId IS NOT NULL
        GROUP BY e.ID
    )
    SELECT
        QuotingStatus =
            CASE
                ----------------------------------------------------------------
                -- Custom/unknown workflow names (kept), excluding operational list
                ----------------------------------------------------------------
                WHEN les.LatestWorkflowStatusName IS NOT NULL
                     AND les.LatestWorkflowStatusName NOT IN
                     (
                        N'N/A', N'Ready for Quote', N'Declined', N'1st Chase', N'2nd Chase', N'Dead',
                        N'Deadline Approaching', N'Deadline Missed'
                     )
                THEN les.LatestWorkflowStatusName

                ----------------------------------------------------------------
                -- Enquiry terminal flags (unchanged)
                ----------------------------------------------------------------
                WHEN e.DeadDate IS NOT NULL THEN N'Dead'
                WHEN e.DeclinedToQuoteDate IS NOT NULL THEN N'Declined'

                ----------------------------------------------------------------
                -- Deadline logic (UPDATED to align with QA expectation)
                --
                -- QA: “Expired not auto changed when Quoting Deadline Date = past date.”
                -- Therefore: past deadline => Expired.
                ----------------------------------------------------------------
                WHEN e.QuotingDeadlineDate IS NOT NULL
                     AND e.QuotingDeadlineDate < n.NowUtc
                THEN N'Expired'

                WHEN e.QuotingDeadlineDate IS NOT NULL
                     AND e.QuotingDeadlineDate < DATEADD(DAY, 2, n.NowUtc)
                THEN N'Deadline Approaching'

                WHEN e.ChaseDate2 IS NOT NULL THEN N'2nd Chase'
                WHEN e.ChaseDate1 IS NOT NULL THEN N'1st Chase'

                ----------------------------------------------------------------
                -- No services => New (unchanged)
                ----------------------------------------------------------------
                WHEN ISNULL(sa.ActiveServices, 0) = 0 THEN N'New'

                ----------------------------------------------------------------
                -- No valid quotes (or only empty quotes with 0 items) => do not
                -- force quoting indicators; fall back to workflow status (if any)
                ----------------------------------------------------------------
                WHEN ISNULL(qa.TotalQuotes, 0) = 0
                THEN NULLIF(les.LatestWorkflowStatusName, N'N/A')

                WHEN ISNULL(qa.AllExpiredNoPositive, 0) = 1 THEN N'Expired'
                WHEN ISNULL(qa.AllComplete, 0) = 1 THEN N'Complete'

                WHEN ISNULL(qa.AnyComplete, 0) > 0 OR ISNULL(qa.AnyPartComplete, 0) > 0
                THEN N'Part Complete'

                WHEN ISNULL(qa.AnyAccepted, 0) > 0 THEN N'Accepted'

                WHEN ISNULL(psf.ServicesWithSent, 0) > 0
                     AND ISNULL(sa.ActiveServices, 0) > 0
                     AND psf.ServicesWithSent < sa.ActiveServices
                THEN N'Part Sent'

                WHEN ISNULL(qa.AnySent, 0) > 0 THEN N'Sent'

                WHEN ISNULL(sa.ActiveServices, 0) > 0
                     AND ISNULL(psf.ServicesWithReadyToSend, 0) = sa.ActiveServices
                     AND ISNULL(psf.ServicesWithBeyondReady, 0) = 0
                THEN N'Ready to Send'

                WHEN ISNULL(qa.AnyReadyToSend, 0) > 0 THEN N'Ready to Send'

                WHEN ISNULL(qa.AnyQuoting, 0) > 0 THEN N'Quoting'

                ELSE N'Quoting'
            END
    FROM Enq e
    CROSS JOIN NowUtc n
    LEFT JOIN LatestEnqStatus les ON les.ID = e.ID
    LEFT JOIN ServiceAgg sa       ON sa.ID  = e.ID
    LEFT JOIN QuoteAgg qa         ON qa.ID  = e.ID
    LEFT JOIN PerServiceFlags psf ON psf.ID = e.ID
);
GO