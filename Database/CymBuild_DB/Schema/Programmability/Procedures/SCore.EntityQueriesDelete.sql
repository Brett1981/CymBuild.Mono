SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[EntityQueriesDelete]')
GO







CREATE PROCEDURE [SCore].[EntityQueriesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	SET NOCOUNT ON 

	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	
	UPDATE	eq
	SET		RowStatus = 254
	FROM	SCore.EntityQueries AS eq
	WHERE	(Guid = @Guid)
END
GO