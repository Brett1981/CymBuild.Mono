SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SCore].[NonActivityTypesDelete]
  @Guid      UNIQUEIDENTIFIER
AS
  BEGIN
   EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SCore.NonActivityTypes
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)
  END;

GO