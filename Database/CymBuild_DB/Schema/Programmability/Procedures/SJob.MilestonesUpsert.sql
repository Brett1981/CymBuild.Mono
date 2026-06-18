SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[MilestonesUpsert]')
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
    @SubmittedDateTimeUTC   DATETIME2,
    @SubmittedByGuid        UNIQUEIDENTIFIER,
    @SubmissionExpiryDate   DATETIME2,
    @Guid                   UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartedByUserID   INT,
            @CompletedByUserID INT,
            @ReviewerUserID    INT,
            @SubmittedByID     INT,
            @MilestoneTypeID   INT,
            @JobID             INT,
            @UserID            INT;

    SELECT @UserID = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);

    SELECT @StartedByUserID = i.ID
    FROM SCore.Identities AS i
    WHERE i.Guid = @StartedByUserGuid;

    IF @StartDateTimeUTC IS NOT NULL
       AND ISNULL(@StartedByUserID, -1) < 0
    BEGIN
        SET @StartedByUserID = @UserID;
    END;

    SELECT @ReviewerUserID = i.ID
    FROM SCore.Identities AS i
    WHERE i.Guid = @ReviewerUserGuid;

    IF @ReviewedDateTimeUTC IS NOT NULL
       AND ISNULL(@ReviewerUserID, -1) < 0
    BEGIN
        SET @ReviewerUserID = @UserID;
    END;

    SELECT @CompletedByUserID = i.ID
    FROM SCore.Identities AS i
    WHERE i.Guid = @CompletedByUserGuid;

    IF @CompletedDateTimeUTC IS NOT NULL
       AND ISNULL(@CompletedByUserID, -1) < 0
    BEGIN
        SET @CompletedByUserID = @UserID;
    END;

    SELECT @SubmittedByID = i.ID
    FROM SCore.Identities AS i
    WHERE i.Guid = @SubmittedByGuid;

    SELECT @MilestoneTypeID = mt.ID
    FROM SJob.MilestoneTypes AS mt
    WHERE mt.Guid = @MilestoneTypeGuid;

    SELECT @JobID = j.ID
    FROM SJob.Jobs AS j
    WHERE j.Guid = @JobGuid;

    DECLARE @IsInsert BIT;

    EXEC SCore.UpsertDataObject
        @Guid       = @Guid,
        @SchemeName = N'SJob',
        @ObjectName = N'Milestones',
        @IsInsert   = @IsInsert OUTPUT;

    IF @IsInsert = 1
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
            1,
            @Guid,
            @JobID,
            -1,
            @MilestoneTypeID,
            @Description,
            @StartDateTimeUTC,
            @DueDateTimeUTC,
            @ScheduledDateTimeUTC,
            @CompletedDateTimeUTC,
            @QuotedHours,
            @EstimateHoursRemaining,
            @SortOrder,
            ISNULL(@StartedByUserID, -1),
            ISNULL(@CompletedByUserID, -1),
            @IsNotApplicable,
            @ReviewedDateTimeUTC,
            ISNULL(@ReviewerUserID, -1),
            @Reference,
            ISNULL(@SubmittedByID, -1),
            @SubmittedDateTimeUTC,
            @SubmissionExpiryDate
        );
    END;
    ELSE
    BEGIN
        UPDATE SJob.Milestones
        SET JobID = @JobID,
            MilestoneTypeID = @MilestoneTypeID,
            Description = @Description,
            StartDateTimeUTC = @StartDateTimeUTC,
            DueDateTimeUTC = @DueDateTimeUTC,
            ScheduledDateTimeUTC = @ScheduledDateTimeUTC,
            CompletedDateTimeUTC = @CompletedDateTimeUTC,
            QuotedHours = @QuotedHours,
            EstimatedRemainingHours = @EstimateHoursRemaining,
            SortOrder = @SortOrder,
            StartedByUserId = ISNULL(@StartedByUserID, -1),
            CompletedByUserId = ISNULL(@CompletedByUserID, -1),
            IsNotApplicable = @IsNotApplicable,
            ReviewedDateTimeUTC = @ReviewedDateTimeUTC,
            ReviewerUserId = ISNULL(@ReviewerUserID, -1),
            Reference = @Reference,
            SubmittedBy = ISNULL(@SubmittedByID, -1),
            SubmittedDateTimeUTC = @SubmittedDateTimeUTC,
            SubmissionExpiryDate = @SubmissionExpiryDate
        WHERE Guid = @Guid;
    END;

    UPDATE m
    SET SortOrder = o.CalcOrder
    FROM SJob.Milestones AS m
    INNER JOIN
    (
        SELECT
            ROW_NUMBER() OVER (ORDER BY m.SortOrder, m.ID) AS CalcOrder,
            m.ID
        FROM SJob.Milestones AS m
        WHERE m.JobID = @JobID
          AND m.RowStatus NOT IN (0, 254)
    ) AS o
        ON o.ID = m.ID
    WHERE o.CalcOrder <> m.SortOrder
      AND m.JobID = @JobID;
END
GO