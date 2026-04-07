SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[WorkflowStatusNotificationGroupsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SCore.WorkflowStatusNotificationGroups
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;

GO