SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SSop].[Project_ExtendedInfo]
    --WITH SCHEMABINDING
AS
SELECT	proj.Id,
		proj.RowStatus,
		proj.RowVersion,
		proj.Guid,
		ISNULL(enq.Count, 0) AS EnquiriesCount,
		ISNULL(quote.Count, 0) AS QuotesCount,
		ISNULL(quote.Total, 0) AS QuotesTotalValue,
		ISNULL(quote.AcceptedTotal, 0) AS AcceptedQuotesTotalValue,
		ISNULL(quote.AcceptedCount, 0) AS AcceptedQuotesCount,
		ISNULL(quote.RejectedTotal, 0) AS RejectedQuotesTotalValue,
		ISNULL(quote.RejectedCount, 0) AS RejectedQuotesCount,
		ISNULL(quote.PendingTotal, 0) AS PendingQuotesTotelValue,
		ISNULL(quote.PendingCount, 0) AS PendingQuotesCount,
		ISNULL(job.Count, 0) AS JobsCount,
		ISNULL(job.AgreedFeesTotal, 0) AS JobsTotalAgreedFeesTotal,
		ISNULL(job.InvoicedFeesTotal, 0) AS JobsTotalInvoicedFeesTotal,
		ISNULL(job.RemainingFeesTotal, 0) AS JobsTotalRemainingFeesTotal,
		ISNULL(job.CompletedCount, 0) AS JobsCompletedCount,
		ISNULL(job.CompletedAgreedFeesTotal, 0) AS JobsCompletedAgreedFeesTotal, 
		ISNULL(job.CompletedInvoicedFeesTotal, 0) AS JobsCompletedInvoicedFeesTotal,
		ISNULL(job.CompletedUnInvoicedFeesTotal, 0) AS JobsCompletedUninvoicesFeesTotal,
		ISNULL(job.ActiveCount, 0) AS JobsActiveCount,
		ISNULL(job.ActiveAgreedFeesTotal, 0) AS JobsActiveAgreedFeesTotal,
		ISNULL(job.ActiveInvoicedFeesTotal, 0) AS JobsActiveInvoicedFeesTotal,
		ISNULL(job.ActiveRemainingFeesTotal, 0) AS JobsActiveRemainingFeesTotal,
		ISNULL(job.CancelledCount, 0) AS JobsCancelledCount,
		ISNULL(job.CancelledAgreedFeesTotal, 0) AS JobsCancelledAgreedFeesTotal,
		ISNULL(job.CancelledInvoicedFeesTotal, 0) AS JobsCancelledInvoicedFeesTotal,
		ISNULL(job.CancelledUnInvoicedFeesTotal, 0) AS JobsCancelledUninvoicedFeesTotal,
		ISNULL(job.PercentageCompleted, 0) AS PercentageCompleted,
		ISNULL(job.PercentageAchievableRevenueAchieved, 0) AS PercentageAchievableRevenueAchieved,
		pl.ListLabel
