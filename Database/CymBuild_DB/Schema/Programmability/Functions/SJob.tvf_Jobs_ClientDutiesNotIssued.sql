SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_ClientDutiesNotIssued]
(
    @UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
(
    SELECT
        j.ID,
        j.RowStatus,
        j.RowVersion,
        j.Guid,
        j.Number,
        j.JobDescription,
        jt.Name                             AS JobTypeName,
        client.Name + N' / ' + agent.Name   AS ClientAgent,
        i.Guid                              AS SurveyorGuid,
        i.FullName                          AS SurveyorName,
        js.IsSubjectToNDA,
        asset.FormattedAddressComma         AS Asset,
        j.ExternalReference,
        j.CreatedOn
    FROM SJob.Jobs            AS j
    JOIN SJob.JobStatus       AS js    ON (js.ID = j.ID)
    JOIN SJob.JobTypes        AS jt    ON (j.JobTypeID = jt.ID)
    JOIN SCore.Identities     AS i     ON (j.SurveyorID = i.ID)
    JOIN SCrm.Accounts        AS client ON (client.ID = j.ClientAccountID)
    JOIN SCrm.Accounts        AS agent  ON (agent.ID = j.AgentAccountID)
    JOIN SJob.Assets          AS asset  ON (asset.ID = j.UprnID)

    -- Latest workflow status for this job (if any). If none, this returns NULLs.
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

    WHERE (j.RowStatus NOT IN (0, 254))

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

      /* --------------------------------------------------------------------
         NOT COMPLETE (exclude completed):
         Completed workflow status GUID: 20D22623-283B-4088-9CEB-D944AC3E6516
         Rule:
         - If workflow exists -> exclude only if latest == Completed
         - Else -> use legacy j.IsComplete (=0 means include)
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsComplete, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '20D22623-283B-4088-9CEB-D944AC3E6516' THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT CANCELLED (exclude cancelled):
         Cancelled workflow status GUID: 18D8E36B-43BE-4BDE-9D0B-1F34B460AD64
         Rule:
         - If workflow exists -> exclude only if latest == Cancelled
         - Else -> use legacy j.IsCancelled (=0 means include)
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsCancelled, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64' THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      AND (j.SurveyorID = @UserId)

      AND EXISTS
      (
          SELECT 1
          FROM SJob.Milestones AS m
          JOIN SJob.MilestoneTypes AS mt ON (mt.ID = m.MilestoneTypeID)
          WHERE (m.JobID = j.ID)
            AND (mt.Code = N'CLIENTDUTIES')
            AND (m.IsComplete = 0)
            AND (m.RowStatus NOT IN (0, 254))
      )
);
GO