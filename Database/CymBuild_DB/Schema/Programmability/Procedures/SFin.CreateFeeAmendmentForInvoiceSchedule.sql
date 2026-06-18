SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[CreateFeeAmendmentForInvoiceSchedule]')
GO

CREATE PROCEDURE [SFin].[CreateFeeAmendmentForInvoiceSchedule]
	(	
		@RIBAStageId	INT,
		@JobId			INT,
		@Amt			DECIMAL(19,2)
		
	)
AS
BEGIN
	
	/*
		Check the RIBA stage value specified on the job.
		If it is 0.0, we must create a fee amendment.
	**/
	IF(EXISTS
		(
			SELECT 1
			FROM SJob.Job_FeeDrawdown root_hobt
			JOIN SJob.Jobs AS J ON (J.ID = root_hobt.JobId)
			WHERE 
					(root_hobt.ID = @JobId)
				AND (root_hobt.StageId = @RibaStageID)
				AND (root_hobt.Agreed = 0.0)
		) AND @RIBAStageId <> 0
	)
	BEGIN

		/*
			[GENERAL VARIABLES]
		*/
		DECLARE 
			@JobGuid UNIQUEIDENTIFIER,
			@FeeAmendmentGuid UNIQUEIDENTIFIER = NEWID(),
			@SVCUserID INT,
			@SVCUserGuid UNIQUEIDENTIFIER,
			@IsCustomRIBAStage BIT;


		/*
			[STANDARD FEE AMENDMENT VARIABLES]
		*/
		DECLARE 
			@RibaStage0Change DECIMAL(9,2)  = 0.0,
			@RibaStage1Change DECIMAL(9,2)  = 0.0,
			@RibaStage2Change DECIMAL(9,2)  = 0.0,
			@RibaStage3Change DECIMAL (9,2) = 0.0,
			@RibaStage4Change DECIMAL (9,2) = 0.0,
			@RibaStage5Change DECIMAL (9,2) = 0.0,
			@RibaStage6Change DECIMAL (9,2) = 0.0,
			@RibaStage7Change DECIMAL (9,2) = 0.0,
			@PreConstructionStageChange DECIMAL (9,2) = 0.0,
			@ConstructionStageChange DECIMAL (9,2) = 0.0,
			@RibaStage0VisitChange DECIMAL(9,2) = 0.0,
			@RibaStage1VisitChange DECIMAL(9,2) = 0.0,
			@RibaStage2VisitChange DECIMAL(9,2) = 0.0,
			@RibaStage3VisitChange DECIMAL(9,2) = 0.0,
			@RibaStage4VisitChange DECIMAL(9,2) = 0.0,
			@RibaStage5VisitChange DECIMAL(9,2) = 0.0,
			@RibaStage6VisitChange DECIMAL(9,2) = 0.0,
			@RibaStage7VisitChange DECIMAL(9,2) = 0.0,
			-- Meetings
			@RibaStage0MeetingChange DECIMAL(9,2) = 0.0,
			@RibaStage1MeetingChange DECIMAL(9,2) = 0.0,
			@RibaStage2MeetingChange DECIMAL(9,2) = 0.0,
			@RibaStage3MeetingChange DECIMAL(9,2) = 0.0,
			@RibaStage4MeetingChange DECIMAL(9,2) = 0.0,
			@RibaStage5MeetingChange DECIMAL(9,2) = 0.0,
			@RibaStage6MeetingChange DECIMAL(9,2) = 0.0,
			@RibaStage7MeetingChange DECIMAL(9,2) = 0.0,
			@PreConstructionStageMeetingChange DECIMAL(9,2) = 0.0,
			@PreConstructionStageVisitChange DECIMAL(9,2) = 0.0,
			@ConstructionStageMeetingChange DECIMAL(9,2) = 0.0,
			@ConstructionStageVisitChange DECIMAL(9,2) = 0.0,
			@FeeCapChange DECIMAL(9,2) = 0.0,
			@Reason NVARCHAR(MAX) = N'Automatically generated fee amendment.';


		/*
			[CUSTOM FEE AMENDMENT VARIABLES]
		*/
		DECLARE 
				@CustomFeeAmendmentGuid UNIQUEIDENTIFIER = NEWID(),
				@CustomRIBAStageGuid UNIQUEIDENTIFIER,
				@CustomStageChange DECIMAL(19,2);
		

		--Check if we are dealing with a custom RIBA stage.

		SELECT @IsCustomRIBAStage = root_hobt.IsCustomStage
		FROM SJob.RibaStages root_hobt
		WHERE 
				(root_hobt.ID = @RIBAStageId)



			--Handling for "default" RIBA stages
			IF(@IsCustomRIBAStage = 0)
				BEGIN
					IF(@RIBAStageId = 1)
						SET @RibaStage0Change = @Amt;
					ELSE IF(@RIBAStageId = 2)
						SET @RibaStage1Change = @Amt;
					ELSE IF(@RIBAStageId = 3)
						SET @RibaStage2Change = @Amt;
					ELSE IF(@RIBAStageId = 4)
						SET @RibaStage3Change = @Amt;
					ELSE IF(@RIBAStageId = 5)
						SET @RibaStage4Change = @Amt;
					ELSE IF(@RIBAStageId = 7)
						SET @RibaStage5Change = @Amt;
					ELSE IF(@RIBAStageId = 8)
						SET @RibaStage6Change = @Amt;
					ELSE IF(@RIBAStageId = 9)
						SET @RibaStage7Change = @Amt;
					ELSE IF(@RIBAStageId = 10)
						SET @PreConstructionStageChange = @Amt;
					ELSE IF(@RIBAStageId = 11)
						SET @ConstructionStageChange = @Amt;
				END
			--Handling for custom RIBA stages (ID should be greater than 11)
			ELSE IF(@IsCustomRIBAStage = 1)
			BEGIN 
				
				--Get GUID for custom RIBA stage.
				SELECT @CustomRIBAStageGuid = Guid
				FROM SJob.RibaStages
				WHERE ID = @RIBAStageId;

				--Set the amount.
				SET @CustomStageChange = @Amt;
			END;

		--Get the job Guid based on the ID
		SELECT @JobGuid = root_hobt.Guid
		FROM SJob.Jobs root_hobt
		WHERE root_hobt.ID = @JobId

		--Get the SVC User ID
		SELECT
			@SVCUserID = ID,
			@SVCUserGuid = Guid
		FROM SCore.Identities
		WHERE FullName LIKE N'%SVC%';

		DECLARE @IsInsert BIT;

		EXEC SCore.UpsertDataObject 
			@Guid = @FeeAmendmentGuid,					-- uniqueidentifier
			@SchemeName = N'SJob',				-- nvarchar(255)
			@ObjectName = N'FeeAmendment',				-- nvarchar(255)
			@IsInsert = @IsInsert OUTPUT	-- bit

		IF (@IsInsert = 1)
		BEGIN
			INSERT  SJob.FeeAmendment 
			(
				RowStatus,
				[Guid],
				JobID,
				CreatedByUserID,
				CreatedDateTime,
				RibaStage0Change,
				RibaStage1Change,
				RibaStage2Change,
				RibaStage3Change,
				RibaStage4Change,
				RibaStage5Change,
				RibaStage6Change,
				RibaStage7Change,
				--VISITS
				RibaStage0VisitChange,
				RibaStage1VisitChange,
				RibaStage2VisitChange,
				RibaStage3VisitChange,
				RibaStage4VisitChange,
				RibaStage5VisitChange,
				RibaStage6VisitChange,
				RibaStage7VisitChange,
				--MEETINGS
				RibaStage0MeetingChange,
				RibaStage1MeetingChange,
				RibaStage2MeetingChange,
				RibaStage3MeetingChange,
				RibaStage4MeetingChange,
				RibaStage5MeetingChange,
				RibaStage6MeetingChange,
				RibaStage7MeetingChange,

				PreConstructionStageChange,
				ConstructionStageChange,
				--PRECONSTRUCTIONS + CONSTRUCTIONS
				PreConstructionStageMeetingChange,
				PreConstructionStageVisitChange,
				ConstructionStageMeetingChange,
				ConstructionStageVisitChange,

				FeeCapChange,
				Reason
			)
			VALUES
			(
				1,
				@FeeAmendmentGuid,
				@JobID,
				@SVCUserID,
				GETUTCDATE(),
				@RibaStage0Change,
				@RibaStage1Change,
				@RibaStage2Change,
				@RibaStage3Change,
				@RibaStage4Change,
				@RibaStage5Change,
				@RibaStage6Change,
				@RibaStage7Change,
				--VISITS
				@RibaStage0VisitChange,
				@RibaStage1VisitChange,
				@RibaStage2VisitChange,
				@RibaStage3VisitChange,
				@RibaStage4VisitChange,
				@RibaStage5VisitChange,
				@RibaStage6VisitChange,
				@RibaStage7VisitChange,
				--MEETINGS
				@RibaStage0MeetingChange,
				@RibaStage1MeetingChange,
				@RibaStage2MeetingChange,
				@RibaStage3MeetingChange,
				@RibaStage4MeetingChange,
				@RibaStage5MeetingChange,
				@RibaStage6MeetingChange,
				@RibaStage7MeetingChange,
				@PreConstructionStageChange,
				@ConstructionStageChange,
				--Preconstruction + construction phases
				@PreConstructionStageMeetingChange,
				@PreConstructionStageVisitChange,
				@ConstructionStageMeetingChange,
				@ConstructionStageVisitChange,
				@FeeCapChange,
				@Reason
			)
		END

		--Create custom RIBA stage
		IF(@IsCustomRIBAStage = 1)
		BEGIN
		
			EXEC [SJob].[CustomFeeAmendmentUpsert]
						@Guid = @CustomFeeAmendmentGuid,
						@StageChange = @CustomStageChange,
						@StageMeetingChange = 0,
						@StageVisitChange = 0,
						@Reason = @Reason,
						@StageGuid = @CustomRIBAStageGuid,
						@FeeAmendmentGuid = @FeeAmendmentGuid,
						@CreatedByUserGuid = @SVCUserGuid
		END;

	END;
END;
GO