SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[WorkflowTransitionDelete]
(
	@Guid UNIQUEIDENTIFIER 
)
AS 
BEGIN

    DECLARE @UserID             INT = -1;

    SELECT
            @UserID = ISNULL(CONVERT(INT,
            SESSION_CONTEXT(N'user_id')
            ),
            -1
            );
DECLARE @IsUserSysAdmin     BIT = 0;

	 --Check if the current user has System Admin priviliges - we will be using this for deleting records.
	 IF(EXISTS
		(
			SELECT	1
				FROM	SCore.UserGroups AS ug
				JOIN	SCore.Groups AS g ON (g.ID = ug.GroupID)
				WHERE	(ug.IdentityID = @UserID)
					AND	(g.Code = N'SYSADM')
		)
		)
		BEGIN 
			SET @IsUserSysAdmin = 1;
		END;

		If (@IsUserSysAdmin = 0)
		BEGIN
			IF(EXISTS
				(
					SELECT 1 FROM
					SCore.WorkflowTransition AS WfT
					WHERE WfT.Guid = @Guid AND WfT.Enabled = 1
			
				))
			BEGIN
				;THROW 60000, N'Cannot delete enabled workflow transitions.', 1
				RETURN
			END;
		END;

		EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier

		UPDATE	SCore.WorkflowTransition
		SET		RowStatus = 254
		WHERE	(Guid = @Guid)
END;
GO