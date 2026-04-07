SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO






CREATE PROCEDURE [SCore].[EntityPropertiesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	SET NOCOUNT ON 

	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	
	UPDATE	ep
	SET		RowStatus = 254
	FROM	SCore.EntityProperties ep
	WHERE	(Guid = @Guid)
END
GO