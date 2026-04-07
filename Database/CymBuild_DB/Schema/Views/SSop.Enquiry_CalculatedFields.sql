SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* =============================================================================
   CYB-119 / CYB-101 Follow-up – Enquiry status (ALLENQUIRIES)

   FIXES:
   - Deadline/Chase/Expired derived from Enquiry ONLY when NO Quotes exist.
   - Prevent "Deadline Approaching/Missed/Expired" showing once Quote exists.
   - Keep Quote Expired (Enquiry-level) rule.
   - Preserve: terminal enquiry statuses + explicit enquiry record-status override.

   NOTE:
   - No workflow meaning changes; calculation/enforcement only.
============================================================================= */
CREATE VIEW [SSop].[Enquiry_CalculatedFields]
      --WITH SCHEMABINDING
AS
SELECT
    e.ID,

    EnquiryStatus =
    CASE
        ------------------------------------------------------------------
        -- 1) Enquiry WORKFLOW terminal statuses must always win (latest-only)
        ------------------------------------------------------------------
        WHEN LastEnqStatus.Name IN (N'Declined', N'Dead', N'1st Chase', N'2nd Chase', N'Reopened')
        THEN LastEnqStatus.Name

        ------------------------------------------------------------------
        -- 2) Legacy terminal flags (existing operational flags)
        ------------------------------------------------------------------
        WHEN e.DeadDate IS NOT NULL
        THEN N'Dead'

        WHEN e.DeclinedToQuoteDate IS NOT NULL
        THEN N'Declined'

        ------------------------------------------------------------------
        -- 3) Explicit Enquiry operational record-status (if set)
        --    IMPORTANT: Deadline/Expired/Chase only valid when NO quotes exist.
        ------------------------------------------------------------------
        WHEN LastEnqStatus.Name = N'Ready to Send'
        THEN N'Ready to Send'

        WHEN LastEnqStatus.Name IN
             (
                N'1st Chase',
                N'2nd Chase',
                N'Deadline Approaching',
                N'Deadline Missed',
                N'Expired',
                N'Ready for Quote'
             )
             AND ISNULL(QuoteAgg.TotalQuotesAll, 0) = 0
        THEN LastEnqStatus.Name

        ------------------------------------------------------------------
        -- 4) Quote rollup FIRST (so Expired never overwrites progress)
        --    Rollup is driven by quotes WITH items (real quote content).
        ------------------------------------------------------------------
        WHEN ISNULL(QuoteAgg.TotalQuotesWithItems, 0) > 0
             AND QuoteAgg.CompleteQuotes = QuoteAgg.TotalQuotesWithItems
        THEN N'Complete'

       WHEN 
			(
				(ISNULL(QuoteAgg.TotalQuotesWithItems, 0) > 0
				 AND (QuoteAgg.CompleteQuotes > 0 OR QuoteAgg.PartCompleteQuotes > 0))
			)
			THEN N'Part Complete'

        WHEN ISNULL(QuoteAgg.TotalQuotesWithItems, 0) > 0
             AND QuoteAgg.AcceptedQuotes = QuoteAgg.TotalQuotesWithItems
        THEN N'Accepted'

        WHEN ISNULL(QuoteAgg.TotalQuotesWithItems, 0) > 0
             AND QuoteAgg.AcceptedQuotes > 0
        THEN N'Part Accepted'

        WHEN ISNULL(QuoteAgg.TotalQuotesWithItems, 0) > 0
             AND QuoteAgg.RejectedQuotes = QuoteAgg.TotalQuotesWithItems
        THEN N'Rejected'

        WHEN ISNULL(QuoteAgg.TotalQuotesWithItems, 0) > 0
             AND QuoteAgg.SentQuotes = QuoteAgg.TotalQuotesWithItems
        THEN N'Sent'

        WHEN ISNULL(QuoteAgg.TotalQuotesWithItems, 0) > 0
             AND QuoteAgg.SentQuotes > 0
        THEN N'Part Sent'

		WHEN 
				(EnquiryServiceItems.NumberOfItems > QuoteAgg.TotalQuotesWithItems
				 AND QuoteAgg.TotalQuotesWithItems > 0)
		THEN N'Part Ready to Send'

        WHEN ISNULL(QuoteAgg.TotalQuotesWithItems, 0) > 0
             AND QuoteAgg.ReadyToSendQuotes = QuoteAgg.TotalQuotesWithItems
        THEN N'Ready to Send'

        WHEN ISNULL(QuoteAgg.TotalQuotesWithItems, 0) > 0
             AND QuoteAgg.ReadyToSendQuotes > 0
        THEN N'Ready to Send'





        ------------------------------------------------------------------
        -- 4B) Quote Expired (Enquiry level):
        --     Quotes exist, quotes are expired, and NO jobs exist anywhere.
        ------------------------------------------------------------------
        WHEN ISNULL(QuoteAgg.TotalQuotesAll, 0) > 0
             AND ISNULL(QuoteAgg.TotalJobsCreated, 0) = 0
             AND ISNULL(QuoteAgg.TotalQuotesWithItems, 0) > 0
             AND QuoteAgg.ExpiredQuotes = QuoteAgg.TotalQuotesWithItems
             AND (
                    QuoteAgg.AcceptedQuotes = 0
                AND QuoteAgg.SentQuotes = 0
                AND QuoteAgg.ReadyToSendQuotes = 0
                AND QuoteAgg.CompleteQuotes = 0
                AND QuoteAgg.PartCompleteQuotes = 0
                 )
        THEN N'Quote Expired'

         ------------------------------------------------------------------
        -- 5) Enquiry deadline/chase derived from Enquiry
        --    IMPORTANT: ONLY when NO quotes exist at all
        ------------------------------------------------------------------

        -- Deadline Missed = deadline passed, but within last 2 days
        WHEN ISNULL(QuoteAgg.TotalQuotesAll, 0) = 0
             AND e.QuotingDeadlineDate IS NOT NULL
             AND e.QuotingDeadlineDate < NowUtc.NowUtc
             AND e.QuotingDeadlineDate >= DATEADD(DAY, -2, NowUtc.NowUtc)
        THEN N'Deadline Missed'

        -- Expired = deadline passed more than 2 days ago
        WHEN ISNULL(QuoteAgg.TotalQuotesAll, 0) = 0
             AND e.QuotingDeadlineDate IS NOT NULL
             AND e.QuotingDeadlineDate < DATEADD(DAY, -2, NowUtc.NowUtc)
        THEN N'Expired'

        -- Deadline Approaching = deadline is within next 2 days (and not already missed/expired)
        WHEN ISNULL(QuoteAgg.TotalQuotesAll, 0) = 0
             AND e.QuotingDeadlineDate IS NOT NULL
             AND e.QuotingDeadlineDate >= NowUtc.NowUtc
             AND e.QuotingDeadlineDate < DATEADD(DAY, 2, NowUtc.NowUtc)
        THEN N'Deadline Approaching'

        WHEN ISNULL(QuoteAgg.TotalQuotesAll, 0) = 0
             AND e.ChaseDate2 IS NOT NULL
        THEN N'2nd Chase'

        WHEN ISNULL(QuoteAgg.TotalQuotesAll, 0) = 0
             AND e.ChaseDate1 IS NOT NULL
        THEN N'1st Chase'

        ------------------------------------------------------------------
        -- 6) Quote exists but no higher rollup matched => Quoting
        ------------------------------------------------------------------
        WHEN ISNULL(QuoteAgg.TotalQuotesAll, 0) > 0
        THEN N'Quoting'

        ------------------------------------------------------------------
        -- 7) No quotes yet: show latest enquiry workflow status (if present)
        ------------------------------------------------------------------
        WHEN ISNULL(QuoteAgg.TotalQuotesAll, 0) = 0
             AND LastEnqStatus.Name IS NOT NULL
             AND LastEnqStatus.Name <> N'N/A'
        THEN LastEnqStatus.Name

        ------------------------------------------------------------------
        -- 8) Fallback
        ------------------------------------------------------------------
        ELSE N'New'
    END
