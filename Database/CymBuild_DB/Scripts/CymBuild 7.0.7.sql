

EXEC sys.sp_set_session_context @key = 'S_disable_triggers',
								@value = 1;

UPDATE SSop.Quotes 
SET QuotingConsultantId = QuotingUserId
WHERE	QuotingConsultantId < 0 



UPDATE q
SET		q.DateAccepted = j.JobStarted
FROM	SSop.Quotes q
JOIN	SSop.QuoteSections qs ON (qs.QuoteId = q.ID)
JOIN	SSop.QuoteItems qi ON (qi.QuoteSectionId = qs.ID)
JOIN	SJob.Jobs j ON (j.ID = qi.CreatedJobId)
WHERE	(q.DateAccepted IS NULL)
	AND	(j.Id > 0)
