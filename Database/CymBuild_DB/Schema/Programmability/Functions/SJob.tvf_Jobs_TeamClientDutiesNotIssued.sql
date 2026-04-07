SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_TeamClientDutiesNotIssued]
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
        i.FullName AS SurveyorName,
        js.IsSubjectToNDA,
        j.ExternalReference,
        client.Name + N' / ' + agent.Name AS ClientAgent,
        asset.FormattedAddressComma AS Asset,
        j.CreatedOn
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus AS js ON (js.ID = j.ID)
    JOIN SJob.JobTypes AS jt ON (j.JobTypeID = jt.ID)
    JOIN SCore.Identities AS i ON (j.SurveyorID = i.ID)
    JOIN SCrm.Accounts AS client ON (client.ID = j.ClientAccountID)
    JOIN SCrm.Accounts AS agent ON (agent.ID = j.AgentAccountID)
    JOIN SJob.Assets AS asset ON (asset.ID = j.UprnID)

    -- Latest workflow status for this job (if any)
    OUTER APPLY
    (
        SELECT TOP (1)
            wfs.Guid AS LatestWorkflowStatusGuid
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

      /* --------------------------------------------------------------------
         NOT COMPLETE: legacy OR workflow (latest only)
         Completed workflow status GUID: 20D22623-283B-4088-9CEB-D944AC3E6516
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN
                      CASE
                          WHEN (ISNULL(j.IsComplete, 0) = 0) AND (j.JobCompleted IS NULL) THEN 1 ELSE 0
                      END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '20D22623-283B-4088-9CEB-D944AC3E6516'
                          THEN 0  -- completed (exclude)
                      ELSE 1      -- not completed (include)
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT CANCELLED: legacy OR workflow (latest only)
         Cancelled workflow status GUID: 18D8E36B-43BE-4BDE-9D0B-1F34B460AD64
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsCancelled, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64'
                          THEN 0  -- cancelled (exclude)
                      ELSE 1      -- not cancelled (include)
                  END
          END
      ) = 1

      -- Security (unchanged)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
      )

      -- Milestone check (unchanged)
      AND EXISTS
      (
          SELECT 1
          FROM SJob.Milestones AS m
          JOIN SJob.MilestoneTypes AS mt ON (mt.ID = m.MilestoneTypeID)
          WHERE (m.JobID = j.ID)
            AND (mt.Code = N'CLIENTDUTIES')
            AND (m.CompletedDateTimeUTC IS NULL)
            AND (m.CompletedByUserId = -1)
            AND (m.RowStatus NOT IN (0, 254))
      )

      -- Team scope (unchanged)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.OrganisationalUnits AS ou2
          WHERE (ou2.ID = i.OriganisationalUnitId)
            AND (ou2.OrgNode.IsDescendantOf(CurrentUser.OrgNode) = 1)
      )
);
GO