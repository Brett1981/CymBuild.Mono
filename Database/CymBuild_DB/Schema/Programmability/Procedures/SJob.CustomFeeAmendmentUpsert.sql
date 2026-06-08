SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SJob].[CustomFeeAmendmentUpsert]
	(	
		@Guid UNIQUEIDENTIFIER,
		@StageChange DECIMAL(19,2),
		@StageMeetingChange DECIMAL(19,2),
		@StageVisitChange DECIMAL(19,2),
		@Reason NVARCHAR(MAX),
		@StageGuid UNIQUEIDENTIFIER,
		@FeeAmendmentGuid UNIQUEIDENTIFIER,
		@CreatedByUserGuid UNIQUEIDENTIFIER
	)
AS
BEGIN
	DECLARE @IsInsert BIT,
			@JobId INT,
			@FeeAmendmentId INT,
			@UserId INT,
			@StageId INT;


	SELECT 
		@JobId = JobID,
		@FeeAmendmentId = ID
	FROM SJob.FeeAmendment
	WHERE Guid = @FeeAmendmentGuid;

	SELECT @StageId = ID
	FROM SJob.RibaStages
	WHERE Guid = @StageGuid;

	SELECT @UserId = ID
	FROM SCore.Identities 
	WHERE Guid = @CreatedByUserGuid;


	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'CustomFeeAmendment',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
	BEGIN
		INSERT	SJob.CustomFeeAmendment
			 (
				RowStatus,
				Guid,
				JobID,
				StageChange,
				StageVisitChange,
				StageMeetingChange,
				StageId,
				FeeAmendmentId,
				CreatedByUserID,
				Reason
			  ) 
		VALUES
			 (
				 1,								-- RowStatus - tinyint
				@Guid,							-- Guid - uniqueidentifier
				@JobId,
				@StageChange,
				@StageVisitChange,
				@StageMeetingChange,
				@StageId,
				@FeeAmendmentId,
				@UserId,
				@Reason
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.CustomFeeAmendment
		SET		
			JobId = @JobId,
			StageChange = @StageChange,
			StageVisitChange = @StageVisitChange,
			StageMeetingChange = @StageMeetingChange,
			StageId = @StageId,
			FeeAmendmentId = @FeeAmendmentId,
			CreatedByUserID = @UserId,
			Reason = @Reason
		WHERE	(Guid = @Guid);
	END;


END;
GO