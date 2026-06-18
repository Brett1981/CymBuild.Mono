SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[MergeDocumentItemIncludesDelete]')
GO








CREATE PROCEDURE [SCore].[MergeDocumentItemIncludesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	SET NOCOUNT ON 

	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	
	UPDATE	mdi
	SET		RowStatus = 254
	FROM	SCore.MergeDocumentItemIncludes mdi 
	WHERE	(Guid = @Guid)
END
GO