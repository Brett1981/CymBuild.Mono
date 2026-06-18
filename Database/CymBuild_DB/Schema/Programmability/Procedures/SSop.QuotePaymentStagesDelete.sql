SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[QuotePaymentStagesDelete]')
GO







CREATE PROCEDURE [SSop].[QuotePaymentStagesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	UPDATE	qps
	SET		RowStatus = 254
	FROM	SSop.QuotePaymentStages qps
	WHERE	(qps.Guid = @Guid)
		

END;

GO