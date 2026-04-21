SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SUserInterface].[ActionMenuItemsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SUserInterface.ActionMenuItems
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;

GO