SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_CompleteForReview]
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
        agent.Name  AS Agent,
        jt.Name     AS JobTypeName,
        i.Guid      AS SurveyorGuid,
        i.FullName  AS SurveyorName,
        js.IsSubjectToNDA,
        j.ExternalReference,
        j.CreatedOn,
        j.CompletedForReviewDate,
        asset.FormattedAddressComma AS Asset
    FROM SJob.Jobs AS j
    JOIN SJob.JobStatus AS js ON (js.ID = j.ID)
    JOIN SJob.JobTypes AS jt ON (j.JobTypeID = jt.ID)
    JOIN SCore.Identities AS i ON (j.SurveyorID = i.ID)
    JOIN SCrm.Accounts AS client ON (client.ID = j.ClientAccountID)
    JOIN SCrm.Accounts AS agent ON (agent.ID = j.AgentAccountID)
    JOIN SJob.Assets AS asset ON (asset.ID = j.UprnID)

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
         COMPLETE FOR REVIEW (this list):
         CFR workflow status GUID: 4BFDB215-3E27-4829-BB44-0468C92DAC82

         Rule:
         - If workflow exists -> include ONLY when latest status == CFR GUID
         - If no workflow -> include when legacy j.IsCompleteForReview = 1
      -------------------------------------------------------------------- */
      AND
      (
          CASE
              WHEN wf.LatestWorkflowStatusGuid IS NULL
                  THEN CASE WHEN ISNULL(j.IsCompleteForReview, 0) = 1 THEN 1 ELSE 0 END
              ELSE
                  CASE
                      WHEN wf.LatestWorkflowStatusGuid = '4BFDB215-3E27-4829-BB44-0468C92DAC82'
                          THEN 1
                      ELSE 0
                  END
          END
      ) = 1

      AND (j.SurveyorID = @UserId)
      AND (j.ReviewedByUserID < 0)
);
GO