SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO








CREATE PROCEDURE [SCore].[MergeDocumentsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	SET NOCOUNT ON 

	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	
	UPDATE	md
	SET		RowStatus = 254
	FROM	SCore.MergeDocuments md 
	WHERE	(Guid = @Guid)
END
GO