SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[MilestonesUpsert]
  (
    @JobGuid                UNIQUEIDENTIFIER,
    @MilestoneTypeGuid      UNIQUEIDENTIFIER,
    @Description            NVARCHAR(500),
    @StartDateTimeUTC       DATETIME2,
    @DueDateTimeUTC         DATETIME2,
    @ScheduledDateTimeUTC   DATETIME2,
    @CompletedDateTimeUTC   DATETIME2,
    @QuotedHours            DECIMAL(19, 2),
    @EstimateHoursRemaining DECIMAL(19, 2),
    @SortOrder              INT,
    @StartedByUserGuid      UNIQUEIDENTIFIER,
    @CompletedByUserGuid    UNIQUEIDENTIFIER,
    @IsNotApplicable        BIT,
    @ReviewedDateTimeUTC    DATETIME2,
    @ReviewerUserGuid       UNIQUEIDENTIFIER,
    @Reference              NVARCHAR(100),
	@SubmittedDateTimeUTC	DATETIME2,
	@SubmittedByGuid		UNIQUEIDENTIFIER,
	@SubmissionExpiryDate	DATETIME2,	
    @Guid                   UNIQUEIDENTIFIER
  )
AS
  BEGIN
    DECLARE @StartedByUserID   INT,
            @CompletedByUserID INT,
            @ReviewerUserID    INT,
			@SubmittedByID		INT,
            @MilestoneTypeID   INT,
            @JobID             INT,
            @UserID            INT

    SELECT
            @UserID = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1)

    SELECT
            @StartedByUserID = ID
    FROM
            SCore.Identities
    WHERE
            ([Guid] = @StartedByUserGuid)

    IF (@StartDateTimeUTC IS NOT NULL)
      AND
      (@StartedByUserID < 0)
      BEGIN
        SET @StartedByUserID = @UserID
      END

    SELECT
            @ReviewerUserID = ID
    FROM
            SCore.Identities
    WHERE
            ([Guid] = @ReviewerUserGuid)

    IF (@ReviewedDateTimeUTC IS NOT NULL)
      AND
      (@ReviewerUserID < 0)
      BEGIN
        SET @ReviewerUserID = @UserID
      END

    SELECT
            @CompletedByUserID = ID
    FROM
            SCore.Identities
    WHERE
            ([Guid] = @CompletedByUserGuid)

    IF (@CompletedDateTimeUTC IS NOT NULL)
      AND
      (@CompletedByUserID < 0)
      BEGIN
        SET @CompletedByUserID = @UserID
      END

	SELECT	
			@SubmittedByID = ID
	FROM	
			SCore.Identities AS i
	WHERE	
			([Guid] = @SubmittedByGuid)

    SELECT
            @MilestoneTypeID = ID
    FROM
            SJob.MilestoneTypes
    WHERE
            ([Guid] = @MilestoneTypeGuid)

    SELECT
            @JobID = ID
    FROM
            SJob.Jobs
    WHERE
            ([Guid] = @JobGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SJob',				-- nvarchar(255)
      @ObjectName = N'Milestones',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SJob.Milestones
              (
                RowStatus,
                Guid,
                JobID,
                QuoteLineID,
                MilestoneTypeID,
                Description,
                StartDateTimeUTC,
                DueDateTimeUTC,
                ScheduledDateTimeUTC,
                CompletedDateTimeUTC,
                QuotedHours,
                EstimatedRemainingHours,
                SortOrder,
                StartedByUserId,
                CompletedByUserId,
                IsNotApplicable,
                ReviewedDateTimeUTC,
                ReviewerUserId,
                Reference,
				SubmittedBy,
				SubmittedDateTimeUTC,
				SubmissionExpiryDate
              )
        VALUES
                (
                  1,	-- RowStatus - tinyint
                  @Guid,	-- Guid - uniqueidentifier
                  @JobID,	-- JobID - int
                  -1,	-- QuoteLineID - int
                  @MilestoneTypeID,	-- MilestoneTypeID - int
                  @Description,	-- Description - nvarchar(500)
                  @StartDateTimeUTC,		-- StartDateTime - datetime2(7)
                  @DueDateTimeUTC,		-- DueDateTime - datetime2(7)
                  @ScheduledDateTimeUTC,		-- ScheduledDateTime - datetime2(7)
                  @CompletedDateTimeUTC,		-- CompletedDateTime - datetime2(7)
                  0,	-- QuotedHours - decimal(19, 2)
                  0,	-- EstimatedRemainingHours - decimal(19, 2)
                  @SortOrder,	-- SortOrder - int
                  @StartedByUserID,	-- StartedByUserId - int
                  @CompletedByUserID,	-- CompletedByUserId - int
                  @IsNotApplicable,	-- IsNotApplicable - bit
                  @ReviewedDateTimeUTC,		-- ReviewedDateTime - datetime2(7)
                  @ReviewerUserID,	-- ReviewerUserId - int
                  @Reference,
				  @SubmittedByID,
				  @SubmittedDateTimeUTC,
				  @SubmissionExpiryDate
                )
      END
    ELSE
      BEGIN
        UPDATE  SJob.Milestones
        SET     JobID = @JobID,
                MilestoneTypeID = @MilestoneTypeID,
                Description = @Description,
                StartDateTimeUTC = @StartDateTimeUTC,
                DueDateTimeUTC = @DueDateTimeUTC,
                ScheduledDateTimeUTC = @ScheduledDateTimeUTC,
                CompletedDateTimeUTC = @CompletedDateTimeUTC,
                QuotedHours = @QuotedHours,
                EstimatedRemainingHours = @EstimateHoursRemaining,
                SortOrder = @SortOrder,
                StartedByUserId = @StartedByUserID,
                CompletedByUserId = @CompletedByUserID,
                IsNotApplicable = @IsNotApplicable,
                ReviewedDateTimeUTC = @ReviewedDateTimeUTC,
                ReviewerUserId = @ReviewerUserID,
                Reference = @Reference,
				SubmittedBy = @SubmittedByID,
				SubmittedDateTimeUTC = @SubmittedDateTimeUTC,
				SubmissionExpiryDate = @SubmissionExpiryDate
        WHERE
          ([Guid] = @Guid)
      END

    UPDATE  m
    SET     SortOrder = o.CalcOrder
    FROM
            SJob.Milestones m
    INNER JOIN
            (
                SELECT
                        ROW_NUMBER() OVER (ORDER BY m.SortOrder, m.ID) AS CalcOrder,
                        m.ID
                FROM
                        SJob.Milestones m
                WHERE
                        (m.JobID = @JobID)
            ) o ON (o.ID = m.ID)
    WHERE
      (o.CalcOrder <> m.SortOrder)
      AND (m.JobID = @JobID)
  END
GO