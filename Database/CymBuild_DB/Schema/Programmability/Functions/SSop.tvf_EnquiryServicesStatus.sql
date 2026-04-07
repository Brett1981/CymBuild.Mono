SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* =============================================================================
   CYB-101 – EnquiryServicesStatus grid dataset hardening
   (NO workflow process changes – data-source correctness only)

   Why this TVF is being amended:
   - This is the new “one row per EnquiryService” dataset used by the new grid.
   - QA issues remaining are heavily centred on “Quoting indicators showing when
     they shouldn’t” and mismatches between Enquiry / Quote states.
   - Even when the underlying calculated views are correct, this grid can still
     appear wrong if the service-row “QuoteStatus” is being driven by empty quotes
     (quotes with zero QuoteItems) or by legacy placeholders.

   QA issues this change supports:
   - “Enquiry status still = Quoting without Quote item (no warning message).”
     (We cannot show the warning message here, but we can stop the service-row
      from showing Quoting/Sent/Accepted when the Quote has no QuoteItems.)
   - Improves visibility/sanity for the new grid so it reflects the corrected
     quote status calculation instead of raw/legacy service values.

   Key principle:
   - Keep navigation behaviour unchanged:
       • Row ID stays EnquiryService.ID
       • Guid stays Enquiry.Guid (DetailPageUri=EnquiryDetail)
   - Do NOT change workflow meanings/transitions.
   - Only improve the dataset’s status columns to be consistent and defensible.
============================================================================= */
CREATE FUNCTION [SSop].[tvf_EnquiryServicesStatus]
(
    @UserId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        /* --------------------------------------------------------------------
           Unique row identity (per service row) – unchanged
        --------------------------------------------------------------------- */
        ID          = es.ID,
        RowStatus   = es.RowStatus,
        RowVersion  = es.RowVersion,

        /* --------------------------------------------------------------------
           Navigation Guid MUST be the Enquiry Guid – unchanged
        --------------------------------------------------------------------- */
        Guid        = e.Guid,

        /* --------------------------------------------------------------------
           Keep the service identity available – unchanged
        --------------------------------------------------------------------- */
        EnquiryServiceGuid = es.Guid,

        /* --------------------------------------------------------------------
           Parent enquiry context (for multidiscipline grouping) – unchanged
        --------------------------------------------------------------------- */
        Number              = e.Number,
        ExternalReference   = e.ExternalReference,
        DescriptionOfWorks  = e.DescriptionOfWorks,
        ClientAgentAccount  = e.ClientAgentAccount,
        uprn                = e.uprn,
        EnquiryStatus       = e.EnquiryStatus,
        Disciplines         = e.Disciplines,
        Property            = e.Property,
        OrgUnit             = e.OrgUnit,
        Date                = e.Date,

        /* --------------------------------------------------------------------
           Service-specific columns (from existing service TVF) – unchanged
        --------------------------------------------------------------------- */
        JobType        = es.JobType,
        Quote          = es.Quote,
        QuoteNet       = es.QuoteNet,
        StartRibaStage = es.StartRibaStage,
        EndRibaStage   = es.EndRibaStage,

        /* --------------------------------------------------------------------
           QuoteStatus (GRID HARDENING)

           Previous behaviour:
           - We were passing through es.QuoteStatus directly. That can be stale,
             legacy-driven, and can present “Quoting” even when the quote has no
             QuoteItems, which QA has explicitly flagged.

           New behaviour:
           - Prefer the status from Quote_CalculatedFields for the latest quote
             (per service) where a quote exists.
           - If the latest quote exists but has ZERO QuoteItems, do not surface
             “Sent/Accepted/Ready to Send/Quoting” indicators from that quote.
             We fall back to "Quoting" only if genuinely required, otherwise NULL.

           Notes:
           - This is display/data-source alignment only.
           - We do not enforce transitions here.
        --------------------------------------------------------------------- */
        QuoteStatus =
            CASE
                WHEN qLatest.QuoteId IS NULL
                THEN es.QuoteStatus  -- no quote found; retain legacy service output

                WHEN ISNULL(qLatest.QuoteItemCount, 0) = 0
                     AND qLatest.CalculatedQuoteStatus IN (N'Quoting', N'Sent', N'Accepted', N'Ready to Send')
                THEN N'Quoting'       -- keep safe pre-send display; avoids false downstream status

                ELSE qLatest.CalculatedQuoteStatus
            END

    FROM SSop.tvf_Enquiries(@UserId) e
    CROSS APPLY SSop.tvf_EnquiryServices(@UserId, e.Guid) es

    /* ------------------------------------------------------------------------
       Latest quote per EnquiryService (if any), plus QuoteItem count and the
       calculated status from SSop.Quote_CalculatedFields.

       We take TOP(1) by Quote ID descending as a pragmatic “latest quote” proxy.
       If you have a dedicated DateCreated/DateTimeUTC column on Quotes that is
       the official ordering, we can switch to that later – but for CYB-101 the
       objective is dataset consistency without changing workflow rules.
    ------------------------------------------------------------------------- */
    OUTER APPLY
    (
        SELECT TOP (1)
            QuoteId                = q.ID,
            CalculatedQuoteStatus  = qcf.QuoteStatus,
            QuoteItemCount         = qc.ItemCount
        FROM SSop.Quotes q
        JOIN SSop.Quote_CalculatedFields qcf
            ON qcf.ID = q.ID
        OUTER APPLY
        (
            SELECT ItemCount = COUNT(1)
            FROM SSop.QuoteItems qi
            WHERE qi.QuoteId = q.ID
              AND qi.RowStatus NOT IN (0,254)
        ) qc
        WHERE q.EnquiryServiceID = es.ID
          AND q.RowStatus NOT IN (0,254)
        ORDER BY q.ID DESC
    ) AS qLatest
);
GO