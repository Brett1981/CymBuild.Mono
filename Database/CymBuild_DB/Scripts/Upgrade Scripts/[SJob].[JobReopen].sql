CREATE OR ALTER PROCEDURE [SJob].[JobReopen]
    @Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserID INT = -1;

    SELECT
        @UserID = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);

    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.UserGroups AS ug
        JOIN SCore.Groups AS g
            ON g.ID = ug.GroupID
        WHERE ug.IdentityID = @UserID
          AND g.Code = N'JOBSU'
          AND ug.RowStatus NOT IN (0,254)
          AND g.RowStatus NOT IN (0,254)
    )
    BEGIN
        ;THROW 60000, N'Only members of the Job Superusers group can run this action.', 1;
    END;

    DECLARE
        @UserGuid UNIQUEIDENTIFIER,
        @PreviousStatusGuid UNIQUEIDENTIFIER,
        @LastAppliedStatusGuid UNIQUEIDENTIFIER,
        @ReopenedStatusGuid UNIQUEIDENTIFIER,
        @JobStartedStatusGuid UNIQUEIDENTIFIER,
        @CompleteStatusGuid UNIQUEIDENTIFIER,
        @CancelledStatusGuid UNIQUEIDENTIFIER,
        @TransitionGuid UNIQUEIDENTIFIER;

    SELECT @UserGuid = i.Guid
    FROM SCore.Identities AS i
    WHERE i.ID = @UserID
      AND i.RowStatus NOT IN (0,254);

    IF (@UserGuid IS NULL)
        THROW 60000, N'Could not resolve current user.', 1;

    SELECT TOP (1) @ReopenedStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInJobs = 1
      AND ws.Name = N'Reopened'
    ORDER BY ws.ID;

    SELECT TOP (1) @JobStartedStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInJobs = 1
      AND ws.Name = N'Job Started'
    ORDER BY ws.ID;

    SELECT TOP (1) @CompleteStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInJobs = 1
      AND ws.Name IN (N'Completed', N'Complete')
    ORDER BY
        CASE WHEN ws.Name = N'Completed' THEN 0 ELSE 1 END,
        ws.ID;

    SELECT TOP (1) @CancelledStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInJobs = 1
      AND ws.Name = N'Cancelled'
    ORDER BY ws.ID;

    IF (@ReopenedStatusGuid IS NULL)
        THROW 60000, N'Could not resolve Reopened job status.', 1;

    IF (@JobStartedStatusGuid IS NULL)
        THROW 60000, N'Could not resolve Job Started job status.', 1;

    IF (@CompleteStatusGuid IS NULL OR @CancelledStatusGuid IS NULL)
        THROW 60000, N'Could not resolve one or more job statuses required for reopening.', 1;

    SELECT TOP (1)
        @PreviousStatusGuid = ws.Guid,
        @LastAppliedStatusGuid = ws.Guid
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = @Guid
      AND dot.RowStatus NOT IN (0,254)
      AND ws.RowStatus NOT IN (0,254)
    ORDER BY dot.ID DESC;

    IF (@LastAppliedStatusGuid IS NULL)
        THROW 60000, N'Could not resolve latest job status.', 1;

    IF (@LastAppliedStatusGuid NOT IN (@CompleteStatusGuid, @CancelledStatusGuid))
        THROW 60000, N'Last applied status must be Completed or Cancelled.', 1;

    UPDATE j
    SET j.JobCompleted = NULL
    FROM SJob.Jobs AS j
    WHERE j.Guid = @Guid
      AND j.RowStatus NOT IN (0,254)
      AND j.JobCompleted IS NOT NULL;

    SET @TransitionGuid = NEWID();

    EXEC SCore.DataObjectTransitionUpsert
        @Guid = @TransitionGuid,
        @OldStatusGuid = @PreviousStatusGuid,
        @StatusGuid = @ReopenedStatusGuid,
        @Comment = N'The job has been reopened.',
        @CreatedByUserGuid = @UserGuid,
        @SurveyorUserGuid = @UserGuid,
        @DataObjectGuid = @Guid,
        @IsImported = 0;

    SET @TransitionGuid = NEWID();

    EXEC SCore.DataObjectTransitionUpsert
        @Guid = @TransitionGuid,
        @OldStatusGuid = @ReopenedStatusGuid,
        @StatusGuid = @JobStartedStatusGuid,
        @Comment = N'Reopened job returned to Job Started.',
        @CreatedByUserGuid = @UserGuid,
        @SurveyorUserGuid = @UserGuid,
        @DataObjectGuid = @Guid,
        @IsImported = 1;
END;
GO