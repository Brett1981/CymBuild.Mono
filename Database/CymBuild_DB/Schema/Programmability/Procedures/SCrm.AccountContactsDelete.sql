SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCrm].[AccountContactsDelete]')
GO





CREATE PROCEDURE [SCrm].[AccountContactsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SCrm.AccountContacts
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;

GO