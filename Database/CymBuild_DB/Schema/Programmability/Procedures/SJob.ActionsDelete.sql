SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO




CREATE PROCEDURE [SJob].[ActionsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SJob.Actions
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;

GO