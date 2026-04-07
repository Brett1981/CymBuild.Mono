SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[QuoteMemosDelete]
  @Guid      UNIQUEIDENTIFIER
AS
  BEGIN
   EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SSop.QuoteMemos
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)
  END;

GO