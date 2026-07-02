SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[tvf_Jobs_F10ExpiryList]')
GO
CREATE FUNCTION [SJob].[tvf_Jobs_F10ExpiryList]
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
        client.Name AS Client,
        jt.Name AS JobTypeName,
        i.Guid AS SurveyorGuid,
        i.FullName AS SurveyorName,
        F10.SubmissionExpiryDate,
        F10.Reference,
        js.JobStatus,
        js.IsSubjectToNDA,
        p.FormattedAddressComma,
        client.Name + N' / ' + agent.Name AS ClientAgent,
        COALESCE(NULLIF(LTRIM(RTRIM(businessUnit.Name)), N''), N'') AS BusinessUnit,
        COALESCE(NULLIF(LTRIM(RTRIM(department.Name)), N''), N'') AS Department,
        j.ExternalReference,
        jobtypes.Name AS JobType
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus      AS js      ON (js.ID = j.ID)
    JOIN SJob.JobTypes       AS jt      ON (j.JobTypeID = jt.ID)
    JOIN SCore.Identities    AS i       ON (j.SurveyorID = i.ID)
    JOIN SCrm.Accounts       AS client  ON (client.ID = j.ClientAccountID)
    JOIN SJob.Assets         AS p       ON (p.ID = j.UprnID)
    JOIN SCrm.Accounts       AS agent   ON (agent.ID = j.AgentAccountID)    
    JOIN SCore.OrganisationalUnits AS ou  ON ou.ID = j.OrganisationalUnitID
    JOIN SJob.JobTypes       AS jobtypes ON (j.JobTypeID = jobtypes.ID)
    OUTER APPLY
    (
        SELECT TOP (1)
            ancestor.Name
        FROM SCore.OrganisationalUnits AS ancestor
        WHERE ancestor.RowStatus NOT IN (0,254)
          AND ISNULL(ancestor.IsBusinessUnit, 0) = 1
          AND ou.OrgNode IS NOT NULL
          AND ancestor.OrgNode IS NOT NULL
          AND ou.OrgNode.IsDescendantOf(ancestor.OrgNode) = 1
        ORDER BY ancestor.OrgNode.GetLevel() DESC,
                 ancestor.ID DESC
    ) AS businessUnit
    OUTER APPLY
    (
        SELECT TOP (1)
            ancestor.Name
        FROM SCore.OrganisationalUnits AS ancestor
        WHERE ancestor.RowStatus NOT IN (0,254)
          AND ISNULL(ancestor.IsDepartment, 0) = 1
          AND ou.OrgNode IS NOT NULL
          AND ancestor.OrgNode IS NOT NULL
          AND ou.OrgNode.IsDescendantOf(ancestor.OrgNode) = 1
        ORDER BY ancestor.OrgNode.GetLevel() DESC,
                 ancestor.ID DESC
    ) AS department
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

    -- Nearest-expiring (within 14 days) F10 that is not complete / not NA / not submitted
    CROSS APPLY
    (
        SELECT TOP (1)
            m.SubmissionExpiryDate,
            m.Reference
        FROM SJob.Milestones     AS m
        JOIN SJob.MilestoneTypes AS mt ON (mt.ID = m.MilestoneTypeID)
        WHERE (m.JobID = j.ID)
          AND (m.RowStatus NOT IN (0, 254))
          AND (mt.RowStatus NOT IN (0, 254))
          AND (mt.Code = N'F10')
          AND (m.IsNotApplicable = 0)
          AND (m.CompletedDateTimeUTC IS NULL)
          AND (m.SubmittedDateTimeUTC IS NULL)
          AND (m.SubmissionExpiryDate IS NOT NULL)
          AND (m.SubmissionExpiryDate >= GETUTCDATE())
          AND (m.SubmissionExpiryDate <  DATEADD(DAY, 14, GETUTCDATE()))
        ORDER BY m.SubmissionExpiryDate ASC, m.ID ASC
    ) AS F10

    WHERE (j.RowStatus NOT IN (0, 254))

      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
      )

      /* --------------------------------------------------------------------
         ACTIVE: latest-workflow-first.
         If wf exists and LatestIsActiveStatus = 0 => EXCLUDE (dead/cancelled equivalent)
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
         NOT COMPLETE FOR REVIEW: latest-workflow-first
         CFR workflow status GUID: 4BFDB215-3E27-4829-BB44-0468C92DAC82
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN ISNULL(j.IsCompleteForReview, 0)
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = CONVERT(uniqueidentifier, '4BFDB215-3E27-4829-BB44-0468C92DAC82')
                          THEN 1
                      ELSE 0
                  END
          END
      ) = 0

      /* --------------------------------------------------------------------
         NOT COMPLETE: latest-workflow-first, legacy fallback only if no wf
         Completed WF GUID: 20D22623-283B-4088-9CEB-D944AC3E6516
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
                      WHEN wf.LatestWorkflowStatusGuid = CONVERT(uniqueidentifier, '20D22623-283B-4088-9CEB-D944AC3E6516')
                          THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT CANCELLED: latest-workflow-first, legacy fallback only if no wf
         Cancelled WF GUID: 18D8E36B-43BE-4BDE-9D0B-1F34B460AD64
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsCancelled, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = CONVERT(uniqueidentifier, '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64')
                          THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      AND (j.SurveyorID = @UserId)
      AND (j.ReviewedByUserID < 0)
);
GO