SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[QuoteKeyDatesDelete]')
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