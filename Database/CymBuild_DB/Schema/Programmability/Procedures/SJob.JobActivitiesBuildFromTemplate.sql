SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[JobActivitiesBuildFromTemplate]
    (@JobID INT)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @JobStartDate             DATETIME2,
            @UserId                   INT,
            @InitialActivityStatusId  INT;

    DECLARE @JobActivities TABLE
    (
        Guid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        Title NVARCHAR(250) NOT NULL DEFAULT '',
        StartDate DATETIME2 NULL,
        EndDate DATETIME2 NULL,
        ActivityTypeId INT NOT NULL DEFAULT ((-1)),
        MilestoneId INT NOT NULL DEFAULT ((-1))
    );

    SELECT @UserId = SCore.GetCurrentUserId();

    -------------------------------------------------------------------------
    -- FIX: JobStarted can be NULL by design (Job is "New").
    -- We must still generate non-null Activity dates.
    -- Anchor priority:
    --   1) JobStarted
    --   2) CreatedOn (if column exists)
    --   3) SYSUTCDATETIME()
    -------------------------------------------------------------------------
    IF COL_LENGTH('SJob.Jobs', 'CreatedOn') IS NOT NULL
    BEGIN
        SELECT @JobStartDate = COALESCE(j.JobStarted, j.CreatedOn, SYSUTCDATETIME())
        FROM   SJob.Jobs AS j
        WHERE  j.ID = @JobID;
    END
    ELSE
    BEGIN
        SELECT @JobStartDate = COALESCE(j.JobStarted, SYSUTCDATETIME())
        FROM   SJob.Jobs AS j
        WHERE  j.ID = @JobID;
    END

    IF (@JobStartDate IS NULL)
    BEGIN
        ;THROW 60001, N'JobActivitiesBuildFromTemplate: Could not resolve a JobStartDate anchor (JobStarted NULL and no fallback available).', 1;
    END

    SELECT @InitialActivityStatusId = stat.ID
    FROM   SJob.ActivityStatus AS stat
    WHERE  stat.Name = N'Tentative';

    IF (@InitialActivityStatusId IS NULL)
    BEGIN
        ;THROW 60000, N'Tentative Activity Status missing from system.', 1;
    END

    INSERT INTO @JobActivities (Title, StartDate, EndDate, ActivityTypeId, MilestoneId)
    SELECT
        pja.ActivityTitle,

        DATEADD(MONTH, pja.OffsetMonths,
            DATEADD(WEEK, pja.OffsetWeeks,
                DATEADD(DAY, pja.OffsetDays, @JobStartDate)
            )
        ) AS StartDate,

        DATEADD(MINUTE, 30,
            DATEADD(MONTH, pja.OffsetMonths,
                DATEADD(WEEK, pja.OffsetWeeks,
                    DATEADD(DAY, pja.OffsetDays, @JobStartDate)
                )
            )
        ) AS EndDate,

        jtat.ActivityTypeID,
        ISNULL(milestone.ID, -1)
    FROM   SJob.ProductJobActivities       AS pja
    JOIN   SJob.JobTypeActivityTypes       AS jtat ON (jtat.ID = pja.JobTypeActivityTypeId)
    JOIN   SJob.JobTypeMilestoneTemplates  AS jtmt ON (jtmt.ID = pja.JobTypeMilestoneTemplateId)
    JOIN   SJob.JobTypes                   AS jt   ON (jt.ID = jtat.JobTypeID)
    JOIN   SJob.Jobs                       AS j    ON (j.JobTypeID = jt.ID)
    OUTER APPLY
    (
        SELECT m.ID
        FROM   SJob.Milestones AS m
        WHERE  m.JobID = j.ID
          AND  jtmt.MilestoneTypeID = m.MilestoneTypeID
    ) AS milestone
    WHERE  j.ID = @JobID
      AND  EXISTS
      (
          SELECT 1
          FROM   SSop.QuoteItems AS qi
          WHERE  qi.CreatedJobId = j.ID
            AND  qi.ProductId    = pja.ProductId
      );

    DECLARE @IsInsert BIT,
            @GuidList SCore.GuidUniqueList;

    INSERT @GuidList (GuidValue)
    SELECT Guid
    FROM   @JobActivities AS ja;

    EXEC SCore.DataObjectBulkUpsert
         @GuidList               = @GuidList,
         @SchemeName             = N'SJob',
         @ObjectName             = N'Activities',
         @IncludeDefaultSecurity = 1,
         @IsInsert               = @IsInsert OUTPUT;

    -------------------------------------------------------------------------
    -- FIX: Ensure we never insert NULL into SJob.Activities.Date (NOT NULL).
    -------------------------------------------------------------------------
    INSERT INTO SJob.Activities
    (
        RowStatus,
        Guid,
        JobID,
        MilestoneID,
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
        InvoicingQuantity,
        LegacyID,
        ExchangeId,
        IsAdditionalWork,
        RibaStageId
    )
    SELECT
        1,
        ja.Guid,
        @JobID,
        ja.MilestoneId,
        -1,
        COALESCE(ja.StartDate, @JobStartDate),
        COALESCE(ja.EndDate, DATEADD(MINUTE, 30, COALESCE(ja.StartDate, @JobStartDate))),
        ja.ActivityTypeId,
        @InitialActivityStatusId,
        ja.Title,
        N'',
        @UserId,
        @UserId,
        -1,
        0,
        NULL,
        N'',
        0,
        -1
    FROM @JobActivities AS ja;
END;
GO