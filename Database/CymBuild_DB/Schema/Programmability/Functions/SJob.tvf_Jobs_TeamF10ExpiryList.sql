SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_TeamF10ExpiryList]
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
        client.Name + N' / ' + agent.Name AS ClientAgent,
        jt.Name AS JobTypeName,
        i.FullName AS Consultant,
        js.IsSubjectToNDA,
        p.FormattedAddressComma,
        F10.Reference,
        js.JobStatus,
        j.ExternalReference,
        CONVERT(NVARCHAR(19), F10.SubmissionExpiryDate, 120) AS F10Range
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus AS js ON (js.ID = j.ID)
    JOIN SJob.JobTypes AS jt ON (j.JobTypeID = jt.ID)
    JOIN SCore.Identities AS i ON (j.SurveyorID = i.ID)
    JOIN SCrm.Accounts AS client ON (client.ID = j.ClientAccountID)
    JOIN SJob.Assets AS p ON (p.ID = j.UprnID)
    JOIN SCrm.Accounts AS agent ON (agent.ID = j.AgentAccountID)

    -- Latest workflow status for this job (if any) - rowstatus safe
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

    CROSS APPLY
    (
        SELECT ou1.OrgNode
        FROM SCore.OrganisationalUnits AS ou1
        JOIN SCore.Identities AS i1 ON (i1.OriganisationalUnitId = ou1.ID)
        WHERE (i1.ID = @UserId)
    ) AS CurrentUser

    CROSS APPLY
    (
        SELECT
            m.SubmissionExpiryDate,
            m.StartDateTimeUTC,
            m.DueDateTimeUTC,
            m.Reference
        FROM SJob.Milestones AS m
        JOIN SJob.MilestoneTypes AS mt ON (mt.ID = m.MilestoneTypeID)
        WHERE (m.JobID = j.ID)
          AND (mt.Code = N'F10')
          AND (m.CompletedDateTimeUTC IS NULL)
          AND (m.IsNotApplicable = 0)
          AND (m.SubmissionExpiryDate IS NOT NULL)

          -- ✅ DUE WITHIN 14 DAYS (NOT EXPIRED)
          AND (m.SubmissionExpiryDate >= GETUTCDATE())
          AND (m.SubmissionExpiryDate <  DATEADD(DAY, 14, GETUTCDATE()))

          AND (m.RowStatus NOT IN (0, 254))
          AND NOT EXISTS
          (
              SELECT 1
              FROM SJob.Milestones AS m1
              WHERE (m1.RowStatus NOT IN (0, 254))
                AND (m1.JobID = j.ID)
                AND (m1.MilestoneTypeID = m.MilestoneTypeID)
                AND (m1.SubmittedDateTimeUTC IS NOT NULL)
                AND (m1.SubmissionExpiryDate < m.SubmissionExpiryDate)
          )
    ) AS F10

    WHERE (j.RowStatus NOT IN (0, 254))

      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
      )

      /* --------------------------------------------------------------------
         ACTIVE: legacy OR workflow (latest only)
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
         Cancelled workflow status GUID: 18D8E36B-43BE-4BDE-9D0B-1F34B460AD64
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

      /* --------------------------------------------------------------------
         NOT COMPLETE: legacy OR workflow (latest only)
         Completed workflow status GUID: 20D22623-283B-4088-9CEB-D944AC3E6516
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN (ISNULL(j.IsComplete, 0) = 0) AND (j.JobCompleted IS NULL) THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '20D22623-283B-4088-9CEB-D944AC3E6516' THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT COMPLETE FOR REVIEW: legacy OR workflow (latest only)
         CompleteForReview workflow status GUID: 4BFDB215-3E27-4829-BB44-0468C92DAC82
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsCompleteForReview, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '4BFDB215-3E27-4829-BB44-0468C92DAC82' THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      AND (j.ReviewedByUserID < 0)

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