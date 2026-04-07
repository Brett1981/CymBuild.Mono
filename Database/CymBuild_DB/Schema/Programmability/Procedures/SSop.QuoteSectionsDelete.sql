SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO






CREATE PROCEDURE [SSop].[QuoteSectionsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	UPDATE	qs
	SET		RowStatus = 254
	FROM	SSop.QuoteSections qs
	WHERE	(qs.Guid = @Guid)
		AND	(NOT EXISTS 
				(
					SELECT	1
					FROM	SSop.Quotes q
					WHERE	(q.ID = qs.QuoteId)
						AND	(q.DateAccepted IS NOT NULL)
						AND	(q.DateSent IS NOT NULL)
						AND	(q.DateAccepted IS NOT NULL)
				)
			)

END;

GO