FROM SSop.Enquiries e

OUTER APPLY
(
    SELECT NowUtc = CONVERT(datetime2(7), SYSUTCDATETIME())
) AS NowUtc

OUTER APPLY
(
    SELECT TOP (1)
        Name = wfs.Name
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.DataObjectGuid = e.Guid
      AND dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
      AND ISNULL(wfs.ShowInEnquiries, 0) = 1
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
) AS LastEnqStatus

OUTER APPLY 
(
	SELECT COUNT(es.ID) AS NumberOfItems
	FROM SSop.EnquiryServices AS es
	WHERE 
			(es.EnquiryId = e.ID)
		AND (es.RowStatus NOT IN (0,254))
) AS EnquiryServiceItems

OUTER APPLY
(
    SELECT
        TotalQuotesAll = qa.TotalQuotesAll,
        TotalQuotesWithItems = ISNULL(qwi.TotalQuotesWithItems, 0),
        TotalJobsCreated = ISNULL(jc.TotalJobsCreated, 0),

        CompleteQuotes     = ISNULL(qwi.CompleteQuotes, 0),
        PartCompleteQuotes = ISNULL(qwi.PartCompleteQuotes, 0),
        AcceptedQuotes     = ISNULL(qwi.AcceptedQuotes, 0),
        RejectedQuotes     = ISNULL(qwi.RejectedQuotes, 0),
        ExpiredQuotes      = ISNULL(qwi.ExpiredQuotes, 0),
        SentQuotes         = ISNULL(qwi.SentQuotes, 0),
        ReadyToSendQuotes  = ISNULL(qwi.ReadyToSendQuotes, 0)
    FROM
    (
        -- TotalQuotesAll (counts any quote linked via enquiry services)
        SELECT TotalQuotesAll = COUNT(1)
        FROM SSop.EnquiryServices es0
        JOIN SSop.Quotes q0
            ON q0.EnquiryServiceID = es0.ID
           AND q0.RowStatus NOT IN (0,254)
        WHERE es0.EnquiryId = e.ID
          AND es0.RowStatus NOT IN (0,254)
    ) qa
    OUTER APPLY
    (
        -- QuoteWithItems aggregated per QUOTE (not per QuoteItem row)
        SELECT
            TotalQuotesWithItems = COUNT(1),

            CompleteQuotes     = SUM(CASE WHEN x.QuoteStatus = N'Complete'      THEN 1 ELSE 0 END),
            PartCompleteQuotes = SUM(CASE WHEN x.QuoteStatus = N'Part Complete' THEN 1 ELSE 0 END),
            AcceptedQuotes     = SUM(CASE WHEN x.QuoteStatus = N'Accepted'      THEN 1 ELSE 0 END),
            RejectedQuotes     = SUM(CASE WHEN x.QuoteStatus = N'Rejected'      THEN 1 ELSE 0 END),
            ExpiredQuotes      = SUM(CASE WHEN x.QuoteStatus = N'Expired'       THEN 1 ELSE 0 END),
            SentQuotes         = SUM(CASE WHEN x.QuoteStatus = N'Sent'          THEN 1 ELSE 0 END),
            ReadyToSendQuotes  = SUM(CASE WHEN x.QuoteStatus = N'Ready to Send' THEN 1 ELSE 0 END)
        FROM
        (
            SELECT
                q.ID,
                QuoteStatus = qcf.QuoteStatus
            FROM SSop.EnquiryServices es
            JOIN SSop.Quotes q
                ON q.EnquiryServiceID = es.ID
               AND q.RowStatus NOT IN (0,254)
            JOIN SSop.QuoteItems qi
                ON qi.QuoteId = q.ID
               AND qi.RowStatus NOT IN (0,254)
            JOIN SSop.Quote_CalculatedFields qcf
                ON qcf.ID = q.ID
            WHERE es.EnquiryId = e.ID
              AND es.RowStatus NOT IN (0,254)
            GROUP BY
                q.ID,
                qcf.QuoteStatus
        ) x
    ) qwi
    OUTER APPLY
    (
        -- TotalJobsCreated across all quoteitems (distinct job ids)
        SELECT TotalJobsCreated = COUNT(DISTINCT qi.CreatedJobId)
        FROM SSop.EnquiryServices es
        JOIN SSop.Quotes q
            ON q.EnquiryServiceID = es.ID
           AND q.RowStatus NOT IN (0,254)
        JOIN SSop.QuoteItems qi
            ON qi.QuoteId = q.ID
           AND qi.RowStatus NOT IN (0,254)
        WHERE es.EnquiryId = e.ID
          AND es.RowStatus NOT IN (0,254)
          AND qi.CreatedJobId IS NOT NULL
          AND qi.CreatedJobId > 0
    ) jc
) AS QuoteAgg;

GO