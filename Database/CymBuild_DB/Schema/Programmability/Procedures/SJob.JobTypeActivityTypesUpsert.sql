SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SJob].[JobTypeActivityTypesUpsert] 
								@JobTypeGuid UNIQUEIDENTIFIER,
								@ActivityTypeGuid UNIQUEIDENTIFIER,
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE	@JobTypeID INT,
			@ActivityTypeID INT

	SELECT	@JobTypeID = ID
	FROM	SJob.JobTypes 
	WHERE	(Guid = @JobTypeGuid)

	SELECT	@ActivityTypeID = ID
	FROM	SJob.ActivityTypes 
	WHERE	(Guid = @ActivityTypeGuid)
	
	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'JobTypeActivityTypes',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.JobTypeActivityTypes
			 (RowStatus, Guid, JobTypeID, ActivityTypeID)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @JobTypeID,	-- JobTypeID - int
				 @ActivityTypeID
			 )
	END;
	ELSE
	BEGIN
		UPDATE	SJob.JobTypeActivityTypes
		SET		JobTypeID = @JobTypeID,
				ActivityTypeID = @ActivityTypeID
		WHERE	(Guid = @Guid);
	END;
END;

GO