FROM	SSop.Projects proj
JOIN	SSop.ProjectsList AS pl ON (pl.ID = proj.ID)
OUTER APPLY 
(
	SELECT	COUNT(1) AS [Count]
	FROM	SSop.Enquiries e
	WHERE	(e.ProjectId = proj.ID)
		AND	(e.ProjectId > 0)
) AS enq
OUTER APPLY 
(
	SELECT	COUNT(1) AS [Count],
			SUM(qstt.Net) AS Total,
			SUM(CASE WHEN q.DateAccepted IS NOT NULL THEN qstt.Net ELSE 0 END) AS AcceptedTotal,
			SUM(CASE WHEN q.DateAccepted IS NOT NULL THEN 1 ELSE 0 END) AS AcceptedCount,
			SUM(CASE WHEN q.DateRejected IS NOT NULL THEN qstt.Net ELSE 0 END) AS RejectedTotal,
			SUM(CASE WHEN q.DateRejected IS NOT NULL THEN 1 ELSE 0 END) AS RejectedCount,
			SUM(CASE WHEN q.DateSent IS NOT NULL AND q.DateAccepted IS NULL AND q.DateRejected IS NULL THEN qstt.Net ELSE 0 END) AS PendingTotal,
			SUM(CASE WHEN q.DateSent IS NOT NULL AND q.DateAccepted IS NULL AND q.DateRejected IS NULL THEN 1 ELSE 0 END) AS PendingCount
	FROM	SSop.Quotes q
	OUTER APPLY
	(
		SELECT	SUM(qst.Net) AS Net
		FROM	SSop.QuoteSections qs  
		JOIN	SSop.QuoteSectionTotals qst ON (qst.ID = qs.ID)
		WHERE	(qs.QuoteId = q.ID)
			AND	(qs.RowStatus NOT IN (0, 254))
	) qstt
	WHERE	(q.ProjectId = proj.ID)
		AND	(q.ProjectId > 0)
		AND	(q.RowStatus NOT IN (0, 254))
		
	GROUP BY	q.ProjectId
) AS quote
OUTER APPLY 
(
	SELECT	COUNT(1) AS [Count],
			SUM(fees.Agreed) AS AgreedFeesTotal,
			SUM(fees.Invoiced) AS InvoicedFeesTotal,
			SUM(fees.Remaining) AS RemainingFeesTotal,
			SUM(CASE WHEN j.IsComplete = 1 THEN 1 ELSE 0 END) AS CompletedCount,
			SUM(CASE WHEN j.IsComplete = 1 THEN fees.Agreed ELSE 0 END) AS CompletedAgreedFeesTotal,
			SUM(CASE WHEN j.IsComplete = 1 THEN fees.Invoiced ELSE 0 END) AS CompletedInvoicedFeesTotal,
			SUM(CASE WHEN j.IsComplete = 1 THEN fees.Remaining ELSE 0 END) AS CompletedUnInvoicedFeesTotal,
			SUM(CASE WHEN j.IsActive = 1 THEN 1 ELSE 0 END) AS ActiveCount,
			SUM(CASE WHEN j.IsActive = 1 THEN fees.Agreed ELSE 0 END) AS ActiveAgreedFeesTotal,
			SUM(CASE WHEN j.IsActive = 1 THEN fees.Invoiced ELSE 0 END) AS ActiveInvoicedFeesTotal,
			SUM(CASE WHEN j.IsActive = 1 THEN fees.Remaining ELSE 0 END) AS ActiveRemainingFeesTotal,
			SUM(CASE WHEN j.IsCancelled = 1 THEN 1 ELSE 0 END) AS CancelledCount,
			SUM(CASE WHEN j.IsCancelled = 1 THEN fees.Agreed ELSE 0 END) AS CancelledAgreedFeesTotal,
			SUM(CASE WHEN j.IsCancelled = 1 THEN fees.Invoiced ELSE 0 END) AS CancelledInvoicedFeesTotal,
			SUM(CASE WHEN j.IsCancelled = 1 THEN fees.Remaining ELSE 0 END) AS CancelledUnInvoicedFeesTotal,
			CASE WHEN (SUM(CASE WHEN j.IsCancelled = 0 THEN 1 ELSE 0 END) > 0) THEN   SUM(CASE WHEN j.IsComplete = 1 THEN 1 ELSE 0 END) / SUM(CASE WHEN j.IsCancelled = 0 THEN 1 ELSE 0 END) * 100 ELSE 0 END AS PercentageCompleted,
			CASE WHEN SUM(fees.Agreed) > 0 THEN (SUM(fees.Invoiced) / (SUM(CASE WHEN j.IsCancelled = 0 THEN fees.Agreed ELSE 0 END) + SUM(CASE WHEN j.IsCancelled = 0 THEN fees.Invoiced ELSE 0 END))) * 100 ELSE 0 END AS PercentageAchievableRevenueAchieved
	FROM	SJob.Jobs j
	OUTER APPLY	
	(
		SELECT	jfd.Agreed,
				jfd.Invoiced, 
				jfd.Remaining
		FROM	SJob.Job_FeeDrawdown jfd 
		WHERE	(j.id = jfd.ID)
			AND	(jfd.Stage = N'Total (ex. Fee Cap.)')
	) AS fees
	WHERE	(j.ProjectId = proj.ID)
		AND	(j.ProjectId > 0)
		AND	(j.RowStatus NOT IN (0, 254))
	GROUP BY	j.ProjectId
) AS job

GO