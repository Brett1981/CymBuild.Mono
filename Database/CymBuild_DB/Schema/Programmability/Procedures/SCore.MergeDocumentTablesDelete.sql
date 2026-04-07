SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO







CREATE PROCEDURE [SCore].[MergeDocumentTablesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	SET NOCOUNT ON 

	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	
	UPDATE	mdt
	SET		RowStatus = 254
	FROM	SCore.MergeDocumentTables mdt 
	WHERE	(Guid = @Guid)
END
GO