SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[WorkflowDelete]
(
	@Guid UNIQUEIDENTIFIER 
)
AS 
BEGIN

	 DECLARE @UserID             INT = -1;
	 DECLARE @IsUserSysAdmin     BIT = 0;
	 DECLARE @WorkflowName NVARCHAR(100);


	 --Get the name of the workflow
	SELECT @WorkflowName = Name
	FROM SCore.Workflow 
	WHERE Guid = @Guid



    SELECT
            @UserID = ISNULL(CONVERT(INT,
            SESSION_CONTEXT(N'user_id')
            ),
            -1
            );

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

    IF (NOT EXISTS
			(
				SELECT	1
				FROM	SCore.UserGroups AS ug
				JOIN	SCore.Groups AS g ON (g.ID = ug.GroupID)
				WHERE	(ug.IdentityID = @UserID)
					AND	(g.Code = N'SU')
			)
		)
	BEGIN 
		;THROW 60000, N'Only members of the Superusers group can run this action.', 1
	END

		
		IF(EXISTS
			(
				SELECT 1 FROM
				SCore.Workflow AS Wf
				WHERE Wf.Guid = @Guid AND Wf.Enabled = 1
			
			)
		)
		BEGIN
			;THROW 60000, N'Cannot delete enabled workflows', 1
			RETURN
		END;
		--Do not delete default workflows - except if the user has System Admin priviliges.
		ELSE IF(EXISTS
				(
					SELECT 1 FROM
					SCore.Workflow AS Wf
					WHERE 
						(Wf.Guid = @Guid) 
						AND (Wf.OrganisationalUnitId = -1)
					
				)
				AND @IsUserSysAdmin = 0
				OR @WorkflowName IN (N'Enquiries (System Default)', N'Quotes (System Default)', N'Jobs (System Default)') --Extra protection against deleting original workflows
				
		)
		BEGIN
			;THROW 60000, N'Cannot delete a default workflow!', 1
			RETURN
		END;

		DECLARE @WorkflowID INT;
		DECLARE @WorkflowTransitionGuid UNIQUEIDENTIFIER;


		--Get the workflow ID - we will use this to "delete" all associated transitions.
		SELECT @WorkflowID = ID 
		FROM SCore.Workflow
		WHERE Guid = @Guid;

		EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier

		UPDATE	SCore.Workflow
		SET		RowStatus = 254
		WHERE	(Guid = @Guid)


		--Now, delete all associated workflow transitions
		WHILE EXISTS(SELECT 1 FROM SCore.WorkflowTransition WHERE WorkflowID = @WorkflowID AND RowStatus <> 254)
		BEGIN

			SELECT TOP 1 @WorkflowTransitionGuid = Guid
			FROM SCore.WorkflowTransition
			WHERE 
				(WorkflowID = @WorkflowID)
				AND (RowStatus NOT IN (0,254))

			EXEC SCore.DeleteDataObject @Guid = @WorkflowTransitionGuid	-- uniqueidentifier

			UPDATE	SCore.WorkflowTransition
			SET		RowStatus = 254
			WHERE	(Guid = @WorkflowTransitionGuid)

		END


		
END;
GO