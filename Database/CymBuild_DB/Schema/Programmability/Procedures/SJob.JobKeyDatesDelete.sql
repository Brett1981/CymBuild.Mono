SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE PROCEDURE [SJob].[JobKeyDatesDelete]
(
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	
	
    UPDATE	SJob.JobKeyDates
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)
END
GO