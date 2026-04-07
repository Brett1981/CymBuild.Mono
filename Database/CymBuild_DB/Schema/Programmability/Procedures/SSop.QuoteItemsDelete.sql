SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO






CREATE PROCEDURE [SSop].[QuoteItemsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	UPDATE	qi
	SET		RowStatus = 254
	FROM	SSop.QuoteItems qi
	WHERE	(qi.Guid = @Guid)
		AND	(NOT EXISTS 
				(
					SELECT	1
					FROM	SSop.Quotes q
					JOIN	SSop.QuoteSections qs ON (qs.QuoteId = q.ID)
					WHERE	(qs.ID = qi.QuoteSectionId)
						AND	(q.DateAccepted IS NOT NULL)
						AND	(q.DateSent IS NOT NULL)
						AND	(q.DateAccepted IS NOT NULL)
				)
			)

END;

GO