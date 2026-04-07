SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[JobTypeProjectDirectoryRolesUpsert] 
								@JobTypeGuid UNIQUEIDENTIFIER,
								@ProjectDirectoryRoleGuid UNIQUEIDENTIFIER,
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE	@JobTypeID INT,
			@ProjectDirectoryRoleID INT

	SELECT	@JobTypeID = ID
	FROM	SJob.JobTypes 
	WHERE	(Guid = @JobTypeGuid)

	SELECT	@ProjectDirectoryRoleID = ID
	FROM	SJob.ProjectDirectoryRoles 
	WHERE	(Guid = @ProjectDirectoryRoleGuid)
	
	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'JobTypeProjectDirectoryRoles',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.JobTypeProjectDirectoryRoles
			 (RowStatus, Guid, JobTypeID, ProjectDirectoryRoleID)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @JobTypeID,	-- JobTypeID - int
				 @ProjectDirectoryRoleID
			 )
	END;
	ELSE
	BEGIN
		UPDATE	SJob.JobTypeProjectDirectoryRoles
		SET		JobTypeID = @JobTypeID,
				ProjectDirectoryRoleID = @ProjectDirectoryRoleID
		WHERE	(Guid = @Guid);
	END;
END;

GO