SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SJob].[JobTypesDuplicate] 
								@SourceGuid UNIQUEIDENTIFIER,
								@TargetGuid UNIQUEIDENTIFIER
AS
BEGIN

	DECLARE @Name NVARCHAR(100),
			@SourceID INT,
			@ID INT


	SELECT	@Name = Name + N' - Copy',
			@SourceID = ID
	FROM	SJob.JobTypes 
	WHERE	(Guid = @SourceGuid)

	EXEC SJob.JobTypesUpsert @Name = @Name,			-- nvarchar(100)
							 @IsActive = 0,		-- bit
							 @Guid = @TargetGuid OUTPUT	-- uniqueidentifier
	
	SELECT	@ID = id 
	FROM	SJob.JobTypes
	WHERE	(Guid = @TargetGuid)

	INSERT	SJob.JobTypeMilestoneTemplates
		 (RowStatus, Guid, JobTypeID, MilestoneTypeID, Description, SortOrder)
	SELECT	1, NEWID(), @ID, MilestoneTypeID, Description, SortOrder 
	FROM	SJob.JobTypeMilestoneTemplates 
	WHERE	(JobTypeID = @SourceID)
		AND	(RowStatus NOT IN (0, 254))

	INSERT	SJob.JobTypeProjectDirectoryRoles
		 (RowStatus, Guid, JobTypeID, ProjectDirectoryRoleID, SortOrder)
	SELECT	1, NEWID(), @ID, ProjectDirectoryRoleID, SortOrder
	FROM	SJob.JobTypeProjectDirectoryRoles
	WHERE	(JobTypeID = @SourceID)
		AND	(RowStatus NOT IN (0, 254))

	INSERT	SJob.JobTypeActivityTypes
		 (RowStatus, Guid, JobTypeID, ActivityTypeID)
	SELECT	1, NEWID(), @ID, ActivityTypeID
	FROM	SJob.JobTypeActivityTypes 
	WHERE	(JobTypeID = @SourceID)
		AND	(RowStatus NOT IN (0, 254))
END;

GO