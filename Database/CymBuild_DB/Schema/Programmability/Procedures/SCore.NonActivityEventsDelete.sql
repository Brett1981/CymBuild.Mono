SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE PROCEDURE [SCore].[NonActivityEventsDelete]
  @Guid      UNIQUEIDENTIFIER
AS
  BEGIN
   EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SCore.NonActivityEvents
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)
  END;

GO