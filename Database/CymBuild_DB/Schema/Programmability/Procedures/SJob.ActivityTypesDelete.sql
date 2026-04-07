SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO




CREATE PROCEDURE [SJob].[ActivityTypesDelete]
  @Guid      UNIQUEIDENTIFIER
AS
  BEGIN
   EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SJob.ActivityTypes
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)
  END;

GO