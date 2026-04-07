SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO






CREATE PROCEDURE [SCore].[EntityQueryParametersDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	SET NOCOUNT ON 

	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	
	UPDATE	ep
	SET		RowStatus = 254
	FROM	SCore.EntityQueryParameters ep
	WHERE	(Guid = @Guid)
END
GO