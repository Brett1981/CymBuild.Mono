SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_NoAcceptanceDocReceived]
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
        j.JobDescription AS Description,
        client.Name + N' / ' + agent.Name AS ClientAgent,
        asset.FormattedAddressComma AS Asset,
        j.ExternalReference AS ExternalReference,
        jt.Name AS JobTypeName,
        j.CreatedOn AS CreatedOn
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus AS js ON (js.ID = j.ID)
    JOIN SJob.JobTypes  AS jt ON (j.JobTypeID = jt.ID)
    JOIN SCrm.Accounts  AS client ON (client.ID = j.ClientAccountID)
    JOIN SCrm.Accounts  AS agent  ON (agent.ID = j.AgentAccountID)
    JOIN SJob.Assets    AS asset  ON (asset.ID = j.UprnID)

    -- Latest workflow status for this job (if any) - rowstatus safe (dot + wfs)
    OUTER APPLY
    (
        SELECT TOP (1)
            wfs.Guid           AS LatestWorkflowStatusGuid,
            wfs.IsActiveStatus AS LatestIsActiveStatus
        FROM SCore.DataObjectTransition AS dot
        JOIN SCore.WorkflowStatus       AS wfs ON (wfs.ID = dot.StatusID)
        WHERE (dot.RowStatus NOT IN (0, 254))
          AND (wfs.RowStatus NOT IN (0, 254))
          AND (dot.DataObjectGuid = j.Guid)
        ORDER BY dot.ID DESC
    ) AS wf

    WHERE (j.RowStatus NOT IN (0, 254))
      AND (j.AppFormReceived = 0)
      AND (j.SurveyorID = @UserId)

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
         NOT CANCELLED: legacy OR workflow (latest only)
         Cancelled workflow GUID: 18D8E36B-43BE-4BDE-9D0B-1F34B460AD64
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsCancelled, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = CONVERT(uniqueidentifier, '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64') THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT COMPLETE: legacy OR workflow (latest only)
         Completed workflow GUID: 20D22623-283B-4088-9CEB-D944AC3E6516
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN
                      CASE
                          WHEN (ISNULL(j.IsComplete, 0) = 0) AND (j.JobCompleted IS NULL) THEN 1
                          ELSE 0
                      END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = CONVERT(uniqueidentifier, '20D22623-283B-4088-9CEB-D944AC3E6516') THEN 0
                      ELSE 1
                  END
          END
      ) = 1
);
GO