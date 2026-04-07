SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO




CREATE PROCEDURE [SJob].[ActionsUpsert]
	(
		@JobGuid			UNIQUEIDENTIFIER,
		@MilestoneGuid		UNIQUEIDENTIFIER,
		@ActivityGuid		UNIQUEIDENTIFIER,
		@SurveyorGuid		UNIQUEIDENTIFIER,
		@Notes				NVARCHAR(MAX),
		@IsComplete			BIT,
		@CreatedByUserGuid  UNIQUEIDENTIFIER,
		@ActionStatusGuid   UNIQUEIDENTIFIER,
		@ActionTypeGuid		UNIQUEIDENTIFIER,
		@ActionPriorityGuid UNIQUEIDENTIFIER,
		@AssigneeUserGuid   UNIQUEIDENTIFIER,
		@Guid				UNIQUEIDENTIFIER
	)
AS
	BEGIN
		DECLARE @CreatedByUserID  INT,
				@MilestoneID	  INT = (-1),
				@ActivityID		  INT = (-1),
				@SurveyorID		  INT = (-1),
				@ActionStatusId	  INT = (-1),
				@ActionPriorityId INT = (-1),
				@ActionTypeId	  INT = (-1),
				@AssigneeUserId	  INT = (-1),
				@JobID			  INT = (-1)

		SELECT
				@SurveyorID = ID
		FROM
				SCore.Identities
		WHERE
				([Guid] = @SurveyorGuid)

		SELECT
				@AssigneeUserId = ID
		FROM
				SCore.Identities i
		WHERE
				(i.Guid = @AssigneeUserGuid)

		SELECT
				@ActionStatusId = ID
		FROM
				SJob.ActionStatus
		WHERE
				(Guid = @ActionStatusGuid)

		SELECT
				@ActionTypeId = ID
		FROM
				SJob.ActionTypes
		WHERE
				(Guid = @ActionTypeGuid)

		SELECT
				@ActionPriorityId = ID
		FROM
				SJob.ActionPriorities
		WHERE
				(Guid = @ActionPriorityGuid)

		SELECT
				@CreatedByUserID = ID
		FROM
				SCore.Identities
		WHERE
				([Guid] = @CreatedByUserGuid)

		SELECT
				@MilestoneID = ID
		FROM
				SJob.Milestones
		WHERE
				([Guid] = @MilestoneGuid)

		SELECT
				@ActivityID = ID
		FROM
				SJob.Activities
		WHERE
				([Guid] = @ActivityGuid)

		SELECT
				@JobID = ID
		FROM
				SJob.Jobs
		WHERE
				([Guid] = @JobGuid)


		DECLARE @IsInsert BIT
		EXEC SCore.UpsertDataObject
			@Guid		= @Guid,					-- uniqueidentifier
			@SchemeName = N'SJob',				-- nvarchar(255)
			@ObjectName = N'Actions',				-- nvarchar(255)
			@IsInsert   = @IsInsert OUTPUT	-- bit

		IF (@IsInsert = 1)
			BEGIN
				INSERT SJob.Actions
						(
							RowStatus,
							Guid,
							JobID,
							MilestoneID,
							ActivityID,
							SurveyorID,
							Notes,
							CreatedByUserID,
							LegacyID,
							ActionPriorityId,
							ActionTypeId,
							ActionStatusId,
							AssigneeUserId,
							IsComplete
						)
				VALUES
						(
							1,	-- RowStatus - tinyint
							@Guid,	-- Guid - uniqueidentifier
							@JobID,	-- JobID - int
							@MilestoneID,	-- MilestoneID - bigint
							@ActivityID,	-- ActivityID - bigint
							@SurveyorID,	-- SurveyorID - int
							@Notes,	-- Notes - nvarchar(max)
							@CreatedByUserID,	-- CreatedByUserID - int
							NULL,		-- LegacyID - bigint
							@ActionPriorityId,
							@ActionTypeId,
							@ActionStatusId,
							@AssigneeUserId,
							@IsComplete	-- IsComplete - bit
						)
			END
		ELSE
			BEGIN
				UPDATE  SJob.Actions
				SET		JobID = @JobID,
						MilestoneID = @MilestoneID,
						ActivityID = @ActivityID,
						SurveyorID = @SurveyorID,
						Notes = @Notes,
						CreatedByUserID = @CreatedByUserID,
						ActionPriorityId = @ActionPriorityId,
						ActionStatusId = @ActionStatusId,
						ActionTypeId = @ActionTypeId,
						AssigneeUserId = @AssigneeUserId,
						IsComplete = @IsComplete
				WHERE
					([Guid] = @Guid)
			END
	END
GO