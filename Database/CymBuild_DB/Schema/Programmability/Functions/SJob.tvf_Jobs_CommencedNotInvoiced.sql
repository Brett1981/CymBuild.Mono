SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_CommencedNotInvoiced]
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
        jt.Name AS JobType,
        client.Name AS Client,
        agent.Name AS Agent,
        jt.Name AS JobTypeName,
        i.Guid AS SurveyorGuid,
        i.FullName AS SurveyorName,
        js.IsSubjectToNDA,
        j.ExternalReference,
        j.CreatedOn,
        assets.FormattedAddressComma
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus AS js ON (js.ID = j.ID)
    JOIN SJob.JobTypes AS jt ON (j.JobTypeID = jt.ID)
    JOIN SCore.Identities AS i ON (j.SurveyorID = i.ID)
    JOIN SCrm.Accounts AS client ON (client.ID = j.ClientAccountID)
    JOIN SCrm.Accounts AS agent ON (agent.ID = j.AgentAccountID)
    JOIN SJob.Assets AS assets ON (assets.ID = j.UprnID)

    -- Latest workflow status for this job (if any). If none, wf.* will be NULL.
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
         - If workflow exists => must have LatestIsActiveStatus = 1 (inactive = cancelled/dead/etc, exclude)
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
         - If workflow exists -> exclude only if latest == Completed
         - Else -> legacy IsComplete + JobCompleted
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
                          THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         COMMENCED:
         any activity OR milestone updated after job creation
      -------------------------------------------------------------------- */
      AND
      (
          EXISTS
          (
              SELECT 1
              FROM SCore.RecordHistory AS rh1
              JOIN SJob.Activities AS a1 ON (rh1.RowGuid = a1.Guid)
              WHERE (a1.JobID = j.ID)
                AND (a1.RowStatus NOT IN (0, 254))
                AND (rh1.RowStatus NOT IN (0, 254))
                AND (rh1.Datetime > j.CreatedOn)
          )
          OR
          EXISTS
          (
              SELECT 1
              FROM SCore.RecordHistory AS rh1
              JOIN SJob.Milestones AS m1 ON (rh1.RowGuid = m1.Guid)
              WHERE (m1.JobID = j.ID)
                AND (m1.RowStatus NOT IN (0, 254))
                AND (rh1.RowStatus NOT IN (0, 254))
                AND (rh1.Datetime > j.CreatedOn)
          )
      )

      /* --------------------------------------------------------------------
         NOT CANCELLED (exclude cancelled):
         Cancelled workflow status GUID: 18D8E36B-43BE-4BDE-9D0B-1F34B460AD64
         - If workflow exists -> exclude only if latest == Cancelled
         - Else -> legacy IsCancelled
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsCancelled, 0) = 0 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64'
                          THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      /* --------------------------------------------------------------------
         NOT COMPLETE FOR REVIEW (exclude CFR):
         CFR workflow status GUID: 4BFDB215-3E27-4829-BB44-0468C92DAC82
         - If workflow exists -> exclude only if latest == CFR
         - Else -> legacy CompletedForReviewDate IS NULL (include)
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN j.CompletedForReviewDate IS NULL THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '4BFDB215-3E27-4829-BB44-0468C92DAC82'
                          THEN 0
                      ELSE 1
                  END
          END
      ) = 1

      AND (j.SurveyorID = @UserId)
      AND (j.ReviewedByUserID < 0)

      /* --------------------------------------------------------------------
         NOT INVOICED:
         no finance transaction against the job
      -------------------------------------------------------------------- */
      AND NOT EXISTS
      (
          SELECT 1
          FROM SFin.Transactions AS trn
          WHERE (trn.RowStatus NOT IN (0, 254))
            AND (trn.JobID = j.ID)
      )
);
GO