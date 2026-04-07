SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SSop].[EnquiryService_ExtendedInfo]
    --WITH SCHEMABINDING
AS
SELECT	es.Id,
		es.RowStatus,
		es.RowVersion,
		es.Guid,
		ISNULL(quote.QuoteID, -1) AS QuoteID,
		quote.DateAccepted,
		quote.DateSent,
		quote.DateRejected,
		quote.QuoteNet,
		ISNULL(quote.Number, 0) AS Number,
		ISNULL(Quote.RevisionNumber, 0) AS RevisionNumber,
		quote.DateDeclinedToQuote AS DeclinedToQuoteDate, --[CBLD-592]
		quote.DeclinedToQuoteReason AS DeclinedToQuoteReason
FROM	SSop.EnquiryServices es
OUTER APPLY 
	(
		SELECT	q.ID AS QuoteID,
				q.DateAccepted,
				q.DateSent, 
				q.DateRejected,
				q.DateDeclinedToQuote, -- [CBLD-592]
				q.DeclinedToQuoteReason,
				q.Number,
				q.RevisionNumber,
				QuoteLines.Net QuoteNet
		FROM	SSop.Quotes AS q
		OUTER APPLY (
			SELECT	SUM(qit.LineNet) AS Net
			FROM	SSop.QuoteItems AS qi 
			JOIN	SSop.QuoteItemTotals AS qit ON (qit.ID = qi.ID)
			WHERE	(qi.QuoteId = q.ID)
				AND	(qi.RowStatus NOT IN (0, 254))
		) QuoteLines
		WHERE	(q.EnquiryServiceID = es.ID)
			AND	(q.EnquiryServiceID > -1)
			AND	(NOT EXISTS
					(
						SELECT	1
						FROM	SSop.Quotes AS q2
						WHERE	(q2.EnquiryServiceID = q.EnquiryServiceID)
							AND	(q2.RevisionNumber > q.RevisionNumber)
							AND	(q2.ID <> q.ID)
							AND	(q2.RowStatus NOT IN (0, 254))
							AND	(q2.DeadDate IS NULL)
					)
				)
	) AS Quote
----[CBLD-592: Getting the declined to quote date]
--OUTER APPLY
--	(
--		SELECT en.DateDeclinedToQuote 
--		FROM SSop.Quotes AS en
--		WHERE es.EnquiryId = en.ID
--	) AS Enquiry

GO