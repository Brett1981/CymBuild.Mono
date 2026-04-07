SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[QuoteKeyDatesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	UPDATE	qkd
	SET		RowStatus = 254
	FROM	SSop.QuoteKeyDates qkd 
	WHERE	(qkd.Guid = @Guid)
	

END;

GO