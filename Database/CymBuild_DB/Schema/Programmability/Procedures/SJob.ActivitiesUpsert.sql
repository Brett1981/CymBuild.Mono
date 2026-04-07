SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[ActivitiesUpsert]
(
    @JobGuid UNIQUEIDENTIFIER,
    @SurveyorGuid UNIQUEIDENTIFIER,
    @Date DATETIME2,
    @EndDate DATETIME2,
    @ActivityTypeGuid UNIQUEIDENTIFIER,
    @ActivityStatusGuid UNIQUEIDENTIFIER,
    @Title NVARCHAR(250),
    @Notes NVARCHAR(MAX),
    @EditedByUserGuid UNIQUEIDENTIFIER,
	@IsAdditionalWork BIT,
	@RibaStageGuid UNIQUEIDENTIFIER,
	@MilestoneGuid UNIQUEIDENTIFIER,
	@InvoicingQuantity Decimal (19,2),
	@InvoicingValue Decimal (19,2),
    @Guid UNIQUEIDENTIFIER,
	@NewExpiryDate DATETIME2
)
AS 
BEGIN 
    DECLARE @SurveyorID INT,
            @ActivityTypeID INT,
            @ActivityStatusID INT,
			@RibaStageId INT = -1,
			@MilestoneId INT = -1,
            @UserID INT,
            @JobID INT

	
	DECLARE @F10UpdatedActivityType UNIQUEIDENTIFIER;

	SELECT @F10UpdatedActivityType = Guid 
	FROM SJob.ActivityTypes
	WHERE Name = N'F10 Updated/Reissued'

    SELECT  @SurveyorID = ID 
    FROM    SCore.Identities 
    WHERE   ([Guid] = @SurveyorGuid)

    SELECT  @ActivityTypeID = ID 
    FROM    SJob.ActivityTypes 
    WHERE   ([Guid] = @ActivityTypeGuid)

	IF (@MilestoneGuid <> '00000000-0000-0000-0000-000000000000')
	BEGIN 
		SELECT	@MilestoneId = m.ID,
				@JobID = m.JobID
		FROM	SJob.Milestones m
		JOIN	SJob.Jobs AS j ON (j.id = m.JobID)
		WHERE	(m.Guid = @MilestoneGuid)
	END	
	ELSE
	BEGIN 
		SET @MilestoneId = -1
	END

    SELECT  @RibaStageId = ID 
    FROM    SJob.RibaStages 
    WHERE   ([Guid] = @RibaStageGuid)

	SELECT  @ActivityStatusID = ID 
    FROM    SJob.ActivityStatus 
    WHERE   ([Guid] = @ActivityStatusGuid)

    SELECT  @UserID = ID 
    FROM    SCore.Identities 
    WHERE   ([Guid] = @EditedByUserGuid)

	IF (@UserID IS NULL)
	BEGIN 
		SELECT @UserID = CONVERT(INT, SESSION_CONTEXT(N'user_id'))
	END

    SELECT  @JobID = ID 
    FROM    SJob.Jobs 
    WHERE   ([Guid] = @JobGuid)

    DECLARE	@IsInsert bit
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'Activities',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN 

        INSERT  SJob.Activities 
        (
            RowStatus,
            [Guid],
            JobID,
            SurveyorID,
            Date,
            EndDate,
            ActivityTypeID,
            ActivityStatusID,
            Title,
            Notes,
            CreatedByUserID,
            LastUpdatedByUserID,
            VersionID,
			IsAdditionalWork,
			MilestoneID,
			RibaStageId,
			InvoicingQuantity,
			InvoicingValue,
			NewExpiryDate
        )
        VALUES
        (
            1,
            @Guid,
            @JobID,
            @SurveyorID,
            @Date,
            @EndDate, 
            @ActivityTypeID,
            @ActivityStatusID,
            @Title,
            @Notes,
            @UserID,
            @UserID,
            -1,
			@IsAdditionalWork,
			@MilestoneId,
			@RibaStageId,
			@InvoicingQuantity,
			@InvoicingValue,
			@NewExpiryDate
        )
    END
    ELSE
    BEGIN 
        UPDATE  SJob.Activities
        SET     RowStatus = 1,
                JobID = @JobID,
                SurveyorID = @SurveyorID,
                Date = @Date,
                EndDate = @EndDate,
                ActivityTypeID = @ActivityTypeID,
                ActivityStatusID = @ActivityStatusID,
                Title = @Title,
                Notes = @Notes,
                LastUpdatedByUserID = @UserID,
				IsAdditionalWork = @IsAdditionalWork,
				RibaStageId = @RibaStageId,
				MilestoneID = @MilestoneId,
				InvoicingQuantity = @InvoicingQuantity,
				InvoicingValue = @InvoicingValue,
				NewExpiryDate = @NewExpiryDate
        WHERE   ([Guid] = @Guid)
    END

	--Lastly, update the new expiry date
	IF(@ActivityTypeGuid = @F10UpdatedActivityType AND @NewExpiryDate IS NOT NULL)
		BEGIN
			
			DECLARE @MilestoneTypeID INT;

			SELECT @MilestoneTypeID = ID 
			FROM SJob.MilestoneTypes
			WHERE Code = N'F10'; --F10;

			UPDATE SJob.Milestones
			SET SubmissionExpiryDate = @NewExpiryDate
			WHERE 
				JobID = @JobID AND
				MilestoneTypeID = @MilestoneTypeID
		END;
END
GO