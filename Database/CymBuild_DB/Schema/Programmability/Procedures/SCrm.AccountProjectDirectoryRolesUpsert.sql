SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO





CREATE PROCEDURE [SCrm].[AccountProjectDirectoryRolesUpsert]
(
    @AccountGuid UNIQUEIDENTIFIER,
	@ProjectDirectoryRoleGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @AccountID INT,
			@ProjectDirectoryRoleID INT

    SELECT  @AccountID = ID 
    FROM    SCrm.Accounts
    WHERE   ([Guid] = @AccountGuid)

	SELECT  @ProjectDirectoryRoleID = ID 
    FROM    SJob.ProjectDirectoryRoles
    WHERE   ([Guid] = @ProjectDirectoryRoleGuid)

    IF (NOT EXISTS
        (
            SELECT  1
            FROM    SCrm.AccountProjectDirectoryRoles
            WHERE   ([Guid] = @Guid)
        )
    )
    BEGIN
		INSERT SCrm.AccountProjectDirectoryRoles
			 (RowStatus, Guid, AccountID, ProjectDirectoryRoleID)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @AccountID,	-- AccountID - int
				 @ProjectDirectoryRoleID	-- ProjectDirectoryRoleID - int
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SCrm.AccountProjectDirectoryRoles
        SET     AccountID = @AccountID,
				ProjectDirectoryRoleID = @ProjectDirectoryRoleID
        WHERE   ([Guid] = @Guid)
    END
END
GO