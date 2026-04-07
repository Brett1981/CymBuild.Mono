SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO








CREATE PROCEDURE [SCore].[MergeDocumentItemsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	SET NOCOUNT ON 

	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	
	UPDATE	mdi
	SET		RowStatus = 254
	FROM	SCore.MergeDocumentItems mdi 
	WHERE	(Guid = @Guid)
END
GO