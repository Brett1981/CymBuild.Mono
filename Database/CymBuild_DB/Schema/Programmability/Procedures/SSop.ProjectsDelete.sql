SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[ProjectsDelete]')
GO





CREATE PROCEDURE [SSop].[ProjectsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SSop.Projects
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;

GO