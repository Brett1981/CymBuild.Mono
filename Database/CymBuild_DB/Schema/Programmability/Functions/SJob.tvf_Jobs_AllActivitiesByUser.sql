SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_AllActivitiesByUser]
(
    @UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
(
    SELECT
        j.Guid,
        act.ID,
        act.RowStatus,
        act.Title,
        act.Notes,
        j.Number,
        actS.Name AS ActivityStatus,
        actT.Name AS ActivityType,
        CONVERT(VARCHAR(10), act.Date, 103) AS [Date]
    FROM SJob.Activities AS act
    INNER JOIN SJob.Jobs AS j ON (act.JobID = j.ID)
    JOIN SJob.ActivityStatus AS actS ON (actS.ID = act.ActivityStatusID)
    JOIN SJob.ActivityTypes  AS actT ON (actT.ID = act.ActivityTypeID)

    -- Latest workflow status for the parent Job (if any) - rowstatus safe
    OUTER APPLY
    (
        SELECT TOP (1)
            wfs.Guid AS LatestWorkflowStatusGuid,
            wfs.IsActiveStatus AS LatestIsActiveStatus
        FROM SCore.DataObjectTransition AS dot
        JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
        WHERE (dot.RowStatus NOT IN (0, 254))
          AND (dot.DataObjectGuid = j.Guid)
        ORDER BY dot.ID DESC
    ) AS wf

    WHERE (act.SurveyorID = @UserId)
      AND (j.RowStatus NOT IN (0, 254))
      AND (act.RowStatus NOT IN (0, 254))

      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
      )

      /* --------------------------------------------------------------------
         GLOBAL ACTIVE RULE (latest workflow wins):
         - If workflow exists => must have LatestIsActiveStatus = 1
         - Else => must have legacy IsActive = 1
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN ISNULL(j.IsActive, 0)
              ELSE ISNULL(wf.LatestIsActiveStatus, 0)
          END
      ) = 1
);
GO