SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[SubContractorInvoicesDelete]')
GO

CREATE PROCEDURE [SJob].[SubContractorInvoicesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SJob.SubContractorInvoices
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;

GO