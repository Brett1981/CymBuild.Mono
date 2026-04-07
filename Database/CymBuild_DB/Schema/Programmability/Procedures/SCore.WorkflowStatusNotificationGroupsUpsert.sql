SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[WorkflowStatusNotificationGroupsUpsert]
  @WorkflowGuid UNIQUEIDENTIFIER,
  @UserGroupGuid UNIQUEIDENTIFIER,
  @CanAction BIT,
  @WorkflowStatusGuid UNIQUEIDENTIFIER,
  @Guid     UNIQUEIDENTIFIER OUT
AS
  BEGIN

	
	DECLARE 
			@WorkflowID		INT,
			@UserGroupID	INT;


	SELECT @UserGroupID = ID
	FROM SCore.Groups
	WHERE ([Guid] = @UserGroupGuid);

	SELECT @WorkflowID = ID
	FROM SCore.Workflow
	WHERE ([Guid] = @WorkflowGuid);




    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SCore',				-- nvarchar(255)
      @ObjectName = N'WorkflowStatusNotificationGroups',-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SCore.WorkflowStatusNotificationGroups
              (
                RowStatus,
                Guid,
				GroupID,
                WorkflowID,
				CanAction,
				WorkflowStatusGuid
              )
        VALUES
                (
                  1,						-- RowStatus - tinyint
                  @Guid,				-- Guid - uniqueidentifier
                  @UserGroupID,
				  @WorkflowID,
				  @CanAction,
				  @WorkflowStatusGuid
                );
      END;
    ELSE
      BEGIN
        UPDATE  SCore.WorkflowStatusNotificationGroups
        SET     GroupID		= @UserGroupID,
				WorkflowID	= @WorkflowID,
				CanAction	= @CanAction,
				WorkflowStatusGuid = @WorkflowStatusGuid
        WHERE
          (Guid = @Guid);
      END;
  END;

GO