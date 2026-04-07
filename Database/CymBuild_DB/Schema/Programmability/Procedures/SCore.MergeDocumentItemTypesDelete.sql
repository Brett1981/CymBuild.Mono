SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO








CREATE PROCEDURE [SCore].[MergeDocumentItemTypesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	SET NOCOUNT ON 

	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	
	UPDATE	mdit
	SET		RowStatus = 254
	FROM	SCore.MergeDocumentItemTypes mdit 
	WHERE	(Guid = @Guid)
END
GO