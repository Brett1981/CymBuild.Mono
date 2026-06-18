SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[JobPurposeGroupsDelete]')
GO



CREATE PROCEDURE [SJob].[JobPurposeGroupsDelete]
(
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	
	
    UPDATE	SJob.JobPurposeGroups 
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)
END
GO