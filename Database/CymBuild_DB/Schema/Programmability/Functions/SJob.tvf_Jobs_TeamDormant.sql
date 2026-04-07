SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_TeamDormant]
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
        j.JobTypeID,
        jt.Name AS JobTypeName,
        i.Guid AS SurveyorGuid,
        client.Name + N' / ' + agent.Name AS ClientAgent,
        i.FullName AS SurveyorName,
        prop.FormattedAddressComma,
        js.IsSubjectToNDA,
        j.IsComplete,
        js.JobStatus,
        j.JobDormant,
        orgu.Name AS OrgUnit
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus AS js ON (js.ID = j.ID)
    JOIN SJob.JobTypes AS jt ON (j.JobTypeID = jt.ID)
    JOIN SCore.Identities AS i ON (j.SurveyorID = i.ID)
    JOIN SJob.Assets AS prop ON (prop.ID = j.UprnID)
    JOIN SCrm.Accounts AS client ON (client.ID = j.ClientAccountID)
    JOIN SCrm.Accounts AS agent ON (agent.ID = j.AgentAccountID)
    JOIN SCore.OrganisationalUnits AS orgu ON (orgu.ID = j.OrganisationalUnitID)

    -- Latest workflow status for this job (if any)
    OUTER APPLY
    (
        SELECT TOP (1)
            wfs.Guid AS LatestWorkflowStatusGuid,
            wfs.Name AS LatestWorkflowStatusName
        FROM SCore.DataObjectTransition dot
        JOIN SCore.WorkflowStatus wfs ON (wfs.ID = dot.StatusID)
        WHERE (dot.RowStatus NOT IN (0, 254))
          AND (dot.DataObjectGuid = j.Guid)
        ORDER BY dot.ID DESC
    ) AS wf

    CROSS APPLY
    (
        SELECT ou1.OrgNode
        FROM SCore.OrganisationalUnits AS ou1
        JOIN SCore.Identities AS i1 ON (i1.OriganisationalUnitId = ou1.ID)
        WHERE (i1.ID = @UserId)
    ) AS CurrentUser

    WHERE (j.RowStatus NOT IN (0, 254))
      AND (j.ID > 0)

      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr


      )

      /* --------------------------------------------------------------------
         NOT COMPLETE: legacy vs workflow (latest only)
         - If workflow exists -> exclude if latest status is Completed (by name to avoid guessing GUID)
         - If no workflow -> use legacy j.IsComplete
         (If you want this tied to the Completed GUID like other TVFs, say so and I’ll align it.)
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsComplete, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusName IN (N'Completed')
                          THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         DORMANT: workflow wins if present; legacy only if no workflow exists
         - If workflow exists -> Dormant when latest status is Dormant
         - If no workflow -> Dormant when legacy JobDormant has a value
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN j.JobDormant IS NOT NULL THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusName = N'Dormant'
                          THEN 1
                      ELSE 0
                  END
          END
      ) = 1

      -- Team scope via org node descendant check (unchanged)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.OrganisationalUnits AS ou2
          WHERE (ou2.ID = i.OriganisationalUnitId)
            AND (ou2.OrgNode.IsDescendantOf(CurrentUser.OrgNode) = 1)
      )
);
GO