SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SFin].[InvoiceRequestItemsDelete]
	@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	
	

	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier

	UPDATE	SFin.InvoiceRequestItems
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

		
END;
GO