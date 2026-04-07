SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[JobTypeActivityTypesDelete]
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SJob.JobTypeActivityTypes
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;
GO