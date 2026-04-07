SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[FeeAmendmentsUpsert]
(
    @JobGuid UNIQUEIDENTIFIER,
	@RibaStage0Change DECIMAL(9,2),
	@RibaStage1Change DECIMAL(9,2),
	@RibaStage2Change DECIMAL(9,2),
	@RibaStage3Change DECIMAL (9,2),
	@RibaStage4Change DECIMAL (9,2),
	@RibaStage5Change DECIMAL (9,2),
	@RibaStage6Change DECIMAL (9,2),
	@RibaStage7Change DECIMAL (9,2),

	 -- Visits
    @RibaStage0VisitChange DECIMAL(9,2),
	@RibaStage1VisitChange DECIMAL(9,2),
	@RibaStage2VisitChange DECIMAL(9,2),
	@RibaStage3VisitChange DECIMAL(9,2),
	@RibaStage4VisitChange DECIMAL(9,2),
	@RibaStage5VisitChange DECIMAL(9,2),
	@RibaStage6VisitChange DECIMAL(9,2),
	@RibaStage7VisitChange DECIMAL(9,2),

    -- Meetings
    @RibaStage0MeetingChange DECIMAL(9,2),
	@RibaStage1MeetingChange DECIMAL(9,2),
	@RibaStage2MeetingChange DECIMAL(9,2),
	@RibaStage3MeetingChange DECIMAL(9,2),
	@RibaStage4MeetingChange DECIMAL(9,2),
	@RibaStage5MeetingChange DECIMAL(9,2),
	@RibaStage6MeetingChange DECIMAL(9,2),
	@RibaStage7MeetingChange DECIMAL(9,2),

	@PreConstructionStageChange DECIMAL (9,2),
	@ConstructionStageChange DECIMAL (9,2),
	--Preconstruction + construction phases
	@PreConstructionStageMeetingChange DECIMAL(9,2),
	@PreConstructionStageVisitChange DECIMAL(9,2),
	@ConstructionStageMeetingChange DECIMAL(9,2),
	@ConstructionStageVisitChange DECIMAL(9,2),

	@FeeCapChange DECIMAL(9,2),
    @Guid UNIQUEIDENTIFIER,
	@Reason NVARCHAR(MAX)
)
AS 
BEGIN 
    DECLARE @UserID INT,
            @JobID INT

	IF (@UserID IS NULL)
	BEGIN 
		SELECT @UserID = CONVERT(INT, SESSION_CONTEXT(N'user_id'))
	END

    SELECT  @JobID = ID 
    FROM    SJob.Jobs 
    WHERE   ([Guid] = @JobGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
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
            @Guid,
            @JobID,
            @UserID,
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
    ELSE
    BEGIN 
        UPDATE  SJob.FeeAmendment 
        SET     RowStatus = 1,
                JobID = @JobID,
                RibaStage0Change = @RibaStage0Change,
				RibaStage1Change = @RibaStage1Change,
				RibaStage2Change = @RibaStage2Change,
				RibaStage3Change = @RibaStage3Change,
				RibaStage4Change = @RibaStage4Change,
				RibaStage5Change = @RibaStage5Change,
				RibaStage6Change = @RibaStage6Change,
				RibaStage7Change = @RibaStage7Change,
				--VISIT
				RibaStage0VisitChange = @RibaStage0VisitChange,
				RibaStage1VisitChange = @RibaStage1VisitChange,
				RibaStage2VisitChange = @RibaStage2VisitChange,
				RibaStage3VisitChange = @RibaStage3VisitChange,
				RibaStage4VisitChange = @RibaStage4VisitChange,
				RibaStage5VisitChange = @RibaStage5VisitChange,
				RibaStage6VisitChange = @RibaStage6VisitChange,
				RibaStage7VisitChange = @RibaStage7VisitChange,
				--MEETINGS
				RibaStage0MeetingChange = @RibaStage0MeetingChange,
				RibaStage1MeetingChange = @RibaStage1MeetingChange,
				RibaStage2MeetingChange = @RibaStage2MeetingChange,
				RibaStage3MeetingChange = @RibaStage3MeetingChange,
				RibaStage4MeetingChange = @RibaStage4MeetingChange,
				RibaStage5MeetingChange = @RibaStage5MeetingChange,
				RibaStage6MeetingChange = @RibaStage6MeetingChange,
				RibaStage7MeetingChange = @RibaStage7MeetingChange,

				PreConstructionStageChange = @PreConstructionStageChange,
				ConstructionStageChange = @ConstructionStageChange,
				--Construction + preconstruction
				PreConstructionStageMeetingChange =  @PreConstructionStageMeetingChange,
				PreConstructionStageVisitChange	  =	 @PreConstructionStageVisitChange, 
				ConstructionStageMeetingChange	  =	 @ConstructionStageMeetingChange,	 
				ConstructionStageVisitChange	  =	 @ConstructionStageVisitChange,	 
				FeeCapChange = @FeeCapChange,
				Reason = @Reason
        WHERE   ([Guid] = @Guid)
    END
END
GO