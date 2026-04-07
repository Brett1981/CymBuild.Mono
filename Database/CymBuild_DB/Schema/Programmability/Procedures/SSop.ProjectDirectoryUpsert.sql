SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SSop].[ProjectDirectoryUpsert]
(
    @JobGuid UNIQUEIDENTIFIER,
	@ProjectDirectoryRoleGuid UNIQUEIDENTIFIER,
	@AccountGuid UNIQUEIDENTIFIER,
	@ContactGuid UNIQUEIDENTIFIER,
	@ProjectGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @ProjectDirectoryRoleId INT,
			@AccountId INT,
			@ContactId INT,
            @JobID INT = -1,
			@ProjectID INT

    SELECT  @ProjectDirectoryRoleId = ID 
    FROM    SJob.ProjectDirectoryRoles 
    WHERE   ([Guid] = @ProjectDirectoryRoleGuid)

    SELECT  @JobID = ID 
    FROM    SJob.Jobs 
    WHERE   ([Guid] = @JobGuid)

	SELECT  @ProjectID = ID 
    FROM    SSop.Projects AS p 
    WHERE   ([Guid] = @ProjectGuid)

	SELECT	@AccountId = ID
	FROM	SCrm.Accounts
	WHERE	([Guid] = @AccountGuid)

	SELECT	@ContactId = ID 
	FROM	SCrm.Contacts 
	WHERE	([Guid] = @ContactGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'ProjectDirectory',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.ProjectDirectory
			 (RowStatus, Guid, JobID, ProjectID, ProjectDirectoryRoleID, AccountID, ContactID)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @JobID,	-- JobID - int
				 @ProjectID,
				 @ProjectDirectoryRoleId,	-- ProjectDirectoryRoleID - int
				 @AccountId,	-- AccountID - int
				 @ContactId	-- ContactID - int
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SJob.ProjectDirectory
        SET     JobID = @JobID,
				ProjectID = @ProjectID,
				ProjectDirectoryRoleID = @ProjectDirectoryRoleId,
				AccountID = @AccountId,
				ContactID = @ContactId
        WHERE   ([Guid] = @Guid)
    END
END
GO