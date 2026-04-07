SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[WorkflowStatusDelete]
(
	@Guid UNIQUEIDENTIFIER 
)
AS 
BEGIN

		IF(EXISTS
			(
				SELECT 1 FROM
				SCore.WorkflowStatus AS WfS
				WHERE WfS.Guid = @Guid AND WfS.Enabled = 1
			
			))
		BEGIN
			;THROW 60000, N'Cannot delete enabled workflow statuses.', 1
			RETURN
		END;

		EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier

		UPDATE	SCore.WorkflowStatus
		SET		RowStatus = 254
		WHERE	(Guid = @Guid)
END;
GO