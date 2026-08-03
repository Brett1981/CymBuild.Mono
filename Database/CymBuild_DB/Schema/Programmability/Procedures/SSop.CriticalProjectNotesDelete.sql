SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[CriticalProjectNotesDelete]')
GO

CREATE PROCEDURE [SSop].[CriticalProjectNotesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN

	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier

	UPDATE	a 
	SET		RowStatus = 254
	FROM	SSop.CriticalProjectNotes a
	WHERE	(Guid = @Guid)
END;

GO